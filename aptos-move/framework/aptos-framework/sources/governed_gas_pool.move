module aptos_framework::governed_gas_pool {

    friend aptos_framework::transaction_validation;

    use std::vector;
    use aptos_framework::account::{Self, SignerCapability, create_signer_with_capability};
    use aptos_framework::system_addresses::{Self};
    // use aptos_framework::primary_fungible_store::{Self};
    use aptos_framework::fungible_asset::{Self};
    use aptos_framework::object::{Self};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use std::features;
    use aptos_framework::signer;
    use aptos_framework::aptos_account::Self;
    
    use aptos_framework::timestamp;
    #[test_only]
    use aptos_framework::coin::{BurnCapability, MintCapability};
    #[test_only]
    use aptos_framework::fungible_asset::BurnRef;
    #[test_only]
    use aptos_framework::aptos_coin::Self;

    friend aptos_framework::stake;

    const MODULE_SALT: vector<u8> = b"aptos_framework::governed_gas_pool";

    /// Event emitted when token are withdraw from the pool
    struct WithdrawStakingRewardEvent has drop, store {
        amount: u64,
    }

    /// Event emitted when pool balance goes below the configured low threshold
    #[event]
    struct PoolLowBalance has drop, store {
        /// Timestamp in microseconds
        when_usecs: u64,
        /// Current total AptosCoin balance of the GGP
        total_balance: u64,
        /// Effective low threshold used for comparison
        low_threshold: u64,
    }

    /// The Governed Gas Pool
    /// Internally, this is a simply wrapper around a resource account. 
    struct GovernedGasPool has key {
        /// The signer capability of the resource account.
        signer_capability: SignerCapability,
    }

    /// Contains added variable needed for the GovernedGasPool staking reward update.
    struct GovernedGasPoolExtension has key {
        deposited_treasury_counter: u64,
        withdraw_staking_reward_events: EventHandle<WithdrawStakingRewardEvent>,
        /// Event handle for low-balance alerts
        low_balance_events: EventHandle<PoolLowBalance>,
        /// Whether we've already emitted a low-balance alert for the current state
        low_event_emitted: bool,
    }

    /// Parameters to compute a dynamic low threshold for the GGP
    /// If this resource does not exist, dynamic low threshold is treated as 0 (disabled)
    struct ThresholdParams has key {
        /// Per-validator base reserve in octas
        base_per_validator: u64,
        /// Target runway in epochs
        runway_epochs: u64,
        /// Safety margin in basis points (e.g. 500 = +5%)
        safety_bps: u64,
        /// Hint for number of active validators
        num_validators_hint: u64,
    }

    /// Address of APT Primary Fungible Store
    inline fun primary_fungible_store_address(account: address): address {
        object::create_user_derived_object_address(account, @aptos_fungible_asset)
    }

    /// Create the seed to derive the resource account address.
    fun create_resource_account_seed(
        delegation_pool_creation_seed: vector<u8>,
    ): vector<u8> {
        let seed = vector::empty<u8>();
        // include module salt (before any subseeds) to avoid conflicts with other modules creating resource accounts
        vector::append(&mut seed, MODULE_SALT);
        // include an additional salt in case the same resource account has already been created
        vector::append(&mut seed, delegation_pool_creation_seed);
        seed
    }

    /// Initializes the governed gas pool around a resource account creation seed. 
    /// @param aptos_framework The signer of the aptos_framework module.
    /// @param delegation_pool_creation_seed The seed to be used to create the resource account hosting the delegation pool.
    public fun initialize(
        aptos_framework: &signer,
        delegation_pool_creation_seed: vector<u8>,
    ) {
        system_addresses::assert_aptos_framework(aptos_framework);

        // return if the governed gas pool has already been initialized
        if (exists<GovernedGasPool>(signer::address_of(aptos_framework))) {
            return
        };

        // generate a seed to be used to create the resource account hosting the delegation pool
        let seed = create_resource_account_seed(delegation_pool_creation_seed);

        let (governed_gas_pool_signer, governed_gas_pool_signer_cap) = account::create_resource_account(aptos_framework, seed);

        // register apt
        aptos_account::register_apt(&governed_gas_pool_signer);

        move_to(aptos_framework, GovernedGasPool{
            signer_capability: governed_gas_pool_signer_cap,
        });

        move_to(aptos_framework, GovernedGasPoolExtension{
            deposited_treasury_counter: 0,
            withdraw_staking_reward_events: account::new_event_handle<WithdrawStakingRewardEvent>(aptos_framework),
            low_balance_events: account::new_event_handle<PoolLowBalance>(aptos_framework),
            low_event_emitted: false,
        });
    }

    /// Initializes the governed gas pool extension alone. 
    /// @param aptos_framework The signer of the aptos_framework module.
    public entry fun initialize_governed_gas_pool_extension(
        aptos_framework: &signer,
    ) {
        system_addresses::assert_aptos_framework(aptos_framework);

        // return if the governed gas extension has already been initialized
        if (exists<GovernedGasPoolExtension>(signer::address_of(aptos_framework))) {
            return
        };

        move_to(aptos_framework, GovernedGasPoolExtension{
            deposited_treasury_counter: 0,
            withdraw_staking_reward_events: account::new_event_handle<WithdrawStakingRewardEvent>(aptos_framework),
            low_balance_events: account::new_event_handle<PoolLowBalance>(aptos_framework),
            low_event_emitted: false,
        });
    }



    /// Initialize the governed gas pool as a module
    /// @param aptos_framework The signer of the aptos_framework module.
    fun init_module(aptos_framework: &signer) {
        // Initialize the governed gas pool
        let seed : vector<u8> = b"aptos_framework::governed_gas_pool";
        initialize(aptos_framework, seed);
    }

    /// Calculate dynamic low threshold based on parameters
    fun compute_dynamic_low_threshold(): u64 acquires ThresholdParams {
        if (!exists<ThresholdParams>(@aptos_framework)) {
            0
        } else {
            let p = borrow_global<ThresholdParams>(@aptos_framework);
            let base = (p.base_per_validator as u128);
            let n = (p.num_validators_hint as u128);
            let runway = (p.runway_epochs as u128);
            let bps = (10000u128 + (p.safety_bps as u128));
            let product = base * n * runway * bps;
            let low_u128 = product / 10000u128;
            assert!(low_u128 <= (18446744073709551615u128), 0);
            (low_u128 as u64)
        }
    }

    #[view]
    public fun get_dynamic_low_threshold(): u64 acquires ThresholdParams {
        compute_dynamic_low_threshold()
    }

    /// Set threshold parameters
    public fun set_threshold_params(
        aptos_framework: &signer,
        base_per_validator: u64,
        runway_epochs: u64,
        safety_bps: u64,
        num_validators_hint: u64,
    ) acquires ThresholdParams {
        system_addresses::assert_aptos_framework(aptos_framework);
        if (exists<ThresholdParams>(@aptos_framework)) {
            let tp = borrow_global_mut<ThresholdParams>(@aptos_framework);
            tp.base_per_validator = base_per_validator;
            tp.runway_epochs = runway_epochs;
            tp.safety_bps = safety_bps;
            tp.num_validators_hint = num_validators_hint;
        } else {
            move_to(aptos_framework, ThresholdParams {
                base_per_validator,
                runway_epochs,
                safety_bps,
                num_validators_hint,
            });
        }
    }

    /// Emit a one-shot low-balance event when crossing below threshold
    fun maybe_emit_low_balance_event() acquires GovernedGasPool, GovernedGasPoolExtension, ThresholdParams {
        let pool_address = governed_gas_pool_address();
        let total_balance = coin::balance<AptosCoin>(pool_address);

        let dyn_low = compute_dynamic_low_threshold();
        // If no dynamic params set, treat low threshold as 0 to avoid false alerts unless desired
        let low_threshold = dyn_low;

        if (low_threshold == 0) {
            return
        };

        let ext = borrow_global<GovernedGasPoolExtension>(@aptos_framework);
        if (total_balance < low_threshold && !ext.low_event_emitted) {
            let now = timestamp::now_microseconds();
            let ext_mut = borrow_global_mut<GovernedGasPoolExtension>(@aptos_framework);
            event::emit_event(
                &mut ext_mut.low_balance_events,
                PoolLowBalance { when_usecs: now, total_balance, low_threshold }
            );
            ext_mut.low_event_emitted = true;
        } else if (total_balance >= low_threshold && ext.low_event_emitted) {
            // Reset flag when we recover above threshold so a future dip re-emits
            let ext_mut = borrow_global_mut<GovernedGasPoolExtension>(@aptos_framework);
            ext_mut.low_event_emitted = false;
        }
    }

    /// Borrows the signer of the governed gas pool.
    /// @return The signer of the governed gas pool.
    fun governed_gas_signer(): signer acquires GovernedGasPool {
        let signer_cap = &borrow_global<GovernedGasPool>(@aptos_framework).signer_capability;
        create_signer_with_capability(signer_cap)
    }

    #[view]
    /// Gets the address of the governed gas pool.
    /// @return The address of the governed gas pool.
    public fun governed_gas_pool_address(): address acquires GovernedGasPool {
        signer::address_of(&governed_gas_signer())
    }

    #[view]
    /// Return the amount of treasury deposited.
    public fun get_treasury_deposited(): u64 acquires GovernedGasPoolExtension {
        borrow_global<GovernedGasPoolExtension>(@aptos_framework).deposited_treasury_counter
    }

    /// Funds the destination account with a given amount of coin.
    /// @param account The account to be funded.
    /// @param amount The amount of coin to be funded.
    public fun fund<CoinType>(aptos_framework: &signer, account: address, amount: u64) acquires GovernedGasPool, GovernedGasPoolExtension, ThresholdParams {
        // Check that the Aptos framework is the caller
        // This is what ensures that funding can only be done by the Aptos framework,
        // i.e., via a governance proposal.
        system_addresses::assert_aptos_framework(aptos_framework);
        let governed_gas_signer = &governed_gas_signer();
        coin::deposit(account, coin::withdraw<CoinType>(governed_gas_signer, amount));
        // Check low threshold after withdrawal from pool
        maybe_emit_low_balance_event();
    }

    /// Deposits some coin into the governed gas pool.
    /// @param coin The coin to be deposited.
    fun deposit<CoinType>(coin: Coin<CoinType>) acquires GovernedGasPool, GovernedGasPoolExtension, ThresholdParams {
        let governed_gas_pool_address = governed_gas_pool_address();
        coin::deposit(governed_gas_pool_address, coin);
        // After deposit, re-evaluate state to reset flag if needed
        maybe_emit_low_balance_event();
    }

    /// Deposits some coin from an account to the governed gas pool.
    /// @param account The account from which the coin is to be deposited.
    /// @param amount The amount of coin to be deposited.
    fun deposit_from<CoinType>(account: address, amount: u64) acquires GovernedGasPool, GovernedGasPoolExtension, ThresholdParams {
       deposit(coin::withdraw_from<CoinType>(account, amount));
    }

    /// Deposits some FA from the fungible store. 
    /// @param aptos_framework The signer of the aptos_framework module.
    /// @param account The account from which the FA is to be deposited.
    /// @param amount The amount of FA to be deposited.
    fun deposit_from_fungible_store(account: address, amount: u64) acquires GovernedGasPool {
        if (amount > 0){
            // compute the governed gas pool store address
            let governed_gas_pool_address = governed_gas_pool_address();
            let governed_gas_pool_store_address = primary_fungible_store_address(governed_gas_pool_address);

            // compute the account store address
            let account_store_address = primary_fungible_store_address(account);
            fungible_asset::deposit_internal( 
                governed_gas_pool_store_address,
                fungible_asset::withdraw_internal(
                    account_store_address,
                    amount
                )
            );
        }
    }

    /// Deposits gas fees into the governed gas pool.
    /// @param gas_payer The address of the account that paid the gas fees.
    /// @param gas_fee The amount of gas fees to be deposited.
    public fun deposit_gas_fee(_gas_payer: address, _gas_fee: u64) acquires GovernedGasPool {
        // get the sender to preserve the signature but do nothing
        governed_gas_pool_address();
    }

    /// Deposits gas fees into the governed gas pool.
    /// @param gas_payer The address of the account that paid the gas fees.
    /// @param gas_fee The amount of gas fees to be deposited.
    public(friend) fun deposit_gas_fee_v2(gas_payer: address, gas_fee: u64) acquires GovernedGasPool, GovernedGasPoolExtension, ThresholdParams {
        if (features::operations_default_to_fa_apt_store_enabled()) {
            deposit_from_fungible_store(gas_payer, gas_fee);
        } else {
            deposit_from<AptosCoin>(gas_payer, gas_fee);
        };
        maybe_emit_low_balance_event();
    }

    /// Deposits from the treasury account. Treasury deposit are recorded.
    /// @param treasury_account The address of the account that paid the treasury.
    /// @param amount The amount of treasury to be deposited.
    public entry fun deposit_treasury(treasury_account: &signer, amount: u64) acquires GovernedGasPool, GovernedGasPoolExtension, ThresholdParams {
        let treasury_account_address = signer::address_of(treasury_account);
        deposit_from<AptosCoin>(treasury_account_address, amount);

        let ggp = borrow_global_mut<GovernedGasPoolExtension>(@aptos_framework);
        ggp.deposited_treasury_counter = ggp.deposited_treasury_counter + amount;
        maybe_emit_low_balance_event();
    }

    #[view]
    /// Gets the balance of a specified coin type in the governed gas pool.
    /// @return The balance of the coin in the pool.
    public fun get_balance<CoinType>(): u64 acquires GovernedGasPool {
        let pool_address = governed_gas_pool_address();
        coin::balance<CoinType>(pool_address)
    }

    /// Withdraws coins from the governed gas pool.
    ///
    /// This function allows friend modules to withdraw a specified amount of a given
    /// `CoinType` from the governed gas pool. It uses the internal signer of the
    /// governed gas pool to authorize the withdrawal.
    ///
    /// @param amount The amount of coins to withdraw from the pool.
    /// @return A `Coin<CoinType>` resource containing the withdrawn amount.
    public(friend) fun withdraw_staking_reward<CoinType>(
        amount: u64
    ): Coin<CoinType> acquires GovernedGasPool, GovernedGasPoolExtension, ThresholdParams {
        let balance = get_balance<CoinType>();
        assert!(balance >= amount, 0); // insufficient balance
        let ggpv2 = borrow_global_mut<GovernedGasPoolExtension>(@aptos_framework);

        event::emit_event(
            &mut ggpv2.withdraw_staking_reward_events,
            WithdrawStakingRewardEvent {
                amount,
            },
        );
        
        // Withdraw reward coin.
        let coin_out = coin::withdraw<CoinType>(&governed_gas_signer(), amount);
        // After withdrawing from pool, check threshold
        maybe_emit_low_balance_event();
        coin_out
    }

    /// Register Aptos coin with Governed gas signer.
    public(friend) fun register_coin<CoinType>() acquires GovernedGasPool {
        let s = governed_gas_signer();
        coin::register<CoinType>(&s);
    }

    #[test_only]
    /// The AptosCoin mint capability
    struct AptosCoinMintCapability has key {
        mint_cap: MintCapability<AptosCoin>,
    }

    #[test_only]
    /// The AptosCoin burn capability
    struct AptosCoinBurnCapability has key {
        burn_cap: BurnCapability<AptosCoin>,
    }

    #[test_only]
    /// The AptosFA burn capabilities
    struct AptosFABurnCapabilities has key {
        burn_ref: BurnRef,
    }


    #[test_only]
    /// Stores the mint capability for AptosCoin.
    ///
    /// @param aptos_framework The signer representing the Aptos framework.
    /// @param mint_cap The mint capability for AptosCoin.
    public fun store_aptos_coin_mint_cap(aptos_framework: &signer, mint_cap: MintCapability<AptosCoin>) {
        system_addresses::assert_aptos_framework(aptos_framework);
        move_to(aptos_framework, AptosCoinMintCapability { mint_cap })
    }

    #[test_only]
    /// Stores the burn capability for AptosCoin, converting to a fungible asset reference if the feature is enabled.
    ///
    /// @param aptos_framework The signer representing the Aptos framework.
    /// @param burn_cap The burn capability for AptosCoin.
    public fun store_aptos_coin_burn_cap(aptos_framework: &signer, burn_cap: BurnCapability<AptosCoin>) {
        system_addresses::assert_aptos_framework(aptos_framework);
        if (features::operations_default_to_fa_apt_store_enabled()) {
            let burn_ref = coin::convert_and_take_paired_burn_ref(burn_cap);
            move_to(aptos_framework, AptosFABurnCapabilities { burn_ref });
        } else {
            move_to(aptos_framework, AptosCoinBurnCapability { burn_cap })
        }
    }

    #[test_only]
    /// Initializes the governed gas pool around a fixed creation seed for testing
    ///
    /// @param aptos_framework The signer of the aptos_framework module.
    public fun initialize_for_test(
        aptos_framework: &signer,
    ) {

        // Create framework account to be able to send event.
        aptos_framework::account::create_account_for_test(@aptos_framework);

        // Ensure timestamp resource exists for tests that emit events with timestamps
        timestamp::set_time_has_started_for_testing(aptos_framework);

        // initialize the AptosCoin module
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        
        // Initialize the governed gas pool
        let seed : vector<u8> = b"test";
        initialize(aptos_framework, seed);

        // add the mint capability to the governed gas pool
        store_aptos_coin_mint_cap(aptos_framework, mint_cap);
        store_aptos_coin_burn_cap(aptos_framework, burn_cap);

    }

    #[test_only]
    /// Mints some coin to an account for testing purposes.
    ///
    /// @param account The account to which the coin is to be minted.
    /// @param amount The amount of coin to be minted.
    public fun mint_for_test(account: address, amount: u64) acquires AptosCoinMintCapability {
         coin::deposit(account, coin::mint(
            amount,
            &borrow_global<AptosCoinMintCapability>(@aptos_framework).mint_cap
        ));
    }

    #[test(aptos_framework = @aptos_framework, depositor = @0xdddd)]
    /// Deposits some coin into the governed gas pool.
    ///
    /// @param aptos_framework is the signer of the aptos_framework module.
    fun test_governed_gas_pool_deposit(aptos_framework: &signer, depositor: &signer) acquires GovernedGasPool, AptosCoinMintCapability, GovernedGasPoolExtension, ThresholdParams {
       
        // initialize the modules
        initialize_for_test(aptos_framework);
    
        // create the depositor account and fund it
        aptos_account::create_account(signer::address_of(depositor));
        mint_for_test(signer::address_of(depositor), 1000);

        // get the balances for the depositor and the governed gas pool
        let depositor_balance = coin::balance<AptosCoin>(signer::address_of(depositor));
        let governed_gas_pool_balance = coin::balance<AptosCoin>(governed_gas_pool_address());

        // deposit some coin into the governed gas pool
        deposit_from<AptosCoin>(signer::address_of(depositor), 100);

        // check the balances after the deposit
        assert!(coin::balance<AptosCoin>(signer::address_of(depositor)) == depositor_balance - 100, 1);
        assert!(coin::balance<AptosCoin>(governed_gas_pool_address()) == governed_gas_pool_balance + 100, 2);
    
    }

    #[test(aptos_framework = @aptos_framework, depositor = @0xdddd)]
    /// Deposits some coin from an account to the governed gas pool as gas fees.
    ///
    /// @param aptos_framework is the signer of the aptos_framework module.
    /// @param depositor is the signer of the account from which the coin is to be deposited.
    fun test_governed_gas_pool_deposit_gas_fee(aptos_framework: &signer, depositor: &signer) acquires GovernedGasPool, AptosCoinMintCapability, GovernedGasPoolExtension, ThresholdParams {
       
        // initialize the modules
        initialize_for_test(aptos_framework);
    
        // create the depositor account and fund it
        aptos_account::create_account(signer::address_of(depositor));
        mint_for_test(signer::address_of(depositor), 1000);

        // get the balances for the depositor and the governed gas pool
        let depositor_balance = coin::balance<AptosCoin>(signer::address_of(depositor));
        let governed_gas_pool_balance = coin::balance<AptosCoin>(governed_gas_pool_address());

        // deposit some coin into the governed gas pool as gas fees
        deposit_gas_fee_v2(signer::address_of(depositor), 100);

        // check the balances after the deposit
        assert!(coin::balance<AptosCoin>(signer::address_of(depositor)) == depositor_balance - 100, 1);
        assert!(coin::balance<AptosCoin>(governed_gas_pool_address()) == governed_gas_pool_balance + 100, 2);
    
    }

    #[test(aptos_framework = @aptos_framework)]
    /// Test for the get_balance view method.
    fun test_governed_gas_pool_get_balance(aptos_framework: &signer) acquires GovernedGasPool, AptosCoinMintCapability {
       
        // initialize the modules
        initialize_for_test(aptos_framework);

        // fund the governed gas pool
        let governed_gas_pool_address = governed_gas_pool_address();
        mint_for_test(governed_gas_pool_address, 1000);

        // assert the balance is correct
        assert!(get_balance<AptosCoin>() == 1000, 1);
    }

    #[test(aptos_framework = @aptos_framework, depositor = @0xdddd, beneficiary = @0xbbbb)]
    /// Funds the destination account with a given amount of coin.
    ///
    /// @param aptos_framework is the signer of the aptos_framework module.
    /// @param depositor is the signer of the account from which the coin is to be funded.
    /// @param beneficiary is the address of the account to be funded.
    fun test_governed_gas_pool_fund(aptos_framework: &signer, depositor: &signer, beneficiary: &signer) acquires GovernedGasPool, AptosCoinMintCapability, GovernedGasPoolExtension, ThresholdParams {
       
        // initialize the modules
        initialize_for_test(aptos_framework);
    
        // create the depositor account and fund it
        aptos_account::create_account(signer::address_of(depositor));
        mint_for_test(signer::address_of(depositor), 1000);

        // get the balances for the depositor and the governed gas pool
        let depositor_balance = coin::balance<AptosCoin>(signer::address_of(depositor));
        let governed_gas_pool_balance = coin::balance<AptosCoin>(governed_gas_pool_address());

        // collect gas fees from the depositor
        deposit_gas_fee_v2(signer::address_of(depositor), 100);

        // check the balances after the deposit
        assert!(coin::balance<AptosCoin>(signer::address_of(depositor)) == depositor_balance - 100, 1);
        assert!(coin::balance<AptosCoin>(governed_gas_pool_address()) == governed_gas_pool_balance + 100, 2);

        // ensure the beneficiary account has registered with the AptosCoin module
        aptos_account::create_account(signer::address_of(beneficiary));
        aptos_account::register_apt(beneficiary);

        // fund the beneficiary account
        fund<AptosCoin>(aptos_framework, signer::address_of(beneficiary), 100);

        // check the balances after the funding
        assert!(coin::balance<AptosCoin>(governed_gas_pool_address()) == governed_gas_pool_balance, 3);
        assert!(coin::balance<AptosCoin>(signer::address_of(beneficiary)) == 100, 4);
    
    }

    #[test(aptos_framework = @aptos_framework)]
    fun test_initialize_is_idempotent(aptos_framework: &signer) {
        // initialize the governed gas pool
        initialize_for_test(aptos_framework);
        // initialize the governed gas pool again, no abort
        initialize(aptos_framework, vector::empty<u8>());
    }


    #[test(aptos_framework = @aptos_framework, treasury = @0xdddd)]
    /// Add some treasury to the governed gas pool.
    ///
    /// @param aptos_framework is the signer of the aptos_framework module.
    fun test_deposite_treasury_and_counter(aptos_framework: &signer, treasury: &signer) acquires GovernedGasPool, GovernedGasPoolExtension, AptosCoinMintCapability, ThresholdParams {
       
        // initialize the modules
        initialize_for_test(aptos_framework);
    
        // create the depositor account and fund it
        aptos_account::create_account(signer::address_of(treasury));
        mint_for_test(signer::address_of(treasury), 1000);

        // get the balances for the depositor and the governed gas pool
        let treasury_balance = coin::balance<AptosCoin>(signer::address_of(treasury));
        let governed_gas_pool_balance = coin::balance<AptosCoin>(governed_gas_pool_address());

        // deposit some coin into the governed gas pool
        deposit_treasury(treasury, 100);

        // check the balances after the deposit
        assert!(coin::balance<AptosCoin>(signer::address_of(treasury)) == treasury_balance - 100, 1);
        assert!(coin::balance<AptosCoin>(governed_gas_pool_address()) == governed_gas_pool_balance + 100, 2);
        assert!(get_treasury_deposited() == 100, 3);

        let withdraw = withdraw_staking_reward<AptosCoin>(10);
        assert!(coin::balance<AptosCoin>(governed_gas_pool_address()) == governed_gas_pool_balance + 100 - 10, 4);
        assert!(get_treasury_deposited() == 100, 5);
        assert!(coin::value(&withdraw) == 10, 6);

        coin::deposit(@0xdddd, withdraw);
    }

    #[test(aptos_framework = @aptos_framework, user = @0x1111)]
    /// Verify low-balance event emits when crossing below dynamic threshold and resets above
    fun test_low_balance_event_flow(aptos_framework: &signer, user: &signer) acquires GovernedGasPool, GovernedGasPoolExtension, AptosCoinMintCapability, ThresholdParams {
        // initialize framework + GGP + coin
        initialize_for_test(aptos_framework);

        // create user and register
        aptos_account::create_account(signer::address_of(user));
        aptos_account::register_apt(user);

        // set dynamic threshold: 1000 octas
        set_threshold_params(aptos_framework, 1000, 1, 0, 1);

        // fund pool above threshold
        mint_for_test(governed_gas_pool_address(), 2000);

        // ensure flag is false initially
        let ext0 = borrow_global<GovernedGasPoolExtension>(@aptos_framework);
        assert!(!ext0.low_event_emitted, 1);

        // withdraw 1500 -> pool = 500 < 1000 => should emit event and set flag
        let c = withdraw_staking_reward<AptosCoin>(1500);
        let ext1 = borrow_global<GovernedGasPoolExtension>(@aptos_framework);
        assert!(ext1.low_event_emitted, 2);

        // deposit back above threshold -> flag resets; move withdrawn coin to user
        mint_for_test(governed_gas_pool_address(), 2000);
        // re-evaluate threshold after direct mint (bypasses deposit path)
        maybe_emit_low_balance_event();
        coin::deposit(signer::address_of(user), c);
        let ext2 = borrow_global<GovernedGasPoolExtension>(@aptos_framework);
        assert!(!ext2.low_event_emitted, 3);
    }

}

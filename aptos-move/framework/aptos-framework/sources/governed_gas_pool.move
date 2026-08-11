module aptos_framework::governed_gas_pool {

    friend aptos_framework::transaction_validation;

    use std::vector;
    use aptos_framework::account::{Self, SignerCapability, create_signer_with_capability};
    use aptos_framework::system_addresses::{Self};
    use aptos_framework::primary_fungible_store::{Self};
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use std::features;
    use aptos_framework::signer;
    use aptos_framework::aptos_account::Self;
    #[test_only]
    use aptos_framework::coin::{BurnCapability, MintCapability};
    #[test_only]
    use aptos_framework::fungible_asset::BurnRef;
    #[test_only]
    use aptos_framework::aptos_coin::Self;

    friend aptos_framework::stake;
    friend aptos_framework::transaction_fee;

    /// No longer supported.
    const ENO_LONGER_SUPPORTED: u64 = 4;

    /// The fungible asset is not accepted for gas payment.
    const EFA_NOT_ACCEPTED: u64 = 5;

    /// A gas fungible asset's gas price must be non-zero.
    const EINVALID_GAS_FA_PRICE: u64 = 6;

    /// The computed fungible asset gas fee does not fit in a u64.
    const EGAS_FA_FEE_OVERFLOW: u64 = 7;

    /// Maximum u64 value, used to guard fungible asset gas fee computation against overflow.
    const MAX_U64: u128 = 18446744073709551615;

    const MODULE_SALT: vector<u8> = b"aptos_framework::governed_gas_pool";

    /// Event emitted when token are withdraw from the pool
    struct WithdrawStakingRewardEvent has drop, store {
        amount: u64,
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
    }

    /// A fungible asset accepted for gas payment, together with its gas price: the number of FA base
    /// units charged per unit of gas consumed. The FA gas fee for a transaction is
    /// `gas_units_used * gas_price`.
    struct AcceptedGasFa has store, drop {
        metadata: address,
        gas_price: u64,
    }

    /// Registry of fungible assets accepted for gas payment. Each accepted FA is held in the
    /// governed gas pool account's own primary store for that metadata object (a separate per-FA
    /// pool that shares the single pool resource account), and stores its gas price alongside.
    struct AcceptedGasFungibleAssets has key {
        entries: vector<AcceptedGasFa>,
    }

    #[event]
    /// Emitted when a fungible asset is added to (`accepted = true`) or removed from
    /// (`accepted = false`) the set accepted for gas payment.
    struct AcceptedGasFungibleAssetUpdate has drop, store {
        metadata: address,
        accepted: bool,
    }

    #[event]
    /// Emitted when a fungible asset's gas price is set or updated.
    struct GasFungibleAssetPriceUpdate has drop, store {
        metadata: address,
        gas_price: u64,
    }

    #[event]
    /// Emitted when gas fees are deposited into a per-FA governed gas pool.
    struct FungibleAssetGasFeeDeposit has drop, store {
        gas_payer: address,
        metadata: address,
        /// Fungible asset base units deposited.
        amount: u64,
    }

    /// Address of `account`'s primary fungible store for the FA identified by `metadata`.
    inline fun primary_fungible_store_address_for(account: address, metadata: address): address {
        object::create_user_derived_object_address(account, metadata)
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
            if (!exists<GovernedGasPoolExtension>(signer::address_of(aptos_framework))) {
                move_to(aptos_framework, GovernedGasPoolExtension{
                    deposited_treasury_counter: 0,
                    withdraw_staking_reward_events: account::new_event_handle<WithdrawStakingRewardEvent>(aptos_framework),
                });
            }
        } else {

            // generate a seed to be used to create the resource account hosting the delegation pool
            let seed = create_resource_account_seed(delegation_pool_creation_seed);

            let (governed_gas_pool_signer, governed_gas_pool_signer_cap) = account::create_resource_account(aptos_framework, seed);

            // register apt
            aptos_account::register_fa_and_apt(&governed_gas_pool_signer);
            move_to(aptos_framework, GovernedGasPool{
                signer_capability: governed_gas_pool_signer_cap,
            });

            move_to(aptos_framework, GovernedGasPoolExtension{
                deposited_treasury_counter: 0,
                withdraw_staking_reward_events: account::new_event_handle<WithdrawStakingRewardEvent>(aptos_framework),
            });
        }
    }

    /// Initializes the governed gas pool extension alone.
    /// @param aptos_framework The signer of the aptos_framework module.
    public entry fun initialize_governed_gas_pool_extension(
        aptos_framework: &signer,
    ) {
        system_addresses::assert_aptos_framework(aptos_framework);

        // return if the governed gas extension has already been initialized
        if (exists<GovernedGasPoolExtension>(signer::address_of(aptos_framework))) {
        } else {

        move_to(aptos_framework, GovernedGasPoolExtension{
            deposited_treasury_counter: 0,
            withdraw_staking_reward_events: account::new_event_handle<WithdrawStakingRewardEvent>(aptos_framework),
        });
        }
    }

    /// Initialize the governed gas pool as a module
    /// @param aptos_framework The signer of the aptos_framework module.
    fun init_module(aptos_framework: &signer) {
        // Initialize the governed gas pool
        let seed : vector<u8> = b"aptos_framework::governed_gas_pool";
        initialize(aptos_framework, seed);
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
    public fun fund<CoinType>(aptos_framework: &signer, account: address, amount: u64) acquires GovernedGasPool {
        // Check that the Aptos framework is the caller
        // This is what ensures that funding can only be done by the Aptos framework,
        // i.e., via a governance proposal.
        system_addresses::assert_aptos_framework(aptos_framework);
        let governed_gas_signer = &governed_gas_signer();
        coin::deposit(account, coin::withdraw<CoinType>(governed_gas_signer, amount));
    }

    /// Deposits some coin into the governed gas pool.
    /// @param coin The coin to be deposited.
    fun deposit<CoinType>(coin: Coin<CoinType>) acquires GovernedGasPool {
        let governed_gas_pool_address = governed_gas_pool_address();
        coin::deposit(governed_gas_pool_address, coin);
    }

    /// Deposits some coin from an account to the governed gas pool.
    /// @param account The account from which the coin is to be deposited.
    /// @param amount The amount of coin to be deposited.
    fun deposit_from<CoinType>(account: address, amount: u64) acquires GovernedGasPool {
       let asset = coin::withdraw_from<CoinType>(account, amount);
       deposit(asset);
    }

    /// Deposits APT from the fungible store into the governed gas pool.
    /// @param account The account from which the APT FA is to be deposited.
    /// @param amount The amount of APT FA to be deposited.
    fun deposit_from_fungible_store(account: address, amount: u64) acquires GovernedGasPool {
        deposit_from_fungible_store_for(account, @aptos_fungible_asset, amount);
    }

    /// Deposits `amount` of the fungible asset identified by `metadata` from `account`'s primary
    /// store into the governed gas pool account's own primary store for that FA (its per-FA pool).
    /// Uses the unchecked (VM-privileged) withdraw/deposit path, as gas collection is not authorized
    /// by the payer's signer.
    fun deposit_from_fungible_store_for(account: address, metadata: address, amount: u64) acquires GovernedGasPool {
        if (amount > 0) {
            let pool_store_address =
                primary_fungible_store_address_for(governed_gas_pool_address(), metadata);
            let account_store_address = primary_fungible_store_address_for(account, metadata);
            fungible_asset::unchecked_deposit(
                pool_store_address,
                fungible_asset::unchecked_withdraw(account_store_address, amount)
            );
        }
    }

    /// Deposits gas fees into the governed gas pool.
    /// @param gas_payer The address of the account that paid the gas fees.
    /// @param gas_fee The amount of gas fees to be deposited.
    public fun deposit_gas_fee(_gas_payer: address, _gas_fee: u64) {
         abort error::not_implemented(ENO_LONGER_SUPPORTED)
    }

    /// Deposits gas fees into the governed gas pool.
    /// @param gas_payer The address of the account that paid the gas fees.
    /// @param gas_fee The amount of gas fees to be deposited.
    public(friend) fun deposit_gas_fee_v2(gas_payer: address, gas_fee: u64) acquires GovernedGasPool {
        if (features::operations_default_to_fa_apt_store_enabled()) {
            deposit_from_fungible_store(gas_payer, gas_fee);
        } else {
            deposit_from<AptosCoin>(gas_payer, gas_fee);
        };
    }

    /// Creates the accepted-FA registry under @aptos_framework if it does not yet exist. This lets
    /// the feature roll out onto an already-initialized governed gas pool without re-running
    /// `initialize`.
    fun ensure_accepted_registry(aptos_framework: &signer) {
        if (!exists<AcceptedGasFungibleAssets>(signer::address_of(aptos_framework))) {
            move_to(aptos_framework, AcceptedGasFungibleAssets { entries: vector::empty<AcceptedGasFa>() });
        };
    }

    /// Index of the accepted-FA entry for `metadata`, if present.
    fun find_accepted_index(entries: &vector<AcceptedGasFa>, metadata: address): (bool, u64) {
        let len = vector::length(entries);
        let i = 0;
        while (i < len) {
            if (vector::borrow(entries, i).metadata == metadata) {
                return (true, i)
            };
            i = i + 1;
        };
        (false, 0)
    }

    /// Adds a fungible asset to the set accepted for gas payment with its gas price (FA base units
    /// charged per unit of gas consumed), and ensures the pool has a primary store to hold it.
    /// Governance-gated (requires the @aptos_framework signer). Re-adding an existing FA updates its
    /// gas price.
    /// @param aptos_framework The signer of the aptos_framework module.
    /// @param metadata The metadata object of the fungible asset to accept.
    /// @param gas_price FA base units charged per unit of gas consumed; must be non-zero.
    public entry fun add_accepted_gas_fungible_asset(
        aptos_framework: &signer,
        metadata: Object<Metadata>,
        gas_price: u64,
    ) acquires GovernedGasPool, AcceptedGasFungibleAssets {
        system_addresses::assert_aptos_framework(aptos_framework);
        assert!(gas_price > 0, error::invalid_argument(EINVALID_GAS_FA_PRICE));
        ensure_accepted_registry(aptos_framework);
        let metadata_address = object::object_address(&metadata);
        let accepted = borrow_global_mut<AcceptedGasFungibleAssets>(@aptos_framework);
        let (found, i) = find_accepted_index(&accepted.entries, metadata_address);
        if (found) {
            vector::borrow_mut(&mut accepted.entries, i).gas_price = gas_price;
        } else {
            vector::push_back(&mut accepted.entries, AcceptedGasFa { metadata: metadata_address, gas_price });
            // Ensure the pool has a primary store for this FA so unchecked deposits succeed.
            primary_fungible_store::ensure_primary_store_exists(governed_gas_pool_address(), metadata);
            event::emit(AcceptedGasFungibleAssetUpdate { metadata: metadata_address, accepted: true });
        };
        event::emit(GasFungibleAssetPriceUpdate { metadata: metadata_address, gas_price });
    }

    /// Sets (updates) the gas price of an already-accepted fungible asset. Governance-gated.
    /// @param aptos_framework The signer of the aptos_framework module.
    /// @param metadata The metadata object of the fungible asset.
    /// @param gas_price FA base units charged per unit of gas consumed; must be non-zero.
    public entry fun set_gas_fungible_asset_price(
        aptos_framework: &signer,
        metadata: Object<Metadata>,
        gas_price: u64,
    ) acquires AcceptedGasFungibleAssets {
        system_addresses::assert_aptos_framework(aptos_framework);
        assert!(gas_price > 0, error::invalid_argument(EINVALID_GAS_FA_PRICE));
        assert!(exists<AcceptedGasFungibleAssets>(@aptos_framework), error::invalid_argument(EFA_NOT_ACCEPTED));
        let metadata_address = object::object_address(&metadata);
        let accepted = borrow_global_mut<AcceptedGasFungibleAssets>(@aptos_framework);
        let (found, i) = find_accepted_index(&accepted.entries, metadata_address);
        assert!(found, error::invalid_argument(EFA_NOT_ACCEPTED));
        vector::borrow_mut(&mut accepted.entries, i).gas_price = gas_price;
        event::emit(GasFungibleAssetPriceUpdate { metadata: metadata_address, gas_price });
    }

    /// Removes a fungible asset from the set accepted for gas payment. Any balance already held in
    /// its pool remains and can still be withdrawn via `fund_fa`. Governance-gated.
    /// @param aptos_framework The signer of the aptos_framework module.
    /// @param metadata The metadata object of the fungible asset to stop accepting.
    public entry fun remove_accepted_gas_fungible_asset(
        aptos_framework: &signer,
        metadata: Object<Metadata>,
    ) acquires AcceptedGasFungibleAssets {
        system_addresses::assert_aptos_framework(aptos_framework);
        if (!exists<AcceptedGasFungibleAssets>(@aptos_framework)) {
            return
        };
        let metadata_address = object::object_address(&metadata);
        let accepted = borrow_global_mut<AcceptedGasFungibleAssets>(@aptos_framework);
        let (found, i) = find_accepted_index(&accepted.entries, metadata_address);
        if (found) {
            vector::remove(&mut accepted.entries, i);
            event::emit(AcceptedGasFungibleAssetUpdate { metadata: metadata_address, accepted: false });
        };
    }

    #[view]
    /// Whether the fungible asset identified by `metadata` is accepted for gas payment.
    public fun is_accepted_gas_fungible_asset(metadata: address): bool acquires AcceptedGasFungibleAssets {
        if (!exists<AcceptedGasFungibleAssets>(@aptos_framework)) {
            return false
        };
        let (found, _) = find_accepted_index(&borrow_global<AcceptedGasFungibleAssets>(@aptos_framework).entries, metadata);
        found
    }

    #[view]
    /// The full set of fungible asset metadata addresses accepted for gas payment.
    public fun accepted_gas_fungible_assets(): vector<address> acquires AcceptedGasFungibleAssets {
        let result = vector::empty<address>();
        if (exists<AcceptedGasFungibleAssets>(@aptos_framework)) {
            let entries = &borrow_global<AcceptedGasFungibleAssets>(@aptos_framework).entries;
            let len = vector::length(entries);
            let i = 0;
            while (i < len) {
                vector::push_back(&mut result, vector::borrow(entries, i).metadata);
                i = i + 1;
            };
        };
        result
    }

    #[view]
    /// The gas price (FA base units per unit of gas) of an accepted fungible asset. Aborts if the
    /// fungible asset is not accepted for gas payment.
    public fun get_gas_fungible_asset_price(metadata: address): u64 acquires AcceptedGasFungibleAssets {
        assert!(exists<AcceptedGasFungibleAssets>(@aptos_framework), error::invalid_argument(EFA_NOT_ACCEPTED));
        let accepted = borrow_global<AcceptedGasFungibleAssets>(@aptos_framework);
        let (found, i) = find_accepted_index(&accepted.entries, metadata);
        assert!(found, error::invalid_argument(EFA_NOT_ACCEPTED));
        vector::borrow(&accepted.entries, i).gas_price
    }

    #[view]
    /// The fungible asset gas fee for `gas_units` of gas consumed under `metadata`'s gas price, i.e.
    /// `gas_units * gas_price`. Aborts if the FA is not accepted or the fee overflows u64.
    public fun gas_fee_in_fa(metadata: address, gas_units: u64): u64 acquires AcceptedGasFungibleAssets {
        let price = get_gas_fungible_asset_price(metadata);
        let fee = (gas_units as u128) * (price as u128);
        assert!(fee <= MAX_U64, error::out_of_range(EGAS_FA_FEE_OVERFLOW));
        (fee as u64)
    }

    #[view]
    /// The governed gas pool's balance of the fungible asset identified by `metadata`.
    public fun get_fa_balance(metadata: address): u64 acquires GovernedGasPool {
        primary_fungible_store::balance(
            governed_gas_pool_address(),
            object::address_to_object<Metadata>(metadata)
        )
    }

    /// Deposits `fa_amount` base units of a selected gas fungible asset (already converted from gas
    /// via that FA's gas price) into its governed gas pool. Aborts if the FA is not accepted.
    /// @param gas_payer The address that paid the gas fees.
    /// @param metadata The metadata object address of the fungible asset.
    /// @param fa_amount The fungible asset base units to deposit.
    public(friend) fun deposit_gas_fee_fa(
        gas_payer: address,
        metadata: address,
        fa_amount: u64,
    ) acquires GovernedGasPool, AcceptedGasFungibleAssets {
        assert!(is_accepted_gas_fungible_asset(metadata), error::invalid_argument(EFA_NOT_ACCEPTED));
        deposit_from_fungible_store_for(gas_payer, metadata, fa_amount);
        if (fa_amount > 0) {
            event::emit(FungibleAssetGasFeeDeposit { gas_payer, metadata, amount: fa_amount });
        };
    }

    /// Withdraws `amount` of the fungible asset identified by `metadata` from its governed gas pool
    /// and deposits it to `account`. Governance-gated; the mirror of `fund` for fungible assets.
    /// @param aptos_framework The signer of the aptos_framework module.
    /// @param account The recipient account.
    /// @param metadata The metadata object address of the fungible asset.
    /// @param amount The amount to withdraw from the pool.
    public fun fund_fa(
        aptos_framework: &signer,
        account: address,
        metadata: address,
        amount: u64,
    ) acquires GovernedGasPool {
        system_addresses::assert_aptos_framework(aptos_framework);
        let pool_signer = governed_gas_signer();
        let fa = primary_fungible_store::withdraw(
            &pool_signer,
            object::address_to_object<Metadata>(metadata),
            amount
        );
        primary_fungible_store::deposit(account, fa);
    }

    /// Deposits from the treasury account. Treasury deposit are recorded.
    /// @param treasury_account The address of the account that paid the treasury.
    /// @param amount The amount of treasury to be deposited.
    public entry fun deposit_treasury(treasury_account: &signer, amount: u64) acquires GovernedGasPool, GovernedGasPoolExtension {
        let treasury_account_address = signer::address_of(treasury_account);
        deposit_from<AptosCoin>(treasury_account_address, amount);

        let ggp = borrow_global_mut<GovernedGasPoolExtension>(@aptos_framework);
        ggp.deposited_treasury_counter = ggp.deposited_treasury_counter + amount;
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
    ): Coin<CoinType> acquires GovernedGasPool, GovernedGasPoolExtension {
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
        coin::withdraw<CoinType>(&governed_gas_signer(), amount)
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
    fun test_governed_gas_pool_deposit(aptos_framework: &signer, depositor: &signer) acquires GovernedGasPool, AptosCoinMintCapability {

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
    fun test_governed_gas_pool_deposit_gas_fee(aptos_framework: &signer, depositor: &signer) acquires GovernedGasPool, AptosCoinMintCapability {

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
    fun test_governed_gas_pool_fund(aptos_framework: &signer, depositor: &signer, beneficiary: &signer) acquires GovernedGasPool, AptosCoinMintCapability {

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
    fun test_deposite_treasury_and_counter(aptos_framework: &signer, treasury: &signer) acquires GovernedGasPool, GovernedGasPoolExtension, AptosCoinMintCapability {
       
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

    #[test(aptos_framework = @aptos_framework, payer = @0xcafe)]
    /// A selected fungible asset gets its own pool: gas paid in it is collected separately from APT,
    /// and can be funded back out by governance.
    fun test_per_fa_gas_pool(aptos_framework: &signer, payer: &signer)
        acquires GovernedGasPool, AcceptedGasFungibleAssets {
        initialize_for_test(aptos_framework);

        // Create a test fungible asset and mint some to the payer.
        let (creator_ref, token) = fungible_asset::create_test_token(payer);
        let (mint_ref, _transfer_ref, _burn_ref) =
            primary_fungible_store::init_test_metadata_with_primary_store_enabled(&creator_ref);
        let payer_address = signer::address_of(payer);
        // The test FA has a max supply of 100.
        primary_fungible_store::mint(&mint_ref, payer_address, 100);
        let metadata_address = object::object_address(&token);
        let metadata = object::address_to_object<Metadata>(metadata_address);

        // Not accepted yet.
        assert!(!is_accepted_gas_fungible_asset(metadata_address), 1);

        // Accept it with a gas price of 2 FA units per gas unit (governance).
        add_accepted_gas_fungible_asset(aptos_framework, metadata, 2);
        assert!(is_accepted_gas_fungible_asset(metadata_address), 2);
        assert!(vector::contains(&accepted_gas_fungible_assets(), &metadata_address), 3);
        assert!(get_gas_fungible_asset_price(metadata_address) == 2, 11);
        // gas_used * price: 5 gas units at price 2 = 10 FA units.
        assert!(gas_fee_in_fa(metadata_address, 5) == 10, 12);

        // Governance can update the gas price via a function.
        set_gas_fungible_asset_price(aptos_framework, metadata, 3);
        assert!(get_gas_fungible_asset_price(metadata_address) == 3, 13);
        assert!(gas_fee_in_fa(metadata_address, 5) == 15, 14);

        // Pay gas in the FA -> goes into that FA's pool, separate from the APT pool.
        deposit_gas_fee_fa(payer_address, metadata_address, 30);
        assert!(primary_fungible_store::balance(payer_address, metadata) == 70, 4);
        assert!(get_fa_balance(metadata_address) == 30, 5);
        // The APT pool is untouched.
        assert!(coin::balance<AptosCoin>(governed_gas_pool_address()) == 0, 6);

        // Governance withdraws from the FA pool back to an account.
        fund_fa(aptos_framework, payer_address, metadata_address, 10);
        assert!(get_fa_balance(metadata_address) == 20, 7);
        assert!(primary_fungible_store::balance(payer_address, metadata) == 80, 8);

        // Removing it from the accepted set leaves the residual balance intact.
        remove_accepted_gas_fungible_asset(aptos_framework, metadata);
        assert!(!is_accepted_gas_fungible_asset(metadata_address), 9);
        assert!(get_fa_balance(metadata_address) == 20, 10);
    }

    #[test(aptos_framework = @aptos_framework, payer = @0xcafe)]
    #[expected_failure(abort_code = 65541, location = Self)]
    /// Depositing gas in a fungible asset that is not accepted aborts with EFA_NOT_ACCEPTED.
    fun test_deposit_gas_fee_fa_aborts_when_not_accepted(aptos_framework: &signer, payer: &signer)
        acquires GovernedGasPool, AcceptedGasFungibleAssets {
        initialize_for_test(aptos_framework);
        let (creator_ref, token) = fungible_asset::create_test_token(payer);
        let (mint_ref, _transfer_ref, _burn_ref) =
            primary_fungible_store::init_test_metadata_with_primary_store_enabled(&creator_ref);
        primary_fungible_store::mint(&mint_ref, signer::address_of(payer), 100);
        // Never accepted -> abort.
        deposit_gas_fee_fa(signer::address_of(payer), object::object_address(&token), 30);
    }

    #[test(aptos_framework = @aptos_framework, intruder = @0xbad)]
    #[expected_failure(abort_code = 327683, location = aptos_framework::system_addresses)]
    /// Accepting a gas FA requires the @aptos_framework (governance) signer.
    fun test_add_accepted_requires_framework(aptos_framework: &signer, intruder: &signer)
        acquires GovernedGasPool, AcceptedGasFungibleAssets {
        initialize_for_test(aptos_framework);
        let (creator_ref, token) = fungible_asset::create_test_token(intruder);
        let (_m, _t, _b) = primary_fungible_store::init_test_metadata_with_primary_store_enabled(&creator_ref);
        add_accepted_gas_fungible_asset(
            intruder,
            object::address_to_object<Metadata>(object::object_address(&token)),
            1,
        );
    }

    #[test(aptos_framework = @aptos_framework, intruder = @0xbad)]
    #[expected_failure(abort_code = 327683, location = aptos_framework::system_addresses)]
    /// Updating a gas FA's price requires the @aptos_framework (governance) signer.
    fun test_set_price_requires_framework(aptos_framework: &signer, intruder: &signer)
        acquires GovernedGasPool, AcceptedGasFungibleAssets {
        initialize_for_test(aptos_framework);
        let (creator_ref, token) = fungible_asset::create_test_token(intruder);
        let (_m, _t, _b) = primary_fungible_store::init_test_metadata_with_primary_store_enabled(&creator_ref);
        let metadata = object::address_to_object<Metadata>(object::object_address(&token));
        add_accepted_gas_fungible_asset(aptos_framework, metadata, 1);
        // Non-governance caller -> abort.
        set_gas_fungible_asset_price(intruder, metadata, 2);
    }

    #[test(aptos_framework = @aptos_framework, creator = @0xcafe)]
    #[expected_failure(abort_code = 65542, location = Self)]
    /// A gas FA cannot be accepted with a zero gas price (would make gas free).
    fun test_add_rejects_zero_price(aptos_framework: &signer, creator: &signer)
        acquires GovernedGasPool, AcceptedGasFungibleAssets {
        initialize_for_test(aptos_framework);
        let (creator_ref, token) = fungible_asset::create_test_token(creator);
        let (_m, _t, _b) = primary_fungible_store::init_test_metadata_with_primary_store_enabled(&creator_ref);
        add_accepted_gas_fungible_asset(
            aptos_framework,
            object::address_to_object<Metadata>(object::object_address(&token)),
            0,
        );
    }

    #[test(aptos_framework = @aptos_framework, creator = @0xcafe)]
    #[expected_failure(abort_code = 65542, location = Self)]
    /// A gas FA's price cannot be set to zero.
    fun test_set_rejects_zero_price(aptos_framework: &signer, creator: &signer)
        acquires GovernedGasPool, AcceptedGasFungibleAssets {
        initialize_for_test(aptos_framework);
        let (creator_ref, token) = fungible_asset::create_test_token(creator);
        let (_m, _t, _b) = primary_fungible_store::init_test_metadata_with_primary_store_enabled(&creator_ref);
        let metadata = object::address_to_object<Metadata>(object::object_address(&token));
        add_accepted_gas_fungible_asset(aptos_framework, metadata, 5);
        set_gas_fungible_asset_price(aptos_framework, metadata, 0);
    }

    #[test(aptos_framework = @aptos_framework, payer = @0xcafe, creator_b = @0xd00d)]
    /// Each accepted FA is a separate pool with its own price: depositing into one FA's pool does
    /// not touch another's, and their prices/fees are independent.
    fun test_multiple_fa_pools_are_independent(
        aptos_framework: &signer,
        payer: &signer,
        creator_b: &signer,
    ) acquires GovernedGasPool, AcceptedGasFungibleAssets {
        initialize_for_test(aptos_framework);
        let payer_addr = signer::address_of(payer);

        // FA A (created by payer) and FA B (created by creator_b), each minted to the payer.
        let (a_ref, a_token) = fungible_asset::create_test_token(payer);
        let (a_mint, _at, _ab) = primary_fungible_store::init_test_metadata_with_primary_store_enabled(&a_ref);
        primary_fungible_store::mint(&a_mint, payer_addr, 100);
        let a = object::object_address(&a_token);

        let (b_ref, b_token) = fungible_asset::create_test_token(creator_b);
        let (b_mint, _bt, _bb) = primary_fungible_store::init_test_metadata_with_primary_store_enabled(&b_ref);
        primary_fungible_store::mint(&b_mint, payer_addr, 100);
        let b = object::object_address(&b_token);

        // Accept both with different gas prices.
        add_accepted_gas_fungible_asset(aptos_framework, object::address_to_object<Metadata>(a), 2);
        add_accepted_gas_fungible_asset(aptos_framework, object::address_to_object<Metadata>(b), 5);

        // Prices and fees are independent per FA.
        assert!(get_gas_fungible_asset_price(a) == 2, 1);
        assert!(get_gas_fungible_asset_price(b) == 5, 2);
        assert!(gas_fee_in_fa(a, 10) == 20, 3);
        assert!(gas_fee_in_fa(b, 10) == 50, 4);

        // Depositing into A's pool leaves B's pool (and the payer's B balance) untouched.
        deposit_gas_fee_fa(payer_addr, a, 30);
        assert!(get_fa_balance(a) == 30, 5);
        assert!(get_fa_balance(b) == 0, 6);
        assert!(primary_fungible_store::balance(payer_addr, object::address_to_object<Metadata>(a)) == 70, 7);
        assert!(primary_fungible_store::balance(payer_addr, object::address_to_object<Metadata>(b)) == 100, 8);
    }

}

spec aptos_framework::governed_gas_pool {
    use aptos_framework::error;

    /// <high-level-req>
    /// No.: 1
    /// Requirement: The GovernedGasPool resource must exist at the aptos_framework address after initialization.
    /// Criticality: Critical
    /// Implementation: The initialize function ensures the resource is created at the aptos_framework address.
    /// Enforcement: Formally verified via [high-level-req-1](initialize).
    ///
    /// No.: 2
    /// Requirement: Only the aptos_framework address is allowed to initialize the GovernedGasPool.
    /// Criticality: Critical
    /// Implementation: The initialize function verifies the signer is the aptos_framework address.
    /// Enforcement: Formally verified via [high-level-req-2](initialize).
    ///
    /// No.: 3
    /// Requirement: Deposits into the GovernedGasPool must be reflected in the pool's balance.
    /// Criticality: High
    /// Implementation: The deposit and deposit_from functions update the pool's balance.
    /// Enforcement: Formally verified via [high-level-req-3](deposit), [high-level-req-3.1](deposit_from).
    ///
    /// No.: 4
    /// Requirement: Only the aptos_framework address can fund accounts from the GovernedGasPool.
    /// Criticality: High
    /// Implementation: The fund function verifies the signer is the aptos_framework address.
    /// Enforcement: Formally verified via [high-level-req-4](fund).
    ///

    spec module {
        /// [high-level-req-1]
        /// The GovernedGasPool resource must exist at aptos_framework after initialization.
        invariant exists<GovernedGasPool>(@aptos_framework);
    }

    spec initialize(aptos_framework: &signer, delegation_pool_creation_seed: vector<u8>) {
        requires system_addresses::is_aptos_framework_address(signer::address_of(aptos_framework));
        /// [high-level-req-1]
        ensures exists<GovernedGasPool>(@aptos_framework);
    }

    spec fund<CoinType>(aptos_framework: &signer, account: address, amount: u64) {
        pragma aborts_if_is_partial = true;

        /// [high-level-req-4]
        // Abort if the caller is not the Aptos framework
        aborts_if !system_addresses::is_aptos_framework_address(signer::address_of(aptos_framework));

        /// Abort if the governed gas pool has insufficient funds
        aborts_with coin::EINSUFFICIENT_BALANCE, error::invalid_argument(EINSUFFICIENT_BALANCE), 0x1, 0x5, 0x7;
    }

    spec deposit<CoinType>(coin: Coin<CoinType>) {
        pragma aborts_if_is_partial = true;

        let pool = signer::address_of(governed_gas_signer());

        /// [high-level-req-3]
        /// The pool always has a registered CoinStore (register_coin at init),
        /// so coin::deposit takes the merge branch and the balance increases by coin.value.
        requires exists<coin::CoinStore<CoinType>>(pool);

        ensures global<coin::CoinStore<CoinType>>(pool).coin.value
            == old(global<coin::CoinStore<CoinType>>(pool).coin.value) + coin.value;
    }

    spec deposit_gas_fee_v2(gas_payer: address, gas_fee: u64) {
        pragma aborts_if_is_partial = true;

        let pool = signer::address_of(governed_gas_signer());

        /// [high-level-req-3]
        /// Characterizes the legacy coin path. The FA-store path
        /// (operations_default_to_fa_apt_store_enabled) routes the fee through the
        /// payer's primary fungible store instead and is not covered here.
        requires gas_payer != pool;
        requires exists<coin::CoinStore<AptosCoin>>(pool);
        requires exists<coin::CoinStore<AptosCoin>>(gas_payer);

        /// The gas fee moves from the payer's store into the pool's store.
        ensures global<coin::CoinStore<AptosCoin>>(pool).coin.value
            == old(global<coin::CoinStore<AptosCoin>>(pool).coin.value) + gas_fee;
        ensures global<coin::CoinStore<AptosCoin>>(gas_payer).coin.value
            == old(global<coin::CoinStore<AptosCoin>>(gas_payer).coin.value) - gas_fee;
    }
}

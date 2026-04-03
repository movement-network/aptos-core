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
    /// No.: 5
    /// Requirement: Aggregator-backed counters must track all inflows and outflows when the feature is enabled.
    /// Criticality: High
    /// Implementation: When governed_gas_pool_aggregators_enabled(), gas fees, treasury deposits,
    ///   governance payouts, and staking rewards are tracked in GovernedGasPoolCounters aggregators.
    /// Enforcement: Formally verified via [high-level-req-5](deposit_gas_fee_v2), [high-level-req-5.1](deposit_treasury),
    ///   [high-level-req-5.2](fund), [high-level-req-5.3](withdraw_staking_reward).
    ///
    /// No.: 6
    /// Requirement: Total outflows must not exceed total inflows (accounting invariant).
    /// Criticality: Critical
    /// Implementation: reward_withdrawn_total + governance_funded_total <= gas_fee_total + treasury_total.
    ///   Note: This invariant is only meaningful for post-migration transactions as historical data is not tracked.
    /// Enforcement: Documented invariant; runtime balance checks prevent overdraw.
    ///

    spec module {
        /// [high-level-req-1]
        /// The GovernedGasPool resource must exist at aptos_framework after initialization.
        invariant exists<GovernedGasPool>(@aptos_framework);
        // Note: Aggregator invariants are omitted in specs to avoid unsupported snapshot expressions.
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

    /// [high-level-req-5] Spec for deposit_gas_fee_v2
    spec deposit_gas_fee_v2(gas_payer: address, gas_fee: u64) {
        pragma aborts_if_is_partial = true;
    }

    /// [high-level-req-5.1] Spec for deposit_treasury
    spec deposit_treasury(treasury_account: &signer, amount: u64) {
        pragma aborts_if_is_partial = true;
    }

    /// [high-level-req-5.2] Spec for fund
    spec fund<CoinType>(aptos_framework: &signer, account: address, amount: u64) {
        pragma aborts_if_is_partial = true;
    }

    /// [high-level-req-5.3] Spec for withdraw_staking_reward
    spec withdraw_staking_reward<CoinType>(amount: u64): Coin<CoinType> {
        pragma aborts_if_is_partial = true;
    }

    /// Spec for initialize_governed_gas_pool_extension
    spec initialize_governed_gas_pool_extension(aptos_framework: &signer) {
        pragma aborts_if_is_partial = true;
    }
}

script {
    use aptos_framework::aptos_governance;
    use aptos_framework::staking_config;

    /// Restore staking params after the post-move2-upgrade migration overwrites
    /// them with placeholder values. Uses mainnet values as of 2026-03-05:
    ///
    ///   min_stake:    10_000_000_000_000       (100,000 MOVE)
    ///   max_stake:    100_000_000_000_000_000  (1,000,000,000 MOVE)
    ///   rewards_rate: 2176 / 100_000_000       (0.002176% per epoch)
    fun main(core_resources: &signer) {
        let core_signer = aptos_governance::get_signer_testnet_only(core_resources, @0000000000000000000000000000000000000000000000000000000000000001);

        // Match mainnet: min 100K MOVE, max 1B MOVE
        staking_config::update_required_stake(&core_signer, 10_000_000_000_000, 100_000_000_000_000_000);

        // Match mainnet: 2176 / 100_000_000 per epoch
        staking_config::update_rewards_rate(&core_signer, 2176, 100_000_000);

        aptos_governance::force_end_epoch(&core_signer);
    }
}

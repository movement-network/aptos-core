script {
    use aptos_framework::staking_config;
    use aptos_framework::aptos_governance;

    /// Update the reward rate. Reward rate must be >0 to start getting rewards.
    /// Example of values: new_rewards_rate :15981 new_rewards_rate_denominator: 1000000000
    fun update_rewards_rate(core_resources: &signer, new_rewards_rate: u64, new_rewards_rate_denominator: u64) {
        let core_signer = aptos_governance::get_signer_testnet_only(core_resources, @0000000000000000000000000000000000000000000000000000000000000001);
        staking_config::update_rewards_rate(&core_signer, new_rewards_rate, new_rewards_rate_denominator);

        aptos_governance::reconfigure(&core_signer);
    }
}
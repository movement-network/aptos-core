script {
    use aptos_framework::aptos_governance;
    use aptos_framework::system_addresses;

    fun one_minute_proposal(aptos_framework: &signer) {
        // Must be the 0x1 framework signer
        system_addresses::assert_aptos_framework(aptos_framework);

        let min_voting_threshold = aptos_governance::get_min_voting_threshold();
        let required_proposer_stake = aptos_governance::get_required_proposer_stake();

        aptos_governance::update_governance_config(
            aptos_framework,
            min_voting_threshold,
            required_proposer_stake,
            /* voting_duration_secs = */ 60,
        );
    }
}

script {
    use std::error;
    use std::vector;
    use aptos_framework::aptos_governance;
    use aptos_framework::chain_id;
    use aptos_framework::stake;
    use aptos_framework::validator_consensus_info;

    const EWRONG_CHAIN: u64 = 1;
    const EUNEXPECTED_VALIDATORS: u64 = 2;
    const VALIDATOR_STATUS_ACTIVE: u64 = 2;

    // Run only AFTER publishing the framework containing the join and pending-queue guards.
    // Supply independently verified pool addresses; never derive the approved list at execution time.
    fun main(
        core_resources: &signer,
        expected_chain_id: u8,
        pool_1: address,
        pool_2: address,
        pool_3: address,
        pool_4: address,
    ) {
        assert!(chain_id::get() == expected_chain_id, error::invalid_argument(EWRONG_CHAIN));
        let expected_pools = vector[pool_1, pool_2, pool_3, pool_4];
        let current = stake::cur_validator_consensus_infos();
        assert!(vector::length(&current) == 4, error::invalid_state(EUNEXPECTED_VALIDATORS));
        vector::for_each_ref(&current, |validator| {
            let pool = validator_consensus_info::get_addr(validator);
            assert!(vector::contains(&expected_pools, &pool), error::invalid_state(EUNEXPECTED_VALIDATORS));
            assert!(stake::get_validator_state(pool) == VALIDATOR_STATUS_ACTIVE, error::invalid_state(EUNEXPECTED_VALIDATORS));
        });

        // Uses the same core-resources authority as the existing Movement migration scripts.
        let framework = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        // This call also rejects any pending joiner outside expected_pools. All checks and
        // the ACL write commit together, so a join racing activation makes this transaction abort.
        stake::configure_allowed_validators(&framework, expected_pools);
    }
}

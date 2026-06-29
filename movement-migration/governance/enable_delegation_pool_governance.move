script {
    use aptos_framework::aptos_governance;
    use aptos_framework::delegation_pool;
    use std::vector;

    const MIN_RESOLVABLE_VOTING_THRESHOLD_OCTAS: u128 = 20000000000000000;

    fun main(proposal_id: u64) {
        let framework_signer = aptos_governance::resolve_multi_step_proposal(
            proposal_id,
            @aptos_framework,
            vector::empty<u8>(),
        );

        aptos_governance::toggle_features(&framework_signer, vector[17, 21], vector::empty<u64>());
        aptos_governance::initialize_partial_voting_if_needed(&framework_signer);
        aptos_governance::update_governance_config(
            &framework_signer,
            MIN_RESOLVABLE_VOTING_THRESHOLD_OCTAS,
            aptos_governance::get_required_proposer_stake(),
            aptos_governance::get_voting_duration_secs(),
        );

        let pool_addresses = vector[
            @0x1ef54ef84e7fb389095f83021755dd71bb51cbfbc8124a4349ec619f9d901f1f,
            @0x830bfd0cd58b06dc938d409b6f3bc8ee97818ffcf9b32d714c068454afb644c7,
            @0x39f116ee9ef048895bff51a5ce62229d153a6fe855798fa75810fd2b85008b9c,
            @0xccba2d929183a642f64d10d27bae0947c112ed7f5427ca3c64a1f0dd0b4b76ea,
        ];
        vector::for_each(pool_addresses, |pool_address| {
            delegation_pool::enable_partial_governance_voting_if_needed(pool_address);
        });

        aptos_governance::force_end_epoch(&framework_signer);
    }
}

// Core-resource-signer script: enable feature 226 (TRANSACTION_PERMISSIONS)
// so the VM starts enforcing the transaction permission table, and force an
// epoch change so it takes effect immediately.
//
// Run initialize_transaction_permissions.move first and populate any initial
// rules before enabling; an empty table changes nothing (no match = allow).
script {
    use aptos_framework::aptos_governance;
    use std::features;
    use std::vector;

    fun main(core_resources: &signer) {
        let framework_signer = aptos_governance::get_signer_testnet_only(
            core_resources,
            @aptos_framework,
        );
        features::change_feature_flags_for_next_epoch(
            &framework_signer,
            vector[226], // TRANSACTION_PERMISSIONS
            vector::empty<u64>(),
        );
        aptos_governance::force_end_epoch(&framework_signer);
    }
}

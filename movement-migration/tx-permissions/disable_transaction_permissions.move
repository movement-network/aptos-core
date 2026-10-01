// Core-resource-signer script: emergency off switch. Disables feature 226
// (TRANSACTION_PERMISSIONS) so the VM stops consulting the rule table, and
// forces an epoch change so it takes effect immediately. The table itself is
// left intact for a later re-enable.
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
            vector::empty<u64>(),
            vector[226], // TRANSACTION_PERMISSIONS
        );
        aptos_governance::force_end_epoch(&framework_signer);
    }
}

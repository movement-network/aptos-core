// One-time core-resource-signer migration script: create the empty
// transaction permission table under @aptos_framework on a chain that
// upgraded past genesis. Idempotent; safe to re-run.
//
// This only creates the resource. Enforcement stays off until feature 226
// (TRANSACTION_PERMISSIONS) is enabled via enable_transaction_permissions.move.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::transaction_permissions;

    fun main(core_resources: &signer) {
        let framework_signer = aptos_governance::get_signer_testnet_only(
            core_resources,
            @aptos_framework,
        );
        transaction_permissions::initialize_extension(&framework_signer);
    }
}

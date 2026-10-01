// Core-resource-signer script: remove the rule at `index` from the
// transaction permission table; later rules shift down by one. List the
// table first (see the runbook) to confirm the index. Takes effect
// immediately; no epoch change needed.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::transaction_permissions;

    fun main(core_resources: &signer, index: u64) {
        let framework_signer = aptos_governance::get_signer_testnet_only(
            core_resources,
            @aptos_framework,
        );
        transaction_permissions::remove_rule(&framework_signer, index);
    }
}

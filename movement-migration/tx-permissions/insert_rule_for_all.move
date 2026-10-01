// Core-resource-signer script: insert a rule matching ALL senders into the
// transaction permission table at `index` (0 = evaluated first; an index
// equal to the current table length appends). Takes effect immediately; no
// epoch change needed.
//
// kind: 0 = deploy, 1 = upgrade, 2 = script, 3 = other
//
// Note: a wildcard deny cannot lock out administration. Approved governance
// scripts, framework-reserved senders, the core-resources account, and
// 0x1::aptos_governance entry functions are exempt from enforcement by the VM.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::transaction_permissions;

    fun main(core_resources: &signer, index: u64, kind: u8, allow: bool) {
        let framework_signer = aptos_governance::get_signer_testnet_only(
            core_resources,
            @aptos_framework,
        );
        transaction_permissions::insert_rule_for_all(&framework_signer, index, kind, allow);
    }
}

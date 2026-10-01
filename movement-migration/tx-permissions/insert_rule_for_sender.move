// Core-resource-signer script: insert a rule matching one sender into the
// transaction permission table at `index` (0 = evaluated first; an index
// equal to the current table length appends). Takes effect immediately; no
// epoch change needed.
//
// kind: 0 = deploy, 1 = upgrade, 2 = script, 3 = other
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::transaction_permissions;

    fun main(core_resources: &signer, index: u64, sender: address, kind: u8, allow: bool) {
        let framework_signer = aptos_governance::get_signer_testnet_only(
            core_resources,
            @aptos_framework,
        );
        transaction_permissions::insert_rule_for_sender(
            &framework_signer,
            index,
            sender,
            kind,
            allow,
        );
    }
}

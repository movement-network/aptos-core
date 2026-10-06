// Core-resource-signer script: insert a module rule matching ALL senders
// into the transaction permission table at `index` (0 = evaluated first). An
// empty module_name matches every module at module_addr. Takes effect
// immediately.
//
// kind: 0 = deploy, 1 = upgrade (pattern matches the published modules),
//       2 = script, 3 = other (pattern matches every module the transaction
//       loads during execution).
// Special addresses (0x0..0xf) cannot be targeted; they are always exempt.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::transaction_permissions;
    use std::string::String;

    fun main(
        core_resources: &signer,
        index: u64,
        kind: u8,
        module_addr: address,
        module_name: String,
        allow: bool,
    ) {
        let framework_signer = aptos_governance::get_signer_testnet_only(
            core_resources,
            @aptos_framework,
        );
        transaction_permissions::insert_module_rule_for_all(
            &framework_signer,
            index,
            kind,
            module_addr,
            module_name,
            allow,
        );
    }
}

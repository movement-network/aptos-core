// Designates the chain-auditor admin via governance. Sender must be the core
// resources account (localnet: key in <test-dir>/mint.key). Pairs with the
// subsequent `confidential_asset::set_chain_auditor` entry call signed by the
// admin itself.
script {
    use aptos_experimental::confidential_asset;
    use aptos_framework::aptos_governance;

    fun main(core_resources: &signer, new_admin: address) {
        let core_signer = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        let framework_signer = &core_signer;
        confidential_asset::set_chain_auditor_admin(framework_signer, new_admin);
    }
}

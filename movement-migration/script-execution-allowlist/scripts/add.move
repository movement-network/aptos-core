// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

/// Run with the core-resources signer to add one standalone-script sender.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::script_execution_allowlist;

    fun main(core_resources: &signer, sender: address) {
        let framework_signer = aptos_governance::get_signer_testnet_only(core_resources, @aptos_framework);
        script_execution_allowlist::add(&framework_signer, sender);
    }
}

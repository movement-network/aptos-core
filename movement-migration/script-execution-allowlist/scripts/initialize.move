// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

/// Run with the core-resources signer before configuring standalone-script senders.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::script_execution_allowlist;

    fun main(core_resources: &signer) {
        let framework_signer = aptos_governance::get_signer_testnet_only(core_resources, @aptos_framework);
        script_execution_allowlist::initialize(&framework_signer);
    }
}

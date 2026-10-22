// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

script {
    use aptos_framework::aptos_governance;
    use aptos_framework::code;

    /// Disables publishing enforcement without modifying the saved list.
    fun main(core_resources: &signer) {
        let framework_signer = aptos_governance::get_signer_testnet_only(
            core_resources,
            @aptos_framework,
        );
        code::disable_publish_allowlist(&framework_signer);
    }
}

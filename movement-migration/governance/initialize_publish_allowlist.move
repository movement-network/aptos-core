// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

script {
    use aptos_framework::aptos_governance;
    use aptos_framework::code;

    fun main(core_resources: &signer) {
        let framework_signer = aptos_governance::get_signer_testnet_only(
            core_resources,
            @aptos_framework,
        );
        code::initialize_publish_allowlist(&framework_signer);
    }
}

// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

// Enable after adding the core-resources transaction sender to the allowlist.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::script_execution_allowlist;
    use std::signer;

    const EADMIN_NOT_ALLOWED: u64 = 2;

    fun main(core_resources: &signer) {
        let framework_signer = aptos_governance::get_signer_testnet_only(core_resources, @aptos_framework);
        assert!(script_execution_allowlist::is_allowed(signer::address_of(core_resources)), EADMIN_NOT_ALLOWED);
        script_execution_allowlist::enable(&framework_signer);
    }
}

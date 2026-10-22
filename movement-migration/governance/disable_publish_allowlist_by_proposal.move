// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

// Execute only after this exact script has passed governance.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::code;

    fun main(proposal_id: u64) {
        let framework = aptos_governance::resolve(proposal_id, @aptos_framework);
        code::disable_publish_allowlist(&framework);
    }
}

// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

// Execute only after this exact script has passed governance.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::script_execution_allowlist;

    fun main(proposal_id: u64) {
        let framework = aptos_governance::resolve(proposal_id, @aptos_framework);
        script_execution_allowlist::disable(&framework);
    }
}

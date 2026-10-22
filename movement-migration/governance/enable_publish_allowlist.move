// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

script {
    use aptos_framework::aptos_governance;
    use aptos_framework::code;

    const EUPGRADE_SENDER_NOT_ALLOWED: u64 = 1;
    const ERECOVERY_SENDER_NOT_ALLOWED: u64 = 2;
    const ESAME_UPGRADE_AND_RECOVERY: u64 = 3;

    // Membership is necessary; separately rehearse credential control and framework authority.
    fun main(core_resources: &signer, upgrade_sender: address, recovery_sender: address) {
        let framework = aptos_governance::get_signer_testnet_only(core_resources, @aptos_framework);
        assert!(upgrade_sender != recovery_sender, ESAME_UPGRADE_AND_RECOVERY);
        assert!(code::is_publish_allowlisted(upgrade_sender), EUPGRADE_SENDER_NOT_ALLOWED);
        assert!(code::is_publish_allowlisted(recovery_sender), ERECOVERY_SENDER_NOT_ALLOWED);
        code::enable_publish_allowlist(&framework);
    }
}

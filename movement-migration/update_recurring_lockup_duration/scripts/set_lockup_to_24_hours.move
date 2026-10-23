// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

script {
    use aptos_framework::aptos_governance;
    use aptos_framework::block;
    use aptos_framework::staking_config;

    const EXPECTED_LOCKUP_SECS: u64 = 14 * 24 * 60 * 60;
    const NEW_LOCKUP_SECS: u64 = 24 * 60 * 60;

    const EUNEXPECTED_LOCKUP: u64 = 1;
    const EEPOCH_TOO_LONG: u64 = 2;

    fun set_lockup_to_24_hours(core_resources: &signer) {
        let framework_signer = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        let config = staking_config::get();
        assert!(
            staking_config::get_recurring_lockup_duration(&config) == EXPECTED_LOCKUP_SECS,
            EUNEXPECTED_LOCKUP,
        );
        assert!(block::get_epoch_interval_secs() <= NEW_LOCKUP_SECS, EEPOCH_TOO_LONG);

        // Existing StakePool.locked_until_secs values remain in force. The new duration
        // applies when a pool next establishes or renews its lockup.
        staking_config::update_recurring_lockup_duration_secs(&framework_signer, NEW_LOCKUP_SECS);
    }
}

script {
    use aptos_framework::aptos_governance;
    use aptos_framework::block;

    // for new_epoch_duration 200_000_000 indicate 200secs.
    fun change_epoch_duration(core_resources: &signer, new_epoch_duration: u64) {
        let core_signer = aptos_governance::get_signer_testnet_only(core_resources, @0000000000000000000000000000000000000000000000000000000000000001);
        block::update_epoch_interval_microsecs(&core_signer, new_epoch_duration);
    }
}

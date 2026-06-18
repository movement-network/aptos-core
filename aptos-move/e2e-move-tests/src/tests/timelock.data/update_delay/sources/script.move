script {
    use aptos_framework::timelock;

    /// Resolves a timelock transaction and uses the resulting signer to update the
    /// timelock account's minimum delay.
    fun main(
        executor: &signer,
        timelock_addr: address,
        proposal_hash: vector<u8>,
        new_min_num_seconds_execute: u64,
    ) {
        let timelock_signer = timelock::resolve(executor, timelock_addr, proposal_hash);
        timelock::update_min_num_seconds_execute(&timelock_signer, new_min_num_seconds_execute);
    }
}

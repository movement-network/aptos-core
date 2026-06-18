script {
    use aptos_framework::timelock;

    /// Resolves a timelock transaction and uses the resulting signer to remove a single
    /// executor from the timelock account.
    fun main(
        executor: &signer,
        timelock_addr: address,
        proposal_hash: vector<u8>,
        target: address,
    ) {
        let timelock_signer = timelock::resolve(executor, timelock_addr, proposal_hash);
        timelock::remove_executors(&timelock_signer, vector[target]);
    }
}

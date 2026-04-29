script {
    use aptos_framework::timelock;

    /// Resolves a timelock transaction and uses the resulting signer to remove a single
    /// creator from the timelock account.
    fun main(
        executor: &signer,
        timelock_addr: address,
        transaction_hash: vector<u8>,
        target: address,
    ) {
        let timelock_signer = timelock::resolve(executor, timelock_addr, transaction_hash);
        timelock::remove_creators(&timelock_signer, vector[target]);
    }
}

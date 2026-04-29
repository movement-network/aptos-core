script {
    use aptos_framework::timelock;

    /// Resolves a timelock transaction and discards the returned signer. Used as a generic
    /// "did the resolve succeed" probe in e2e tests.
    fun main(executor: &signer, timelock_addr: address, transaction_hash: vector<u8>) {
        let _ = timelock::resolve(executor, timelock_addr, transaction_hash);
    }
}

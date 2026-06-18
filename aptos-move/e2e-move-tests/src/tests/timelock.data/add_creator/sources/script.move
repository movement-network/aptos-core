script {
    use aptos_framework::timelock;

    /// Resolves a timelock transaction and uses the resulting signer to add a single
    /// creator to the timelock account.
    fun main(
        executor: &signer,
        timelock_addr: address,
        proposal_hash: vector<u8>,
        new_creator: address,
    ) {
        let timelock_signer = timelock::resolve(executor, timelock_addr, proposal_hash);
        timelock::add_creators(&timelock_signer, vector[new_creator]);
    }
}

script {
    use aptos_framework::timelock;

    /// Self-contained resolution script (test fixture): resolves the timelock and adds a single,
    /// BAKED-IN executor address (`@0xA401`). The new executor is a literal in the bytecode, so the
    /// proposal's execution hash commits to it and the submitter cannot substitute a different
    /// address. Only non-privileged routing values are passed as arguments; see `add_creator` for
    /// why (and where the fully self-contained shape is exercised).
    fun main(executor: &signer, timelock_addr: address, proposal_hash: vector<u8>) {
        let timelock_signer = timelock::resolve(executor, timelock_addr, proposal_hash);
        timelock::add_executors(&timelock_signer, vector[@0xA401]);
    }
}

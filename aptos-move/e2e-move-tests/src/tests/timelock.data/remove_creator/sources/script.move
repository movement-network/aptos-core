script {
    use aptos_framework::timelock;

    /// Self-contained resolution script (test fixture): resolves the timelock and removes a single,
    /// BAKED-IN creator address (`@0xA301`). The target is a literal in the bytecode, so the
    /// proposal's execution hash commits to it and the submitter cannot redirect the removal to a
    /// different creator. Only non-privileged routing values are passed as arguments; see
    /// `add_creator` for why (and where the fully self-contained shape is exercised).
    fun main(executor: &signer, timelock_addr: address, proposal_hash: vector<u8>) {
        let timelock_signer = timelock::resolve(executor, timelock_addr, proposal_hash);
        timelock::remove_creators(&timelock_signer, vector[@0xA301]);
    }
}

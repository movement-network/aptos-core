script {
    use aptos_framework::timelock;

    /// Self-contained resolution script (test fixture): resolves the timelock and sets the account's
    /// minimum delay to a BAKED-IN value (7200 seconds). The new delay is a literal in the bytecode,
    /// so the proposal's execution hash commits to it and the submitter cannot substitute a
    /// different value. Only non-privileged routing values are passed as arguments; see
    /// `add_creator` for why (and where the fully self-contained shape is exercised).
    fun main(executor: &signer, timelock_addr: address, proposal_hash: vector<u8>) {
        let timelock_signer = timelock::resolve(executor, timelock_addr, proposal_hash);
        timelock::update_min_num_seconds_execute(&timelock_signer, 7200);
    }
}

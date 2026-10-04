script {
    use aptos_framework::timelock;

    /// Self-contained resolution script (test fixture): resolves the timelock and adds a single,
    /// BAKED-IN creator address (`@0xA201`). Because the new creator is a literal in the bytecode,
    /// the proposal's execution hash commits to it and the submitter cannot substitute a different
    /// address. This is the pattern every production resolution script must follow for its
    /// privileged values. Only the non-privileged routing values (the executor signer, the timelock
    /// address, and the proposal hash) are passed as arguments — these precompiled fixtures cannot
    /// bake per-test resource addresses; the fully self-contained `fun main(executor: &signer)`
    /// shape (with the address and salt baked in too) is exercised by the smoke tests.
    fun main(executor: &signer, timelock_addr: address, proposal_hash: vector<u8>) {
        let timelock_signer = timelock::resolve(executor, timelock_addr, proposal_hash);
        timelock::add_creators(&timelock_signer, vector[@0xA201]);
    }
}

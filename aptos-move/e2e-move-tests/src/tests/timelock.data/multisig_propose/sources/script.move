script {
    use aptos_framework::multisig_account;
    use aptos_framework::timelock;

    /// Resolves a timelock transaction and uses the resulting signer to propose a
    /// transaction into a multisig account, demonstrating the timelock → multisig flow.
    ///
    /// NOTE (test fixture): this fixture takes `multisig_addr`/`multisig_payload` as arguments only
    /// because they are per-test runtime values a precompiled fixture cannot bake. A production
    /// resolution script MUST bake these privileged values into the bytecode (the execution hash
    /// does not cover arguments). The residual risk of a substituted target/payload here is bounded
    /// by the downstream multisig's own n-of-m approval gate, which still governs execution — but
    /// do not rely on that; bake the values.
    fun main(
        executor: &signer,
        timelock_addr: address,
        proposal_hash: vector<u8>,
        multisig_addr: address,
        multisig_payload: vector<u8>,
    ) {
        let timelock_signer = timelock::resolve(executor, timelock_addr, proposal_hash);
        multisig_account::create_transaction(&timelock_signer, multisig_addr, multisig_payload);
    }
}

script {
    use aptos_framework::multisig_account;
    use aptos_framework::timelock;

    /// Resolves a timelock transaction and uses the resulting signer to propose a
    /// transaction into a multisig account, demonstrating the timelock → multisig flow.
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

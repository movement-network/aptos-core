// MSL Spec Template: Confidential Transfer
// Complete, compilable spec template for confidential_transfer_internal
spec aptos_experimental::confidential_asset {
    spec fun sum_balance_chunks(balance: vector<u8>): u256 {
        if (len(balance) == 0) { 0 }
        else { chunk_value(balance[0]) + sum_balance_chunks(slice(balance, 1, len(balance))) }
    }
    spec fun chunk_value(chunk: u8): u256;
    spec confidential_transfer_internal(
        sender_store: &mut ConfidentialAssetStore,
        recipient_store: &mut ConfidentialAssetStore,
        proof: &vector<u8>,
        amount: u64
    ) {
        pragma aborts_if_is_strict;
        aborts_if sender_store.frozen with ETOKEN_IS_FROZEN;
        aborts_if recipient_store.frozen with ETOKEN_IS_FROZEN;
        let sender_old_sum = sum_balance_chunks(old(sender_store.pending_balance));
        let sender_new_sum = sum_balance_chunks(sender_store.pending_balance);
        let recipient_old_sum = sum_balance_chunks(old(recipient_store.pending_balance));
        let recipient_new_sum = sum_balance_chunks(recipient_store.pending_balance);
        ensures sender_new_sum == sender_old_sum - amount;
        ensures recipient_new_sum == recipient_old_sum + amount;
        ensures len(sender_store.pending_balance) == len(old(sender_store.pending_balance));
        ensures sender_store.encryption_pubkey == old(sender_store.encryption_pubkey);
        modifies global<ConfidentialAssetStore>(sender_addr);
    }
}

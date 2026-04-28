// Complete MSL Spec: rotate_encryption_key_internal

spec aptos_experimental::confidential_asset {
    
    spec rotate_encryption_key_internal(
        store: &mut ConfidentialAssetStore,
        new_pubkey: vector<u8>,
        rotation_proof: &vector<u8>,
        re_encrypted_balance: vector<u8>
    ) {
        pragma aborts_if_is_strict;
        
        requires !store.frozen;
        requires len(new_pubkey) == 32;
        requires len(*rotation_proof) >= 64;
        
        aborts_if store.frozen with ETOKEN_IS_FROZEN;
        aborts_if !verify_rotation_proof(
            rotation_proof,
            &store.encryption_pubkey,
            &new_pubkey,
            &store.pending_balance,
            &re_encrypted_balance
        ) with ESIGMA_PROTOCOL_VERIFY_FAILED;
        
        // Balance sum preserved (under new encryption)
        ensures sum_balance_chunks(store.pending_balance) == 
                sum_balance_chunks(old(store.pending_balance));
        
        // Key updated
        ensures store.encryption_pubkey == new_pubkey;
        
        // Balance re-encrypted
        ensures store.pending_balance == re_encrypted_balance;
        
        // Frame conditions
        ensures store.frozen == old(store.frozen);
        ensures store.actual_balance == old(store.actual_balance);
        
        modifies store;
    }
    
    spec verify_rotation_proof(
        proof: &vector<u8>,
        old_pubkey: &vector<u8>,
        new_pubkey: &vector<u8>,
        old_balance: &vector<u8>,
        new_balance: &vector<u8>
    ): bool {
        pragma opaque;
    }
}

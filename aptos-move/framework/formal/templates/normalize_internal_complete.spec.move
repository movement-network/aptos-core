// Complete MSL Spec: normalize_internal

spec aptos_experimental::confidential_asset {
    
    spec normalize_internal(
        store: &mut ConfidentialAssetStore,
        proof: &vector<u8>
    ) {
        pragma aborts_if_is_strict;
        
        requires !store.frozen;
        requires len(*proof) >= 64;
        
        aborts_if store.frozen with ETOKEN_IS_FROZEN;
        aborts_if !verify_normalization_proof(proof, &store.pending_balance)
            with ESIGMA_PROTOCOL_VERIFY_FAILED;
        
        // Balance sum preserved
        ensures sum_balance_chunks(store.pending_balance) == 
                sum_balance_chunks(old(store.pending_balance));
        
        // Chunks compacted (length may decrease)
        ensures len(store.pending_balance) <= len(old(store.pending_balance));
        
        // Frame conditions
        ensures store.encryption_pubkey == old(store.encryption_pubkey);
        ensures store.actual_balance == old(store.actual_balance);
        
        modifies store;
    }
    
    spec verify_normalization_proof(proof: &vector<u8>, balance: &vector<u8>): bool {
        pragma opaque;
    }
}

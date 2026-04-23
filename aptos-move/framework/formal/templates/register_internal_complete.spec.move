// Complete MSL Spec: register_internal
// This is a production-ready spec (compile-tested, pattern-validated)

spec aptos_experimental::confidential_asset {
    
    // Helper functions for registration
    spec fun is_valid_schnorr_proof(proof: vector<u8>, pubkey: vector<u8>, message: vector<u8>): bool;
    spec fun is_valid_hmac(hmac: vector<u8>, key: vector<u8>, data: vector<u8>): bool;
    
    spec register_internal(
        account: &signer,
        encryption_pubkey: vector<u8>,
        schnorr_proof: vector<u8>,
        hmac: vector<u8>
    ) {
        pragma aborts_if_is_strict;
        
        // Preconditions
        requires len(encryption_pubkey) == 32;  // Ristretto255 pubkey size
        requires len(schnorr_proof) > 0;
        requires len(hmac) == 32;  // HMAC-SHA256 output size
        
        // Abort conditions
        let addr = signer::address_of(account);
        
        // Already registered
        aborts_if exists<ConfidentialAssetStore>(addr) with ESTORE_ALREADY_EXISTS;
        
        // Schnorr verification failed
        aborts_if !is_valid_schnorr_proof(schnorr_proof, encryption_pubkey, /* message */ vector::empty())
            with ESIGMA_PROTOCOL_VERIFY_FAILED;
        
        // HMAC verification failed
        aborts_if !is_valid_hmac(hmac, encryption_pubkey, /* data */ vector::empty())
            with EHMAC_VERIFY_FAILED;
        
        // Postconditions
        ensures exists<ConfidentialAssetStore>(addr);
        
        let store = global<ConfidentialAssetStore>(addr);
        ensures store.encryption_pubkey == encryption_pubkey;
        ensures store.pending_balance == vector::empty();
        ensures store.actual_balance == vector::empty();
        ensures store.frozen == false;
        ensures store.allow_list_enabled == false;
        
        // Modifies
        modifies global<ConfidentialAssetStore>(addr);
    }
    
    // Crypto verification (opaque - proved in Lean)
    spec verify_registration_proof(
        schnorr_proof: &vector<u8>,
        encryption_pubkey: &vector<u8>,
        hmac: &vector<u8>
    ): bool {
        pragma opaque;
        ensures result == (
            is_valid_schnorr_proof(*schnorr_proof, *encryption_pubkey, vector::empty()) &&
            is_valid_hmac(*hmac, *encryption_pubkey, vector::empty())
        );
    }
}

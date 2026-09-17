#[test_only]
module aptos_framework::ristretto255_twisted_elgamal_tests {
    use aptos_framework::ristretto255_twisted_elgamal::{
        Self as twisted_elgamal,
        generate_twisted_elgamal_keypair,
    };

    #[test]
    fun new_pubkey_from_bytes_rejects_identity() {
        // 32 zero bytes is the canonical compressed encoding of the Ristretto255
        // identity point. There is no scalar `sk` such that `sk^(-1) * H = identity`,
        // so identity cannot correspond to any keypair and must be rejected.
        let identity_bytes = x"0000000000000000000000000000000000000000000000000000000000000000";
        assert!(twisted_elgamal::new_pubkey_from_bytes(identity_bytes).is_none(), 1);
    }

    #[test]
    fun new_pubkey_from_bytes_accepts_real_key() {
        let (_sk, ek) = generate_twisted_elgamal_keypair();
        let round_trip = twisted_elgamal::new_pubkey_from_bytes(twisted_elgamal::pubkey_to_bytes(&ek));
        assert!(round_trip.is_some(), 2);

        let round_trip_pk = round_trip.extract();
        assert!(!twisted_elgamal::is_identity_pubkey(&round_trip_pk), 3);
        assert!(!twisted_elgamal::is_identity_pubkey(&ek), 4);
    }

    #[test]
    fun new_pubkey_from_bytes_rejects_non_canonical() {
        // 31 bytes is too short.
        let short = x"00000000000000000000000000000000000000000000000000000000000000";
        assert!(twisted_elgamal::new_pubkey_from_bytes(short).is_none(), 5);

        // All-ones is not a valid Ristretto255 encoding.
        let bogus = x"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
        assert!(twisted_elgamal::new_pubkey_from_bytes(bogus).is_none(), 6);
    }
}

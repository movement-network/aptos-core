#[test_only]
/// Goldens for `ristretto255_twisted_elgamal` that back the assumptions the
/// Lean formalization makes about Twisted ElGamal primitives:
///
/// * `pubkey_from_secret_key(dk)` satisfies `pubkey_to_point(pk) == dk⁻¹ · H`.
/// * `new_ciphertext_with_basepoint(v, r, pk)` decrypts with `dk` to `v · G`.
/// * `ciphertext_add` is homomorphic (on both value and randomness slots).
/// * `ciphertext_sub` is the inverse of `ciphertext_add`.
/// * `compress_ciphertext` / `decompress_ciphertext` round-trip.
/// * `new_ciphertext_from_bytes` / `ciphertext_to_bytes` round-trip.
/// * `pubkey_to_bytes` / `new_pubkey_from_bytes` round-trip.
module aptos_experimental::formal_goldens_twisted_elgamal {
    use std::option;
    use aptos_std::ristretto255;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;

    fun deterministic_dk(seed: u64): ristretto255::Scalar {
        ristretto255::new_scalar_from_u64(seed)
    }

    // pubkey = dk⁻¹ · H: decryption with dk should give `v · G`.
    #[test]
    fun golden_decryption_roundtrip() {
        let dk = deterministic_dk(42);
        let pk = twisted_elgamal::pubkey_from_secret_key(&dk).extract();

        let v = ristretto255::new_scalar_from_u64(123);
        let r = ristretto255::new_scalar_from_u64(456);

        let ct = twisted_elgamal::new_ciphertext_with_basepoint(&v, &r, &pk);
        let (c, d) = twisted_elgamal::ciphertext_as_points(&ct);

        // Decryption: `C - dk · D = v · G`.
        let decrypted = ristretto255::point_sub(c, &ristretto255::point_mul(d, &dk));
        let expected = ristretto255::basepoint_mul(&v);
        assert!(ristretto255::point_equals(&decrypted, &expected), 0);
    }

    // Decrypting `v = 0` yields the group identity (on the C - dk·D slot).
    #[test]
    fun golden_decryption_zero_value() {
        let dk = deterministic_dk(43);
        let pk = twisted_elgamal::pubkey_from_secret_key(&dk).extract();

        let v = ristretto255::new_scalar_from_u64(0);
        let r = ristretto255::new_scalar_from_u64(99);

        let ct = twisted_elgamal::new_ciphertext_with_basepoint(&v, &r, &pk);
        let (c, d) = twisted_elgamal::ciphertext_as_points(&ct);
        let decrypted = ristretto255::point_sub(c, &ristretto255::point_mul(d, &dk));
        let expected = ristretto255::basepoint_mul(&v);
        assert!(ristretto255::point_equals(&decrypted, &expected), 0);
    }

    // `ciphertext_add` is homomorphic: E(a) + E(b) decrypts to a + b.
    #[test]
    fun golden_ciphertext_add_homomorphic() {
        let dk = deterministic_dk(44);
        let pk = twisted_elgamal::pubkey_from_secret_key(&dk).extract();

        let va = ristretto255::new_scalar_from_u64(5);
        let vb = ristretto255::new_scalar_from_u64(7);
        let ra = ristretto255::new_scalar_from_u64(11);
        let rb = ristretto255::new_scalar_from_u64(13);

        let ea = twisted_elgamal::new_ciphertext_with_basepoint(&va, &ra, &pk);
        let eb = twisted_elgamal::new_ciphertext_with_basepoint(&vb, &rb, &pk);

        let ec = twisted_elgamal::ciphertext_add(&ea, &eb);
        let (c, d) = twisted_elgamal::ciphertext_as_points(&ec);
        let decrypted = ristretto255::point_sub(c, &ristretto255::point_mul(d, &dk));
        let expected = ristretto255::basepoint_mul(&ristretto255::scalar_add(&va, &vb));
        assert!(ristretto255::point_equals(&decrypted, &expected), 0);
    }

    // `ciphertext_sub` inverts `ciphertext_add`: (E(a) + E(b)) - E(b) == E(a) bytewise.
    #[test]
    fun golden_ciphertext_sub_inverts_add() {
        let dk = deterministic_dk(45);
        let pk = twisted_elgamal::pubkey_from_secret_key(&dk).extract();

        let va = ristretto255::new_scalar_from_u64(21);
        let vb = ristretto255::new_scalar_from_u64(17);
        let ra = ristretto255::new_scalar_from_u64(31);
        let rb = ristretto255::new_scalar_from_u64(37);

        let ea = twisted_elgamal::new_ciphertext_with_basepoint(&va, &ra, &pk);
        let eb = twisted_elgamal::new_ciphertext_with_basepoint(&vb, &rb, &pk);

        let sum = twisted_elgamal::ciphertext_add(&ea, &eb);
        let recovered = twisted_elgamal::ciphertext_sub(&sum, &eb);

        assert!(twisted_elgamal::ciphertext_equals(&recovered, &ea), 0);
    }

    // `ciphertext_add_assign` matches `ciphertext_add` in place.
    #[test]
    fun golden_ciphertext_add_assign_matches_add() {
        let dk = deterministic_dk(46);
        let pk = twisted_elgamal::pubkey_from_secret_key(&dk).extract();

        let va = ristretto255::new_scalar_from_u64(4);
        let vb = ristretto255::new_scalar_from_u64(9);
        let ra = ristretto255::new_scalar_from_u64(22);
        let rb = ristretto255::new_scalar_from_u64(55);

        let ea = twisted_elgamal::new_ciphertext_with_basepoint(&va, &ra, &pk);
        let eb = twisted_elgamal::new_ciphertext_with_basepoint(&vb, &rb, &pk);

        let expected = twisted_elgamal::ciphertext_add(&ea, &eb);
        twisted_elgamal::ciphertext_add_assign(&mut ea, &eb);
        assert!(twisted_elgamal::ciphertext_equals(&ea, &expected), 0);
    }

    // `ciphertext_sub_assign` matches `ciphertext_sub` in place.
    #[test]
    fun golden_ciphertext_sub_assign_matches_sub() {
        let dk = deterministic_dk(47);
        let pk = twisted_elgamal::pubkey_from_secret_key(&dk).extract();

        let va = ristretto255::new_scalar_from_u64(40);
        let vb = ristretto255::new_scalar_from_u64(15);
        let ra = ristretto255::new_scalar_from_u64(1);
        let rb = ristretto255::new_scalar_from_u64(2);

        let ea = twisted_elgamal::new_ciphertext_with_basepoint(&va, &ra, &pk);
        let eb = twisted_elgamal::new_ciphertext_with_basepoint(&vb, &rb, &pk);

        let expected = twisted_elgamal::ciphertext_sub(&ea, &eb);
        twisted_elgamal::ciphertext_sub_assign(&mut ea, &eb);
        assert!(twisted_elgamal::ciphertext_equals(&ea, &expected), 0);
    }

    // compress ∘ decompress is identity.
    #[test]
    fun golden_ciphertext_compress_roundtrip() {
        let dk = deterministic_dk(49);
        let pk = twisted_elgamal::pubkey_from_secret_key(&dk).extract();

        let v = ristretto255::new_scalar_from_u64(12345);
        let r = ristretto255::new_scalar_from_u64(67890);
        let ct = twisted_elgamal::new_ciphertext_with_basepoint(&v, &r, &pk);

        let compressed = twisted_elgamal::compress_ciphertext(&ct);
        let decompressed = twisted_elgamal::decompress_ciphertext(&compressed);
        assert!(twisted_elgamal::ciphertext_equals(&ct, &decompressed), 0);
    }

    // Bytes round-trip: ciphertext_to_bytes → new_ciphertext_from_bytes is id.
    #[test]
    fun golden_ciphertext_bytes_roundtrip() {
        let dk = deterministic_dk(51);
        let pk = twisted_elgamal::pubkey_from_secret_key(&dk).extract();

        let v = ristretto255::new_scalar_from_u64(777);
        let r = ristretto255::new_scalar_from_u64(888);
        let ct = twisted_elgamal::new_ciphertext_with_basepoint(&v, &r, &pk);

        let bytes = twisted_elgamal::ciphertext_to_bytes(&ct);
        assert!(bytes.length() == 64, 0);

        let parsed = twisted_elgamal::new_ciphertext_from_bytes(bytes);
        assert!(parsed.is_some(), 1);
        assert!(twisted_elgamal::ciphertext_equals(&ct, &parsed.extract()), 2);
    }

    // new_ciphertext_from_bytes rejects wrong length.
    #[test]
    fun golden_ciphertext_from_bytes_wrong_length_rejected() {
        let short = vector[0u8, 1u8, 2u8];
        let parsed = twisted_elgamal::new_ciphertext_from_bytes(short);
        assert!(parsed.is_none(), 0);
        option::destroy_none(parsed);
    }

    // Pubkey bytes round-trip.
    #[test]
    fun golden_pubkey_bytes_roundtrip() {
        let dk = deterministic_dk(53);
        let pk = twisted_elgamal::pubkey_from_secret_key(&dk).extract();

        let bytes = twisted_elgamal::pubkey_to_bytes(&pk);
        assert!(bytes.length() == 32, 0);

        let parsed = twisted_elgamal::new_pubkey_from_bytes(bytes);
        assert!(parsed.is_some(), 1);

        let bytes2 = twisted_elgamal::pubkey_to_bytes(&parsed.extract());
        let bytes_again = twisted_elgamal::pubkey_to_bytes(&pk);
        assert!(bytes2 == bytes_again, 2);
    }

    // new_ciphertext_no_randomness: the `right` component is the identity.
    #[test]
    fun golden_ciphertext_no_randomness_has_identity_right() {
        let v = ristretto255::new_scalar_from_u64(42);
        let ct = twisted_elgamal::new_ciphertext_no_randomness(&v);
        let (c, d) = twisted_elgamal::ciphertext_as_points(&ct);
        let identity = ristretto255::point_identity();
        assert!(ristretto255::point_equals(d, &identity), 0);
        assert!(ristretto255::point_equals(c, &ristretto255::basepoint_mul(&v)), 1);
    }

    // `generate_twisted_elgamal_keypair` yields a pubkey that satisfies
    // `pubkey_to_point(pk) = dk⁻¹ · H` (invariant assumed by the Lean model).
    #[test]
    fun golden_generated_keypair_satisfies_pubkey_invariant() {
        let (dk, pk) = twisted_elgamal::generate_twisted_elgamal_keypair();
        let dk_inv = ristretto255::scalar_invert(&dk).extract();
        let expected = ristretto255::point_mul(&ristretto255::hash_to_point_base(), &dk_inv);
        let actual = twisted_elgamal::pubkey_to_point(&pk);
        assert!(ristretto255::point_equals(&actual, &expected), 0);
    }
}

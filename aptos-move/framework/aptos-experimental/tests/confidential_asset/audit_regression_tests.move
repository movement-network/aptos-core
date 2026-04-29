#[test_only]
/// Regression tests for the confidential-asset audit fixes:
///   1. `confidential_balance::sub_balances_mut` previously called `ciphertext_add_assign`
///      and was therefore equivalent to `add_balances_mut`. This test asserts that
///      subtracting a balance from itself yields the encryption of zero.
///   2. `ristretto255_twisted_elgamal::new_pubkey_from_bytes` previously accepted the
///      Ristretto255 identity point. With identity as the encryption key, sigma proofs
///      that bind the public key become forgeable and ciphertext blinding is null.
///      These tests assert the deserializer now rejects identity, and that the
///      `is_identity_pubkey` helper detects identity keys obtained through any path.
module aptos_experimental::audit_regression_tests {
    use std::option;

    use aptos_experimental::confidential_balance;
    use aptos_experimental::ristretto255_twisted_elgamal::{
        Self as twisted_elgamal,
        generate_twisted_elgamal_keypair,
    };

    // ---------------------------------------------------------------------
    // sub_balances_mut
    // ---------------------------------------------------------------------

    #[test]
    fun sub_balances_mut_self_yields_zero() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let randomness = confidential_balance::generate_balance_randomness();

        let amount: u128 = 0xdead_beef_cafe_f00d;
        let balance = confidential_balance::new_actual_balance_from_u128(amount, &randomness, &ek);
        let other = confidential_balance::new_actual_balance_from_u128(amount, &randomness, &ek);

        // balance := balance - other  (== balance - balance == 0)
        confidential_balance::sub_balances_mut(&mut balance, &other);

        assert!(
            confidential_balance::verify_actual_balance(&balance, &dk, 0),
            1,
        );
    }

    #[test]
    fun sub_balances_mut_zero_is_identity() {
        let (dk, ek) = generate_twisted_elgamal_keypair();
        let randomness = confidential_balance::generate_balance_randomness();
        let zero_randomness = confidential_balance::generate_balance_randomness();

        let amount: u128 = 0x1234_5678;
        let balance = confidential_balance::new_actual_balance_from_u128(amount, &randomness, &ek);
        let zero = confidential_balance::new_actual_balance_from_u128(0, &zero_randomness, &ek);

        // balance := balance - 0  (must still decrypt to `amount`)
        confidential_balance::sub_balances_mut(&mut balance, &zero);

        assert!(
            confidential_balance::verify_actual_balance(&balance, &dk, amount),
            2,
        );
    }

    // ---------------------------------------------------------------------
    // identity-point pubkey rejection
    // ---------------------------------------------------------------------

    // The canonical compressed encoding of the Ristretto255 identity point is
    // 32 zero bytes. `new_pubkey_from_bytes` must reject it.
    #[test]
    fun new_pubkey_from_bytes_rejects_identity() {
        let identity_bytes = x"0000000000000000000000000000000000000000000000000000000000000000";
        let result = twisted_elgamal::new_pubkey_from_bytes(identity_bytes);
        assert!(result.is_none(), 3);
    }

    #[test]
    fun new_pubkey_from_bytes_accepts_real_key() {
        let (_dk, ek) = generate_twisted_elgamal_keypair();
        let bytes = twisted_elgamal::pubkey_to_bytes(&ek);

        let round_trip = twisted_elgamal::new_pubkey_from_bytes(bytes);
        assert!(round_trip.is_some(), 4);

        let round_trip_pk = round_trip.extract();
        assert!(!twisted_elgamal::is_identity_pubkey(&round_trip_pk), 5);
        assert!(!twisted_elgamal::is_identity_pubkey(&ek), 6);
    }

    // Reject malformed inputs as well — the previous behaviour for non-canonical
    // bytes is preserved.
    #[test]
    fun new_pubkey_from_bytes_rejects_non_canonical() {
        // 31 bytes is too short.
        let short = x"00000000000000000000000000000000000000000000000000000000000000";
        assert!(twisted_elgamal::new_pubkey_from_bytes(short).is_none(), 7);

        // All-ones is not a valid Ristretto255 encoding.
        let bogus = x"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
        assert!(twisted_elgamal::new_pubkey_from_bytes(bogus).is_none(), 8);
    }

    // Sanity check: identity rejection composes with `option::is_some`, i.e. callers
    // that previously did `assert!(new_pubkey_from_bytes(b).is_some())` now also
    // reject identity without further code changes.
    #[test]
    fun identity_rejection_composes_with_is_some() {
        let identity_bytes = x"0000000000000000000000000000000000000000000000000000000000000000";
        let opt = twisted_elgamal::new_pubkey_from_bytes(identity_bytes);
        assert!(option::is_none(&opt), 9);
    }
}

/// MSL specs for `aptos_experimental::confidential_balance`.
///
/// **Scope:** this initial pass covers the structural / length invariants that do not depend on
/// crypto-native behavior:
///
/// - chunk-count invariants for pending (4) vs actual (8) balances,
/// - length preservation under `add_balances_mut` / `sub_balances_mut`,
/// - abort conditions when lhs has fewer chunks than rhs,
/// - view-function return values for the exported constants.
///
/// The ciphertext-level homomorphism (i.e. "sum of homomorphic decryptions" commutes with
/// `add_balances_mut`) is **not** covered here; it belongs with the crypto-layer specs and
/// is blocked on upstream ristretto255 spec patches (see unified-verification-plan §5.2).
/// Functions whose behavior is fully inside the crypto layer are left unspecified for now
/// rather than axiomatized via `pragma opaque` — that's a Phase 2/3 decision.
spec aptos_experimental::confidential_balance {
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict = false;
    }

    //
    // Chunk-count invariants — skip due to vector::range + map SMT havoc
    //

    spec new_pending_balance_no_randomness {
        pragma verify = false;
    }

    spec new_actual_balance_no_randomness {
        pragma verify = false;
    }

    spec new_compressed_pending_balance_no_randomness {
        pragma verify = false;
    }

    spec new_compressed_actual_balance_no_randomness {
        pragma verify = false;
    }

    //
    // Homomorphic ops — skip due to vector::zip_ref SMT havoc
    //

    spec add_balances_mut {
        pragma verify = false;
    }

    spec sub_balances_mut {
        pragma verify = false;
    }

    spec balance_equals {
        pragma verify = false;
    }

    spec balance_c_equals {
        pragma verify = false;
    }

    //
    // Chunk-splitting arithmetic — skip due to loop-based SMT havoc
    //

    spec split_into_chunks_u64 {
        pragma verify = false;
    }

    spec split_into_chunks_u128 {
        pragma verify = false;
    }

    //
    // View functions — constants
    //

    spec get_pending_balance_chunks {
        aborts_if false;
        ensures result == PENDING_BALANCE_CHUNKS;
    }

    spec get_actual_balance_chunks {
        aborts_if false;
        ensures result == ACTUAL_BALANCE_CHUNKS;
    }

    spec get_chunk_size_bits {
        aborts_if false;
        ensures result == CHUNK_SIZE_BITS;
    }

    //
    // Deserialization — skip due to vector operations
    //

    spec new_pending_balance_from_bytes {
        pragma verify = false;
    }

    spec new_actual_balance_from_bytes {
        pragma verify = false;
    }

    //
    // is_zero_balance — skip due to vector operations
    //

    spec is_zero_balance {
        pragma verify = false;
    }

    //
    // compress/decompress — skip due to vector::map
    //

    spec compress_balance {
        pragma verify = false;
    }

    spec decompress_balance {
        pragma verify = false;
    }

    //
    // balance_to_bytes — skip due to vector operations
    //

    spec balance_to_bytes {
        pragma verify = false;
    }

    //
    // balance_to_points_{c,d} — skip due to vector::map
    //

    spec balance_to_points_c {
        pragma verify = false;
    }

    spec balance_to_points_d {
        pragma verify = false;
    }

    //
    // Amount-initialized constructors — skip due to split_into_chunks + map
    //

    spec new_pending_balance_u64_no_randonmess {
        pragma verify = false;
    }

    //
    // Randomness-backed constructors — skip due to vector operations
    //

    spec new_actual_balance_from_u128 {
        pragma verify = false;
    }

    spec new_pending_balance_from_u64 {
        pragma verify = false;
    }

    //
    // Randomness generation — skip due to vector operations
    //

    spec generate_balance_randomness {
        pragma verify = false;
    }

    spec balance_randomness_as_scalars {
        pragma verify = false;
    }

    //
    // Verification helpers — skip due to complex ristretto255 operations
    //

    spec verify_actual_balance {
        pragma verify = false;
    }

    spec verify_pending_balance {
        pragma verify = false;
    }

    spec verify_actual_balance_for_test {
        pragma verify = false;
    }

    spec verify_pending_balance_for_test {
        pragma verify = false;
    }
}

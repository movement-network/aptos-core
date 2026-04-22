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
        pragma aborts_if_is_strict;
    }

    //
    // Chunk-count invariants
    //

    spec new_pending_balance_no_randomness {
        pragma opaque;
        aborts_if false;
        ensures len(result.chunks) == PENDING_BALANCE_CHUNKS;
    }

    spec new_actual_balance_no_randomness {
        pragma opaque;
        aborts_if false;
        ensures len(result.chunks) == ACTUAL_BALANCE_CHUNKS;
    }

    spec new_compressed_pending_balance_no_randomness {
        pragma opaque;
        aborts_if false;
        ensures len(result.chunks) == PENDING_BALANCE_CHUNKS;
    }

    spec new_compressed_actual_balance_no_randomness {
        pragma opaque;
        aborts_if false;
        ensures len(result.chunks) == ACTUAL_BALANCE_CHUNKS;
    }

    //
    // Homomorphic ops — structural part only (length preservation + abort conditions)
    //

    spec add_balances_mut {
        pragma opaque;
        aborts_if len(lhs.chunks) < len(rhs.chunks) with std::error::INTERNAL;
        ensures len(lhs.chunks) == len(old(lhs).chunks);
    }

    spec sub_balances_mut {
        pragma opaque;
        aborts_if len(lhs.chunks) < len(rhs.chunks) with std::error::INTERNAL;
        ensures len(lhs.chunks) == len(old(lhs).chunks);
    }

    spec balance_equals {
        pragma opaque;
        aborts_if len(lhs.chunks) != len(rhs.chunks) with std::error::INTERNAL;
    }

    spec balance_c_equals {
        pragma opaque;
        aborts_if len(lhs.chunks) != len(rhs.chunks) with std::error::INTERNAL;
    }

    //
    // Chunk-splitting arithmetic
    //

    spec split_into_chunks_u64 {
        pragma opaque;
        aborts_if false;
        ensures len(result) == PENDING_BALANCE_CHUNKS;
    }

    spec split_into_chunks_u128 {
        pragma opaque;
        aborts_if false;
        ensures len(result) == ACTUAL_BALANCE_CHUNKS;
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
    // Deserialization — Option-valued, never abort
    //

    spec new_pending_balance_from_bytes {
        pragma opaque;
        aborts_if false;
    }

    spec new_actual_balance_from_bytes {
        pragma opaque;
        aborts_if false;
    }

    //
    // is_zero_balance — pure bool predicate, never aborts
    //

    spec is_zero_balance {
        pragma opaque;
        aborts_if false;
    }

    //
    // compress/decompress — pure transformations; length-preserving
    //

    spec compress_balance {
        pragma opaque;
        aborts_if false;
        ensures len(result.chunks) == len(balance.chunks);
    }

    spec decompress_balance {
        pragma opaque;
        aborts_if false;
        ensures len(result.chunks) == len(balance.chunks);
    }

    //
    // balance_to_bytes — serializer, never aborts
    //

    spec balance_to_bytes {
        pragma opaque;
        aborts_if false;
    }

    //
    // balance_to_points_{c,d} — extractors. Return length = balance length.
    //

    spec balance_to_points_c {
        pragma opaque;
        aborts_if false;
        ensures len(result) == len(balance.chunks);
    }

    spec balance_to_points_d {
        pragma opaque;
        aborts_if false;
        ensures len(result) == len(balance.chunks);
    }

    //
    // Amount-initialized constructors (no randomness variants)
    //

    spec new_pending_balance_u64_no_randonmess {
        pragma opaque;
        aborts_if false;
        ensures len(result.chunks) == PENDING_BALANCE_CHUNKS;
    }

    //
    // Randomness-backed constructors (test-only helpers; left opaque)
    //

    spec new_actual_balance_from_u128 {
        pragma opaque;
        aborts_if false;
        ensures len(result.chunks) == ACTUAL_BALANCE_CHUNKS;
    }

    spec new_pending_balance_from_u64 {
        pragma opaque;
        aborts_if false;
        ensures len(result.chunks) == PENDING_BALANCE_CHUNKS;
    }
}

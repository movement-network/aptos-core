/// MSL specs for `aptos_experimental::ristretto255_twisted_elgamal`.
///
/// **Scope:** this module is the crypto boundary — its functions wrap Ristretto255 point
/// arithmetic and serialization. Per the unified verification plan §3, the crypto-native
/// operations are treated as `pragma opaque` at the Move Prover boundary (their semantics are
/// pinned by the Lean side's `@[opaque]` oracle interface, cross-checked via difftest).
///
/// This initial pass declares the opacity explicitly and states `aborts_if false` where the
/// source never aborts. Full crypto semantics are not in scope here — Ristretto255 algebraic
/// properties (pubkey_to_bytes ∘ pubkey_from_bytes = id modulo canonical encoding, ciphertext
/// homomorphism, etc.) are tracked on the Lean side (`SigmaVerifiers.lean`) and the difftest
/// corpus.
///
/// **Blocked:** full verification requires the upstream ristretto255 spec patches in
/// `aptos-stdlib/sources/cryptography/ristretto255.spec.move` (plan §5.2).
spec aptos_experimental::ristretto255_twisted_elgamal {
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict = false;
    }

    //
    // Deserialization — Option-valued, can abort on malformed ristretto255 points
    //

    spec new_pubkey_from_bytes {
        pragma opaque;
        aborts_if false;
    }

    spec new_ciphertext_from_bytes {
        pragma opaque;
    }

    //
    // Pure-functional constructors — opaque crypto boundary
    //

    spec new_ciphertext_no_randomness {
        pragma opaque;
    }

    spec ciphertext_from_points {
        pragma opaque;
        aborts_if false;
    }

    spec ciphertext_from_compressed_points {
        pragma opaque;
        aborts_if false;
    }

    //
    // Compression / decompression — opaque crypto boundary
    //

    spec compress_ciphertext {
        pragma opaque;
        aborts_if false;
    }

    spec decompress_ciphertext {
        pragma opaque;
        aborts_if false;
    }

    //
    // Homomorphic operations — algebraic semantics pinned on the Lean side
    //

    spec ciphertext_add {
        pragma opaque;
        aborts_if false;
    }

    spec ciphertext_add_assign {
        pragma opaque;
        aborts_if false;
    }

    spec ciphertext_sub {
        pragma opaque;
        aborts_if false;
    }

    spec ciphertext_sub_assign {
        pragma opaque;
        aborts_if false;
    }

    spec ciphertext_equals {
        pragma opaque;
        aborts_if false;
    }

    spec ciphertext_clone {
        pragma opaque;
        aborts_if false;
    }

    //
    // Accessors — can abort on point operations
    //

    spec pubkey_to_bytes {
        pragma opaque;
        aborts_if false;
    }

    spec pubkey_to_point {
        pragma opaque;
    }

    spec pubkey_to_compressed_point {
        pragma opaque;
    }

    spec ciphertext_to_bytes {
        pragma opaque;
    }

    spec ciphertext_into_points {
        pragma opaque;
        aborts_if false;
    }

    spec ciphertext_as_points {
        pragma opaque;
        aborts_if false;
    }

    spec get_value_component {
        pragma opaque;
        aborts_if false;
    }

    //
    // Keypair generation and ciphertext construction
    //

    spec generate_twisted_elgamal_keypair {
        pragma opaque;
        aborts_if false;
        ensures std::option::spec_is_some(result.1);
    }

    spec pubkey_from_secret_key {
        pragma opaque;
        aborts_if false;
    }

    spec new_ciphertext {
        pragma opaque;
        aborts_if false;
    }

    spec new_ciphertext_with_basepoint {
        pragma opaque;
        aborts_if false;
    }
}

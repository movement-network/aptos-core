/// Difftest-only registration Schnorr (prove + verify) mirroring
/// `aptos_experimental::confidential_proof::{verify_registration_proof, …}` on a fixed fixture.
///
/// The default oracle includes **`registration_roundtrip_vm`** (Lean **`execVerifyRegistrationProof`**) and
/// exports **`registration_fixture_pubkey_from_secret_scalar`** for the production-framework roundtrip row
/// (`test_registration_proof_framework_deterministic_verify_roundtrip` in `difftest_confidential_proof`).
/// Regenerate `RegistrationDifftestOracle` wire bytes if this module’s algebra diverges from `confidential_proof`.
module 0x1::difftest_registration_helpers {
    use std::error;
    use std::vector;
    use aptos_std::aptos_hash;
    use aptos_std::ristretto255::{Self, Scalar};
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;

    const FIAT_SHAMIR_REGISTRATION_SIGMA_DST: vector<u8> = b"MovementConfidentialAsset/Registration";

    /// Same byte layout as `confidential_proof::registration_fs_message_for_test` for the
    /// **formal golden** inputs (`chain_id=9`, `@0x1`/`@0x2`/`@0x3`, ek=R=basepoint) — see
    /// `formal_goldens_registration.move` and Lean `TranscriptAlignment.lean`.
    public fun registration_fs_message_golden_move(): vector<u8> {
        let msg = vector::singleton(9u8);
        msg.append(std::bcs::to_bytes(&@0x1));
        msg.append(std::bcs::to_bytes(&@0x2));
        msg.append(std::bcs::to_bytes(&@0x3));
        let bp = ristretto255::basepoint_compressed();
        let ek_bytes = ristretto255::compressed_point_to_bytes(bp);
        let ek = std::option::destroy_some(twisted_elgamal::new_pubkey_from_bytes(ek_bytes));
        msg.append(twisted_elgamal::pubkey_to_bytes(&ek));
        msg.append(ek_bytes);
        msg
    }

    /// Second formal golden: `chain_id=42`, `@0x10` / `@0x20` / `@0x30`, ek=R=basepoint — see
    /// `formal_goldens_registration.move` (`golden_registration_fs_message_second_scenario`) and
    /// Lean `TranscriptAlignment.expectedRegistrationFsMsg2`.
    public fun registration_fs_message_golden_move_second_scenario(): vector<u8> {
        let msg = vector::singleton(42u8);
        msg.append(std::bcs::to_bytes(&@0x10));
        msg.append(std::bcs::to_bytes(&@0x20));
        msg.append(std::bcs::to_bytes(&@0x30));
        let bp = ristretto255::basepoint_compressed();
        let ek_bytes = ristretto255::compressed_point_to_bytes(bp);
        let ek = std::option::destroy_some(twisted_elgamal::new_pubkey_from_bytes(ek_bytes));
        msg.append(twisted_elgamal::pubkey_to_bytes(&ek));
        msg.append(ek_bytes);
        msg
    }

    /// 64-byte `tagged_hash(FIAT_SHAMIR_REGISTRATION_SIGMA_DST, golden1_msg)` — corpus `registration_tagged_hash_golden_1.hex`.
    public fun registration_tagged_hash_golden_move_first(): vector<u8> {
        tagged_hash(FIAT_SHAMIR_REGISTRATION_SIGMA_DST, registration_fs_message_golden_move())
    }

    /// Same for the second golden FS `msg` — corpus `registration_tagged_hash_golden_2.hex`.
    public fun registration_tagged_hash_golden_move_second(): vector<u8> {
        tagged_hash(FIAT_SHAMIR_REGISTRATION_SIGMA_DST, registration_fs_message_golden_move_second_scenario())
    }

    fun tagged_hash(tag: vector<u8>, msg: vector<u8>): vector<u8> {
        let tag_hash = aptos_hash::sha3_512(tag);
        let input = tag_hash;
        input.append(tag_hash);
        input.append(msg);
        aptos_hash::sha3_512(input)
    }

    fun new_scalar_from_tagged_hash(tag: vector<u8>, msg: vector<u8>): Scalar {
        let hash = tagged_hash(tag, msg);
        std::option::extract(&mut ristretto255::new_scalar_uniform_from_64_bytes(hash))
    }

    /// Same relation as `ristretto255_twisted_elgamal::pubkey_from_secret_key` (test-only in framework).
    /// Exposed for deterministic registration fixtures shared with `difftest_confidential_proof`.
    public fun registration_fixture_pubkey_from_secret_scalar(sk: &Scalar): twisted_elgamal::CompressedPubkey {
        let sk_invert = ristretto255::scalar_invert(sk);
        assert!(std::option::is_some(&sk_invert), error::invalid_argument(1));
        let inv = std::option::destroy_some(sk_invert);
        let point = ristretto255::point_mul(
            &ristretto255::hash_to_point_base(),
            &inv
        );
        let cmp = ristretto255::point_compress(&point);
        let bytes = ristretto255::compressed_point_to_bytes(cmp);
        std::option::destroy_some(twisted_elgamal::new_pubkey_from_bytes(bytes))
    }

    fun prove_deterministic(
        chain_id: u8,
        sender: address,
        contract_address: address,
        dk: &Scalar,
        ek: &twisted_elgamal::CompressedPubkey,
        token_address: address,
        k: &Scalar,
    ): (vector<u8>, vector<u8>) {
        let h = ristretto255::hash_to_point_base();
        let r = ristretto255::point_mul(&h, k);
        let r_compressed = ristretto255::point_compress(&r);

        let msg = vector::singleton(chain_id);
        msg.append(std::bcs::to_bytes(&sender));
        msg.append(std::bcs::to_bytes(&contract_address));
        msg.append(std::bcs::to_bytes(&token_address));
        msg.append(twisted_elgamal::pubkey_to_bytes(ek));
        msg.append(ristretto255::compressed_point_to_bytes(r_compressed));
        let e = new_scalar_from_tagged_hash(FIAT_SHAMIR_REGISTRATION_SIGMA_DST, msg);

        let dk_inv_opt = ristretto255::scalar_invert(dk);
        assert!(std::option::is_some(&dk_inv_opt), error::invalid_argument(1));
        let dk_inv = std::option::destroy_some(dk_inv_opt);
        let s = ristretto255::scalar_sub(k, &ristretto255::scalar_mul(&e, &dk_inv));

        let commitment_bytes = ristretto255::compressed_point_to_bytes(r_compressed);
        let response_bytes = ristretto255::scalar_to_bytes(&s);
        (commitment_bytes, response_bytes)
    }

    fun verify_like_confidential_proof(
        chain_id: u8,
        sender: address,
        contract_address: address,
        ek: &twisted_elgamal::CompressedPubkey,
        token_address: address,
        commitment_bytes: vector<u8>,
        response_bytes: vector<u8>,
    ) {
        let r_point = ristretto255::new_compressed_point_from_bytes(commitment_bytes);
        assert!(std::option::is_some(&r_point), error::invalid_argument(1));
        let r_compressed = std::option::destroy_some(r_point);

        let s_opt = ristretto255::new_scalar_from_bytes(response_bytes);
        assert!(std::option::is_some(&s_opt), error::invalid_argument(1));
        let s = std::option::destroy_some(s_opt);

        let msg = vector::singleton(chain_id);
        msg.append(std::bcs::to_bytes(&sender));
        msg.append(std::bcs::to_bytes(&contract_address));
        msg.append(std::bcs::to_bytes(&token_address));
        msg.append(twisted_elgamal::pubkey_to_bytes(ek));
        msg.append(ristretto255::compressed_point_to_bytes(r_compressed));
        let e = new_scalar_from_tagged_hash(FIAT_SHAMIR_REGISTRATION_SIGMA_DST, msg);

        let h = ristretto255::hash_to_point_base();
        let ek_point = twisted_elgamal::pubkey_to_point(ek);

        let lhs = ristretto255::point_add(
            &ristretto255::point_mul(&h, &s),
            &ristretto255::point_mul(&ek_point, &e)
        );
        let rhs = ristretto255::point_decompress(&r_compressed);

        assert!(
            ristretto255::point_equals(&lhs, &rhs),
            error::invalid_argument(1)
        );
    }

    /// Fixed vectors for VM oracle; Lean column uses a bool stub (see `Programs/Confidential.lean`).
    public fun registration_roundtrip_vm(): bool {
        let chain_id = 9u8;
        let sender = @0x1;
        let contract_address = @0x2;
        let token_address = @0x3;
        let dk = ristretto255::new_scalar_from_u64(42);
        let ek = registration_fixture_pubkey_from_secret_scalar(&dk);
        let k = ristretto255::new_scalar_from_u64(9999);
        let (commitment, response) = prove_deterministic(
            chain_id,
            sender,
            contract_address,
            &dk,
            &ek,
            token_address,
            &k,
        );
        verify_like_confidential_proof(
            chain_id,
            sender,
            contract_address,
            &ek,
            token_address,
            commitment,
            response,
        );
        true
    }
}

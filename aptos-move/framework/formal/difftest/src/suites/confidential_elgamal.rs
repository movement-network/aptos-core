//! VM oracles for `aptos_experimental::ristretto255_twisted_elgamal` (release-visible API surface).
//!
//! Lean: `MovementFormal.MoveModel.Programs.Confidential` stubs indices **20–31**, **53–54** (`*_assign`),
//! **58** (`ciphertext_sub` self), **66** (`ciphertext_add` commutes at zero), **72** (three-way associativity at zero),
//! **77–78** (short pubkey / 63-byte CT `Option` edges), **88–92** (split chunk-1 smoke, 65-byte CT, 31-byte PK, sub/add restore); see `Runner.funcNameToMapping`.

use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_confidential_elgamal";

const TEST_SOURCE: &str = r#"
module 0x1::difftest_confidential_elgamal {
    use std::option;
    use std::vector;
    use aptos_std::ristretto255;
    use aptos_experimental::ristretto255_twisted_elgamal as elg;

    public fun test_elg_pubkey_from_empty_is_none(): bool {
        option::is_none(&elg::new_pubkey_from_bytes(x""))
    }

    public fun test_elg_pubkey_basepoint_roundtrip(): bool {
        let bp = ristretto255::basepoint_compressed();
        let pk = elg::new_pubkey_from_bytes(ristretto255::compressed_point_to_bytes(bp)).extract();
        let bytes2 = elg::pubkey_to_bytes(&pk);
        let bp2 = ristretto255::new_compressed_point_from_bytes(bytes2).extract();
        ristretto255::compressed_point_to_bytes(bp) == ristretto255::compressed_point_to_bytes(bp2)
    }

    public fun test_elg_ciphertext_from_bytes_wrong_len(): bool {
        option::is_none(&elg::new_ciphertext_from_bytes(x""))
    }

    public fun test_elg_pubkey_from_short_bytes_is_none(): bool {
        let v = vector::range(0, 10).map(|_| 0u8);
        option::is_none(&elg::new_pubkey_from_bytes(v))
    }

    public fun test_elg_ciphertext_from_63_bytes_is_none(): bool {
        let v = vector::range(0, 63).map(|_| 0u8);
        option::is_none(&elg::new_ciphertext_from_bytes(v))
    }

    public fun test_elg_ciphertext_from_65_bytes_is_none(): bool {
        let v = vector::range(0, 65).map(|_| 0u8);
        option::is_none(&elg::new_ciphertext_from_bytes(v))
    }

    public fun test_elg_pubkey_from_31_bytes_is_none(): bool {
        let v = vector::range(0, 31).map(|_| 0u8);
        option::is_none(&elg::new_pubkey_from_bytes(v))
    }

    public fun test_elg_ciphertext_sub_then_add_zero_restores(): bool {
        let z = ristretto255::scalar_zero();
        let a = elg::new_ciphertext_no_randomness(&z);
        let b = elg::new_ciphertext_no_randomness(&z);
        elg::ciphertext_equals(&elg::ciphertext_add(&elg::ciphertext_sub(&a, &b), &b), &a)
    }

    public fun test_elg_two_zero_plaintext_ciphertexts_equal(): bool {
        let z = ristretto255::scalar_zero();
        let a = elg::new_ciphertext_no_randomness(&z);
        let b = elg::new_ciphertext_no_randomness(&z);
        elg::ciphertext_equals(&a, &b)
    }

    public fun test_elg_compress_decompress_ciphertext(): bool {
        let z = ristretto255::scalar_zero();
        let ct = elg::new_ciphertext_no_randomness(&z);
        let comp = elg::compress_ciphertext(&ct);
        let ct2 = elg::decompress_ciphertext(&comp);
        elg::ciphertext_equals(&ct, &ct2)
    }

    public fun test_elg_ciphertext_add_sub(): bool {
        let z = ristretto255::scalar_zero();
        let a = elg::new_ciphertext_no_randomness(&z);
        let b = elg::new_ciphertext_no_randomness(&z);
        let sum = elg::ciphertext_add(&a, &b);
        let diff = elg::ciphertext_sub(&sum, &b);
        elg::ciphertext_equals(&diff, &a)
    }

    public fun test_elg_ciphertext_add_assign_matches_add(): bool {
        let z = ristretto255::scalar_zero();
        let b = elg::new_ciphertext_no_randomness(&z);
        let sum_direct = elg::ciphertext_add(
            &elg::new_ciphertext_no_randomness(&z),
            &b
        );
        let mut_a = elg::new_ciphertext_no_randomness(&z);
        elg::ciphertext_add_assign(&mut mut_a, &b);
        elg::ciphertext_equals(&mut_a, &sum_direct)
    }

    public fun test_elg_ciphertext_sub_assign_matches_sub(): bool {
        let z = ristretto255::scalar_zero();
        let b = elg::new_ciphertext_no_randomness(&z);
        let base = elg::ciphertext_add(
            &elg::new_ciphertext_no_randomness(&z),
            &b
        );
        let diff_direct = elg::ciphertext_sub(&base, &b);
        let mut_a = elg::ciphertext_add(
            &elg::new_ciphertext_no_randomness(&z),
            &b
        );
        elg::ciphertext_sub_assign(&mut mut_a, &b);
        elg::ciphertext_equals(&mut_a, &diff_direct)
    }

    public fun test_elg_ciphertext_sub_self_is_zero(): bool {
        let z = ristretto255::scalar_zero();
        let a = elg::new_ciphertext_no_randomness(&z);
        let d = elg::ciphertext_sub(&a, &a);
        elg::ciphertext_equals(&d, &a)
    }

    public fun test_elg_ciphertext_add_commutes_at_zero(): bool {
        let z = ristretto255::scalar_zero();
        let a = elg::new_ciphertext_no_randomness(&z);
        let b = elg::new_ciphertext_no_randomness(&z);
        elg::ciphertext_equals(&elg::ciphertext_add(&a, &b), &elg::ciphertext_add(&b, &a))
    }

    public fun test_elg_ciphertext_add_associative_three_zeros(): bool {
        let z = ristretto255::scalar_zero();
        let a = elg::new_ciphertext_no_randomness(&z);
        let b = elg::new_ciphertext_no_randomness(&z);
        let c = elg::new_ciphertext_no_randomness(&z);
        let left = elg::ciphertext_add(&elg::ciphertext_add(&a, &b), &c);
        let right = elg::ciphertext_add(&a, &elg::ciphertext_add(&b, &c));
        elg::ciphertext_equals(&left, &right)
    }

    public fun test_elg_compress_ciphertext_twice_same(): bool {
        let z = ristretto255::scalar_zero();
        let ct = elg::new_ciphertext_no_randomness(&z);
        let c1 = elg::compress_ciphertext(&ct);
        let c2 = elg::compress_ciphertext(&ct);
        let ct1 = elg::decompress_ciphertext(&c1);
        let ct2 = elg::decompress_ciphertext(&c2);
        elg::ciphertext_equals(&ct1, &ct2)
    }

    public fun test_elg_ciphertext_to_bytes_len_64(): bool {
        let z = ristretto255::scalar_zero();
        let ct = elg::new_ciphertext_no_randomness(&z);
        elg::ciphertext_to_bytes(&ct).length() == 64
    }

    public fun test_elg_ciphertext_into_from_points(): bool {
        let z = ristretto255::scalar_zero();
        let ct = elg::new_ciphertext_no_randomness(&z);
        let (l, r) = elg::ciphertext_into_points(ct);
        let ct2 = elg::ciphertext_from_points(l, r);
        elg::ciphertext_equals(&ct2, &elg::new_ciphertext_no_randomness(&z))
    }

    public fun test_elg_get_value_component_is_identity_for_zero_plaintext(): bool {
        let z = ristretto255::scalar_zero();
        let ct = elg::new_ciphertext_no_randomness(&z);
        let g0 = ristretto255::basepoint_mul(&z);
        ristretto255::point_equals(elg::get_value_component(&ct), &g0)
    }

    public fun test_elg_pubkey_to_point_roundtrip(): bool {
        let bp = ristretto255::basepoint_compressed();
        let pk = elg::new_pubkey_from_bytes(ristretto255::compressed_point_to_bytes(bp)).extract();
        let pt = elg::pubkey_to_point(&pk);
        let c = elg::pubkey_to_compressed_point(&pk);
        ristretto255::point_equals(&pt, &ristretto255::point_decompress(&c))
    }

    public fun test_elg_ciphertext_to_bytes_roundtrip(): bool {
        let z = ristretto255::scalar_zero();
        let ct = elg::new_ciphertext_no_randomness(&z);
        let b = elg::ciphertext_to_bytes(&ct);
        let ct2 = elg::new_ciphertext_from_bytes(b).extract();
        elg::ciphertext_equals(&ct, &ct2)
    }
}
"#;

pub struct ConfidentialElGamalSuite;

impl DiffTestSuite for ConfidentialElGamalSuite {
    fn id(&self) -> &'static str {
        "confidential_elgamal"
    }

    fn name(&self) -> &str {
        "0x1::difftest_confidential_elgamal"
    }

    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()> {
        let modules = compile_with_aptos_head_bundle(TEST_SOURCE)?;
        for module in &modules {
            let blob = module_blob(module)?;
            storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
        }
        Ok(())
    }

    fn generate_test_cases(&self, storage: &mut InMemoryStorage) -> Result<Vec<TestCase>> {
        let mut cases = Vec::new();
        let tests: &[(&str, &str)] = &[
            ("test_elg_pubkey_from_empty_is_none", "none"),
            ("test_elg_pubkey_basepoint_roundtrip", "rt"),
            ("test_elg_ciphertext_from_bytes_wrong_len", "len"),
            ("test_elg_pubkey_from_short_bytes_is_none", "pk_short"),
            ("test_elg_ciphertext_from_63_bytes_is_none", "ct63"),
            ("test_elg_ciphertext_from_65_bytes_is_none", "ct65"),
            ("test_elg_pubkey_from_31_bytes_is_none", "pk31"),
            ("test_elg_ciphertext_sub_then_add_zero_restores", "sub_add"),
            ("test_elg_two_zero_plaintext_ciphertexts_equal", "eq"),
            ("test_elg_compress_decompress_ciphertext", "cmp"),
            ("test_elg_ciphertext_add_sub", "addsub"),
            ("test_elg_ciphertext_add_assign_matches_add", "add_assign"),
            ("test_elg_ciphertext_sub_assign_matches_sub", "sub_assign"),
            ("test_elg_ciphertext_sub_self_is_zero", "sub_self"),
            ("test_elg_ciphertext_add_commutes_at_zero", "add_comm0"),
            (
                "test_elg_ciphertext_add_associative_three_zeros",
                "add_assoc0",
            ),
            ("test_elg_compress_ciphertext_twice_same", "cmp2"),
            ("test_elg_ciphertext_to_bytes_len_64", "b64"),
            ("test_elg_ciphertext_into_from_points", "pts"),
            (
                "test_elg_get_value_component_is_identity_for_zero_plaintext",
                "gc",
            ),
            ("test_elg_pubkey_to_point_roundtrip", "pkpt"),
            ("test_elg_ciphertext_to_bytes_roundtrip", "btrt"),
        ];
        for (function, label) in tests {
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, function, &[])?;
            cases.push(TestCase {
                function: format!("{} [{}]", function, label),
                type_args: None,
                args: vec![],
                result,
                skip_lean: false,
            });
        }
        Ok(cases)
    }
}

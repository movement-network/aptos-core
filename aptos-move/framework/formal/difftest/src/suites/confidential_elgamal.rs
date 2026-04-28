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

    /// `ciphertext_as_points` returns references that compress to the same bytes as the direct
    /// `ciphertext_to_bytes` serialization (i.e. `(&left, &right)` observe the same points).
    public fun test_elg_ciphertext_as_points_compress_equals_to_bytes(): bool {
        let z = ristretto255::scalar_zero();
        let ct = elg::new_ciphertext_no_randomness(&z);
        let (lref, rref) = elg::ciphertext_as_points(&ct);
        let bytes = ristretto255::point_to_bytes(&ristretto255::point_compress(lref));
        bytes.append(ristretto255::point_to_bytes(&ristretto255::point_compress(rref)));
        bytes == elg::ciphertext_to_bytes(&ct)
    }

    /// `ciphertext_from_compressed_points` round-trips through the canonical zero-plaintext
    /// ciphertext: compressing, rebuilding with `_from_compressed_points`, decompressing yields
    /// a ciphertext equal to the original.
    public fun test_elg_ciphertext_from_compressed_points_roundtrip(): bool {
        let z = ristretto255::scalar_zero();
        let ct = elg::new_ciphertext_no_randomness(&z);
        let comp = elg::compress_ciphertext(&ct);
        let b = elg::ciphertext_to_bytes(&ct);
        let lbytes = std::vector::slice(&b, 0, 32);
        let rbytes = std::vector::slice(&b, 32, 64);
        let lc = ristretto255::new_compressed_point_from_bytes(lbytes).extract();
        let rc = ristretto255::new_compressed_point_from_bytes(rbytes).extract();
        let rebuilt = elg::ciphertext_from_compressed_points(lc, rc);
        let rebuilt_ct = elg::decompress_ciphertext(&rebuilt);
        // Verify same bytes as round-tripping `comp`, i.e. the constructor just packs the two
        // `CompressedRistretto` fields with no hidden state.
        let via_comp = elg::decompress_ciphertext(&comp);
        elg::ciphertext_equals(&rebuilt_ct, &ct) && elg::ciphertext_equals(&via_comp, &ct)
    }

    // ─────────────────── STRONG tests on NON-TRIVIAL plaintexts ────────────────────
    // The preceding tests all use `scalar_zero()` which makes many crypto bugs invisible
    // (e.g. `ciphertext_equals` always-true, `ciphertext_add` being a no-op, `to_bytes`
    // ignoring the plaintext). The tests below distinguish non-equal ciphertexts and
    // exercise scalar-preserving algebraic identities, so a regression to a trivial
    // implementation would produce a VM result other than `true` and the Lean `ldTrue`
    // pin would mismatch → **FAIL**, i.e. the bug is caught by the difftest oracle.

    /// Two ciphertexts with different non-zero plaintexts **must not** compare equal under
    /// `ciphertext_equals`. Catches: `ciphertext_equals` that always returns `true` or
    /// compares only one component.
    public fun test_elg_ciphertext_one_not_equal_zero(): bool {
        let o = ristretto255::scalar_one();
        let z = ristretto255::scalar_zero();
        let ct_one = elg::new_ciphertext_no_randomness(&o);
        let ct_zero = elg::new_ciphertext_no_randomness(&z);
        !elg::ciphertext_equals(&ct_one, &ct_zero)
    }

    /// Byte serialization of a non-zero plaintext ciphertext **must** differ from the
    /// zero-plaintext serialization. Catches: `ciphertext_to_bytes` that ignores the
    /// left (value) component.
    public fun test_elg_ciphertext_one_bytes_differ_from_zero_bytes(): bool {
        let o = ristretto255::scalar_one();
        let z = ristretto255::scalar_zero();
        let b_one = elg::ciphertext_to_bytes(&elg::new_ciphertext_no_randomness(&o));
        let b_zero = elg::ciphertext_to_bytes(&elg::new_ciphertext_no_randomness(&z));
        b_one != b_zero
    }

    /// `ciphertext_add(ct(1), ct(0)) == ct(1)`: adding the zero ciphertext (identity)
    /// must leave the left operand unchanged. Catches: `ciphertext_add` that overwrites
    /// with identity / swaps operands / does subtraction.
    public fun test_elg_ciphertext_add_one_plus_zero_equals_one(): bool {
        let o = ristretto255::scalar_one();
        let z = ristretto255::scalar_zero();
        let ct_one = elg::new_ciphertext_no_randomness(&o);
        let ct_zero = elg::new_ciphertext_no_randomness(&z);
        let sum = elg::ciphertext_add(&ct_one, &ct_zero);
        elg::ciphertext_equals(&sum, &ct_one)
    }

    /// Scalar homomorphism: `ciphertext_add(ct(1), ct(2)) == ct(3)` (randomness=0 on
    /// both sides, so equals `(1·G + 2·G, 0+0) = (3·G, 0)`). Catches: `ciphertext_add`
    /// that collapses to a constant, only adds one component, or misorders.
    public fun test_elg_ciphertext_add_one_plus_two_equals_three(): bool {
        let o = ristretto255::scalar_one();
        let two = ristretto255::new_scalar_from_u64(2);
        let three = ristretto255::new_scalar_from_u64(3);
        let sum = elg::ciphertext_add(
            &elg::new_ciphertext_no_randomness(&o),
            &elg::new_ciphertext_no_randomness(&two),
        );
        let expected = elg::new_ciphertext_no_randomness(&three);
        elg::ciphertext_equals(&sum, &expected)
    }

    /// `ciphertext_sub(ct(v), ct(v)) == ct(0)` for non-zero v. Catches: `ciphertext_sub`
    /// that is a no-op or misuses `add`. Critical because `scalar_zero()` inputs make
    /// this trivially pass — the test uses a non-zero plaintext to distinguish.
    public fun test_elg_ciphertext_sub_one_from_one_is_zero(): bool {
        let o = ristretto255::scalar_one();
        let z = ristretto255::scalar_zero();
        let ct_one = elg::new_ciphertext_no_randomness(&o);
        let diff = elg::ciphertext_sub(&ct_one, &ct_one);
        let ct_zero = elg::new_ciphertext_no_randomness(&z);
        elg::ciphertext_equals(&diff, &ct_zero)
    }

    /// Scalar homomorphism for sub: `ciphertext_sub(ct(3), ct(2)) == ct(1)`.
    public fun test_elg_ciphertext_sub_three_minus_two_equals_one(): bool {
        let o = ristretto255::scalar_one();
        let two = ristretto255::new_scalar_from_u64(2);
        let three = ristretto255::new_scalar_from_u64(3);
        let diff = elg::ciphertext_sub(
            &elg::new_ciphertext_no_randomness(&three),
            &elg::new_ciphertext_no_randomness(&two),
        );
        let expected = elg::new_ciphertext_no_randomness(&o);
        elg::ciphertext_equals(&diff, &expected)
    }

    /// `ciphertext_sub_assign` must produce the same result as `ciphertext_sub` on
    /// non-zero inputs (matches the well-tested zero-input twin, but here with a
    /// distinguishing plaintext).
    public fun test_elg_ciphertext_sub_assign_on_nonzero_matches_sub(): bool {
        let one = ristretto255::scalar_one();
        let two = ristretto255::new_scalar_from_u64(2);
        let direct = elg::ciphertext_sub(
            &elg::new_ciphertext_no_randomness(&two),
            &elg::new_ciphertext_no_randomness(&one),
        );
        let mut_a = elg::new_ciphertext_no_randomness(&two);
        elg::ciphertext_sub_assign(&mut mut_a, &elg::new_ciphertext_no_randomness(&one));
        elg::ciphertext_equals(&mut_a, &direct)
    }

    /// Compress/decompress roundtrip on a non-zero plaintext must preserve the ciphertext.
    /// Catches: compress/decompress that silently resets to identity / loses the left point.
    public fun test_elg_compress_decompress_nonzero_ciphertext_roundtrips(): bool {
        let s = ristretto255::new_scalar_from_u64(42);
        let ct = elg::new_ciphertext_no_randomness(&s);
        let comp = elg::compress_ciphertext(&ct);
        let ct2 = elg::decompress_ciphertext(&comp);
        elg::ciphertext_equals(&ct, &ct2)
    }

    /// `get_value_component(ct(v))` must equal `v · basepoint` for non-zero `v`.
    /// Catches: `get_value_component` returning the wrong field (right vs left).
    public fun test_elg_get_value_component_nonzero_matches_basepoint_mul(): bool {
        let s = ristretto255::new_scalar_from_u64(7);
        let ct = elg::new_ciphertext_no_randomness(&s);
        let expected = ristretto255::basepoint_mul(&s);
        ristretto255::point_equals(elg::get_value_component(&ct), &expected)
    }

    /// `ciphertext_to_bytes(ct(v))` round-trips through `new_ciphertext_from_bytes` for
    /// non-zero `v`. Catches: serializer/deserializer that only preserves zero inputs.
    public fun test_elg_ciphertext_to_bytes_roundtrip_nonzero(): bool {
        let s = ristretto255::new_scalar_from_u64(65535);
        let ct = elg::new_ciphertext_no_randomness(&s);
        let b = elg::ciphertext_to_bytes(&ct);
        let opt = elg::new_ciphertext_from_bytes(b);
        if (std::option::is_none(&opt)) {
            false
        } else {
            elg::ciphertext_equals(&ct, std::option::borrow(&opt))
        }
    }

    /// Associativity of `ciphertext_add` with three NON-ZERO plaintexts:
    /// `(ct(1)+ct(2))+ct(3) == ct(1)+(ct(2)+ct(3)) == ct(6)`. The zero-
    /// plaintext associativity test is also present (see
    /// `test_elg_ciphertext_add_associative_three_zeros`), but that one
    /// passes vacuously under a no-op `ciphertext_add`. This row distinguishes.
    public fun test_elg_ciphertext_add_associative_nonzero(): bool {
        let o = ristretto255::scalar_one();
        let two = ristretto255::new_scalar_from_u64(2);
        let three = ristretto255::new_scalar_from_u64(3);
        let six = ristretto255::new_scalar_from_u64(6);
        let left = elg::ciphertext_add(
            &elg::ciphertext_add(
                &elg::new_ciphertext_no_randomness(&o),
                &elg::new_ciphertext_no_randomness(&two),
            ),
            &elg::new_ciphertext_no_randomness(&three),
        );
        let right = elg::ciphertext_add(
            &elg::new_ciphertext_no_randomness(&o),
            &elg::ciphertext_add(
                &elg::new_ciphertext_no_randomness(&two),
                &elg::new_ciphertext_no_randomness(&three),
            ),
        );
        let expected = elg::new_ciphertext_no_randomness(&six);
        elg::ciphertext_equals(&left, &right)
            && elg::ciphertext_equals(&left, &expected)
    }

    /// Commutativity of `ciphertext_add` with two NON-ZERO plaintexts:
    /// `ct(1)+ct(2) == ct(2)+ct(1) == ct(3)`. The zero-plaintext commutativity
    /// row passes under a constant-returning add; this row does not.
    public fun test_elg_ciphertext_add_commutative_nonzero(): bool {
        let o = ristretto255::scalar_one();
        let two = ristretto255::new_scalar_from_u64(2);
        let three = ristretto255::new_scalar_from_u64(3);
        let lhs = elg::ciphertext_add(
            &elg::new_ciphertext_no_randomness(&o),
            &elg::new_ciphertext_no_randomness(&two),
        );
        let rhs = elg::ciphertext_add(
            &elg::new_ciphertext_no_randomness(&two),
            &elg::new_ciphertext_no_randomness(&o),
        );
        let expected = elg::new_ciphertext_no_randomness(&three);
        elg::ciphertext_equals(&lhs, &rhs) && elg::ciphertext_equals(&lhs, &expected)
    }

    /// `ciphertext_sub(ct(v), ct(v)) == ct(0)` for non-zero `v`, via the in-
    /// place `sub_assign` variant. Catches: `sub_assign` that is a no-op or
    /// accidentally calls `add_assign` (the sibling bug to the production
    /// `sub_balances_mut` bug caught at the balance layer).
    public fun test_elg_ciphertext_sub_assign_self_is_zero_nonzero(): bool {
        let v = ristretto255::new_scalar_from_u64(7);
        let z = ristretto255::scalar_zero();
        let mut_a = elg::new_ciphertext_no_randomness(&v);
        elg::ciphertext_sub_assign(&mut mut_a, &elg::new_ciphertext_no_randomness(&v));
        elg::ciphertext_equals(&mut_a, &elg::new_ciphertext_no_randomness(&z))
    }

    /// `ciphertext_add_assign(&mut ct(1), ct(2))` must equal `ct(3)`. Catches:
    /// `add_assign` that is a no-op (would leave `ct(1)` unchanged) or that
    /// subtracts (would produce `ct(1) - ct(2)`).
    public fun test_elg_ciphertext_add_assign_one_plus_two_equals_three(): bool {
        let o = ristretto255::scalar_one();
        let two = ristretto255::new_scalar_from_u64(2);
        let three = ristretto255::new_scalar_from_u64(3);
        let mut_a = elg::new_ciphertext_no_randomness(&o);
        elg::ciphertext_add_assign(&mut mut_a, &elg::new_ciphertext_no_randomness(&two));
        elg::ciphertext_equals(&mut_a, &elg::new_ciphertext_no_randomness(&three))
    }

    /// `(a + b) - b == a` for NON-ZERO plaintexts: round-trip identity that
    /// would catch a simultaneous mis-wire of both `ciphertext_add` and
    /// `ciphertext_sub` as long as they aren't both no-ops at the same time.
    public fun test_elg_ciphertext_add_then_sub_recovers_original_nonzero(): bool {
        let five = ristretto255::new_scalar_from_u64(5);
        let three = ristretto255::new_scalar_from_u64(3);
        let sum = elg::ciphertext_add(
            &elg::new_ciphertext_no_randomness(&five),
            &elg::new_ciphertext_no_randomness(&three),
        );
        let diff = elg::ciphertext_sub(&sum, &elg::new_ciphertext_no_randomness(&three));
        elg::ciphertext_equals(&diff, &elg::new_ciphertext_no_randomness(&five))
    }

    /// `ciphertext_to_bytes(ct(v)).length() == 64` for NON-ZERO `v`. Pins the
    /// output length invariant against a regression where the serializer
    /// omits bytes for nonzero components.
    public fun test_elg_ciphertext_to_bytes_len_64_nonzero(): bool {
        let v = ristretto255::new_scalar_from_u64(42);
        let ct = elg::new_ciphertext_no_randomness(&v);
        elg::ciphertext_to_bytes(&ct).length() == 64
    }

    /// `get_value_component` extracts the FIRST (left / `C`) point of a
    /// ciphertext. `new_ciphertext_no_randomness(v)` builds `(v·G, 0)`, so
    /// the right/D component is identity. If `get_value_component` were
    /// swapped to return `D`, for non-zero `v` the returned point would be
    /// identity — not equal to `v·basepoint`. This row complements
    /// `test_elg_get_value_component_nonzero_matches_basepoint_mul` by
    /// explicitly demanding `get_value_component != identity` when v != 0.
    public fun test_elg_get_value_component_not_identity_when_v_nonzero(): bool {
        let v = ristretto255::new_scalar_from_u64(11);
        let ct = elg::new_ciphertext_no_randomness(&v);
        !ristretto255::point_equals(elg::get_value_component(&ct), &ristretto255::point_identity())
    }

    /// For distinct NON-ZERO plaintexts `a=3`, `b=2`, `sub(ct(a), ct(b))` MUST
    /// differ from `sub(ct(b), ct(a))` (the former encrypts `+1`, the latter
    /// `-1`). Catches: `ciphertext_sub` implementation that accidentally
    /// commutes operands (e.g., swapped left/right in `point_sub`).
    public fun test_elg_ciphertext_sub_not_commutative_on_distinct_nonzero(): bool {
        let s_a = ristretto255::new_scalar_from_u64(3);
        let s_b = ristretto255::new_scalar_from_u64(2);
        let ct_a = elg::new_ciphertext_no_randomness(&s_a);
        let ct_b = elg::new_ciphertext_no_randomness(&s_b);
        let ab = elg::ciphertext_sub(&ct_a, &ct_b);
        let ba = elg::ciphertext_sub(&ct_b, &ct_a);
        !elg::ciphertext_equals(&ab, &ba)
    }

    /// `sub(ct(5), ct(3)) == ct(2)` — direct additive-inverse algebra at
    /// ElGamal level with three DISTINCT non-zero values. Catches:
    /// `ciphertext_sub` returning `ct(0)` (always-zero bug), `ct(a+b)` (add
    /// bug), or reversed-operand bug. Complements the existing
    /// `sub_three_minus_two_equals_one` test at a different algebra point.
    public fun test_elg_ciphertext_sub_five_minus_three_equals_two_nonzero(): bool {
        let s5 = ristretto255::new_scalar_from_u64(5);
        let s3 = ristretto255::new_scalar_from_u64(3);
        let s2 = ristretto255::new_scalar_from_u64(2);
        let ct5 = elg::new_ciphertext_no_randomness(&s5);
        let ct3 = elg::new_ciphertext_no_randomness(&s3);
        let ct2 = elg::new_ciphertext_no_randomness(&s2);
        let diff = elg::ciphertext_sub(&ct5, &ct3);
        elg::ciphertext_equals(&diff, &ct2)
    }

    /// `ciphertext_add_assign` over THREE non-zero additions must produce
    /// `ct(1+2+3) == ct(6)`. Catches: `add_assign` that is a no-op (common
    /// copy-paste slip where the mutator does nothing), or `add_assign` that
    /// overwrites with rhs instead of adding.
    public fun test_elg_ciphertext_add_assign_accumulates_three_nonzero(): bool {
        let s1 = ristretto255::new_scalar_from_u64(1);
        let s2 = ristretto255::new_scalar_from_u64(2);
        let s3 = ristretto255::new_scalar_from_u64(3);
        let s6 = ristretto255::new_scalar_from_u64(6);
        let acc = elg::new_ciphertext_no_randomness(&s1);
        let ct2 = elg::new_ciphertext_no_randomness(&s2);
        let ct3 = elg::new_ciphertext_no_randomness(&s3);
        elg::ciphertext_add_assign(&mut acc, &ct2);
        elg::ciphertext_add_assign(&mut acc, &ct3);
        let ct6 = elg::new_ciphertext_no_randomness(&s6);
        elg::ciphertext_equals(&acc, &ct6)
    }

    /// `ciphertext_sub_assign` chained: `10 -= 3 -= 2 == 5`. Catches:
    /// `sub_assign` that is a no-op, or `sub_assign` that adds instead of
    /// subtracts (the exact pattern of the `sub_balances_mut` bug caught by
    /// this diff-testing campaign — regression coverage at a direct ElGamal
    /// level).
    public fun test_elg_ciphertext_sub_assign_chain_nonzero(): bool {
        let s10 = ristretto255::new_scalar_from_u64(10);
        let s3 = ristretto255::new_scalar_from_u64(3);
        let s2 = ristretto255::new_scalar_from_u64(2);
        let s5 = ristretto255::new_scalar_from_u64(5);
        let acc = elg::new_ciphertext_no_randomness(&s10);
        let ct3 = elg::new_ciphertext_no_randomness(&s3);
        let ct2 = elg::new_ciphertext_no_randomness(&s2);
        elg::ciphertext_sub_assign(&mut acc, &ct3);
        elg::ciphertext_sub_assign(&mut acc, &ct2);
        let ct5 = elg::new_ciphertext_no_randomness(&s5);
        elg::ciphertext_equals(&acc, &ct5)
    }

    /// `add(ct(3), ct(2)) != sub(ct(3), ct(2))` — for distinct NON-ZERO `a`,
    /// `b`, the sum (`ct(5)`) and difference (`ct(1)`) must differ. Catches:
    /// `ciphertext_add` and `ciphertext_sub` that alias to the same
    /// implementation, or a toolchain miscompile where `point_sub` is
    /// inlined as `point_add`.
    public fun test_elg_ciphertext_add_sub_distinct_nonzero(): bool {
        let s3 = ristretto255::new_scalar_from_u64(3);
        let s2 = ristretto255::new_scalar_from_u64(2);
        let ct3 = elg::new_ciphertext_no_randomness(&s3);
        let ct2 = elg::new_ciphertext_no_randomness(&s2);
        let sum = elg::ciphertext_add(&ct3, &ct2);
        let diff = elg::ciphertext_sub(&ct3, &ct2);
        !elg::ciphertext_equals(&sum, &diff)
    }

    /// `compress_ciphertext` then `decompress_ciphertext` roundtrip equals
    /// the original for a non-zero plaintext. Already covered at zero and
    /// at `u64(42)`; this variant uses `u64(0xffff)` — the max 16-bit chunk
    /// value — and additionally verifies the compressed form serializes to
    /// **64 bytes**. Catches: compression bugs that silently lose
    /// information at chunk-boundary plaintexts.
    public fun test_elg_compress_decompress_ciphertext_0xffff_and_len(): bool {
        let v = ristretto255::new_scalar_from_u64(0xffff);
        let ct = elg::new_ciphertext_no_randomness(&v);
        let cct = elg::compress_ciphertext(&ct);
        let ct2 = elg::decompress_ciphertext(&cct);
        elg::ciphertext_equals(&ct, &ct2) &&
            elg::ciphertext_to_bytes(&ct2).length() == 64
    }

    /// `ciphertext_to_bytes(ct)` MUST emit `compress(left) || compress(right)`,
    /// in that order. For `ct = new_ciphertext_no_randomness(1)` we have
    /// `left = basepoint`, `right = identity`. Pinning the first 32 bytes to
    /// `basepoint_compressed()` catches: (i) a serializer that emits
    /// `right || left` (left/right swap) — identity compressed is all-zero,
    /// so bytes[0..32] would be zero instead of the basepoint; (ii) a
    /// serializer that only encodes one component.
    public fun test_elg_ciphertext_to_bytes_first_32_is_left_basepoint(): bool {
        let s1 = ristretto255::new_scalar_from_u64(1);
        let ct = elg::new_ciphertext_no_randomness(&s1);
        let bytes = elg::ciphertext_to_bytes(&ct);
        let first32 = bytes.slice(0, 32);
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        first32 == bp_bytes
    }

    /// Dual pin to `..._first_32_is_left_basepoint`: the LAST 32 bytes must
    /// equal the compressed identity (all-zero) because `right = identity`
    /// for a no-randomness ciphertext. Catches a serializer that duplicates
    /// `left` into both halves (some pathological copy-paste).
    public fun test_elg_ciphertext_to_bytes_last_32_is_right_identity(): bool {
        let s1 = ristretto255::new_scalar_from_u64(1);
        let ct = elg::new_ciphertext_no_randomness(&s1);
        let bytes = elg::ciphertext_to_bytes(&ct);
        let last32 = bytes.slice(32, 64);
        let id_bytes = ristretto255::compressed_point_to_bytes(ristretto255::point_identity_compressed());
        last32 == id_bytes
    }

    /// Dual pin for `new_ciphertext_from_bytes`: given 64 zero bytes (the
    /// canonical encoding of `(identity, identity)`), the decoded ciphertext
    /// must equal `new_ciphertext_no_randomness(0)`. Catches: deserializer
    /// that rejects valid identity encodings (the zero-plaintext path), or
    /// that silently swaps left/right (since both are identity here, a swap
    /// would be invisible — so this pin partners with the 0-plaintext
    /// algebra `ct_zero == ct_zero` NOT with swap detection; the swap
    /// detection is covered by the preceding two tests using distinct
    /// basepoint / identity halves).
    public fun test_elg_new_ciphertext_from_bytes_64_zero_is_identity_pair(): bool {
        let zero_bytes = vector[
            0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,
            0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,
            0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,
            0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,
            0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,
            0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,
            0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,
            0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,
        ];
        let opt = elg::new_ciphertext_from_bytes(zero_bytes);
        if (opt.is_none()) { return false };
        let ct = opt.extract();
        let zero = ristretto255::scalar_zero();
        let ct0 = elg::new_ciphertext_no_randomness(&zero);
        elg::ciphertext_equals(&ct, &ct0)
    }

    /// Stronger roundtrip pin for `new_ciphertext_from_bytes` / `ciphertext_to_bytes`
    /// using the basepoint / identity pair: build `bytes = basepoint_compressed || zeros32`,
    /// decode, re-encode, and assert byte equality. This catches a deserializer
    /// that silently normalizes to a different canonical encoding, or that
    /// has left/right-swap bugs which would only be invisible on identity-pair
    /// inputs.
    public fun test_elg_ciphertext_from_bytes_basepoint_left_identity_right_roundtrip_bytes(): bool {
        let bp_bytes = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let id_bytes = ristretto255::compressed_point_to_bytes(ristretto255::point_identity_compressed());
        let bytes = bp_bytes;
        bytes.append(id_bytes);
        let opt = elg::new_ciphertext_from_bytes(bytes);
        if (opt.is_none()) { return false };
        let ct = opt.extract();
        let bp_bytes2 = ristretto255::compressed_point_to_bytes(ristretto255::basepoint_compressed());
        let id_bytes2 = ristretto255::compressed_point_to_bytes(ristretto255::point_identity_compressed());
        let expected = bp_bytes2;
        expected.append(id_bytes2);
        elg::ciphertext_to_bytes(&ct) == expected
    }

    /// `ciphertext_from_points(left, right)` MUST distinguish the two
    /// argument positions. Build `ct_a = from_points(basepoint, identity)`
    /// and `ct_b = from_points(identity, basepoint)`; these are different
    /// ciphertexts. A regression that swaps the argument order or aliases
    /// both to the same field would make them equal. `ciphertext_equals`
    /// must return `false`.
    public fun test_elg_ciphertext_from_points_distinguishes_left_right(): bool {
        let bp = ristretto255::basepoint();
        let id = ristretto255::point_identity();
        let ct_a = elg::ciphertext_from_points(bp, id);
        let bp2 = ristretto255::basepoint();
        let id2 = ristretto255::point_identity();
        let ct_b = elg::ciphertext_from_points(id2, bp2);
        !elg::ciphertext_equals(&ct_a, &ct_b)
    }

    /// `ciphertext_from_compressed_points(left, right)` then decompress MUST
    /// preserve argument order. Build
    /// `ct_a = decompress(from_compressed_points(bp_compressed, identity_compressed))`
    /// — this should equal `new_ciphertext_no_randomness(1)` (since bp =
    /// 1·G and id encodes the zero-randomness right component). Catches a
    /// `ciphertext_from_compressed_points` that swaps left/right in the
    /// struct literal.
    public fun test_elg_from_compressed_points_preserves_order(): bool {
        let cct = elg::ciphertext_from_compressed_points(
            ristretto255::basepoint_compressed(),
            ristretto255::point_identity_compressed(),
        );
        let ct = elg::decompress_ciphertext(&cct);
        let s1 = ristretto255::new_scalar_from_u64(1);
        let ct1 = elg::new_ciphertext_no_randomness(&s1);
        elg::ciphertext_equals(&ct, &ct1)
    }

    /// `get_value_component(ct)` MUST return the SAME point as the first
    /// element of `ciphertext_into_points(ct)` for a NON-ZERO plaintext.
    /// Catches `get_value_component` returning `&ct.right` instead of
    /// `&ct.left` — a bug that is invisible when both components are
    /// identity (zero-plaintext, zero-randomness) but flips the result
    /// here.
    public fun test_elg_get_value_component_matches_into_points_left_nonzero(): bool {
        let v = ristretto255::new_scalar_from_u64(13);
        let ct = elg::new_ciphertext_no_randomness(&v);
        let ct2 = elg::new_ciphertext_no_randomness(&v);
        let gc = elg::get_value_component(&ct);
        let (left, _right) = elg::ciphertext_into_points(ct2);
        ristretto255::point_equals(gc, &left)
    }

    /// `ciphertext_equals(ct, ct) == true` for a NON-ZERO plaintext.
    /// Pairs with the non-equals tests to lock reflexivity at a non-trivial
    /// point (catches an `equals` implementation that always returns
    /// `false`, e.g., accidentally negated).
    public fun test_elg_ciphertext_equals_reflexive_nonzero(): bool {
        let v = ristretto255::new_scalar_from_u64(42);
        let ct1 = elg::new_ciphertext_no_randomness(&v);
        let ct2 = elg::new_ciphertext_no_randomness(&v);
        elg::ciphertext_equals(&ct1, &ct2)
    }

    /// Commutativity of `ciphertext_equals`: for two DISTINCT non-zero
    /// plaintexts, `equals(a, b) == equals(b, a)` (both must be `false`).
    /// Catches an asymmetric `equals` that only inspects `lhs` and ignores
    /// `rhs`.
    public fun test_elg_ciphertext_equals_commutative_on_distinct_nonzero(): bool {
        let s_a = ristretto255::new_scalar_from_u64(3);
        let s_b = ristretto255::new_scalar_from_u64(4);
        let a = elg::new_ciphertext_no_randomness(&s_a);
        let b = elg::new_ciphertext_no_randomness(&s_b);
        elg::ciphertext_equals(&a, &b) == elg::ciphertext_equals(&b, &a)
    }

    /// `pubkey_to_bytes(pk)` length MUST be 32 bytes — a Ristretto255
    /// compressed point. Catches a serializer that emits an
    /// uncompressed (64-byte) or prefixed encoding.
    public fun test_elg_pubkey_to_bytes_len_is_32(): bool {
        let bp = ristretto255::basepoint_compressed();
        let pk = elg::new_pubkey_from_bytes(
            ristretto255::compressed_point_to_bytes(bp)
        ).extract();
        elg::pubkey_to_bytes(&pk).length() == 32
    }

    // --- Phase E: `ciphertext_clone` + balance point-extraction ---
    //
    // Previously BLOCKED(harness) because `ristretto255::point_clone` was
    // gated on the on-chain `features::bulletproofs_enabled()` bit, which
    // the difftest harness did not set. Phase D.1 enabled
    // `BULLETPROOFS_NATIVES` (feature 24) and `BULLETPROOFS_BATCH_NATIVES`
    // (feature 87) in the harness `Features` resource, which unblocks
    // every transitive caller of `point_clone` — these rows are the
    // direct regression coverage at the ElGamal layer.

    /// `ciphertext_clone(ct)` must equal `ct` by `ciphertext_equals`. Tested
    /// on a NON-ZERO plaintext so a clone that returns the identity pair
    /// would flip the row. Also catches a clone that silently swaps
    /// `left`/`right`.
    public fun test_elg_ciphertext_clone_equals_original_nonzero(): bool {
        let s = ristretto255::new_scalar_from_u64(7);
        let ct = elg::new_ciphertext_no_randomness(&s);
        let cloned = elg::ciphertext_clone(&ct);
        elg::ciphertext_equals(&ct, &cloned)
    }

    /// `ciphertext_to_bytes(clone(ct)) == ciphertext_to_bytes(ct)` on
    /// NON-ZERO plaintext. Stronger than the `ciphertext_equals` check
    /// because it catches a clone that re-encodes a structurally-equal
    /// but byte-distinct representation (e.g. via a canonical
    /// re-encoding that drops subgroup cofactor information).
    public fun test_elg_ciphertext_clone_bytes_identical_nonzero(): bool {
        let s = ristretto255::new_scalar_from_u64(11);
        let ct = elg::new_ciphertext_no_randomness(&s);
        let cloned = elg::ciphertext_clone(&ct);
        elg::ciphertext_to_bytes(&ct) == elg::ciphertext_to_bytes(&cloned)
    }

    /// `ciphertext_clone` must produce a structurally-independent copy:
    /// mutating the original must NOT affect the clone. We clone
    /// `ct(2)`, then call `ciphertext_add_assign(&mut ct, ct(3))` on the
    /// original. Afterwards the original encrypts `5` and the clone
    /// must still encrypt `2`. A regression where `ciphertext_clone` is
    /// an alias (`*dst = *src`, or returns a wrong reference semantics
    /// equivalent) would let the mutation leak into the clone and
    /// `ciphertext_equals(&cloned, &ct(2))` would flip to false.
    public fun test_elg_ciphertext_clone_is_structurally_independent(): bool {
        let s2 = ristretto255::new_scalar_from_u64(2);
        let s3 = ristretto255::new_scalar_from_u64(3);
        let ct = elg::new_ciphertext_no_randomness(&s2);
        let cloned = elg::ciphertext_clone(&ct);
        elg::ciphertext_add_assign(&mut ct, &elg::new_ciphertext_no_randomness(&s3));
        elg::ciphertext_equals(&cloned, &elg::new_ciphertext_no_randomness(&s2))
    }

    /// Clone of the identity / zero ciphertext equals itself AND encodes
    /// to 64 all-zero bytes. Pins the boundary case for `point_clone` on
    /// the identity point.
    public fun test_elg_ciphertext_clone_zero_encodes_all_zero(): bool {
        let zero = ristretto255::scalar_zero();
        let ct = elg::new_ciphertext_no_randomness(&zero);
        let cloned = elg::ciphertext_clone(&ct);
        let bytes = elg::ciphertext_to_bytes(&cloned);
        let i = 0;
        let n = bytes.length();
        let all_zero = n == 64;
        while (i < n) {
            if (*bytes.borrow(i) != 0u8) { all_zero = false; };
            i = i + 1;
        };
        all_zero && elg::ciphertext_equals(&ct, &cloned)
    }

    //
    // Non-canonical byte rejection pins for public constructors. The existing
    // `test_elg_{ciphertext_from_{63,65}_bytes,pubkey_from_{empty,short,31}_bytes}_is_none`
    // rows cover wrong-LENGTH inputs; these rows cover the orthogonal class of
    // regressions where the length is correct but one or both 32-byte windows
    // are non-canonical point encodings. A future "optimization" that skipped
    // the underlying `ristretto255::new_point_from_bytes` canonicality check
    // would silently lift arbitrary 32-byte blobs into `Ciphertext` /
    // `CompressedPubkey`, breaking the encoding uniqueness that the
    // protocol's soundness rests on. The all-`0xff` pattern is guaranteed
    // non-canonical (high bit set, violates Ristretto255 canonical form).
    //

    /// 64-byte length OK, left (first-32) non-canonical ⇒ `None`.
    public fun test_elg_ciphertext_from_64_bytes_noncanonical_left_is_none(): bool {
        let v = vector::empty<u8>();
        let i = 0;
        while (i < 32) { v.push_back(0xffu8); i = i + 1; };
        while (i < 64) { v.push_back(0u8); i = i + 1; };
        option::is_none(&elg::new_ciphertext_from_bytes(v))
    }

    /// 64-byte length OK, right (last-32) non-canonical ⇒ `None`. Catches a
    /// regression where only the LEFT half's canonical check survives (e.g.
    /// the right-half parse was accidentally moved under the success arm).
    public fun test_elg_ciphertext_from_64_bytes_noncanonical_right_is_none(): bool {
        let v = vector::empty<u8>();
        let i = 0;
        while (i < 32) { v.push_back(0u8); i = i + 1; };
        while (i < 64) { v.push_back(0xffu8); i = i + 1; };
        option::is_none(&elg::new_ciphertext_from_bytes(v))
    }

    /// 64-byte length OK, both halves non-canonical ⇒ `None`.
    public fun test_elg_ciphertext_from_64_bytes_both_noncanonical_is_none(): bool {
        let v = vector::empty<u8>();
        let i = 0;
        while (i < 64) { v.push_back(0xffu8); i = i + 1; };
        option::is_none(&elg::new_ciphertext_from_bytes(v))
    }

    /// 32-byte length OK for a pubkey, but the encoding is non-canonical
    /// (`0xff * 32` — high bit set) ⇒ `None`. Catches dropping
    /// `new_compressed_point_from_bytes`'s canonicality check inside
    /// `new_pubkey_from_bytes`.
    public fun test_elg_pubkey_from_32_bytes_noncanonical_is_none(): bool {
        let v = vector::empty<u8>();
        let i = 0;
        while (i < 32) { v.push_back(0xffu8); i = i + 1; };
        option::is_none(&elg::new_pubkey_from_bytes(v))
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
            (
                "test_elg_ciphertext_as_points_compress_equals_to_bytes",
                "as_points",
            ),
            (
                "test_elg_ciphertext_from_compressed_points_roundtrip",
                "from_c_pts",
            ),
            ("test_elg_ciphertext_one_not_equal_zero", "neq_1_0"),
            (
                "test_elg_ciphertext_one_bytes_differ_from_zero_bytes",
                "bytes_neq_1_0",
            ),
            (
                "test_elg_ciphertext_add_one_plus_zero_equals_one",
                "add_1_0",
            ),
            (
                "test_elg_ciphertext_add_one_plus_two_equals_three",
                "add_1_2_3",
            ),
            ("test_elg_ciphertext_sub_one_from_one_is_zero", "sub_1_1_0"),
            (
                "test_elg_ciphertext_sub_three_minus_two_equals_one",
                "sub_3_2_1",
            ),
            (
                "test_elg_ciphertext_sub_assign_on_nonzero_matches_sub",
                "sub_assign_nz",
            ),
            (
                "test_elg_compress_decompress_nonzero_ciphertext_roundtrips",
                "cmp_nz",
            ),
            (
                "test_elg_get_value_component_nonzero_matches_basepoint_mul",
                "gc_nz",
            ),
            (
                "test_elg_ciphertext_to_bytes_roundtrip_nonzero",
                "btrt_nz",
            ),
            (
                "test_elg_ciphertext_add_associative_nonzero",
                "add_assoc_nz",
            ),
            (
                "test_elg_ciphertext_add_commutative_nonzero",
                "add_comm_nz",
            ),
            (
                "test_elg_ciphertext_sub_assign_self_is_zero_nonzero",
                "sub_assign_self_nz",
            ),
            (
                "test_elg_ciphertext_add_assign_one_plus_two_equals_three",
                "add_assign_1_2_3",
            ),
            (
                "test_elg_ciphertext_add_then_sub_recovers_original_nonzero",
                "add_sub_rt_nz",
            ),
            (
                "test_elg_ciphertext_to_bytes_len_64_nonzero",
                "b64_nz",
            ),
            (
                "test_elg_get_value_component_not_identity_when_v_nonzero",
                "gc_neq_id_nz",
            ),
            (
                "test_elg_ciphertext_sub_not_commutative_on_distinct_nonzero",
                "sub_non_comm_nz",
            ),
            (
                "test_elg_ciphertext_sub_five_minus_three_equals_two_nonzero",
                "sub_5_3_2",
            ),
            (
                "test_elg_ciphertext_add_assign_accumulates_three_nonzero",
                "add_assign_acc3_nz",
            ),
            (
                "test_elg_ciphertext_sub_assign_chain_nonzero",
                "sub_assign_chain_nz",
            ),
            (
                "test_elg_ciphertext_add_sub_distinct_nonzero",
                "add_neq_sub_nz",
            ),
            (
                "test_elg_compress_decompress_ciphertext_0xffff_and_len",
                "cmp_0xffff_len",
            ),
            (
                "test_elg_ciphertext_to_bytes_first_32_is_left_basepoint",
                "b64_first32_bp",
            ),
            (
                "test_elg_ciphertext_to_bytes_last_32_is_right_identity",
                "b64_last32_id",
            ),
            (
                "test_elg_new_ciphertext_from_bytes_64_zero_is_identity_pair",
                "from_zero64_id",
            ),
            (
                "test_elg_ciphertext_from_bytes_basepoint_left_identity_right_roundtrip_bytes",
                "from_bp_id_rt",
            ),
            (
                "test_elg_ciphertext_from_points_distinguishes_left_right",
                "from_pts_lr",
            ),
            (
                "test_elg_from_compressed_points_preserves_order",
                "from_cpts_ord",
            ),
            (
                "test_elg_get_value_component_matches_into_points_left_nonzero",
                "gc_ip_match_nz",
            ),
            (
                "test_elg_ciphertext_equals_reflexive_nonzero",
                "eq_refl_nz",
            ),
            (
                "test_elg_ciphertext_equals_commutative_on_distinct_nonzero",
                "eq_comm_nz",
            ),
            (
                "test_elg_pubkey_to_bytes_len_is_32",
                "pk_len_32",
            ),
            (
                "test_elg_ciphertext_clone_equals_original_nonzero",
                "clone_eq_nz",
            ),
            (
                "test_elg_ciphertext_clone_bytes_identical_nonzero",
                "clone_bytes_nz",
            ),
            (
                "test_elg_ciphertext_clone_is_structurally_independent",
                "clone_indep",
            ),
            (
                "test_elg_ciphertext_clone_zero_encodes_all_zero",
                "clone_zero_bytes",
            ),
            (
                "test_elg_ciphertext_from_64_bytes_noncanonical_left_is_none",
                "ct_nc_left_none",
            ),
            (
                "test_elg_ciphertext_from_64_bytes_noncanonical_right_is_none",
                "ct_nc_right_none",
            ),
            (
                "test_elg_ciphertext_from_64_bytes_both_noncanonical_is_none",
                "ct_nc_both_none",
            ),
            (
                "test_elg_pubkey_from_32_bytes_noncanonical_is_none",
                "pk_nc_none",
            ),
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

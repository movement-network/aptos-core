#[test_only]
/// Move-side evidence for `RistrettoGroupAxioms` (§6.2 of `REGISTRATION_VERIFY_REVIEW.md`).
///
/// Tests group-law properties of `aptos_std::ristretto255` that the Lean formalization
/// assumes via `RistrettoGroupAxioms` in `GroupAxioms.lean`. Passing these tests does
/// **not** replace a full correctness proof of the Ristretto natives, but provides
/// concrete evidence that the axioms hold for this branch's implementation.
module aptos_experimental::formal_goldens_ristretto {
    use aptos_std::ristretto255;

    // point_mul(H, 1) == H — scalar 1 is the identity action.
    #[test]
    fun golden_scalar_mul_one() {
        let h = ristretto255::hash_to_point_base();
        let one = ristretto255::new_scalar_from_u64(1);
        let result = ristretto255::point_mul(&h, &one);
        assert!(ristretto255::point_equals(&result, &h), 0);
    }

    // `point_mul(H, 0) == identity` — scalar 0 annihilates.
    #[test]
    fun golden_scalar_mul_zero() {
        let h = ristretto255::hash_to_point_base();
        let zero = ristretto255::new_scalar_from_u64(0);
        let result = ristretto255::point_mul(&h, &zero);
        let identity = ristretto255::point_identity();
        assert!(ristretto255::point_equals(&result, &identity), 0);
    }

    // `point_add(H, H) == point_mul(H, 2)` — addition is repeated multiplication.
    #[test]
    fun golden_point_add_equals_double() {
        let h = ristretto255::hash_to_point_base();
        let two = ristretto255::new_scalar_from_u64(2);
        let doubled = ristretto255::point_mul(&h, &two);
        let sum = ristretto255::point_add(&h, &h);
        assert!(ristretto255::point_equals(&doubled, &sum), 0);
    }

    // `point_mul(H, a) + point_mul(H, b) == point_mul(H, a+b)` — distributivity.
    #[test]
    fun golden_scalar_distributivity() {
        let h = ristretto255::hash_to_point_base();
        let a = ristretto255::new_scalar_from_u64(42);
        let b = ristretto255::new_scalar_from_u64(58);
        let ab = ristretto255::scalar_add(&a, &b);
        let pa = ristretto255::point_mul(&h, &a);
        let pb = ristretto255::point_mul(&h, &b);
        let sum = ristretto255::point_add(&pa, &pb);
        let direct = ristretto255::point_mul(&h, &ab);
        assert!(ristretto255::point_equals(&sum, &direct), 0);
    }

    // `point_equals(H, H)` — equality is reflexive.
    #[test]
    fun golden_point_equals_reflexive() {
        let h = ristretto255::hash_to_point_base();
        assert!(ristretto255::point_equals(&h, &h), 0);
    }

    // `point_add(H, identity) == H` — identity element.
    #[test]
    fun golden_point_add_identity() {
        let h = ristretto255::hash_to_point_base();
        let identity = ristretto255::point_identity();
        let result = ristretto255::point_add(&h, &identity);
        assert!(ristretto255::point_equals(&result, &h), 0);
    }

    // Commutativity: `point_add(A, B) == point_add(B, A)` for distinct points.
    #[test]
    fun golden_point_add_commutative() {
        let h = ristretto255::hash_to_point_base();
        let bp = ristretto255::basepoint();
        let ab = ristretto255::point_add(&h, &bp);
        let ba = ristretto255::point_add(&bp, &h);
        assert!(ristretto255::point_equals(&ab, &ba), 0);
    }

    // `point_mul(point_mul(H, a), b) == point_mul(H, a*b)` — associativity of scalar action.
    #[test]
    fun golden_scalar_mul_associative() {
        let h = ristretto255::hash_to_point_base();
        let a = ristretto255::new_scalar_from_u64(7);
        let b = ristretto255::new_scalar_from_u64(13);
        let ab = ristretto255::scalar_mul(&a, &b);
        let step = ristretto255::point_mul(&h, &a);
        let double_mul = ristretto255::point_mul(&step, &b);
        let direct = ristretto255::point_mul(&h, &ab);
        assert!(ristretto255::point_equals(&double_mul, &direct), 0);
    }
}

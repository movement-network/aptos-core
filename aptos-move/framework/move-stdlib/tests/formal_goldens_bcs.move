#[test_only]
/// Curated BCS bytes for Lean `AptosFormal.Std.Bcs` alignment (`MoveStdlibGoldens.lean`).
/// Overlaps `bcs_tests.move`; separate file avoids editing existing tests.
module std::formal_goldens_bcs {
    use std::bcs;

    #[test]
    fun golden_bcs_bool_true() {
        assert!(bcs::to_bytes(&true) == x"01", 0);
    }

    #[test]
    fun golden_bcs_bool_false() {
        assert!(bcs::to_bytes(&false) == x"00", 0);
    }

    #[test]
    fun golden_bcs_u8_one() {
        assert!(bcs::to_bytes(&1u8) == x"01", 0);
    }

    #[test]
    fun golden_bcs_u64_one() {
        assert!(bcs::to_bytes(&1u64) == x"0100000000000000", 0);
    }

    #[test]
    fun golden_bcs_u128_one() {
        assert!(bcs::to_bytes(&1u128) == x"01000000000000000000000000000000", 0);
    }

    #[test]
    fun golden_bcs_vec_u8_singleton() {
        let v = x"0f";
        assert!(bcs::to_bytes(&v) == x"010f", 0);
    }

    #[test]
    fun golden_bcs_vec_u8_empty() {
        let v = x"";
        assert!(bcs::to_bytes(&v) == x"00", 0);
    }
}

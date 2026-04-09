#[test_only]
/// BCS encoding goldens for `address` values (§6.3 of `REGISTRATION_VERIFY_REVIEW.md`).
///
/// Validates that `std::bcs::to_bytes` on Aptos addresses produces 32 raw bytes
/// (no length prefix) matching the layout assumed by the Lean `AptosAddress32` model
/// in `VerifyMath.lean` and the transcript alignment in `TranscriptAlignment.lean`.
module std::formal_goldens_bcs_address {
    use std::bcs;

    #[test]
    fun golden_bcs_address_0x1() {
        let addr = @0x1;
        let bytes = bcs::to_bytes(&addr);
        assert!(bytes.length() == 32, 0);
        let expected = x"0000000000000000000000000000000000000000000000000000000000000001";
        assert!(bytes == expected, 1);
    }

    #[test]
    fun golden_bcs_address_0x2() {
        let addr = @0x2;
        let bytes = bcs::to_bytes(&addr);
        let expected = x"0000000000000000000000000000000000000000000000000000000000000002";
        assert!(bytes == expected, 0);
    }

    #[test]
    fun golden_bcs_address_0x3() {
        let addr = @0x3;
        let bytes = bcs::to_bytes(&addr);
        let expected = x"0000000000000000000000000000000000000000000000000000000000000003";
        assert!(bytes == expected, 0);
    }

    #[test]
    fun golden_bcs_address_0x10() {
        let addr = @0x10;
        let bytes = bcs::to_bytes(&addr);
        assert!(bytes.length() == 32, 0);
        let expected = x"0000000000000000000000000000000000000000000000000000000000000010";
        assert!(bytes == expected, 1);
    }

    #[test]
    fun golden_bcs_address_0x20() {
        let addr = @0x20;
        let bytes = bcs::to_bytes(&addr);
        let expected = x"0000000000000000000000000000000000000000000000000000000000000020";
        assert!(bytes == expected, 0);
    }

    #[test]
    fun golden_bcs_address_0x30() {
        let addr = @0x30;
        let bytes = bcs::to_bytes(&addr);
        let expected = x"0000000000000000000000000000000000000000000000000000000000000030";
        assert!(bytes == expected, 0);
    }

    #[test]
    fun golden_bcs_address_max() {
        let addr = @0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        let bytes = bcs::to_bytes(&addr);
        assert!(bytes.length() == 32, 0);
        let expected = x"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
        assert!(bytes == expected, 1);
    }
}

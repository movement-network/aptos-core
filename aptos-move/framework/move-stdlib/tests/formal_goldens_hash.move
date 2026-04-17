#[test_only]
/// Curated digests for Lean `MovementFormal` alignment (`MoveStd.Hash.Sha3_256` / future SHA2-256).
/// Same values as `hash_tests.move`; kept in a separate module so we do not edit existing tests.
module std::formal_goldens_hash {
    use std::hash;

    #[test]
    fun golden_sha2_256_abc() {
        let input = x"616263";
        let expected_output = x"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        assert!(hash::sha2_256(input) == expected_output, 0);
    }

    #[test]
    fun golden_sha3_256_abc() {
        let input = x"616263";
        let expected_output = x"3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532";
        assert!(hash::sha3_256(input) == expected_output, 0);
    }

    #[test]
    fun golden_sha3_256_empty() {
        let input = x"";
        let expected_output =
            x"a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a";
        assert!(hash::sha3_256(input) == expected_output, 0);
    }
}

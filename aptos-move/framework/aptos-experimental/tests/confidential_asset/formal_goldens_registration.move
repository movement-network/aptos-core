#[test_only]
/// Goldens for Lean `MovementFormal` registration transcript alignment (`verify_registration_proof` FS `msg`).
module aptos_experimental::formal_goldens_registration {
    use aptos_experimental::confidential_proof;
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;
    use aptos_std::ristretto255;

    #[test]
    fun golden_registration_fs_message_matches_expected_bytes() {
        let chain_id = 9u8;
        let sender = @0x1;
        let contract_address = @0x2;
        let token_address = @0x3;
        let bp = ristretto255::basepoint_compressed();
        let ek_bytes = ristretto255::compressed_point_to_bytes(bp);
        let ek = twisted_elgamal::new_pubkey_from_bytes(ek_bytes).extract();
        let r_bytes = ek_bytes;
        let msg = confidential_proof::registration_fs_message_for_test(
            chain_id,
            sender,
            contract_address,
            token_address,
            &ek,
            r_bytes,
        );
        assert!(msg.length() == 199, 0);
        let expected =
            x"4d6f76656d656e74436f6e666964656e7469616c41737365742f526567697374726174696f6e09000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76";
        assert!(msg == expected, 1);
    }

    #[test]
    fun golden_registration_fs_message_second_scenario() {
        let chain_id = 42u8;
        let sender = @0x10;
        let contract_address = @0x20;
        let token_address = @0x30;
        let bp = ristretto255::basepoint_compressed();
        let ek_bytes = ristretto255::compressed_point_to_bytes(bp);
        let ek = twisted_elgamal::new_pubkey_from_bytes(ek_bytes).extract();
        let r_bytes = ek_bytes;
        let msg = confidential_proof::registration_fs_message_for_test(
            chain_id,
            sender,
            contract_address,
            token_address,
            &ek,
            r_bytes,
        );
        assert!(msg.length() == 199, 0);
        let expected =
            x"4d6f76656d656e74436f6e666964656e7469616c41737365742f526567697374726174696f6e2a000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76";
        assert!(msg == expected, 1);
    }
}

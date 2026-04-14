#[test_only]
module aptos_experimental::confidential_asset_tests {
    use std::features;
    use std::option;
    use std::signer;
    use std::string::utf8;
    use aptos_std::ristretto255::Scalar;
    use aptos_framework::account;
    use aptos_framework::chain_id;
    use aptos_framework::coin;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;

    use aptos_experimental::confidential_asset;
    use aptos_experimental::confidential_balance;
    use aptos_experimental::confidential_proof;
    use aptos_experimental::ristretto255_twisted_elgamal::{Self as twisted_elgamal, generate_twisted_elgamal_keypair};

    struct MockCoin {}

    fun withdraw(
        sender: &signer,
        sender_dk: &Scalar,
        token: Object<Metadata>,
        to: address,
        amount: u64,
        new_amount: u128)
    {
        let from = signer::address_of(sender);
        let sender_ek = confidential_asset::encryption_key(from, token);
        let current_balance = confidential_balance::decompress_balance(
            &confidential_asset::actual_balance(from, token)
        );

        let cid = 4u8; // test chain ID
        let (proof, new_balance) = confidential_proof::prove_withdrawal(
            cid,
            from,
            @aptos_experimental,
            sender_dk,
            &sender_ek,
            amount,
            new_amount,
            &current_balance
        );

        let new_balance = confidential_balance::balance_to_bytes(&new_balance);
        let (sigma_proof, zkrp_new_balance) = confidential_proof::serialize_withdrawal_proof(&proof);

        if (signer::address_of(sender) == to) {
            confidential_asset::withdraw(sender, token, amount, new_balance, zkrp_new_balance, sigma_proof);
        } else {
            confidential_asset::withdraw_to(sender, token, to, amount, new_balance, zkrp_new_balance, sigma_proof);
        }
    }

    fun transfer(
        sender: &signer,
        sender_dk: &Scalar,
        token: Object<Metadata>,
        to: address,
        amount: u64,
        new_amount: u128,
        sender_auditor_hint: vector<u8>)
    {
        let from = signer::address_of(sender);
        let sender_ek = confidential_asset::encryption_key(from, token);
        let recipient_ek = confidential_asset::encryption_key(to, token);
        let current_balance = confidential_balance::decompress_balance(
            &confidential_asset::actual_balance(from, token)
        );

        let (
            proof,
            new_balance,
            sender_amount,
            recipient_amount,
            _
        ) = confidential_proof::prove_transfer(
            4u8, // test chain ID
            from,
            @aptos_experimental,
            sender_dk,
            &sender_ek,
            &recipient_ek,
            amount,
            new_amount,
            &current_balance,
            &vector[],
            sender_auditor_hint,
        );

        let (sigma_proof, zkrp_new_balance, zkrp_transfer_amount) = confidential_proof::serialize_transfer_proof(
            &proof
        );

        confidential_asset::confidential_transfer(
            sender,
            token,
            to,
            confidential_balance::balance_to_bytes(&new_balance),
            confidential_balance::balance_to_bytes(&sender_amount),
            confidential_balance::balance_to_bytes(&recipient_amount),
            b"",
            b"",
            zkrp_new_balance,
            zkrp_transfer_amount,
            sigma_proof,
            sender_auditor_hint
        );
    }

    fun audit_transfer(
        sender: &signer,
        sender_dk: &Scalar,
        token: Object<Metadata>,
        to: address,
        amount: u64,
        new_amount: u128,
        auditor_eks: &vector<twisted_elgamal::CompressedPubkey>,
        sender_auditor_hint: vector<u8>): vector<confidential_balance::ConfidentialBalance>
    {
        let from = signer::address_of(sender);
        let sender_ek = confidential_asset::encryption_key(from, token);
        let recipient_ek = confidential_asset::encryption_key(to, token);
        let current_balance = confidential_balance::decompress_balance(
            &confidential_asset::actual_balance(from, token)
        );

        let (
            proof,
            new_balance,
            sender_amount,
            recipient_amount,
            auditor_amounts
        ) = confidential_proof::prove_transfer(
            4u8, // test chain ID
            from,
            @aptos_experimental,
            sender_dk,
            &sender_ek,
            &recipient_ek,
            amount,
            new_amount,
            &current_balance,
            auditor_eks,
            sender_auditor_hint,
        );

        let (sigma_proof, zkrp_new_balance, zkrp_transfer_amount) = confidential_proof::serialize_transfer_proof(
            &proof
        );

        confidential_asset::confidential_transfer(
            sender,
            token,
            to,
            confidential_balance::balance_to_bytes(&new_balance),
            confidential_balance::balance_to_bytes(&sender_amount),
            confidential_balance::balance_to_bytes(&recipient_amount),
            confidential_asset::serialize_auditor_eks(auditor_eks),
            confidential_asset::serialize_auditor_amounts(&auditor_amounts),
            zkrp_new_balance,
            zkrp_transfer_amount,
            sigma_proof,
            sender_auditor_hint
        );

        auditor_amounts
    }

    fun rotate(
        sender: &signer,
        sender_dk: &Scalar,
        token: Object<Metadata>,
        new_dk: &Scalar,
        new_ek: &twisted_elgamal::CompressedPubkey,
        amount: u128)
    {
        let from = signer::address_of(sender);
        let sender_ek = confidential_asset::encryption_key(from, token);
        let current_balance = confidential_balance::decompress_balance(
            &confidential_asset::actual_balance(from, token)
        );

        let (proof, new_balance) = confidential_proof::prove_rotation(
            4u8, // test chain ID
            from,
            @aptos_experimental,
            sender_dk,
            new_dk,
            &sender_ek,
            new_ek,
            amount,
            &current_balance
        );

        let (sigma_proof, zkrp_new_balance) = confidential_proof::serialize_rotation_proof(&proof);

        confidential_asset::rotate_encryption_key(
            sender,
            token,
            twisted_elgamal::pubkey_to_bytes(new_ek),
            confidential_balance::balance_to_bytes(&new_balance),
            zkrp_new_balance,
            sigma_proof
        );
    }

    fun normalize(
        sender: &signer,
        sender_dk: &Scalar,
        token: Object<Metadata>,
        amount: u128)
    {
        let from = signer::address_of(sender);
        let sender_ek = confidential_asset::encryption_key(from, token);
        let current_balance = confidential_balance::decompress_balance(
            &confidential_asset::actual_balance(from, token)
        );

        let (proof, new_balance) = confidential_proof::prove_normalization(
            4u8, // test chain ID
            from,
            @aptos_experimental,
            sender_dk,
            &sender_ek,
            amount,
            &current_balance);

        let (sigma_proof, zkrp_new_balance) = confidential_proof::serialize_normalization_proof(&proof);

        confidential_asset::normalize(
            sender,
            token,
            confidential_balance::balance_to_bytes(&new_balance),
            zkrp_new_balance,
            sigma_proof
        );
    }

    public fun set_up_for_confidential_asset_test(
        confidential_asset: &signer,
        aptos_fx: &signer,
        fa: &signer,
        sender: &signer,
        recipient: &signer,
        sender_amount: u64,
        recipient_amount: u64): Object<Metadata>
    {
        chain_id::initialize_for_test(aptos_fx, 4);

        let ctor_ref = &object::create_sticky_object(signer::address_of(fa));

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            ctor_ref,
            option::none(),
            utf8(b"MockToken"),
            utf8(b"MT"),
            18,
            utf8(b"https://"),
            utf8(b"https://"),
        );

        let mint_ref = fungible_asset::generate_mint_ref(ctor_ref);

        assert!(signer::address_of(aptos_fx) != signer::address_of(sender), 1);
        assert!(signer::address_of(aptos_fx) != signer::address_of(recipient), 2);

        confidential_asset::init_module_for_testing(confidential_asset);

        features::change_feature_flags_for_testing(aptos_fx, vector[features::get_bulletproofs_feature()], vector[]);

        let token = object::object_from_constructor_ref<Metadata>(ctor_ref);

        let sender_store = primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), token);
        fungible_asset::mint_to(&mint_ref, sender_store, sender_amount);

        let recipient_store = primary_fungible_store::ensure_primary_store_exists(signer::address_of(recipient), token);
        fungible_asset::mint_to(&mint_ref, recipient_store, recipient_amount);

        token
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_deposit_test(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (bob_dk, bob_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        confidential_asset::deposit(&alice, token, 100);
        confidential_asset::deposit_to(&alice, token, bob_addr, 150);

        assert!(primary_fungible_store::balance(alice_addr, token) == 250, 1);
        assert!(confidential_asset::verify_pending_balance(alice_addr, token, &alice_dk, 100), 1);
        assert!(confidential_asset::verify_pending_balance(bob_addr, token, &bob_dk, 150), 1);
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_withdraw_test(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        withdraw(&alice, &alice_dk, token, bob_addr, 50, 150);

        assert!(primary_fungible_store::balance(bob_addr, token) == 550, 1);
        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 150), 1);

        withdraw(&alice, &alice_dk, token, alice_addr, 50, 100);

        assert!(primary_fungible_store::balance(alice_addr, token) == 350, 1);
        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 100), 1);
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_transfer_test(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (bob_dk, bob_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        transfer(&alice, &alice_dk, token, bob_addr, 100, 100, vector[]);

        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 100), 1);
        assert!(confidential_asset::verify_pending_balance(bob_addr, token, &bob_dk, 100), 1);

        transfer(&alice, &alice_dk, token, alice_addr, 100, 0, vector[]);

        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 0), 1);
        assert!(confidential_asset::verify_pending_balance(alice_addr, token, &alice_dk, 100), 1);
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun transferred_event_matches_on_chain_balances(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_, bob_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        let hint = vector[0x01u8, 0x77u8, 0x61u8]; // arbitrary opaque bytes ("wa" with prefix)
        transfer(&alice, &alice_dk, token, bob_addr, 100, 100, hint);
        confidential_asset::assert_last_transferred_event_matches_state(
            token,
            alice_addr,
            bob_addr,
            0,
            hint
        );
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_audit_transfer_test(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (bob_dk, bob_ek) = generate_twisted_elgamal_keypair();
        let (auditor1_dk, auditor1_ek) = generate_twisted_elgamal_keypair();
        let (auditor2_dk, auditor2_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::set_auditor(
            &aptos_fx,
            token,
            twisted_elgamal::pubkey_to_bytes(&auditor1_ek));

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        let auditor_amounts = audit_transfer(
            &alice,
            &alice_dk,
            token,
            bob_addr,
            100,
            100,
            &vector[auditor1_ek, auditor2_ek],
            vector[]);

        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 100), 1);
        assert!(confidential_asset::verify_pending_balance(bob_addr, token, &bob_dk, 100), 1);

        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[0], &auditor1_dk, 100), 1);
        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[1], &auditor2_dk, 100), 1);
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun transferred_event_matches_on_chain_balances_audited(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (bob_dk, bob_ek) = generate_twisted_elgamal_keypair();
        let (auditor1_dk, auditor1_ek) = generate_twisted_elgamal_keypair();
        let (auditor2_dk, auditor2_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::set_auditor(
            &aptos_fx,
            token,
            twisted_elgamal::pubkey_to_bytes(&auditor1_ek));

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        let hint = vector[0xabu8, 0xcdu8];
        let auditor_amounts = audit_transfer(
            &alice,
            &alice_dk,
            token,
            bob_addr,
            100,
            100,
            &vector[auditor1_ek, auditor2_ek],
            hint);

        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 100), 1);
        assert!(confidential_asset::verify_pending_balance(bob_addr, token, &bob_dk, 100), 1);
        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[0], &auditor1_dk, 100), 2);
        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[1], &auditor2_dk, 100), 3);

        confidential_asset::assert_last_transferred_event_matches_state(
            token,
            alice_addr,
            bob_addr,
            2,
            hint
        );
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    #[expected_failure(abort_code = 0x010006, location = confidential_asset)]
    fun fail_audit_transfer_if_wrong_auditor_list(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_, bob_ek) = generate_twisted_elgamal_keypair();
        let (_, auditor1_ek) = generate_twisted_elgamal_keypair();
        let (_, auditor2_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::set_auditor(
            &aptos_fx,
            token,
            twisted_elgamal::pubkey_to_bytes(&auditor1_ek));

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        // This fails because the `auditor1` is set for `token`,
        // so each transfer must include `auditor1` in the auditor list as the FIRST element.
        // Please, see `confidential_asset::validate_auditors` for more details.
        audit_transfer(
            &alice,
            &alice_dk,
            token,
            bob_addr,
            100,
            100,
            &vector[auditor2_ek, auditor1_ek],
            vector[]);
    }

    fun oversized_auditor_hint(): vector<u8> {
        let max = confidential_asset::max_sender_auditor_hint_bytes();
        let v = vector[];
        let i = 0u64;
        while (i <= max) {
            v.push_back(0u8);
            i = i + 1;
        };
        v
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    #[expected_failure(abort_code = 0x010012, location = confidential_asset)]
    fun fail_transfer_if_auditor_hint_too_long(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_, bob_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        transfer(&alice, &alice_dk, token, bob_addr, 100, 100, oversized_auditor_hint());
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_rotate(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        withdraw(&alice, &alice_dk, token, bob_addr, 50, 150);

        let (new_alice_dk, new_alice_ek) = generate_twisted_elgamal_keypair();

        rotate(&alice, &alice_dk, token, &new_alice_dk, &new_alice_ek, 150);

        assert!(confidential_asset::encryption_key(alice_addr, token) == new_alice_ek, 1);
        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &new_alice_dk, 150), 1);
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_normalize(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let max_chunk_value = 1 << 16 - 1;
        let token = set_up_for_confidential_asset_test(
            &confidential_asset,
            &aptos_fx,
            &fa,
            &alice,
            &bob,
            max_chunk_value,
            max_chunk_value
        );

        let alice_addr = signer::address_of(&alice);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        confidential_asset::deposit(&alice, token, max_chunk_value);
        confidential_asset::deposit_to(&bob, token, alice_addr, max_chunk_value);

        confidential_asset::rollover_pending_balance(&alice, token);

        assert!(!confidential_asset::is_normalized(alice_addr, token));
        assert!(
            !confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, (2 * max_chunk_value as u128)),
            1
        );

        normalize(&alice, &alice_dk, token, (2 * max_chunk_value as u128));

        assert!(confidential_asset::is_normalized(alice_addr, token));
        assert!(
            confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, (2 * max_chunk_value as u128)), 1);
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun events_balance_changing_operations(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let max_chunk_value = 1 << 16 - 1;
        let token = set_up_for_confidential_asset_test(
            &confidential_asset, &aptos_fx, &fa, &alice, &bob, max_chunk_value, max_chunk_value);

        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_, bob_ek) = generate_twisted_elgamal_keypair();

        // --- register emits Registered ---
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::assert_last_registered_event(token, alice_addr);

        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));
        confidential_asset::assert_last_registered_event(token, bob_addr);

        // --- deposit emits Deposited with new_pending_balance ---
        confidential_asset::deposit(&alice, token, 100);
        confidential_asset::assert_last_deposited_event_matches_state(token, alice_addr, 100);

        confidential_asset::deposit_to(&bob, token, alice_addr, 200);
        confidential_asset::assert_last_deposited_event_matches_state(token, alice_addr, 200);

        // --- rollover emits RolledOver with new_available_balance ---
        confidential_asset::rollover_pending_balance(&alice, token);
        confidential_asset::assert_last_rolled_over_event_matches_state(token, alice_addr);

        // --- normalize emits Normalized with new_available_balance ---
        assert!(!confidential_asset::is_normalized(alice_addr, token));
        normalize(&alice, &alice_dk, token, 300);
        confidential_asset::assert_last_normalized_event_matches_state(token, alice_addr);

        // --- withdraw emits Withdrawn with new_available_balance ---
        withdraw(&alice, &alice_dk, token, bob_addr, 50, 250);
        confidential_asset::assert_last_withdrawn_event_matches_state(token, alice_addr, 50);

        // --- freeze / unfreeze emits FreezeChanged ---
        confidential_asset::rollover_pending_balance_and_freeze(&alice, token);
        confidential_asset::assert_last_freeze_changed_event(token, alice_addr, true);

        // --- rotate emits KeyRotated with new_ek and new_available_balance ---
        let (new_alice_dk, new_alice_ek) = generate_twisted_elgamal_keypair();
        rotate(&alice, &alice_dk, token, &new_alice_dk, &new_alice_ek, 250);
        confidential_asset::assert_last_key_rotated_event_matches_state(token, alice_addr);

        // --- unfreeze emits FreezeChanged ---
        confidential_asset::unfreeze_token(&alice, token);
        confidential_asset::assert_last_freeze_changed_event(token, alice_addr, false);
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun events_admin_operations(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        // --- enable_allow_list emits AllowListChanged ---
        confidential_asset::enable_allow_list(&aptos_fx);
        confidential_asset::assert_last_allow_list_changed_event(true);

        // --- enable_token emits TokenAllowChanged ---
        confidential_asset::enable_token(&aptos_fx, token);
        confidential_asset::assert_last_token_allow_changed_event(token, true);

        // --- disable_token emits TokenAllowChanged ---
        confidential_asset::disable_token(&aptos_fx, token);
        confidential_asset::assert_last_token_allow_changed_event(token, false);

        // --- disable_allow_list emits AllowListChanged ---
        confidential_asset::disable_allow_list(&aptos_fx);
        confidential_asset::assert_last_allow_list_changed_event(false);

        // --- set_auditor emits AuditorChanged ---
        let (_, auditor_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_auditor(
            &aptos_fx,
            token,
            twisted_elgamal::pubkey_to_bytes(&auditor_ek));
        confidential_asset::assert_last_auditor_changed_event(token);

        // remove auditor
        confidential_asset::set_auditor(&aptos_fx, token, b"");
        confidential_asset::assert_last_auditor_changed_event(token);
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1
    )]
    #[expected_failure(abort_code = 0x01000D, location = confidential_asset)]
    fun fail_register_if_token_disallowed(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &alice, 500, 500);

        confidential_asset::enable_allow_list(&aptos_fx);

        let (_, alice_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1
    )]
    fun success_register_if_token_allowed(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &alice, 500, 500);

        confidential_asset::enable_allow_list(&aptos_fx);
        confidential_asset::enable_token(&aptos_fx, token);

        let (_, alice_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        alice = @0xa1
    )]
    fun fail_deposit_with_coins_if_insufficient_amount(
        confidential_asset: signer,
        aptos_fx: signer,
        alice: signer)
    {
        chain_id::initialize_for_test(&aptos_fx, 4);
        confidential_asset::init_module_for_testing(&confidential_asset);
        coin::create_coin_conversion_map(&aptos_fx);

        let alice_addr = signer::address_of(&alice);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<MockCoin>(
            &confidential_asset, utf8(b"MockCoin"), utf8(b"MC"), 0, false);

        let coin_amount = coin::mint(100, &mint_cap);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);

        account::create_account_if_does_not_exist(alice_addr);
        coin::register<MockCoin>(&alice);
        coin::deposit(alice_addr, coin_amount);

        coin::create_pairing<MockCoin>(&aptos_fx);

        let token = coin::paired_metadata<MockCoin>().extract();

        let (_, alice_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::deposit(&alice, token, 100);
    }

    #[test(
        confidential_asset = @aptos_experimental,
        aptos_fx = @aptos_framework,
        alice = @0xa1,
    )]
    fun success_deposit_with_coins(
        confidential_asset: signer,
        aptos_fx: signer,
        alice: signer)
    {
        chain_id::initialize_for_test(&aptos_fx, 4);
        confidential_asset::init_module_for_testing(&confidential_asset);
        coin::create_coin_conversion_map(&aptos_fx);

        let alice_addr = signer::address_of(&alice);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<MockCoin>(
            &confidential_asset, utf8(b"MockCoin"), utf8(b"MC"), 0, false);

        let coin_amount = coin::mint(100, &mint_cap);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);

        account::create_account_if_does_not_exist(alice_addr);
        coin::register<MockCoin>(&alice);
        coin::deposit(alice_addr, coin_amount);

        coin::create_pairing<MockCoin>(&aptos_fx);

        let token = coin::paired_metadata<MockCoin>().extract();

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        assert!(coin::balance<MockCoin>(alice_addr) == 100, 1);
        assert!(primary_fungible_store::balance(alice_addr, token) == 100, 1);
        assert!(confidential_asset::verify_pending_balance(alice_addr, token, &alice_dk, 0), 1);

        confidential_asset::deposit_coins<MockCoin>(&alice, 50);

        assert!(coin::balance<MockCoin>(alice_addr) == 50, 1);
        assert!(primary_fungible_store::balance(alice_addr, token) == 50, 1);
        assert!(confidential_asset::verify_pending_balance(alice_addr, token, &alice_dk, 50), 1);
    }
}

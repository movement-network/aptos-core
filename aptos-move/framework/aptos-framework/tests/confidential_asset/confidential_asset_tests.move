#[test_only]
module aptos_framework::confidential_asset_tests {
    use std::features;
    use std::option;
    use std::signer;
    use std::string::utf8;
    use aptos_std::ristretto255::Scalar;
    use aptos_framework::account;
    use aptos_framework::chain_id;
    use aptos_framework::coin;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;

    use aptos_framework::confidential_asset;
    use aptos_framework::confidential_balance;
    use aptos_framework::confidential_proof;
    use aptos_framework::ristretto255_twisted_elgamal::{Self as twisted_elgamal, generate_twisted_elgamal_keypair};

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
            @aptos_framework,
            object::object_address(&token),
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
        // Every confidential transfer must include the chain-level auditor at slot 0; helper
        // fetches it from on-chain state so individual tests don't have to thread it through.
        let chain_auditor_ek = confidential_asset::get_chain_auditor().extract();
        let auditor_eks = vector[chain_auditor_ek];

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
            @aptos_framework,
            object::object_address(&token),
            sender_dk,
            &sender_ek,
            &recipient_ek,
            amount,
            new_amount,
            &current_balance,
            &auditor_eks,
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
            confidential_asset::serialize_auditor_eks(&auditor_eks),
            confidential_asset::serialize_auditor_amounts(&auditor_amounts),
            zkrp_new_balance,
            zkrp_transfer_amount,
            sigma_proof,
            sender_auditor_hint
        );
    }

    /// Like `transfer`, but lets the caller append additional auditor keys (asset-level
    /// and/or voluntary). The chain-level auditor is fetched from on-chain state and
    /// automatically placed at slot 0; the caller's `extra_auditor_eks` are appended in
    /// order, so an asset-auditor test should pass `[asset_auditor_ek, vol1, vol2, ...]`
    /// and a pure-voluntary test should pass `[vol1, vol2, ...]`.
    fun audit_transfer(
        sender: &signer,
        sender_dk: &Scalar,
        token: Object<Metadata>,
        to: address,
        amount: u64,
        new_amount: u128,
        extra_auditor_eks: &vector<twisted_elgamal::CompressedPubkey>,
        sender_auditor_hint: vector<u8>): vector<confidential_balance::ConfidentialBalance>
    {
        let chain_auditor_ek = confidential_asset::get_chain_auditor().extract();
        let auditor_eks = vector[chain_auditor_ek];
        extra_auditor_eks.for_each_ref(|ek| auditor_eks.push_back(*ek));

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
            @aptos_framework,
            object::object_address(&token),
            sender_dk,
            &sender_ek,
            &recipient_ek,
            amount,
            new_amount,
            &current_balance,
            &auditor_eks,
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
            confidential_asset::serialize_auditor_eks(&auditor_eks),
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
            @aptos_framework,
            object::object_address(&token),
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
            @aptos_framework,
            object::object_address(&token),
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

    fun normalize_and_rollover(
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
            @aptos_framework,
            object::object_address(&token),
            sender_dk,
            &sender_ek,
            amount,
            &current_balance);

        let (sigma_proof, zkrp_new_balance) = confidential_proof::serialize_normalization_proof(&proof);

        confidential_asset::normalize_and_rollover_pending_balance(
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

        // Every confidential transfer requires the chain-level auditor to be set. Since
        // `set_chain_auditor` is now gated on the chain-auditor admin (governance does
        // *not* hold rotation authority directly), governance first delegates the admin
        // role to `aptos_fx` itself in tests so the shared setup can install a fresh key
        // without standing up a separate admin account. Tests that exercise the
        // governance-vs-admin separation install their own admin.
        confidential_asset::set_chain_auditor_admin(aptos_fx, signer::address_of(aptos_fx));
        let (_chain_dk, chain_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(aptos_fx, twisted_elgamal::pubkey_to_bytes(&chain_ek));

        let token = object::object_from_constructor_ref<Metadata>(ctor_ref);

        let sender_store = primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), token);
        fungible_asset::mint_to(&mint_ref, sender_store, sender_amount);

        let recipient_store = primary_fungible_store::ensure_primary_store_exists(signer::address_of(recipient), token);
        fungible_asset::mint_to(&mint_ref, recipient_store, recipient_amount);

        token
    }

    #[test(
        confidential_asset = @aptos_framework,
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
        confidential_asset = @aptos_framework,
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
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    #[expected_failure(abort_code = 0x010019, location = confidential_asset)]
    fun fail_deposit_zero_amount(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let bob_addr = signer::address_of(&bob);

        let (_alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_bob_dk, bob_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        // Zero deposits move no funds but would consume the recipient's pending slots.
        confidential_asset::deposit_to(&alice, token, bob_addr, 0);
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    #[expected_failure(abort_code = 0x010019, location = confidential_asset)]
    fun fail_withdraw_zero_amount(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);

        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        // A zero withdrawal would act as a normalize that skips the EALREADY_NORMALIZED guard.
        withdraw(&alice, &alice_dk, token, alice_addr, 0, 200);
    }

    #[test(
        confidential_asset = @aptos_framework,
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

    // First-time combined entry point: register + deposit + rollover in one transaction. After
    // success, the store is published, public FA moved into the protocol, and the deposited
    // amount is in actual_balance (spendable) — not pending.
    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_register_and_deposit_and_rollover_pending_balance(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (commitment, response) = confidential_proof::prove_registration(
            4u8,
            alice_addr,
            @aptos_framework,
            &alice_dk,
            &alice_ek,
            object::object_address(&token),
        );

        confidential_asset::register_and_deposit_and_rollover_pending_balance(
            &alice,
            token,
            100,
            twisted_elgamal::pubkey_to_bytes(&alice_ek),
            commitment,
            response,
        );

        assert!(confidential_asset::has_confidential_asset_store(alice_addr, token), 1);
        assert!(primary_fungible_store::balance(alice_addr, token) == 400, 2);
        // Funds landed in actual (spendable), not pending. Pending is empty after rollover.
        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 100), 3);
        assert!(confidential_asset::verify_pending_balance(alice_addr, token, &alice_dk, 0), 4);
    }

    // Submitting a malformed registration proof through the combined entry must abort before any
    // state mutates: store is not created, fungible balance is not moved, no rollover happens.
    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    #[expected_failure(abort_code = 65537, location = aptos_framework::confidential_proof)]
    fun fail_register_and_deposit_and_rollover_with_bad_registration_proof(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_other_dk, other_ek) = generate_twisted_elgamal_keypair();

        // Build a registration proof for `alice_ek` but submit it alongside a different `ek`.
        // verify_registration_proof recomputes the challenge against the *submitted* ek and the
        // proof fails Schnorr verification.
        let (commitment, response) = confidential_proof::prove_registration(
            4u8,
            alice_addr,
            @aptos_framework,
            &alice_dk,
            &alice_ek,
            object::object_address(&token),
        );

        confidential_asset::register_and_deposit_and_rollover_pending_balance(
            &alice,
            token,
            100,
            twisted_elgamal::pubkey_to_bytes(&other_ek),
            commitment,
            response,
        );
    }

    // The combined entry aborts when the sender is already registered for the token.
    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    #[expected_failure(abort_code = 524290, location = aptos_framework::confidential_asset)]
    fun fail_register_and_deposit_and_rollover_when_already_registered(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        let (commitment, response) = confidential_proof::prove_registration(
            4u8,
            alice_addr,
            @aptos_framework,
            &alice_dk,
            &alice_ek,
            object::object_address(&token),
        );

        confidential_asset::register_and_deposit_and_rollover_pending_balance(
            &alice,
            token,
            10,
            twisted_elgamal::pubkey_to_bytes(&alice_ek),
            commitment,
            response,
        );
    }

    // Subsequent combined entry (already registered, currently normalized): deposit + rollover.
    // We arrange a normalized state by sending a confidential transfer first (which sets
    // normalized=true on the sender's store).
    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_deposit_and_rollover_pending_balance(
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
        let (_bob_dk, bob_ek) = generate_twisted_elgamal_keypair();

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        // Bring Alice into a normalized=true state. After register_for_testing, deposit, then
        // rollover, normalized=false. After a confidential_transfer the sender's store is set
        // normalized=true, which is the precondition this entry point asserts.
        confidential_asset::deposit(&alice, token, 100);
        confidential_asset::rollover_pending_balance(&alice, token);
        transfer(&alice, &alice_dk, token, bob_addr, 1, 99, vector[]);
        // sanity-check our setup
        assert!(confidential_asset::is_normalized(alice_addr, token), 99);

        // Now exercise the combined entry: deposit + rollover, no normalize required.
        confidential_asset::deposit_and_rollover_pending_balance(&alice, token, 50);

        // 99 (post-transfer actual) + 50 (just deposited) = 149 in actual; pending empty.
        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 149), 1);
        assert!(confidential_asset::verify_pending_balance(alice_addr, token, &alice_dk, 0), 2);
    }

    // `deposit_and_rollover_pending_balance` aborts when the actual balance is not normalized.
    // The state arrives after any prior `rollover_pending_balance` (which sets normalized=false),
    // so this is the common post-make-private state and the wallet must route to
    // `deposit_and_normalize_and_rollover_pending_balance` instead.
    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    #[expected_failure(abort_code = 196618, location = aptos_framework::confidential_asset)]
    fun fail_deposit_and_rollover_when_not_normalized(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let (_alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        // After deposit + rollover, normalized=false. Subsequent combined call must abort.
        confidential_asset::deposit(&alice, token, 100);
        confidential_asset::rollover_pending_balance(&alice, token);
        assert!(!confidential_asset::is_normalized(alice_addr, token), 99);

        confidential_asset::deposit_and_rollover_pending_balance(&alice, token, 50);
    }

    // Subsequent combined entry with normalize: deposit + normalize + rollover. Used after a
    // prior rollover (which left the store with normalized=false). After this call, normalized
    // is back to false (rollover always sets it false), but the actual balance is the canonical
    // sum so the next deposit-then-rollover call goes through the same path.
    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_deposit_and_normalize_and_rollover_pending_balance(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(&confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);

        let alice_addr = signer::address_of(&alice);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        // Establish a normalized=false state (deposit then rollover).
        confidential_asset::deposit(&alice, token, 100);
        confidential_asset::rollover_pending_balance(&alice, token);
        assert!(!confidential_asset::is_normalized(alice_addr, token), 99);

        // Build the normalize proof off-chain against the *current* actual balance (100).
        // `deposit_to_internal` only mutates pending, so the actual balance the proof is bound
        // to matches the actual balance at on-chain `normalize_internal` time.
        let cid = 4u8;
        let sender_ek = confidential_asset::encryption_key(alice_addr, token);
        let current_actual = confidential_balance::decompress_balance(
            &confidential_asset::actual_balance(alice_addr, token)
        );
        let (proof, new_balance) = confidential_proof::prove_normalization(
            cid,
            alice_addr,
            @aptos_framework,
            object::object_address(&token),
            &alice_dk,
            &sender_ek,
            100,
            &current_actual,
        );
        let new_balance_bytes = confidential_balance::balance_to_bytes(&new_balance);
        let (sigma, zkrp) = confidential_proof::serialize_normalization_proof(&proof);

        // deposit 30, then normalize, then rollover → actual = 100 + 30 = 130.
        confidential_asset::deposit_and_normalize_and_rollover_pending_balance(
            &alice,
            token,
            30,
            new_balance_bytes,
            zkrp,
            sigma,
        );

        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 130), 1);
        assert!(confidential_asset::verify_pending_balance(alice_addr, token, &alice_dk, 0), 2);
    }

    #[test(
        confidential_asset = @aptos_framework,
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
        // setup set the chain auditor exactly once (epoch 1); no asset auditor (epoch 0).
        // ek_volun_auds covers ALL auditors including chain — so 1 row, not 0.
        confidential_asset::assert_last_transferred_event_matches_state(
            token,
            alice_addr,
            bob_addr,
            1,
            hint,
            1,
            0,
        );
    }

    #[test(
        confidential_asset = @aptos_framework,
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

        confidential_asset::set_asset_auditor(
            &fa,
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

        // auditor_amounts[0] is the chain auditor's row; the asset & voluntary rows shift to [1]/[2].
        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[1], &auditor1_dk, 100), 1);
        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[2], &auditor2_dk, 100), 1);
    }

    #[test(
        confidential_asset = @aptos_framework,
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

        confidential_asset::set_asset_auditor(
            &fa,
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
        // auditor_amounts[0] is the chain auditor's row; the asset & voluntary rows shift to [1]/[2].
        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[1], &auditor1_dk, 100), 2);
        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[2], &auditor2_dk, 100), 3);

        // chain auditor + asset auditor + 1 voluntary = 3 auditor rows in ek_volun_auds.
        confidential_asset::assert_last_transferred_event_matches_state(
            token,
            alice_addr,
            bob_addr,
            3,
            hint,
            1,
            1,
        );
    }

    #[test(
        confidential_asset = @aptos_framework,
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

        confidential_asset::set_asset_auditor(
            &fa,
            token,
            twisted_elgamal::pubkey_to_bytes(&auditor1_ek));

        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));

        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        // Asset auditor for `token` is `auditor1`, so the first slot in `extra_auditor_eks`
        // (which becomes `auditor_eks[1]` after the helper prepends the chain auditor at slot 0)
        // must equal `auditor1`. Passing `auditor2` there is a slot-1 mismatch and is rejected.
        // See `confidential_asset::validate_auditors`.
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
        confidential_asset = @aptos_framework,
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
        confidential_asset = @aptos_framework,
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
        confidential_asset = @aptos_framework,
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

    // `normalize_and_rollover_pending_balance` from an unnormalized state combines the two
    // steps in one tx. After: pending is empty, balance becomes (old available + pending),
    // and `normalized` is back to `false` (rollover resets it).
    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    fun success_normalize_and_rollover_from_unnormalized(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let max_chunk_value = 1 << 16 - 1;
        let token = set_up_for_confidential_asset_test(
            &confidential_asset, &aptos_fx, &fa, &alice, &bob,
            max_chunk_value + 50, max_chunk_value);

        let alice_addr = signer::address_of(&alice);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        // Two deposits + a rollover stack max-chunk values into a single chunk, leaving the
        // available balance unnormalized.
        confidential_asset::deposit(&alice, token, max_chunk_value);
        confidential_asset::deposit_to(&bob, token, alice_addr, max_chunk_value);
        confidential_asset::rollover_pending_balance(&alice, token);
        assert!(!confidential_asset::is_normalized(alice_addr, token), 1);

        // A fresh deposit lands in pending; the combined entry must roll it in.
        confidential_asset::deposit(&alice, token, 50);

        let total: u128 = (2 * max_chunk_value as u128) + 50;
        normalize_and_rollover(&alice, &alice_dk, token, (2 * max_chunk_value as u128));

        // Available reflects normalized old + pending; not normalized
        // (rollover always leaves the merged balance unnormalized — same as plain rollover).
        assert!(!confidential_asset::is_normalized(alice_addr, token), 3);
        assert!(
            confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, total), 5);
    }

    // Calling `normalize_and_rollover_pending_balance` while already normalized aborts at
    // the `normalize_internal` step (`EALREADY_NORMALIZED`, invalid_state = category 3).
    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1,
        bob = @0xb0
    )]
    #[expected_failure(abort_code = 0x03000B, location = aptos_framework::confidential_asset)]
    fun fail_normalize_and_rollover_when_already_normalized(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer,
        bob: signer)
    {
        let token = set_up_for_confidential_asset_test(
            &confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);
        let alice_addr = signer::address_of(&alice);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));

        // A freshly registered store starts with `normalized == true` and an empty available
        // balance, so the wrapper must abort at `normalize_internal`'s `EALREADY_NORMALIZED`.
        assert!(confidential_asset::is_normalized(alice_addr, token), 1);

        normalize_and_rollover(&alice, &alice_dk, token, 0);
    }

    #[test(
        confidential_asset = @aptos_framework,
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
        confidential_asset = @aptos_framework,
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

        // --- set_asset_auditor emits AssetAuditorChanged with bumped epoch ---
        let (_, auditor_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_asset_auditor(
            &fa,
            token,
            twisted_elgamal::pubkey_to_bytes(&auditor_ek));
        confidential_asset::assert_last_asset_auditor_changed_event(token, 1);

        // clear asset auditor — still bumps epoch and emits the event
        confidential_asset::set_asset_auditor(&fa, token, b"");
        confidential_asset::assert_last_asset_auditor_changed_event(token, 2);

        // --- set_chain_auditor emits ChainAuditorChanged ---
        // Setup already set the chain auditor once (epoch 1); rotate to a new key (epoch 2).
        let (_, new_chain_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(
            &aptos_fx,
            twisted_elgamal::pubkey_to_bytes(&new_chain_ek));
        confidential_asset::assert_last_chain_auditor_changed_event(2);
    }

    #[test(
        confidential_asset = @aptos_framework,
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
        confidential_asset = @aptos_framework,
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
        confidential_asset = @aptos_framework,
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
        confidential_asset = @aptos_framework,
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

    fun set_up_dispatchable_fa_test(
        confidential_asset_signer: &signer,
        aptos_fx: &signer,
        fa: &signer,
        sender: &signer,
        sender_amount: u64): Object<Metadata>
    {
        chain_id::initialize_for_test(aptos_fx, 4);

        let ctor_ref = &object::create_sticky_object(signer::address_of(fa));

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            ctor_ref,
            option::none(),
            utf8(b"DispatchToken"),
            utf8(b"DT"),
            18,
            utf8(b"https://"),
            utf8(b"https://"),
        );

        dispatchable_fungible_asset::register_dispatch_functions(
            ctor_ref,
            option::none(),
            option::none(),
            option::none(),
        );

        let mint_ref = fungible_asset::generate_mint_ref(ctor_ref);

        confidential_asset::init_module_for_testing(confidential_asset_signer);
        features::change_feature_flags_for_testing(aptos_fx, vector[features::get_bulletproofs_feature()], vector[]);

        let token = object::object_from_constructor_ref<Metadata>(ctor_ref);

        let sender_store = primary_fungible_store::ensure_primary_store_exists(signer::address_of(sender), token);
        fungible_asset::mint_to(&mint_ref, sender_store, sender_amount);

        token
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1
    )]
    #[expected_failure(abort_code = 0x010013, location = confidential_asset)]
    fun fail_register_with_dispatchable_fa(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer)
    {
        let token = set_up_dispatchable_fa_test(&confidential_asset, &aptos_fx, &fa, &alice, 500);

        assert!(fungible_asset::is_asset_type_dispatchable(token), 1);

        let (_, alice_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1
    )]
    fun success_standard_fa_not_blocked(
        confidential_asset: signer,
        aptos_fx: signer,
        fa: signer,
        alice: signer)
    {
        let token = set_up_for_confidential_asset_test(
            &confidential_asset, &aptos_fx, &fa, &alice, &alice, 500, 0);

        assert!(!fungible_asset::is_asset_type_dispatchable(token), 1);

        let (_, alice_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::deposit(&alice, token, 100);
    }

    //
    // Auditor layering: chain-level + per-asset + voluntary auditors.
    //

    /// Setup variant that does NOT install a chain-level auditor. Used to exercise the
    /// `ECHAIN_AUDITOR_NOT_SET` precondition on transfers.
    fun set_up_without_chain_auditor(
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
            ctor_ref, option::none(), utf8(b"NoChainAuditor"), utf8(b"NCA"), 18,
            utf8(b"https://"), utf8(b"https://"));
        let mint_ref = fungible_asset::generate_mint_ref(ctor_ref);
        confidential_asset::init_module_for_testing(confidential_asset);
        features::change_feature_flags_for_testing(
            aptos_fx, vector[features::get_bulletproofs_feature()], vector[]);
        let token = object::object_from_constructor_ref<Metadata>(ctor_ref);
        let sender_store = primary_fungible_store::ensure_primary_store_exists(
            signer::address_of(sender), token);
        fungible_asset::mint_to(&mint_ref, sender_store, sender_amount);
        let recipient_store = primary_fungible_store::ensure_primary_store_exists(
            signer::address_of(recipient), token);
        fungible_asset::mint_to(&mint_ref, recipient_store, recipient_amount);
        token
    }

    /// Builds and submits a transfer using the supplied `auditor_eks` *verbatim* — without
    /// the chain-key prepend that `audit_transfer` performs. Used by tests that need to
    /// exercise rejection paths (wrong slot 0, missing prefix, post-rotation old proof).
    fun audit_transfer_raw(
        sender: &signer,
        sender_dk: &Scalar,
        token: Object<Metadata>,
        to: address,
        amount: u64,
        new_amount: u128,
        auditor_eks: &vector<twisted_elgamal::CompressedPubkey>,
        sender_auditor_hint: vector<u8>)
    {
        let from = signer::address_of(sender);
        let sender_ek = confidential_asset::encryption_key(from, token);
        let recipient_ek = confidential_asset::encryption_key(to, token);
        let current_balance = confidential_balance::decompress_balance(
            &confidential_asset::actual_balance(from, token));
        let (proof, new_balance, sender_amount, recipient_amount, auditor_amounts) =
            confidential_proof::prove_transfer(
                4u8, from, @aptos_framework, object::object_address(&token),
                sender_dk, &sender_ek, &recipient_ek, amount, new_amount,
                &current_balance, auditor_eks, sender_auditor_hint);
        let (sigma_proof, zkrp_new_balance, zkrp_transfer_amount) =
            confidential_proof::serialize_transfer_proof(&proof);
        confidential_asset::confidential_transfer(
            sender, token, to,
            confidential_balance::balance_to_bytes(&new_balance),
            confidential_balance::balance_to_bytes(&sender_amount),
            confidential_balance::balance_to_bytes(&recipient_amount),
            confidential_asset::serialize_auditor_eks(auditor_eks),
            confidential_asset::serialize_auditor_amounts(&auditor_amounts),
            zkrp_new_balance, zkrp_transfer_amount, sigma_proof, sender_auditor_hint);
    }

    #[test(confidential_asset = @aptos_framework, aptos_fx = @aptos_framework,
        fa = @0xfa, alice = @0xa1, bob = @0xb0)]
    #[expected_failure(abort_code = 0x030015, location = confidential_asset)]
    /// Confidential transfers cannot run before the chain-level auditor has been
    /// configured. Aborts with `ECHAIN_AUDITOR_NOT_SET`.
    fun fail_transfer_if_chain_auditor_unset(
        confidential_asset: signer, aptos_fx: signer, fa: signer,
        alice: signer, bob: signer)
    {
        let token = set_up_without_chain_auditor(
            &confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);
        let bob_addr = signer::address_of(&bob);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_, bob_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));
        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        // Even an empty auditor list is rejected — chain auditor is mandatory.
        audit_transfer_raw(&alice, &alice_dk, token, bob_addr, 100, 100, &vector[], vector[]);
    }

    #[test(confidential_asset = @aptos_framework, aptos_fx = @aptos_framework,
        fa = @0xfa, alice = @0xa1, bob = @0xb0)]
    #[expected_failure(abort_code = 0x010006, location = confidential_asset)]
    /// Slot 0 of `auditor_eks` must equal the active chain auditor key — a sender cannot
    /// substitute their own key in that position even if they encrypt a valid auditor
    /// amount under it.
    fun fail_transfer_if_slot0_not_chain_auditor(
        confidential_asset: signer, aptos_fx: signer, fa: signer,
        alice: signer, bob: signer)
    {
        let token = set_up_for_confidential_asset_test(
            &confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);
        let bob_addr = signer::address_of(&bob);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_, bob_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));
        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        // Use a fresh keypair as slot 0 — proof verifies (consistent transcript) but
        // `validate_auditors` rejects because slot 0 ≠ on-chain chain auditor.
        let (_, wrong_ek) = generate_twisted_elgamal_keypair();
        audit_transfer_raw(&alice, &alice_dk, token, bob_addr, 100, 100,
            &vector[wrong_ek], vector[]);
    }

    #[test(confidential_asset = @aptos_framework, aptos_fx = @aptos_framework,
        fa = @0xfa, alice = @0xa1, bob = @0xb0)]
    #[expected_failure(abort_code = 0x010006, location = confidential_asset)]
    /// When an asset auditor is set, `auditor_eks` must include both the chain auditor
    /// (slot 0) and the asset auditor (slot 1). Submitting only the chain auditor is
    /// rejected — the prefix length check in `validate_auditors` catches it.
    fun fail_transfer_if_asset_auditor_required_but_missing(
        confidential_asset: signer, aptos_fx: signer, fa: signer,
        alice: signer, bob: signer)
    {
        let token = set_up_for_confidential_asset_test(
            &confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);
        let bob_addr = signer::address_of(&bob);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_, bob_ek) = generate_twisted_elgamal_keypair();
        let (_, asset_aud_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_asset_auditor(&fa, token,
            twisted_elgamal::pubkey_to_bytes(&asset_aud_ek));
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));
        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        // Helper auto-prepends the chain auditor ⇒ auditor_eks = [chain]. Slot 1 is missing
        // even though asset auditor is set ⇒ rejected.
        audit_transfer(&alice, &alice_dk, token, bob_addr, 100, 100, &vector[], vector[]);
    }

    #[test(confidential_asset = @aptos_framework, aptos_fx = @aptos_framework,
        fa = @0xfa, alice = @0xa1, bob = @0xb0)]
    /// Voluntary auditors at slot 2+ are accepted when no asset auditor is configured —
    /// the prefix is just `[chain]`, anything after is the sender's choice.
    fun success_voluntary_auditors_without_asset_auditor(
        confidential_asset: signer, aptos_fx: signer, fa: signer,
        alice: signer, bob: signer)
    {
        let token = set_up_for_confidential_asset_test(
            &confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);
        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (bob_dk, bob_ek) = generate_twisted_elgamal_keypair();
        let (vol1_dk, vol1_ek) = generate_twisted_elgamal_keypair();
        let (vol2_dk, vol2_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));
        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        let auditor_amounts = audit_transfer(&alice, &alice_dk, token, bob_addr, 100, 100,
            &vector[vol1_ek, vol2_ek], vector[]);

        assert!(confidential_asset::verify_actual_balance(alice_addr, token, &alice_dk, 100), 1);
        assert!(confidential_asset::verify_pending_balance(bob_addr, token, &bob_dk, 100), 1);
        // [0] = chain auditor (helper-prepended); [1] = vol1; [2] = vol2.
        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[1], &vol1_dk, 100), 2);
        assert!(confidential_balance::verify_pending_balance(&auditor_amounts[2], &vol2_dk, 100), 3);
    }

    #[test(confidential_asset = @aptos_framework, aptos_fx = @aptos_framework,
        fa = @0xfa, alice = @0xa1, bob = @0xb0)]
    #[expected_failure(abort_code = 0x010006, location = confidential_asset)]
    /// A proof generated under the previous chain auditor key becomes unsubmittable after
    /// governance rotates the chain auditor — slot 0 no longer equals the on-chain key.
    /// This is the explicit "rotation invalidates in-flight proofs" property documented
    /// on `set_chain_auditor`.
    fun fail_transfer_after_chain_auditor_rotation(
        confidential_asset: signer, aptos_fx: signer, fa: signer,
        alice: signer, bob: signer)
    {
        let token = set_up_for_confidential_asset_test(
            &confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);
        let bob_addr = signer::address_of(&bob);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_, bob_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));
        confidential_asset::deposit(&alice, token, 200);
        confidential_asset::rollover_pending_balance(&alice, token);

        // Capture the chain auditor key in force at proof-generation time, then rotate
        // before submission to simulate a governance proposal landing mid-flight.
        let old_chain_ek = confidential_asset::get_chain_auditor().extract();
        let (_, new_chain_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(&aptos_fx, twisted_elgamal::pubkey_to_bytes(&new_chain_ek));

        // `audit_transfer_raw` uses the supplied list verbatim — slot 0 is the *old* key,
        // which no longer matches the on-chain chain auditor.
        audit_transfer_raw(&alice, &alice_dk, token, bob_addr, 100, 100,
            &vector[old_chain_ek], vector[]);
    }

    #[test(confidential_asset = @aptos_framework, aptos_fx = @aptos_framework,
        fa = @0xfa, alice = @0xa1, bob = @0xb0)]
    /// Rotation: each rotation bumps the epoch and stamps the new epoch on subsequent
    /// transfers. Off-chain auditors / gateways resolve epoch → key by indexing
    /// `ChainAuditorChanged` / `AssetAuditorChanged` events.
    fun success_auditor_rotation_bumps_epoch(
        confidential_asset: signer, aptos_fx: signer, fa: signer,
        alice: signer, bob: signer)
    {
        let token = set_up_for_confidential_asset_test(
            &confidential_asset, &aptos_fx, &fa, &alice, &bob, 500, 500);
        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);
        let (alice_dk, alice_ek) = generate_twisted_elgamal_keypair();
        let (_, bob_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::register_for_testing(&alice, token, twisted_elgamal::pubkey_to_bytes(&alice_ek));
        confidential_asset::register_for_testing(&bob, token, twisted_elgamal::pubkey_to_bytes(&bob_ek));
        confidential_asset::deposit(&alice, token, 300);
        confidential_asset::rollover_pending_balance(&alice, token);

        // Setup installed epoch 1; rotate twice → epochs 2, 3.
        assert!(confidential_asset::get_chain_auditor_epoch() == 1, 1);
        let (_, ek2) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(&aptos_fx, twisted_elgamal::pubkey_to_bytes(&ek2));
        assert!(confidential_asset::get_chain_auditor_epoch() == 2, 2);
        let (_, ek3) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(&aptos_fx, twisted_elgamal::pubkey_to_bytes(&ek3));
        assert!(confidential_asset::get_chain_auditor_epoch() == 3, 3);

        // Transfer stamps the *current* epoch (3) on the event.
        transfer(&alice, &alice_dk, token, bob_addr, 100, 200, vector[]);
        confidential_asset::assert_last_transferred_event_matches_state(
            token, alice_addr, bob_addr, 1, vector[], 3, 0);

        // Asset auditor history is independent. Set, rotate, clear.
        let (_, asset_ek1) = generate_twisted_elgamal_keypair();
        let (_, asset_ek2) = generate_twisted_elgamal_keypair();
        confidential_asset::set_asset_auditor(&fa, token, twisted_elgamal::pubkey_to_bytes(&asset_ek1));
        assert!(confidential_asset::get_asset_auditor_epoch(token) == 1, 5);
        confidential_asset::set_asset_auditor(&fa, token, twisted_elgamal::pubkey_to_bytes(&asset_ek2));
        assert!(confidential_asset::get_asset_auditor_epoch(token) == 2, 6);
        confidential_asset::set_asset_auditor(&fa, token, b"");
        assert!(confidential_asset::get_asset_auditor_epoch(token) == 3, 7);
        // After the clear there is no active asset auditor; the epoch keeps advancing.
        assert!(confidential_asset::get_asset_auditor(token).is_none(), 9);
    }

    // ============================================================================
    // Asset auditor authorization tests
    //
    // `set_asset_auditor` is gated by `object::root_owner(token) == signer::address_of(issuer)`.
    // For framework-managed FAs (root = @0x1) only governance qualifies; for issuer-deployed
    // FAs the account at the top of the metadata object's ownership chain qualifies — even
    // if there are intermediate object owners (the USDCX-style "contract object owns FA,
    // multisig owns contract" pattern).
    // ============================================================================

    /// Helper: chain auditor + module init + features, without minting or creating an FA.
    /// Tests below create their own FA with custom ownership chains.
    fun set_up_chain_only(confidential_asset: &signer, aptos_fx: &signer) {
        chain_id::initialize_for_test(aptos_fx, 4);
        confidential_asset::init_module_for_testing(confidential_asset);
        features::change_feature_flags_for_testing(
            aptos_fx, vector[features::get_bulletproofs_feature()], vector[]
        );
        confidential_asset::set_chain_auditor_admin(aptos_fx, signer::address_of(aptos_fx));
        let (_, chain_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(aptos_fx, twisted_elgamal::pubkey_to_bytes(&chain_ek));
    }

    /// Helper: create a fresh FA owned directly by `creator_addr`.
    fun create_fa_owned_by(creator_addr: address): Object<Metadata> {
        let ctor_ref = &object::create_sticky_object(creator_addr);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            ctor_ref,
            option::none(),
            utf8(b"MockToken"),
            utf8(b"MT"),
            18,
            utf8(b"https://"),
            utf8(b"https://"),
        );
        object::object_from_constructor_ref<Metadata>(ctor_ref)
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1
    )]
    /// Direct-ownership case: the FA creator is the root owner of the metadata object,
    /// so they can rotate the asset auditor. Mirrors the issuer-deployed FA shape where
    /// no intermediate object sits between the issuer account and the FA.
    fun success_set_asset_auditor_by_direct_root_owner(
        confidential_asset: signer, aptos_fx: signer, fa: signer, alice: signer)
    {
        set_up_chain_only(&confidential_asset, &aptos_fx);
        let token = create_fa_owned_by(signer::address_of(&fa));

        // Sanity: direct owner == root owner == fa.
        assert!(object::owner(token) == signer::address_of(&fa), 1);
        assert!(object::root_owner(token) == signer::address_of(&fa), 2);

        let (_, ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_asset_auditor(&fa, token, twisted_elgamal::pubkey_to_bytes(&ek));
        assert!(confidential_asset::get_asset_auditor_epoch(token) == 1, 3);
        assert!(confidential_asset::get_asset_auditor(token).is_some(), 4);

        // Silence unused-binding warning for `alice` (kept in the test signature so the
        // address space matches sibling tests).
        let _ = alice;
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1
    )]
    #[expected_failure(abort_code = 0x50016, location = confidential_asset)]
    /// Negative: a non-owner signer is rejected. `alice` did not create the FA and is not
    /// in the ownership chain, so root_owner != alice and the call aborts with
    /// `ENOT_ASSET_ISSUER` (0x16) under permission_denied (category 5).
    fun fail_set_asset_auditor_if_not_root_owner(
        confidential_asset: signer, aptos_fx: signer, fa: signer, alice: signer)
    {
        set_up_chain_only(&confidential_asset, &aptos_fx);
        let token = create_fa_owned_by(signer::address_of(&fa));

        let (_, ek) = generate_twisted_elgamal_keypair();
        // Alice is not the root owner — must abort.
        confidential_asset::set_asset_auditor(&alice, token, twisted_elgamal::pubkey_to_bytes(&ek));
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        fa = @0xfa,
        alice = @0xa1
    )]
    #[expected_failure(abort_code = 0x50016, location = confidential_asset)]
    /// Negative: governance cannot rotate the auditor of an issuer-deployed FA. This is
    /// the intended authorization shift — `aptos_framework` no longer has implicit
    /// authority over per-asset auditors; only the FA's root owner does.
    fun fail_set_asset_auditor_by_aptos_framework_for_issuer_fa(
        confidential_asset: signer, aptos_fx: signer, fa: signer, alice: signer)
    {
        set_up_chain_only(&confidential_asset, &aptos_fx);
        let token = create_fa_owned_by(signer::address_of(&fa));

        let (_, ek) = generate_twisted_elgamal_keypair();
        // root_owner(token) == @0xfa, signer::address_of(&aptos_fx) == @0x1 — mismatch.
        confidential_asset::set_asset_auditor(&aptos_fx, token, twisted_elgamal::pubkey_to_bytes(&ek));

        let _ = fa;
        let _ = alice;
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        alice = @0xa1
    )]
    /// Framework-managed FA: when the FA is created with `@aptos_framework` (= @0x1) as
    /// the creator, root_owner returns @0x1 and only governance — via the
    /// `aptos_framework` signer — can rotate the auditor. Models a canonical framework
    /// FA like APT at @0xa.
    fun success_set_asset_auditor_for_framework_fa(
        confidential_asset: signer, aptos_fx: signer, alice: signer)
    {
        set_up_chain_only(&confidential_asset, &aptos_fx);
        // Framework FA: creator is @aptos_framework, so root_owner == @0x1.
        let token = create_fa_owned_by(@aptos_framework);

        assert!(object::root_owner(token) == @aptos_framework, 1);

        let (_, ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_asset_auditor(&aptos_fx, token, twisted_elgamal::pubkey_to_bytes(&ek));
        assert!(confidential_asset::get_asset_auditor_epoch(token) == 1, 2);

        let _ = alice;
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        multisig = @0x9001,
        alice = @0xa1
    )]
    /// Nested-ownership case (USDCX shape): a "contract object" sits between the multisig
    /// issuer and the FA metadata object. `object::root_owner` walks the chain through
    /// the contract object to the multisig at the top, so the multisig can call
    /// `set_asset_auditor` directly without needing the contract's ExtendRef wrapper.
    fun success_set_asset_auditor_via_nested_object_chain(
        confidential_asset: signer, aptos_fx: signer, multisig: signer, alice: signer)
    {
        set_up_chain_only(&confidential_asset, &aptos_fx);

        // Build the chain: multisig -> contract_obj -> fa_metadata_obj.
        let contract_ctor = object::create_sticky_object(signer::address_of(&multisig));
        let contract_signer = object::generate_signer(&contract_ctor);
        let contract_addr = signer::address_of(&contract_signer);

        let token = create_fa_owned_by(contract_addr);

        // Direct owner is the contract object; root walks past it to the multisig.
        assert!(object::owner(token) == contract_addr, 1);
        assert!(object::root_owner(token) == signer::address_of(&multisig), 2);

        // Multisig (root) can rotate directly.
        let (_, ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_asset_auditor(&multisig, token, twisted_elgamal::pubkey_to_bytes(&ek));
        assert!(confidential_asset::get_asset_auditor_epoch(token) == 1, 3);

        let _ = alice;
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        multisig = @0x9001,
        alice = @0xa1
    )]
    #[expected_failure(abort_code = 0x50016, location = confidential_asset)]
    /// Nested-ownership negative: the *intermediate* object signer (the contract object
    /// directly above the FA) is not the root owner and is rejected. Only the account at
    /// the top of the chain has authority.
    fun fail_set_asset_auditor_by_intermediate_object_in_chain(
        confidential_asset: signer, aptos_fx: signer, multisig: signer, alice: signer)
    {
        set_up_chain_only(&confidential_asset, &aptos_fx);

        let contract_ctor = object::create_sticky_object(signer::address_of(&multisig));
        let contract_signer = object::generate_signer(&contract_ctor);
        let contract_addr = signer::address_of(&contract_signer);

        let token = create_fa_owned_by(contract_addr);

        // The contract-object signer is the *direct* owner but not the *root* owner —
        // root_owner walks past it to the multisig — so this must abort.
        let (_, ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_asset_auditor(
            &contract_signer, token, twisted_elgamal::pubkey_to_bytes(&ek)
        );

        let _ = alice;
    }

    // ============================================================================
    // Chain-auditor admin authorization tests
    //
    // Movement governance does NOT directly hold rotation authority over the chain-level
    // auditor key. Instead, governance designates a chain-auditor admin account via
    // `set_chain_auditor_admin`, and only that account may subsequently call
    // `set_chain_auditor`.
    //
    // The shared `set_up_for_confidential_asset_test` helper papers over this by
    // designating `aptos_fx` itself as the admin so other tests don't need to know the
    // detail; the tests below stand up their own state (no shared setup) to exercise the
    // authorization boundary directly.
    // ============================================================================

    /// Helper: minimal init without setting the chain-auditor admin or the chain auditor
    /// itself, so admin-related tests can exercise the bootstrap path explicitly.
    fun set_up_chain_admin_test(confidential_asset: &signer, aptos_fx: &signer) {
        chain_id::initialize_for_test(aptos_fx, 4);
        confidential_asset::init_module_for_testing(confidential_asset);
        features::change_feature_flags_for_testing(
            aptos_fx, vector[features::get_bulletproofs_feature()], vector[]
        );
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        ca_admin = @0xCA
    )]
    /// Happy path: governance designates a chain-auditor admin, that admin then sets the
    /// chain auditor. Verifies the admin view, the emitted admin-changed event, and that
    /// the chain auditor key actually lands.
    fun success_set_chain_auditor_by_designated_admin(
        confidential_asset: signer, aptos_fx: signer, ca_admin: signer)
    {
        set_up_chain_admin_test(&confidential_asset, &aptos_fx);

        // Admin starts unset.
        assert!(confidential_asset::get_chain_auditor_admin().is_none(), 1);

        // Governance designates ca_admin.
        let ca_admin_addr = signer::address_of(&ca_admin);
        confidential_asset::set_chain_auditor_admin(&aptos_fx, ca_admin_addr);
        assert!(confidential_asset::get_chain_auditor_admin() == option::some(ca_admin_addr), 2);
        confidential_asset::assert_last_chain_auditor_admin_changed_event(ca_admin_addr);

        // Designated admin can install a chain auditor.
        let (_, chain_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(&ca_admin, twisted_elgamal::pubkey_to_bytes(&chain_ek));
        assert!(confidential_asset::get_chain_auditor_epoch() == 1, 3);
        assert!(confidential_asset::get_chain_auditor().is_some(), 4);
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        ca_admin = @0xCA
    )]
    /// Admin rotation: governance can hand the role to a successor account. The previous
    /// admin loses authority; the new admin gains it.
    fun success_chain_auditor_admin_rotation(
        confidential_asset: signer, aptos_fx: signer, ca_admin: signer)
    {
        set_up_chain_admin_test(&confidential_asset, &aptos_fx);
        let ca_admin_addr = signer::address_of(&ca_admin);
        confidential_asset::set_chain_auditor_admin(&aptos_fx, ca_admin_addr);

        // Rotate admin to a fresh address.
        let new_admin_addr = @0xCAFE;
        confidential_asset::set_chain_auditor_admin(&aptos_fx, new_admin_addr);
        assert!(confidential_asset::get_chain_auditor_admin() == option::some(new_admin_addr), 1);
        confidential_asset::assert_last_chain_auditor_admin_changed_event(new_admin_addr);

        let _ = ca_admin;
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        not_gov = @0x9999
    )]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    /// Negative: only governance can designate the chain-auditor admin. A non-governance
    /// signer hits `assert_aptos_framework` and aborts with the framework's standard
    /// permission_denied code (0x50003).
    fun fail_set_chain_auditor_admin_by_non_governance(
        confidential_asset: signer, aptos_fx: signer, not_gov: signer)
    {
        set_up_chain_admin_test(&confidential_asset, &aptos_fx);
        confidential_asset::set_chain_auditor_admin(&not_gov, @0xCA);
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework
    )]
    #[expected_failure(abort_code = 0x30017, location = confidential_asset)]
    /// Negative bootstrap: before governance has assigned an admin, no one — not even
    /// governance itself — can set the chain auditor. Aborts with
    /// `ECHAIN_AUDITOR_ADMIN_NOT_SET` (0x17) under invalid_state (category 3).
    fun fail_set_chain_auditor_when_admin_not_set(
        confidential_asset: signer, aptos_fx: signer)
    {
        set_up_chain_admin_test(&confidential_asset, &aptos_fx);

        let (_, chain_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(&aptos_fx, twisted_elgamal::pubkey_to_bytes(&chain_ek));
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        ca_admin = @0xCA
    )]
    #[expected_failure(abort_code = 0x50018, location = confidential_asset)]
    /// The separation property: once governance has designated a separate admin,
    /// governance itself can no longer rotate the chain auditor. Aborts with
    /// `ENOT_CHAIN_AUDITOR_ADMIN` (0x18) under permission_denied.
    fun fail_set_chain_auditor_by_governance_when_admin_is_separate(
        confidential_asset: signer, aptos_fx: signer, ca_admin: signer)
    {
        set_up_chain_admin_test(&confidential_asset, &aptos_fx);
        confidential_asset::set_chain_auditor_admin(&aptos_fx, signer::address_of(&ca_admin));

        let (_, chain_ek) = generate_twisted_elgamal_keypair();
        // aptos_fx (governance) is no longer the admin — must abort.
        confidential_asset::set_chain_auditor(&aptos_fx, twisted_elgamal::pubkey_to_bytes(&chain_ek));

        let _ = ca_admin;
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        ca_admin = @0xCA,
        stranger = @0x1234
    )]
    #[expected_failure(abort_code = 0x50018, location = confidential_asset)]
    /// Negative: an arbitrary third party who is neither governance nor the designated
    /// admin cannot rotate the chain auditor.
    fun fail_set_chain_auditor_by_stranger(
        confidential_asset: signer, aptos_fx: signer, ca_admin: signer, stranger: signer)
    {
        set_up_chain_admin_test(&confidential_asset, &aptos_fx);
        confidential_asset::set_chain_auditor_admin(&aptos_fx, signer::address_of(&ca_admin));

        let (_, chain_ek) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(&stranger, twisted_elgamal::pubkey_to_bytes(&chain_ek));

        let _ = ca_admin;
    }

    #[test(
        confidential_asset = @aptos_framework,
        aptos_fx = @aptos_framework,
        ca_admin1 = @0xCA1,
        ca_admin2 = @0xCA2
    )]
    #[expected_failure(abort_code = 0x50018, location = confidential_asset)]
    /// Rotation revokes the prior admin: after governance moves the role from ca_admin1
    /// to ca_admin2, ca_admin1 loses authority.
    fun fail_set_chain_auditor_by_revoked_admin(
        confidential_asset: signer,
        aptos_fx: signer,
        ca_admin1: signer,
        ca_admin2: signer)
    {
        set_up_chain_admin_test(&confidential_asset, &aptos_fx);
        confidential_asset::set_chain_auditor_admin(&aptos_fx, signer::address_of(&ca_admin1));

        // ca_admin1 sets a key successfully.
        let (_, ek1) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(&ca_admin1, twisted_elgamal::pubkey_to_bytes(&ek1));

        // Governance rotates the admin role away from ca_admin1.
        confidential_asset::set_chain_auditor_admin(&aptos_fx, signer::address_of(&ca_admin2));

        // The former admin tries to rotate again — must abort.
        let (_, ek2) = generate_twisted_elgamal_keypair();
        confidential_asset::set_chain_auditor(&ca_admin1, twisted_elgamal::pubkey_to_bytes(&ek2));

        let _ = ca_admin2;
    }
}

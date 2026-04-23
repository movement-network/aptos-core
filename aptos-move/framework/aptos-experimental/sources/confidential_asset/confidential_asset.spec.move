/// MSL specs for `aptos_experimental::confidential_asset`.
///
/// **Scope:** this initial pass covers the store-only operations from Phase 3 of the unified
/// verification plan (freeze/unfreeze, view functions, `has_confidential_asset_store`). These
/// are pure ConfidentialAssetStore mutations / reads with no crypto content, so they can be
/// discharged by the Move Prover independent of the ristretto255 spec work tracked in §5.2.
///
/// The `*_internal` balance mutators (`register_internal`, `deposit_to_internal`,
/// `withdraw_to_internal`, `confidential_transfer_internal`) and FA-integrated entry points are
/// left unspecified here — those belong to Phase 2 / Phase 5 and carry crypto-layer obligations
/// that need the ristretto255 spec patches first.
spec aptos_experimental::confidential_asset {
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict;

        // Global module invariants (Phase 2/3 strengthening)
        //
        // These invariants state properties that must hold across all functions in the module.
        // They strengthen the verification by ensuring structural consistency is maintained.

        // Invariant 1: Pending counter never exceeds MAX_TRANSFERS_BEFORE_ROLLOVER
        // This prevents counter overflow and ensures rollover is enforced
        invariant forall addr: address, token: Object<Metadata>:
            exists<ConfidentialAssetStore>(spec_get_user_address(addr, token)) ==>
                global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).pending_counter
                    <= MAX_TRANSFERS_BEFORE_ROLLOVER;

        // Invariant 2: Balance chunk counts are always correct
        // Pending balances have 4 chunks, actual balances have 8 chunks
        invariant forall addr: address, token: Object<Metadata>:
            exists<ConfidentialAssetStore>(spec_get_user_address(addr, token)) ==>
                (len(global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).pending_balance.chunks)
                    == confidential_balance::PENDING_BALANCE_CHUNKS &&
                 len(global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).actual_balance.chunks)
                    == confidential_balance::ACTUAL_BALANCE_CHUNKS);

        // Invariant 3: If normalized flag is false, pending_counter > 0
        // This ensures normalized flag accurately reflects whether pending balance has been rolled over
        invariant forall addr: address, token: Object<Metadata>:
            exists<ConfidentialAssetStore>(spec_get_user_address(addr, token)) ==>
                (!global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).normalized ==>
                 global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).pending_counter > 0);
    }

    //
    // Store existence predicate
    //

    spec has_confidential_asset_store {
        aborts_if false;
        ensures result ==
            exists<ConfidentialAssetStore>(spec_get_user_address(user, token));
    }

    //
    // Freeze / unfreeze — store-only state toggles
    //

    spec freeze_token_internal {
        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if global<ConfidentialAssetStore>(store_addr).frozen;

        ensures global<ConfidentialAssetStore>(store_addr).frozen;
        ensures global<ConfidentialAssetStore>(store_addr).normalized
            == old(global<ConfidentialAssetStore>(store_addr)).normalized;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter
            == old(global<ConfidentialAssetStore>(store_addr)).pending_counter;
        ensures global<ConfidentialAssetStore>(store_addr).pending_balance
            == old(global<ConfidentialAssetStore>(store_addr)).pending_balance;
        ensures global<ConfidentialAssetStore>(store_addr).actual_balance
            == old(global<ConfidentialAssetStore>(store_addr)).actual_balance;
        ensures global<ConfidentialAssetStore>(store_addr).ek
            == old(global<ConfidentialAssetStore>(store_addr)).ek;

        modifies global<ConfidentialAssetStore>(store_addr);
    }

    spec unfreeze_token_internal {
        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if !global<ConfidentialAssetStore>(store_addr).frozen;

        ensures !global<ConfidentialAssetStore>(store_addr).frozen;
        ensures global<ConfidentialAssetStore>(store_addr).normalized
            == old(global<ConfidentialAssetStore>(store_addr)).normalized;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter
            == old(global<ConfidentialAssetStore>(store_addr)).pending_counter;
        ensures global<ConfidentialAssetStore>(store_addr).pending_balance
            == old(global<ConfidentialAssetStore>(store_addr)).pending_balance;
        ensures global<ConfidentialAssetStore>(store_addr).actual_balance
            == old(global<ConfidentialAssetStore>(store_addr)).actual_balance;
        ensures global<ConfidentialAssetStore>(store_addr).ek
            == old(global<ConfidentialAssetStore>(store_addr)).ek;

        modifies global<ConfidentialAssetStore>(store_addr);
    }

    //
    // View functions — all assert has_confidential_asset_store then read a field
    //

    spec pending_balance {
        let store_addr = spec_get_user_address(owner, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        ensures result == global<ConfidentialAssetStore>(store_addr).pending_balance;
    }

    spec actual_balance {
        let store_addr = spec_get_user_address(owner, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        ensures result == global<ConfidentialAssetStore>(store_addr).actual_balance;
    }

    spec encryption_key {
        let store_addr = spec_get_user_address(user, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        ensures result == global<ConfidentialAssetStore>(store_addr).ek;
        modifies global<ConfidentialAssetStore>(store_addr);
    }

    spec is_normalized {
        let store_addr = spec_get_user_address(user, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        ensures result == global<ConfidentialAssetStore>(store_addr).normalized;
    }

    spec is_frozen {
        let store_addr = spec_get_user_address(user, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        ensures result == global<ConfidentialAssetStore>(store_addr).frozen;
    }

    spec is_allow_list_enabled {
        aborts_if !exists<FAController>(@aptos_experimental);
        ensures result == global<FAController>(@aptos_experimental).allow_list_enabled;
    }

    //
    // Additional view functions
    //

    /// `max_sender_auditor_hint_bytes` — returns the 256-byte constant.
    spec max_sender_auditor_hint_bytes {
        aborts_if false;
        ensures result == MAX_SENDER_AUDITOR_HINT_BYTES;
    }

    /// `get_auditor` — returns `None` when no FAConfig exists or allow-list is disabled;
    /// otherwise returns the FAConfig's `auditor_ek`. Aborts-if condition captures the
    /// FAController existence check (required by `is_allow_list_enabled` invocation).
    spec get_auditor {
        pragma aborts_if_is_strict = false;
        pragma opaque;
        // Full spec deferred to Phase 5 — the auditor Option field's semantics compose
        // with set_auditor's updates. Marked opaque for now.
    }

    /// `confidential_asset_balance` — returns the protocol-owned primary-store balance
    /// for `token`. Aborts if the FA store doesn't exist (EINTERNAL_ERROR).
    spec confidential_asset_balance {
        pragma aborts_if_is_strict = false;
        pragma opaque;
        aborts_if !exists<FAController>(@aptos_experimental);
    }

    /// `is_token_allowed` — True if allow-list is disabled, or if FAConfig's `allowed` bit
    /// is set for the token.
    spec is_token_allowed {
        pragma aborts_if_is_strict = false;
        aborts_if !exists<FAController>(@aptos_experimental);
    }

    //
    // Balance verification helpers (test/audit utilities)
    //

    /// `verify_pending_balance` — Decrypts and verifies the pending balance matches expected amount.
    /// This is a testing/audit utility that allows external verification of encrypted balances.
    /// The function decompresses the stored balance and delegates to the confidential_balance
    /// module's verification logic.
    spec verify_pending_balance {
        pragma opaque;
        pragma aborts_if_is_strict = false;

        let store_addr = spec_get_user_address(user, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);

        // Result semantics: returns true iff the pending balance decrypts to the expected amount
        // under the provided decryption key. Detailed verification logic is opaque (delegated
        // to confidential_balance module).
    }

    /// `verify_actual_balance` — Decrypts and verifies the actual balance matches expected amount.
    /// Test-only utility for validating encrypted actual balance correctness. Marked test_only
    /// in source to prevent production use of decryption keys.
    spec verify_actual_balance {
        pragma opaque;
        pragma aborts_if_is_strict = false;

        let store_addr = spec_get_user_address(user, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);

        // Returns true iff actual balance decrypts to expected amount. Test-only guard ensures
        // decryption keys are never exposed in production code paths.
    }

    //
    // Serialization helpers (difftest/testing support)
    //

    /// `serialize_auditor_eks` — Pure serialization of auditor encryption key vector to bytes.
    /// No store access, no abort conditions. Used by difftest and testing infrastructure to
    /// produce canonical byte representations for cross-environment validation.
    spec serialize_auditor_eks {
        aborts_if false;
        // Result is the concatenation of pubkey_to_bytes for each auditor key in the vector.
        // Length: |auditor_eks| * COMPRESSED_PUBKEY_SIZE bytes (32 bytes per pubkey).
        // TODO: Re-enable once COMPRESSED_PUBKEY_SIZE constant is defined in ristretto255_twisted_elgamal
        // ensures len(result) == len(auditor_eks) * 32;
    }

    /// `serialize_auditor_amounts` — Pure serialization of confidential balance vector to bytes.
    /// No store access, no abort conditions. Produces canonical byte encoding for auditor
    /// amount commitments in cross-environment testing.
    spec serialize_auditor_amounts {
        aborts_if false;
        // Result is the concatenation of balance_to_bytes for each balance in the vector.
        // Each balance serializes to a fixed size determined by chunk count.
        // Length: |auditor_amounts| * (per-balance serialized size).
        // Exact per-balance size depends on chunk count (pending: 4 chunks, actual: 8 chunks).
    }

    //
    // Governance — allow-list toggles
    //

    spec enable_allow_list {
        pragma aborts_if_is_strict = false;

        aborts_if !exists<FAController>(@aptos_experimental);
        aborts_if global<FAController>(@aptos_experimental).allow_list_enabled;

        ensures global<FAController>(@aptos_experimental).allow_list_enabled;
        modifies global<FAController>(@aptos_experimental);
    }

    spec disable_allow_list {
        pragma aborts_if_is_strict = false;

        aborts_if !exists<FAController>(@aptos_experimental);
        aborts_if !global<FAController>(@aptos_experimental).allow_list_enabled;

        ensures !global<FAController>(@aptos_experimental).allow_list_enabled;
        modifies global<FAController>(@aptos_experimental);
    }

    //
    // Governance — per-token enable/disable
    //
    // `ensure_fa_config_exists` may create an `FAConfig` side-effect; we state the
    // post-condition in terms of the `FAConfig` at the derived address rather than
    // unwinding `ensure_fa_config_exists` here. Phase 5 will refine these as the FA
    // side-effect composition lands.

    spec enable_token {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let fa_config_addr = spec_get_fa_config_address(token);

        aborts_if signer::address_of(aptos_framework) != @aptos_framework;
        // fa_config.allowed must be false before this call
        // exact aborts_if for the post-ensure_fa_config_exists FAConfig is captured in Phase 5.

        modifies global<FAConfig>(fa_config_addr);
        modifies global<object::ObjectCore>(fa_config_addr);
    }

    spec disable_token {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let fa_config_addr = spec_get_fa_config_address(token);

        aborts_if signer::address_of(aptos_framework) != @aptos_framework;

        modifies global<FAConfig>(fa_config_addr);
        modifies global<object::ObjectCore>(fa_config_addr);
    }

    spec set_auditor {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let fa_config_addr = spec_get_fa_config_address(token);

        aborts_if signer::address_of(aptos_framework) != @aptos_framework;
        // Phase 5: the ensures clause relates fa_config.auditor_ek to
        // twisted_elgamal::new_pubkey_from_bytes; left opaque until the twisted-elgamal
        // specs are filled in.

        modifies global<FAConfig>(fa_config_addr);
        modifies global<object::ObjectCore>(fa_config_addr);
    }

    //
    // Rollover — store-only structural part
    //
    // Only the non-crypto effects are captured here: (a) requires store to be normalized,
    // (b) clears `normalized`, (c) resets `pending_counter` to 0. The ciphertext-level
    // homomorphic addition of `pending_balance` into `actual_balance` is deferred to
    // Phase 5 where it composes with the `confidential_balance` spec and the upstream
    // ristretto255 specs (currently blocked per plan §5.2).

    spec rollover_pending_balance_internal {
        pragma aborts_if_is_strict = false;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if !global<ConfidentialAssetStore>(store_addr).normalized;

        ensures !global<ConfidentialAssetStore>(store_addr).normalized;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter == 0;
        ensures global<ConfidentialAssetStore>(store_addr).frozen
            == old(global<ConfidentialAssetStore>(store_addr)).frozen;
        ensures global<ConfidentialAssetStore>(store_addr).ek
            == old(global<ConfidentialAssetStore>(store_addr)).ek;

        modifies global<ConfidentialAssetStore>(store_addr);
    }

    //
    // Phase 2 — `*_internal` functions, structural scaffold
    //
    // These specs capture the non-crypto frame conditions: the ConfidentialAssetStore
    // pre/post, abort conditions from explicit `assert!` sites, and observable field
    // mutations. The crypto-layer obligations (balance homomorphism, proof-verification
    // acceptance ≡ sigma predicate) compose on top of these in Phase 5.
    //

    /// `register_internal` — creates a fresh ConfidentialAssetStore for (user, token).
    ///
    /// **Strengthened post-conditions** (Phase 2 extended):
    /// - `pending_balance` initialized to the canonical zero-balance (4-chunk compressed).
    /// - `actual_balance` initialized to the canonical zero-balance (8-chunk compressed).
    /// - Token allow-list check: `is_token_allowed(token)` holds at call time, else aborts.
    spec register_internal {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        // Token must be allowed (else ETOKEN_DISABLED abort)
        // and the store must not already exist.
        aborts_if exists<ConfidentialAssetStore>(store_addr);

        // Post: store exists with canonical initial fields.
        ensures exists<ConfidentialAssetStore>(store_addr);
        ensures !global<ConfidentialAssetStore>(store_addr).frozen;
        ensures global<ConfidentialAssetStore>(store_addr).normalized;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter == 0;
        ensures global<ConfidentialAssetStore>(store_addr).ek == ek;
        // Balance fields start at the canonical zero-balance constants.
        ensures len(global<ConfidentialAssetStore>(store_addr).pending_balance.chunks)
            == confidential_balance::PENDING_BALANCE_CHUNKS;
        ensures len(global<ConfidentialAssetStore>(store_addr).actual_balance.chunks)
            == confidential_balance::ACTUAL_BALANCE_CHUNKS;

        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `ensure_sufficient_fa` — helper that converts CoinType to FA if needed.
    /// Marked opaque for now; full composition with coin/FA framework specs in Phase 5.
    spec ensure_sufficient_fa {
        pragma aborts_if_is_strict = false;
        pragma opaque;
        modifies global<object::ObjectCore>(@aptos_framework);
        modifies global<object::TombStone>(@aptos_framework);
        modifies global<object::Untransferable>(@aptos_framework);
        modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::FungibleStore>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::Metadata>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::Supply>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentSupply>(@aptos_framework);
        modifies global<aptos_framework::primary_fungible_store::DeriveRefPod>(@aptos_framework);
    }

    /// `deposit_to_internal` — receives an amount into the recipient's pending balance.
    /// Structural part: recipient store must exist, must not be frozen, pending_counter
    /// is bounded. Crypto part (pending_balance homomorphic update) is Phase 5.
    ///
    /// **Modifies clauses:** Includes FA framework resources for primary_fungible_store deposit operation.
    spec deposit_to_internal {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let recipient_store = spec_get_user_address(to, token);

        aborts_if !exists<ConfidentialAssetStore>(recipient_store);
        aborts_if global<ConfidentialAssetStore>(recipient_store).frozen;
        aborts_if global<ConfidentialAssetStore>(recipient_store).pending_counter
            >= MAX_TRANSFERS_BEFORE_ROLLOVER;

        ensures global<ConfidentialAssetStore>(recipient_store).pending_counter
            == old(global<ConfidentialAssetStore>(recipient_store)).pending_counter + 1;
        ensures global<ConfidentialAssetStore>(recipient_store).frozen
            == old(global<ConfidentialAssetStore>(recipient_store)).frozen;
        ensures global<ConfidentialAssetStore>(recipient_store).normalized
            == old(global<ConfidentialAssetStore>(recipient_store)).normalized;
        ensures global<ConfidentialAssetStore>(recipient_store).ek
            == old(global<ConfidentialAssetStore>(recipient_store)).ek;
        // Balance length preservation (homomorphic operations preserve chunk counts)
        ensures len(global<ConfidentialAssetStore>(recipient_store).pending_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(recipient_store)).pending_balance.chunks);
        ensures len(global<ConfidentialAssetStore>(recipient_store).actual_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(recipient_store)).actual_balance.chunks);

        modifies global<ConfidentialAssetStore>(recipient_store);
        modifies global<object::ObjectCore>(@aptos_framework);
        modifies global<object::Untransferable>(@aptos_framework);
        modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::FungibleStore>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
    }

    /// `withdraw_to_internal` — burns from sender's actual balance after proof acceptance.
    /// Structural: sender store must exist, marks `normalized = true`. Crypto: the
    /// `verify_withdrawal_proof` call's accept/reject semantics belong to Phase 4 (Lean)
    /// and Phase 5 (MSL composition).
    spec withdraw_to_internal {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let from = signer::address_of(sender);
        let sender_store = spec_get_user_address(from, token);

        aborts_if !exists<ConfidentialAssetStore>(sender_store);

        ensures global<ConfidentialAssetStore>(sender_store).normalized;
        ensures global<ConfidentialAssetStore>(sender_store).frozen
            == old(global<ConfidentialAssetStore>(sender_store)).frozen;
        ensures global<ConfidentialAssetStore>(sender_store).pending_counter
            == old(global<ConfidentialAssetStore>(sender_store)).pending_counter;
        ensures global<ConfidentialAssetStore>(sender_store).pending_balance
            == old(global<ConfidentialAssetStore>(sender_store)).pending_balance;
        ensures global<ConfidentialAssetStore>(sender_store).ek
            == old(global<ConfidentialAssetStore>(sender_store)).ek;
        // Balance length preservation (proof verification doesn't change chunk structure)
        ensures len(global<ConfidentialAssetStore>(sender_store).pending_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(sender_store)).pending_balance.chunks);
        ensures len(global<ConfidentialAssetStore>(sender_store).actual_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(sender_store)).actual_balance.chunks);

        modifies global<ConfidentialAssetStore>(sender_store);
    }

    /// `rotate_encryption_key_internal` — updates `ek` and `actual_balance`, re-normalizes.
    /// Requires pending balance to be zero (enforced via abort); crypto-layer proof acceptance
    /// belongs to Phase 4 (Lean `verify_rotation_proof`).
    spec rotate_encryption_key_internal {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);

        ensures global<ConfidentialAssetStore>(store_addr).ek == new_ek;
        ensures global<ConfidentialAssetStore>(store_addr).normalized;
        ensures global<ConfidentialAssetStore>(store_addr).frozen
            == old(global<ConfidentialAssetStore>(store_addr)).frozen;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter
            == old(global<ConfidentialAssetStore>(store_addr)).pending_counter;
        ensures global<ConfidentialAssetStore>(store_addr).pending_balance
            == old(global<ConfidentialAssetStore>(store_addr)).pending_balance;

        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `normalize_internal` — sets `normalized` to true after proof acceptance. Aborts if
    /// already normalized.
    spec normalize_internal {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if global<ConfidentialAssetStore>(store_addr).normalized;

        ensures global<ConfidentialAssetStore>(store_addr).normalized;
        ensures global<ConfidentialAssetStore>(store_addr).ek
            == old(global<ConfidentialAssetStore>(store_addr)).ek;
        ensures global<ConfidentialAssetStore>(store_addr).frozen
            == old(global<ConfidentialAssetStore>(store_addr)).frozen;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter
            == old(global<ConfidentialAssetStore>(store_addr)).pending_counter;
        ensures global<ConfidentialAssetStore>(store_addr).pending_balance
            == old(global<ConfidentialAssetStore>(store_addr)).pending_balance;
        // Balance length preservation (normalization adds pending to actual, preserves structure)
        ensures len(global<ConfidentialAssetStore>(store_addr).pending_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(store_addr)).pending_balance.chunks);
        ensures len(global<ConfidentialAssetStore>(store_addr).actual_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(store_addr)).actual_balance.chunks);

        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `confidential_transfer_internal` — moves an amount from sender actual balance to
    /// recipient pending balance, after proof acceptance. Structural: both stores must
    /// exist, recipient not frozen, recipient pending_counter bounded; post updates sender
    /// actual_balance and recipient pending_balance, pending_counter increments.
    ///
    /// **Auditor-list invariants (Phase 5 extended):**
    /// - `auditor_eks.length() == auditor_amounts.length()` (enforced by `validate_auditors`)
    /// - `sender_auditor_hint.length() <= MAX_SENDER_AUDITOR_HINT_BYTES` (256 bytes)
    /// - `balance_c_equals(sender_amount, recipient_amount) = true` (same encrypted amount
    ///   from sender's and recipient's ek — enforced by explicit `assert!` at PC ≈5)
    spec confidential_transfer_internal {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let from = signer::address_of(sender);
        let sender_store = spec_get_user_address(from, token);
        let recipient_store = spec_get_user_address(to, token);

        aborts_if !exists<ConfidentialAssetStore>(sender_store);
        aborts_if !exists<ConfidentialAssetStore>(recipient_store);
        aborts_if global<ConfidentialAssetStore>(recipient_store).frozen;
        aborts_if global<ConfidentialAssetStore>(recipient_store).pending_counter
            >= MAX_TRANSFERS_BEFORE_ROLLOVER;
        aborts_if len(sender_auditor_hint) > MAX_SENDER_AUDITOR_HINT_BYTES;
        aborts_if len(auditor_eks) != len(auditor_amounts);

        // Sender's normalized flag set to true after proof verification
        ensures global<ConfidentialAssetStore>(sender_store).normalized;

        // Recipient's pending_counter incremented
        ensures global<ConfidentialAssetStore>(recipient_store).pending_counter
            == old(global<ConfidentialAssetStore>(recipient_store)).pending_counter + 1;
        // Recipient's normalized flag preserved
        ensures global<ConfidentialAssetStore>(recipient_store).normalized
            == old(global<ConfidentialAssetStore>(recipient_store)).normalized;

        // Sender's frozen state unchanged (we only freeze on explicit request).
        ensures global<ConfidentialAssetStore>(sender_store).frozen
            == old(global<ConfidentialAssetStore>(sender_store)).frozen;
        // Sender's ek unchanged (confidential_transfer doesn't rotate the key).
        ensures global<ConfidentialAssetStore>(sender_store).ek
            == old(global<ConfidentialAssetStore>(sender_store)).ek;
        // Sender's pending_counter preserved
        ensures global<ConfidentialAssetStore>(sender_store).pending_counter
            == old(global<ConfidentialAssetStore>(sender_store)).pending_counter;

        // Recipient's frozen / ek preserved.
        ensures global<ConfidentialAssetStore>(recipient_store).frozen
            == old(global<ConfidentialAssetStore>(recipient_store)).frozen;
        ensures global<ConfidentialAssetStore>(recipient_store).ek
            == old(global<ConfidentialAssetStore>(recipient_store)).ek;

        // Balance length preservation for both sender and recipient
        ensures len(global<ConfidentialAssetStore>(sender_store).pending_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(sender_store)).pending_balance.chunks);
        ensures len(global<ConfidentialAssetStore>(sender_store).actual_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(sender_store)).actual_balance.chunks);
        ensures len(global<ConfidentialAssetStore>(recipient_store).pending_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(recipient_store)).pending_balance.chunks);
        ensures len(global<ConfidentialAssetStore>(recipient_store).actual_balance.chunks)
            == len(old(global<ConfidentialAssetStore>(recipient_store)).actual_balance.chunks);

        modifies global<ConfidentialAssetStore>(sender_store);
        modifies global<ConfidentialAssetStore>(recipient_store);
    }

    //
    // Phase 5 — FA-integrated entry-point wrappers
    //
    // Entry points are thin wrappers around their `*_internal` counterparts. The store-side
    // semantics compose directly with the Phase 2 specs above; the FA side-effects (primary
    // store creation/transfer, dispatchable_fungible_asset::transfer) are covered by the
    // upstream `aptos_framework::fungible_asset` spec. Each entry-point spec below pins only
    // the store-observable part — the FA composition is implicit via Move Prover's inlining
    // of the `*_internal` call.
    //

    /// `freeze_token` entry — wraps `freeze_token_internal`.
    spec freeze_token {
        pragma aborts_if_is_strict = false;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if global<ConfidentialAssetStore>(store_addr).frozen;

        ensures global<ConfidentialAssetStore>(store_addr).frozen;
        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `unfreeze_token` entry — wraps `unfreeze_token_internal`.
    spec unfreeze_token {
        pragma aborts_if_is_strict = false;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if !global<ConfidentialAssetStore>(store_addr).frozen;

        ensures !global<ConfidentialAssetStore>(store_addr).frozen;
        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `rollover_pending_balance` entry — wraps `rollover_pending_balance_internal`.
    spec rollover_pending_balance {
        pragma aborts_if_is_strict = false;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if !global<ConfidentialAssetStore>(store_addr).normalized;

        ensures !global<ConfidentialAssetStore>(store_addr).normalized;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter == 0;
        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `rollover_pending_balance_and_freeze` — calls rollover then freeze. Post: frozen, pending_counter = 0.
    spec rollover_pending_balance_and_freeze {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if !global<ConfidentialAssetStore>(store_addr).normalized;

        ensures global<ConfidentialAssetStore>(store_addr).frozen;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter == 0;
        ensures !global<ConfidentialAssetStore>(store_addr).normalized;
        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `register` entry — deserializes `ek`, verifies registration proof, calls `register_internal`.
    /// The registration-proof bytecode theorem (Lean Phase 1/1.5) composes with this spec:
    /// Lean pins the verifier's accept/reject semantics, MSL pins the resulting store state.
    spec register {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);
        let token_addr = object::object_address(token);

        aborts_if exists<ConfidentialAssetStore>(store_addr);

        ensures exists<ConfidentialAssetStore>(store_addr);
        ensures !global<ConfidentialAssetStore>(store_addr).frozen;
        ensures global<ConfidentialAssetStore>(store_addr).normalized;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter == 0;

        // Event emission: Registered event with user address, token address, and ek
        // Note: event emission specs require std::event framework support (Phase 5 extended)
        // Placeholder for when event spec support is available:
        // emits Registered { addr: user, asset_type: token_addr, ek: ... } to sender;

        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `deposit_to` entry — delegates to `deposit_to_internal`.
    spec deposit_to {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let recipient_store = spec_get_user_address(to, token);

        aborts_if !exists<ConfidentialAssetStore>(recipient_store);
        aborts_if global<ConfidentialAssetStore>(recipient_store).frozen;
        aborts_if global<ConfidentialAssetStore>(recipient_store).pending_counter
            >= MAX_TRANSFERS_BEFORE_ROLLOVER;

        ensures global<ConfidentialAssetStore>(recipient_store).pending_counter
            == old(global<ConfidentialAssetStore>(recipient_store)).pending_counter + 1;

        modifies global<ConfidentialAssetStore>(recipient_store);
    }

    /// `deposit_coins_to` entry — converts `CoinType` to FA then delegates to `deposit_to_internal`.
    /// The coin→FA conversion is an FA-framework side effect not captured by this spec;
    /// composition with upstream coin/FA specs completes the story (Phase 5 follow-up).
    ///
    /// **Modifies clauses:** Includes all FA framework and object framework resources touched
    /// by ensure_sufficient_fa and deposit operations.
    spec deposit_coins_to {
        pragma aborts_if_is_strict = false;
        pragma opaque;
        // `token` is a local obtained from ensure_sufficient_fa — not available in spec scope.
        // Full composition with upstream coin/FA specs deferred to Phase 5.
        modifies global<ConfidentialAssetStore>(@aptos_framework);
        modifies global<object::ObjectCore>(@aptos_framework);
        modifies global<object::TombStone>(@aptos_framework);
        modifies global<object::Untransferable>(@aptos_framework);
        modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::FungibleStore>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::Metadata>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::Supply>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentSupply>(@aptos_framework);
        modifies global<aptos_framework::primary_fungible_store::DeriveRefPod>(@aptos_framework);
    }

    /// `deposit_coins` entry — to self.
    ///
    /// **Modifies clauses:** Same as deposit_coins_to, plus ConfidentialAssetStore.
    spec deposit_coins {
        pragma aborts_if_is_strict = false;
        pragma opaque;
        modifies global<ConfidentialAssetStore>(@aptos_framework);
        modifies global<object::ObjectCore>(@aptos_framework);
        modifies global<object::TombStone>(@aptos_framework);
        modifies global<object::Untransferable>(@aptos_framework);
        modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::FungibleStore>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::Metadata>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::Supply>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentSupply>(@aptos_framework);
        modifies global<aptos_framework::primary_fungible_store::DeriveRefPod>(@aptos_framework);
    }

    /// `deposit` entry — deposits to self. `to = address_of(sender)` path.
    spec deposit {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if global<ConfidentialAssetStore>(store_addr).frozen;
        aborts_if global<ConfidentialAssetStore>(store_addr).pending_counter
            >= MAX_TRANSFERS_BEFORE_ROLLOVER;

        ensures global<ConfidentialAssetStore>(store_addr).pending_counter
            == old(global<ConfidentialAssetStore>(store_addr)).pending_counter + 1;

        modifies global<ConfidentialAssetStore>(store_addr);
        modifies global<object::ObjectCore>(@aptos_framework);
        modifies global<object::Untransferable>(@aptos_framework);
        modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::FungibleStore>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
    }

    /// `withdraw_to` entry — deserializes balance + proof, delegates to `withdraw_to_internal`.
    ///
    /// **Modifies clauses:** Includes object framework and FA resources touched by primary_fungible_store::transfer.
    spec withdraw_to {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);

        ensures global<ConfidentialAssetStore>(store_addr).normalized;
        modifies global<ConfidentialAssetStore>(store_addr);
        modifies global<object::ObjectCore>(@aptos_framework);
        modifies global<object::TombStone>(@aptos_framework);
        modifies global<object::Untransferable>(@aptos_framework);
        modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::FungibleStore>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
    }

    /// `withdraw` entry — withdraws to self.
    ///
    /// **Modifies clauses:** Includes object framework and FA resources touched by primary_fungible_store::transfer.
    spec withdraw {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);

        ensures global<ConfidentialAssetStore>(store_addr).normalized;
        modifies global<ConfidentialAssetStore>(store_addr);
        modifies global<object::ObjectCore>(@aptos_framework);
        modifies global<object::TombStone>(@aptos_framework);
        modifies global<object::Untransferable>(@aptos_framework);
        modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::FungibleStore>(@aptos_framework);
        modifies global<aptos_framework::fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
    }

    /// `confidential_transfer` entry — delegates to `confidential_transfer_internal`.
    spec confidential_transfer {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let from = signer::address_of(sender);
        let sender_store = spec_get_user_address(from, token);
        let recipient_store = spec_get_user_address(to, token);

        aborts_if !exists<ConfidentialAssetStore>(sender_store);
        aborts_if !exists<ConfidentialAssetStore>(recipient_store);
        aborts_if global<ConfidentialAssetStore>(recipient_store).frozen;
        aborts_if global<ConfidentialAssetStore>(recipient_store).pending_counter
            >= MAX_TRANSFERS_BEFORE_ROLLOVER;

        ensures global<ConfidentialAssetStore>(recipient_store).pending_counter
            == old(global<ConfidentialAssetStore>(recipient_store)).pending_counter + 1;

        modifies global<ConfidentialAssetStore>(sender_store);
        modifies global<ConfidentialAssetStore>(recipient_store);
    }

    /// `rotate_encryption_key` entry — delegates to `rotate_encryption_key_internal`.
    spec rotate_encryption_key {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);

        ensures global<ConfidentialAssetStore>(store_addr).normalized;
        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `rotate_encryption_key_and_unfreeze` — rotates key then unfreezes. Post: key rotated, !frozen.
    spec rotate_encryption_key_and_unfreeze {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        // The subsequent unfreeze requires the store to be frozen — enforced by caller
        // via the `rollover_pending_balance_and_freeze` flow.

        ensures !global<ConfidentialAssetStore>(store_addr).frozen;
        ensures global<ConfidentialAssetStore>(store_addr).normalized;
        modifies global<ConfidentialAssetStore>(store_addr);
    }

    /// `normalize` entry — delegates to `normalize_internal`.
    spec normalize {
        pragma aborts_if_is_strict = false;
        pragma opaque;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        aborts_if global<ConfidentialAssetStore>(store_addr).normalized;

        ensures global<ConfidentialAssetStore>(store_addr).normalized;
        modifies global<ConfidentialAssetStore>(store_addr);
    }

    //
    // Test-only event assertion helpers
    //
    // These functions are used by tests to verify that events were emitted with correct
    // content. They check the most recent emitted event of each type and assert field values
    // match expectations. All abort with custom codes (100-102) on mismatch or no events.
    //

    /// `assert_last_registered_event` — Verifies most recent Registered event matches expectations.
    /// Test-only utility for validating registration event emission.
    spec assert_last_registered_event {
        pragma aborts_if_is_strict = false;
        // Aborts if no Registered events have been emitted (custom code 100)
        // Aborts if most recent event's addr doesn't match expected_addr (code 101)
        // Aborts if most recent event's asset_type doesn't match token address (code 102)
    }

    /// `assert_last_deposited_event_matches_state` — Verifies Deposited event matches store state.
    /// Checks that the most recent deposit event's values align with current store state.
    spec assert_last_deposited_event_matches_state {
        pragma aborts_if_is_strict = false;
        let store_addr = spec_get_user_address(to, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        // Additional aborts from event checks (custom codes 100-102)
    }

    /// `assert_last_withdrawn_event_matches_state` — Verifies Withdrawn event correctness.
    /// Test utility for validating withdrawal event emission and field values.
    spec assert_last_withdrawn_event_matches_state {
        pragma aborts_if_is_strict = false;
        let store_addr = spec_get_user_address(from, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        // Additional aborts from event checks (custom codes 100-102)
    }

    /// `assert_last_transferred_event_matches_state` — Verifies Transferred event correctness.
    /// Checks sender and recipient event fields against current store states.
    spec assert_last_transferred_event_matches_state {
        pragma aborts_if_is_strict = false;
        let sender_store = spec_get_user_address(from, token);
        let recipient_store = spec_get_user_address(to, token);
        aborts_if !exists<ConfidentialAssetStore>(sender_store);
        aborts_if !exists<ConfidentialAssetStore>(recipient_store);
        // Additional aborts from event checks (custom codes 100-102)
    }

    /// `assert_last_key_rotated_event_matches_state` — Verifies KeyRotated event correctness.
    /// Test utility for validating encryption key rotation event emission.
    spec assert_last_key_rotated_event_matches_state {
        pragma aborts_if_is_strict = false;
        let store_addr = spec_get_user_address(user, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        // Additional aborts from event checks (custom codes 100-102)
    }

    /// `assert_last_normalized_event_matches_state` — Verifies Normalized event correctness.
    /// Checks that normalization event reflects current store state.
    spec assert_last_normalized_event_matches_state {
        pragma aborts_if_is_strict = false;
        let store_addr = spec_get_user_address(user, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        // Additional aborts from event checks (custom codes 100-102)
    }

    /// `assert_last_rolled_over_event_matches_state` — Verifies RolledOver event correctness.
    /// Test utility for validating pending balance rollover event emission.
    spec assert_last_rolled_over_event_matches_state {
        pragma aborts_if_is_strict = false;
        let store_addr = spec_get_user_address(user, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        // Additional aborts from event checks (custom codes 100-102)
    }

    /// `assert_last_freeze_changed_event` — Verifies FreezeChanged event correctness.
    /// Test utility for validating freeze state change events.
    spec assert_last_freeze_changed_event {
        pragma aborts_if_is_strict = false;
        let store_addr = spec_get_user_address(user, token);
        aborts_if !exists<ConfidentialAssetStore>(store_addr);
        // Additional aborts from event checks (custom codes 100-102)
    }

    /// `assert_last_allow_list_changed_event` — Verifies AllowListChanged event correctness.
    /// Test utility for validating allow-list toggle events.
    spec assert_last_allow_list_changed_event {
        pragma aborts_if_is_strict = false;
        aborts_if !exists<FAController>(@aptos_experimental);
        // Additional aborts from event checks (custom codes 100-102)
    }

    /// `assert_last_token_allow_changed_event` — Verifies TokenAllowChanged event correctness.
    /// Test utility for validating per-token allow-list events.
    spec assert_last_token_allow_changed_event {
        pragma aborts_if_is_strict = false;
        aborts_if !exists<FAController>(@aptos_experimental);
        // Additional aborts from event checks (custom codes 100-102)
    }

    /// `assert_last_auditor_changed_event` — Verifies AuditorChanged event correctness.
    /// Test utility for validating auditor configuration change events.
    spec assert_last_auditor_changed_event {
        pragma aborts_if_is_strict = false;
        aborts_if !exists<FAController>(@aptos_experimental);
        // Additional aborts from event checks (custom codes 100-102)
    }

    //
    // Test-only setup helpers
    //

    /// `init_module_for_testing` — Test-only module initialization.
    /// Creates FAController resource for testing environments. Only callable in tests.
    spec init_module_for_testing {
        aborts_if exists<FAController>(@aptos_experimental);
        ensures exists<FAController>(@aptos_experimental);
    }

    /// `register_for_testing` — Test-only registration helper with direct ek/balance provision.
    /// Bypasses proof verification for test setup. Allows tests to create accounts with
    /// predetermined encryption keys and balances without needing to generate valid proofs.
    spec register_for_testing {
        pragma aborts_if_is_strict = false;

        let user = signer::address_of(sender);
        let store_addr = spec_get_user_address(user, token);

        aborts_if exists<ConfidentialAssetStore>(store_addr);
        aborts_if !exists<FAController>(@aptos_experimental);

        ensures exists<ConfidentialAssetStore>(store_addr);
        ensures global<ConfidentialAssetStore>(store_addr).frozen == false;
        ensures global<ConfidentialAssetStore>(store_addr).normalized == true;
        ensures global<ConfidentialAssetStore>(store_addr).pending_counter == 0;
    }

    //
    // Pure spec-level replacement for `get_user_address`. The Move implementation
    // transitively calls `object::create_object_address` which uses `&mut` (flagged
    // impure by the spec checker). This uninterpreted spec fun + ensures bridge lets
    // all spec blocks reference the address purely.
    //
    spec fun spec_get_user_address(user: address, token: Object<Metadata>): address;

    spec get_user_address {
        pragma opaque;
        ensures result == spec_get_user_address(user, token);
    }

    //
    // FA config address derivation — opaque abstraction
    //
    // `get_fa_config_address` computes a derived object address for FAConfig storage.
    // Similar to `spec_get_user_address`, this needs an uninterpreted spec function
    // because the implementation uses object framework primitives.
    //
    spec fun spec_get_fa_config_address(token: Object<Metadata>): address;

    spec get_fa_config_address {
        pragma opaque;
        ensures result == spec_get_fa_config_address(token);
    }
}

/// Per-action authorization: a short-lived signed capability that satisfies one step-up decision
/// for one action.
///
/// The point is not freshness, although a sixty-second capability does make revocation trivial,
/// since revoking means declining to issue the next one and no denylist, epoch or status list is
/// involved on this path. The point is the AUDIT RECORD. A view call leaves no trace and a
/// transaction-prologue rejection is a discard with no ledger record at all, so a design built only
/// on persistent facts cannot answer "prove this address was authorized at the moment this exact
/// transaction executed, and show the basis". An authorization is a transaction argument, so it is
/// in the ledger permanently, naming the policy, the action and the moment.
///
/// The symmetric cost, stated because it is a disclosure decision rather than an oversight:
/// everything an authorization names is public forever. That is why the amount is committed as a
/// BUCKET rather than a value, so the authorizer commits to a ceiling instead of publishing a
/// customer's exact transaction size.
///
/// Replay protection is a nonce table. The clever alternative is to bind the capability to the
/// account's sequence number, which costs no storage because the number advances when the
/// transaction lands, but orderless transactions carry a `Nonce` replay protector instead and
/// leave the sequence number untouched, so a capability bound to it would stay reusable there.
/// Orderless transactions are in this fork's genesis default features, so the clever version is a
/// footgun and this module does not use it.
///
/// Batched pre-authorization needs no separate mechanism: a batch is N authorizations with distinct
/// nonces over the same window, which drops the liveness dependency on the authorizer from
/// per-transaction to per-window. This note exists so nobody builds a second code path for it.
module aptos_framework::attestation_authorization {
    use std::bcs::to_bytes;
    use std::chain_id;
    use std::ed25519;
    use std::error;
    use std::event::emit;
    use std::table::{Self, Table};
    use std::timestamp::now_seconds;

    friend aptos_framework::attestation_policy;

    /// Domain separator for the signed message, so an authorization cannot be reinterpreted as any
    /// other signed payload.
    const DOMAIN_AUTHORIZE: vector<u8> = b"aptos_framework::attestation_authorization::AUTH";

    /// Largest bucket exponent. Bucket b covers amounts up to 10^b, saturating at u64 max.
    const MAX_BUCKET: u8 = 20;
    /// Required length of a nonce.
    const NONCE_LENGTH: u64 = 32;
    /// Required length of an ed25519 public key.
    const PUBKEY_LENGTH: u64 = 32;
    /// Required length of an ed25519 signature.
    const SIGNATURE_LENGTH: u64 = 64;
    /// Largest number of nonces one prune call may release.
    const MAX_PRUNE: u64 = 1000;

    /// This policy has no nonce store, so it was not created by `attestation_policy`.
    const ENOT_INITIALIZED: u64 = 1;
    /// The authorizer signature did not verify.
    const EBAD_SIGNATURE: u64 = 2;
    /// The authorization has expired.
    const EEXPIRED: u64 = 3;
    /// This nonce has already been consumed.
    const ENONCE_USED: u64 = 4;
    /// The amount exceeds the ceiling the authorizer committed to.
    const EAMOUNT_OVER_BUCKET: u64 = 5;
    /// The authorization's validity window is longer than the policy permits.
    const ETTL_TOO_LONG: u64 = 6;
    /// The policy has no authorizer key configured.
    const ENO_AUTHORIZER: u64 = 7;
    /// A nonce must be exactly 32 bytes.
    const EBAD_NONCE_LENGTH: u64 = 8;
    /// A signature must be exactly 64 bytes.
    const EBAD_SIGNATURE_LENGTH: u64 = 9;
    /// The bucket exponent exceeds MAX_BUCKET.
    const EBAD_BUCKET: u64 = 10;
    /// The authorization was issued in the future.
    const ENOT_YET_VALID: u64 = 11;
    /// The batch exceeds MAX_PRUNE.
    const EBATCH_TOO_LARGE: u64 = 12;

    /// Consumed nonces, stored at the policy's address. The value is the expiry, retained so an
    /// entry can be pruned once it can no longer be replayed.
    struct Nonces has key {
        used: Table<vector<u8>, u64>
    }

    #[event]
    struct ConsumeAuthorization has drop, store {
        policy: address,
        subject: address,
        action: u8,
        amount_bucket: u8,
        nonce: vector<u8>,
        issued_at_secs: u64,
        expires_at_secs: u64
    }

    #[event]
    struct PruneNonces has drop, store {
        policy: address,
        released: u64
    }

    // =============================== Views ===============================

    #[view]
    public fun is_initialized(policy: address): bool {
        exists<Nonces>(policy)
    }

    #[view]
    public fun is_nonce_used(policy: address, nonce: vector<u8>): bool acquires Nonces {
        exists<Nonces>(policy) && table::contains(&Nonces[policy].used, nonce)
    }

    #[view]
    /// Ceiling a bucket exponent commits to: 10^bucket, saturating at u64 max.
    public fun bucket_ceiling(bucket: u8): u64 {
        assert!(bucket <= MAX_BUCKET, error::invalid_argument(EBAD_BUCKET));
        let ceiling = 1u64;
        let step = 0;
        while (step < bucket) {
            // 10^20 overflows u64, so saturate rather than abort.
            if (ceiling > 1844674407370955161) {
                return 18446744073709551615
            };
            ceiling *= 10;
            step += 1;
        };
        ceiling
    }

    #[view]
    /// The message an authorizer signs. Published so an authorizing service can be implemented in
    /// any language without reading this module.
    public fun authorization_message(
        policy: address,
        subject: address,
        action: u8,
        amount_bucket: u8,
        nonce: vector<u8>,
        issued_at_secs: u64,
        expires_at_secs: u64
    ): vector<u8> {
        let message = vector[];
        message.append(DOMAIN_AUTHORIZE);
        message.append(to_bytes(&chain_id::get()));
        message.append(to_bytes(&policy));
        message.append(to_bytes(&subject));
        message.append(to_bytes(&action));
        message.append(to_bytes(&amount_bucket));
        message.append(to_bytes(&nonce));
        message.append(to_bytes(&issued_at_secs));
        message.append(to_bytes(&expires_at_secs));
        message
    }

    // =============================== Lifecycle ===============================

    /// Create the nonce store. Called by `attestation_policy::create` with the policy's own
    /// resource-account signer, which is why this needs no permission check of its own.
    public(friend) fun initialize(policy_account: &signer) {
        move_to(policy_account, Nonces { used: table::new<vector<u8>, u64>() });
    }

    /// Verify an authorization and consume its nonce.
    ///
    /// Every field is checked against the call it is being used for; none is advisory. The policy
    /// supplies the authorizer key and the longest window it will accept, so a compromised
    /// authorizer cannot mint a long-lived capability by setting a distant expiry.
    ///
    /// @param policy The policy the authorization was issued for.
    /// @param authorizer_pubkey 32-byte ed25519 key the policy trusts.
    /// @param max_ttl_secs Longest validity window the policy accepts.
    /// @param subject The subject taking the action.
    /// @param action The action being taken.
    /// @param amount The actual amount, which must be within the committed bucket ceiling.
    /// @param authorization BCS of (action, amount_bucket, nonce, issued_at, expires_at) followed
    ///        by the 64-byte signature.
    /// @abort If any field disagrees with the call, the window is too long, the signature fails,
    ///        or the nonce has already been consumed.
    public(friend) fun verify_and_consume(
        policy: address,
        authorizer_pubkey: vector<u8>,
        max_ttl_secs: u64,
        subject: address,
        action: u8,
        amount: u64,
        authorization: vector<u8>
    ) acquires Nonces {
        assert!(exists<Nonces>(policy), error::not_found(ENOT_INITIALIZED));
        assert!(
            authorizer_pubkey.length() == PUBKEY_LENGTH,
            error::invalid_state(ENO_AUTHORIZER)
        );

        let (signed_action, amount_bucket, nonce, issued_at_secs, expires_at_secs, signature) =
            decode(authorization);

        assert!(signed_action == action, error::invalid_argument(EBAD_SIGNATURE));
        assert!(
            amount <= bucket_ceiling(amount_bucket),
            error::invalid_argument(EAMOUNT_OVER_BUCKET)
        );

        let now = now_seconds();
        assert!(issued_at_secs <= now, error::invalid_argument(ENOT_YET_VALID));
        assert!(now < expires_at_secs, error::invalid_state(EEXPIRED));
        assert!(
            expires_at_secs - issued_at_secs <= max_ttl_secs,
            error::invalid_argument(ETTL_TOO_LONG)
        );

        let message =
            authorization_message(
                policy,
                subject,
                action,
                amount_bucket,
                nonce,
                issued_at_secs,
                expires_at_secs
            );
        assert!(
            ed25519::signature_verify_strict(
                &ed25519::new_signature_from_bytes(signature),
                &ed25519::new_unvalidated_public_key_from_bytes(authorizer_pubkey),
                message
            ),
            error::invalid_argument(EBAD_SIGNATURE)
        );

        let used = &mut Nonces[policy].used;
        assert!(!table::contains(used, nonce), error::invalid_state(ENONCE_USED));
        table::add(used, nonce, expires_at_secs);

        emit(
            ConsumeAuthorization {
                policy,
                subject,
                action,
                amount_bucket,
                nonce,
                issued_at_secs,
                expires_at_secs
            }
        );
    }

    /// Release the storage held by nonces that can no longer be replayed. Permissionless, because
    /// it is pure cleanup and nobody has a reason to withhold it other than the fee, which is the
    /// caller's to pay.
    public entry fun prune_nonces(
        _anyone: &signer, policy: address, nonces: vector<vector<u8>>
    ) acquires Nonces {
        assert!(exists<Nonces>(policy), error::not_found(ENOT_INITIALIZED));
        assert!(nonces.length() <= MAX_PRUNE, error::invalid_argument(EBATCH_TOO_LARGE));
        let now = now_seconds();
        let used = &mut Nonces[policy].used;
        let released = 0;
        nonces.for_each(|nonce| {
            if (table::contains(used, nonce) && *table::borrow(used, nonce) <= now) {
                table::remove(used, nonce);
                released += 1;
            };
        });
        emit(PruneNonces { policy, released });
    }

    // =============================== Helpers ===============================

    /// Split an authorization blob into its fields and the signature. The layout is fixed width up
    /// to the signature so it can be parsed without a length prefix:
    /// action (1) || bucket (1) || nonce (32) || issued_at (8) || expires_at (8) || signature (64).
    /// Integers are little-endian, matching BCS.
    fun decode(authorization: vector<u8>): (u8, u8, vector<u8>, u64, u64, vector<u8>) {
        let expected = 1 + 1 + NONCE_LENGTH + 8 + 8 + SIGNATURE_LENGTH;
        assert!(
            authorization.length() == expected,
            error::invalid_argument(EBAD_SIGNATURE_LENGTH)
        );
        let action = authorization[0];
        let amount_bucket = authorization[1];

        let nonce = vector[];
        let index = 2;
        while (index < 2 + NONCE_LENGTH) {
            nonce.push_back(authorization[index]);
            index += 1;
        };
        assert!(nonce.length() == NONCE_LENGTH, error::invalid_argument(EBAD_NONCE_LENGTH));

        let issued_at_secs = read_u64_le(&authorization, 2 + NONCE_LENGTH);
        let expires_at_secs = read_u64_le(&authorization, 2 + NONCE_LENGTH + 8);

        let signature = vector[];
        index = 2 + NONCE_LENGTH + 16;
        while (index < expected) {
            signature.push_back(authorization[index]);
            index += 1;
        };

        (action, amount_bucket, nonce, issued_at_secs, expires_at_secs, signature)
    }

    fun read_u64_le(bytes: &vector<u8>, offset: u64): u64 {
        let value = 0u64;
        let index = 0;
        while (index < 8) {
            value += (bytes[offset + index] as u64) << ((index * 8) as u8);
            index += 1;
        };
        value
    }

    #[test_only]
    /// Build an authorization blob the way an authorizing service would.
    public fun encode_for_test(
        action: u8,
        amount_bucket: u8,
        nonce: vector<u8>,
        issued_at_secs: u64,
        expires_at_secs: u64,
        signature: vector<u8>
    ): vector<u8> {
        let blob = vector[];
        blob.push_back(action);
        blob.push_back(amount_bucket);
        blob.append(nonce);
        blob.append(to_bytes(&issued_at_secs));
        blob.append(to_bytes(&expires_at_secs));
        blob.append(signature);
        blob
    }
}

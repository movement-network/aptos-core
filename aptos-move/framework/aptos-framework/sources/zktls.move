/// Onchain verification of zkTLS attestations, at enrollment.
///
/// The chain verifies the attestation itself: it recomputes the claim digest with keccak256 and
/// recovers one signer per signature with `secp256k1::ecdsa_recover` against an epoch-registered
/// attestor set, rejecting duplicates and requiring a threshold. Both primitives are ungated
/// natives, so this module needs no Rust change, no new native and no feature flag. The shape is
/// borrowed from Reclaim's onchain verifier, which contains no zero-knowledge verification at all:
/// it is a digest recomputation plus N public-key recoveries plus a threshold and a duplicate
/// check.
///
/// This is ENROLLMENT and must never sit in a per-action path. A proxy or MPC-TLS session takes
/// seconds, needs the user to log into the provider inside the flow, and depends on a provider
/// template that breaks when the provider changes its markup. Verify once at the boundary, write a
/// fact through `aptos_framework::attestation`, then read the fact from then on. The failure mode
/// of a broken template is then that new enrollment degrades, not that existing subjects break.
///
/// Known offchain dependency, stated plainly because it cannot be fixed here: `template_id` is the
/// hash of a provider config (the request URL, the response regex, the redaction rules) that lives
/// in the provider's own registry. An attestor cannot run a session without resolving that hash to
/// the config, so if the provider delists it the onchain template becomes a dead pointer that
/// governance cannot repair.
module aptos_framework::zktls {
    use std::aptos_hash::keccak256;
    use std::error;
    use std::event::emit;
    use std::option;
    use std::secp256k1;
    use std::signer::address_of;
    use std::table::{Self, Table};
    use std::timestamp::now_seconds;
    use aptos_framework::attestation;

    /// The caller is not an admin of the source.
    const ENOT_ADMIN: u64 = 1;
    /// No template is registered under the given id.
    const EUNKNOWN_TEMPLATE: u64 = 2;
    /// The template has been revoked.
    const ETEMPLATE_REVOKED: u64 = 3;
    /// Fewer distinct attestors signed than the threshold requires.
    const EBELOW_THRESHOLD: u64 = 4;
    /// The same attestor signed twice.
    const EDUPLICATE_SIGNER: u64 = 5;
    /// A recovered signer is not in the registered attestor set.
    const EUNKNOWN_ATTESTOR: u64 = 6;
    /// No attestor set is registered for the requested epoch.
    const EUNKNOWN_ATTESTOR_EPOCH: u64 = 7;
    /// The claim does not bind this subject and this template.
    const EMALFORMED_CLAIM: u64 = 8;
    /// A signature could not be recovered.
    const EBAD_SIGNATURE: u64 = 9;
    /// The threshold must be at least 1 and at most the attestor count.
    const EBAD_THRESHOLD: u64 = 10;
    /// The attestor list cannot contain duplicates.
    const EDUPLICATE_ATTESTOR: u64 = 11;
    /// This source has no verifier configured.
    const ENOT_INITIALIZED: u64 = 12;
    /// An attestor address must be exactly 20 bytes.
    const EBAD_ATTESTOR_LENGTH: u64 = 13;
    /// A signature must be exactly 65 bytes: r, s, then the recovery id.
    const EBAD_SIGNATURE_LENGTH: u64 = 14;
    /// The attestor epoch has been rotated away and its grace window has ended.
    const ERETIRED_ATTESTOR_EPOCH: u64 = 15;
    /// This claim has already been used to enroll.
    const ECLAIM_CONSUMED: u64 = 16;

    /// Largest number of signatures one claim may carry.
    const MAX_SIGNATURES: u64 = 16;
    const MAX_U64: u64 = 18446744073709551615;
    /// Ethereum-style attestor address length.
    const ATTESTOR_LENGTH: u64 = 20;
    /// r (32) plus s (32) plus the recovery id (1).
    const SIGNATURE_LENGTH: u64 = 65;

    /// The prefix Ethereum wallets and attestor networks apply before signing.
    const ETH_PREFIX: vector<u8> = b"\x19Ethereum Signed Message:\n";

    /// A set of attestors and how many of them must sign.
    struct AttestorSet has copy, drop, store {
        // 20-byte Ethereum-style addresses, because that is the identity form existing attestor
        // networks already publish.
        attestors: vector<vector<u8>>,
        threshold: u64
    }

    /// What a successful claim under one provider template entitles the subject to.
    struct Template has copy, drop, store {
        // Hash of the provider config. See the module doc for what this depends on.
        template_id: vector<u8>,
        grants_level: u8,
        ttl_secs: u64,
        active: bool
    }

    /// Stored under the source's resource account address.
    struct Verifier has key {
        // epoch to set. Past epochs are retained for audit. Only the current epoch verifies, plus
        // the immediately previous one until `previous_deadline_secs`, so a claim signed moments
        // before a rotation still verifies while a rotated-away compromised set stops verifying.
        sets: Table<u64, AttestorSet>,
        current_epoch: u64,
        // Claims under epoch current_epoch - 1 verify while now_seconds() is below this.
        previous_deadline_secs: u64,
        templates: Table<vector<u8>, Template>,
        // keccak256 of every claim already used to enroll, so a signed claim is single use and
        // cannot refresh an expiry forever or undo an issuer's revocation.
        consumed: Table<vector<u8>, bool>
    }

    #[event]
    struct SetAttestorSet has drop, store {
        source: address,
        epoch: u64,
        threshold: u64,
        count: u64
    }

    #[event]
    struct RegisterTemplate has drop, store {
        source: address,
        template_id: vector<u8>,
        grants_level: u8
    }

    #[event]
    struct RevokeTemplate has drop, store {
        source: address,
        template_id: vector<u8>
    }

    #[event]
    struct Enroll has drop, store {
        source: address,
        subject: address,
        template_id: vector<u8>,
        signers: u64
    }

    // =============================== Views ===============================

    #[view]
    public fun is_initialized(source: address): bool {
        exists<Verifier>(source)
    }

    #[view]
    public fun current_epoch(source: address): u64 acquires Verifier {
        assert_initialized(source);
        Verifier[source].current_epoch
    }

    #[view]
    /// Attestor addresses registered for an epoch.
    public fun attestors(source: address, epoch: u64): vector<vector<u8>> acquires Verifier {
        assert_initialized(source);
        let verifier = &Verifier[source];
        assert!(
            table::contains(&verifier.sets, epoch),
            error::not_found(EUNKNOWN_ATTESTOR_EPOCH)
        );
        table::borrow(&verifier.sets, epoch).attestors
    }

    #[view]
    public fun threshold(source: address, epoch: u64): u64 acquires Verifier {
        assert_initialized(source);
        let verifier = &Verifier[source];
        assert!(
            table::contains(&verifier.sets, epoch),
            error::not_found(EUNKNOWN_ATTESTOR_EPOCH)
        );
        table::borrow(&verifier.sets, epoch).threshold
    }

    #[view]
    /// Whether claims signed by the given epoch's attestor set are accepted right now.
    public fun is_epoch_accepted(source: address, epoch: u64): bool acquires Verifier {
        if (!exists<Verifier>(source)) {
            return false
        };
        epoch_accepted(&Verifier[source], epoch)
    }

    #[view]
    /// Whether a claim has already been used to enroll in this source.
    public fun is_claim_consumed(source: address, claim: vector<u8>): bool acquires Verifier {
        exists<Verifier>(source)
            && table::contains(&Verifier[source].consumed, keccak256(claim))
    }

    #[view]
    public fun is_template_active(source: address, template_id: vector<u8>): bool acquires Verifier {
        if (!exists<Verifier>(source)) {
            return false
        };
        let templates = &Verifier[source].templates;
        table::contains(templates, template_id)
            && table::borrow(templates, template_id).active
    }

    #[view]
    /// The digest an attestor signs: keccak256 over the Ethereum-prefixed claim. Published so an
    /// attestor implementation can be checked against this module without reading it.
    public fun claim_digest(claim: vector<u8>): vector<u8> {
        let prefixed = vector[];
        prefixed.append(ETH_PREFIX);
        prefixed.append(decimal_bytes(claim.length()));
        prefixed.append(claim);
        keccak256(prefixed)
    }

    #[view]
    /// Recover the 20-byte attestor address that produced a signature over a claim.
    public fun recover_attestor(claim: vector<u8>, signature: vector<u8>): vector<u8> {
        assert!(
            signature.length() == SIGNATURE_LENGTH,
            error::invalid_argument(EBAD_SIGNATURE_LENGTH)
        );
        let digest = claim_digest(claim);
        // Ethereum wallets and attestor networks emit v as 27 or 28; the native takes 0 to 3.
        let v = signature[SIGNATURE_LENGTH - 1];
        let recovery_id = if (v >= 27) { v - 27 } else { v };
        assert!(recovery_id < 4, error::invalid_argument(EBAD_SIGNATURE));
        let rs = vector[];
        let index = 0;
        while (index < SIGNATURE_LENGTH - 1) {
            rs.push_back(signature[index]);
            index += 1;
        };
        let recovered =
            secp256k1::ecdsa_recover(
                digest, recovery_id, &secp256k1::ecdsa_signature_from_bytes(rs)
            );
        assert!(option::is_some(&recovered), error::invalid_argument(EBAD_SIGNATURE));
        let pubkey = secp256k1::ecdsa_raw_public_key_to_bytes(option::borrow(&recovered));
        // Ethereum address: the low 20 bytes of keccak256 over the 64-byte public key.
        let hashed = keccak256(pubkey);
        let address_bytes = vector[];
        let position = 12;
        while (position < 32) {
            address_bytes.push_back(hashed[position]);
            position += 1;
        };
        address_bytes
    }

    #[view]
    /// Whether `enroll` would accept this claim right now, without writing anything: the
    /// signatures meet the threshold, the template is active and the claim is unused. Aborts on
    /// the same malformed inputs `enroll` aborts on.
    public fun verify_claim(
        source: address,
        template_id: vector<u8>,
        subject: address,
        claim: vector<u8>,
        signatures: vector<vector<u8>>,
        attestor_epoch: u64
    ): bool acquires Verifier {
        let (met, active, consumed, _) =
            verify_claim_internal(
                source, template_id, subject, claim, signatures, attestor_epoch
            );
        met && active && !consumed
    }

    // =============================== Configuration ===============================

    /// Create the verifier for a source. Requires an admin of that source, and obtains the
    /// source's resource-account signer through `attestation`'s friend accessor.
    public entry fun initialize(admin: &signer, source: address) {
        assert!(
            attestation::is_admin(address_of(admin), source),
            error::permission_denied(ENOT_ADMIN)
        );
        let source_signer = attestation::source_signer(source);
        move_to(
            &source_signer,
            Verifier {
                sets: table::new<u64, AttestorSet>(),
                current_epoch: 0,
                previous_deadline_secs: 0,
                templates: table::new<vector<u8>, Template>(),
                consumed: table::new<vector<u8>, bool>()
            }
        );
    }

    /// Register a new attestor set under the next epoch. The set it replaces keeps verifying for
    /// `previous_grace_secs`, so a claim signed moments before the rotation still verifies; every
    /// older set stops verifying immediately. Rotating away a compromised set with a zero grace
    /// window cuts it off at once.
    ///
    /// @param admin An admin of the source.
    /// @param source The source address.
    /// @param attestor_addresses 20-byte Ethereum-style addresses, no duplicates.
    /// @param required How many distinct attestors must sign. At least 1, at most the count.
    /// @param previous_grace_secs How long the replaced set keeps verifying. 0 for no grace.
    public entry fun set_attestor_set(
        admin: &signer,
        source: address,
        attestor_addresses: vector<vector<u8>>,
        required: u64,
        previous_grace_secs: u64
    ) acquires Verifier {
        assert!(
            attestation::is_admin(address_of(admin), source),
            error::permission_denied(ENOT_ADMIN)
        );
        assert_initialized(source);
        let count = attestor_addresses.length();
        assert!(
            required >= 1 && required <= count,
            error::invalid_argument(EBAD_THRESHOLD)
        );
        let seen: vector<vector<u8>> = vector[];
        attestor_addresses.for_each_ref(|attestor| {
            assert!(
                attestor.length() == ATTESTOR_LENGTH,
                error::invalid_argument(EBAD_ATTESTOR_LENGTH)
            );
            assert!(
                !seen.contains(attestor),
                error::invalid_argument(EDUPLICATE_ATTESTOR)
            );
            seen.push_back(*attestor);
        });

        let now = now_seconds();
        let verifier = &mut Verifier[source];
        let epoch = verifier.current_epoch + 1;
        verifier.current_epoch = epoch;
        verifier.previous_deadline_secs =
            if (previous_grace_secs > MAX_U64 - now) { MAX_U64 }
            else { now + previous_grace_secs };
        table::add(
            &mut verifier.sets,
            epoch,
            AttestorSet { attestors: attestor_addresses, threshold: required }
        );
        emit(SetAttestorSet { source, epoch, threshold: required, count });
    }

    /// Allow a provider template and say what a claim under it grants.
    public entry fun register_template(
        admin: &signer,
        source: address,
        template_id: vector<u8>,
        grants_level: u8,
        ttl_secs: u64
    ) acquires Verifier {
        assert!(
            attestation::is_admin(address_of(admin), source),
            error::permission_denied(ENOT_ADMIN)
        );
        assert_initialized(source);
        table::upsert(
            &mut Verifier[source].templates,
            template_id,
            Template { template_id, grants_level, ttl_secs, active: true }
        );
        emit(RegisterTemplate { source, template_id, grants_level });
    }

    /// Stop accepting new claims under a template. Facts already recorded are untouched; use
    /// `attestation::bump_issuer_epoch` with issuer id 0, which invalidates every zkTLS
    /// enrollment in the source, or a denial per subject for those.
    public entry fun revoke_template(
        admin: &signer, source: address, template_id: vector<u8>
    ) acquires Verifier {
        assert!(
            attestation::is_admin(address_of(admin), source),
            error::permission_denied(ENOT_ADMIN)
        );
        assert_initialized(source);
        let templates = &mut Verifier[source].templates;
        assert!(
            table::contains(templates, template_id),
            error::not_found(EUNKNOWN_TEMPLATE)
        );
        table::borrow_mut(templates, template_id).active = false;
        emit(RevokeTemplate { source, template_id });
    }

    // =============================== Enrollment ===============================

    /// Submit a verified claim about yourself. No issuer key is involved on this path: the trust
    /// root is the attestor set plus the provider's TLS certificate, not an operator holding a key.
    ///
    /// @param user The subject. Must be the address the claim names.
    /// @param source The source to record the fact in.
    /// @param template_id Registered, active template the claim was produced under.
    /// @param claim Canonically serialized claim. Must contain the subject and the template id.
    /// @param signatures One 65-byte recoverable ECDSA signature per attestor.
    /// @param attestor_epoch Epoch whose attestor set signed.
    /// @param nullifier 32 bytes binding one identity to one subject, or empty to skip. When set,
    ///        its lowercase hex must appear in the signed claim, so the attestors vouch for it.
    /// @abort If the claim does not bind the subject (or the nullifier), a signer is unknown or
    ///        repeated, the attestor epoch is retired, the template is revoked, the claim was
    ///        already used, or fewer than the threshold signed.
    public entry fun enroll(
        user: &signer,
        source: address,
        template_id: vector<u8>,
        claim: vector<u8>,
        signatures: vector<vector<u8>>,
        attestor_epoch: u64,
        nullifier: vector<u8>
    ) acquires Verifier {
        let subject = address_of(user);
        let (met, active, consumed, signers) =
            verify_claim_internal(
                source, template_id, subject, claim, signatures, attestor_epoch
            );
        assert!(active, error::invalid_state(ETEMPLATE_REVOKED));
        assert!(!consumed, error::invalid_state(ECLAIM_CONSUMED));
        assert!(met, error::invalid_argument(EBELOW_THRESHOLD));
        // A nullifier the attestors did not sign is just a user-chosen value and gives no sybil
        // resistance, so it must be carried by the claim itself.
        assert!(
            nullifier.is_empty() || contains_bytes(&claim, &lowercase_hex(nullifier)),
            error::invalid_argument(EMALFORMED_CLAIM)
        );

        let verifier = &mut Verifier[source];
        table::add(&mut verifier.consumed, keccak256(claim), true);
        let template = *table::borrow(&verifier.templates, template_id);

        attestation::record_verified_claim(
            source,
            subject,
            template.grants_level,
            now_seconds() + template.ttl_secs,
            keccak256(claim),
            nullifier
        );

        emit(Enroll { source, subject, template_id, signers });
    }

    /// Structural checks abort. Returns whether the threshold is met, whether the template is
    /// active, whether the claim was already consumed, and how many distinct attestors signed.
    fun verify_claim_internal(
        source: address,
        template_id: vector<u8>,
        subject: address,
        claim: vector<u8>,
        signatures: vector<vector<u8>>,
        attestor_epoch: u64
    ): (bool, bool, bool, u64) acquires Verifier {
        assert_initialized(source);
        assert!(
            signatures.length() <= MAX_SIGNATURES,
            error::invalid_argument(EBELOW_THRESHOLD)
        );

        let verifier = &Verifier[source];
        assert!(
            table::contains(&verifier.templates, template_id),
            error::not_found(EUNKNOWN_TEMPLATE)
        );
        assert!(
            table::contains(&verifier.sets, attestor_epoch),
            error::not_found(EUNKNOWN_ATTESTOR_EPOCH)
        );
        assert!(
            epoch_accepted(verifier, attestor_epoch),
            error::invalid_state(ERETIRED_ATTESTOR_EPOCH)
        );
        let set = table::borrow(&verifier.sets, attestor_epoch);

        // The single most important check in this module, and the first thing an attacker will
        // look for. Without it a valid attestation for one person is a valid attestation for
        // whoever relays it, and one self-hosted endpoint mints unlimited verified addresses.
        assert!(
            claim_binds(&claim, subject, &template_id),
            error::invalid_argument(EMALFORMED_CLAIM)
        );

        let seen: vector<vector<u8>> = vector[];
        signatures.for_each_ref(|signature| {
            let recovered = recover_attestor(claim, *signature);
            assert!(
                set.attestors.contains(&recovered),
                error::invalid_argument(EUNKNOWN_ATTESTOR)
            );
            assert!(
                !seen.contains(&recovered),
                error::invalid_argument(EDUPLICATE_SIGNER)
            );
            seen.push_back(recovered);
        });

        (
            seen.length() >= set.threshold,
            table::borrow(&verifier.templates, template_id).active,
            table::contains(&verifier.consumed, keccak256(claim)),
            seen.length()
        )
    }

    fun epoch_accepted(verifier: &Verifier, epoch: u64): bool {
        epoch != 0
            && (
                epoch == verifier.current_epoch
                    || (
                        // Written as a subtraction so an epoch of u64::MAX cannot overflow.
                        epoch < verifier.current_epoch
                            && verifier.current_epoch - epoch == 1
                            && now_seconds() < verifier.previous_deadline_secs
                    )
            )
    }

    // =============================== Helpers ===============================

    /// Whether the claim names this subject and this template. The canonical serialization is the
    /// provider's, so this checks containment of both binding values rather than parsing: a claim
    /// that does not carry them is rejected outright.
    ///
    /// Reclaim compatibility means reproducing its ASCII claim serialization exactly, down to the
    /// lowercase hex identifier, the decimal formatting of its integer fields and the newline
    /// joins. One wrong byte fails every proof, so this must be covered by pinned conformance
    /// vectors from a real attestor rather than by a test written from the documentation.
    fun claim_binds(
        claim: &vector<u8>, subject: address, template_id: &vector<u8>
    ): bool {
        contains_bytes(claim, &lowercase_hex(std::bcs::to_bytes(&subject)))
            && contains_bytes(claim, &lowercase_hex(*template_id))
    }

    /// Whether `needle` appears in `haystack`.
    fun contains_bytes(haystack: &vector<u8>, needle: &vector<u8>): bool {
        let needle_length = needle.length();
        let haystack_length = haystack.length();
        if (needle_length == 0 || needle_length > haystack_length) {
            return needle_length == 0
        };
        let start = 0;
        while (start + needle_length <= haystack_length) {
            let offset = 0;
            let matched = true;
            while (offset < needle_length && matched) {
                if (haystack[start + offset] != needle[offset]) {
                    matched = false;
                };
                offset += 1;
            };
            if (matched) {
                return true
            };
            start += 1;
        };
        false
    }

    /// Lowercase hex encoding, matching the form attestor networks put in a claim.
    fun lowercase_hex(bytes: vector<u8>): vector<u8> {
        let digits = b"0123456789abcdef";
        let out = vector[];
        bytes.for_each(|byte| {
            out.push_back(digits[((byte >> 4) as u64)]);
            out.push_back(digits[((byte & 0x0f) as u64)]);
        });
        out
    }

    /// Decimal ASCII encoding of a length, for the Ethereum signing prefix.
    fun decimal_bytes(value: u64): vector<u8> {
        if (value == 0) {
            return b"0"
        };
        let digits = vector[];
        let remaining = value;
        while (remaining > 0) {
            digits.push_back(((remaining % 10) as u8) + 48);
            remaining /= 10;
        };
        digits.reverse();
        digits
    }

    fun assert_initialized(source: address) {
        assert!(exists<Verifier>(source), error::not_found(ENOT_INITIALIZED));
    }

    // =============================== Tests ===============================

    #[test_only]
    use std::account::create_account_for_test;
    #[test_only]
    use std::timestamp;

    #[test_only]
    const TEMPLATE: vector<u8> = x"7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e";
    #[test_only]
    const OTHER_TEMPLATE: vector<u8> = x"5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a";
    #[test_only]
    const CLAIM_A: vector<u8> = x"7b2270726f7669646572223a2268747470222c2274656d706c617465223a2237653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765222c226f776e6572223a2230303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030613131222c227473223a2231373030303030303030227d";
    #[test_only]
    const CLAIM_B: vector<u8> = x"7b2270726f7669646572223a2268747470222c2274656d706c617465223a2237653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765222c226f776e6572223a2230303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030623232222c227473223a2231373030303030303030227d";
    #[test_only]
    const CLAIM_A_OTHER_TEMPLATE: vector<u8> = x"7b2270726f7669646572223a2268747470222c2274656d706c617465223a2235613561356135613561356135613561356135613561356135613561356135613561356135613561356135613561356135613561356135613561356135613561222c226f776e6572223a2230303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030613131222c227473223a2231373030303030303030227d";
    #[test_only]
    const CLAIM_A_DIGEST: vector<u8> = x"912fdd57cc04db75f129bd56dc54658123218868366f80f6644ee0b292d027f5";
    #[test_only]
    const ATTESTOR_1: vector<u8> = x"19e7e376e7c213b7e7e7e46cc70a5dd086daff2a";
    #[test_only]
    const ATTESTOR_2: vector<u8> = x"1563915e194d8cfba1943570603f7606a3115508";
    #[test_only]
    const ATTESTOR_3: vector<u8> = x"5cbdd86a2fa8dc4bddd8a8f69dba48572eec07fb";
    #[test_only]
    const ATTESTOR_4: vector<u8> = x"7564105e977516c53be337314c7e53838967bdac";
    #[test_only]
    const SIG_A_1: vector<u8> = x"4703083a440db78273fd4ce9154b0157f8ab7c15bb65eed7fbfbef5c2ec1449163d44433555af2f7ec21b64014621a54d0c4a078aac75f38c1b4f78d888ca79b00";
    #[test_only]
    const SIG_A_2: vector<u8> = x"b54401bceb2e7d8061864924292ca5403aa7236f6ceeb55ec271453d6528e6f03343476fe93a74d4c576b7129e496d882fc5487b5c25c7668550284d6afe181300";
    #[test_only]
    const SIG_A_3: vector<u8> = x"08697601f0f6a657e28154b8eae435136ed64b1064d9b4264982c2a1b0853f923288b570e09ef8d88a9af7e7fa177986c3d9710444ee0d57062a70bde2f47eb801";
    #[test_only]
    const SIG_A_4: vector<u8> = x"b85981aae115e62404096ecb494fa0cbc5728ea6485fa98298bef589ba42368a35aed04c34c235dfa1f64f40f90a4ed633140670e196760b041829a5b8cd4e2101";
    #[test_only]
    const SIG_B_1: vector<u8> = x"8fbfd696cef9aeaa25d06afc3474ae75e1986ab9133a5bc274449256172338a16a9d7d7eb86f92a76fa50a73a2818682f7a34bafa9a13df66b3c1258b34470ee00";
    #[test_only]
    const SIG_B_2: vector<u8> = x"5ffc582e9709da7f454ee57f297b030ecfcd76421886edb1ad2256741c1f5b5f7b36d4575535c93602efb46161646d61641b1d8a1a8e2f1b059a5ee822dfcaf401";
    #[test_only]
    const SIG_OTHER_TEMPLATE_1: vector<u8> = x"baea13629ea7d53646cc7b1d8d14cb82e283e533f902505f1b9579df195cfbb018b3732b13f10acf5195efc9dfe6836ccd99c3a4ed019cb7239cc0f39036734c01";
    #[test_only]
    const SIG_OTHER_TEMPLATE_2: vector<u8> = x"60ecbc93b3b8b7afa359b7aabf2a2f2fb1fa137ca32633598e0152877011108c5dfb7455b7f1d1000d032a647b6a5c2034400b04cb50c6b0fe8d245f8a3149d300";

    #[test_only]
    const CLAIM_A_REFRESH: vector<u8> = x"7b2270726f7669646572223a2268747470222c2274656d706c617465223a2237653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765222c226f776e6572223a2230303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030613131222c227473223a2231373030303030313030227d";
    #[test_only]
    const CLAIM_A_NULLIFIED: vector<u8> = x"7b2270726f7669646572223a2268747470222c2274656d706c617465223a2237653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765222c226f776e6572223a2230303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030613131222c227473223a2231373030303030303030222c226e756c6c6966696572223a2231313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131227d";
    #[test_only]
    const CLAIM_B_NULLIFIED: vector<u8> = x"7b2270726f7669646572223a2268747470222c2274656d706c617465223a2237653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765376537653765222c226f776e6572223a2230303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030623232222c227473223a2231373030303030303030222c226e756c6c6966696572223a2231313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131227d";
    #[test_only]
    const SIG_A_REFRESH_1: vector<u8> = x"cca6bd1ac3eda43ec5c92dff15268b1a35558a0f99ba7ae8a721fbc452a92e99678c820835737a589bcf65e9f3f98b4b9147f90e7737d3578421cdbcdc54130500";
    #[test_only]
    const SIG_A_REFRESH_2: vector<u8> = x"64ba8b859e88de7d139e5de8a92327dbe0776e7272094cde5268b846b4f9266e47559d61595080f5744c9ef565417f92aeefe08381b39bc5adf10d01ea22182c01";
    #[test_only]
    const SIG_A_NULLIFIED_1: vector<u8> = x"8f89ebbae7c4afcf47a8eac4fea1065f27d78228e3218ffa62d12f08ac0a84b04759ef4ffa2aa2a842ae6ae110832573efb21bb259e290e9983a6242679fb17000";
    #[test_only]
    const SIG_A_NULLIFIED_2: vector<u8> = x"5e4da7e6a806dc873b71a5b7ffb252e491f11a0c747c422f31876220e80090c92965ba95a0ccb1f73dd984a1e0f63bab2b0e4ab972ec608bafdb5c53bdb408bd01";
    #[test_only]
    const SIG_B_NULLIFIED_1: vector<u8> = x"01a673a511e1c50cfe3c73c47567b01e21bb0cd0c74f67db6111e4d4af5152b77dd5ca1ee0f2da3438afe5e069fe8bb38e3fc19fb821dc4bbef776e4743f30b000";
    #[test_only]
    const SIG_B_NULLIFIED_2: vector<u8> = x"7049978c93c1960169e5e6770885938655866afe81f7fe929e33df17579096670844f26f9c9dfc7be422829d120c66594f8bb6d914d18e29c033e3e2c6de169d01";

    #[test_only]
    const SUBJECT_A: address = @0xa11;
    #[test_only]
    const SUBJECT_B: address = @0xb22;
    #[test_only]
    const LEVEL_ZKTLS: u8 = 3;
    #[test_only]
    const TTL: u64 = 86400;
    #[test_only]
    const NULLIFIER: vector<u8> = x"1111111111111111111111111111111111111111111111111111111111111111";

    #[test_only]
    fun setup(framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        std::chain_id::initialize_for_test(framework, 4);
    }

    // A source whose deployer holds every role, with a verifier, a 2-of-3 attestor set at epoch 1
    // and TEMPLATE registered.
    #[test_only]
    fun new_verifier(deployer: &signer): address acquires Verifier {
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        let source = attestation::get_next_source_address(deployer_address);
        attestation::create(
            deployer,
            vector[deployer_address],
            vector[],
            vector[deployer_address],
            vector[deployer_address],
            vector[deployer_address]
        );
        initialize(deployer, source);
        set_attestor_set(deployer, source, vector[ATTESTOR_1, ATTESTOR_2, ATTESTOR_3], 2, 0);
        register_template(deployer, source, TEMPLATE, LEVEL_ZKTLS, TTL);
        source
    }

    // --- Configuration ---

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_initialize(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        let source = attestation::get_next_source_address(deployer_address);
        attestation::create(deployer, vector[deployer_address], vector[], vector[], vector[], vector[]);
        assert!(!is_initialized(source), 0);
        assert!(!is_template_active(source, TEMPLATE), 1);

        initialize(deployer, source);
        assert!(is_initialized(source), 2);
        assert!(current_epoch(source) == 0, 3);
        assert!(!is_template_active(source, TEMPLATE), 4);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    fun test_initialize_by_non_admin_fails(
        framework: &signer, deployer: &signer, other: &signer
    ) {
        setup(framework);
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        let source = attestation::get_next_source_address(deployer_address);
        attestation::create(deployer, vector[deployer_address], vector[], vector[], vector[], vector[]);
        initialize(other, source);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(major_status = 4004, location = Self)]
    fun test_initialize_twice_fails(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        initialize(deployer, source);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_attestor_set_rotation_keeps_old_epochs(
        framework: &signer, deployer: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        assert!(current_epoch(source) == 1, 0);
        assert!(attestors(source, 1) == vector[ATTESTOR_1, ATTESTOR_2, ATTESTOR_3], 1);
        assert!(threshold(source, 1) == 2, 2);

        set_attestor_set(deployer, source, vector[ATTESTOR_4], 1, 0);
        assert!(current_epoch(source) == 2, 3);
        assert!(attestors(source, 2) == vector[ATTESTOR_4], 4);
        assert!(threshold(source, 2) == 1, 5);
        // The previous set is retained unchanged.
        assert!(attestors(source, 1) == vector[ATTESTOR_1, ATTESTOR_2, ATTESTOR_3], 6);
        assert!(threshold(source, 1) == 2, 7);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x1000a, location = Self)]
    fun test_zero_threshold_fails(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(deployer, source, vector[ATTESTOR_1], 0, 0);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x1000a, location = Self)]
    fun test_threshold_above_count_fails(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(deployer, source, vector[ATTESTOR_1, ATTESTOR_2], 3, 0);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x1000b, location = Self)]
    fun test_duplicate_attestor_fails(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(deployer, source, vector[ATTESTOR_1, ATTESTOR_1], 1, 0);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x1000d, location = Self)]
    fun test_bad_attestor_length_fails(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(deployer, source, vector[x"0102"], 1, 0);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    fun test_set_attestor_set_by_non_admin_fails(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(other, source, vector[ATTESTOR_4], 1, 0);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x6000c, location = Self)]
    fun test_set_attestor_set_uninitialized_fails(
        framework: &signer, deployer: &signer
    ) acquires Verifier {
        setup(framework);
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        let source = attestation::get_next_source_address(deployer_address);
        attestation::create(deployer, vector[deployer_address], vector[], vector[], vector[], vector[]);
        set_attestor_set(deployer, source, vector[ATTESTOR_1], 1, 0);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x60007, location = Self)]
    fun test_unknown_epoch_view_fails(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        attestors(source, 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_template_lifecycle(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        assert!(is_template_active(source, TEMPLATE), 0);
        assert!(!is_template_active(source, OTHER_TEMPLATE), 1);

        revoke_template(deployer, source, TEMPLATE);
        assert!(!is_template_active(source, TEMPLATE), 2);

        // Registering again reactivates, with the new terms.
        register_template(deployer, source, TEMPLATE, LEVEL_ZKTLS + 1, TTL);
        assert!(is_template_active(source, TEMPLATE), 3);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x60002, location = Self)]
    fun test_revoke_unknown_template_fails(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        revoke_template(deployer, source, OTHER_TEMPLATE);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    fun test_register_template_by_non_admin_fails(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        register_template(other, source, OTHER_TEMPLATE, LEVEL_ZKTLS, TTL);
    }

    #[test(framework = @0x1, deployer = @0x123, other = @0x456)]
    #[expected_failure(abort_code = 0x50001, location = Self)]
    fun test_revoke_template_by_non_admin_fails(
        framework: &signer, deployer: &signer, other: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        revoke_template(other, source, TEMPLATE);
    }

    // --- Digest and recovery, pinned against vectors computed off chain ---

    #[test]
    fun test_claim_digest_matches_ethereum_personal_sign() {
        assert!(claim_digest(CLAIM_A) == CLAIM_A_DIGEST, 0);
    }

    #[test]
    fun test_recover_attestor() {
        assert!(recover_attestor(CLAIM_A, SIG_A_1) == ATTESTOR_1, 0);
        assert!(recover_attestor(CLAIM_A, SIG_A_2) == ATTESTOR_2, 1);
        assert!(recover_attestor(CLAIM_A, SIG_A_3) == ATTESTOR_3, 2);
        // A signature over a different claim recovers some other key.
        assert!(recover_attestor(CLAIM_A, SIG_B_1) != ATTESTOR_1, 3);
    }

    #[test]
    fun test_recover_attestor_accepts_ethereum_v() {
        // Same signatures with v encoded as 27 + recovery id, as Ethereum tooling emits them.
        let sig_1 = SIG_A_1;
        *sig_1.borrow_mut(SIGNATURE_LENGTH - 1) = 27;
        assert!(recover_attestor(CLAIM_A, sig_1) == ATTESTOR_1, 0);
        let sig_3 = SIG_A_3;
        *sig_3.borrow_mut(SIGNATURE_LENGTH - 1) = 28;
        assert!(recover_attestor(CLAIM_A, sig_3) == ATTESTOR_3, 1);
    }

    #[test]
    #[expected_failure(abort_code = 0x10009, location = Self)]
    fun test_out_of_range_recovery_id_fails() {
        let signature = SIG_A_1;
        *signature.borrow_mut(SIGNATURE_LENGTH - 1) = 5;
        recover_attestor(CLAIM_A, signature);
    }

    #[test]
    #[expected_failure(abort_code = 0x1000e, location = Self)]
    fun test_bad_signature_length_fails() {
        recover_attestor(CLAIM_A, x"00");
    }

    #[test]
    #[expected_failure(abort_code = 0x10009, location = Self)]
    fun test_unrecoverable_signature_fails() {
        let signature = vector[];
        let index = 0;
        while (index < SIGNATURE_LENGTH) {
            signature.push_back(0);
            index += 1;
        };
        recover_attestor(CLAIM_A, signature);
    }

    #[test]
    fun test_helpers() {
        assert!(decimal_bytes(0) == b"0", 0);
        assert!(decimal_bytes(7) == b"7", 1);
        assert!(decimal_bytes(190) == b"190", 2);
        assert!(decimal_bytes(18446744073709551615) == b"18446744073709551615", 3);
        assert!(lowercase_hex(x"00ab7f") == b"00ab7f", 4);
        assert!(contains_bytes(&b"abcdef", &b"cde"), 5);
        assert!(contains_bytes(&b"abcdef", &b"abcdef"), 6);
        assert!(contains_bytes(&b"abc", &b""), 7);
        assert!(!contains_bytes(&b"abc", &b"abcd"), 8);
        assert!(!contains_bytes(&b"abcdef", &b"ce"), 9);
        assert!(claim_binds(&CLAIM_A, SUBJECT_A, &TEMPLATE), 10);
        assert!(!claim_binds(&CLAIM_A, SUBJECT_B, &TEMPLATE), 11);
        assert!(!claim_binds(&CLAIM_A, SUBJECT_A, &OTHER_TEMPLATE), 12);
    }

    // --- Enrollment ---

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    fun test_enroll_two_of_three(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        assert!(verify_claim(source, TEMPLATE, SUBJECT_A, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1), 0);
        assert!(!attestation::is_verified(source, SUBJECT_A), 1);

        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_3, SIG_A_1], 1, vector[]);
        assert!(attestation::is_verified(source, SUBJECT_A), 2);
        assert!(attestation::level_of(source, SUBJECT_A) == LEVEL_ZKTLS, 3);
        assert!(attestation::expires_at(source, SUBJECT_A) == now_seconds() + TTL, 4);

        // The fact lapses on its own at the template's TTL.
        timestamp::fast_forward_seconds(TTL);
        assert!(!attestation::is_verified(source, SUBJECT_A), 5);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    fun test_enroll_with_every_attestor(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2, SIG_A_3], 1, vector[]);
        assert!(attestation::is_verified(source, SUBJECT_A), 0);

        // A fresh claim later refreshes the expiry.
        timestamp::fast_forward_seconds(100);
        enroll(
            user, source, TEMPLATE, CLAIM_A_REFRESH, vector[SIG_A_REFRESH_1, SIG_A_REFRESH_2], 1, vector[]
        );
        assert!(attestation::expires_at(source, SUBJECT_A) == now_seconds() + TTL, 1);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x30010, location = Self)]
    fun test_replayed_claim_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        assert!(!is_claim_consumed(source, CLAIM_A), 0);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
        assert!(is_claim_consumed(source, CLAIM_A), 1);
        assert!(!verify_claim(source, TEMPLATE, SUBJECT_A, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1), 2);

        // Replaying the same signed claim later would push the expiry out forever.
        timestamp::fast_forward_seconds(100);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x30010, location = Self)]
    fun test_replay_cannot_undo_revocation(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
        attestation::register_issuer(deployer, source, address_of(deployer), vector[]);
        attestation::revoke_batch(deployer, source, vector[SUBJECT_A], 1);
        assert!(!attestation::is_verified(source, SUBJECT_A), 0);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    fun test_enroll_with_signed_nullifier(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(
            user,
            source,
            TEMPLATE,
            CLAIM_A_NULLIFIED,
            vector[SIG_A_NULLIFIED_1, SIG_A_NULLIFIED_2],
            1,
            NULLIFIER
        );
        assert!(attestation::is_verified(source, SUBJECT_A), 0);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x10008, location = Self)]
    fun test_nullifier_not_in_claim_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        // CLAIM_A carries no nullifier, so a caller-chosen one is not vouched for by anybody.
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, NULLIFIER);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    fun test_bump_of_cohort_zero_kills_zktls_facts(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
        assert!(attestation::is_verified(source, SUBJECT_A), 0);

        attestation::bump_issuer_epoch(deployer, source, 0);
        assert!(!attestation::is_verified(source, SUBJECT_A), 1);
        assert!(attestation::issuer_epoch_of(source, 0) == 1, 2);

        // New enrollments land in the new cohort epoch and are usable.
        enroll(
            user, source, TEMPLATE, CLAIM_A_REFRESH, vector[SIG_A_REFRESH_1, SIG_A_REFRESH_2], 1, vector[]
        );
        assert!(attestation::is_verified(source, SUBJECT_A), 3);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x10004, location = Self)]
    fun test_below_threshold_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        assert!(!verify_claim(source, TEMPLATE, SUBJECT_A, CLAIM_A, vector[SIG_A_1], 1), 0);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x10004, location = Self)]
    fun test_no_signatures_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x10004, location = Self)]
    fun test_too_many_signatures_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        let signatures = vector[];
        let index = 0;
        while (index <= MAX_SIGNATURES) {
            signatures.push_back(SIG_A_1);
            index += 1;
        };
        enroll(user, source, TEMPLATE, CLAIM_A, signatures, 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x10005, location = Self)]
    fun test_duplicate_signer_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_1], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x10006, location = Self)]
    fun test_unknown_attestor_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_4], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x10006, location = Self)]
    fun test_signature_over_another_claim_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_B_1, SIG_B_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x60007, location = Self)]
    fun test_unknown_attestor_epoch_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 2, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    fun test_previous_epoch_still_verifies_after_rotation(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(deployer, source, vector[ATTESTOR_4], 1, 100);
        assert!(is_epoch_accepted(source, 1), 0);
        assert!(is_epoch_accepted(source, 2), 1);
        timestamp::fast_forward_seconds(99);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
        assert!(attestation::is_verified(source, SUBJECT_A), 2);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x3000f, location = Self)]
    fun test_previous_epoch_retired_after_grace(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(deployer, source, vector[ATTESTOR_4], 1, 100);
        timestamp::fast_forward_seconds(100);
        assert!(!is_epoch_accepted(source, 1), 0);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x3000f, location = Self)]
    fun test_zero_grace_retires_previous_epoch_at_once(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        // Rotating away a compromised set with no grace cuts it off immediately.
        set_attestor_set(deployer, source, vector[ATTESTOR_4], 1, 0);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x3000f, location = Self)]
    fun test_two_epochs_back_is_retired_despite_grace(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(deployer, source, vector[ATTESTOR_4], 1, 1000);
        set_attestor_set(deployer, source, vector[ATTESTOR_4], 1, 1000);
        assert!(!is_epoch_accepted(source, 1), 0);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_max_epoch_is_not_accepted(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        assert!(!is_epoch_accepted(source, MAX_U64), 0);
        assert!(!is_epoch_accepted(source, 0), 1);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    fun test_huge_grace_does_not_overflow(framework: &signer, deployer: &signer) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        timestamp::fast_forward_seconds(10);
        set_attestor_set(deployer, source, vector[ATTESTOR_4], 1, MAX_U64);
        assert!(is_epoch_accepted(source, 1), 0);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x10006, location = Self)]
    fun test_old_attestors_rejected_under_new_epoch(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(deployer, source, vector[ATTESTOR_4], 1, 0);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1], 2, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    fun test_new_epoch_verifies(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        set_attestor_set(deployer, source, vector[ATTESTOR_4], 1, 0);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_4], 2, vector[]);
        assert!(attestation::is_verified(source, SUBJECT_A), 0);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x60002, location = Self)]
    fun test_unknown_template_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(
            user,
            source,
            OTHER_TEMPLATE,
            CLAIM_A_OTHER_TEMPLATE,
            vector[SIG_OTHER_TEMPLATE_1, SIG_OTHER_TEMPLATE_2],
            1,
            vector[]
        );
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x30003, location = Self)]
    fun test_revoked_template_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        revoke_template(deployer, source, TEMPLATE);
        assert!(!verify_claim(source, TEMPLATE, SUBJECT_A, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1), 0);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    fun test_revoking_template_keeps_recorded_facts(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
        revoke_template(deployer, source, TEMPLATE);
        assert!(attestation::is_verified(source, SUBJECT_A), 0);
    }

    #[test(framework = @0x1, deployer = @0x123, relayer = @0xb22)]
    #[expected_failure(abort_code = 0x10008, location = Self)]
    fun test_claim_for_another_subject_fails(
        framework: &signer, deployer: &signer, relayer: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        // A valid attestation for A is not an attestation for whoever relays it.
        enroll(relayer, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x10008, location = Self)]
    fun test_claim_under_another_template_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        register_template(deployer, source, OTHER_TEMPLATE, LEVEL_ZKTLS + 1, TTL);
        // CLAIM_A names TEMPLATE, so it cannot be redeemed under a more generous template.
        enroll(user, source, OTHER_TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x6000c, location = Self)]
    fun test_enroll_uninitialized_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let deployer_address = address_of(deployer);
        create_account_for_test(deployer_address);
        let source = attestation::get_next_source_address(deployer_address);
        attestation::create(deployer, vector[deployer_address], vector[], vector[], vector[], vector[]);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x30007, location = aptos_framework::attestation)]
    fun test_enroll_on_paused_source_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        attestation::pause(deployer, source);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    #[expected_failure(abort_code = 0x30013, location = aptos_framework::attestation)]
    fun test_enroll_denied_subject_fails(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        attestation::deny(deployer, source, SUBJECT_A, 1, now_seconds());
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11, other = @0xb22)]
    #[expected_failure(abort_code = 0x30014, location = aptos_framework::attestation)]
    fun test_nullifier_binds_one_subject(
        framework: &signer, deployer: &signer, user: &signer, other: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        enroll(
            user,
            source,
            TEMPLATE,
            CLAIM_A_NULLIFIED,
            vector[SIG_A_NULLIFIED_1, SIG_A_NULLIFIED_2],
            1,
            NULLIFIER
        );
        enroll(
            other,
            source,
            TEMPLATE,
            CLAIM_B_NULLIFIED,
            vector[SIG_B_NULLIFIED_1, SIG_B_NULLIFIED_2],
            1,
            NULLIFIER
        );
    }

    #[test(framework = @0x1, deployer = @0x123, user = @0xa11)]
    fun test_enrolled_fact_survives_floor_raise_then_dies_on_next(
        framework: &signer, deployer: &signer, user: &signer
    ) acquires Verifier {
        setup(framework);
        let source = new_verifier(deployer);
        // A floor raised before enrollment must not make new zkTLS facts unusable.
        attestation::set_floor_epoch(deployer, source, 1);
        enroll(user, source, TEMPLATE, CLAIM_A, vector[SIG_A_1, SIG_A_2], 1, vector[]);
        assert!(attestation::is_verified(source, SUBJECT_A), 0);
        // Raising the floor again invalidates it, like every other fact.
        attestation::set_floor_epoch(deployer, source, 2);
        assert!(!attestation::is_verified(source, SUBJECT_A), 1);
    }
}

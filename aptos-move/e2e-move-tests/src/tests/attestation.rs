// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! End-to-end VM tests for the attestation framework modules: `attestation` (sources and facts),
//! `attestation_policy` (a business's rules), `attestation_authorization` (per-action step-up
//! capabilities) and `zktls` (attestor-signed enrollment).
//!
//! Everything a signer produces off chain is produced here in Rust, with the byte layout rebuilt
//! independently from the module docs and then checked against the module's own published message
//! views, so a drift between the two fails loudly. A small consumer package under
//! `attestation.data/gated` stands in for a business contract that gates an entry function on a
//! policy.

use crate::{assert_success, tests::common, MoveHarness};
use aptos_crypto::{
    ed25519::{Ed25519PrivateKey, Ed25519PublicKey},
    SigningKey,
};
use aptos_framework::{BuildOptions, BuiltPackage};
use aptos_language_e2e_tests::account::Account;
use aptos_types::{
    account_address::AccountAddress,
    transaction::{ExecutionStatus, TransactionStatus},
};
use move_core_types::vm_status::AbortLocation;
use once_cell::sync::Lazy;
use serde::{de::DeserializeOwned, Deserialize, Serialize};
use sha3::{Digest, Keccak256};

// ──────────────────────────────────────────────────────────────
// Constants mirrored from the Move modules
// ──────────────────────────────────────────────────────────────

const ATTESTATION_DOMAIN: &[u8] = b"aptos_framework::attestation::ATTEST";
const AUTHORIZATION_DOMAIN: &[u8] = b"aptos_framework::attestation_authorization::AUTH";
const ETH_PREFIX: &[u8] = b"\x19Ethereum Signed Message:\n";

const STATE_NONE: u8 = 0;
const STATE_ACTIVE: u8 = 1;
const STATE_SUSPENDED: u8 = 2;
const STATE_REVOKED: u8 = 3;

const DECISION_ALLOW: u8 = 0;
const DECISION_DENY: u8 = 1;
const DECISION_STEP_UP: u8 = 2;

const REASON_OK: u16 = 0;
const REASON_CHAIN_DENIED: u16 = 1;
const REASON_SOURCE_DENIED: u16 = 2;
const REASON_MISSING_REQUIRED: u16 = 3;
const REASON_NO_QUALIFYING: u16 = 4;
const REASON_LEVEL_TOO_LOW: u16 = 5;
const REASON_ATTR_FAILED: u16 = 6;
const REASON_AMOUNT_THRESHOLD: u16 = 7;
const REASON_POLICY_PAUSED: u16 = 8;
const REASON_EMPTY_BODY: u16 = 9;

const OP_IN: u8 = 0;
const OP_GTE: u8 = 3;

const ACTION_TRANSFER: u8 = 1;
const ATTR_COUNTRY: u16 = 1;
const COUNTRY_PT: [u8; 2] = [0x02, 0x6C];
const COUNTRY_BR: [u8; 2] = [0x00, 0x4C];

const LEVEL_BASIC: u8 = 1;
const LEVEL_ENHANCED: u8 = 2;
const ONE_YEAR: u64 = 31_536_000;

// Abort codes, as `error::<category>(E...)` = (category << 16) | reason.
//
// attestation
const ATT_ENOT_ADMIN: u64 = 0x50002;
const ATT_ENOT_ISSUER: u64 = 0x50003;
const ATT_ENOT_SENTINEL: u64 = 0x50004;
const ATT_ENOT_REMOVER: u64 = 0x50005;
const ATT_ENOT_GUARDIAN: u64 = 0x50006;
const ATT_EPAUSED: u64 = 0x30007;
const ATT_ELENGTH_MISMATCH: u64 = 0x1000C;
const ATT_EBAD_SIGNATURE: u64 = 0x10010;
const ATT_ESTALE_EPOCH: u64 = 0x30011;
const ATT_ENOT_MONOTONIC: u64 = 0x10012;
const ATT_ESUBJECT_DENIED: u64 = 0x30013;
const ATT_ENULLIFIER_BOUND: u64 = 0x30014;
const ATT_ERECORD_NOT_FOUND: u64 = 0x60015;
const ATT_EINVALID_TRANSITION: u64 = 0x30019;
// attestation_policy
const POL_ENOT_EFFECTIVE: u64 = 0x3000C;
const POL_EDENIED: u64 = 0x5000D;
const POL_ESTEP_UP_REQUIRED: u64 = 0x5000E;
const POL_ETOO_MANY_CHAIN_DENY: u64 = 0x10012;
const POL_EBAD_RULE: u64 = 0x10010;
// attestation_authorization
const AUTH_EBAD_SIGNATURE: u64 = 0x10002;
const AUTH_EEXPIRED: u64 = 0x30003;
const AUTH_ENONCE_USED: u64 = 0x30004;
const AUTH_EAMOUNT_OVER_BUCKET: u64 = 0x10005;
const AUTH_ETTL_TOO_LONG: u64 = 0x10006;
// zktls
const ZK_ETEMPLATE_REVOKED: u64 = 0x30003;
const ZK_EBELOW_THRESHOLD: u64 = 0x10004;
const ZK_EDUPLICATE_SIGNER: u64 = 0x10005;
const ZK_EUNKNOWN_ATTESTOR: u64 = 0x10006;
const ZK_EMALFORMED_CLAIM: u64 = 0x10008;
const ZK_ERETIRED_ATTESTOR_EPOCH: u64 = 0x3000F;
const ZK_ECLAIM_CONSUMED: u64 = 0x30010;

// ──────────────────────────────────────────────────────────────
// Mirrors of Move structs returned by views
// ──────────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct Change {
    _at_secs: u64,
    prev_state: u8,
    new_state: u8,
    reason: u16,
    issuer_id: u16,
}

#[derive(Debug, Deserialize)]
struct Record {
    state: u8,
    level: u8,
    issuer_id: u16,
    issuer_epoch: u64,
    issued_at_secs: u64,
    expires_at_secs: u64,
    revoked_at_secs: u64,
    _reason: u16,
    attestation_digest: Vec<u8>,
    // `SimpleMap<u16, vector<u8>>` is a vector of key/value elements in BCS.
    attrs: Vec<(u16, Vec<u8>)>,
    history: Vec<Change>,
}

// ──────────────────────────────────────────────────────────────
// Generic helpers
// ──────────────────────────────────────────────────────────────

fn arg<T: Serialize + ?Sized>(value: &T) -> Vec<u8> {
    bcs::to_bytes(value).unwrap()
}

fn addr(hex: &str) -> AccountAddress {
    AccountAddress::from_hex_literal(hex).unwrap()
}

fn keccak(bytes: &[u8]) -> Vec<u8> {
    Keccak256::digest(bytes).to_vec()
}

fn run(h: &mut MoveHarness, sender: &Account, fun: &str, args: Vec<Vec<u8>>) -> TransactionStatus {
    h.run_entry_function(sender, str::parse(fun).unwrap(), vec![], args)
}

fn view_raw(h: &mut MoveHarness, fun: &str, args: Vec<Vec<u8>>) -> Vec<Vec<u8>> {
    h.execute_view_function(str::parse(fun).unwrap(), vec![], args)
        .values
        .unwrap_or_else(|e| panic!("view {fun} failed: {e:?}"))
}

fn view<T: DeserializeOwned>(h: &mut MoveHarness, fun: &str, args: Vec<Vec<u8>>) -> T {
    bcs::from_bytes(&view_raw(h, fun, args)[0]).unwrap()
}

fn now(h: &mut MoveHarness) -> u64 {
    view(h, "0x1::timestamp::now_seconds", vec![])
}

fn chain_id(h: &mut MoveHarness) -> u8 {
    view(h, "0x1::chain_id::get", vec![])
}

fn advance(h: &mut MoveHarness, secs: u64) {
    h.fast_forward(secs);
    h.executor.new_block();
}

/// Assert a Move abort with the given code raised inside the given module.
#[track_caller]
fn assert_abort(status: &TransactionStatus, module: &str, code: u64) {
    match status {
        TransactionStatus::Keep(ExecutionStatus::MoveAbort {
            location,
            code: actual,
            ..
        }) => {
            match location {
                AbortLocation::Module(id) => assert_eq!(
                    id.name().as_str(),
                    module,
                    "abort {actual:#x} raised in {id} instead of {module}"
                ),
                AbortLocation::Script => panic!("abort {actual:#x} raised in a script"),
            }
            assert_eq!(*actual, code, "expected abort {code:#x}, got {actual:#x}");
        },
        other => panic!("expected MoveAbort({code:#x}) in {module}, got {other:?}"),
    }
}

// ──────────────────────────────────────────────────────────────
// Keys
// ──────────────────────────────────────────────────────────────

fn ed25519_key(seed: u8) -> (Ed25519PrivateKey, Vec<u8>) {
    let private = Ed25519PrivateKey::try_from(&[seed; 32][..]).unwrap();
    let public = Ed25519PublicKey::from(&private).to_bytes().to_vec();
    (private, public)
}

struct Attestor {
    secret: libsecp256k1::SecretKey,
    /// 20-byte Ethereum-style address: low 20 bytes of keccak256 over the uncompressed key.
    address: Vec<u8>,
}

fn attestor(seed: u8) -> Attestor {
    let secret = libsecp256k1::SecretKey::parse(&[seed; 32]).unwrap();
    let public = libsecp256k1::PublicKey::from_secret_key(&secret).serialize();
    let address = keccak(&public[1..])[12..].to_vec();
    Attestor { secret, address }
}

// ──────────────────────────────────────────────────────────────
// World
// ──────────────────────────────────────────────────────────────

/// One harness plus one source whose five roles are held by five different accounts, which is
/// the configuration that makes role separation observable.
struct World {
    h: MoveHarness,
    admin: Account,
    issuer: Account,
    sentinel: Account,
    remover: Account,
    guardian: Account,
    relayer: Account,
    alice: Account,
    bob: Account,
    carol: Account,
    source: AccountAddress,
    issuer_key: Ed25519PrivateKey,
}

const ISSUER_ID: u16 = 1;

impl World {
    fn new() -> Self {
        let mut h = MoveHarness::new();
        let admin = h.new_account_at(addr("0xad"));
        let issuer = h.new_account_at(addr("0x155"));
        let sentinel = h.new_account_at(addr("0x5e1"));
        let remover = h.new_account_at(addr("0x5e2"));
        let guardian = h.new_account_at(addr("0x6a"));
        let relayer = h.new_account_at(addr("0x7e"));
        let alice = h.new_account_at(addr("0xa11ce"));
        let bob = h.new_account_at(addr("0xb0b"));
        let carol = h.new_account_at(addr("0xca401"));
        let (issuer_key, issuer_pubkey) = ed25519_key(7);

        let source = create_source(
            &mut h,
            &admin,
            vec![*admin.address()],
            vec![*issuer.address()],
            vec![*sentinel.address()],
            vec![*remover.address()],
            vec![*guardian.address()],
        );
        assert_success!(run(
            &mut h,
            &admin,
            "0x1::attestation::register_issuer",
            vec![arg(&source), arg(issuer.address()), arg(&issuer_pubkey),]
        ));

        World {
            h,
            admin,
            issuer,
            sentinel,
            remover,
            guardian,
            relayer,
            alice,
            bob,
            carol,
            source,
            issuer_key,
        }
    }

    fn issue(&mut self, subjects: &[&Account], levels: Vec<u8>, ttl: u64) -> TransactionStatus {
        let expiry = now(&mut self.h) + ttl;
        let subjects: Vec<AccountAddress> = subjects.iter().map(|a| *a.address()).collect();
        let expiries = vec![expiry; subjects.len()];
        let issuer = self.issuer.clone();
        run(&mut self.h, &issuer, "0x1::attestation::issue_batch", vec![
            arg(&self.source),
            arg(&subjects),
            arg(&levels),
            arg(&expiries),
            arg(&0u16),
        ])
    }

    fn verified(&mut self, subject: &Account) -> bool {
        let source = self.source;
        is_verified(&mut self.h, source, *subject.address())
    }

    fn deny(&mut self, actor: &Account, subject: &Account) -> TransactionStatus {
        let at = now(&mut self.h);
        run(&mut self.h, actor, "0x1::attestation::deny", vec![
            arg(&self.source),
            arg(subject.address()),
            arg(&42u16),
            arg(&at),
        ])
    }

    fn undeny(&mut self, actor: &Account, subject: &Account) -> TransactionStatus {
        run(&mut self.h, actor, "0x1::attestation::undeny", vec![
            arg(&self.source),
            arg(subject.address()),
        ])
    }
}

fn create_source(
    h: &mut MoveHarness,
    deployer: &Account,
    admins: Vec<AccountAddress>,
    issuers: Vec<AccountAddress>,
    sentinels: Vec<AccountAddress>,
    removers: Vec<AccountAddress>,
    guardians: Vec<AccountAddress>,
) -> AccountAddress {
    let predicted: AccountAddress =
        view(h, "0x1::attestation::get_next_source_address", vec![arg(
            deployer.address(),
        )]);
    assert_success!(run(h, deployer, "0x1::attestation::create", vec![
        arg(&admins),
        arg(&issuers),
        arg(&sentinels),
        arg(&removers),
        arg(&guardians),
    ]));
    assert!(view::<bool>(h, "0x1::attestation::is_source", vec![arg(
        &predicted
    )]));
    predicted
}

fn is_verified(h: &mut MoveHarness, source: AccountAddress, subject: AccountAddress) -> bool {
    view(h, "0x1::attestation::is_verified", vec![
        arg(&source),
        arg(&subject),
    ])
}

fn source_view<T: DeserializeOwned>(
    h: &mut MoveHarness,
    fun: &str,
    source: AccountAddress,
    subject: AccountAddress,
) -> T {
    view(h, &format!("0x1::attestation::{fun}"), vec![
        arg(&source),
        arg(&subject),
    ])
}

// ──────────────────────────────────────────────────────────────
// Relay attestations
// ──────────────────────────────────────────────────────────────

struct Attestation {
    subject: AccountAddress,
    issuer_id: u16,
    issuer_epoch: u64,
    level: u8,
    expires_at_secs: u64,
    issued_at_secs: u64,
    nullifier: Vec<u8>,
}

/// Rebuilds `attestation::attestation_message` byte for byte.
fn attestation_message(chain_id: u8, source: AccountAddress, a: &Attestation) -> Vec<u8> {
    let mut message = ATTESTATION_DOMAIN.to_vec();
    message.extend(arg(&chain_id));
    message.extend(arg(&source));
    message.extend(arg(&a.subject));
    message.extend(arg(&a.issuer_id));
    message.extend(arg(&a.issuer_epoch));
    message.extend(arg(&a.level));
    message.extend(arg(&a.expires_at_secs));
    message.extend(arg(&a.issued_at_secs));
    message.extend(arg(&a.nullifier));
    message
}

fn attestation_message_view(
    h: &mut MoveHarness,
    source: AccountAddress,
    a: &Attestation,
) -> Vec<u8> {
    view(h, "0x1::attestation::attestation_message", vec![
        arg(&source),
        arg(&a.subject),
        arg(&a.issuer_id),
        arg(&a.issuer_epoch),
        arg(&a.level),
        arg(&a.expires_at_secs),
        arg(&a.issued_at_secs),
        arg(&a.nullifier),
    ])
}

fn sign_attestation(w: &mut World, a: &Attestation) -> Vec<u8> {
    let chain = chain_id(&mut w.h);
    let message = attestation_message(chain, w.source, a);
    let source = w.source;
    assert_eq!(
        message,
        attestation_message_view(&mut w.h, source, a),
        "Rust and Move disagree on the attestation message layout"
    );
    w.issuer_key
        .sign_arbitrary_message(&message)
        .to_bytes()
        .to_vec()
}

fn redeem(w: &mut World, a: &Attestation, signature: &[u8]) -> TransactionStatus {
    let relayer = w.relayer.clone();
    run(
        &mut w.h,
        &relayer,
        "0x1::attestation::redeem_attestation",
        vec![
            arg(&w.source),
            arg(&a.subject),
            arg(&a.issuer_id),
            arg(&a.issuer_epoch),
            arg(&a.level),
            arg(&a.expires_at_secs),
            arg(&a.issued_at_secs),
            arg(&a.nullifier),
            arg(&signature.to_vec()),
        ],
    )
}

fn fresh_attestation(w: &mut World, subject: &Account, level: u8) -> Attestation {
    let t = now(&mut w.h);
    Attestation {
        subject: *subject.address(),
        issuer_id: ISSUER_ID,
        issuer_epoch: 0,
        level,
        expires_at_secs: t + ONE_YEAR,
        issued_at_secs: t,
        nullifier: vec![],
    }
}

// ──────────────────────────────────────────────────────────────
// Policies
// ──────────────────────────────────────────────────────────────

fn create_policy(
    h: &mut MoveHarness,
    deployer: &Account,
    guardians: Vec<AccountAddress>,
) -> AccountAddress {
    let predicted: AccountAddress =
        view(h, "0x1::attestation_policy::get_next_policy_address", vec![
            arg(deployer.address()),
        ]);
    assert_success!(run(h, deployer, "0x1::attestation_policy::create", vec![
        arg(&vec![*deployer.address()]),
        arg(&guardians),
    ]));
    predicted
}

struct BodySpec {
    require_any: Vec<(AccountAddress, u8)>,
    require_all: Vec<(AccountAddress, u8)>,
    deny_any: Vec<AccountAddress>,
    chain_deny: Vec<AccountAddress>,
}

impl BodySpec {
    fn any(source: AccountAddress, level: u8) -> Self {
        BodySpec {
            require_any: vec![(source, level)],
            require_all: vec![],
            deny_any: vec![],
            chain_deny: vec![],
        }
    }
}

fn stage_body(
    h: &mut MoveHarness,
    admin: &Account,
    policy: AccountAddress,
    body: &BodySpec,
    effective_at_secs: u64,
) -> TransactionStatus {
    let split = |refs: &Vec<(AccountAddress, u8)>| -> (Vec<AccountAddress>, Vec<u8>) {
        refs.iter().cloned().unzip()
    };
    let (any_sources, any_levels) = split(&body.require_any);
    let (all_sources, all_levels) = split(&body.require_all);
    run(h, admin, "0x1::attestation_policy::stage_body", vec![
        arg(&policy),
        arg(&any_sources),
        arg(&any_levels),
        arg(&all_sources),
        arg(&all_levels),
        arg(&body.deny_any),
        arg(&body.chain_deny),
        arg(&effective_at_secs),
    ])
}

fn activate(h: &mut MoveHarness, anyone: &Account, policy: AccountAddress) -> TransactionStatus {
    run(
        h,
        anyone,
        "0x1::attestation_policy::activate_pending",
        vec![arg(&policy)],
    )
}

/// Stage `body` effective now and push it live straight away.
fn apply_body(h: &mut MoveHarness, admin: &Account, policy: AccountAddress, body: &BodySpec) {
    let t = now(h);
    assert_success!(stage_body(h, admin, policy, body, t));
    assert_success!(activate(h, admin, policy));
}

fn policy_view<T: DeserializeOwned>(
    h: &mut MoveHarness,
    fun: &str,
    policy: AccountAddress,
    subject: AccountAddress,
    amount: u64,
) -> T {
    view(h, &format!("0x1::attestation_policy::{fun}"), vec![
        arg(&policy),
        arg(&subject),
        arg(&ACTION_TRANSFER),
        arg(&amount),
    ])
}

fn decision(
    h: &mut MoveHarness,
    policy: AccountAddress,
    subject: &Account,
    amount: u64,
) -> (u8, u16) {
    let values = view_raw(h, "0x1::attestation_policy::evaluate", vec![
        arg(&policy),
        arg(subject.address()),
        arg(&ACTION_TRANSFER),
        arg(&amount),
    ]);
    (
        bcs::from_bytes(&values[0]).unwrap(),
        bcs::from_bytes(&values[1]).unwrap(),
    )
}

fn reason(h: &mut MoveHarness, policy: AccountAddress, subject: &Account) -> u16 {
    policy_view(h, "reason_of", policy, *subject.address(), 1)
}

// ──────────────────────────────────────────────────────────────
// The consumer contract and authorizations
// ──────────────────────────────────────────────────────────────

/// Compiled once and shared. Compiling a package against the framework recurses deeply enough to
/// overflow the default 2 MB test-thread stack, so the build runs on its own large-stack thread.
static GATED: Lazy<BuiltPackage> = Lazy::new(|| {
    std::thread::Builder::new()
        .stack_size(32 * 1024 * 1024)
        .spawn(|| {
            BuiltPackage::build(
                common::test_dir_path("attestation.data/gated"),
                BuildOptions::default(),
            )
            .expect("the gated consumer package must build")
        })
        .unwrap()
        .join()
        .unwrap()
});

fn publish_gated(h: &mut MoveHarness) {
    let account = h.new_account_at(addr("0xcafe"));
    let txn = h.create_publish_built_package(&account, &GATED, |_| {});
    assert_success!(h.run(txn));
}

fn gated_transfer(
    h: &mut MoveHarness,
    user: &Account,
    policy: AccountAddress,
    amount: u64,
) -> TransactionStatus {
    run(h, user, "0xcafe::vault::transfer", vec![
        arg(&policy),
        arg(&amount),
    ])
}

fn gated_transfer_authorized(
    h: &mut MoveHarness,
    user: &Account,
    policy: AccountAddress,
    amount: u64,
    authorization: &[u8],
) -> TransactionStatus {
    run(h, user, "0xcafe::vault::transfer_authorized", vec![
        arg(&policy),
        arg(&amount),
        arg(&authorization.to_vec()),
    ])
}

fn transfer_count(h: &mut MoveHarness, user: &Account) -> u64 {
    view(h, "0xcafe::vault::count_of", vec![arg(user.address())])
}

struct Authorization {
    policy: AccountAddress,
    subject: AccountAddress,
    action: u8,
    amount_bucket: u8,
    nonce: [u8; 32],
    issued_at_secs: u64,
    expires_at_secs: u64,
}

/// Rebuilds `attestation_authorization::authorization_message` byte for byte.
fn authorization_message(chain_id: u8, a: &Authorization) -> Vec<u8> {
    let mut message = AUTHORIZATION_DOMAIN.to_vec();
    message.extend(arg(&chain_id));
    message.extend(arg(&a.policy));
    message.extend(arg(&a.subject));
    message.extend(arg(&a.action));
    message.extend(arg(&a.amount_bucket));
    message.extend(arg(&a.nonce.to_vec()));
    message.extend(arg(&a.issued_at_secs));
    message.extend(arg(&a.expires_at_secs));
    message
}

/// Produce the fixed-width blob `attestation_authorization::decode` expects:
/// action (1) || bucket (1) || nonce (32) || issued_at (8 LE) || expires_at (8 LE) || sig (64).
fn sign_authorization(h: &mut MoveHarness, key: &Ed25519PrivateKey, a: &Authorization) -> Vec<u8> {
    let message = authorization_message(chain_id(h), a);
    let from_view: Vec<u8> = view(
        h,
        "0x1::attestation_authorization::authorization_message",
        vec![
            arg(&a.policy),
            arg(&a.subject),
            arg(&a.action),
            arg(&a.amount_bucket),
            arg(&a.nonce.to_vec()),
            arg(&a.issued_at_secs),
            arg(&a.expires_at_secs),
        ],
    );
    assert_eq!(
        message, from_view,
        "Rust and Move disagree on the authorization message layout"
    );
    let signature = key.sign_arbitrary_message(&message).to_bytes();
    let mut blob = vec![a.action, a.amount_bucket];
    blob.extend_from_slice(&a.nonce);
    blob.extend_from_slice(&a.issued_at_secs.to_le_bytes());
    blob.extend_from_slice(&a.expires_at_secs.to_le_bytes());
    blob.extend_from_slice(&signature);
    blob
}

/// A world with a policy requiring the main source at LEVEL_BASIC, a step-up threshold of 1000
/// on transfers, an authorizer key, and the consumer contract published. Alice is verified,
/// Carol is not.
fn step_up_world() -> (World, AccountAddress, Ed25519PrivateKey) {
    let mut w = World::new();
    let alice = w.alice.clone();
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    let admin = w.admin.clone();
    let policy = create_policy(&mut w.h, &admin, vec![]);
    apply_body(
        &mut w.h,
        &admin,
        policy,
        &BodySpec::any(w.source, LEVEL_BASIC),
    );
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation_policy::set_step_up",
        vec![arg(&policy), arg(&ACTION_TRANSFER), arg(&1000u64)]
    ));
    let (authorizer, authorizer_pubkey) = ed25519_key(9);
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation_policy::set_authorizer",
        vec![arg(&policy), arg(&authorizer_pubkey), arg(&300u64)]
    ));
    publish_gated(&mut w.h);
    (w, policy, authorizer)
}

fn authorization_for(
    h: &mut MoveHarness,
    policy: AccountAddress,
    subject: &Account,
    nonce_byte: u8,
    ttl: u64,
) -> Authorization {
    let t = now(h);
    Authorization {
        policy,
        subject: *subject.address(),
        action: ACTION_TRANSFER,
        // 10^4 = 10000 ceiling.
        amount_bucket: 4,
        nonce: [nonce_byte; 32],
        issued_at_secs: t,
        expires_at_secs: t + ttl,
    }
}

// ──────────────────────────────────────────────────────────────
// zkTLS
// ──────────────────────────────────────────────────────────────

const TEMPLATE_ID: [u8; 32] = [0xAB; 32];
const ZK_LEVEL: u8 = 3;
const ZK_TTL: u64 = 86_400;

/// Build a claim that binds the subject and the template the way `zktls::claim_binds` checks:
/// both as lowercase hex anywhere in the claim bytes. A non-empty nullifier must be bound too.
fn claim_for(subject: AccountAddress, template_id: &[u8], nullifier: &[u8], salt: &str) -> Vec<u8> {
    let mut claim = format!(
        "{{\"provider\":\"http\",\"owner\":\"0x{}\",\"template\":\"0x{}\",\"context\":\"{}\"",
        hex::encode(subject.to_vec()),
        hex::encode(template_id),
        salt,
    );
    if !nullifier.is_empty() {
        claim.push_str(&format!(",\"nullifier\":\"0x{}\"", hex::encode(nullifier)));
    }
    claim.push('}');
    claim.into_bytes()
}

/// `zktls::claim_digest`: keccak256 over the Ethereum-prefixed claim.
fn claim_digest(claim: &[u8]) -> [u8; 32] {
    let mut prefixed = ETH_PREFIX.to_vec();
    prefixed.extend(claim.len().to_string().as_bytes());
    prefixed.extend(claim);
    keccak(&prefixed).try_into().unwrap()
}

/// 65-byte recoverable signature: r || s || recovery id (0 or 1, not Ethereum's 27/28).
fn sign_claim(attestor: &Attestor, claim: &[u8]) -> Vec<u8> {
    let message = libsecp256k1::Message::parse(&claim_digest(claim));
    let (signature, recovery_id) = libsecp256k1::sign(&message, &attestor.secret);
    let mut out = signature.serialize().to_vec();
    out.push(recovery_id.serialize());
    out
}

/// A world whose source has a zkTLS verifier with three attestors at threshold two, and one
/// active template.
fn zktls_world() -> (World, Vec<Attestor>) {
    let mut w = World::new();
    let attestors = vec![attestor(1), attestor(2), attestor(3)];
    let admin = w.admin.clone();
    let source = w.source;
    assert_success!(run(&mut w.h, &admin, "0x1::zktls::initialize", vec![arg(
        &source
    )]));
    set_attestors(&mut w, &attestors.iter().collect::<Vec<_>>(), 2, 0);
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::zktls::register_template",
        vec![
            arg(&source),
            arg(&TEMPLATE_ID.to_vec()),
            arg(&ZK_LEVEL),
            arg(&ZK_TTL),
        ]
    ));
    (w, attestors)
}

fn set_attestors(w: &mut World, attestors: &[&Attestor], threshold: u64, grace_secs: u64) {
    let addresses: Vec<Vec<u8>> = attestors.iter().map(|a| a.address.clone()).collect();
    let admin = w.admin.clone();
    assert_success!(run(&mut w.h, &admin, "0x1::zktls::set_attestor_set", vec![
        arg(&w.source),
        arg(&addresses),
        arg(&threshold),
        arg(&grace_secs),
    ]));
}

fn enroll(
    w: &mut World,
    user: &Account,
    claim: &[u8],
    signatures: Vec<Vec<u8>>,
    attestor_epoch: u64,
    nullifier: &[u8],
) -> TransactionStatus {
    run(&mut w.h, user, "0x1::zktls::enroll", vec![
        arg(&w.source),
        arg(&TEMPLATE_ID.to_vec()),
        arg(&claim.to_vec()),
        arg(&signatures),
        arg(&attestor_epoch),
        arg(&nullifier.to_vec()),
    ])
}

fn verify_claim(
    w: &mut World,
    subject: &Account,
    claim: &[u8],
    signatures: Vec<Vec<u8>>,
    attestor_epoch: u64,
) -> bool {
    let source = w.source;
    view(&mut w.h, "0x1::zktls::verify_claim", vec![
        arg(&source),
        arg(&TEMPLATE_ID.to_vec()),
        arg(subject.address()),
        arg(&claim.to_vec()),
        arg(&signatures),
        arg(&attestor_epoch),
    ])
}

// ══════════════════════════════════════════════════════════════
// Sources, roles and issuers
// ══════════════════════════════════════════════════════════════

#[test]
fn test_source_creation_and_role_views() {
    let mut w = World::new();
    let source = w.source;
    let admins: Vec<AccountAddress> =
        view(&mut w.h, "0x1::attestation::admins", vec![arg(&source)]);
    assert_eq!(admins, vec![*w.admin.address()]);
    let issuers: Vec<AccountAddress> =
        view(&mut w.h, "0x1::attestation::issuers", vec![arg(&source)]);
    assert_eq!(issuers, vec![*w.issuer.address()]);
    assert_eq!(
        view::<u16>(&mut w.h, "0x1::attestation::issuer_id_of", vec![
            arg(&source),
            arg(w.issuer.address()),
        ]),
        ISSUER_ID
    );
    assert_eq!(
        view::<u64>(&mut w.h, "0x1::attestation::standard_version", vec![]),
        1
    );
    assert!(!view::<bool>(
        &mut w.h,
        "0x1::attestation::is_paused",
        vec![arg(&source)]
    ));
    // The deployer holds no role it was not given: a source deployed by a third party.
    let deployer = w.relayer.clone();
    let other = create_source(
        &mut w.h,
        &deployer,
        vec![*w.admin.address()],
        vec![],
        vec![],
        vec![],
        vec![],
    );
    assert!(!view::<bool>(&mut w.h, "0x1::attestation::is_admin", vec![
        arg(deployer.address()),
        arg(&other),
    ]));
    // An address that is not a source is not one.
    assert!(!view::<bool>(
        &mut w.h,
        "0x1::attestation::is_source",
        vec![arg(w.alice.address())]
    ));
}

#[test]
fn test_only_admin_registers_issuers_and_grants_roles() {
    let mut w = World::new();
    let (_, pubkey) = ed25519_key(11);
    let issuer = w.issuer.clone();
    let source = w.source;
    let status = run(
        &mut w.h,
        &issuer,
        "0x1::attestation::register_issuer",
        vec![arg(&source), arg(w.bob.address()), arg(&pubkey)],
    );
    assert_abort(&status, "attestation", ATT_ENOT_ADMIN);
    let status = run(&mut w.h, &issuer, "0x1::attestation::add_sentinels", vec![
        arg(&source),
        arg(&vec![*issuer.address()]),
    ]);
    assert_abort(&status, "attestation", ATT_ENOT_ADMIN);

    // The admin can, and the new issuer gets the next id.
    let admin = w.admin.clone();
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation::register_issuer",
        vec![arg(&source), arg(w.bob.address()), arg(&pubkey),]
    ));
    assert_eq!(
        view::<u16>(&mut w.h, "0x1::attestation::issuer_id_of", vec![
            arg(&source),
            arg(w.bob.address()),
        ]),
        2
    );
}

// ══════════════════════════════════════════════════════════════
// Write path 1: issuer batch
// ══════════════════════════════════════════════════════════════

#[test]
fn test_issue_batch_and_read_back() {
    let mut w = World::new();
    let (alice, bob, carol) = (w.alice.clone(), w.bob.clone(), w.carol.clone());
    assert_success!(w.issue(&[&alice, &bob], vec![LEVEL_ENHANCED, LEVEL_BASIC], ONE_YEAR));

    let source = w.source;
    assert!(w.verified(&alice));
    assert!(w.verified(&bob));
    assert!(!w.verified(&carol));
    assert_eq!(
        source_view::<u8>(&mut w.h, "level_of", source, *alice.address()),
        LEVEL_ENHANCED
    );
    assert_eq!(
        source_view::<u8>(&mut w.h, "state_of", source, *alice.address()),
        STATE_ACTIVE
    );
    assert_eq!(
        source_view::<u8>(&mut w.h, "state_of", source, *carol.address()),
        STATE_NONE
    );

    let record: Record = source_view(&mut w.h, "record_of", source, *alice.address());
    assert_eq!(record.state, STATE_ACTIVE);
    assert_eq!(record.level, LEVEL_ENHANCED);
    assert_eq!(record.issuer_id, ISSUER_ID);
    assert_eq!(record.issuer_epoch, 0);
    assert!(record.attestation_digest.is_empty());
    assert_eq!(record.history.len(), 1);
    assert_eq!(record.history[0].prev_state, STATE_NONE);
    assert_eq!(record.history[0].new_state, STATE_ACTIVE);
    assert_eq!(record.history[0].issuer_id, ISSUER_ID);
    assert_eq!(
        source_view::<u64>(&mut w.h, "expires_at", source, *alice.address()),
        record.expires_at_secs
    );
}

#[test]
fn test_issue_batch_rejections() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    // Two subjects, one level.
    let status = w.issue(&[&alice, &bob], vec![LEVEL_BASIC], ONE_YEAR);
    assert_abort(&status, "attestation", ATT_ELENGTH_MISMATCH);

    // Neither the admin nor the sentinel is an issuer.
    for actor in [w.admin.clone(), w.sentinel.clone()] {
        let source = w.source;
        let status = run(&mut w.h, &actor, "0x1::attestation::issue_batch", vec![
            arg(&source),
            arg(&vec![*alice.address()]),
            arg(&vec![LEVEL_BASIC]),
            arg(&vec![u64::MAX]),
            arg(&0u16),
        ]);
        assert_abort(&status, "attestation", ATT_ENOT_ISSUER);
    }
}

#[test]
fn test_expiry_and_revocation_lifecycle() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    assert_success!(w.issue(&[&bob], vec![LEVEL_BASIC], 100));
    advance(&mut w.h, 101);
    // Bob's fact lapsed on its own; nobody had to relay anything.
    assert!(!w.verified(&bob));
    assert!(w.verified(&alice));

    // Suspend is reversible, revoke is terminal.
    let issuer = w.issuer.clone();
    let source = w.source;
    assert_success!(run(&mut w.h, &issuer, "0x1::attestation::suspend", vec![
        arg(&source),
        arg(alice.address()),
        arg(&5u16),
    ]));
    assert!(!w.verified(&alice));
    assert_eq!(
        source_view::<u8>(&mut w.h, "state_of", source, *alice.address()),
        STATE_SUSPENDED
    );
    assert_success!(run(&mut w.h, &issuer, "0x1::attestation::unsuspend", vec![
        arg(&source),
        arg(alice.address()),
        arg(&6u16),
    ]));
    assert!(w.verified(&alice));
    assert_success!(run(
        &mut w.h,
        &issuer,
        "0x1::attestation::revoke_batch",
        vec![arg(&source), arg(&vec![*alice.address()]), arg(&7u16),]
    ));
    assert!(!w.verified(&alice));
    let record: Record = source_view(&mut w.h, "record_of", source, *alice.address());
    assert_eq!(record.state, STATE_REVOKED);
    assert!(record.revoked_at_secs > 0);
    // issue, suspend, unsuspend, revoke.
    let transitions: Vec<(u8, u8, u16)> = record
        .history
        .iter()
        .map(|c| (c.prev_state, c.new_state, c.reason))
        .collect();
    assert_eq!(transitions, vec![
        (STATE_NONE, STATE_ACTIVE, 0),
        (STATE_ACTIVE, STATE_SUSPENDED, 5),
        (STATE_SUSPENDED, STATE_ACTIVE, 6),
        (STATE_ACTIVE, STATE_REVOKED, 7),
    ]);
}

#[test]
fn test_issuer_epoch_bump_kills_cohort() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    assert_success!(w.issue(&[&alice, &bob], vec![LEVEL_BASIC, LEVEL_BASIC], ONE_YEAR));
    let admin = w.admin.clone();
    let source = w.source;
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation::bump_issuer_epoch",
        vec![arg(&source), arg(&ISSUER_ID),]
    ));
    // One write, both facts dead.
    assert!(!w.verified(&alice));
    assert!(!w.verified(&bob));
    assert_eq!(
        view::<u64>(&mut w.h, "0x1::attestation::issuer_epoch_of", vec![
            arg(&source),
            arg(&ISSUER_ID),
        ]),
        1
    );
    // Re-issuing under the new epoch brings a subject back.
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    assert!(w.verified(&alice));
    assert!(!w.verified(&bob));
}

#[test]
fn test_floor_epoch_kills_everything_below_it() {
    let mut w = World::new();
    let alice = w.alice.clone();
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    let admin = w.admin.clone();
    let source = w.source;
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation::set_floor_epoch",
        vec![arg(&source), arg(&1u64),]
    ));
    assert!(!w.verified(&alice));
    assert_eq!(
        view::<u64>(&mut w.h, "0x1::attestation::floor_epoch", vec![arg(
            &source
        )]),
        1
    );
    // A fresh write lands at the effective epoch, which is at least the floor.
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    assert!(w.verified(&alice));
    // The floor only rises, so lowering it can never resurrect a fact.
    let status = run(&mut w.h, &admin, "0x1::attestation::set_floor_epoch", vec![
        arg(&source),
        arg(&1u64),
    ]);
    assert_abort(&status, "attestation", ATT_ENOT_MONOTONIC);
}

#[test]
fn test_lifecycle_transitions_are_checked() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    let issuer = w.issuer.clone();
    let source = w.source;
    let transition = |h: &mut MoveHarness, fun: &str, subject: &Account| {
        run(h, &issuer, &format!("0x1::attestation::{fun}"), vec![
            arg(&source),
            arg(subject.address()),
            arg(&0u16),
        ])
    };
    // Only a suspended record can be unsuspended, and there must be a record at all.
    assert_abort(
        &transition(&mut w.h, "unsuspend", &alice),
        "attestation",
        ATT_EINVALID_TRANSITION,
    );
    assert_abort(
        &transition(&mut w.h, "suspend", &bob),
        "attestation",
        ATT_ERECORD_NOT_FOUND,
    );

    // A transition keeps the epoch the fact was written under, so unsuspending after a bump
    // does not launder a fact from a compromised cohort back to life.
    assert_success!(transition(&mut w.h, "suspend", &alice));
    let admin = w.admin.clone();
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation::bump_issuer_epoch",
        vec![arg(&source), arg(&ISSUER_ID),]
    ));
    assert_success!(transition(&mut w.h, "unsuspend", &alice));
    let record: Record = source_view(&mut w.h, "record_of", source, *alice.address());
    assert_eq!(record.state, STATE_ACTIVE);
    assert_eq!(record.issuer_epoch, 0);
    assert!(!w.verified(&alice));

    // Revocation is terminal: a revoked record cannot be suspended, and revoking it again is a
    // no-op rather than an abort, so a batch containing it still goes through.
    let revoke = |h: &mut MoveHarness| {
        run(h, &issuer, "0x1::attestation::revoke_batch", vec![
            arg(&source),
            arg(&vec![*alice.address()]),
            arg(&9u16),
        ])
    };
    assert_success!(revoke(&mut w.h));
    let history_len = source_view::<Record>(&mut w.h, "record_of", source, *alice.address())
        .history
        .len();
    assert_success!(revoke(&mut w.h));
    let record: Record = source_view(&mut w.h, "record_of", source, *alice.address());
    assert_eq!(record.history.len(), history_len);
    assert_abort(
        &transition(&mut w.h, "suspend", &alice),
        "attestation",
        ATT_EINVALID_TRANSITION,
    );
    assert_abort(
        &transition(&mut w.h, "unsuspend", &alice),
        "attestation",
        ATT_EINVALID_TRANSITION,
    );
}

// ══════════════════════════════════════════════════════════════
// Write path 2: permissionless relay of issuer-signed attestations
// ══════════════════════════════════════════════════════════════

#[test]
fn test_redeem_attestation_signed_off_chain() {
    let mut w = World::new();
    let alice = w.alice.clone();
    let mut a = fresh_attestation(&mut w, &alice, LEVEL_ENHANCED);
    a.nullifier = vec![0x11; 32];
    let signature = sign_attestation(&mut w, &a);
    // The relayer is neither the subject nor the issuer, and pays for the write.
    assert_success!(redeem(&mut w, &a, &signature));

    assert!(w.verified(&alice));
    let source = w.source;
    let record: Record = source_view(&mut w.h, "record_of", source, *alice.address());
    assert_eq!(record.level, LEVEL_ENHANCED);
    assert_eq!(record.issued_at_secs, a.issued_at_secs);
    assert_eq!(record.expires_at_secs, a.expires_at_secs);
    let chain = chain_id(&mut w.h);
    assert_eq!(
        record.attestation_digest,
        keccak(&attestation_message(chain, source, &a)),
        "the stored digest names the exact attestation the fact came from"
    );
}

#[test]
fn test_redeem_rejects_replay_and_tampering() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    let a = fresh_attestation(&mut w, &alice, LEVEL_BASIC);
    let signature = sign_attestation(&mut w, &a);
    assert_success!(redeem(&mut w, &a, &signature));

    // The same attestation again cannot push the fact back out.
    assert_abort(
        &redeem(&mut w, &a, &signature),
        "attestation",
        ATT_ENOT_MONOTONIC,
    );

    // Upgrading the level in transit breaks the signature.
    let mut tampered = fresh_attestation(&mut w, &bob, LEVEL_BASIC);
    let signature = sign_attestation(&mut w, &tampered);
    tampered.level = LEVEL_ENHANCED;
    assert_abort(
        &redeem(&mut w, &tampered, &signature),
        "attestation",
        ATT_EBAD_SIGNATURE,
    );

    // So does retargeting it at a different subject.
    let mut retargeted = fresh_attestation(&mut w, &bob, LEVEL_BASIC);
    let signature = sign_attestation(&mut w, &retargeted);
    retargeted.subject = *w.carol.address();
    assert_abort(
        &redeem(&mut w, &retargeted, &signature),
        "attestation",
        ATT_EBAD_SIGNATURE,
    );

    // A key that is not the registered issuer's cannot sign for it.
    let b = fresh_attestation(&mut w, &bob, LEVEL_BASIC);
    let chain = chain_id(&mut w.h);
    let (forger, _) = ed25519_key(99);
    let forged = forger
        .sign_arbitrary_message(&attestation_message(chain, w.source, &b))
        .to_bytes();
    assert_abort(
        &redeem(&mut w, &b, &forged),
        "attestation",
        ATT_EBAD_SIGNATURE,
    );
    assert!(!w.verified(&bob));
}

#[test]
fn test_redeem_rejects_stale_epoch() {
    let mut w = World::new();
    let alice = w.alice.clone();
    // Signed under epoch 0, then the issuer is bumped before it is relayed.
    let a = fresh_attestation(&mut w, &alice, LEVEL_BASIC);
    let signature = sign_attestation(&mut w, &a);
    let admin = w.admin.clone();
    let source = w.source;
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation::bump_issuer_epoch",
        vec![arg(&source), arg(&ISSUER_ID),]
    ));
    assert_abort(
        &redeem(&mut w, &a, &signature),
        "attestation",
        ATT_ESTALE_EPOCH,
    );

    // Signing for an epoch the issuer has not entered is refused too.
    let mut future = fresh_attestation(&mut w, &alice, LEVEL_BASIC);
    future.issuer_epoch = 5;
    let signature = sign_attestation(&mut w, &future);
    assert_abort(
        &redeem(&mut w, &future, &signature),
        "attestation",
        ATT_ESTALE_EPOCH,
    );

    // Under the current epoch it lands.
    let mut current = fresh_attestation(&mut w, &alice, LEVEL_BASIC);
    current.issuer_epoch = 1;
    let signature = sign_attestation(&mut w, &current);
    assert_success!(redeem(&mut w, &current, &signature));
    assert!(w.verified(&alice));
}

#[test]
fn test_relay_stops_when_issuer_is_removed() {
    let mut w = World::new();
    let alice = w.alice.clone();
    // Signed while the issuer was in good standing...
    let a = fresh_attestation(&mut w, &alice, LEVEL_BASIC);
    let signature = sign_attestation(&mut w, &a);
    let admin = w.admin.clone();
    let source = w.source;
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation::remove_issuers",
        vec![arg(&source), arg(&vec![*w.issuer.address()]),]
    ));
    // ...but relayed after it was removed. Removing an issuer must stop both of its write paths,
    // not only the one that needs its account to sign a transaction.
    assert_abort(
        &redeem(&mut w, &a, &signature),
        "attestation",
        ATT_ENOT_ISSUER,
    );
    assert_abort(
        &w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR),
        "attestation",
        ATT_ENOT_ISSUER,
    );
    assert!(!w.verified(&alice));
}

#[test]
fn test_nullifier_binds_one_identity_to_one_subject() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    let mut a = fresh_attestation(&mut w, &alice, LEVEL_BASIC);
    a.nullifier = vec![0x22; 32];
    let signature = sign_attestation(&mut w, &a);
    assert_success!(redeem(&mut w, &a, &signature));

    // The same real-world identity cannot also verify a second address.
    let mut b = fresh_attestation(&mut w, &bob, LEVEL_BASIC);
    b.nullifier = vec![0x22; 32];
    let signature = sign_attestation(&mut w, &b);
    assert_abort(
        &redeem(&mut w, &b, &signature),
        "attestation",
        ATT_ENULLIFIER_BOUND,
    );
    assert!(!w.verified(&bob));
}

// ══════════════════════════════════════════════════════════════
// Denial precedence and pause
// ══════════════════════════════════════════════════════════════

#[test]
fn test_denial_beats_a_valid_fact_and_only_remover_undoes_it() {
    let mut w = World::new();
    let alice = w.alice.clone();
    assert_success!(w.issue(&[&alice], vec![LEVEL_ENHANCED], ONE_YEAR));
    assert!(w.verified(&alice));

    let sentinel = w.sentinel.clone();
    assert_success!(w.deny(&sentinel, &alice));
    let source = w.source;
    assert!(!w.verified(&alice));
    assert!(source_view::<bool>(
        &mut w.h,
        "is_denied",
        source,
        *alice.address()
    ));
    assert_eq!(
        source_view::<u16>(&mut w.h, "deny_reason", source, *alice.address()),
        42
    );
    assert_eq!(
        source_view::<u8>(&mut w.h, "state_of", source, *alice.address()),
        STATE_REVOKED
    );

    // No positive write path can overwrite a denial.
    assert_abort(
        &w.issue(&[&alice], vec![LEVEL_ENHANCED], ONE_YEAR),
        "attestation",
        ATT_ESUBJECT_DENIED,
    );
    // Signed after the existing fact, so it is not refused for being older.
    advance(&mut w.h, 1);
    let a = fresh_attestation(&mut w, &alice, LEVEL_ENHANCED);
    let signature = sign_attestation(&mut w, &a);
    assert_abort(
        &redeem(&mut w, &a, &signature),
        "attestation",
        ATT_ESUBJECT_DENIED,
    );

    // The sentinel cannot undo its own work, and neither can the admin.
    assert_abort(
        &w.undeny(&sentinel, &alice),
        "attestation",
        ATT_ENOT_REMOVER,
    );
    let admin = w.admin.clone();
    assert_abort(&w.undeny(&admin, &alice), "attestation", ATT_ENOT_REMOVER);

    // The remover can, and the underlying fact is intact.
    let remover = w.remover.clone();
    assert_success!(w.undeny(&remover, &alice));
    assert!(w.verified(&alice));
    assert_eq!(
        source_view::<u8>(&mut w.h, "level_of", source, *alice.address()),
        LEVEL_ENHANCED
    );
}

#[test]
fn test_remover_cannot_deny_and_denial_can_be_scheduled() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    assert_success!(w.issue(&[&alice, &bob], vec![LEVEL_BASIC, LEVEL_BASIC], ONE_YEAR));
    let remover = w.remover.clone();
    assert_abort(&w.deny(&remover, &alice), "attestation", ATT_ENOT_SENTINEL);

    // A denial announced for an hour from now does not bite yet.
    let sentinel = w.sentinel.clone();
    let source = w.source;
    let at = now(&mut w.h) + 3600;
    assert_success!(run(&mut w.h, &sentinel, "0x1::attestation::deny", vec![
        arg(&source),
        arg(bob.address()),
        arg(&1u16),
        arg(&at),
    ]));
    assert!(w.verified(&bob));
    advance(&mut w.h, 3600);
    assert!(!w.verified(&bob));
    assert!(w.verified(&alice));

    // Batch denial is immediate.
    assert_success!(run(
        &mut w.h,
        &sentinel,
        "0x1::attestation::deny_batch",
        vec![arg(&source), arg(&vec![*alice.address()]), arg(&2u16),]
    ));
    assert!(!w.verified(&alice));
}

#[test]
fn test_pause_blocks_writes_not_reads() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    let source = w.source;

    // Only a guardian may pause.
    let issuer = w.issuer.clone();
    assert_abort(
        &run(&mut w.h, &issuer, "0x1::attestation::pause", vec![arg(
            &source,
        )]),
        "attestation",
        ATT_ENOT_GUARDIAN,
    );
    let guardian = w.guardian.clone();
    assert_success!(run(&mut w.h, &guardian, "0x1::attestation::pause", vec![
        arg(&source)
    ]));
    assert!(view::<bool>(&mut w.h, "0x1::attestation::is_paused", vec![
        arg(&source)
    ]));

    // The answer other protocols depend on does not flip.
    assert!(w.verified(&alice));
    // Writes stop, on both positive paths.
    assert_abort(
        &w.issue(&[&bob], vec![LEVEL_BASIC], ONE_YEAR),
        "attestation",
        ATT_EPAUSED,
    );
    let b = fresh_attestation(&mut w, &bob, LEVEL_BASIC);
    let signature = sign_attestation(&mut w, &b);
    assert_abort(&redeem(&mut w, &b, &signature), "attestation", ATT_EPAUSED);
    // Exclusion keeps working during an incident, which is when it matters most.
    let sentinel = w.sentinel.clone();
    assert_success!(w.deny(&sentinel, &alice));
    assert!(!w.verified(&alice));

    assert_success!(run(&mut w.h, &guardian, "0x1::attestation::unpause", vec![
        arg(&source)
    ]));
    assert_success!(w.issue(&[&bob], vec![LEVEL_BASIC], ONE_YEAR));
    assert!(w.verified(&bob));
}

#[test]
fn test_attributes_round_trip() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    let issuer = w.issuer.clone();
    let source = w.source;
    assert_success!(run(
        &mut w.h,
        &issuer,
        "0x1::attestation::set_attribute",
        vec![
            arg(&source),
            arg(alice.address()),
            arg(&ATTR_COUNTRY),
            arg(&COUNTRY_PT.to_vec()),
        ]
    ));
    let value: Vec<u8> = view(&mut w.h, "0x1::attestation::attribute_of", vec![
        arg(&source),
        arg(alice.address()),
        arg(&ATTR_COUNTRY),
    ]);
    assert_eq!(value, COUNTRY_PT.to_vec());
    let record: Record = source_view(&mut w.h, "record_of", source, *alice.address());
    assert_eq!(record.attrs, vec![(ATTR_COUNTRY, COUNTRY_PT.to_vec())]);
    // Attributes need a record to hang off.
    let status = run(&mut w.h, &issuer, "0x1::attestation::set_attribute", vec![
        arg(&source),
        arg(bob.address()),
        arg(&ATTR_COUNTRY),
        arg(&COUNTRY_PT.to_vec()),
    ]);
    assert_abort(&status, "attestation", ATT_ERECORD_NOT_FOUND);

    assert_success!(run(
        &mut w.h,
        &issuer,
        "0x1::attestation::remove_attribute",
        vec![arg(&source), arg(alice.address()), arg(&ATTR_COUNTRY),]
    ));
    let value: Vec<u8> = view(&mut w.h, "0x1::attestation::attribute_of", vec![
        arg(&source),
        arg(alice.address()),
        arg(&ATTR_COUNTRY),
    ]);
    assert!(value.is_empty());
}

// ══════════════════════════════════════════════════════════════
// Policies
// ══════════════════════════════════════════════════════════════

#[test]
fn test_new_policy_denies_everything() {
    let mut w = World::new();
    let alice = w.alice.clone();
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    let admin = w.admin.clone();
    let policy = create_policy(&mut w.h, &admin, vec![]);
    assert_eq!(
        decision(&mut w.h, policy, &alice, 1),
        (DECISION_DENY, REASON_EMPTY_BODY)
    );
}

#[test]
fn test_policy_staged_activation_is_timed_and_permissionless() {
    let mut w = World::new();
    let (alice, bob, carol) = (w.alice.clone(), w.bob.clone(), w.carol.clone());
    assert_success!(w.issue(&[&alice, &bob], vec![LEVEL_ENHANCED, LEVEL_BASIC], ONE_YEAR));
    let admin = w.admin.clone();
    let policy = create_policy(&mut w.h, &admin, vec![]);

    let effective_at = now(&mut w.h) + 600;
    let body = BodySpec::any(w.source, LEVEL_ENHANCED);
    assert_success!(stage_body(&mut w.h, &admin, policy, &body, effective_at));
    assert!(view::<bool>(
        &mut w.h,
        "0x1::attestation_policy::has_pending",
        vec![arg(&policy)]
    ));
    assert_eq!(
        view::<u64>(
            &mut w.h,
            "0x1::attestation_policy::pending_effective_at",
            vec![arg(&policy)]
        ),
        effective_at
    );

    // A staged body has no effect before its time, and cannot be forced live early.
    assert_eq!(reason(&mut w.h, policy, &alice), REASON_EMPTY_BODY);
    let relayer = w.relayer.clone();
    assert_abort(
        &activate(&mut w.h, &relayer, policy),
        "attestation_policy",
        POL_ENOT_EFFECTIVE,
    );

    // Once its time arrives anyone may push it live, so the business need not be online.
    advance(&mut w.h, 600);
    assert_success!(activate(&mut w.h, &relayer, policy));
    assert!(!view::<bool>(
        &mut w.h,
        "0x1::attestation_policy::has_pending",
        vec![arg(&policy)]
    ));
    assert_eq!(
        decision(&mut w.h, policy, &alice, 1),
        (DECISION_ALLOW, REASON_OK)
    );
    assert_eq!(reason(&mut w.h, policy, &bob), REASON_NO_QUALIFYING);
    assert_eq!(reason(&mut w.h, policy, &carol), REASON_NO_QUALIFYING);

    // simulate returns one decision per subject, in order.
    let decisions: Vec<u8> = view(&mut w.h, "0x1::attestation_policy::simulate", vec![
        arg(&policy),
        arg(&vec![*alice.address(), *bob.address(), *carol.address()]),
        arg(&ACTION_TRANSFER),
        arg(&1u64),
    ]);
    assert_eq!(decisions, vec![
        DECISION_ALLOW,
        DECISION_DENY,
        DECISION_DENY
    ]);
}

#[test]
fn test_policy_require_all_and_levels() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    assert_success!(w.issue(&[&alice, &bob], vec![LEVEL_ENHANCED, LEVEL_BASIC], ONE_YEAR));
    // A second source, run by someone else, that only vouches for Alice.
    let other_admin = w.carol.clone();
    let other = create_source(
        &mut w.h,
        &other_admin,
        vec![*other_admin.address()],
        vec![*other_admin.address()],
        vec![],
        vec![],
        vec![],
    );
    let (_, key) = ed25519_key(12);
    assert_success!(run(
        &mut w.h,
        &other_admin,
        "0x1::attestation::register_issuer",
        vec![arg(&other), arg(other_admin.address()), arg(&key),]
    ));
    let expiry = now(&mut w.h) + ONE_YEAR;
    assert_success!(run(
        &mut w.h,
        &other_admin,
        "0x1::attestation::issue_batch",
        vec![
            arg(&other),
            arg(&vec![*alice.address(), *bob.address()]),
            arg(&vec![LEVEL_BASIC, LEVEL_BASIC]),
            arg(&vec![expiry, expiry]),
            arg(&0u16),
        ]
    ));

    let admin = w.admin.clone();
    let policy = create_policy(&mut w.h, &admin, vec![]);
    apply_body(&mut w.h, &admin, policy, &BodySpec {
        require_any: vec![],
        require_all: vec![(w.source, LEVEL_ENHANCED), (other, LEVEL_BASIC)],
        deny_any: vec![],
        chain_deny: vec![],
    });
    assert_eq!(
        decision(&mut w.h, policy, &alice, 1),
        (DECISION_ALLOW, REASON_OK)
    );
    assert_eq!(reason(&mut w.h, policy, &bob), REASON_LEVEL_TOO_LOW);
    let carol = w.carol.clone();
    assert_eq!(reason(&mut w.h, policy, &carol), REASON_MISSING_REQUIRED);
}

#[test]
fn test_policy_denial_sources_outrank_vouching() {
    let mut w = World::new();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    assert_success!(w.issue(&[&alice, &bob], vec![LEVEL_BASIC, LEVEL_BASIC], ONE_YEAR));
    // A sanctions source and a chain-wide denial source, both run by the relayer account.
    let operator = w.relayer.clone();
    let make_deny_source = |h: &mut MoveHarness| {
        create_source(
            h,
            &operator,
            vec![*operator.address()],
            vec![],
            vec![*operator.address()],
            vec![],
            vec![],
        )
    };
    let sanctions = make_deny_source(&mut w.h);
    let chain = make_deny_source(&mut w.h);

    let admin = w.admin.clone();
    let policy = create_policy(&mut w.h, &admin, vec![]);
    let t = now(&mut w.h);
    // Only one chain-wide denial source may be named.
    let mut body = BodySpec::any(w.source, LEVEL_BASIC);
    body.chain_deny = vec![chain, sanctions];
    assert_abort(
        &stage_body(&mut w.h, &admin, policy, &body, t),
        "attestation_policy",
        POL_ETOO_MANY_CHAIN_DENY,
    );
    body.chain_deny = vec![chain];
    body.deny_any = vec![sanctions];
    apply_body(&mut w.h, &admin, policy, &body);
    assert_eq!(
        decision(&mut w.h, policy, &alice, 1),
        (DECISION_ALLOW, REASON_OK)
    );

    let deny_in = |h: &mut MoveHarness, source: AccountAddress, subject: &Account| {
        let at = now(h);
        assert_success!(run(h, &operator, "0x1::attestation::deny", vec![
            arg(&source),
            arg(subject.address()),
            arg(&1u16),
            arg(&at),
        ]));
    };
    deny_in(&mut w.h, sanctions, &alice);
    assert_eq!(
        decision(&mut w.h, policy, &alice, 1),
        (DECISION_DENY, REASON_SOURCE_DENIED)
    );
    // The chain-wide source is consulted first.
    deny_in(&mut w.h, chain, &alice);
    deny_in(&mut w.h, chain, &bob);
    assert_eq!(reason(&mut w.h, policy, &alice), REASON_CHAIN_DENIED);
    assert_eq!(reason(&mut w.h, policy, &bob), REASON_CHAIN_DENIED);
}

#[test]
fn test_policy_attribute_rules() {
    let mut w = World::new();
    let (alice, bob, carol) = (w.alice.clone(), w.bob.clone(), w.carol.clone());
    assert_success!(w.issue(
        &[&alice, &bob, &carol],
        vec![LEVEL_BASIC, LEVEL_BASIC, LEVEL_BASIC],
        ONE_YEAR
    ));
    let issuer = w.issuer.clone();
    let source = w.source;
    for (subject, country) in [(&alice, COUNTRY_PT), (&bob, COUNTRY_BR)] {
        assert_success!(run(
            &mut w.h,
            &issuer,
            "0x1::attestation::set_attribute",
            vec![
                arg(&source),
                arg(subject.address()),
                arg(&ATTR_COUNTRY),
                arg(&country.to_vec()),
            ]
        ));
    }
    let admin = w.admin.clone();
    let policy = create_policy(&mut w.h, &admin, vec![]);
    let t = now(&mut w.h);
    assert_success!(stage_body(
        &mut w.h,
        &admin,
        policy,
        &BodySpec::any(source, LEVEL_BASIC),
        t
    ));
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation_policy::stage_attr_rules",
        vec![
            arg(&policy),
            arg(&vec![source]),
            arg(&vec![ATTR_COUNTRY]),
            arg(&vec![OP_IN]),
            arg(&vec![vec![COUNTRY_PT.to_vec()]]),
        ]
    ));
    assert_success!(activate(&mut w.h, &admin, policy));

    assert_eq!(
        decision(&mut w.h, policy, &alice, 1),
        (DECISION_ALLOW, REASON_OK)
    );
    assert_eq!(reason(&mut w.h, policy, &bob), REASON_ATTR_FAILED);
    // An unset attribute never satisfies a positive requirement.
    assert_eq!(reason(&mut w.h, policy, &carol), REASON_ATTR_FAILED);

    // A malformed rule is rejected at staging time: OP_GTE takes exactly one value.
    let status = run(
        &mut w.h,
        &admin,
        "0x1::attestation_policy::stage_attr_rules",
        vec![
            arg(&policy),
            arg(&vec![source]),
            arg(&vec![ATTR_COUNTRY]),
            arg(&vec![OP_GTE]),
            arg(&vec![vec![COUNTRY_PT.to_vec(), COUNTRY_BR.to_vec()]]),
        ],
    );
    assert_abort(&status, "attestation_policy", POL_EBAD_RULE);
}

#[test]
fn test_paused_policy_denies_loudly() {
    let mut w = World::new();
    let alice = w.alice.clone();
    assert_success!(w.issue(&[&alice], vec![LEVEL_BASIC], ONE_YEAR));
    let admin = w.admin.clone();
    let guardian = w.guardian.clone();
    let policy = create_policy(&mut w.h, &admin, vec![*guardian.address()]);
    apply_body(
        &mut w.h,
        &admin,
        policy,
        &BodySpec::any(w.source, LEVEL_BASIC),
    );
    assert_success!(run(
        &mut w.h,
        &guardian,
        "0x1::attestation_policy::pause",
        vec![arg(&policy)]
    ));
    assert_eq!(
        decision(&mut w.h, policy, &alice, 1),
        (DECISION_DENY, REASON_POLICY_PAUSED)
    );
    assert_success!(run(
        &mut w.h,
        &guardian,
        "0x1::attestation_policy::unpause",
        vec![arg(&policy)]
    ));
    assert_eq!(
        decision(&mut w.h, policy, &alice, 1),
        (DECISION_ALLOW, REASON_OK)
    );
}

// ══════════════════════════════════════════════════════════════
// A consumer contract gated on a policy
// ══════════════════════════════════════════════════════════════

#[test]
fn test_gated_entry_function_allows_and_denies() {
    let (mut w, policy, _) = step_up_world();
    let (alice, carol) = (w.alice.clone(), w.carol.clone());

    assert_success!(gated_transfer(&mut w.h, &alice, policy, 10));
    assert_eq!(transfer_count(&mut w.h, &alice), 1);

    // An unverified subject is stopped inside the business's own entry function.
    assert_abort(
        &gated_transfer(&mut w.h, &carol, policy, 10),
        "attestation_policy",
        POL_EDENIED,
    );
    assert_eq!(transfer_count(&mut w.h, &carol), 0);

    // A denial landing after onboarding stops the next transaction.
    let sentinel = w.sentinel.clone();
    assert_success!(w.deny(&sentinel, &alice));
    assert_abort(
        &gated_transfer(&mut w.h, &alice, policy, 10),
        "attestation_policy",
        POL_EDENIED,
    );
    assert_eq!(transfer_count(&mut w.h, &alice), 1);
}

#[test]
fn test_gated_entry_function_demands_step_up_over_threshold() {
    let (mut w, policy, _) = step_up_world();
    let alice = w.alice.clone();
    assert_eq!(
        decision(&mut w.h, policy, &alice, 1001),
        (DECISION_STEP_UP, REASON_AMOUNT_THRESHOLD)
    );
    // At the threshold is fine, above it is not.
    assert_success!(gated_transfer(&mut w.h, &alice, policy, 1000));
    assert_abort(
        &gated_transfer(&mut w.h, &alice, policy, 1001),
        "attestation_policy",
        POL_ESTEP_UP_REQUIRED,
    );
    // An allowed amount through the authorized entry point consumes nothing.
    assert_success!(gated_transfer_authorized(&mut w.h, &alice, policy, 10, &[]));
    assert_eq!(transfer_count(&mut w.h, &alice), 2);

    let counts: Vec<u64> = view(&mut w.h, "0x1::attestation_policy::simulate_counts", vec![
        arg(&policy),
        arg(&vec![*alice.address(), *w.carol.address()]),
        arg(&ACTION_TRANSFER),
        arg(&5000u64),
    ]);
    assert_eq!(counts, vec![0, 1, 1]);
}

#[test]
fn test_authorization_satisfies_step_up_once() {
    let (mut w, policy, authorizer) = step_up_world();
    let alice = w.alice.clone();
    let a = authorization_for(&mut w.h, policy, &alice, 0x01, 60);
    let blob = sign_authorization(&mut w.h, &authorizer, &a);

    assert_success!(gated_transfer_authorized(
        &mut w.h, &alice, policy, 5000, &blob
    ));
    assert_eq!(transfer_count(&mut w.h, &alice), 1);
    assert!(view::<bool>(
        &mut w.h,
        "0x1::attestation_authorization::is_nonce_used",
        vec![arg(&policy), arg(&a.nonce.to_vec())]
    ));

    // The nonce is burned: the same capability cannot be spent twice.
    assert_abort(
        &gated_transfer_authorized(&mut w.h, &alice, policy, 5000, &blob),
        "attestation_authorization",
        AUTH_ENONCE_USED,
    );
    assert_eq!(transfer_count(&mut w.h, &alice), 1);

    // Once it can no longer be replayed, anyone may release its storage.
    advance(&mut w.h, 61);
    let relayer = w.relayer.clone();
    assert_success!(run(
        &mut w.h,
        &relayer,
        "0x1::attestation_authorization::prune_nonces",
        vec![arg(&policy), arg(&vec![a.nonce.to_vec()])]
    ));
    assert!(!view::<bool>(
        &mut w.h,
        "0x1::attestation_authorization::is_nonce_used",
        vec![arg(&policy), arg(&a.nonce.to_vec())]
    ));
}

#[test]
fn test_authorization_rejections() {
    let (mut w, policy, authorizer) = step_up_world();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());

    // Expired.
    let a = authorization_for(&mut w.h, policy, &alice, 0x02, 60);
    let blob = sign_authorization(&mut w.h, &authorizer, &a);
    advance(&mut w.h, 60);
    assert_abort(
        &gated_transfer_authorized(&mut w.h, &alice, policy, 5000, &blob),
        "attestation_authorization",
        AUTH_EEXPIRED,
    );

    // Amount above the committed bucket ceiling (10^4).
    let a = authorization_for(&mut w.h, policy, &alice, 0x03, 60);
    let blob = sign_authorization(&mut w.h, &authorizer, &a);
    assert_abort(
        &gated_transfer_authorized(&mut w.h, &alice, policy, 10_001, &blob),
        "attestation_authorization",
        AUTH_EAMOUNT_OVER_BUCKET,
    );

    // A window longer than the policy's max TTL (300s) is refused even if validly signed.
    let a = authorization_for(&mut w.h, policy, &alice, 0x04, 301);
    let blob = sign_authorization(&mut w.h, &authorizer, &a);
    assert_abort(
        &gated_transfer_authorized(&mut w.h, &alice, policy, 5000, &blob),
        "attestation_authorization",
        AUTH_ETTL_TOO_LONG,
    );

    // Issued to Bob, spent by Alice.
    let a = authorization_for(&mut w.h, policy, &bob, 0x05, 60);
    let blob = sign_authorization(&mut w.h, &authorizer, &a);
    assert_abort(
        &gated_transfer_authorized(&mut w.h, &alice, policy, 5000, &blob),
        "attestation_authorization",
        AUTH_EBAD_SIGNATURE,
    );

    // Signed by a key the policy does not trust.
    let (stranger, _) = ed25519_key(77);
    let a = authorization_for(&mut w.h, policy, &alice, 0x06, 60);
    let blob = sign_authorization(&mut w.h, &stranger, &a);
    assert_abort(
        &gated_transfer_authorized(&mut w.h, &alice, policy, 5000, &blob),
        "attestation_authorization",
        AUTH_EBAD_SIGNATURE,
    );

    // An authorization never outranks a denial.
    let sentinel = w.sentinel.clone();
    assert_success!(w.deny(&sentinel, &alice));
    let a = authorization_for(&mut w.h, policy, &alice, 0x07, 60);
    let blob = sign_authorization(&mut w.h, &authorizer, &a);
    assert_abort(
        &gated_transfer_authorized(&mut w.h, &alice, policy, 5000, &blob),
        "attestation_policy",
        POL_EDENIED,
    );
    assert_eq!(transfer_count(&mut w.h, &alice), 0);
}

// ══════════════════════════════════════════════════════════════
// Write path 3: zkTLS enrollment
// ══════════════════════════════════════════════════════════════

#[test]
fn test_zktls_enroll_with_threshold_signatures() {
    let (mut w, attestors) = zktls_world();
    let alice = w.alice.clone();
    let claim = claim_for(*alice.address(), &TEMPLATE_ID, &[], "session-1");
    let signatures = vec![
        sign_claim(&attestors[0], &claim),
        sign_claim(&attestors[2], &claim),
    ];

    // The published digest and recovery views agree with the Rust signer.
    let digest: Vec<u8> = view(&mut w.h, "0x1::zktls::claim_digest", vec![arg(&claim)]);
    assert_eq!(digest, claim_digest(&claim).to_vec());
    let recovered: Vec<u8> = view(&mut w.h, "0x1::zktls::recover_attestor", vec![
        arg(&claim),
        arg(&signatures[0]),
    ]);
    assert_eq!(recovered, attestors[0].address);
    assert!(verify_claim(&mut w, &alice, &claim, signatures.clone(), 1));

    assert_success!(enroll(&mut w, &alice, &claim, signatures, 1, &[]));
    assert!(w.verified(&alice));
    let source = w.source;
    let record: Record = source_view(&mut w.h, "record_of", source, *alice.address());
    assert_eq!(record.level, ZK_LEVEL);
    assert_eq!(
        record.issuer_id, 0,
        "no issuer key is involved on this path"
    );
    assert_eq!(record.attestation_digest, keccak(&claim));
    assert_eq!(record.expires_at_secs, now(&mut w.h) + ZK_TTL);
}

#[test]
fn test_zktls_enroll_rejections() {
    let (mut w, attestors) = zktls_world();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    let claim = claim_for(*alice.address(), &TEMPLATE_ID, &[], "session-2");

    // One of two required signatures.
    let one = vec![sign_claim(&attestors[0], &claim)];
    assert!(!verify_claim(&mut w, &alice, &claim, one.clone(), 1));
    assert_abort(
        &enroll(&mut w, &alice, &claim, one, 1, &[]),
        "zktls",
        ZK_EBELOW_THRESHOLD,
    );

    // The same attestor twice does not count as two.
    let twice = vec![
        sign_claim(&attestors[0], &claim),
        sign_claim(&attestors[0], &claim),
    ];
    assert_abort(
        &enroll(&mut w, &alice, &claim, twice, 1, &[]),
        "zktls",
        ZK_EDUPLICATE_SIGNER,
    );

    // A signer outside the registered set.
    let outsider = attestor(40);
    let foreign = vec![
        sign_claim(&attestors[0], &claim),
        sign_claim(&outsider, &claim),
    ];
    assert_abort(
        &enroll(&mut w, &alice, &claim, foreign, 1, &[]),
        "zktls",
        ZK_EUNKNOWN_ATTESTOR,
    );

    // A valid claim about Alice is not a valid claim for Bob, whoever relays it.
    let signatures = vec![
        sign_claim(&attestors[0], &claim),
        sign_claim(&attestors[1], &claim),
    ];
    assert_abort(
        &enroll(&mut w, &bob, &claim, signatures.clone(), 1, &[]),
        "zktls",
        ZK_EMALFORMED_CLAIM,
    );
    assert!(!w.verified(&alice));
    assert!(!w.verified(&bob));
}

#[test]
fn test_zktls_revoked_template_stops_new_enrollment() {
    let (mut w, attestors) = zktls_world();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    let alice_claim = claim_for(*alice.address(), &TEMPLATE_ID, &[], "a");
    let signatures = vec![
        sign_claim(&attestors[0], &alice_claim),
        sign_claim(&attestors[1], &alice_claim),
    ];
    assert_success!(enroll(&mut w, &alice, &alice_claim, signatures, 1, &[]));

    let admin = w.admin.clone();
    let source = w.source;
    assert_success!(run(&mut w.h, &admin, "0x1::zktls::revoke_template", vec![
        arg(&source),
        arg(&TEMPLATE_ID.to_vec()),
    ]));
    let bob_claim = claim_for(*bob.address(), &TEMPLATE_ID, &[], "b");
    let signatures = vec![
        sign_claim(&attestors[0], &bob_claim),
        sign_claim(&attestors[1], &bob_claim),
    ];
    assert!(!verify_claim(
        &mut w,
        &bob,
        &bob_claim,
        signatures.clone(),
        1
    ));
    assert_abort(
        &enroll(&mut w, &bob, &bob_claim, signatures, 1, &[]),
        "zktls",
        ZK_ETEMPLATE_REVOKED,
    );
    // Facts already recorded are untouched: a broken template degrades enrollment only.
    assert!(w.verified(&alice));
    assert!(!w.verified(&bob));
}

#[test]
fn test_zktls_claim_is_single_use() {
    let (mut w, attestors) = zktls_world();
    let alice = w.alice.clone();
    let claim = claim_for(*alice.address(), &TEMPLATE_ID, &[], "session-3");
    let signatures = vec![
        sign_claim(&attestors[0], &claim),
        sign_claim(&attestors[1], &claim),
    ];
    assert_success!(enroll(&mut w, &alice, &claim, signatures.clone(), 1, &[]));

    // Replaying the same attested session, for example to refresh an expiry without a new TLS
    // session, is refused.
    assert!(!verify_claim(&mut w, &alice, &claim, signatures.clone(), 1));
    assert_abort(
        &enroll(&mut w, &alice, &claim, signatures, 1, &[]),
        "zktls",
        ZK_ECLAIM_CONSUMED,
    );

    // A fresh session is accepted.
    advance(&mut w.h, 10);
    let claim = claim_for(*alice.address(), &TEMPLATE_ID, &[], "session-4");
    let signatures = vec![
        sign_claim(&attestors[1], &claim),
        sign_claim(&attestors[2], &claim),
    ];
    assert_success!(enroll(&mut w, &alice, &claim, signatures, 1, &[]));
    assert!(w.verified(&alice));
}

#[test]
fn test_zktls_attestor_rotation_grace_window() {
    let (mut w, old_set) = zktls_world();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    let new_set = [attestor(4), attestor(5)];
    // Rotate to epoch 2, keeping epoch 1 alive for ten minutes.
    set_attestors(&mut w, &new_set.iter().collect::<Vec<_>>(), 2, 600);
    let source = w.source;
    assert_eq!(
        view::<u64>(&mut w.h, "0x1::zktls::current_epoch", vec![arg(&source)]),
        2
    );

    // A claim signed by the old set just before the rotation still lands inside the window.
    let claim = claim_for(*alice.address(), &TEMPLATE_ID, &[], "late");
    let signatures = vec![
        sign_claim(&old_set[0], &claim),
        sign_claim(&old_set[1], &claim),
    ];
    assert_success!(enroll(&mut w, &alice, &claim, signatures, 1, &[]));

    // After the window the retired set is refused, while the new one works.
    advance(&mut w.h, 600);
    let claim = claim_for(*bob.address(), &TEMPLATE_ID, &[], "stale");
    let signatures = vec![
        sign_claim(&old_set[0], &claim),
        sign_claim(&old_set[1], &claim),
    ];
    assert_abort(
        &enroll(&mut w, &bob, &claim, signatures, 1, &[]),
        "zktls",
        ZK_ERETIRED_ATTESTOR_EPOCH,
    );
    let signatures = vec![
        sign_claim(&new_set[0], &claim),
        sign_claim(&new_set[1], &claim),
    ];
    assert_success!(enroll(&mut w, &bob, &claim, signatures, 2, &[]));
    assert!(w.verified(&bob));

    // A second rotation retires epoch 2's predecessor at once, with or without grace.
    set_attestors(&mut w, &old_set.iter().collect::<Vec<_>>(), 2, 0);
    let carol = w.carol.clone();
    let claim = claim_for(*carol.address(), &TEMPLATE_ID, &[], "rotated");
    let signatures = vec![
        sign_claim(&new_set[0], &claim),
        sign_claim(&new_set[1], &claim),
    ];
    assert_abort(
        &enroll(&mut w, &carol, &claim, signatures, 2, &[]),
        "zktls",
        ZK_ERETIRED_ATTESTOR_EPOCH,
    );
}

#[test]
fn test_zktls_nullifier_must_be_attested() {
    let (mut w, attestors) = zktls_world();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    let nullifier = [0x33u8; 32];

    // A nullifier the attestors did not sign is just a value the user picked.
    let unsigned = claim_for(*alice.address(), &TEMPLATE_ID, &[], "n1");
    let signatures = vec![
        sign_claim(&attestors[0], &unsigned),
        sign_claim(&attestors[1], &unsigned),
    ];
    assert_abort(
        &enroll(&mut w, &alice, &unsigned, signatures, 1, &nullifier),
        "zktls",
        ZK_EMALFORMED_CLAIM,
    );

    // Carried inside the attested claim, it binds.
    let signed = claim_for(*alice.address(), &TEMPLATE_ID, &nullifier, "n2");
    let signatures = vec![
        sign_claim(&attestors[0], &signed),
        sign_claim(&attestors[1], &signed),
    ];
    assert_success!(enroll(&mut w, &alice, &signed, signatures, 1, &nullifier));

    // The same real-world identity enrolling a second address is refused by the source.
    let second = claim_for(*bob.address(), &TEMPLATE_ID, &nullifier, "n3");
    let signatures = vec![
        sign_claim(&attestors[0], &second),
        sign_claim(&attestors[1], &second),
    ];
    assert_abort(
        &enroll(&mut w, &bob, &second, signatures, 1, &nullifier),
        "attestation",
        ATT_ENULLIFIER_BOUND,
    );
    assert!(w.verified(&alice));
    assert!(!w.verified(&bob));
}

#[test]
fn test_zktls_cohort_can_be_killed_in_one_write() {
    let (mut w, attestors) = zktls_world();
    let (alice, bob) = (w.alice.clone(), w.bob.clone());
    assert_success!(w.issue(&[&bob], vec![LEVEL_BASIC], ONE_YEAR));
    let claim = claim_for(*alice.address(), &TEMPLATE_ID, &[], "cohort");
    let signatures = vec![
        sign_claim(&attestors[0], &claim),
        sign_claim(&attestors[1], &claim),
    ];
    assert_success!(enroll(&mut w, &alice, &claim, signatures, 1, &[]));
    assert!(w.verified(&alice));

    // Issuer id 0 is the zkTLS cohort. Bumping it is the remedy for a compromised attestor set,
    // and it leaves facts written by real issuers alone.
    let admin = w.admin.clone();
    let source = w.source;
    assert_success!(run(
        &mut w.h,
        &admin,
        "0x1::attestation::bump_issuer_epoch",
        vec![arg(&source), arg(&0u16),]
    ));
    assert!(!w.verified(&alice));
    assert!(w.verified(&bob));
}

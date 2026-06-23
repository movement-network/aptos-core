// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! End-to-end VM tests for the timelock module's script-resolution model: a creator proposes
//! `execution_hash = sha3_256(script)`, time advances past the delay, then an authorized executor
//! submits the matching `Script` whose first call is `timelock::resolve`. If `resolve` aborts, the
//! whole script reverts atomically (Keep + MoveAbort).

use crate::{assert_success, tests::common, MoveHarness};
use aptos_crypto::HashValue;
use aptos_language_e2e_tests::account::Account;
use aptos_types::{
    account_address::{create_resource_address, AccountAddress},
    transaction::{
        EntryFunction, ExecutionStatus, MultisigTransactionPayload, TransactionArgument,
        TransactionStatus,
    },
};
use move_core_types::{
    ident_str,
    language_storage::{ModuleId, CORE_CODE_ADDRESS},
};
use once_cell::sync::Lazy;
use sha3::{Digest, Keccak256};
use std::collections::BTreeMap;

// ──────────────────────────────────────────────────────────────
// Script package fixtures (compiled once, shared across tests)
// ──────────────────────────────────────────────────────────────

const SCRIPT_NAMES: &[&str] = &[
    "noop",
    "update_delay",
    "add_creator",
    "remove_creator",
    "add_executor",
    "remove_executor",
    "multisig_propose",
];

static SCRIPTS: Lazy<BTreeMap<String, Vec<u8>>> =
    Lazy::new(|| common::build_scripts("timelock.data", SCRIPT_NAMES.to_vec()));

fn script(name: &str) -> Vec<u8> {
    SCRIPTS
        .get(name)
        .cloned()
        .unwrap_or_else(|| panic!("script `{name}` not found in timelock.data fixtures"))
}

/// `execution_hash` value the timelock module expects: SHA3-256 of the script's bytecode.
/// This matches the VM's `transaction_context::get_script_hash()` value at execution time.
fn execution_hash_of(script_code: &[u8]) -> Vec<u8> {
    HashValue::sha3_256_of(script_code).to_vec()
}

/// `proposal_hash = keccak256(execution_hash || salt)`. Mirrors `timelock::get_proposal_hash`.
fn proposal_hash_of(execution_hash: &[u8], salt: &[u8]) -> Vec<u8> {
    let mut hasher = Keccak256::new();
    hasher.update(execution_hash);
    hasher.update(salt);
    hasher.finalize().to_vec()
}

fn salt32(label: &[u8]) -> Vec<u8> {
    let mut hasher = Keccak256::new();
    hasher.update(label);
    hasher.finalize().to_vec()
}

// ──────────────────────────────────────────────────────────────
// Address derivation helpers
// ──────────────────────────────────────────────────────────────

fn timelock_account_address(creator: AccountAddress, seq: u64) -> AccountAddress {
    const DOMAIN_SEPARATOR: &[u8] = b"aptos_framework::timelock";
    let mut seed = DOMAIN_SEPARATOR.to_vec();
    seed.extend(bcs::to_bytes(&seq).unwrap());
    create_resource_address(creator, &seed)
}

fn multisig_account_address(creator: AccountAddress, seq: u64) -> AccountAddress {
    aptos_types::account_address::create_multisig_account_address(creator, seq)
}

// ──────────────────────────────────────────────────────────────
// Action helpers
// ──────────────────────────────────────────────────────────────

const DELAY: u64 = 3700;
/// Must match `timelock::MIN_NUM_SECONDS_EXECUTE`. Used by the delay-boundary test.
const MIN_DELAY_SECS: u64 = 3600;

/// Convenience wrapper that calls `0x1::timelock::create` with the deployer included as a
/// creator. The on-chain `create` no longer auto-adds the deployer; tests that want the
/// deployer to also be a creator (which is most of them) rely on this helper to splice it in.
fn create_timelock(
    h: &mut MoveHarness,
    deployer: &Account,
    additional_creators: Vec<AccountAddress>,
    executors: Vec<AccountAddress>,
    delay: u64,
) -> TransactionStatus {
    create_timelock_with_cancelers(h, deployer, additional_creators, executors, vec![], delay)
}

fn create_timelock_with_cancelers(
    h: &mut MoveHarness,
    deployer: &Account,
    additional_creators: Vec<AccountAddress>,
    executors: Vec<AccountAddress>,
    cancelers: Vec<AccountAddress>,
    delay: u64,
) -> TransactionStatus {
    let mut creators = vec![*deployer.address()];
    creators.extend(additional_creators);
    h.run_entry_function(
        deployer,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&creators).unwrap(),
            bcs::to_bytes(&executors).unwrap(),
            bcs::to_bytes(&cancelers).unwrap(),
            bcs::to_bytes(&delay).unwrap(),
        ],
    )
}

fn propose(
    h: &mut MoveHarness,
    creator: &Account,
    timelock_addr: AccountAddress,
    execution_hash: &[u8],
    delay: u64,
    salt: &[u8],
) -> TransactionStatus {
    h.run_entry_function(
        creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&execution_hash.to_vec()).unwrap(),
            bcs::to_bytes(&delay).unwrap(),
            bcs::to_bytes(&salt.to_vec()).unwrap(),
            // Optional off-chain script_path pointer; empty in these tests.
            bcs::to_bytes(&Vec::<u8>::new()).unwrap(),
        ],
    )
}

fn cancel(
    h: &mut MoveHarness,
    actor: &Account,
    timelock_addr: AccountAddress,
    proposal_hash: &[u8],
) -> TransactionStatus {
    h.run_entry_function(
        actor,
        str::parse("0x1::timelock::cancel_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&proposal_hash.to_vec()).unwrap(),
        ],
    )
}

/// Pre-authorize resolution via the `approve_resolution` entry function. This mirrors how a
/// multisig account would authorize (it dispatches an entry function, not a `Script`).
fn approve_resolution(
    h: &mut MoveHarness,
    executor: &Account,
    timelock_addr: AccountAddress,
    proposal_hash: &[u8],
) -> TransactionStatus {
    h.run_entry_function(
        executor,
        str::parse("0x1::timelock::approve_resolution").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&proposal_hash.to_vec()).unwrap(),
        ],
    )
}

fn run_resolution_script(
    h: &mut MoveHarness,
    executor: &Account,
    script_code: Vec<u8>,
    extra_args: Vec<TransactionArgument>,
    timelock_addr: AccountAddress,
    proposal_hash: &[u8],
) -> TransactionStatus {
    let mut args = vec![
        TransactionArgument::Address(timelock_addr),
        TransactionArgument::U8Vector(proposal_hash.to_vec()),
    ];
    args.extend(extra_args);
    let txn = h.create_script(executor, script_code, vec![], args);
    h.run(txn)
}

fn fast_forward_block(h: &mut MoveHarness, secs: u64) {
    h.fast_forward(secs);
    h.executor.new_block();
}

// ──────────────────────────────────────────────────────────────
// View helpers
// ──────────────────────────────────────────────────────────────

fn can_be_executed(h: &mut MoveHarness, timelock_addr: AccountAddress, hash: &[u8]) -> bool {
    let result = h.execute_view_function(
        str::parse("0x1::timelock::can_be_executed").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&hash.to_vec()).unwrap(),
        ],
    );
    bcs::from_bytes::<bool>(&result.values.unwrap()[0]).unwrap()
}

fn member_view(
    h: &mut MoveHarness,
    function: &str,
    addr: AccountAddress,
    timelock_addr: AccountAddress,
) -> bool {
    let result = h.execute_view_function(
        str::parse(function).unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&addr).unwrap(),
            bcs::to_bytes(&timelock_addr).unwrap(),
        ],
    );
    bcs::from_bytes::<bool>(&result.values.unwrap()[0]).unwrap()
}

fn is_creator_view(h: &mut MoveHarness, addr: AccountAddress, timelock_addr: AccountAddress) -> bool {
    member_view(h, "0x1::timelock::is_creator", addr, timelock_addr)
}

fn is_executor_view(h: &mut MoveHarness, addr: AccountAddress, timelock_addr: AccountAddress) -> bool {
    member_view(h, "0x1::timelock::is_executor", addr, timelock_addr)
}

fn min_num_seconds_execute(h: &mut MoveHarness, timelock_addr: AccountAddress) -> u64 {
    let result = h.execute_view_function(
        str::parse("0x1::timelock::min_num_seconds_execute").unwrap(),
        vec![],
        vec![bcs::to_bytes(&timelock_addr).unwrap()],
    );
    bcs::from_bytes::<u64>(&result.values.unwrap()[0]).unwrap()
}

// ──────────────────────────────────────────────────────────────
// Status assertion helpers
// ──────────────────────────────────────────────────────────────

fn assert_aborts_with(status: &TransactionStatus, expected_code: u64) {
    match status {
        TransactionStatus::Keep(ExecutionStatus::MoveAbort { code, .. }) => assert_eq!(
            *code, expected_code,
            "expected abort code {:#x}, got {:#x}",
            expected_code, code
        ),
        other => panic!("expected MoveAbort({:#x}), got {:?}", expected_code, other),
    }
}


// Abort codes (from timelock.move):
//   ETIMELOCK_NOT_EXPIRED = 8        → error::invalid_state         → 0x30008
//   ETRANSACTION_ALREADY_EXECUTED= 9 → error::invalid_state         → 0x30009
//   ENOT_EXECUTOR = 5                → error::permission_denied     → 0x50005
//   EACCOUNT_NOT_TIMELOCK = 3        → error::invalid_state         → 0x30003
//   ETRANSACTION_NOT_FOUND = 7       → error::not_found             → 0x60007
//   EEXECUTION_HASH_NOT_MATCHING= 17 → error::invalid_argument      → 0x10011
//   EWOULD_REMOVE_ALL_CREATORS = 12  → error::invalid_state         → 0x3000C
//   ENOT_CREATOR_OR_CANCELER = 13    → error::permission_denied     → 0x5000D
//   ENUMBER_SECONDS_TOO_SMALL = 14   → error::invalid_argument      → 0x1000E
//   EINVALID_BYTES_LENGTH = 16       → error::invalid_argument      → 0x10010
const ABORT_TIMELOCK_NOT_EXPIRED: u64 = 0x30008;
const ABORT_ALREADY_EXECUTED: u64 = 0x30009;
const ABORT_NOT_EXECUTOR: u64 = 0x50005;
const ABORT_ACCOUNT_NOT_TIMELOCK: u64 = 0x30003;
const ABORT_TRANSACTION_NOT_FOUND: u64 = 0x60007;
const ABORT_EXECUTION_HASH_MISMATCH: u64 = 0x10011;
const ABORT_WOULD_REMOVE_ALL_CREATORS: u64 = 0x3000C;
const ABORT_NOT_CREATOR_OR_CANCELER: u64 = 0x5000D;
const ABORT_NUMBER_SECONDS_TOO_SMALL: u64 = 0x1000E;
const ABORT_INVALID_BYTES_LENGTH: u64 = 0x10010;
// ENOT_CREATOR = 4               → error::permission_denied     → 0x50004
// EDUPLICATE_TRANSACTION = 11    → error::already_exists        → 0x8000B
const ABORT_NOT_CREATOR: u64 = 0x50004;
const ABORT_DUPLICATE_TRANSACTION: u64 = 0x8000B;

/// The Lazy `SCRIPTS` initializer compiles seven Move script packages on first invocation,
/// which recurses deeply enough to overflow Rust's default 2 MB test thread stack. Each
/// `#[test]` body runs inside this 32 MB-stack thread to avoid that.
fn run_in_big_stack(f: impl FnOnce() + Send + 'static) {
    std::thread::Builder::new()
        .stack_size(32 * 1024 * 1024)
        .spawn(f)
        .unwrap()
        .join()
        .unwrap();
}

// ══════════════════════════════════════════════════════════════
// Tests
// ══════════════════════════════════════════════════════════════

// ──── Happy path ────

#[test]
fn test_resolve_executes() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xCAFE").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);

    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"noop_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);

    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    assert!(!can_be_executed(&mut h, timelock_addr, &proposal_hash));
    fast_forward_block(&mut h, DELAY + 1);
    assert!(can_be_executed(&mut h, timelock_addr, &proposal_hash));

    let status = run_resolution_script(&mut h, &creator, code, vec![], timelock_addr, &proposal_hash);
    assert_success!(status);

    // After execution, the entry is marked executed → can_be_executed returns false.
    assert!(!can_be_executed(&mut h, timelock_addr, &proposal_hash));
    });
}

#[test]
fn test_delegated_resolution_via_approval() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xCA5E").unwrap());
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xCA5F").unwrap());
    // `relayer` is neither a creator nor an executor — it only submits the script.
    let relayer = h.new_account_at(AccountAddress::from_hex_literal("0xCA60").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(
        &mut h,
        &creator,
        vec![],
        vec![*executor.address()],
        DELAY
    ));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"delegated_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    // The executor pre-authorizes resolution via the entry function (the multisig-style path),
    // once the delay has elapsed.
    assert_success!(approve_resolution(&mut h, &executor, timelock_addr, &proposal_hash));

    // The relayer — not an executor — can now submit the committed script, because it was approved.
    let status = run_resolution_script(&mut h, &relayer, code, vec![], timelock_addr, &proposal_hash);
    assert_success!(status);
    assert!(!can_be_executed(&mut h, timelock_addr, &proposal_hash));
    });
}

// ──── Resolve precondition aborts ────

#[test]
fn test_resolve_fails_before_delay() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xBEEF").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"early_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    // No time advance — resolve must abort with ETIMELOCK_NOT_EXPIRED.
    let status = run_resolution_script(&mut h, &creator, code, vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_TIMELOCK_NOT_EXPIRED);

    // The proposal must still be pending: failed script rolled back the executed-flag flip.
    fast_forward_block(&mut h, DELAY + 1);
    assert!(can_be_executed(&mut h, timelock_addr, &proposal_hash));
    });
}

#[test]
fn test_resolve_fails_unauthorized_executor() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xC0DE").unwrap());
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xC0DF").unwrap());
    let intruder = h.new_account_at(AccountAddress::from_hex_literal("0xDEAD").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);

    assert_success!(create_timelock(
        &mut h,
        &creator,
        vec![],
        vec![*executor.address()],
        DELAY
    ));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"auth_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    let status = run_resolution_script(&mut h, &intruder, code, vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_NOT_EXECUTOR);
    });
}

#[test]
fn test_resolve_fails_already_executed() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xF001").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"replay_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    assert_success!(run_resolution_script(
        &mut h,
        &creator,
        code.clone(),
        vec![],
        timelock_addr,
        &proposal_hash
    ));

    // Replay: must abort with ETRANSACTION_ALREADY_EXECUTED.
    let status = run_resolution_script(&mut h, &creator, code, vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_ALREADY_EXECUTED);
    });
}

#[test]
fn test_resolve_fails_canceled() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xF002").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"canceled_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));
    assert_success!(cancel(&mut h, &creator, timelock_addr, &proposal_hash));

    fast_forward_block(&mut h, DELAY + 1);

    let status = run_resolution_script(&mut h, &creator, code, vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_ALREADY_EXECUTED);
    });
}

#[test]
fn test_resolve_fails_with_wrong_script() {
    run_in_big_stack(|| {
    // Propose execution_hash from script A but submit script B → EEXECUTION_HASH_NOT_MATCHING.
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xF003").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code_a = script("noop");
    let code_b = script("update_delay");
    let exec_hash_a = execution_hash_of(&code_a);
    let salt = salt32(b"wrong_script");
    let proposal_hash = proposal_hash_of(&exec_hash_a, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash_a, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    // Submit script B with the proposal's proposal_hash. Note that update_delay needs an
    // extra u64 arg; supply a dummy so the script can deserialize, even though resolve will
    // abort first.
    let extra = vec![TransactionArgument::U64(7200)];
    let status = run_resolution_script(&mut h, &creator, code_b, extra, timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_EXECUTION_HASH_MISMATCH);
    });
}

#[test]
fn test_resolve_fails_no_proposal() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xF030").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    fast_forward_block(&mut h, DELAY + 1);

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"ghost_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    let status = run_resolution_script(&mut h, &creator, code, vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_TRANSACTION_NOT_FOUND);
    });
}

#[test]
fn test_resolve_fails_non_timelock_account() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xF020").unwrap());

    // Use the executor's own (non-timelock) address.
    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let proposal_hash = proposal_hash_of(&exec_hash, &salt32(b"no_timelock"));
    let status = run_resolution_script(&mut h, &executor, code, vec![], *executor.address(), &proposal_hash);
    assert_aborts_with(&status, ABORT_ACCOUNT_NOT_TIMELOCK);
    });
}

// ──── Self-governance via resolution scripts ────

#[test]
fn test_self_governance_update_delay() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE001").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    const NEW_DELAY: u64 = 7200;
    let code = script("update_delay");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"update_delay_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    let extra = vec![TransactionArgument::U64(NEW_DELAY)];
    assert_success!(run_resolution_script(
        &mut h,
        &creator,
        code,
        extra,
        timelock_addr,
        &proposal_hash
    ));

    assert_eq!(min_num_seconds_execute(&mut h, timelock_addr), NEW_DELAY);
    });
}

#[test]
fn test_self_governance_add_creators() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA200").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xA201").unwrap());
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    assert_success!(create_timelock(&mut h, &alice, vec![], vec![], DELAY));
    assert!(!is_creator_view(&mut h, *bob.address(), timelock_addr));

    let code = script("add_creator");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"add_creator_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &alice, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    let extra = vec![TransactionArgument::Address(*bob.address())];
    assert_success!(run_resolution_script(
        &mut h, &alice, code, extra, timelock_addr, &proposal_hash
    ));

    assert!(is_creator_view(&mut h, *bob.address(), timelock_addr));
    });
}

#[test]
fn test_self_governance_remove_creators() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA300").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xA301").unwrap());
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    assert_success!(create_timelock(
        &mut h,
        &alice,
        vec![*bob.address()],
        vec![],
        DELAY
    ));
    assert!(is_creator_view(&mut h, *alice.address(), timelock_addr));
    assert!(is_creator_view(&mut h, *bob.address(), timelock_addr));

    let code = script("remove_creator");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"remove_creator_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &alice, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    // Bob (also creator/executor since executor list is empty) submits the script removing Alice.
    let extra = vec![TransactionArgument::Address(*alice.address())];
    assert_success!(run_resolution_script(
        &mut h, &bob, code, extra, timelock_addr, &proposal_hash
    ));

    assert!(!is_creator_view(&mut h, *alice.address(), timelock_addr));
    assert!(is_creator_view(&mut h, *bob.address(), timelock_addr));
    });
}

#[test]
fn test_self_governance_add_executors() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA400").unwrap());
    let charlie = h.new_account_at(AccountAddress::from_hex_literal("0xA401").unwrap());
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    assert_success!(create_timelock(&mut h, &alice, vec![], vec![], DELAY));

    // Initially: empty executor list → Alice (creator) is executor.
    assert!(is_executor_view(&mut h, *alice.address(), timelock_addr));
    assert!(!is_executor_view(&mut h, *charlie.address(), timelock_addr));

    let code = script("add_executor");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"add_executor_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &alice, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    let extra = vec![TransactionArgument::Address(*charlie.address())];
    assert_success!(run_resolution_script(
        &mut h, &alice, code, extra, timelock_addr, &proposal_hash
    ));

    // Executor list now [charlie]; creator fallback no longer applies.
    assert!(is_executor_view(&mut h, *charlie.address(), timelock_addr));
    assert!(!is_executor_view(&mut h, *alice.address(), timelock_addr));
    });
}

#[test]
fn test_self_governance_remove_executors() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA500").unwrap());
    let eve = h.new_account_at(AccountAddress::from_hex_literal("0xA501").unwrap());
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    assert_success!(create_timelock(
        &mut h,
        &alice,
        vec![],
        vec![*eve.address()],
        DELAY
    ));
    assert!(is_executor_view(&mut h, *eve.address(), timelock_addr));
    assert!(!is_executor_view(&mut h, *alice.address(), timelock_addr));

    let code = script("remove_executor");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"remove_executor_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &alice, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    let extra = vec![TransactionArgument::Address(*eve.address())];
    // Eve (still the executor at this point) submits the governance script.
    assert_success!(run_resolution_script(
        &mut h, &eve, code, extra, timelock_addr, &proposal_hash
    ));

    assert!(is_executor_view(&mut h, *alice.address(), timelock_addr));
    assert!(!is_executor_view(&mut h, *eve.address(), timelock_addr));
    });
}

// ──── Authorization variants ────

#[test]
fn test_dedicated_executor_runs_resolution() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA100").unwrap());
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xA101").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(
        &mut h,
        &creator,
        vec![],
        vec![*executor.address()],
        DELAY
    ));

    assert!(!is_executor_view(&mut h, *creator.address(), timelock_addr));
    assert!(is_executor_view(&mut h, *executor.address(), timelock_addr));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"dedicated_executor");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    assert_success!(run_resolution_script(
        &mut h, &executor, code.clone(), vec![], timelock_addr, &proposal_hash
    ));

    // Executor replays the same proposal → already-executed abort. (Creator would abort with
    // NOT_EXECUTOR first since executor list is non-empty, masking the executed-flag check.)
    let status = run_resolution_script(&mut h, &executor, code, vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_ALREADY_EXECUTED);
    });
}

#[test]
fn test_creator_cancels_when_executor_list_nonempty() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE003").unwrap());
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xE004").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(
        &mut h,
        &creator,
        vec![],
        vec![*executor.address()],
        DELAY
    ));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"creator_cancels");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    assert_success!(cancel(&mut h, &creator, timelock_addr, &proposal_hash));

    fast_forward_block(&mut h, DELAY + 1);
    assert!(!can_be_executed(&mut h, timelock_addr, &proposal_hash));

    let status = run_resolution_script(&mut h, &executor, code, vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_ALREADY_EXECUTED);
    });
}

#[test]
fn test_canceler_cancels_transaction() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA600").unwrap());
    let canceler = h.new_account_at(AccountAddress::from_hex_literal("0xA601").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    // A dedicated canceler (emergency-response role) can cancel even though it is not a creator.
    assert_success!(create_timelock_with_cancelers(
        &mut h,
        &creator,
        vec![],
        vec![],
        vec![*canceler.address()],
        DELAY
    ));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"canceler_cancels");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    assert_success!(cancel(&mut h, &canceler, timelock_addr, &proposal_hash));
    assert!(!can_be_executed(&mut h, timelock_addr, &proposal_hash));

    fast_forward_block(&mut h, DELAY + 1);
    let status = run_resolution_script(&mut h, &creator, code, vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_ALREADY_EXECUTED);
    });
}

#[test]
fn test_executor_cannot_cancel_transaction() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA610").unwrap());
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xA611").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(
        &mut h,
        &creator,
        vec![],
        vec![*executor.address()],
        DELAY
    ));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"executor_cannot_cancel");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    // Executors can execute but must NOT be able to cancel.
    let status = cancel(&mut h, &executor, timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_NOT_CREATOR_OR_CANCELER);
    });
}

// ──── Salt and ordering ────

#[test]
fn test_non_sequential_salt_execution() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE002").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt_a = salt32(b"alpha");
    let salt_b = salt32(b"beta");
    let hash_a = proposal_hash_of(&exec_hash, &salt_a);
    let hash_b = proposal_hash_of(&exec_hash, &salt_b);

    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt_a));
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt_b));

    fast_forward_block(&mut h, DELAY + 1);

    // Execute B before A.
    assert_success!(run_resolution_script(
        &mut h, &creator, code.clone(), vec![], timelock_addr, &hash_b
    ));
    assert_success!(run_resolution_script(
        &mut h, &creator, code, vec![], timelock_addr, &hash_a
    ));

    assert!(!can_be_executed(&mut h, timelock_addr, &hash_a));
    assert!(!can_be_executed(&mut h, timelock_addr, &hash_b));
    });
}

#[test]
fn test_duplicate_transaction_rejected() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE005").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"dup");
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    // Same execution_hash + salt → must fail (EDUPLICATE_TRANSACTION).
    let status = propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt);
    assert_aborts_with(&status, ABORT_DUPLICATE_TRANSACTION);

    // Different salt → must succeed.
    let salt2 = salt32(b"dup_2");
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt2));
    });
}

// ──── Proposal validation ────

#[test]
fn test_non_creator_cannot_propose() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE006").unwrap());
    let outsider = h.new_account_at(AccountAddress::from_hex_literal("0xE007").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"non_creator");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    let status = propose(&mut h, &outsider, timelock_addr, &exec_hash, DELAY, &salt);
    assert_aborts_with(&status, ABORT_NOT_CREATOR);

    // Nothing was stored, so the table key is absent.
    assert!(!can_be_executed(&mut h, timelock_addr, &proposal_hash));
    });
}

#[test]
fn test_create_timelock_below_min_delay_fails() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA700").unwrap());

    // One below the minimum → must fail (must be >= MIN_NUM_SECONDS_EXECUTE).
    assert_aborts_with(
        &create_timelock(&mut h, &creator, vec![], vec![], MIN_DELAY_SECS - 1),
        ABORT_NUMBER_SECONDS_TOO_SMALL,
    );

    // Exactly the minimum → must succeed.
    let creator2 = h.new_account_at(AccountAddress::from_hex_literal("0xA702").unwrap());
    assert_success!(create_timelock(&mut h, &creator2, vec![], vec![], MIN_DELAY_SECS));
    });
}

#[test]
fn test_propose_below_min_delay_fails() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA800").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);

    // num_seconds_execute < min_num_seconds_execute → fails.
    let status = propose(
        &mut h,
        &creator,
        timelock_addr,
        &exec_hash,
        DELAY - 1,
        &salt32(b"below_min"),
    );
    assert_aborts_with(&status, ABORT_NUMBER_SECONDS_TOO_SMALL);

    // Exactly min_num_seconds_execute → succeeds.
    assert_success!(propose(
        &mut h,
        &creator,
        timelock_addr,
        &exec_hash,
        DELAY,
        &salt32(b"exact_min"),
    ));
    });
}

#[test]
fn test_create_transaction_invalid_lengths_fail() {
    run_in_big_stack(|| {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA900").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let valid_salt = salt32(b"valid");

    // Salt too short.
    let status = propose(
        &mut h,
        &creator,
        timelock_addr,
        &exec_hash,
        DELAY,
        b"short",
    );
    assert_aborts_with(&status, ABORT_INVALID_BYTES_LENGTH);

    // Salt too long.
    let long_salt = vec![0u8; 33];
    let status = propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &long_salt);
    assert_aborts_with(&status, ABORT_INVALID_BYTES_LENGTH);

    // execution_hash wrong length.
    let bad_hash = vec![0u8; 31];
    let status = propose(&mut h, &creator, timelock_addr, &bad_hash, DELAY, &valid_salt);
    assert_aborts_with(&status, ABORT_INVALID_BYTES_LENGTH);

    // All correct → succeeds.
    assert_success!(propose(
        &mut h,
        &creator,
        timelock_addr,
        &exec_hash,
        DELAY,
        &valid_salt,
    ));
    });
}

// ──── Cross-module: multisig proposes into timelock ────

#[test]
fn test_multisig_proposes_timelock_transaction() {
    run_in_big_stack(|| {
    // alice runs a 1-of-1 multisig that proposes timelock::create_transaction; the multisig
    // is set as an additional creator on the timelock. Once the multisig executes, the
    // timelock has the proposal and a noop resolution script can run.
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA11CE").unwrap());

    // 1-of-1 multisig (alice's seq before this tx is 10).
    let multisig_addr = multisig_account_address(*alice.address(), 10);
    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::multisig_account::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&1u64).unwrap(),
            bcs::to_bytes::<Vec<Vec<u8>>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<Vec<u8>>>(&vec![]).unwrap(),
        ],
    ));

    // Timelock with the multisig as an additional creator (alice's seq = 11 now).
    let timelock_addr = timelock_account_address(*alice.address(), 11);
    assert_success!(create_timelock(
        &mut h,
        &alice,
        vec![multisig_addr],
        vec![],
        DELAY
    ));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"multisig_proposes");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);

    // The multisig's inner entry function: timelock::create_transaction(...).
    let inner_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("timelock").to_owned()),
        ident_str!("create_transaction").to_owned(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&exec_hash).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
            // Optional off-chain script_path pointer; empty here.
            bcs::to_bytes(&Vec::<u8>::new()).unwrap(),
        ],
    );
    let multisig_payload = MultisigTransactionPayload::EntryFunction(inner_fn);

    // Alice proposes the multisig transaction.
    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::multisig_account::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&multisig_addr).unwrap(),
            bcs::to_bytes(&bcs::to_bytes(&multisig_payload).unwrap()).unwrap(),
        ],
    ));

    // Alice executes the multisig (auto-approved since 1-of-1).
    assert_success!(h.run_multisig(&alice, multisig_addr, Some(multisig_payload)));

    // Now the timelock has the proposal. Run the resolution script.
    fast_forward_block(&mut h, DELAY + 1);
    assert!(can_be_executed(&mut h, timelock_addr, &proposal_hash));
    assert_success!(run_resolution_script(
        &mut h, &alice, code, vec![], timelock_addr, &proposal_hash
    ));
    });
}

// ──── Cross-module: timelock proposes into multisig ────

#[test]
fn test_timelock_proposes_multisig_transaction() {
    run_in_big_stack(|| {
    // Reverse direction: alice runs a timelock and a 1-of-N multisig where the timelock is an
    // additional owner. Alice proposes a script (multisig_propose) that, on resolve, calls
    // multisig_account::create_transaction with the timelock signer — making the timelock the
    // proposer of a multisig transaction.
    let mut h = MoveHarness::new();
    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xB0B").unwrap());

    // Timelock first (alice's seq = 10).
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    assert_success!(create_timelock(&mut h, &alice, vec![], vec![], DELAY));

    // Multisig with timelock as additional owner (alice's seq = 11).
    let multisig_addr = multisig_account_address(*alice.address(), 11);
    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::multisig_account::create_with_owners").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![timelock_addr]).unwrap(),
            bcs::to_bytes(&1u64).unwrap(),
            bcs::to_bytes::<Vec<Vec<u8>>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<Vec<u8>>>(&vec![]).unwrap(),
        ],
    ));

    // Inner multisig payload: an entry-function noop (account::create_account_if_does_not_exist).
    let multisig_inner_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("account").to_owned()),
        ident_str!("create_account_if_does_not_exist").to_owned(),
        vec![],
        vec![bcs::to_bytes(&AccountAddress::new([0xAB; 32])).unwrap()],
    );
    let multisig_payload = MultisigTransactionPayload::EntryFunction(multisig_inner_fn);
    let multisig_payload_bytes = bcs::to_bytes(&multisig_payload).unwrap();

    let code = script("multisig_propose");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"timelock_to_multisig");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &alice, timelock_addr, &exec_hash, DELAY, &salt));

    fast_forward_block(&mut h, DELAY + 1);

    // Run the resolution script: the timelock signer (returned by resolve) calls
    // multisig::create_transaction, making the timelock the multisig proposer.
    let extra = vec![
        TransactionArgument::Address(multisig_addr),
        TransactionArgument::U8Vector(multisig_payload_bytes),
    ];
    assert_success!(run_resolution_script(
        &mut h, &alice, code, extra, timelock_addr, &proposal_hash
    ));

    // Alice (also a multisig owner) executes the multisig transaction. With 1-of-N approval and
    // the proposer (timelock) auto-approving, the proposal is at quorum.
    assert_success!(h.run_multisig(&alice, multisig_addr, Some(multisig_payload)));
    });
}

// ──── Delay / authorization / cancel edge cases ────

#[test]
fn test_resolve_uses_per_transaction_delay_not_min() {
    run_in_big_stack(|| {
    // The resolve gate must use the transaction's own `num_seconds_execute`, not the account's
    // `min_num_seconds_execute`. Propose with a delay LARGER than the account min and verify the
    // proposal is not executable until the larger per-transaction delay elapses.
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xD100").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let tx_delay = DELAY * 2; // >= account min, so accepted by create_transaction.
    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"longer_delay_salt");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, tx_delay, &salt));

    // Past the account min (DELAY) but before the per-transaction delay (2*DELAY): not executable.
    fast_forward_block(&mut h, DELAY + 1);
    assert!(!can_be_executed(&mut h, timelock_addr, &proposal_hash));
    let status =
        run_resolution_script(&mut h, &creator, code.clone(), vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_TIMELOCK_NOT_EXPIRED);

    // Past the per-transaction delay: now executable.
    fast_forward_block(&mut h, DELAY + 1);
    assert!(can_be_executed(&mut h, timelock_addr, &proposal_hash));
    assert_success!(run_resolution_script(
        &mut h, &creator, code, vec![], timelock_addr, &proposal_hash
    ));
    });
}

#[test]
fn test_creator_cannot_resolve_when_executors_set() {
    run_in_big_stack(|| {
    // With a non-empty executor set, a creator may propose but must NOT be able to resolve.
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xD200").unwrap());
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xD201").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(
        &mut h,
        &creator,
        vec![],
        vec![*executor.address()],
        DELAY
    ));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"creator_no_resolve");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));
    fast_forward_block(&mut h, DELAY + 1);

    // Creator is a valid proposer but not in the executor set → denied.
    let status =
        run_resolution_script(&mut h, &creator, code.clone(), vec![], timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_NOT_EXECUTOR);

    // The designated executor can resolve the same (still-pending) proposal.
    assert_success!(run_resolution_script(
        &mut h, &executor, code, vec![], timelock_addr, &proposal_hash
    ));
    });
}

#[test]
fn test_resolve_remove_last_creator_aborts() {
    run_in_big_stack(|| {
    // Removing the sole remaining creator through the real resolve→remove_creators path must
    // abort (EWOULD_REMOVE_ALL_CREATORS); the whole script reverts atomically.
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xD300").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("remove_creator");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"remove_last_creator");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));
    fast_forward_block(&mut h, DELAY + 1);

    let extra = vec![TransactionArgument::Address(*creator.address())];
    let status = run_resolution_script(&mut h, &creator, code, extra, timelock_addr, &proposal_hash);
    assert_aborts_with(&status, ABORT_WOULD_REMOVE_ALL_CREATORS);

    // Atomic revert: the creator is still present and the proposal is still pending.
    assert!(is_creator_view(&mut h, *creator.address(), timelock_addr));
    assert!(can_be_executed(&mut h, timelock_addr, &proposal_hash));
    });
}

#[test]
fn test_cancel_edge_cases() {
    run_in_big_stack(|| {
    // Covers cancel_transaction's three guard paths: bad hash length, not-found, and an
    // unauthorized actor.
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xD400").unwrap());
    let intruder = h.new_account_at(AccountAddress::from_hex_literal("0xD4FF").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt = salt32(b"cancel_edge");
    let proposal_hash = proposal_hash_of(&exec_hash, &salt);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt));

    // (1) Wrong length: a 31-byte hash is rejected before the existence/auth checks.
    let short_hash = vec![0u8; 31];
    assert_aborts_with(
        &cancel(&mut h, &creator, timelock_addr, &short_hash),
        ABORT_INVALID_BYTES_LENGTH,
    );

    // (2) Well-formed 32-byte hash that was never proposed → not found (actor is authorized).
    let ghost_hash = proposal_hash_of(&exec_hash, &salt32(b"never_proposed"));
    assert_aborts_with(
        &cancel(&mut h, &creator, timelock_addr, &ghost_hash),
        ABORT_TRANSACTION_NOT_FOUND,
    );

    // (3) An actor who is neither creator nor canceler cannot cancel an existing proposal.
    assert_aborts_with(
        &cancel(&mut h, &intruder, timelock_addr, &proposal_hash),
        ABORT_NOT_CREATOR_OR_CANCELER,
    );

    // The proposal survived all three rejected attempts.
    fast_forward_block(&mut h, DELAY + 1);
    assert!(can_be_executed(&mut h, timelock_addr, &proposal_hash));
    });
}

#[test]
fn test_same_execution_hash_different_salt_independent() {
    run_in_big_stack(|| {
    // Two proposals of the SAME script, disambiguated only by salt, are independent: each is
    // resolved by its own `proposal_hash` (= keccak256(execution_hash || salt)), and resolving
    // one does not consume the other. This pins the salt-binding behavior of the resolve path.
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xD500").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    assert_success!(create_timelock(&mut h, &creator, vec![], vec![], DELAY));

    let code = script("noop");
    let exec_hash = execution_hash_of(&code);
    let salt_a = salt32(b"salt_a");
    let salt_b = salt32(b"salt_b");
    let tx_hash_a = proposal_hash_of(&exec_hash, &salt_a);
    let tx_hash_b = proposal_hash_of(&exec_hash, &salt_b);
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt_a));
    assert_success!(propose(&mut h, &creator, timelock_addr, &exec_hash, DELAY, &salt_b));

    fast_forward_block(&mut h, DELAY + 1);

    // Resolve A by its own hash.
    assert_success!(run_resolution_script(
        &mut h, &creator, code.clone(), vec![], timelock_addr, &tx_hash_a
    ));

    // A is consumed; B is untouched and still executable.
    assert!(!can_be_executed(&mut h, timelock_addr, &tx_hash_a));
    assert!(can_be_executed(&mut h, timelock_addr, &tx_hash_b));

    // Re-resolving A fails; B still resolves with its own hash.
    assert_aborts_with(
        &run_resolution_script(&mut h, &creator, code.clone(), vec![], timelock_addr, &tx_hash_a),
        ABORT_ALREADY_EXECUTED,
    );
    assert_success!(run_resolution_script(
        &mut h, &creator, code, vec![], timelock_addr, &tx_hash_b
    ));
    });
}


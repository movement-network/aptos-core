// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! End-to-end VM tests for the timelock module.
//!
//! These tests exercise the full VM path:
//!   1. Creating a timelock account via Move entry functions.
//!   2. Proposing a transaction (create_transaction).
//!   3. Submitting a `TransactionPayload::Timelock` transaction that goes through
//!      the VM prologue (validate_timelock_transaction) → execution → epilogue
//!      (successful_transaction_execution_cleanup).
//!   4. Cross-module (multisig → timelock): a multisig transaction proposes into a timelock,
//!      then the timelock executes.
//!   5. Cross-module (timelock → multisig): a timelock transaction proposes into a multisig,
//!      then the multisig executes.

use crate::{assert_success, MoveHarness};
use aptos_language_e2e_tests::account::Account;
use aptos_types::{
    account_address::{create_resource_address, AccountAddress},
    transaction::{
        EntryFunction, MultisigTransactionPayload, TimelockTransactionPayload, TransactionStatus,
    },
};
use move_core_types::{
    ident_str,
    language_storage::{ModuleId, CORE_CODE_ADDRESS},
};
use sha3::{Digest, Keccak256};

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

/// Derive the timelock resource-account address that will be created when `creator`
/// (with on-chain sequence number `seq`) calls `timelock::create(...)`.
///
/// Mirrors the Move logic:
///   seed  = b"aptos_framework::timelock" ++ bcs(seq)
///   addr  = create_resource_address(creator, seed)
fn timelock_account_address(creator: AccountAddress, seq: u64) -> AccountAddress {
    const DOMAIN_SEPARATOR: &[u8] = b"aptos_framework::timelock";
    let mut seed = DOMAIN_SEPARATOR.to_vec();
    seed.extend(bcs::to_bytes(&seq).unwrap());
    create_resource_address(creator, &seed)
}

/// Derive the multisig resource-account address.
/// Mirrors `create_multisig_account_address` in types.
fn multisig_account_address(creator: AccountAddress, seq: u64) -> AccountAddress {
    aptos_types::account_address::create_multisig_account_address(creator, seq)
}

/// Build an EntryFunction that calls `0x1::timelock::noop_for_test` – used as a
/// stand-in payload to verify that the VM correctly dispatches and executes.
///
/// In practice the payload can be any valid entry function; for these tests we
/// re-use `0x1::timelock::cancel_transaction` with a dummy salt (it will fail at
/// Move level, which is fine – we only care about the VM dispatch path for the
/// success path tests, and we use a real function for those).
fn make_noop_entry_function() -> EntryFunction {
    // We use an entry function that definitely exists: `coin::transfer` is not
    // appropriate because it needs extra setup. Instead we call timelock's own
    // `create_transaction` as a no-op by pointing to a function that always
    // succeeds with no side effects — `0x1::timelock::cancel_transaction` is a
    // real entry fn; its execution will fail at Move level but the VM will still
    // go through the full prologue/epilogue machinery which is what we test.
    //
    // For the "execute succeeds" test we need a function that will actually work.
    // The simplest callable no-op available in the framework without extra state
    // is `aptos_framework::account::create_account_if_does_not_exist`.
    EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("account").to_owned()),
        ident_str!("create_account_if_does_not_exist").to_owned(),
        vec![],
        // address argument – use a fresh address unlikely to exist
        vec![bcs::to_bytes(&AccountAddress::new([0xAB; 32])).unwrap()],
    )
}

fn salt32(label: &[u8]) -> Vec<u8> {
    let mut hasher = Keccak256::new();
    hasher.update(label);
    hasher.finalize().to_vec()
}

fn timelock_hash(payload_bytes: &[u8], salt: &[u8]) -> Vec<u8> {
    let mut hasher = Keccak256::new();
    hasher.update(payload_bytes);
    hasher.update(salt);
    hasher.finalize().to_vec()
}

fn propose_timelock_transaction(
    h: &mut MoveHarness,
    creator: &Account,
    timelock_addr: AccountAddress,
    payload: Option<Vec<u8>>,
    hash: Option<Vec<u8>>,
    delay: u64,
    salt: Vec<u8>,
) -> TransactionStatus {
    match (payload, hash) {
        (Some(payload), None) => h.run_entry_function(
            creator,
            str::parse("0x1::timelock::create_transaction").unwrap(),
            vec![],
            vec![
                bcs::to_bytes(&timelock_addr).unwrap(),
                bcs::to_bytes(&payload).unwrap(),
                bcs::to_bytes(&delay).unwrap(),
                bcs::to_bytes(&salt).unwrap(),
            ],
        ),
        (None, Some(hash)) => h.run_entry_function(
            creator,
            str::parse("0x1::timelock::create_transaction_with_hash").unwrap(),
            vec![],
            vec![
                bcs::to_bytes(&timelock_addr).unwrap(),
                bcs::to_bytes(&hash).unwrap(),
                bcs::to_bytes(&delay).unwrap(),
                bcs::to_bytes(&salt).unwrap(),
            ],
        ),
        _ => panic!("timelock proposal must provide exactly one of payload or hash"),
    }
}

// ──────────────────────────────────────────────────────────────
// Test 1 — basic timelock transaction executes on-chain
// ──────────────────────────────────────────────────────────────

/// Full end-to-end path:
///   create timelock → propose transaction → wait → submit TimelockTransaction → verify executed
#[test]
fn test_timelock_transaction_execute() {
    let mut h = MoveHarness::new();

    // Accounts: creator is also the executor (no dedicated executors list).
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xCAFE").unwrap());

    // ── Step 1: create the timelock account ──────────────────────────────────
    // Creator's on-chain sequence number is 10 before this transaction
    // (new_account_at initializes accounts with seq_num = 10).
    let timelock_addr = timelock_account_address(*creator.address(), 10);

    // Minimum delay is > 360 s; we use 3700.
    const DELAY: u64 = 3700;

    let status = h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(), // additional_creators
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(), // executors (empty → creator can execute)
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    );
    assert_success!(status);

    // ── Step 2: propose a transaction ────────────────────────────────────────
    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt = salt32(b"test_salt_1");

    let status = propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt.clone(),
    );
    assert_success!(status);

    // ── Step 3: advance time past the delay ─────────────────────────────────
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // ── Step 4: submit the TimelockTransaction ───────────────────────────────
    // The creator is also the executor since no dedicated executors were set.
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt,
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    assert_success!(status);
}

#[test]
fn test_timelock_transaction_execute_hash_only() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xCAFF").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload = TimelockTransactionPayload::EntryFunction(entry_fn.clone());
    let payload_bytes = bcs::to_bytes(&payload).unwrap();
    let salt = salt32(b"test_salt_hash_only");
    let hash = timelock_hash(&payload_bytes, &salt);

    let status = propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        None,
        Some(hash),
        DELAY,
        salt.clone(),
    );
    assert_success!(status);

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    let status = h.run_timelock(&creator, timelock_addr, salt, Some(payload));
    assert_success!(status);
}

// ──────────────────────────────────────────────────────────────
// Test 2 — timelock transaction fails if submitted before delay
// ──────────────────────────────────────────────────────────────

#[test]
fn test_timelock_transaction_fails_before_delay() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xBEEF").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt = salt32(b"early_salt");

    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    // Do NOT advance time – the prologue should abort with ETIMELOCK_NOT_EXPIRED.
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt,
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    // The transaction should be discarded (prologue failure).
    assert!(
        matches!(status, aptos_types::transaction::TransactionStatus::Discard(_)),
        "Expected prologue rejection (Discard), got: {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 3 — non-executor cannot execute the timelock transaction
// ──────────────────────────────────────────────────────────────

#[test]
fn test_timelock_transaction_unauthorized_executor() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xC0DE").unwrap());
    // A separate account that is NOT a creator/executor.
    let intruder = h.new_account_at(AccountAddress::from_hex_literal("0xDEAD").unwrap());

    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt = salt32(b"auth_salt");

    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Intruder tries to execute – should be rejected in the prologue.
    let status = h.run_timelock(
        &intruder,
        timelock_addr,
        salt,
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    assert!(
        matches!(status, aptos_types::transaction::TransactionStatus::Discard(_)),
        "Expected prologue rejection for unauthorized executor, got: {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 4 — multisig proposes into timelock, then timelock executes
// ──────────────────────────────────────────────────────────────

/// Cross-module flow:
///   alice creates a multisig → alice creates a timelock with multisig as creator
///   → multisig proposes `timelock::create_transaction` → multisig executes it
///   → time passes → TimelockTransaction executes
#[test]
fn test_multisig_proposes_timelock_transaction() {
    let mut h = MoveHarness::new();

    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA11CE").unwrap());

    // ── Step 1: alice creates a 1-of-1 multisig ─────────────────────────────
    // Alice's sequence number is 10 before this transaction
    // (new_account_at initializes accounts with seq_num = 10).
    let multisig_addr = multisig_account_address(*alice.address(), 10);

    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::multisig_account::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&1u64).unwrap(), // num_signatures_required
            bcs::to_bytes::<Vec<Vec<u8>>>(&vec![]).unwrap(), // metadata_keys
            bcs::to_bytes::<Vec<Vec<u8>>>(&vec![]).unwrap(), // metadata_values
        ],
    ));

    // ── Step 2: alice creates a timelock with multisig_addr as a creator ────
    // Alice's sequence number is now 11 (after the multisig create).
    let timelock_addr = timelock_account_address(*alice.address(), 11);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![multisig_addr]).unwrap(), // additional_creators
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),              // executors (alice can execute)
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    // ── Step 3: build the payload for `timelock::create_transaction` ─────────
    // The multisig will execute `timelock::create_transaction` *as the multisig
    // account*, making the multisig account the creator of a timelock tx.
    let inner_entry_fn = make_noop_entry_function();
    let inner_payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(inner_entry_fn.clone()))
            .unwrap();
    let timelock_salt = salt32(b"multisig_via_timelock");

    let multisig_inner_entry_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("timelock").to_owned()),
        ident_str!("create_transaction").to_owned(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&inner_payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&timelock_salt).unwrap(),
        ],
    );

    // ── Step 4: alice proposes the above via the multisig ───────────────────
    let multisig_payload =
        MultisigTransactionPayload::EntryFunction(multisig_inner_entry_fn.clone());

    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::multisig_account::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&multisig_addr).unwrap(),
            bcs::to_bytes(&bcs::to_bytes(&multisig_payload).unwrap()).unwrap(),
        ],
    ));

    // ── Step 5: alice (sole owner) executes the multisig transaction ─────────
    // This calls `timelock::create_transaction` as the multisig account signer.
    let status = h.run_multisig(
        &alice,
        multisig_addr,
        Some(multisig_payload),
    );
    assert_success!(status);

    // ── Step 6: advance time and execute the timelock transaction ────────────
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Alice (creator of the timelock) submits the TimelockTransaction.
    let status = h.run_timelock(
        &alice,
        timelock_addr,
        timelock_salt,
        Some(TimelockTransactionPayload::EntryFunction(inner_entry_fn)),
    );
    assert_success!(status);
}

// ──────────────────────────────────────────────────────────────
// Test 5 (cross-module reverse) — timelock proposes into multisig, then multisig executes
// ──────────────────────────────────────────────────────────────

/// Reverse cross-module flow (timelock → multisig):
///   alice creates a timelock → alice creates a multisig with timelock as an additional owner
///   → alice proposes `multisig_account::create_transaction` into the timelock
///   → time passes → TimelockTransaction executes (timelock account proposes the multisig tx)
///   → alice executes the multisig transaction
///
/// This verifies the reverse direction of Test 4: the timelock is the actor that drives
/// the multisig, rather than the multisig driving the timelock.
#[test]
fn test_timelock_proposes_multisig_transaction() {
    let mut h = MoveHarness::new();

    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xB0B").unwrap());

    // ── Step 1: alice creates a timelock ─────────────────────────────────────
    // Alice's sequence number is 10 before this transaction
    // (new_account_at initializes accounts with seq_num = 10).
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(), // no additional creators
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(), // executors (alice can execute)
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    // ── Step 2: alice creates a multisig with timelock_addr as an additional owner ──
    // Alice's sequence number is now 11 (after the timelock create).
    // With num_signatures_required = 1, any single owner approval is sufficient to execute.
    let multisig_addr = multisig_account_address(*alice.address(), 11);

    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::multisig_account::create_with_owners").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![timelock_addr]).unwrap(), // additional_owners
            bcs::to_bytes(&1u64).unwrap(),                                        // num_signatures_required
            bcs::to_bytes::<Vec<Vec<u8>>>(&vec![]).unwrap(),                      // metadata_keys
            bcs::to_bytes::<Vec<Vec<u8>>>(&vec![]).unwrap(),                      // metadata_values
        ],
    ));

    // ── Step 3: build the multisig proposal (the noop that the multisig will eventually run) ──
    let noop_entry_fn = make_noop_entry_function();
    let multisig_proposal_payload =
        MultisigTransactionPayload::EntryFunction(noop_entry_fn.clone());

    // ── Step 4: build the timelock inner payload: propose the above into the multisig ──
    // When the timelock executes this, the timelock account is the signer calling
    // `multisig_account::create_transaction`, making it the creator/proposer of the
    // multisig tx.  Since num_signatures_required = 1 the proposal is auto-approved.
    let timelock_inner_entry_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("multisig_account").to_owned()),
        ident_str!("create_transaction").to_owned(),
        vec![],
        vec![
            bcs::to_bytes(&multisig_addr).unwrap(),
            bcs::to_bytes(&bcs::to_bytes(&multisig_proposal_payload).unwrap()).unwrap(),
        ],
    );
    let timelock_salt = salt32(b"timelock_to_multisig");

    let timelock_payload =
        TimelockTransactionPayload::EntryFunction(timelock_inner_entry_fn.clone());
    let payload_bytes = bcs::to_bytes(&timelock_payload).unwrap();

    assert_success!(propose_timelock_transaction(
        &mut h,
        &alice,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        timelock_salt.clone(),
    ));

    // ── Step 5: advance time and execute the timelock transaction ────────────
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Alice (executor of the timelock) submits the TimelockTransaction.
    // Inside, the VM executes `multisig_account::create_transaction` with the
    // timelock account as the signer — creating a multisig proposal that is
    // immediately at quorum (1-of-1 approval from the proposer itself).
    let status = h.run_timelock(
        &alice,
        timelock_addr,
        timelock_salt,
        Some(timelock_payload),
    );
    assert_success!(status);

    // ── Step 6: alice executes the multisig transaction ──────────────────────
    // The multisig proposal (seq_no = 1) was created by the timelock and is already
    // at quorum.  Alice is also an owner (added by `create_with_owners`) so she can
    // submit the MultisigTransaction that drives execution.
    let status = h.run_multisig(
        &alice,
        multisig_addr,
        Some(multisig_proposal_payload),
    );
    assert_success!(status);
}

// ──────────────────────────────────────────────────────────────
// Helper: call the `can_be_executed` view function.
// Returns false when:
//   (a) not enough time has passed, OR
//   (b) the transaction has already been executed (executed = true).
// Returns true only when time has elapsed AND executed = false.
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

fn is_creator_view(h: &mut MoveHarness, addr: AccountAddress, timelock_addr: AccountAddress) -> bool {
    let result = h.execute_view_function(
        str::parse("0x1::timelock::is_creator").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&addr).unwrap(),
            bcs::to_bytes(&timelock_addr).unwrap(),
        ],
    );
    bcs::from_bytes::<bool>(&result.values.unwrap()[0]).unwrap()
}

fn is_executor_view(h: &mut MoveHarness, addr: AccountAddress, timelock_addr: AccountAddress) -> bool {
    let result = h.execute_view_function(
        str::parse("0x1::timelock::is_executor").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&addr).unwrap(),
            bcs::to_bytes(&timelock_addr).unwrap(),
        ],
    );
    bcs::from_bytes::<bool>(&result.values.unwrap()[0]).unwrap()
}

// ──────────────────────────────────────────────────────────────
// Test 6 — transaction remains executed:false while delay has not elapsed
// ──────────────────────────────────────────────────────────────

/// Assurance: a failed prologue (timelock not expired) must NOT consume the
/// transaction.  After the failure the transaction must still be executable
/// once the delay passes.
///
/// Verification strategy:
///   1. Propose tx.
///   2. Submit TimelockTransaction before delay → Discard (prologue abort).
///   3. `can_be_executed` returns false (time not yet elapsed; executed still false).
///   4. Advance time.
///   5. `can_be_executed` now returns true (time elapsed, executed still false).
///   6. Execute successfully → Keep.
///   7. `can_be_executed` returns false again (executed = true now).
///   8. A second execution attempt → Discard (ETRANSACTION_ALREADY_EXECUTED).
#[test]
fn test_executed_false_while_delay_not_elapsed() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xF001").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    // Create timelock.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt = salt32(b"delay_check_salt");
    let hash = timelock_hash(&payload_bytes, &salt);

    // Propose transaction.
    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    // ── Attempt 1: too early — prologue must reject ───────────────────────────
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt.clone(),
        Some(TimelockTransactionPayload::EntryFunction(entry_fn.clone())),
    );
    assert!(
        matches!(status, TransactionStatus::Discard(_)),
        "Expected Discard (prologue: ETIMELOCK_NOT_EXPIRED), got {:?}",
        status
    );

    // The transaction must still be pending — not consumed by the failed attempt.
    // can_be_executed returns false because time hasn't passed yet (not because executed=true).
    assert!(
        !can_be_executed(&mut h, timelock_addr, &hash),
        "can_be_executed should be false (delay not elapsed)",
    );

    // ── Advance time ─────────────────────────────────────────────────────────
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Now `can_be_executed` must return true: time has passed and executed is still false.
    assert!(
        can_be_executed(&mut h, timelock_addr, &hash),
        "can_be_executed should be true after delay with executed=false",
    );

    // ── Attempt 2: correct time — must succeed ────────────────────────────────
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt.clone(),
        Some(TimelockTransactionPayload::EntryFunction(entry_fn.clone())),
    );
    assert_success!(status);

    // After successful execution, executed=true → can_be_executed returns false.
    assert!(
        !can_be_executed(&mut h, timelock_addr, &hash),
        "can_be_executed should be false after successful execution",
    );

    // ── Attempt 3: already executed — prologue must reject ────────────────────
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt.clone(),
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    assert!(
        matches!(status, TransactionStatus::Discard(_)),
        "Expected Discard (prologue: ETRANSACTION_ALREADY_EXECUTED), got {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 7 — malconstructed inner payload: executed:true, no state change
// ──────────────────────────────────────────────────────────────

/// Assurance: if the inner entry function fails (malconstructed args →
/// VM deserialization error), the cleanup epilogue still runs and sets
/// `executed = true`, but none of the inner function's intended state
/// changes are persisted.
///
/// We use `aptos_account::transfer` as the inner function but supply
/// garbage bytes as the `amount` argument.  The Move VM cannot deserialize
/// a `u64` from those bytes → execution fails → `failed_transaction_execution_cleanup`
/// → `executed = true`.  We verify that the receiver account did NOT
/// receive any APT (the transfer's side-effect is absent).
///
/// Verification:
///   1. Confirm receiver has 0 APT before the test.
///   2. Propose a timelock tx whose inner function is a transfer with bad args.
///   3. Execute the TimelockTransaction — expect Keep (cleanup ran, outer txn is kept).
///   4. Confirm receiver still has 0 APT (inner function effect absent).
///   5. Confirm `can_be_executed` is now false (executed = true set by failed cleanup).
///   6. A second execution attempt → Discard (ETRANSACTION_ALREADY_EXECUTED).
#[test]
fn test_malconstructed_payload_sets_executed_no_state_change() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xF002").unwrap());
    let receiver = AccountAddress::from_hex_literal("0xF003").unwrap();
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    // Receiver must not exist / have 0 APT.
    assert_eq!(h.read_aptos_balance(&receiver), 0);

    // Create timelock.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    // Build an EntryFunction for `aptos_account::transfer(receiver, amount)` where
    // `amount` is encoded as garbage bytes — the Move VM cannot parse a u64 from them.
    let garbage_amount: Vec<u8> = vec![0xFF, 0xFF, 0xFF]; // 3 bytes, not a valid u64
    let bad_inner_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("aptos_account").to_owned()),
        ident_str!("transfer").to_owned(),
        vec![],
        vec![
            bcs::to_bytes(&receiver).unwrap(), // valid receiver address
            garbage_amount,                    // INVALID amount encoding
        ],
    );

    // The on-chain stored payload is the BCS of the `TimelockTransactionPayload` enum —
    // this is the same encoding the VM will reconstruct from the transaction, so the
    // prologue byte-equality check will pass.
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(bad_inner_fn.clone())).unwrap();
    let salt = salt32(b"bad_payload_salt");
    let hash = timelock_hash(&payload_bytes, &salt);

    // Propose the transaction — the payload is accepted as-is (the timelock module
    // stores raw bytes without interpreting them).
    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Submit the TimelockTransaction.  The outer transaction is Kept (the VM ran
    // the failed-cleanup epilogue), but the inner function's effects are absent.
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt.clone(),
        Some(TimelockTransactionPayload::EntryFunction(bad_inner_fn)),
    );
    // The outer transaction is kept — gas is charged and the cleanup ran.
    assert!(
        matches!(status, TransactionStatus::Keep(_)),
        "Expected Keep (failed cleanup ran), got {:?}",
        status
    );

    // ── State-change assurance: receiver has no APT ───────────────────────────
    // The transfer's side-effect must NOT have been applied.
    assert_eq!(
        h.read_aptos_balance(&receiver),
        0,
        "Receiver should still have 0 APT — inner function effects must not be persisted",
    );

    // ── executed:true assurance ───────────────────────────────────────────────
    // can_be_executed returns false because executed was set to true by the cleanup.
    assert!(
        !can_be_executed(&mut h, timelock_addr, &hash),
        "can_be_executed should be false — executed=true was set by failed_transaction_execution_cleanup",
    );

    // A second execution attempt must be rejected by the prologue.
    let retry_fn = make_noop_entry_function();
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt.clone(),
        Some(TimelockTransactionPayload::EntryFunction(retry_fn)),
    );
    assert!(
        matches!(status, TransactionStatus::Discard(_)),
        "Expected Discard (ETRANSACTION_ALREADY_EXECUTED) on retry, got {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 8 (H2) — self-governance: timelock proposes update_min_num_seconds_execute
// ──────────────────────────────────────────────────────────────

/// Self-governance flow: the timelock account uses its own proposal mechanism to
/// update its minimum execution delay.
///
///   1. Creator creates timelock with DELAY = 3700 s.
///   2. Creator proposes `timelock::update_min_num_seconds_execute(timelock_addr, NEW_DELAY)`.
///      This entry function can only be called by the timelock account itself, so the only
///      way to invoke it is through a TimelockTransaction.
///   3. Time advances past DELAY.
///   4. Creator submits the TimelockTransaction → VM invokes the entry function with the
///      timelock account signer.
///   5. Verify `min_num_seconds_execute` is now NEW_DELAY.
#[test]
fn test_self_governance_update_delay() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE001").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;
    const NEW_DELAY: u64 = 7200;

    // Step 1: create the timelock.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    // Step 2: build the self-governance payload.
    // `update_min_num_seconds_execute(timelock_account: &signer, new_min_num_seconds_execute: u64)`
    let governance_entry_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("timelock").to_owned()),
        ident_str!("update_min_num_seconds_execute").to_owned(),
        vec![],
        vec![bcs::to_bytes(&NEW_DELAY).unwrap()],
    );
    let governance_payload = TimelockTransactionPayload::EntryFunction(governance_entry_fn.clone());
    let governance_payload_bytes = bcs::to_bytes(&governance_payload).unwrap();
    let salt = salt32(b"governance_update_delay");
    let hash = timelock_hash(&governance_payload_bytes, &salt);

    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(governance_payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    // Step 3: advance time.
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Step 4: execute the governance transaction.
    let status = h.run_timelock(&creator, timelock_addr, salt, Some(governance_payload));
    assert_success!(status);

    assert!(
        !can_be_executed(&mut h, timelock_addr, &hash),
        "can_be_executed should be false after governance execution",
    );

    // Step 5: verify the new delay is in effect.
    let result = h.execute_view_function(
        str::parse("0x1::timelock::min_num_seconds_execute").unwrap(),
        vec![],
        vec![bcs::to_bytes(&timelock_addr).unwrap()],
    );
    let actual_delay = bcs::from_bytes::<u64>(&result.values.unwrap()[0]).unwrap();
    assert_eq!(
        actual_delay, NEW_DELAY,
        "min_num_seconds_execute should be {NEW_DELAY} after self-governance update",
    );
}

// ──────────────────────────────────────────────────────────────
// Test 9 (M4) — non-sequential salt execution order
// ──────────────────────────────────────────────────────────────

/// Salts are arbitrary — transactions can be executed in any order, not just
/// the order they were proposed.
///
///   1. Propose salt_A and salt_B.
///   2. Advance time past both delays.
///   3. Execute salt_B first, then salt_A.
///   4. Both succeed and both show executed=true.
#[test]
fn test_non_sequential_salt_execution() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE002").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();

    let salt_a = salt32(b"salt_alpha");
    let salt_b = salt32(b"salt_beta");
    let hash_a = timelock_hash(&payload_bytes, &salt_a);
    let hash_b = timelock_hash(&payload_bytes, &salt_b);

    // Propose A then B.
    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes.clone()),
        None,
        DELAY,
        salt_a.clone(),
    ));
    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt_b.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Execute B before A — should succeed.
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt_b.clone(),
        Some(TimelockTransactionPayload::EntryFunction(entry_fn.clone())),
    );
    assert_success!(status);

    // Now execute A — also succeeds.
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt_a.clone(),
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    assert_success!(status);

    // Both are executed.
    assert!(!can_be_executed(&mut h, timelock_addr, &hash_a));
    assert!(!can_be_executed(&mut h, timelock_addr, &hash_b));
}

// ──────────────────────────────────────────────────────────────
// Test 10 (M5) — creator cancels transaction when executor list is non-empty
// ──────────────────────────────────────────────────────────────

/// Cancellation is allowed by any creator or executor at any time.
/// Verify that a creator can cancel even when a dedicated executor list is set.
///
///   1. Create timelock with creator + dedicated executor.
///   2. Creator proposes a transaction.
///   3. Creator cancels it via `cancel_transaction`.
///   4. can_be_executed returns false (executed = true after cancel).
///   5. Executor tries to run it → Discard (already executed/canceled).
#[test]
fn test_creator_cancels_when_executor_list_nonempty() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE003").unwrap());
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xE004").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    // Create timelock with a dedicated executor.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![*executor.address()]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt = salt32(b"cancel_by_creator");
    let hash = timelock_hash(&payload_bytes, &salt);

    // Propose.
    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    // Creator cancels before the delay elapses.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::cancel_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&hash).unwrap(),
        ],
    ));

    // Advance time — doesn't matter, the transaction is already canceled.
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // can_be_executed returns false because executed = true (canceled).
    assert!(
        !can_be_executed(&mut h, timelock_addr, &hash),
        "can_be_executed should be false — transaction was canceled",
    );

    // Executor tries to run the canceled transaction — prologue must reject.
    let status = h.run_timelock(
        &executor,
        timelock_addr,
        salt,
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    assert!(
        matches!(status, TransactionStatus::Discard(_)),
        "Expected Discard (ETRANSACTION_ALREADY_EXECUTED) for canceled tx, got {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 11 (L3) — duplicate salt is rejected
// ──────────────────────────────────────────────────────────────

/// Proposing two transactions with the same salt must fail on the second attempt.
/// Using a different salt for the same payload must succeed.
#[test]
fn test_duplicate_salt_rejected() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE005").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt = salt32(b"dup_salt_test");

    // First proposal — must succeed.
    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes.clone()),
        None,
        DELAY,
        salt.clone(),
    ));

    // Second proposal with same salt — must fail (EDUPLICATE_SALT).
    let status = propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes.clone()),
        None,
        DELAY,
        salt.clone(),
    );
    assert!(
        !matches!(status, TransactionStatus::Keep(aptos_types::transaction::ExecutionStatus::Success)),
        "Expected failure for duplicate salt, got: {:?}",
        status
    );

    // Different salt — must succeed.
    let salt2 = salt32(b"dup_salt_test_2");
    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt2,
    ));
}

// ──────────────────────────────────────────────────────────────
// Test 13 — payload mismatch is rejected in the prologue
// ──────────────────────────────────────────────────────────────

/// Propose a transaction with payload A stored on-chain, then attempt to execute it
/// while supplying a different payload B. The prologue should reject the transaction
/// with TIMELOCK_TRANSACTION_PAYLOAD_DOES_NOT_MATCH (Discard).
#[test]
fn test_timelock_transaction_payload_mismatch() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xF010").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    // Payload A — what is stored on-chain.
    let payload_a = make_noop_entry_function();
    let payload_a_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(payload_a)).unwrap();
    let salt = salt32(b"mismatch_salt");

    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_a_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Payload B — a different entry function submitted at execution time.
    let payload_b = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("account").to_owned()),
        ident_str!("create_account_if_does_not_exist").to_owned(),
        vec![],
        vec![bcs::to_bytes(&AccountAddress::new([0xCC; 32])).unwrap()],
    );

    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt,
        Some(TimelockTransactionPayload::EntryFunction(payload_b)),
    );
    assert!(
        matches!(status, aptos_types::transaction::TransactionStatus::Discard(_)),
        "Expected Discard (TIMELOCK_TRANSACTION_PAYLOAD_DOES_NOT_MATCH), got: {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 14 — executing against a non-timelock account is rejected
// ──────────────────────────────────────────────────────────────

/// Submitting a TimelockTransaction whose `timelock_address` does not have a
/// TimelockAccount resource must be rejected in the prologue with ACCOUNT_NOT_TIMELOCK.
#[test]
fn test_timelock_transaction_non_timelock_account() {
    let mut h = MoveHarness::new();
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xF020").unwrap());

    // Use the executor's own address — it is a regular account, not a timelock account.
    let fake_timelock_addr = *executor.address();
    let salt = salt32(b"no_timelock_salt");

    let status = h.run_timelock(
        &executor,
        fake_timelock_addr,
        salt,
        Some(TimelockTransactionPayload::EntryFunction(make_noop_entry_function())),
    );
    assert!(
        matches!(status, aptos_types::transaction::TransactionStatus::Discard(_)),
        "Expected Discard (ACCOUNT_NOT_TIMELOCK), got: {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 15 — executing a salt that was never proposed is rejected
// ──────────────────────────────────────────────────────────────

/// Submitting a TimelockTransaction with a salt that has no corresponding on-chain
/// proposal must be rejected in the prologue with TIMELOCK_TRANSACTION_NOT_FOUND.
#[test]
fn test_timelock_transaction_salt_not_found() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xF030").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    // Create the timelock account but do NOT propose any transaction.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Attempt to execute with a salt that was never proposed.
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt32(b"ghost_salt"),
        Some(TimelockTransactionPayload::EntryFunction(make_noop_entry_function())),
    );
    assert!(
        matches!(status, aptos_types::transaction::TransactionStatus::Discard(_)),
        "Expected Discard (TIMELOCK_TRANSACTION_NOT_FOUND), got: {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 12 (L4) — non-creator cannot propose a transaction
// ──────────────────────────────────────────────────────────────

/// An address that is not in the creator list must be rejected when trying to
/// call `create_transaction`. The Move assertion (ENOT_CREATOR) causes the
/// transaction to abort with a non-success execution status.
#[test]
fn test_non_creator_cannot_propose() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xE006").unwrap());
    let non_creator = h.new_account_at(AccountAddress::from_hex_literal("0xE007").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn)).unwrap();
    let salt = salt32(b"non_creator_salt");
    let hash = timelock_hash(&payload_bytes, &salt);

    // Non-creator attempts to propose — must fail.
    let status = propose_timelock_transaction(
        &mut h,
        &non_creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt.clone(),
    );
    assert!(
        !matches!(status, TransactionStatus::Keep(aptos_types::transaction::ExecutionStatus::Success)),
        "Expected ENOT_CREATOR failure for non-creator propose, got: {:?}",
        status
    );

    // Verify no transaction was stored (the table should not contain the salt).
    // We do this by trying to read can_be_executed — it returns false (salt not present).
    assert!(
        !can_be_executed(&mut h, timelock_addr, &hash),
        "No transaction should have been stored after rejected proposal",
    );
}

// ──────────────────────────────────────────────────────────────
// Test 16 — dedicated executor (not creator) runs a TimelockTransaction
// ──────────────────────────────────────────────────────────────

/// A timelock account with a dedicated executor list: the creator proposes, but only
/// the executor (not the creator) is allowed to submit the TimelockTransaction.
///
///   1. Create timelock with creator and a dedicated executor.
///   2. Creator proposes a transaction.
///   3. Advance time past delay.
///   4. Dedicated executor submits the TimelockTransaction → success.
///   5. Creator tries to execute the same (already-executed) hash → Discard.
#[test]
fn test_dedicated_executor_runs_timelock_transaction() {
    let mut h = MoveHarness::new();

    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA100").unwrap());
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xA101").unwrap());

    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    // Create timelock: creator can propose, executor can execute (creator cannot).
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![*executor.address()]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    // Verify: executor list is non-empty, so creator is NOT an executor.
    assert!(
        !is_executor_view(&mut h, *creator.address(), timelock_addr),
        "creator should not be executor when executor list is non-empty",
    );
    assert!(
        is_executor_view(&mut h, *executor.address(), timelock_addr),
        "executor should be recognized as executor",
    );

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt = salt32(b"dedicated_executor_salt");
    let hash = timelock_hash(&payload_bytes, &salt);

    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Dedicated executor submits the TimelockTransaction — must succeed.
    let status = h.run_timelock(
        &executor,
        timelock_addr,
        salt.clone(),
        Some(TimelockTransactionPayload::EntryFunction(entry_fn.clone())),
    );
    assert_success!(status);

    // Transaction is now executed — can_be_executed must return false.
    assert!(
        !can_be_executed(&mut h, timelock_addr, &hash),
        "can_be_executed should be false after execution",
    );

    // Creator now tries to run the same (already-executed) hash → prologue reject.
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt,
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    assert!(
        matches!(status, aptos_types::transaction::TransactionStatus::Discard(_)),
        "Expected Discard: creator cannot run already-executed tx, got: {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 17 — self-governance: add_creators via TimelockTransaction
// ──────────────────────────────────────────────────────────────

/// Full VM path for the self-governance add_creators entry function.
///
///   1. Alice creates timelock (sole creator, no executors).
///   2. Alice proposes `timelock::add_creators([bob])` via a TimelockTransaction.
///   3. Time advances.
///   4. Alice (executor) submits the TimelockTransaction.
///      The VM uses the timelock's signer_cap to call add_creators as the timelock signer.
///   5. Bob is now a creator and can propose transactions.
#[test]
fn test_self_governance_add_creators() {
    let mut h = MoveHarness::new();

    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA200").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xA201").unwrap());
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    assert!(!is_creator_view(&mut h, *bob.address(), timelock_addr));

    // Build the add_creators payload: the timelock signer is injected by the VM,
    // so we only encode `new_creators: vector<address>`.
    let add_creators_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("timelock").to_owned()),
        ident_str!("add_creators").to_owned(),
        vec![],
        vec![bcs::to_bytes::<Vec<AccountAddress>>(&vec![*bob.address()]).unwrap()],
    );
    let governance_payload = TimelockTransactionPayload::EntryFunction(add_creators_fn.clone());
    let governance_payload_bytes = bcs::to_bytes(&governance_payload).unwrap();
    let salt = salt32(b"add_creators_salt");

    assert_success!(propose_timelock_transaction(
        &mut h,
        &alice,
        timelock_addr,
        Some(governance_payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Alice executes the governance TimelockTransaction.
    let status = h.run_timelock(&alice, timelock_addr, salt, Some(governance_payload));
    assert_success!(status);

    // Bob is now a creator.
    assert!(
        is_creator_view(&mut h, *bob.address(), timelock_addr),
        "bob should be a creator after add_creators governance tx",
    );

    // Bob can propose a transaction.
    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn)).unwrap();
    let bob_salt = salt32(b"bob_first_proposal");
    let status = propose_timelock_transaction(
        &mut h,
        &bob,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        bob_salt,
    );
    assert_success!(status);
}

// ──────────────────────────────────────────────────────────────
// Test 18 — self-governance: remove_creators via TimelockTransaction
// ──────────────────────────────────────────────────────────────

/// Full VM path for the self-governance remove_creators entry function.
///
///   1. Alice creates timelock with herself and Bob as creators.
///   2. Alice proposes `timelock::remove_creators([alice])`.
///   3. Bob executes (also creator, empty executor list).
///   4. Alice is no longer a creator; Bob still is.
#[test]
fn test_self_governance_remove_creators() {
    let mut h = MoveHarness::new();

    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA300").unwrap());
    let bob = h.new_account_at(AccountAddress::from_hex_literal("0xA301").unwrap());
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    const DELAY: u64 = 3700;

    // Alice creates timelock with Bob as an additional creator.
    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![*bob.address()]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    assert!(is_creator_view(&mut h, *alice.address(), timelock_addr));
    assert!(is_creator_view(&mut h, *bob.address(), timelock_addr));

    // Build the remove_creators payload targeting Alice.
    let remove_creators_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("timelock").to_owned()),
        ident_str!("remove_creators").to_owned(),
        vec![],
        vec![bcs::to_bytes::<Vec<AccountAddress>>(&vec![*alice.address()]).unwrap()],
    );
    let governance_payload = TimelockTransactionPayload::EntryFunction(remove_creators_fn);
    let governance_payload_bytes = bcs::to_bytes(&governance_payload).unwrap();
    let salt = salt32(b"remove_alice_salt");

    // Alice proposes her own removal.
    assert_success!(propose_timelock_transaction(
        &mut h,
        &alice,
        timelock_addr,
        Some(governance_payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Bob submits the TimelockTransaction (he is also a creator and executor list is empty).
    let status = h.run_timelock(&bob, timelock_addr, salt, Some(governance_payload));
    assert_success!(status);

    // Alice is no longer a creator; Bob still is.
    assert!(
        !is_creator_view(&mut h, *alice.address(), timelock_addr),
        "alice should have been removed from creators",
    );
    assert!(
        is_creator_view(&mut h, *bob.address(), timelock_addr),
        "bob should still be a creator",
    );
}

// ──────────────────────────────────────────────────────────────
// Test 19 — self-governance: add_executors via TimelockTransaction
// ──────────────────────────────────────────────────────────────

/// Full VM path for the self-governance add_executors entry function.
///
///   1. Alice creates timelock (sole creator, no executors).
///   2. Alice proposes `timelock::add_executors([charlie])`.
///   3. Alice executes (executor list still empty at proposal time).
///   4. Charlie is now an executor — the executor list is non-empty.
///   5. Alice (creator) is no longer executor; Charlie is.
///   6. Charlie executes a subsequent TimelockTransaction successfully.
#[test]
fn test_self_governance_add_executors() {
    let mut h = MoveHarness::new();

    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA400").unwrap());
    let charlie = h.new_account_at(AccountAddress::from_hex_literal("0xA401").unwrap());
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    // Before governance tx: Alice is executor (empty executor list → creator fallback).
    assert!(is_executor_view(&mut h, *alice.address(), timelock_addr));
    assert!(!is_executor_view(&mut h, *charlie.address(), timelock_addr));

    let add_executors_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("timelock").to_owned()),
        ident_str!("add_executors").to_owned(),
        vec![],
        vec![bcs::to_bytes::<Vec<AccountAddress>>(&vec![*charlie.address()]).unwrap()],
    );
    let governance_payload = TimelockTransactionPayload::EntryFunction(add_executors_fn);
    let governance_payload_bytes = bcs::to_bytes(&governance_payload).unwrap();
    let salt = salt32(b"add_executors_salt");

    assert_success!(propose_timelock_transaction(
        &mut h,
        &alice,
        timelock_addr,
        Some(governance_payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Alice executes (executor list still empty at this point → creator fallback).
    let status = h.run_timelock(&alice, timelock_addr, salt, Some(governance_payload));
    assert_success!(status);

    // After governance: executor list is now [charlie]; creator fallback no longer applies.
    assert!(
        is_executor_view(&mut h, *charlie.address(), timelock_addr),
        "charlie should now be an executor",
    );
    assert!(
        !is_executor_view(&mut h, *alice.address(), timelock_addr),
        "alice should no longer be executor (executor list is non-empty)",
    );

    // Charlie executes a subsequent TimelockTransaction.
    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt2 = salt32(b"charlie_executes");

    assert_success!(propose_timelock_transaction(
        &mut h,
        &alice,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt2.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    let status = h.run_timelock(
        &charlie,
        timelock_addr,
        salt2,
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    assert_success!(status);
}

// ──────────────────────────────────────────────────────────────
// Test 20 — self-governance: remove_executors via TimelockTransaction
// ──────────────────────────────────────────────────────────────

/// Full VM path for the self-governance remove_executors entry function.
///
///   1. Alice creates timelock with Eve as dedicated executor.
///   2. Alice proposes `timelock::remove_executors([eve])`.
///   3. Eve executes the governance TimelockTransaction.
///   4. Executor list is now empty → Alice (creator) can execute again.
///   5. Eve can no longer execute.
#[test]
fn test_self_governance_remove_executors() {
    let mut h = MoveHarness::new();

    let alice = h.new_account_at(AccountAddress::from_hex_literal("0xA500").unwrap());
    let eve = h.new_account_at(AccountAddress::from_hex_literal("0xA501").unwrap());
    let timelock_addr = timelock_account_address(*alice.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![*eve.address()]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    assert!(is_executor_view(&mut h, *eve.address(), timelock_addr));
    assert!(!is_executor_view(&mut h, *alice.address(), timelock_addr));

    let remove_executors_fn = EntryFunction::new(
        ModuleId::new(CORE_CODE_ADDRESS, ident_str!("timelock").to_owned()),
        ident_str!("remove_executors").to_owned(),
        vec![],
        vec![bcs::to_bytes::<Vec<AccountAddress>>(&vec![*eve.address()]).unwrap()],
    );
    let governance_payload = TimelockTransactionPayload::EntryFunction(remove_executors_fn);
    let governance_payload_bytes = bcs::to_bytes(&governance_payload).unwrap();
    let salt = salt32(b"remove_executors_salt");

    assert_success!(propose_timelock_transaction(
        &mut h,
        &alice,
        timelock_addr,
        Some(governance_payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Eve executes the governance tx (she is still the executor at this point).
    let status = h.run_timelock(&eve, timelock_addr, salt, Some(governance_payload));
    assert_success!(status);

    // Executor list is now empty → Alice (creator) is executor again.
    assert!(
        is_executor_view(&mut h, *alice.address(), timelock_addr),
        "alice should be executor again once executor list is empty",
    );
    assert!(
        !is_executor_view(&mut h, *eve.address(), timelock_addr),
        "eve should no longer be executor",
    );

    // Alice executes a subsequent TimelockTransaction — must succeed.
    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt2 = salt32(b"alice_executes_after_remove");

    assert_success!(propose_timelock_transaction(
        &mut h,
        &alice,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt2.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    let status = h.run_timelock(
        &alice,
        timelock_addr,
        salt2.clone(),
        Some(TimelockTransactionPayload::EntryFunction(entry_fn.clone())),
    );
    assert_success!(status);

    // Eve tries to execute a new transaction — should be rejected (no longer executor).
    let salt3 = salt32(b"eve_tries_after_remove");
    assert_success!(propose_timelock_transaction(
        &mut h,
        &alice,
        timelock_addr,
        Some(bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap()),
        None,
        DELAY,
        salt3.clone(),
    ));

    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    let status = h.run_timelock(
        &eve,
        timelock_addr,
        salt3,
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    assert!(
        matches!(status, aptos_types::transaction::TransactionStatus::Discard(_)),
        "Expected Discard: eve is no longer an executor, got: {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 21 — executor cancels a pending transaction (entry function path)
// ──────────────────────────────────────────────────────────────

/// A dedicated executor calls `cancel_transaction` via an entry-function transaction,
/// then verifies that the TimelockTransaction can no longer be executed.
///
///   1. Create timelock with creator and dedicated executor.
///   2. Creator proposes a transaction.
///   3. Executor cancels via `cancel_transaction` entry function.
///   4. `can_be_executed` returns false (executed = true from cancellation).
///   5. After delay, executor tries to run the canceled transaction → Discard.
#[test]
fn test_executor_cancels_transaction() {
    let mut h = MoveHarness::new();

    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA600").unwrap());
    let executor = h.new_account_at(AccountAddress::from_hex_literal("0xA601").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![*executor.address()]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt = salt32(b"executor_cancel_salt");
    let hash = timelock_hash(&payload_bytes, &salt);

    assert_success!(propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        DELAY,
        salt.clone(),
    ));

    // Executor cancels before the delay elapses.
    assert_success!(h.run_entry_function(
        &executor,
        str::parse("0x1::timelock::cancel_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&hash).unwrap(),
        ],
    ));

    // can_be_executed must return false (executed = true via cancellation).
    assert!(
        !can_be_executed(&mut h, timelock_addr, &hash),
        "can_be_executed should be false after cancellation",
    );

    // Advance time past delay — the transaction is already canceled, must still be rejected.
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    let status = h.run_timelock(
        &executor,
        timelock_addr,
        salt,
        Some(TimelockTransactionPayload::EntryFunction(entry_fn)),
    );
    assert!(
        matches!(status, aptos_types::transaction::TransactionStatus::Discard(_)),
        "Expected Discard (ETRANSACTION_ALREADY_EXECUTED) for canceled tx, got: {:?}",
        status
    );
}

// ──────────────────────────────────────────────────────────────
// Test 22 — creating a timelock with num_seconds_execute <= 360 fails
// ──────────────────────────────────────────────────────────────

/// The minimum timelock delay enforced on-chain is > 360 seconds.
/// Creating with delay = 360 must fail; delay = 361 must succeed.
#[test]
fn test_create_timelock_below_min_delay_fails() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA700").unwrap());

    // delay = 360 → must fail (ENUMBER_SECONDS_TOO_SMALL, error code 14).
    let status = h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&360u64).unwrap(),
        ],
    );
    assert!(
        !matches!(
            status,
            aptos_types::transaction::TransactionStatus::Keep(
                aptos_types::transaction::ExecutionStatus::Success
            )
        ),
        "Expected failure for delay=360, got: {:?}",
        status
    );

    // delay = 361 → must succeed (boundary: delay > 360).
    let creator2 = h.new_account_at(AccountAddress::from_hex_literal("0xA702").unwrap());
    assert_success!(h.run_entry_function(
        &creator2,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&361u64).unwrap(),
        ],
    ));
}

// ──────────────────────────────────────────────────────────────
// Test 23 — proposing a transaction with num_seconds_execute below minimum fails
// ──────────────────────────────────────────────────────────────

/// `create_transaction` must reject any proposal whose `num_seconds_execute` is
/// strictly less than the account's `min_num_seconds_execute`.
#[test]
fn test_propose_transaction_below_min_delay_fails() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA800").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const MIN_DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&MIN_DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn.clone())).unwrap();
    let salt = salt32(b"below_min_delay_salt");

    // Propose with num_seconds_execute = MIN_DELAY - 1 → must fail.
    let status = propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes.clone()),
        None,
        MIN_DELAY - 1,
        salt.clone(),
    );
    assert!(
        !matches!(
            status,
            aptos_types::transaction::TransactionStatus::Keep(
                aptos_types::transaction::ExecutionStatus::Success
            )
        ),
        "Expected failure for num_seconds_execute < min_delay, got: {:?}",
        status
    );

    // Propose with exactly MIN_DELAY → must succeed.
    let salt2 = salt32(b"exact_min_delay_salt");
    let status = propose_timelock_transaction(
        &mut h,
        &creator,
        timelock_addr,
        Some(payload_bytes),
        None,
        MIN_DELAY,
        salt2,
    );
    assert_success!(status);
}

// ──────────────────────────────────────────────────────────────
// Test 24 — create_transaction with invalid salt length fails
// ──────────────────────────────────────────────────────────────

/// Salts must be exactly 32 bytes. Shorter or longer salts must be rejected
/// (error::invalid_argument(EINVALID_BYTES_LENGTH)).
#[test]
fn test_create_transaction_invalid_salt_length_fails() {
    let mut h = MoveHarness::new();
    let creator = h.new_account_at(AccountAddress::from_hex_literal("0xA900").unwrap());
    let timelock_addr = timelock_account_address(*creator.address(), 10);
    const DELAY: u64 = 3700;

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create").unwrap(),
        vec![],
        vec![
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes::<Vec<AccountAddress>>(&vec![]).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
        ],
    ));

    let entry_fn = make_noop_entry_function();
    let payload_bytes =
        bcs::to_bytes(&TimelockTransactionPayload::EntryFunction(entry_fn)).unwrap();

    // Salt too short (< 32 bytes) → must fail.
    let short_salt: Vec<u8> = b"short".to_vec();
    let status = h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&short_salt).unwrap(),
        ],
    );
    assert!(
        !matches!(
            status,
            aptos_types::transaction::TransactionStatus::Keep(
                aptos_types::transaction::ExecutionStatus::Success
            )
        ),
        "Expected failure for salt.len() < 32, got: {:?}",
        status
    );

    // Salt too long (> 32 bytes) → must fail.
    let long_salt: Vec<u8> = vec![0u8; 33];
    let status = h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&long_salt).unwrap(),
        ],
    );
    assert!(
        !matches!(
            status,
            aptos_types::transaction::TransactionStatus::Keep(
                aptos_types::transaction::ExecutionStatus::Success
            )
        ),
        "Expected failure for salt.len() > 32, got: {:?}",
        status
    );

    // Exactly 32 bytes → must succeed.
    let valid_salt = salt32(b"valid_salt_exactly_32");
    let status = h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&valid_salt).unwrap(),
        ],
    );
    assert_success!(status);
}

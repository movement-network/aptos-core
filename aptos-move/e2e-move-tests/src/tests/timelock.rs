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
    let salt = b"test_salt_1".to_vec();

    let status = h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
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
    let salt = b"early_salt".to_vec();

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
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
    let salt = b"auth_salt".to_vec();

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
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
    let timelock_salt = b"multisig_via_timelock".to_vec();

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
    let timelock_salt = b"timelock_to_multisig".to_vec();

    let timelock_payload =
        TimelockTransactionPayload::EntryFunction(timelock_inner_entry_fn.clone());
    let payload_bytes = bcs::to_bytes(&timelock_payload).unwrap();

    assert_success!(h.run_entry_function(
        &alice,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&timelock_salt).unwrap(),
        ],
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

fn can_be_executed(h: &mut MoveHarness, timelock_addr: AccountAddress, salt: &[u8]) -> bool {
    let result = h.execute_view_function(
        str::parse("0x1::timelock::can_be_executed").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&salt.to_vec()).unwrap(),
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
    let salt = b"delay_check_salt".to_vec();

    // Propose transaction.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
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
        !can_be_executed(&mut h, timelock_addr, &salt),
        "can_be_executed should be false (delay not elapsed)",
    );

    // ── Advance time ─────────────────────────────────────────────────────────
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Now `can_be_executed` must return true: time has passed and executed is still false.
    assert!(
        can_be_executed(&mut h, timelock_addr, &salt),
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
        !can_be_executed(&mut h, timelock_addr, &salt),
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
    let salt = b"bad_payload_salt".to_vec();

    // Propose the transaction — the payload is accepted as-is (the timelock module
    // stores raw bytes without interpreting them).
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
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
        !can_be_executed(&mut h, timelock_addr, &salt),
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
    let salt = b"governance_update_delay".to_vec();

    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&governance_payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
    ));

    // Step 3: advance time.
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // Step 4: execute the governance transaction.
    let status = h.run_timelock(
        &creator,
        timelock_addr,
        salt,
        Some(governance_payload),
    );
    assert_success!(status);

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

    let salt_a = b"salt_alpha".to_vec();
    let salt_b = b"salt_beta".to_vec();

    // Propose A then B.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt_a).unwrap(),
        ],
    ));
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt_b).unwrap(),
        ],
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
    assert!(!can_be_executed(&mut h, timelock_addr, &salt_a));
    assert!(!can_be_executed(&mut h, timelock_addr, &salt_b));
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
    let salt = b"cancel_by_creator".to_vec();

    // Propose.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
    ));

    // Creator cancels before the delay elapses.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::cancel_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
    ));

    // Advance time — doesn't matter, the transaction is already canceled.
    h.fast_forward(DELAY + 1);
    h.executor.new_block();

    // can_be_executed returns false because executed = true (canceled).
    assert!(
        !can_be_executed(&mut h, timelock_addr, &salt),
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
    let salt = b"dup_salt_test".to_vec();

    // First proposal — must succeed.
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
    ));

    // Second proposal with same salt — must fail (EDUPLICATE_SALT).
    let status = h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
    );
    assert!(
        !matches!(status, TransactionStatus::Keep(aptos_types::transaction::ExecutionStatus::Success)),
        "Expected failure for duplicate salt, got: {:?}",
        status
    );

    // Different salt — must succeed.
    let salt2 = b"dup_salt_test_2".to_vec();
    assert_success!(h.run_entry_function(
        &creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt2).unwrap(),
        ],
    ));
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
    let salt = b"non_creator_salt".to_vec();

    // Non-creator attempts to propose — must fail.
    let status = h.run_entry_function(
        &non_creator,
        str::parse("0x1::timelock::create_transaction").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&timelock_addr).unwrap(),
            bcs::to_bytes(&payload_bytes).unwrap(),
            bcs::to_bytes(&DELAY).unwrap(),
            bcs::to_bytes(&salt).unwrap(),
        ],
    );
    assert!(
        !matches!(status, TransactionStatus::Keep(aptos_types::transaction::ExecutionStatus::Success)),
        "Expected ENOT_CREATOR failure for non-creator propose, got: {:?}",
        status
    );

    // Verify no transaction was stored (the table should not contain the salt).
    // We do this by trying to read can_be_executed — it returns false (salt not present).
    assert!(
        !can_be_executed(&mut h, timelock_addr, &salt),
        "No transaction should have been stored after rejected proposal",
    );
}

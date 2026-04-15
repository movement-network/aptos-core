// Oracle fragment for `move-lean-difftest merge` — see `confidential_asset_e2e.rs` and formal difftest README.
// Loaded via `#[path = "..."] mod oracle` so `use super::*` reaches the parent module's helpers.

use aptos_types::transaction::{ExecutionStatus, TransactionStatus};
use move_core_types::vm_status::VMStatus;
use move_lean_difftest::oracle_row::vm_lean_row;
use move_lean_difftest::schema::{OracleFragment, TestCase, TestResult};
use move_lean_difftest::typed_value::{make_bool, make_u64};
use std::path::{Path, PathBuf};

use super::*;

fn txn_outcome(status: &TransactionStatus) -> TestResult {
    match status {
        TransactionStatus::Keep(ExecutionStatus::Success) => TestResult::Returned { values: vec![] },
        TransactionStatus::Keep(ExecutionStatus::MoveAbort { code, .. }) => {
            TestResult::Aborted { abort_code: *code }
        },
        TransactionStatus::Keep(_) => TestResult::Aborted {
            abort_code: 0xFFFF_FFFF_FFFF_FFFE,
        },
        _ => TestResult::Aborted {
            abort_code: 0xFFFF_FFFF_FFFF_FFFF,
        },
    }
}

/// Outcome of **`try_exec_function_bypass_at`** on **`0x7::confidential_asset`** (used when there is no `entry` wrapper).
fn bypass_outcome(h: &mut MoveHarness, fun: &str, args: Vec<Vec<u8>>) -> TestResult {
    match h.executor.try_exec_function_bypass_at(
        super::APTOS_EXPERIMENTAL,
        "confidential_asset",
        fun,
        vec![],
        args,
    ) {
        Ok(_) => TestResult::Returned { values: vec![] },
        Err(VMStatus::MoveAbort(_, code)) => TestResult::Aborted { abort_code: code },
        Err(_) => TestResult::Aborted {
            abort_code: 0xFFFF_FFFF_FFFF_FFFE,
        },
    }
}

fn success_row(test_fn: &'static str) -> TestCase {
    vm_lean_row(
        format!("confidential_asset_e2e::{test_fn}"),
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )
}

/// Register → deposit → `rollover_pending_balance_and_freeze` (VM path not covered by a dedicated row elsewhere).
pub(super) fn rollover_and_freeze_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xE9, 1);
    let account = h.new_account_with_balance_at(u, 35_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &comm, &resp), "register");

    assert_kept_success(&run_deposit(&mut h, &account, 3_333), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    vec![success_row("confidential_asset_rollover_and_freeze_only")]
}

/// `rollover_pending_balance_and_freeze` then `rotate_encryption_key_and_unfreeze` — VM exercises rotate + `unfreeze_token` in one entry transaction.
pub(super) fn rotate_encryption_key_and_unfreeze_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 1);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &comm, &resp), "register");

    let deposit_amt: u64 = 4_200;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    vec![success_row("confidential_asset_rotate_encryption_key_and_unfreeze_only")]
}

/// `rollover_pending_balance_and_freeze` then **`rotate_encryption_key`** only (token may stay frozen — distinct combined entry).
pub(super) fn rotate_encryption_key_after_freeze_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 1);
    let account = h.new_account_with_balance_at(u, 44_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &comm, &resp), "register");

    let deposit_amt: u64 = 3_777;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    vec![success_row("confidential_asset_rotate_encryption_key_after_freeze_only")]
}

/// Register → deposit → `freeze_token` → `unfreeze_token` (standalone governance-style freeze, not rollover+freeze).
pub(super) fn freeze_then_unfreeze_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEB, 1);
    let account = h.new_account_with_balance_at(u, 38_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &comm, &resp), "register");
    assert_kept_success(&run_deposit(&mut h, &account, 2_000), "deposit");
    assert_kept_success(&run_freeze_token(&mut h, &account), "freeze_token");
    assert_kept_success(&run_unfreeze_token(&mut h, &account), "unfreeze_token");

    vec![success_row("confidential_asset_freeze_then_unfreeze_only")]
}

/// Register → deposit → `rollover_pending_balance` (denormalize) → `normalize` with VM `verify_normalization_proof`.
pub(super) fn rollover_then_normalize_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 1);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &comm, &resp), "register");

    let deposit_amt: u64 = 555;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover(&mut h, &account),
        "rollover_pending_balance",
    );

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    vec![success_row("confidential_asset_rollover_then_normalize_only")]
}

/// After `rollover_pending_balance`, `confidential_asset::is_normalized` is **`false`** until `normalize`.
pub(super) fn is_normalized_false_after_rollover_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF3, 1);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &comm, &resp), "register");
    assert_kept_success(&run_deposit(&mut h, &account, 888), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_normalized",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let normalized: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_normalized bool");
    assert!(
        !normalized,
        "expected is_normalized false after rollover (got {normalized})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_normalized_false_after_rollover_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After `freeze_token`, `is_frozen` must read **`true`** (`#[view]` on real store).
pub(super) fn is_frozen_true_after_freeze_token_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF4, 1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");
    assert_kept_success(&run_deposit(&mut h, &account, 100), "deposit");
    assert_kept_success(&run_freeze_token(&mut h, &account), "freeze_token");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_frozen",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let frozen: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_frozen bool");
    assert!(frozen, "expected is_frozen true after freeze_token (got {frozen})");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_frozen_true_after_freeze_token_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )]
}

/// `has_confidential_asset_store` is **`false`** before `register` for a fresh address.
pub(super) fn has_confidential_asset_store_false_before_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let u = confidential_e2e_addr(0xF5, 1);
    let _account = h.new_account_with_balance_at(u, 40_000_000_000_000);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "has_confidential_asset_store",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let has: bool = bcs::from_bytes(&ret.return_values[0].0).expect("has_confidential_asset_store bool");
    assert!(
        !has,
        "expected has_confidential_asset_store false before register (got {has})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_has_confidential_asset_store_false_before_register_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After `register`, **`encryption_key`** BCS round-trips to the same **32**-byte compressed point as **`pubkey_to_bytes(ek_struct)`** (VM `#[view]` on real store).
pub(super) fn encryption_key_view_matches_registered_ek_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 7);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "encryption_key",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let key_bcs = ret.return_values[0].0.clone();
    let pb = bypass_at(
        &mut h,
        "ristretto255_twisted_elgamal",
        "pubkey_to_bytes",
        vec![],
        vec![key_bcs],
    );
    assert_eq!(pb.return_values.len(), 1);
    assert_eq!(
        pb.return_values[0].0, ek_pk,
        "encryption_key view should serialize to the registered compressed pubkey bytes"
    );

    vec![success_row(
        "confidential_asset_encryption_key_view_matches_registered_ek_only",
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, the **`encryption_key`**
/// `#[view]` BCS matches the **new** ElGamal compressed pubkey (not the pre-rotate key).
pub(super) fn encryption_key_view_matches_new_ek_after_deposit_rollover_and_rotate_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 8);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 2_112;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let new_ek_pk = twisted_pubkey_bytes(&mut h, &new_ek_struct);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "encryption_key",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let key_bcs = ret.return_values[0].0.clone();
    let pb = bypass_at(
        &mut h,
        "ristretto255_twisted_elgamal",
        "pubkey_to_bytes",
        vec![],
        vec![key_bcs],
    );
    assert_eq!(pb.return_values.len(), 1);
    assert_eq!(
        pb.return_values[0].0, new_ek_pk,
        "encryption_key view should match new compressed pubkey after rotate"
    );

    vec![success_row(
        "confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_and_rotate_only",
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_actual_balance`**
/// with the **new** decryption key and **`u128(actual)`** returns **`true`**.
pub(super) fn verify_actual_balance_matches_after_deposit_rollover_and_rotate_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 9);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 3_141;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&balance_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({balance_u128}) with new dk should succeed after rotate"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_rotate_only",
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_actual_balance`**
/// with the **pre-rotate** decryption key must return **`false`** (stale **`dk`**).
pub(super) fn verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_rotate_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 10);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 4_159;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&balance_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance with stale dk should fail after rotate (actual {balance_u128})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_pending_balance(0)`**
/// with the **new** decryption key returns **`true`**.
pub(super) fn verify_pending_balance_zero_after_deposit_rollover_and_rotate_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 11);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_271;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance(0) with new dk should succeed after rotate (pending cleared)"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_rotate_only",
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_pending_balance(1)`**
/// with the **pre-rotate** decryption key must return **`false`** (**pending** is **0**; claim is inconsistent).
pub(super) fn verify_pending_balance_rejects_nonzero_with_stale_dk_after_deposit_rollover_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 12);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 6_353;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&1u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(1) with stale dk should fail when pending is 0 after rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_stale_dk_after_deposit_rollover_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_pending_balance(1)`**
/// with the **new** decryption key must return **`false`** (**pending** is **0**).
pub(super) fn verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 14);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_171;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&1u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(1) with new dk should fail when pending is 0 after rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_actual_balance`**
/// with **`u128(actual−1)`** and the **new** decryption key must return **`false`**.
pub(super) fn verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 13);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 8_008;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let wrong: u128 = balance_u128.saturating_sub(1);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail with new dk when actual is {balance_u128} after rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_pending_balance`**
/// with the **pre-deposit** **`u64(deposit)`** and the **new** decryption key must return **`false`**
/// (**pending** was cleared at rollover; amount is **stale** as a pending claim).
pub(super) fn verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 15);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 9_191;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&deposit_amt).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(deposit_amt) with new dk should fail when pending is 0 after rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_actual_balance(0)`**
/// with the **new** decryption key must return **`false`** when **actual** is the deposited amount.
pub(super) fn verify_actual_balance_rejects_zero_after_deposit_rollover_and_rotate_when_actual_nonzero_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 16);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 8_282;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance(0) with new dk should fail when actual is {balance_u128} after rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_deposit_rollover_and_rotate_when_actual_nonzero_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_pending_balance(deposit−1)`**
/// with the **new** decryption key must return **`false`** (**pending** is **0**).
pub(super) fn verify_pending_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 17);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_373;
    let wrong_pending: u64 = deposit_amt - 1;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&wrong_pending).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({wrong_pending}) with new dk should fail when pending is 0 after rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`rotate_encryption_key`**, **`verify_actual_balance(actual+1)`**
/// with the **new** decryption key must return **`false`**.
pub(super) fn verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 18);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 6_262;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let too_high: u128 = balance_u128 + 1;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&too_high).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({too_high}) should fail with new dk when actual is {balance_u128} after rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`deposit`** → **`rollover_pending_balance`** → **`withdraw`** → **`rotate_encryption_key`**:
/// **`verify_actual_balance`** with **new** **`dk`** and **`u128(pool)`** succeeds.
pub(super) fn verify_actual_balance_matches_after_deposit_rollover_withdraw_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 19);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 2_001;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w: u64 = 555;
    let pool: u128 = dep as u128 - w as u128;
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek_struct, w, pool);
    assert_kept_success(
        &run_withdraw(&mut h, &account, w, &nb, &z, &s),
        "withdraw before rotate",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        pool,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&pool).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({pool}) with new dk should succeed after withdraw+rotate"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_after_deposit_rollover_withdraw_and_rotate_only",
    )]
}

/// Same path as **`verify_actual_balance_matches_after_deposit_rollover_withdraw_and_rotate_only`**,
/// but **`verify_actual_balance`** with **stale** pre-rotate **`dk`** must return **`false`**.
pub(super) fn verify_actual_balance_rejects_stale_dk_after_deposit_rollover_withdraw_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 20);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 2_002;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w: u64 = 556;
    let pool: u128 = dep as u128 - w as u128;
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek_struct, w, pool);
    assert_kept_success(
        &run_withdraw(&mut h, &account, w, &nb, &z, &s),
        "withdraw before rotate",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        pool,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&pool).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance with stale dk should fail after withdraw+rotate (pool {pool})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_withdraw_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`verify_actual_balance(u128(sum))`** with **new** **`dk`** after **two** **`deposit`**s, **`rollover`**, **`rotate`**.
pub(super) fn verify_actual_balance_matches_sum_after_two_deposits_rollover_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 21);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 3_333;
    let d2: u64 = 4_444;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");
    let sum_u128: u128 = (d1 as u128).saturating_add(d2 as u128);

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        sum_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&sum_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({sum_u128}) with new dk should succeed after two deposits+rollover+rotate"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_sum_after_two_deposits_rollover_and_rotate_only",
    )]
}

/// After **two** **`deposit`**s + **`rollover`** + **`rotate`**, **`verify_pending_balance(sum)`** with **new** **`dk`**
/// must return **`false`** (**pending** is **0**).
pub(super) fn verify_pending_balance_rejects_stale_sum_after_two_deposits_rollover_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 22);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 2_222;
    let d2: u64 = 3_333;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");
    let sum_u64: u64 = d1.saturating_add(d2);
    let sum_u128: u128 = sum_u64 as u128;

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        sum_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&sum_u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({sum_u64}) with new dk should fail when pending is 0 after rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_sum_after_two_deposits_rollover_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`deposit`** → **`rollover`** → **`withdraw`** → **`rotate`**: **`verify_pending_balance(0)`** with **new** **`dk`** succeeds.
pub(super) fn verify_pending_balance_zero_after_deposit_rollover_withdraw_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 23);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 3_003;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w: u64 = 1_001;
    let pool: u128 = dep as u128 - w as u128;
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek_struct, w, pool);
    assert_kept_success(
        &run_withdraw(&mut h, &account, w, &nb, &z, &s),
        "withdraw before rotate",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        pool,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance(0) with new dk should succeed after withdraw+rotate"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_zero_after_deposit_rollover_withdraw_and_rotate_only",
    )]
}

/// After **`deposit`** + **`rollover`** + **`withdraw`** + **`rotate`**, **`verify_actual_balance(pool+1)`** with **new** **`dk`**
/// must return **`false`**.
pub(super) fn verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_withdraw_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 24);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 4_004;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w: u64 = 1_004;
    let pool: u128 = dep as u128 - w as u128;
    let wrong: u128 = pool.saturating_add(1);
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek_struct, w, pool);
    assert_kept_success(
        &run_withdraw(&mut h, &account, w, &nb, &z, &s),
        "withdraw before rotate",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        pool,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail when pool is {pool} after withdraw+rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_withdraw_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`deposit`** → **`rollover_pending_balance`** → **`normalize`** → **`rotate_encryption_key`**:
/// **`verify_actual_balance`** with **new** **`dk`** and **`u128(actual)`** succeeds.
pub(super) fn verify_actual_balance_matches_after_deposit_rollover_normalize_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 25);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_055;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr2, sig2) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        amt_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr2, &sig2),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&amt_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({amt_u128}) with new dk should succeed after normalize+rotate"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_after_deposit_rollover_normalize_and_rotate_only",
    )]
}

/// After **`deposit`** → **`rollover`** → **`normalize`** → **`rotate`**, **`encryption_key`** view matches the **new** EK bytes.
pub(super) fn encryption_key_view_matches_new_ek_after_deposit_rollover_normalize_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 26);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 6_066;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let new_ek_pk = twisted_pubkey_bytes(&mut h, &new_ek_struct);
    let (nek_bytes, nbal, zkr2, sig2) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        amt_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr2, &sig2),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "encryption_key",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let key_bcs = ret.return_values[0].0.clone();
    let pb = bypass_at(
        &mut h,
        "ristretto255_twisted_elgamal",
        "pubkey_to_bytes",
        vec![],
        vec![key_bcs],
    );
    assert_eq!(pb.return_values.len(), 1);
    assert_eq!(
        pb.return_values[0].0, new_ek_pk,
        "encryption_key view should match new compressed pubkey after normalize+rotate"
    );

    vec![success_row(
        "confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_normalize_and_rotate_only",
    )]
}

/// After **`deposit`** → **`rollover`** → **`normalize`** → **`rotate`**, **`verify_pending_balance(0)`** with **new** **`dk`** succeeds.
pub(super) fn verify_pending_balance_zero_after_deposit_rollover_normalize_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 27);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_077;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr2, sig2) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        amt_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr2, &sig2),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance(0) with new dk should succeed after normalize+rotate"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_zero_after_deposit_rollover_normalize_and_rotate_only",
    )]
}

/// After **`normalize`** + **`rotate`**, **`verify_actual_balance`** with **stale** pre-rotate **`dk`** must return **`false`**.
pub(super) fn verify_actual_balance_rejects_stale_dk_after_deposit_rollover_normalize_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 28);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 8_088;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr2, sig2) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        amt_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr2, &sig2),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&amt_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance with stale dk should fail after normalize+rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_normalize_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`normalize`** + **`rotate`**, **`verify_pending_balance(1)`** with **new** **`dk`** must return **`false`**.
pub(super) fn verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_normalize_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 29);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 9_099;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr2, sig2) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        amt_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr2, &sig2),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&1u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(1) with new dk should fail when pending is 0 after normalize+rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_normalize_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`normalize`** + **`rotate`**, **`verify_actual_balance(actual−1)`** with **new** **`dk`** must return **`false`**.
pub(super) fn verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_normalize_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 30);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 10_010;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let wrong: u128 = amt_u128.saturating_sub(1);
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr2, sig2) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        amt_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr2, &sig2),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail with new dk when actual is {amt_u128} after normalize+rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_normalize_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`deposit`** → **`rollover_pending_balance_and_freeze`** → **`rotate_encryption_key`** (no unfreeze):
/// **`verify_actual_balance`** with **new** **`dk`** and **`u128(deposit)`** succeeds.
pub(super) fn verify_actual_balance_matches_after_deposit_rollover_and_freeze_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 31);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 4_141;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&balance_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({balance_u128}) with new dk should succeed after rollover_and_freeze+rotate"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_freeze_and_rotate_only",
    )]
}

/// After **`rollover_pending_balance_and_freeze`** + **`rotate`**, **`encryption_key`** view matches the **new** EK.
pub(super) fn encryption_key_view_matches_new_ek_after_deposit_rollover_and_freeze_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 32);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_252;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let new_ek_pk = twisted_pubkey_bytes(&mut h, &new_ek_struct);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "encryption_key",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let key_bcs = ret.return_values[0].0.clone();
    let pb = bypass_at(
        &mut h,
        "ristretto255_twisted_elgamal",
        "pubkey_to_bytes",
        vec![],
        vec![key_bcs],
    );
    assert_eq!(pb.return_values.len(), 1);
    assert_eq!(
        pb.return_values[0].0, new_ek_pk,
        "encryption_key view should match new compressed pubkey after freeze+rotate"
    );

    vec![success_row(
        "confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_and_freeze_and_rotate_only",
    )]
}

/// After **`rollover_pending_balance_and_freeze`** + **`rotate`**, **`verify_pending_balance(0)`** with **new** **`dk`** succeeds.
pub(super) fn verify_pending_balance_zero_after_deposit_rollover_and_freeze_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 33);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 6_363;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance(0) with new dk should succeed after freeze+rotate"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_freeze_and_rotate_only",
    )]
}

/// After **`freeze`** path + **`rotate`**, **`verify_actual_balance`** with **stale** **`dk`** must return **`false`**.
pub(super) fn verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_freeze_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 34);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_474;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&balance_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance with stale dk should fail after freeze+rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_freeze_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`freeze`** path + **`rotate`**, **`verify_pending_balance(1)`** with **new** **`dk`** must return **`false`**.
pub(super) fn verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_freeze_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 35);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 8_585;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&1u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(1) with new dk should fail when pending is 0 after freeze+rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_freeze_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`deposit`** → **`rollover_pending_balance`** (no freeze) → second **`deposit`** leaves **pending** non-zero; **`rotate_encryption_key`** aborts (**`ENOT_ZERO_BALANCE`** pending gate).
pub(super) fn rotate_encryption_key_aborts_when_pending_nonzero_after_deposit_rollover_and_second_deposit_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 1);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 6_667;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover_pending_balance");
    assert_kept_success(&run_deposit(&mut h, &account, 2_222), "second deposit (pending non-zero)");

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    let st = run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig);
    assert!(
        matches!(
            &st,
            TransactionStatus::Keep(ExecutionStatus::MoveAbort { .. })
        ),
        "rotate_encryption_key: expected MoveAbort when pending non-zero, got {st:?}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_rotate_encryption_key_aborts_when_pending_nonzero_after_deposit_rollover_and_second_deposit_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// After **`rotate_encryption_key`** without unfreeze, **`is_frozen`** remains **`true`**.
pub(super) fn is_frozen_true_after_deposit_rollover_and_freeze_and_rotate_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 36);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 9_696;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_frozen",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let frozen: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_frozen bool");
    assert!(
        frozen,
        "expected is_frozen true after rotate without unfreeze (got {frozen})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_frozen_true_after_deposit_rollover_and_freeze_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )]
}

/// After **`freeze`** path + **`rotate`**, **`verify_actual_balance(actual−1)`** with **new** **`dk`** must return **`false`**.
pub(super) fn verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_freeze_and_rotate_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 37);
    let account = h.new_account_with_balance_at(u, 41_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 10_717;
    let balance_u128: u128 = deposit_amt as u128;
    let wrong: u128 = balance_u128.saturating_sub(1);
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail with new dk when actual is {balance_u128} after freeze+rotate"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_freeze_and_rotate_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`rollover_pending_balance_and_freeze`** → **`rotate_encryption_key_and_unfreeze`**, **`verify_actual_balance(deposit_amt)`** with **new** **`dk`** returns **`true`**.
pub(super) fn verify_actual_balance_matches_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 2);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_272;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&balance_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(ok, "verify_actual_balance should succeed with new dk after rotate+unfreeze");

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// After **`rotate_encryption_key_and_unfreeze`**, **`verify_pending_balance(0)`** with **new** **`dk`** returns **`true`**.
pub(super) fn verify_pending_balance_zero_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 3);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_272;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(ok, "verify_pending_balance(0) with new dk should succeed after rotate+unfreeze");

    vec![success_row(
        "confidential_asset_verify_pending_balance_zero_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// **`is_frozen`** is **`false`** after **`rotate_encryption_key_and_unfreeze`** on the freeze path.
pub(super) fn is_frozen_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 4);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_272;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_frozen",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let frozen: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_frozen bool");
    assert!(!frozen, "expected is_frozen false after rotate_encryption_key_and_unfreeze (got {frozen})");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_frozen_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`encryption_key`** view matches the **new** pubkey after **`rotate_encryption_key_and_unfreeze`**.
pub(super) fn encryption_key_view_matches_new_ek_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 5);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_272;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let new_ek_pk = twisted_pubkey_bytes(&mut h, &new_ek_struct);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "encryption_key",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let key_bcs = ret.return_values[0].0.clone();
    let pb = bypass_at(
        &mut h,
        "ristretto255_twisted_elgamal",
        "pubkey_to_bytes",
        vec![],
        vec![key_bcs],
    );
    assert_eq!(pb.return_values.len(), 1);
    assert_eq!(
        pb.return_values[0].0, new_ek_pk,
        "encryption_key view should match new compressed pubkey after rotate+unfreeze"
    );

    vec![success_row(
        "confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// **`verify_actual_balance`** with **stale** pre-rotate **`dk`** must return **`false`** after **`rotate_encryption_key_and_unfreeze`**.
pub(super) fn verify_actual_balance_rejects_stale_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 6);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_272;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&balance_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(!ok, "verify_actual_balance with stale dk should fail after rotate+unfreeze");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`verify_pending_balance(1)`** with **new** **`dk`** must return **`false`** (**pending** is **0** after rollover on this path).
pub(super) fn verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 7);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 7_272;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let balance_u128: u128 = deposit_amt as u128;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&1u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(!ok, "verify_pending_balance(1) should fail when pending is 0 after rotate+unfreeze");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`rotate_encryption_key_and_unfreeze`**, **`verify_actual_balance(actual−1)`** with **new** **`dk`** returns **`false`**.
pub(super) fn verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 8);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 9_181;
    let balance_u128: u128 = deposit_amt as u128;
    let wrong: u128 = balance_u128.saturating_sub(1);
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(!ok, "verify_actual_balance({wrong}) should fail with new dk after rotate+unfreeze");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`rotate_encryption_key_and_unfreeze`**, **`verify_actual_balance(actual+1)`** with **new** **`dk`** returns **`false`**.
pub(super) fn verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 9);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 11_919;
    let balance_u128: u128 = deposit_amt as u128;
    let wrong: u128 = balance_u128.saturating_add(1);
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(!ok, "verify_actual_balance({wrong}) should fail (off-by-one high) after rotate+unfreeze");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`rotate_encryption_key_and_unfreeze`**, **`is_normalized`** reads **`true`** (**`rotate_encryption_key_internal`** sets **`normalized`**).
pub(super) fn is_normalized_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 10);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_432;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_normalized",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let norm: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_normalized bool");
    assert!(norm, "expected is_normalized true after rotate+unfreeze (got {norm})");

    vec![success_row(
        "confidential_asset_is_normalized_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// After **`rotate_encryption_key_and_unfreeze`**, a second **`deposit`**; **`verify_pending_balance(second)`** with **new** **`dk`** returns **`true`**.
pub(super) fn verify_pending_balance_matches_second_deposit_after_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 11);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 4_001;
    let d2: u64 = 3_002;
    let balance_u128: u128 = d1 as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, d2), "second deposit after unfreeze");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&d2).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(ok, "verify_pending_balance({d2}) should succeed for second deposit after unfreeze");

    vec![success_row(
        "confidential_asset_verify_pending_balance_matches_second_deposit_after_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// After unfreeze + second **`deposit`**, **`verify_actual_balance(first_deposit)`** with **new** **`dk`** still returns **`true`** (**actual** unchanged).
pub(super) fn verify_actual_balance_matches_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 12);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 4_011;
    let d2: u64 = 3_012;
    let balance_u128: u128 = d1 as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, d2), "second deposit after unfreeze");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&balance_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({balance_u128}) should succeed (actual is first deposit) after second deposit post-unfreeze"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// After unfreeze + second **`deposit`**, **`verify_pending_balance(0)`** with **new** **`dk`** returns **`false`**.
pub(super) fn verify_pending_balance_rejects_zero_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 13);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 4_021;
    let d2: u64 = 3_022;
    let balance_u128: u128 = d1 as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, d2), "second deposit after unfreeze");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(!ok, "verify_pending_balance(0) should fail when pending is {d2} after second deposit");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_zero_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// Right after **`rotate_encryption_key_and_unfreeze`** (before any further **`deposit`**), **`verify_actual_balance(0)`** with **new** **`dk`** returns **`false`** when **actual** is the rolled-over amount.
pub(super) fn verify_actual_balance_rejects_zero_after_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 14);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 4_033;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance(0) should fail when actual is {balance_u128} after rotate+unfreeze"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`confidential_asset_balance`** (FA pool) unchanged after **`deposit`** + **`rollover_pending_balance_and_freeze`** + **`rotate_encryption_key_and_unfreeze`**.
pub(super) fn confidential_asset_balance_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 2);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 8_881;
    let balance_u128: u128 = dep as u128;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(bal, dep, "expected pool balance {dep} after rotate+unfreeze, got {bal}");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(dep)],
        },
    )]
}

/// After **`rotate_encryption_key_and_unfreeze`**, **`pending_balance`** `#[view]` wire length matches the **265**-byte register baseline (observed via **`bypass_at`** framing).
pub(super) fn pending_balance_view_return_len_265_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 15);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_151;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let wire_len = ret.return_values[0].0.len();
    assert_eq!(
        wire_len, 265,
        "expected pending_balance return byte len 265 after rotate+unfreeze (got {wire_len})"
    );

    vec![success_row(
        "confidential_asset_pending_balance_view_return_len_265_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// After **`rotate_encryption_key_and_unfreeze`**, **`actual_balance`** `#[view]` wire length matches the **529**-byte register baseline.
pub(super) fn actual_balance_view_return_len_529_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 16);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_252;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let wire_len = ret.return_values[0].0.len();
    assert_eq!(
        wire_len, 529,
        "expected actual_balance return byte len 529 after rotate+unfreeze (got {wire_len})"
    );

    vec![success_row(
        "confidential_asset_actual_balance_view_return_len_529_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// **`has_confidential_asset_store`** remains **`true`** after **`rotate_encryption_key_and_unfreeze`** on the freeze path.
pub(super) fn has_confidential_asset_store_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 17);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_353;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "has_confidential_asset_store",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let has: bool = bcs::from_bytes(&ret.return_values[0].0).expect("has_confidential_asset_store bool");
    assert!(has, "expected has_confidential_asset_store true after rotate+unfreeze (got {has})");

    vec![success_row(
        "confidential_asset_has_confidential_asset_store_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// After unfreeze + second **`deposit`**, **`verify_pending_balance(first_deposit)`** with **new** **`dk`** is **`false`** (**pending** encodes only the second amount).
pub(super) fn verify_pending_balance_rejects_stale_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 18);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 5_010;
    let d2: u64 = 4_109;
    let balance_u128: u128 = d1 as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, d2), "second deposit after unfreeze");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&d1).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({d1}) should fail when pending encodes only {d2}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`confidential_asset_balance`** is **6001** + **4002** = **10003** after one post-unfreeze **`deposit`** (**4002**) on top of the rolled **6001**.
pub(super) fn confidential_asset_balance_matches_10003_after_post_unfreeze_deposit_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 3);
    let account = h.new_account_with_balance_at(u, 48_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 6_001;
    let d2: u64 = 4_002;
    let balance_u128: u128 = d1 as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, d2), "post-unfreeze deposit");

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    let total: u64 = d1 + d2;
    assert_eq!(bal, total, "expected pool {total} after post-unfreeze deposit, got {bal}");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_matches_10003_after_post_unfreeze_deposit_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(total)],
        },
    )]
}

/// **`is_token_allowed(MOVE_METADATA)`** remains **`true`** after **`rotate_encryption_key_and_unfreeze`** on the freeze path.
pub(super) fn is_token_allowed_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 19);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_454;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_token_allowed",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_token_allowed bool");
    assert!(ok, "expected is_token_allowed true after rotate+unfreeze (got {ok})");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_token_allowed_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )]
}

/// **`get_auditor(MOVE_METADATA)`** still encodes **`option::none`** (**`[0]`** BCS) after **`rotate_encryption_key_and_unfreeze`** (no **`FAConfig`** in tests).
pub(super) fn get_auditor_returns_none_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 20);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_555;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "get_auditor",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bytes = ret.return_values[0].0.as_slice();
    assert_eq!(
        bytes,
        [0u8].as_slice(),
        "expected get_auditor BCS none ([0]) after rotate+unfreeze (got {bytes:?})"
    );

    vec![success_row(
        "confidential_asset_get_auditor_returns_none_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// After **two** post-unfreeze **`deposit`**s (**2000** then **900**), **`verify_pending_balance(2900)`** with **new** **`dk`** returns **`true`** (**pending** sums **2000** + **900**; **actual** still holds the rolled **6001**).
pub(super) fn verify_pending_balance_matches_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 21);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    let d2: u64 = 2_000;
    let d3: u64 = 900;
    assert_kept_success(&run_deposit(&mut h, &account, d2), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d3), "post-unfreeze deposit 2");

    let pending_sum: u64 = d2 + d3;
    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&pending_sum).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance({pending_sum}) should succeed for two post-unfreeze deposits"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_matches_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// **`is_allow_list_enabled`** stays **`false`** off mainnet after **`rotate_encryption_key_and_unfreeze`** on the freeze path.
pub(super) fn is_allow_list_enabled_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 22);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 5_656;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );

    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_allow_list_enabled",
        vec![],
        vec![],
    );
    assert_eq!(ret.return_values.len(), 1);
    let en: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_allow_list_enabled bool");
    assert!(
        !en,
        "expected is_allow_list_enabled false after rotate+unfreeze on test chain (got {en})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_allow_list_enabled_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** post-unfreeze **`deposit`**s, **`verify_pending_balance(sum−1)`** with **new** **`dk`** is **`false`**.
pub(super) fn verify_pending_balance_rejects_wrong_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 23);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    let d2: u64 = 2_000;
    let d3: u64 = 900;
    assert_kept_success(&run_deposit(&mut h, &account, d2), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d3), "post-unfreeze deposit 2");

    let pending_sum: u64 = d2 + d3;
    let wrong: u64 = pending_sum.saturating_sub(1);
    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({wrong}) should fail when pending sum is {pending_sum}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** post-unfreeze **`deposit`**s, **`verify_actual_balance(rolled−1)`** with **new** **`dk`** is **`false`** (**actual** still **6001**).
pub(super) fn verify_actual_balance_rejects_wrong_amount_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 24);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 2_000), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 900), "post-unfreeze deposit 2");

    let wrong: u128 = balance_u128.saturating_sub(1);
    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail when actual encodes {balance_u128}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`confidential_asset_balance`** is **6001** + **2000** + **900** = **8901** after **two** post-unfreeze **`deposit`**s on the freeze path.
pub(super) fn confidential_asset_balance_matches_8901_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 4);
    let account = h.new_account_with_balance_at(u, 48_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let d2: u64 = 2_000;
    let d3: u64 = 900;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, d2), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d3), "post-unfreeze deposit 2");

    let total: u64 = d_roll + d2 + d3;
    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(bal, total, "expected pool {total} after two post-unfreeze deposits, got {bal}");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_matches_8901_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(total)],
        },
    )]
}

/// After **two** post-unfreeze **`deposit`**s, **`verify_pending_balance(sum+1)`** with **new** **`dk`** is **`false`**.
pub(super) fn verify_pending_balance_rejects_sum_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 25);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    let d2: u64 = 2_000;
    let d3: u64 = 900;
    assert_kept_success(&run_deposit(&mut h, &account, d2), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d3), "post-unfreeze deposit 2");

    let pending_sum: u64 = d2 + d3;
    let too_high: u64 = pending_sum.saturating_add(1);
    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&too_high).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({too_high}) should fail when pending sum is {pending_sum}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_sum_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** post-unfreeze **`deposit`**s, **`verify_actual_balance(rolled+1)`** with **new** **`dk`** is **`false`**.
pub(super) fn verify_actual_balance_rejects_amount_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 26);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 2_000), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 900), "post-unfreeze deposit 2");

    let too_high: u128 = balance_u128.saturating_add(1);
    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&too_high).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({too_high}) should fail when actual encodes {balance_u128}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** post-unfreeze **`deposit`**s, **`encryption_key`** still matches **`pubkey_to_bytes(new_ek)`**.
pub(super) fn encryption_key_view_matches_new_ek_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 27);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 6_717;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let new_ek_pk = twisted_pubkey_bytes(&mut h, &new_ek_struct);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 2_000), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 900), "post-unfreeze deposit 2");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "encryption_key",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let key_bcs = ret.return_values[0].0.clone();
    let pb = bypass_at(
        &mut h,
        "ristretto255_twisted_elgamal",
        "pubkey_to_bytes",
        vec![],
        vec![key_bcs],
    );
    assert_eq!(pb.return_values.len(), 1);
    assert_eq!(
        pb.return_values[0].0, new_ek_pk,
        "encryption_key view should still match new compressed pubkey after two post-unfreeze deposits"
    );

    vec![success_row(
        "confidential_asset_encryption_key_view_matches_new_ek_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// **`is_frozen`** stays **`false`** after **two** post-unfreeze **`deposit`**s on the freeze path.
pub(super) fn is_frozen_false_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEF, 28);
    let account = h.new_account_with_balance_at(u, 46_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 6_818;
    let balance_u128: u128 = deposit_amt as u128;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 2_000), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 900), "post-unfreeze deposit 2");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_frozen",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let frozen: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_frozen bool");
    assert!(
        !frozen,
        "expected is_frozen false after two post-unfreeze deposits (got {frozen})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_frozen_false_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`confidential_asset_balance`** is **6001** + **100** + **200** + **300** = **6601** after **three** post-unfreeze **`deposit`**s.
pub(super) fn confidential_asset_balance_matches_6601_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 5);
    let account = h.new_account_with_balance_at(u, 48_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 100), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 200), "post-unfreeze deposit 2");
    assert_kept_success(&run_deposit(&mut h, &account, 300), "post-unfreeze deposit 3");

    let total: u64 = d_roll + 100 + 200 + 300;
    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(bal, total, "expected pool {total} after three post-unfreeze deposits, got {bal}");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_matches_6601_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(total)],
        },
    )]
}

/// After **three** post-unfreeze **`deposit`**s on the rolled **6001** path, **`is_normalized`** still reads **`true`** (**`deposit`** does not clear **`normalized`**).
pub(super) fn is_normalized_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 6);
    let account = h.new_account_with_balance_at(u, 48_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 100), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 200), "post-unfreeze deposit 2");
    assert_kept_success(&run_deposit(&mut h, &account, 300), "post-unfreeze deposit 3");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_normalized",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let norm: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_normalized bool");
    assert!(norm, "expected is_normalized true after three post-unfreeze deposits (got {norm})");

    vec![success_row(
        "confidential_asset_is_normalized_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// **`has_confidential_asset_store`** remains **`true`** after **three** post-unfreeze **`deposit`**s.
pub(super) fn has_confidential_asset_store_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 7);
    let account = h.new_account_with_balance_at(u, 48_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 100), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 200), "post-unfreeze deposit 2");
    assert_kept_success(&run_deposit(&mut h, &account, 300), "post-unfreeze deposit 3");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "has_confidential_asset_store",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let has: bool = bcs::from_bytes(&ret.return_values[0].0).expect("has_confidential_asset_store bool");
    assert!(has, "expected has_confidential_asset_store true after three post-unfreeze deposits (got {has})");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_has_confidential_asset_store_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )]
}

/// After **three** post-unfreeze **`deposit`**s (**100** + **200** + **300**), **`verify_pending_balance(600)`** with **new** **`dk`** returns **`true`**.
pub(super) fn verify_pending_balance_matches_sum_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 8);
    let account = h.new_account_with_balance_at(u, 48_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    let d2: u64 = 100;
    let d3: u64 = 200;
    let d4: u64 = 300;
    assert_kept_success(&run_deposit(&mut h, &account, d2), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d3), "post-unfreeze deposit 2");
    assert_kept_success(&run_deposit(&mut h, &account, d4), "post-unfreeze deposit 3");

    let pending_sum: u64 = d2 + d3 + d4;
    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&pending_sum).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance({pending_sum}) should succeed for three post-unfreeze deposits"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_matches_sum_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
    )]
}

/// After **three** post-unfreeze **`deposit`**s, **`verify_pending_balance(0)`** with **new** **`dk`** returns **`false`**.
pub(super) fn verify_pending_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 9);
    let account = h.new_account_with_balance_at(u, 48_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 100), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 200), "post-unfreeze deposit 2");
    assert_kept_success(&run_deposit(&mut h, &account, 300), "post-unfreeze deposit 3");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(!ok, "verify_pending_balance(0) should fail when pending sums 600 after three deposits");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **three** post-unfreeze **`deposit`**s, **`verify_actual_balance(0)`** with **new** **`dk`** returns **`false`** (**actual** still **6001**).
pub(super) fn verify_actual_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 10);
    let account = h.new_account_with_balance_at(u, 48_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 100), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 200), "post-unfreeze deposit 2");
    assert_kept_success(&run_deposit(&mut h, &account, 300), "post-unfreeze deposit 3");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        new_dk.clone(),
        bcs::to_bytes(&0u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance(0) should fail when actual is {balance_u128} with non-zero pending"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// **`confidential_asset_balance`** is **6001** + **111** + **222** + **333** + **444** = **7111** after **four** post-unfreeze **`deposit`**s.
pub(super) fn confidential_asset_balance_matches_7111_after_four_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF0, 11);
    let account = h.new_account_with_balance_at(u, 48_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d_roll: u64 = 6_001;
    let balance_u128: u128 = d_roll as u128;
    assert_kept_success(&run_deposit(&mut h, &account, d_roll), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        u,
        &dk,
        &new_dk,
        &new_ek_struct,
        balance_u128,
    );
    assert_kept_success(
        &run_rotate_and_unfreeze(&mut h, &account, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key_and_unfreeze",
    );
    assert_kept_success(&run_deposit(&mut h, &account, 111), "post-unfreeze deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, 222), "post-unfreeze deposit 2");
    assert_kept_success(&run_deposit(&mut h, &account, 333), "post-unfreeze deposit 3");
    assert_kept_success(&run_deposit(&mut h, &account, 444), "post-unfreeze deposit 4");

    let total: u64 = d_roll + 111 + 222 + 333 + 444;
    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(bal, total, "expected pool {total} after four post-unfreeze deposits, got {bal}");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_matches_7111_after_four_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(total)],
        },
    )]
}

/// After `register`, `has_confidential_asset_store` reads **`true`**.
pub(super) fn has_confidential_asset_store_true_after_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF6, 1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "has_confidential_asset_store",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let has: bool = bcs::from_bytes(&ret.return_values[0].0).expect("has_confidential_asset_store bool");
    assert!(has, "expected has_confidential_asset_store true after register (got {has})");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_has_confidential_asset_store_true_after_register_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )]
}

/// `is_token_allowed(MOVE_METADATA)` with allow-list off (typical test chain) ⇒ **`true`**.
pub(super) fn is_token_allowed_true_for_metadata_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_token_allowed",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_token_allowed bool");
    assert!(ok, "expected is_token_allowed true when allow list is off");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_token_allowed_true_for_metadata_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )]
}

/// `is_allow_list_enabled` is **`false`** off mainnet (`FAController` init in `confidential_asset.move`).
pub(super) fn is_allow_list_enabled_false_in_tests_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_allow_list_enabled",
        vec![],
        vec![],
    );
    assert_eq!(ret.return_values.len(), 1);
    let en: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_allow_list_enabled bool");
    assert!(
        !en,
        "expected is_allow_list_enabled false on non-mainnet test chain (got {en})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_allow_list_enabled_false_in_tests_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// With allow-list **off** and **no** `FAConfig` at the FA config address for **`MOVE_METADATA`**, **`get_auditor`**
/// returns **`option::none`** (BCS discriminant **`0`** only).
pub(super) fn get_auditor_returns_none_for_move_metadata_no_fa_config_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "get_auditor",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bytes = ret.return_values[0].0.as_slice();
    assert_eq!(
        bytes,
        [0u8].as_slice(),
        "expected get_auditor BCS none ([0]) for MOVE_METADATA without FAConfig (got {bytes:?})"
    );

    vec![success_row(
        "confidential_asset_get_auditor_returns_none_for_move_metadata_no_fa_config_only",
    )]
}

/// Right after `register`, `is_normalized` is **`true`** (initial store layout).
pub(super) fn is_normalized_true_after_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF7, 1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_normalized",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let norm: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_normalized bool");
    assert!(norm, "expected is_normalized true right after register (got {norm})");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_normalized_true_after_register_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )]
}

/// After `freeze_token` then `unfreeze_token`, `is_frozen` reads **`false`**.
pub(super) fn is_frozen_false_after_unfreeze_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF8, 1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");
    assert_kept_success(&run_deposit(&mut h, &account, 50), "deposit");
    assert_kept_success(&run_freeze_token(&mut h, &account), "freeze_token");
    assert_kept_success(&run_unfreeze_token(&mut h, &account), "unfreeze_token");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_frozen",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let frozen: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_frozen bool");
    assert!(
        !frozen,
        "expected is_frozen false after unfreeze_token (got {frozen})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_frozen_false_after_unfreeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// `is_frozen` is **`false`** after `register` / `deposit` before any `freeze_token` entry.
pub(super) fn is_frozen_false_after_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xF9, 1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");
    assert_kept_success(&run_deposit(&mut h, &account, 10), "deposit");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_frozen",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let frozen: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_frozen bool");
    assert!(
        !frozen,
        "expected is_frozen false before freeze_token (got {frozen})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_frozen_false_after_register_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// Alice is registered for the token; Bob is not — `has_confidential_asset_store` is **`false`** for Bob.
pub(super) fn has_confidential_asset_store_false_for_peer_not_registered_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xFA, 1);
    let bob_addr = confidential_e2e_addr(0xFA, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let _bob = h.new_account_with_balance_at(bob_addr, 10_000_000_000_000);

    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, alice_addr, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &alice, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&bob_addr).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "has_confidential_asset_store",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let has: bool = bcs::from_bytes(&ret.return_values[0].0).expect("has_confidential_asset_store bool");
    assert!(
        !has,
        "expected has_confidential_asset_store false for non-registered peer (got {has})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_has_confidential_asset_store_false_for_peer_not_registered",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// `rollover_pending_balance_and_freeze` leaves the store **frozen** — `is_frozen` reads **`true`**.
pub(super) fn is_frozen_true_after_rollover_and_freeze_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFB, 1);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &comm, &resp), "register");
    assert_kept_success(&run_deposit(&mut h, &account, 1_111), "deposit");
    assert_kept_success(
        &run_rollover_and_freeze(&mut h, &account),
        "rollover_pending_balance_and_freeze",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_frozen",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let frozen: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_frozen bool");
    assert!(
        frozen,
        "expected is_frozen true after rollover_pending_balance_and_freeze (got {frozen})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_frozen_true_after_rollover_and_freeze_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )]
}

/// After `normalize` following rollover, `is_normalized` reads **`true`** again.
pub(super) fn is_normalized_true_after_normalize_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFC, 1);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &comm, &resp), "register");

    let deposit_amt: u64 = 606;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(
        &run_rollover(&mut h, &account),
        "rollover_pending_balance",
    );

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "is_normalized",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let norm: bool = bcs::from_bytes(&ret.return_values[0].0).expect("is_normalized bool");
    assert!(
        norm,
        "expected is_normalized true after normalize (got {norm})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_is_normalized_true_after_normalize_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(true)],
        },
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`normalize`**, **`verify_actual_balance`** with the
/// rolled-over **actual** amount (**`u128`**) succeeds.
pub(super) fn verify_actual_balance_matches_after_deposit_rollover_and_normalize_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFC, 2);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 424;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&amt_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({amt_u128}) should succeed after deposit+rollover+normalize"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_normalize_only",
    )]
}

/// After **`deposit`** → **`rollover`** → **`normalize`**, **`verify_pending_balance(0)`** still succeeds
/// (**pending** encoding remains zero after rollover).
pub(super) fn verify_pending_balance_zero_after_deposit_rollover_and_normalize_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFC, 3);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 515;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance(0) should succeed after deposit+rollover+normalize"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_normalize_only",
    )]
}

/// After **`deposit`** → **`rollover`** → **`normalize`**, **`verify_actual_balance`** with **`u128(actual−1)`**
/// must return **`false`**.
pub(super) fn verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_normalize_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFC, 4);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 303;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let wrong: u128 = amt_u128.saturating_sub(1);
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail when actual is {amt_u128} after normalize"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_normalize_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover`** → **`normalize`**, **`verify_actual_balance(u128(actual+1))`**
/// must return **`false`**.
pub(super) fn verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_normalize_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFC, 7);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 808;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let too_high: u128 = amt_u128.saturating_add(1);
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&too_high).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({too_high}) should fail when actual is {amt_u128} after normalize"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_normalize_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover`** → **`normalize`**, **`verify_actual_balance(0)`** must return **`false`**
/// (**actual** is the deposited amount on-chain).
pub(super) fn verify_actual_balance_rejects_zero_after_deposit_rollover_and_normalize_when_actual_nonzero_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFC, 8);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 919;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance(0) should fail when actual is {amt_u128} after normalize"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_deposit_rollover_and_normalize_when_actual_nonzero",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover`** → **`normalize`**, **`verify_pending_balance(1)`** must return **`false`**
/// (**pending** is still zero).
pub(super) fn verify_pending_balance_rejects_nonzero_after_deposit_rollover_and_normalize_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFC, 5);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 302;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&1u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(1) should fail when pending is zero after normalize"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_after_deposit_rollover_and_normalize_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover`** → **`normalize`**, **`verify_pending_balance(deposit_amt)`** must return **`false`**
/// (**pending** is cleared to zero; the old deposit amount is not a valid pending claim).
pub(super) fn verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_normalize_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFC, 6);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 707;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "normalize",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&deposit_amt).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({deposit_amt}) should fail when pending is zero after normalize"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_normalize_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// `confidential_asset_balance` (circulating in the CA pool) equals the first **`deposit`** amount once the FA primary store exists.
pub(super) fn confidential_asset_balance_matches_single_deposit_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFD, 1);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 77;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(
        bal, dep,
        "expected confidential_asset_balance == first deposit ({dep}), got {bal}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_matches_single_deposit_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(dep)],
        },
    )]
}

/// `confidential_asset_balance` sums both self-**`deposit`** calls (100 + 65 = **165**).
pub(super) fn confidential_asset_balance_after_two_deposits_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFE, 1);
    let account = h.new_account_with_balance_at(u, 50_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 100;
    let d2: u64 = 65;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    let total = d1 + d2;
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(
        bal, total,
        "expected confidential_asset_balance == {total} (got {bal})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_after_two_deposits_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(total)],
        },
    )]
}

/// `confidential_asset_balance` after **`deposit`** → **`rollover`** → **`withdraw`** (pool = deposit − withdrawn).
pub(super) fn confidential_asset_balance_after_deposit_and_withdraw_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFF, 1);
    let account = h.new_account_with_balance_at(u, 50_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 1_000;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w: u64 = 333;
    let after: u128 = dep as u128 - w as u128;
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek_struct, w, after);
    assert_kept_success(
        &run_withdraw(&mut h, &account, w, &nb, &z, &s),
        "withdraw before balance view",
    );

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(
        bal, after as u64,
        "expected confidential_asset_balance == pool after withdraw ({after}), got {bal}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_after_deposit_and_withdraw_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(after as u64)],
        },
    )]
}

/// `confidential_asset_balance` after a single cross-party **`deposit_to`** (Alice → Bob); pool equals that amount.
pub(super) fn confidential_asset_balance_after_deposit_to_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xDD, 1);
    let bob_addr = confidential_e2e_addr(0xDD, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 10_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in [
        (&alice, alice_addr, &alice_dk, &alice_ek),
        (&bob, bob_addr, &bob_dk, &bob_ek),
    ] {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    let amt: u64 = 5_678;
    assert_kept_success(
        &run_deposit_to(&mut h, &alice, bob_addr, amt),
        "deposit_to before balance view",
    );

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(
        bal, amt,
        "expected confidential_asset_balance == deposit_to amount ({amt}), got {bal}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_after_deposit_to_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(amt)],
        },
    )]
}

/// `confidential_asset_balance` is **unchanged** by `confidential_transfer` (FA stays in the CA pool); witness = initial deposit.
pub(super) fn confidential_asset_balance_after_confidential_transfer_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xCC, 1);
    let bob_addr = confidential_e2e_addr(0xCC, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 10_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in [
        (&alice, alice_addr, &alice_dk, &alice_ek),
        (&bob, bob_addr, &bob_dk, &bob_ek),
    ] {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    let dep: u64 = 12_345;
    assert_kept_success(&run_deposit(&mut h, &alice, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

    let xfer: u64 = 4_321;
    let remaining: u128 = dep as u128 - xfer as u128;
    let parts = pack_transfer_simple(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        xfer,
        remaining,
        vec![],
    );
    assert_kept_success(
        &run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]),
        "confidential_transfer before balance view",
    );

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(
        bal, dep,
        "expected confidential_asset_balance unchanged at deposit total ({dep}) after transfer, got {bal}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_after_confidential_transfer_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(dep)],
        },
    )]
}

/// Pool **`confidential_asset_balance`** after **`deposit`** → **`rollover`** → **`confidential_transfer`** → second **`deposit`** (sums new FA into the pool).
pub(super) fn confidential_asset_balance_after_transfer_and_second_deposit_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xCB, 1);
    let bob_addr = confidential_e2e_addr(0xCB, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 10_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in [
        (&alice, alice_addr, &alice_dk, &alice_ek),
        (&bob, bob_addr, &bob_dk, &bob_ek),
    ] {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    let dep1: u64 = 5_000;
    assert_kept_success(&run_deposit(&mut h, &alice, dep1), "first deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

    let xfer: u64 = 1_000;
    let remaining_after_xfer: u128 = dep1 as u128 - xfer as u128;
    let parts = pack_transfer_simple(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        xfer,
        remaining_after_xfer,
        vec![],
    );
    assert_kept_success(
        &run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]),
        "transfer mid scenario",
    );

    let dep2: u64 = 2_000;
    assert_kept_success(&run_deposit(&mut h, &alice, dep2), "second deposit");
    let expected_pool: u64 = dep1 + dep2;

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(
        bal, expected_pool,
        "expected confidential_asset_balance == {expected_pool} (dep1+dep2), got {bal}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_after_transfer_and_second_deposit_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(expected_pool)],
        },
    )]
}

/// Pool **`confidential_asset_balance`** after **two** sequential **`deposit_to`** calls (same sender → same recipient).
pub(super) fn confidential_asset_balance_after_two_deposit_to_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xCA, 1);
    let bob_addr = confidential_e2e_addr(0xCA, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 10_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in [
        (&alice, alice_addr, &alice_dk, &alice_ek),
        (&bob, bob_addr, &bob_dk, &bob_ek),
    ] {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    let d1: u64 = 3_333;
    let d2: u64 = 4_444;
    assert_kept_success(
        &run_deposit_to(&mut h, &alice, bob_addr, d1),
        "first deposit_to",
    );
    assert_kept_success(
        &run_deposit_to(&mut h, &alice, bob_addr, d2),
        "second deposit_to",
    );
    let total = d1 + d2;

    let args = vec![bcs::to_bytes(&MOVE_METADATA).unwrap()];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "confidential_asset_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let bal: u64 = bcs::from_bytes(&ret.return_values[0].0).expect("confidential_asset_balance u64");
    assert_eq!(
        bal, total,
        "expected confidential_asset_balance == two deposit_to sum ({total}), got {bal}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_balance_after_two_deposit_to_only",
        vec![],
        TestResult::Returned {
            values: vec![make_u64(total)],
        },
    )]
}

/// Two registered accounts; Alice uses `deposit_to` to fund Bob's pending balance (not `deposit` self).
pub(super) fn deposit_to_cross_party_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xED, 1);
    let bob_addr = confidential_e2e_addr(0xED, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 10_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in [
        (&alice, alice_addr, &alice_dk, &alice_ek),
        (&bob, bob_addr, &bob_dk, &bob_ek),
    ] {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    assert_kept_success(
        &run_deposit_to(&mut h, &alice, bob_addr, 4_321),
        "deposit_to recipient",
    );

    vec![success_row("confidential_asset_deposit_to_cross_party_only")]
}

/// `withdraw` entry (self recipient) after deposit + rollover — distinct from `withdraw_to` oracle rows.
pub(super) fn withdraw_entry_self_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEE, 1);
    let account = h.new_account_with_balance_at(u, 45_000_000_000_000);
    let (dk, ek) = generate_elgamal_keypair(&mut h);
    let pk = twisted_pubkey_bytes(&mut h, &ek);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &pk, &c, &r), "register");

    let dep: u64 = 8_080;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w = 80u64;
    let after: u128 = dep as u128 - w as u128;
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek, w, after);
    assert_kept_success(
        &run_withdraw(&mut h, &account, w, &nb, &z, &s),
        "withdraw entry self",
    );

    vec![success_row("confidential_asset_withdraw_entry_self_only")]
}

pub(super) fn register_deposit_rollover_and_gas_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = AccountAddress::from_hex_literal("0xa11e").unwrap();
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);

    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) =
        prove_registration_parts(&mut h, chain, alice_addr, &dk, &ek_struct, MOVE_METADATA);
    let st = run_register(&mut h, &alice, &ek_pk, &comm, &resp);
    assert_kept_success(&st, "register");

    let st = run_deposit(&mut h, &alice, 5_000);
    assert_kept_success(&st, "deposit");

    let st = run_rollover(&mut h, &alice);
    assert_kept_success(&st, "rollover");

    let deposit_payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("deposit").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            bcs::to_bytes(&1_000u64).unwrap(),
        ],
    ));
    let _ = profile_gas(&mut h, &alice, deposit_payload, "deposit (profile)");

    vec![success_row("confidential_asset_register_deposit_rollover_and_gas")]
}

pub(super) fn transfer_withdraw_rotate_and_auditor_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();

    let alice_addr = AccountAddress::from_hex_literal("0xa1a1").unwrap();
    let bob_addr = AccountAddress::from_hex_literal("0xb0b0").unwrap();
    let alice = h.new_account_with_balance_at(alice_addr, 80_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 80_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);

    for (acct, addr, dk, ek_struct) in [
        (&alice, alice_addr, &alice_dk, &alice_ek),
        (&bob, bob_addr, &bob_dk, &bob_ek),
    ] {
        let ek_pk = twisted_pubkey_bytes(&mut h, ek_struct);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek_struct, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &ek_pk, &c, &r), "register");
    }

    assert_kept_success(&run_deposit(&mut h, &alice, 10_000), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover pre-transfer");

    let xfer_amt = 400u64;
    let mut remaining: u128 = 10_000 - xfer_amt as u128;
    let xfer_hint = vec![1u8, 2, 3];
    let parts = pack_transfer_simple(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        xfer_amt,
        remaining,
        xfer_hint.clone(),
    );
    assert_kept_success(
        &run_confidential_transfer(&mut h, &alice, bob_addr, &parts, xfer_hint),
        "confidential_transfer",
    );

    remaining -= xfer_amt as u128;
    let parts2 = pack_transfer_simple(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        xfer_amt,
        remaining,
        vec![],
    );
    assert_kept_success(
        &run_confidential_transfer(&mut h, &alice, bob_addr, &parts2, vec![]),
        "confidential_transfer (second)",
    );

    let (_aud_dk, aud_ek_struct) = generate_elgamal_keypair(&mut h);
    let aud_pk = twisted_pubkey_bytes(&mut h, &aud_ek_struct);
    set_asset_auditor(&mut h, &aud_pk);
    remaining -= xfer_amt as u128;
    let warm = pack_transfer_audited(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        xfer_amt,
        remaining,
        vec![aud_pk.clone()],
        vec![],
    );
    assert_kept_success(
        &run_confidential_transfer(&mut h, &alice, bob_addr, &warm, vec![]),
        "audited transfer",
    );

    assert_kept_success(&run_rollover(&mut h, &bob), "bob rollover");
    let w_amt = 50u64;
    let bob_after_withdraw: u128 = xfer_amt as u128 * 3 - w_amt as u128;
    let (nb, zkrp, sigma) = pack_withdraw(
        &mut h,
        chain,
        bob_addr,
        &bob_dk,
        &bob_ek,
        w_amt,
        bob_after_withdraw,
    );
    assert_kept_success(
        &run_withdraw_to(&mut h, &bob, bob_addr, w_amt, &nb, &zkrp, &sigma),
        "withdraw_to self",
    );

    assert_kept_success(&run_rollover_and_freeze(&mut h, &alice), "freeze alice");
    let (new_dk, new_ek_struct) = generate_elgamal_keypair(&mut h);
    let alice_remaining = remaining;
    let (nek_bytes, nbal, zkr, sig) = pack_rotate(
        &mut h,
        chain,
        alice_addr,
        &alice_dk,
        &new_dk,
        &new_ek_struct,
        alice_remaining,
    );
    assert_kept_success(
        &run_rotate(&mut h, &alice, &nek_bytes, &nbal, &zkr, &sig),
        "rotate_encryption_key",
    );

    vec![success_row("confidential_asset_transfer_withdraw_rotate_and_auditor")]
}

/// After **`register`** (no **`deposit`** yet), **`pending_balance`** `#[view]` return payload has the
/// **observed** serialized length (**265** bytes through `bypass_at` in this harness — includes BCS
/// framing for `CompressedConfidentialBalance`; not the raw **256**-byte “zero pending” wire alone).
pub(super) fn pending_balance_view_return_len_265_after_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xED, 3);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let wire_len = ret.return_values[0].0.len();
    assert_eq!(
        wire_len, 265,
        "expected pending_balance return byte len 265 after register (got {wire_len})"
    );

    vec![success_row(
        "confidential_asset_pending_balance_view_return_len_265_after_register_only",
    )]
}

/// After **`register`** (no **`deposit`**), **`actual_balance`** `#[view]` return payload length (**529** bytes
/// observed through `bypass_at` — **8** ciphertext chunks vs **4** for pending’s **265**).
pub(super) fn actual_balance_view_return_len_529_after_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xED, 4);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let wire_len = ret.return_values[0].0.len();
    assert_eq!(
        wire_len, 529,
        "expected actual_balance return byte len 529 after register (got {wire_len})"
    );

    vec![success_row(
        "confidential_asset_actual_balance_view_return_len_529_after_register_only",
    )]
}

pub(super) fn pending_balance_view_matches_deposit_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = AccountAddress::from_hex_literal("0xce11").unwrap();
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 777;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&deposit_amt).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("bool return");
    assert!(ok, "pending balance should decrypt to deposited amount");

    vec![success_row("confidential_asset_pending_balance_view_matches_deposit")]
}

/// After **`register`** only, **`verify_pending_balance`** with **`u64(0)`** matches the initial **zero** pending balance.
pub(super) fn verify_pending_balance_zero_after_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 6);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance(0) should succeed on freshly registered zero pending balance"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_zero_after_register_only",
    )]
}

/// After **`register`** only, **`verify_actual_balance`** with **`u128(0)`** matches the initial **zero** actual balance.
pub(super) fn verify_actual_balance_zero_after_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 5);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance(0) should succeed on freshly registered zero actual balance"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_zero_after_register_only",
    )]
}

/// After **`register`** only, **`verify_pending_balance`** with a **non-zero** **`u64`** must return **`false`**.
pub(super) fn verify_pending_balance_rejects_nonzero_after_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 15);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&1u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(1) should fail on freshly registered zero pending balance"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_after_register_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`register`** only, **`verify_actual_balance`** with a **non-zero** **`u128`** must return **`false`**.
pub(super) fn verify_actual_balance_rejects_nonzero_after_register_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 16);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&1u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance(1) should fail on freshly registered zero actual balance"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_nonzero_after_register_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`register`** → **`deposit`** → **`rollover_pending_balance`**, **`verify_actual_balance`**
/// with the deposited amount (**`u128`**) matches the **actual** balance (funds moved from pending).
pub(super) fn verify_actual_balance_matches_after_deposit_and_rollover_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 7);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 888;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&(deposit_amt as u128)).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({deposit_amt}) should succeed after deposit+rollover"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_after_deposit_and_rollover_only",
    )]
}

/// After **two** **`deposit`** calls then **`rollover_pending_balance`**, **`verify_actual_balance`** with the
/// **sum** of the deposits (as **`u128`**) matches **actual**.
pub(super) fn verify_actual_balance_matches_sum_after_two_deposits_and_rollover_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 20);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 40;
    let d2: u64 = 60;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");
    let sum_u128 = (d1 as u128).saturating_add(d2 as u128);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&sum_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({sum_u128}) should succeed after two deposits+rollover ({d1}+{d2})"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_sum_after_two_deposits_and_rollover_only",
    )]
}

/// After **`deposit`** → **`rollover_pending_balance`** → **`withdraw`**, **`verify_actual_balance`** with the
/// **remaining pool** (**`u128`**) succeeds (same numeric path as the balance view after withdraw).
pub(super) fn verify_actual_balance_matches_after_deposit_rollover_and_withdraw_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFF, 2);
    let account = h.new_account_with_balance_at(u, 50_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 1_000;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w: u64 = 333;
    let after: u128 = dep as u128 - w as u128;
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek_struct, w, after);
    assert_kept_success(
        &run_withdraw(&mut h, &account, w, &nb, &z, &s),
        "withdraw before verify_actual_balance",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&after).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance({after}) should succeed after deposit+rollover+withdraw (pool {after})"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_withdraw_only",
    )]
}

/// After **`deposit`** → **`rollover`** → **`withdraw`**, **`verify_actual_balance`** with **`u128(pool+1)`**
/// must return **`false`** (off-by-one vs remaining pool).
pub(super) fn verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_withdraw_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFF, 3);
    let account = h.new_account_with_balance_at(u, 50_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 1_000;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w: u64 = 333;
    let after: u128 = dep as u128 - w as u128;
    let wrong: u128 = after.saturating_add(1);
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek_struct, w, after);
    assert_kept_success(
        &run_withdraw(&mut h, &account, w, &nb, &z, &s),
        "withdraw before verify_actual_balance wrong",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail when pool is {after} after withdraw"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_withdraw_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** → **`rollover`** → **`withdraw`**, **pending** is still **zero** — **`verify_pending_balance(0)`**
/// succeeds.
pub(super) fn verify_pending_balance_zero_after_deposit_rollover_and_withdraw_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xFF, 4);
    let account = h.new_account_with_balance_at(u, 50_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let dep: u64 = 1_000;
    assert_kept_success(&run_deposit(&mut h, &account, dep), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w: u64 = 333;
    let after: u128 = dep as u128 - w as u128;
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek_struct, w, after);
    assert_kept_success(
        &run_withdraw(&mut h, &account, w, &nb, &z, &s),
        "withdraw before verify_pending_balance",
    );

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance(0) should succeed when pending is zero after deposit+rollover+withdraw"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_withdraw_only",
    )]
}

/// After **two** **`deposit`** calls then **`rollover_pending_balance`**, **`verify_actual_balance`** with an amount
/// **one less** than the true **actual** sum must return **`false`**.
pub(super) fn verify_actual_balance_rejects_wrong_sum_after_two_deposits_and_rollover_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 22);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 50;
    let d2: u64 = 70;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");
    let sum_u128 = (d1 as u128).saturating_add(d2 as u128);
    let wrong = sum_u128.saturating_sub(1);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail when actual encodes sum {sum_u128} ({d1}+{d2})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_sum_after_two_deposits_and_rollover_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** then **`rollover_pending_balance`**, **`verify_pending_balance`** with **`u64(0)`**
/// matches the **cleared** pending balance (funds are in **actual**).
pub(super) fn verify_pending_balance_zero_after_deposit_and_rollover_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 8);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 888;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance(0) should succeed after rollover cleared pending to zero encoding"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_zero_after_deposit_and_rollover_only",
    )]
}

/// After **`deposit`** without **`rollover_pending_balance`**, **`verify_pending_balance`** with the
/// deposited **`u64`** matches **pending** (funds not yet in **actual**).
pub(super) fn verify_pending_balance_matches_after_deposit_only_no_rollover_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 9);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 333;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&deposit_amt).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance({deposit_amt}) should succeed before rollover"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_matches_after_deposit_only_no_rollover",
    )]
}

/// After **two** **`deposit`** calls without **`rollover_pending_balance`**, **`verify_pending_balance`**
/// with the **sum** of the deposits matches aggregated **pending**.
pub(super) fn verify_pending_balance_matches_sum_after_two_deposits_no_rollover_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 19);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 100;
    let d2: u64 = 200;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    let sum = d1.saturating_add(d2);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&sum).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        ok,
        "verify_pending_balance({sum}) should succeed after two deposits {d1}+{d2} before rollover"
    );

    vec![success_row(
        "confidential_asset_verify_pending_balance_matches_sum_after_two_deposits_no_rollover",
    )]
}

/// After **two** **`deposit`** calls without rollover, **`verify_pending_balance`** with an amount **one less**
/// than the true **pending** sum must return **`false`**.
pub(super) fn verify_pending_balance_rejects_wrong_sum_after_two_deposits_no_rollover_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 21);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 100;
    let d2: u64 = 200;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    let sum = d1.saturating_add(d2);
    let wrong = sum.saturating_sub(1);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({wrong}) should fail when pending encodes sum {sum} ({d1}+{d2})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_sum_after_two_deposits_no_rollover",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** **`deposit`** calls without rollover, **`verify_pending_balance`** with **`u64(0)`** must return **`false`**
/// (**pending** holds the **sum** of deposits).
pub(super) fn verify_pending_balance_rejects_zero_after_two_deposits_no_rollover_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 28);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 11;
    let d2: u64 = 22;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    let sum = d1.saturating_add(d2);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(0) should fail when pending encodes sum {sum} ({d1}+{d2}) before rollover"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_zero_after_two_deposits_no_rollover",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After a **single** **`deposit`** without rollover, **`verify_pending_balance`** with **`u64(0)`** must return **`false`**
/// (**pending** holds the deposited amount).
pub(super) fn verify_pending_balance_rejects_zero_after_deposit_only_no_rollover_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 29);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 55;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(0) should fail when pending encodes {deposit_amt} before rollover"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_zero_after_deposit_only_no_rollover",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** without rollover, **`verify_pending_balance`** with a **wrong** **`u64`**
/// must return **`false`**.
pub(super) fn verify_pending_balance_rejects_wrong_amount_after_deposit_only_no_rollover_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 12);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 333;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");

    let wrong = deposit_amt.saturating_sub(1);
    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({wrong}) should fail when pending encodes {deposit_amt}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_amount_after_deposit_only_no_rollover",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** without **`rollover_pending_balance`**, **`verify_actual_balance`** with **`u128(0)`**
/// still matches **actual** (deposit sits in **pending**).
pub(super) fn verify_actual_balance_zero_after_deposit_only_no_rollover_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 10);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 333;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        ok,
        "verify_actual_balance(0) should still succeed before rollover (funds in pending)"
    );

    vec![success_row(
        "confidential_asset_verify_actual_balance_zero_after_deposit_only_no_rollover",
    )]
}

/// After **`deposit`** without **`rollover_pending_balance`**, **`verify_actual_balance`** with a **non-zero**
/// **`u128`** (here the deposited amount while funds still sit in **pending**) must return **`false`**.
pub(super) fn verify_actual_balance_rejects_nonzero_after_deposit_only_no_rollover_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 14);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 555;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");

    let wrong: u128 = deposit_amt as u128;
    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail before rollover (actual still 0; pending holds {deposit_amt})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_nonzero_after_deposit_only_no_rollover",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** **`deposit`** calls without **`rollover_pending_balance`**, **`verify_actual_balance`** with the
/// **pending sum** as **`u128`** must return **`false`** (**actual** is still **`0`** until rollover).
pub(super) fn verify_actual_balance_rejects_nonzero_sum_after_two_deposits_no_rollover_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 25);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 77;
    let d2: u64 = 88;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    let sum_u128: u128 = (d1 as u128).saturating_add(d2 as u128);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&sum_u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({sum_u128}) should fail before rollover (actual still 0; pending holds {d1}+{d2})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_nonzero_sum_after_two_deposits_no_rollover",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** **`deposit`** calls without rollover, **`verify_actual_balance`** with **`u128`** **one less** than
/// the **pending** sum must return **`false`** (**actual** still **`0`**; distinct from claiming the exact sum).
pub(super) fn verify_actual_balance_rejects_wrong_sum_after_two_deposits_no_rollover_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 26);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 50;
    let d2: u64 = 60;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    let sum: u128 = (d1 as u128).saturating_add(d2 as u128);
    let wrong: u128 = sum.saturating_sub(1);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail before rollover (pending sum {sum}; actual still 0)"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_sum_after_two_deposits_no_rollover",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** **`deposit`** calls without rollover, **`verify_actual_balance`** with **`u128`** **one greater** than
/// the **pending** sum must return **`false`** (**actual** still **`0`**).
pub(super) fn verify_actual_balance_rejects_sum_plus_one_after_two_deposits_no_rollover_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 27);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 33;
    let d2: u64 = 44;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    let sum: u128 = (d1 as u128).saturating_add(d2 as u128);
    let too_high: u128 = sum.saturating_add(1);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&too_high).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({too_high}) should fail before rollover (pending sum {sum}; actual still 0)"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_sum_plus_one_after_two_deposits_no_rollover",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** + **`rollover_pending_balance`**, **`verify_actual_balance`** with a **wrong** **`u128`**
/// amount must return **`false`** (VM rejects decryption check).
pub(super) fn verify_actual_balance_rejects_wrong_amount_after_deposit_and_rollover_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 11);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 888;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let wrong: u128 = (deposit_amt as u128).saturating_sub(1);
    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance({wrong}) should fail when actual balance is {deposit_amt}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_and_rollover_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** + **`rollover_pending_balance`**, **`verify_actual_balance`** with **`u128(0)`**
/// must return **`false`** once **actual** holds the deposited amount.
pub(super) fn verify_actual_balance_rejects_zero_after_deposit_and_rollover_when_actual_nonzero_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 18);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 666;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&0u128).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_actual_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_actual_balance bool");
    assert!(
        !ok,
        "verify_actual_balance(0) should fail after rollover when actual encodes {deposit_amt}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_actual_balance_rejects_zero_after_deposit_and_rollover_when_actual_nonzero",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`rollover_pending_balance`**, **pending** is cleared — **`verify_pending_balance`** with a **non-zero**
/// **`u64`** must return **`false`**.
pub(super) fn verify_pending_balance_rejects_nonzero_after_deposit_and_rollover_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 13);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 888;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&1u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance(1) should fail when pending is zero after rollover"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_nonzero_after_deposit_and_rollover_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **`deposit`** + **`rollover_pending_balance`**, **pending** is cleared — claiming the old
/// **`deposit`** amount as **`verify_pending_balance`** must return **`false`**.
pub(super) fn verify_pending_balance_rejects_stale_deposit_amount_after_deposit_and_rollover_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 17);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 777;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&deposit_amt).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({deposit_amt}) should fail after rollover (pending cleared; actual holds {deposit_amt})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_deposit_amount_after_deposit_and_rollover_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** **`deposit`** calls then **`rollover_pending_balance`**, **pending** is cleared — claiming the
/// **summed** pending amount as **`verify_pending_balance`** must return **`false`** (distinct from the single-deposit stale row).
pub(super) fn verify_pending_balance_rejects_stale_sum_after_two_deposits_and_rollover_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 23);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 41;
    let d2: u64 = 59;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");
    let sum_u64 = d1.saturating_add(d2);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&sum_u64).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({sum_u64}) should fail after rollover (pending cleared; actual holds {sum_u64})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_stale_sum_after_two_deposits_and_rollover_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

/// After **two** **`deposit`** calls then **`rollover_pending_balance`**, **pending** is cleared — a **wrong** **`u64`**
/// (here **one less** than the pre-rollover **sum**) must not satisfy **`verify_pending_balance`**.
pub(super) fn verify_pending_balance_rejects_wrong_amount_after_two_deposits_and_rollover_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEC, 24);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let d1: u64 = 40;
    let d2: u64 = 60;
    assert_kept_success(&run_deposit(&mut h, &account, d1), "deposit 1");
    assert_kept_success(&run_deposit(&mut h, &account, d2), "deposit 2");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");
    let sum_u64 = d1.saturating_add(d2);
    let wrong = sum_u64.saturating_sub(1);

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        dk.clone(),
        bcs::to_bytes(&wrong).unwrap(),
    ];
    let ret = bypass_at(
        &mut h,
        "confidential_asset",
        "verify_pending_balance",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 1);
    let ok: bool = bcs::from_bytes(&ret.return_values[0].0).expect("verify_pending_balance bool");
    assert!(
        !ok,
        "verify_pending_balance({wrong}) should fail when pending is cleared (actual holds sum {sum_u64})"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_asset_verify_pending_balance_rejects_wrong_amount_after_two_deposits_and_rollover_only",
        vec![],
        TestResult::Returned {
            values: vec![make_bool(false)],
        },
    )]
}

pub(super) fn compare_plain_fa_transfer_gas_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let a = AccountAddress::from_hex_literal("0xf1fa").unwrap();
    let b = AccountAddress::from_hex_literal("0xf2fa").unwrap();
    let alice = h.new_account_with_balance_at(a, 20_000_000_000_000);
    let _bob = h.new_account_with_balance_at(b, 1_000_000_000);
    let g = baseline_fa_transfer_gas(&mut h, &alice, b, 100);
    assert!(g > 0, "plain FA transfer should charge gas (got {g})");

    vec![success_row("confidential_asset_compare_plain_fa_transfer_gas")]
}

pub(super) fn confidential_transfer_with_voluntary_auditors_only_cases() -> Vec<TestCase> {
    let mut rows = Vec::new();
    for num_voluntary in 1u8..=3 {
        let mut h = fresh_harness();
        let chain = h.executor.get_chain_id().id();
        let alice_addr = confidential_e2e_addr(0xE1, num_voluntary);
        let bob_addr = confidential_e2e_addr(0xE2, num_voluntary);
        let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
        let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

        let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
        let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
        for (acct, addr, dk, ek) in
            [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)]
        {
            let pk = twisted_pubkey_bytes(&mut h, ek);
            let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
            assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
        }

        let mut vol_eks = Vec::<Vec<u8>>::new();
        for _ in 0..num_voluntary {
            let (_dk, ek) = generate_elgamal_keypair(&mut h);
            vol_eks.push(ek);
        }
        let vol_pks = bcs_auditor_pubkeys_from_ek_structs(&mut h, &vol_eks);

        assert_kept_success(&run_deposit(&mut h, &alice, 8_000), "deposit");
        assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

        let xfer = 200u64;
        let mut remaining: u128 = 8_000 - xfer as u128;
        let parts = pack_transfer_audited(
            &mut h,
            chain,
            alice_addr,
            bob_addr,
            &alice_dk,
            xfer,
            remaining,
            vol_pks,
            vec![],
        );
        assert_kept_success(
            &run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]),
            &format!("transfer {num_voluntary} voluntary auditors"),
        );

        remaining -= xfer as u128;
        let vol_eks2: Vec<Vec<u8>> = (0..num_voluntary)
            .map(|_| generate_elgamal_keypair(&mut h).1)
            .collect();
        let vol_pks2 = bcs_auditor_pubkeys_from_ek_structs(&mut h, &vol_eks2);
        let parts2 = pack_transfer_audited(
            &mut h,
            chain,
            alice_addr,
            bob_addr,
            &alice_dk,
            xfer,
            remaining,
            vol_pks2,
            vec![],
        );
        assert_kept_success(
            &run_confidential_transfer(&mut h, &alice, bob_addr, &parts2, vec![]),
            "second transfer (new voluntary auditor set)",
        );

        rows.push(vm_lean_row(
            format!(
                "confidential_asset_e2e::confidential_transfer_with_voluntary_auditors_only [n={num_voluntary}]"
            ),
            vec![],
            TestResult::Returned { values: vec![] },
        ));
    }
    rows
}

pub(super) fn confidential_transfer_asset_auditor_plus_voluntary_auditors_cases() -> Vec<TestCase> {
    let mut rows = Vec::new();
    for num_voluntary in 0u8..=3 {
        let mut h = fresh_harness();
        let chain = h.executor.get_chain_id().id();
        let alice_addr = confidential_e2e_addr(0xE3, num_voluntary);
        let bob_addr = confidential_e2e_addr(0xE4, num_voluntary);
        let alice = h.new_account_with_balance_at(alice_addr, 60_000_000_000_000);
        let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

        let (_asset_dk, asset_ek) = generate_elgamal_keypair(&mut h);
        let asset_pk = twisted_pubkey_bytes(&mut h, &asset_ek);
        set_asset_auditor(&mut h, &asset_pk);

        let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
        let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
        for (acct, addr, dk, ek) in
            [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)]
        {
            let pk = twisted_pubkey_bytes(&mut h, ek);
            let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
            assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
        }

        let mut auditor_keys = vec![asset_pk.clone()];
        let mut vol_structs = Vec::new();
        for _ in 0..num_voluntary {
            vol_structs.push(generate_elgamal_keypair(&mut h).1);
        }
        auditor_keys.extend(bcs_auditor_pubkeys_from_ek_structs(&mut h, &vol_structs));

        assert_kept_success(&run_deposit(&mut h, &alice, 9_000), "deposit");
        assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

        let xfer = 300u64;
        let remaining: u128 = 9_000 - xfer as u128;
        let parts = pack_transfer_audited(
            &mut h,
            chain,
            alice_addr,
            bob_addr,
            &alice_dk,
            xfer,
            remaining,
            auditor_keys,
            vec![],
        );
        assert_kept_success(
            &run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]),
            &format!("audited transfer asset auditor + {num_voluntary} voluntary"),
        );

        rows.push(vm_lean_row(
            format!(
                "confidential_asset_e2e::confidential_transfer_asset_auditor_plus_voluntary_auditors [n={num_voluntary}]"
            ),
            vec![],
            TestResult::Returned { values: vec![] },
        ));
    }
    rows
}

pub(super) fn confidential_withdraw_without_asset_auditor_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xE5, 1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek) = generate_elgamal_keypair(&mut h);
    let pk = twisted_pubkey_bytes(&mut h, &ek);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &pk, &c, &r), "register");

    let deposit_amt: u64 = 4_000;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w1 = 111u64;
    let after1: u128 = deposit_amt as u128 - w1 as u128;
    let (nb1, z1, s1) = pack_withdraw(&mut h, chain, u, &dk, &ek, w1, after1);
    assert_kept_success(
        &run_withdraw_to(&mut h, &account, u, w1, &nb1, &z1, &s1),
        "withdraw 1",
    );

    let w2 = 222u64;
    let after2 = after1 - w2 as u128;
    let (nb2, z2, s2) = pack_withdraw(&mut h, chain, u, &dk, &ek, w2, after2);
    assert_kept_success(
        &run_withdraw_to(&mut h, &account, u, w2, &nb2, &z2, &s2),
        "withdraw 2",
    );

    vec![success_row("confidential_withdraw_without_asset_auditor")]
}

pub(super) fn confidential_withdraw_after_asset_auditor_enabled_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xE6, 1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);

    let (_aud_dk, aud_ek) = generate_elgamal_keypair(&mut h);
    let aud_pk = twisted_pubkey_bytes(&mut h, &aud_ek);
    set_asset_auditor(&mut h, &aud_pk);

    let (dk, ek) = generate_elgamal_keypair(&mut h);
    let pk = twisted_pubkey_bytes(&mut h, &ek);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &pk, &c, &r), "register");

    let deposit_amt: u64 = 3_000;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let w = 400u64;
    let after: u128 = deposit_amt as u128 - w as u128;
    let (nb, z, s) = pack_withdraw(&mut h, chain, u, &dk, &ek, w, after);
    assert_kept_success(
        &run_withdraw_to(&mut h, &account, u, w, &nb, &z, &s),
        "withdraw with asset auditor configured (withdraw path ignores auditor list)",
    );

    vec![success_row("confidential_withdraw_after_asset_auditor_enabled")]
}

pub(super) fn confidential_transfer_rejects_empty_auditors_when_asset_auditor_set_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xE7, 1);
    let bob_addr = confidential_e2e_addr(0xE7, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

    let (_aud_dk, aud_ek) = generate_elgamal_keypair(&mut h);
    let aud_pk = twisted_pubkey_bytes(&mut h, &aud_ek);
    set_asset_auditor(&mut h, &aud_pk);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in
        [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)]
    {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    assert_kept_success(&run_deposit(&mut h, &alice, 2_000), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

    let parts = pack_transfer_simple(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        100,
        1900,
        vec![],
    );
    let st = run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]);
    assert_kept_failure(&st, "transfer with zero auditors in proof when asset auditor required");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_transfer_rejects_empty_auditors_when_asset_auditor_set",
        vec![],
        txn_outcome(&st),
    )]
}

/// **`confidential_transfer_internal`** rejects when **`balance_c_equals(sender_amount, recipient_amount)`** fails
/// (**`EINVALID_SENDER_AMOUNT`** → canonical abort **`65553`** = **`0x10011`**) before **`verify_transfer_proof`**.
///
/// Construct two valid proof bundles at the same on-chain **`actual_balance`**, then splice **`recipient_amount`**
/// bytes from a **different** cleartext transfer amount into the row that still carries the **`sender_amount`**
/// ciphertext for the first amount.
pub(super) fn confidential_transfer_rejects_mismatched_sender_recipient_amount_ciphertexts_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xE9, 9);
    let bob_addr = confidential_e2e_addr(0xE9, 10);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in
        [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)]
    {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    assert_kept_success(&run_deposit(&mut h, &alice, 8_000), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

    let mut parts_a = pack_transfer_simple(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        100,
        7_900,
        vec![],
    )
    .to_vec();
    let parts_b = pack_transfer_simple(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        200,
        7_800,
        vec![],
    );
    // `parts_b[2]` encrypts a different transfer cleartext than `parts_a[1]` / `parts_a[2]`.
    parts_a[2] = parts_b[2].clone();

    let parts: [Vec<u8>; 8] = std::array::from_fn(|i| parts_a[i].clone());
    let st = run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]);
    assert_kept_failure(
        &st,
        "sender_amount / recipient_amount ciphertext pair should fail balance_c_equals",
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_transfer_rejects_mismatched_sender_recipient_amount_ciphertexts",
        vec![],
        txn_outcome(&st),
    )]
}

/// **`confidential_transfer_internal`** rejects when the **recipient** confidential store is **frozen**
/// (`EALREADY_FROZEN` → **`invalid_state(7)`** → **`196615`**), before auditor / amount / proof checks.
pub(super) fn confidential_transfer_rejects_when_recipient_frozen_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xEA, 0x21);
    let bob_addr = confidential_e2e_addr(0xEA, 0x22);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in
        [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)]
    {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    assert_kept_success(&run_deposit(&mut h, &alice, 8_000), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

    assert_kept_success(&run_freeze_token(&mut h, &bob), "freeze_token recipient");

    let parts = pack_transfer_simple(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        100,
        7_900,
        vec![],
    );
    let st = run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]);
    assert_kept_failure(&st, "confidential_transfer to frozen recipient should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_transfer_rejects_when_recipient_frozen",
        vec![],
        txn_outcome(&st),
    )]
}

/// Second **`normalize`** after a successful first **`normalize`** (store already **`normalized`**):
/// **`normalize_internal`** aborts with **`EALREADY_NORMALIZED`** (**`invalid_state(11)`** → **`196619`**)
/// before **`verify_normalization_proof`**.
pub(super) fn normalize_aborts_when_already_normalized_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0x31);
    let account = h.new_account_with_balance_at(u, 42_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 424;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "rollover");

    let amt_u128: u128 = deposit_amt as u128;
    let (nb, zkr, sig) = pack_normalize(&mut h, chain, u, &dk, amt_u128);
    assert_kept_success(
        &run_normalize(&mut h, &account, &nb, &zkr, &sig),
        "first normalize",
    );

    let st = run_normalize(&mut h, &account, &nb, &zkr, &sig);
    assert_kept_failure(&st, "second normalize should abort when already normalized");

    vec![vm_lean_row(
        "confidential_asset_e2e::normalize_aborts_when_already_normalized_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// **`deposit_to_internal`** rejects when **`is_frozen(to, token)`** — same **`196615`** as **`confidential_transfer`** to a frozen recipient.
pub(super) fn deposit_to_rejects_when_recipient_frozen_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xEA, 0x41);
    let bob_addr = confidential_e2e_addr(0xEA, 0x42);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in
        [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)]
    {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    assert_kept_success(&run_freeze_token(&mut h, &bob), "freeze_token recipient");

    let st = run_deposit_to(&mut h, &alice, bob_addr, 50);
    assert_kept_failure(&st, "deposit_to to frozen recipient should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::deposit_to_rejects_when_recipient_frozen",
        vec![],
        txn_outcome(&st),
    )]
}

/// Self **`deposit`** after **`freeze_token`** on the same account — **`deposit_to_internal`** checks **`!is_frozen(to, …)`** with **`to` = sender**, so this hits the same **`196615`** as cross-party **`deposit_to`** / **`confidential_transfer`** to a frozen recipient.
pub(super) fn deposit_rejects_when_account_frozen_self_deposit_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0x71);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    assert_kept_success(&run_freeze_token(&mut h, &account), "freeze_token self");

    let st = run_deposit(&mut h, &account, 50);
    assert_kept_failure(&st, "deposit to self while frozen should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::deposit_rejects_when_account_frozen_self_deposit_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// Second **`freeze_token`** when the store is already frozen — **`EALREADY_FROZEN`** (**`196615`**).
pub(super) fn freeze_token_aborts_when_already_frozen_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0x51);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    assert_kept_success(&run_freeze_token(&mut h, &account), "first freeze_token");
    let st = run_freeze_token(&mut h, &account);
    assert_kept_failure(&st, "second freeze_token should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::freeze_token_aborts_when_already_frozen_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// **`unfreeze_token`** without a prior **`freeze_token`** — **`ENOT_FROZEN`** (**`196616`**).
pub(super) fn unfreeze_token_aborts_when_not_frozen_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0x61);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let st = run_unfreeze_token(&mut h, &account);
    assert_kept_failure(&st, "unfreeze_token when not frozen should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::unfreeze_token_aborts_when_not_frozen_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// Second **`register`** for the same user+token — **`error::already_exists(ECA_STORE_ALREADY_PUBLISHED)`** ⇒ **`524290`** (`0x80002`).
pub(super) fn register_aborts_when_store_already_published_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0x81);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let st = run_register(&mut h, &account, &ek_pk, &c, &r);
    assert_kept_failure(&st, "second register should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::register_aborts_when_store_already_published_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// Second **`rollover_pending_balance`** while the store is denormalized (after a prior rollover, before **`normalize`**) — **`ENORMALIZATION_REQUIRED`** ⇒ **`196618`** (`0x3000A`).
pub(super) fn rollover_pending_balance_aborts_when_denormalized_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0x82);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");
    assert_kept_success(&run_deposit(&mut h, &account, 100), "deposit");
    assert_kept_success(&run_rollover(&mut h, &account), "first rollover");

    let st = run_rollover(&mut h, &account);
    assert_kept_failure(&st, "second rollover while denormalized should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::rollover_pending_balance_aborts_when_denormalized_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// Second framework **`enable_token`** when **`FAConfig.allowed`** is already **`true`** — **`ETOKEN_ENABLED`** ⇒ **`196620`** (`0x3000C`).
pub(super) fn enable_token_aborts_when_already_enabled_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let args = confidential_asset_enable_token_bypass_args();
    let first = bypass_outcome(&mut h, "enable_token", args.clone());
    assert!(
        matches!(first, TestResult::Returned { ref values } if values.is_empty()),
        "first enable_token expected void success, got {first:?}"
    );
    let second = bypass_outcome(&mut h, "enable_token", args);
    assert!(
        matches!(second, TestResult::Aborted { .. }),
        "second enable_token expected abort, got {second:?}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::enable_token_aborts_when_already_enabled_only",
        vec![],
        second,
    )]
}

/// **`deposit_to_internal`** rejects **`!is_token_allowed`** after **`enable_allow_list`** when no **`FAConfig`** row exists yet — **`ETOKEN_DISABLED`** ⇒ **`65549`** (`0x1000D`).
pub(super) fn deposit_rejects_when_token_not_allowlisted_after_allow_list_enabled_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0x91);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let al_args = confidential_asset_allow_list_governance_bypass_args();
    let al_first = bypass_outcome(&mut h, "enable_allow_list", al_args.clone());
    assert!(
        matches!(al_first, TestResult::Returned { ref values } if values.is_empty()),
        "enable_allow_list expected success, got {al_first:?}"
    );

    let st = run_deposit(&mut h, &account, 50);
    assert_kept_failure(&st, "deposit should abort when token not on allow list");

    vec![vm_lean_row(
        "confidential_asset_e2e::deposit_rejects_when_token_not_allowlisted_after_allow_list_enabled_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// Second **`enable_allow_list`** — **`EALLOW_LIST_ENABLED`** (**14**) ⇒ **`196622`** (`0x3000E`).
pub(super) fn enable_allow_list_aborts_when_already_enabled_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let args = confidential_asset_allow_list_governance_bypass_args();
    let first = bypass_outcome(&mut h, "enable_allow_list", args.clone());
    assert!(
        matches!(first, TestResult::Returned { ref values } if values.is_empty()),
        "first enable_allow_list expected success, got {first:?}"
    );
    let second = bypass_outcome(&mut h, "enable_allow_list", args);
    assert!(
        matches!(second, TestResult::Aborted { .. }),
        "second enable_allow_list expected abort, got {second:?}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::enable_allow_list_aborts_when_already_enabled_only",
        vec![],
        second,
    )]
}

/// Second **`disable_allow_list`** after the list is already off — **`EALLOW_LIST_DISABLED`** (**15**) ⇒ **`196623`** (`0x3000F`).
pub(super) fn disable_allow_list_aborts_when_already_disabled_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let args = confidential_asset_allow_list_governance_bypass_args();
    let first = bypass_outcome(&mut h, "enable_allow_list", args.clone());
    assert!(
        matches!(first, TestResult::Returned { ref values } if values.is_empty()),
        "enable_allow_list expected success, got {first:?}"
    );
    let dis_first = bypass_outcome(&mut h, "disable_allow_list", args.clone());
    assert!(
        matches!(dis_first, TestResult::Returned { ref values } if values.is_empty()),
        "first disable_allow_list expected success, got {dis_first:?}"
    );
    let second = bypass_outcome(&mut h, "disable_allow_list", args);
    assert!(
        matches!(second, TestResult::Aborted { .. }),
        "second disable_allow_list expected abort, got {second:?}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::disable_allow_list_aborts_when_already_disabled_only",
        vec![],
        second,
    )]
}

/// **`register_internal`** hits **`!is_token_allowed`** when **`enable_allow_list`** ran before any **`enable_token`**
/// (no **`FAConfig`** for the metadata) — same **`65549`** as **`deposit`** in that configuration.
pub(super) fn register_rejects_when_token_not_allowlisted_after_allow_list_enabled_first_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0xB1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);

    let al_args = confidential_asset_allow_list_governance_bypass_args();
    let al_first = bypass_outcome(&mut h, "enable_allow_list", al_args);
    assert!(
        matches!(al_first, TestResult::Returned { ref values } if values.is_empty()),
        "enable_allow_list expected success, got {al_first:?}"
    );

    let st = run_register(&mut h, &account, &ek_pk, &c, &r);
    assert_kept_failure(&st, "register should abort when token not on allow list");

    vec![vm_lean_row(
        "confidential_asset_e2e::register_rejects_when_token_not_allowlisted_after_allow_list_enabled_first_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// **`disable_token`** then **`deposit`** with allow list on — **`is_token_allowed`** is **`false`** ⇒ **`65549`**.
pub(super) fn deposit_rejects_after_disable_token_with_allow_list_on_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0xB2);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let tok_args = confidential_asset_token_toggle_bypass_args();
    let en_tok = bypass_outcome(&mut h, "enable_token", tok_args.clone());
    assert!(
        matches!(en_tok, TestResult::Returned { ref values } if values.is_empty()),
        "enable_token expected success, got {en_tok:?}"
    );

    let al_args = confidential_asset_allow_list_governance_bypass_args();
    let al_first = bypass_outcome(&mut h, "enable_allow_list", al_args);
    assert!(
        matches!(al_first, TestResult::Returned { ref values } if values.is_empty()),
        "enable_allow_list expected success, got {al_first:?}"
    );

    let dis_tok = bypass_outcome(&mut h, "disable_token", tok_args);
    assert!(
        matches!(dis_tok, TestResult::Returned { ref values } if values.is_empty()),
        "disable_token expected success, got {dis_tok:?}"
    );

    let st = run_deposit(&mut h, &account, 50);
    assert_kept_failure(&st, "deposit should abort after disable_token under allow list");

    vec![vm_lean_row(
        "confidential_asset_e2e::deposit_rejects_after_disable_token_with_allow_list_on_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// **`freeze_token_internal`** without a published **`ConfidentialAssetStore`** — **`not_found(ECA_STORE_NOT_PUBLISHED)`** ⇒ **`393219`** (`0x60003`).
pub(super) fn freeze_token_aborts_when_store_not_published_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let u = confidential_e2e_addr(0xEA, 0xB3);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);

    let st = run_freeze_token(&mut h, &account);
    assert_kept_failure(&st, "freeze_token without register should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::freeze_token_aborts_when_store_not_published_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// **`unfreeze_token_internal`** without a published **`ConfidentialAssetStore`** — same **`not_found`** as **`freeze_token`** (**`393219`**).
pub(super) fn unfreeze_token_aborts_when_store_not_published_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let u = confidential_e2e_addr(0xEA, 0xB5);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);

    let st = run_unfreeze_token(&mut h, &account);
    assert_kept_failure(&st, "unfreeze_token without register should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::unfreeze_token_aborts_when_store_not_published_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// **`rollover_pending_balance_internal`** without a store — **`not_found(ECA_STORE_NOT_PUBLISHED)`** ⇒ **`393219`**.
pub(super) fn rollover_pending_balance_aborts_when_store_not_published_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let u = confidential_e2e_addr(0xEA, 0xB6);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);

    let st = run_rollover(&mut h, &account);
    assert_kept_failure(&st, "rollover_pending_balance without register should abort");

    vec![vm_lean_row(
        "confidential_asset_e2e::rollover_pending_balance_aborts_when_store_not_published_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// **`rollover_pending_balance_and_freeze`** calls **`rollover_pending_balance`** first — no store ⇒ same **`393219`** before **`freeze_token`** runs.
pub(super) fn rollover_pending_balance_and_freeze_aborts_when_store_not_published_only_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let u = confidential_e2e_addr(0xEA, 0xB7);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);

    let st = run_rollover_and_freeze(&mut h, &account);
    assert_kept_failure(
        &st,
        "rollover_pending_balance_and_freeze without register should abort",
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::rollover_pending_balance_and_freeze_aborts_when_store_not_published_only",
        vec![],
        txn_outcome(&st),
    )]
}

/// Second **`disable_token`** when **`FAConfig.allowed`** is already **`false`** — **`invalid_state(ETOKEN_DISABLED)`** ⇒ **`196621`** (`0x3000D`).
pub(super) fn disable_token_aborts_when_already_disabled_only_cases() -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xEA, 0xB4);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, MOVE_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let tok_args = confidential_asset_token_toggle_bypass_args();
    let en_tok = bypass_outcome(&mut h, "enable_token", tok_args.clone());
    assert!(
        matches!(en_tok, TestResult::Returned { ref values } if values.is_empty()),
        "enable_token expected success, got {en_tok:?}"
    );

    let al_args = confidential_asset_allow_list_governance_bypass_args();
    assert!(
        matches!(
            bypass_outcome(&mut h, "enable_allow_list", al_args),
            TestResult::Returned { ref values } if values.is_empty()
        ),
        "enable_allow_list expected success"
    );

    let dis1 = bypass_outcome(&mut h, "disable_token", tok_args.clone());
    assert!(
        matches!(dis1, TestResult::Returned { ref values } if values.is_empty()),
        "first disable_token expected success, got {dis1:?}"
    );

    let second = bypass_outcome(&mut h, "disable_token", tok_args);
    assert!(
        matches!(second, TestResult::Aborted { .. }),
        "second disable_token expected abort, got {second:?}"
    );

    vec![vm_lean_row(
        "confidential_asset_e2e::disable_token_aborts_when_already_disabled_only",
        vec![],
        second,
    )]
}

pub(super) fn confidential_transfer_rejects_non_matching_asset_auditor_pubkey_cases(
) -> Vec<TestCase> {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xE8, 1);
    let bob_addr = confidential_e2e_addr(0xE8, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

    let (_real_aud_dk, real_aud_ek) = generate_elgamal_keypair(&mut h);
    let _real_aud_pk = twisted_pubkey_bytes(&mut h, &real_aud_ek);
    set_asset_auditor(&mut h, &_real_aud_pk);

    let (_wrong_dk, wrong_ek) = generate_elgamal_keypair(&mut h);
    let wrong_pk = twisted_pubkey_bytes(&mut h, &wrong_ek);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in
        [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)]
    {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    assert_kept_success(&run_deposit(&mut h, &alice, 2_000), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

    let parts = pack_transfer_audited(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        100,
        1900,
        vec![wrong_pk],
        vec![],
    );
    let st = run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]);
    assert_kept_failure(&st, "first auditor EK must match asset auditor");

    vec![vm_lean_row(
        "confidential_asset_e2e::confidential_transfer_rejects_non_matching_asset_auditor_pubkey",
        vec![],
        txn_outcome(&st),
    )]
}

pub(super) fn all_fragment_cases() -> Vec<TestCase> {
    let mut v = Vec::new();
    v.extend(register_deposit_rollover_and_gas_cases());
    v.extend(rollover_and_freeze_only_cases());
    v.extend(rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_actual_balance_matches_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_zero_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(is_frozen_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(encryption_key_view_matches_new_ek_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_actual_balance_rejects_stale_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(is_normalized_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_matches_second_deposit_after_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_actual_balance_matches_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_rejects_zero_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_actual_balance_rejects_zero_after_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only_cases());
    v.extend(confidential_asset_balance_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(pending_balance_view_return_len_265_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(actual_balance_view_return_len_529_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(has_confidential_asset_store_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_rejects_stale_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(confidential_asset_balance_matches_10003_after_post_unfreeze_deposit_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(is_token_allowed_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(get_auditor_returns_none_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_matches_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(is_allow_list_enabled_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_rejects_wrong_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_actual_balance_rejects_wrong_amount_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(confidential_asset_balance_matches_8901_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_rejects_sum_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_actual_balance_rejects_amount_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(encryption_key_view_matches_new_ek_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(is_frozen_false_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(confidential_asset_balance_matches_6601_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(is_normalized_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(has_confidential_asset_store_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_matches_sum_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_pending_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(verify_actual_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only_cases());
    v.extend(confidential_asset_balance_matches_7111_after_four_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases());
    v.extend(rotate_encryption_key_after_freeze_only_cases());
    v.extend(freeze_then_unfreeze_only_cases());
    v.extend(rollover_then_normalize_only_cases());
    v.extend(is_normalized_false_after_rollover_only_cases());
    v.extend(is_frozen_true_after_freeze_token_only_cases());
    v.extend(has_confidential_asset_store_false_before_register_only_cases());
    v.extend(encryption_key_view_matches_registered_ek_only_cases());
    v.extend(encryption_key_view_matches_new_ek_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_actual_balance_matches_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_pending_balance_zero_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_pending_balance_rejects_nonzero_with_stale_dk_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_zero_after_deposit_rollover_and_rotate_when_actual_nonzero_only_cases());
    v.extend(verify_pending_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_rotate_only_cases());
    v.extend(verify_actual_balance_matches_after_deposit_rollover_withdraw_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_stale_dk_after_deposit_rollover_withdraw_and_rotate_only_cases());
    v.extend(verify_actual_balance_matches_sum_after_two_deposits_rollover_and_rotate_only_cases());
    v.extend(verify_pending_balance_rejects_stale_sum_after_two_deposits_rollover_and_rotate_only_cases());
    v.extend(verify_pending_balance_zero_after_deposit_rollover_withdraw_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_withdraw_and_rotate_only_cases());
    v.extend(verify_actual_balance_matches_after_deposit_rollover_normalize_and_rotate_only_cases());
    v.extend(encryption_key_view_matches_new_ek_after_deposit_rollover_normalize_and_rotate_only_cases());
    v.extend(verify_pending_balance_zero_after_deposit_rollover_normalize_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_stale_dk_after_deposit_rollover_normalize_and_rotate_only_cases());
    v.extend(verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_normalize_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_normalize_and_rotate_only_cases());
    v.extend(verify_actual_balance_matches_after_deposit_rollover_and_freeze_and_rotate_only_cases());
    v.extend(encryption_key_view_matches_new_ek_after_deposit_rollover_and_freeze_and_rotate_only_cases());
    v.extend(verify_pending_balance_zero_after_deposit_rollover_and_freeze_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_freeze_and_rotate_only_cases());
    v.extend(verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_freeze_and_rotate_only_cases());
    v.extend(rotate_encryption_key_aborts_when_pending_nonzero_after_deposit_rollover_and_second_deposit_only_cases());
    v.extend(is_frozen_true_after_deposit_rollover_and_freeze_and_rotate_only_cases());
    v.extend(verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_freeze_and_rotate_only_cases());
    v.extend(has_confidential_asset_store_true_after_register_only_cases());
    v.extend(is_token_allowed_true_for_metadata_only_cases());
    v.extend(is_allow_list_enabled_false_in_tests_only_cases());
    v.extend(get_auditor_returns_none_for_move_metadata_no_fa_config_only_cases());
    v.extend(is_normalized_true_after_register_only_cases());
    v.extend(is_frozen_false_after_unfreeze_only_cases());
    v.extend(is_frozen_false_after_register_only_cases());
    v.extend(has_confidential_asset_store_false_for_peer_not_registered_cases());
    v.extend(is_frozen_true_after_rollover_and_freeze_only_cases());
    v.extend(is_normalized_true_after_normalize_only_cases());
    v.extend(verify_actual_balance_matches_after_deposit_rollover_and_normalize_only_cases());
    v.extend(verify_pending_balance_zero_after_deposit_rollover_and_normalize_only_cases());
    v.extend(verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_normalize_only_cases());
    v.extend(
        verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_normalize_only_cases(),
    );
    v.extend(
        verify_actual_balance_rejects_zero_after_deposit_rollover_and_normalize_when_actual_nonzero_cases(),
    );
    v.extend(verify_pending_balance_rejects_nonzero_after_deposit_rollover_and_normalize_only_cases());
    v.extend(
        verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_normalize_only_cases(),
    );
    v.extend(confidential_asset_balance_matches_single_deposit_only_cases());
    v.extend(confidential_asset_balance_after_two_deposits_only_cases());
    v.extend(confidential_asset_balance_after_deposit_and_withdraw_only_cases());
    v.extend(confidential_asset_balance_after_deposit_to_only_cases());
    v.extend(confidential_asset_balance_after_confidential_transfer_only_cases());
    v.extend(confidential_asset_balance_after_transfer_and_second_deposit_only_cases());
    v.extend(confidential_asset_balance_after_two_deposit_to_only_cases());
    v.extend(deposit_to_cross_party_only_cases());
    v.extend(withdraw_entry_self_only_cases());
    v.extend(transfer_withdraw_rotate_and_auditor_cases());
    v.extend(pending_balance_view_return_len_265_after_register_only_cases());
    v.extend(actual_balance_view_return_len_529_after_register_only_cases());
    v.extend(pending_balance_view_matches_deposit_cases());
    v.extend(verify_pending_balance_zero_after_register_only_cases());
    v.extend(verify_pending_balance_rejects_nonzero_after_register_only_cases());
    v.extend(verify_actual_balance_zero_after_register_only_cases());
    v.extend(verify_actual_balance_rejects_nonzero_after_register_only_cases());
    v.extend(verify_actual_balance_matches_after_deposit_and_rollover_only_cases());
    v.extend(verify_actual_balance_matches_sum_after_two_deposits_and_rollover_only_cases());
    v.extend(verify_actual_balance_matches_after_deposit_rollover_and_withdraw_only_cases());
    v.extend(verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_withdraw_only_cases());
    v.extend(verify_pending_balance_zero_after_deposit_rollover_and_withdraw_only_cases());
    v.extend(verify_actual_balance_rejects_wrong_sum_after_two_deposits_and_rollover_only_cases());
    v.extend(verify_pending_balance_zero_after_deposit_and_rollover_only_cases());
    v.extend(verify_pending_balance_matches_after_deposit_only_no_rollover_cases());
    v.extend(verify_pending_balance_matches_sum_after_two_deposits_no_rollover_cases());
    v.extend(verify_pending_balance_rejects_wrong_sum_after_two_deposits_no_rollover_cases());
    v.extend(verify_pending_balance_rejects_zero_after_two_deposits_no_rollover_cases());
    v.extend(verify_pending_balance_rejects_zero_after_deposit_only_no_rollover_cases());
    v.extend(verify_pending_balance_rejects_wrong_amount_after_deposit_only_no_rollover_cases());
    v.extend(verify_actual_balance_zero_after_deposit_only_no_rollover_cases());
    v.extend(verify_actual_balance_rejects_nonzero_after_deposit_only_no_rollover_cases());
    v.extend(verify_actual_balance_rejects_nonzero_sum_after_two_deposits_no_rollover_cases());
    v.extend(verify_actual_balance_rejects_wrong_sum_after_two_deposits_no_rollover_cases());
    v.extend(verify_actual_balance_rejects_sum_plus_one_after_two_deposits_no_rollover_cases());
    v.extend(verify_actual_balance_rejects_wrong_amount_after_deposit_and_rollover_only_cases());
    v.extend(verify_actual_balance_rejects_zero_after_deposit_and_rollover_when_actual_nonzero_cases());
    v.extend(verify_pending_balance_rejects_nonzero_after_deposit_and_rollover_only_cases());
    v.extend(verify_pending_balance_rejects_stale_deposit_amount_after_deposit_and_rollover_only_cases());
    v.extend(verify_pending_balance_rejects_stale_sum_after_two_deposits_and_rollover_only_cases());
    v.extend(verify_pending_balance_rejects_wrong_amount_after_two_deposits_and_rollover_only_cases());
    v.extend(compare_plain_fa_transfer_gas_cases());
    v.extend(confidential_transfer_with_voluntary_auditors_only_cases());
    v.extend(confidential_transfer_asset_auditor_plus_voluntary_auditors_cases());
    v.extend(confidential_withdraw_without_asset_auditor_cases());
    v.extend(confidential_withdraw_after_asset_auditor_enabled_cases());
    v.extend(confidential_transfer_rejects_empty_auditors_when_asset_auditor_set_cases());
    v.extend(confidential_transfer_rejects_non_matching_asset_auditor_pubkey_cases());
    v.extend(confidential_transfer_rejects_mismatched_sender_recipient_amount_ciphertexts_cases());
    v.extend(confidential_transfer_rejects_when_recipient_frozen_cases());
    v.extend(normalize_aborts_when_already_normalized_only_cases());
    v.extend(deposit_to_rejects_when_recipient_frozen_cases());
    v.extend(deposit_rejects_when_account_frozen_self_deposit_only_cases());
    v.extend(register_aborts_when_store_already_published_only_cases());
    v.extend(rollover_pending_balance_aborts_when_denormalized_only_cases());
    v.extend(enable_token_aborts_when_already_enabled_only_cases());
    v.extend(deposit_rejects_when_token_not_allowlisted_after_allow_list_enabled_only_cases());
    v.extend(enable_allow_list_aborts_when_already_enabled_only_cases());
    v.extend(disable_allow_list_aborts_when_already_disabled_only_cases());
    v.extend(register_rejects_when_token_not_allowlisted_after_allow_list_enabled_first_only_cases());
    v.extend(deposit_rejects_after_disable_token_with_allow_list_on_only_cases());
    v.extend(freeze_token_aborts_when_store_not_published_only_cases());
    v.extend(unfreeze_token_aborts_when_store_not_published_only_cases());
    v.extend(rollover_pending_balance_aborts_when_store_not_published_only_cases());
    v.extend(rollover_pending_balance_and_freeze_aborts_when_store_not_published_only_cases());
    v.extend(disable_token_aborts_when_already_disabled_only_cases());
    v.extend(freeze_token_aborts_when_already_frozen_only_cases());
    v.extend(unfreeze_token_aborts_when_not_frozen_only_cases());
    v
}

/// Writes [`OracleFragment`] JSON when `CONFIDENTIAL_ASSET_E2E_ORACLE_OUT` is set (used by CI merge).
#[test]
fn export_confidential_asset_e2e_oracle_fragment() {
    let Some(out) = std::env::var_os("CONFIDENTIAL_ASSET_E2E_ORACLE_OUT") else {
        return;
    };
    let out_path = {
        let p = Path::new(&out);
        if p.is_absolute() {
            p.to_path_buf()
        } else {
            // `e2e-move-tests` lives at `aptos-move/e2e-move-tests`; repo root is two parents up.
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..").join(p)
        }
    };
    let frag = OracleFragment {
        test_cases: all_fragment_cases(),
    };
    let json = serde_json::to_string_pretty(&frag).expect("serialize OracleFragment");
    std::fs::write(&out_path, json).unwrap_or_else(|e| {
        panic!("write oracle fragment {}: {e}", out_path.display());
    });
}

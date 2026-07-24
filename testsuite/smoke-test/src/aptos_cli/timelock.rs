// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! End-to-end smoke tests for the `aptos timelock` CLI subcommand.
//!
//! The successful `execute` path is NOT tested here: `MIN_NUM_SECONDS_EXECUTE` is 3600s and a live
//! swarm runs on real wall clock with no fast-forward, so "propose -> wait -> execute" is
//! infeasible. That path (and the self-governance effects) is covered by the VM-harness tests in
//! `aptos-move/e2e-move-tests/src/tests/timelock.rs`. These tests cover the time-independent CLI
//! surface and `execute`'s pre-flight checks (delay-not-elapsed, hash-mismatch) that reject before
//! gas. Argument-parser coverage lives in `crates/aptos/src/test/tests.rs`.

#![cfg(feature = "cli-framework-test-move")]

use crate::smoke_test_environment::SwarmBuilder;
use move_core_types::account_address::AccountAddress;
use std::path::PathBuf;
use tempfile::TempDir;

/// `timelock::MIN_NUM_SECONDS_EXECUTE`, the chosen delay. Cannot be waited out on a live swarm.
const DELAY_SECS: u64 = 3600;

/// Fixed 32-byte salt (no `0x` prefix), shared by the CLI `--salt` flag and the script's `x"..."`
/// literal so the proposal hash is reproducible.
const SALT_HEX: &str = "00000000000000000000000000000000000000000000000000000000000000aa";
/// A distinct salt, yielding a script with a different hash for the mismatch tests.
const OTHER_SALT_HEX: &str = "00000000000000000000000000000000000000000000000000000000000000bb";

/// A self-contained resolution script: derives the proposal hash from its own bytecode hash and
/// the baked-in salt, then resolves the timelock.
fn resolution_script(timelock_address: AccountAddress, salt_hex: &str) -> String {
    format!(
        r#"script {{
    use aptos_framework::timelock;
    use aptos_framework::transaction_context;

    fun main(executor: &signer) {{
        let execution_hash = transaction_context::get_script_hash();
        let proposal_hash = timelock::get_proposal_hash(execution_hash, x"{salt}");
        let _timelock_signer = timelock::resolve(executor, @{addr}, proposal_hash);
    }}
}}
"#,
        salt = salt_hex,
        addr = timelock_address.to_hex_literal(),
    )
}

/// Write `contents` to a `script.move` inside `dir` and return its path. The caller must
/// keep `dir` alive until compilation finishes.
fn write_script(dir: &TempDir, contents: &str) -> PathBuf {
    let path = dir.path().join("script.move");
    std::fs::write(&path, contents).unwrap();
    path
}

fn salt_flag(salt_hex: &str) -> String {
    format!("0x{}", salt_hex)
}

// ----------------------------------------------------------------------------
// create + membership
// ----------------------------------------------------------------------------

/// The deployer gains no authority; creators/executors are exactly the provided lists, and
/// with a non-empty executor list a creator is NOT an executor.
#[tokio::test]
async fn test_timelock_create_membership() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(3)
        .await;
    let (deployer, creator, executor) = (0, 1, 2);

    let timelock = cli
        .create_timelock(
            deployer,
            vec![cli.account_id(creator)],
            vec![cli.account_id(executor)],
            DELAY_SECS,
        )
        .await
        .expect("create should succeed");

    // Provided members hold their roles.
    assert!(cli.timelock_is_creator(0, cli.account_id(creator), timelock).await);
    assert!(cli.timelock_is_executor(0, cli.account_id(executor), timelock).await);
    // The deployer gains nothing.
    assert!(!cli.timelock_is_creator(0, cli.account_id(deployer), timelock).await);
    assert!(!cli.timelock_is_executor(0, cli.account_id(deployer), timelock).await);
    // With a non-empty executor list, a creator is not implicitly an executor.
    assert!(!cli.timelock_is_executor(0, cli.account_id(creator), timelock).await);
}

/// With an empty executor list, creators are reported as executors (the "creator acts as
/// executor" rule that governs `execute` when no dedicated executor exists).
#[tokio::test]
async fn test_timelock_create_empty_executors_creator_is_executor() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");

    assert!(cli.timelock_is_creator(0, cli.account_id(0), timelock).await);
    assert!(cli.timelock_is_executor(0, cli.account_id(0), timelock).await);
}

// ----------------------------------------------------------------------------
// propose + verify + execute pre-flight
// ----------------------------------------------------------------------------

/// Propose a resolution script, verify it matches (and that a different script does not),
/// then confirm `execute` is rejected by its pre-flight because the delay has not elapsed —
/// without submitting a transaction.
#[tokio::test]
async fn test_timelock_propose_verify_and_execute_preflight() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");

    let dir = TempDir::new().unwrap();
    let script = write_script(&dir, &resolution_script(timelock, SALT_HEX));

    let summary = cli
        .create_timelock_transaction(
            0,
            timelock,
            script.clone(),
            DELAY_SECS,
            Some(salt_flag(SALT_HEX)),
            None,
        )
        .await
        .expect("propose should succeed");
    let proposal_hash = summary
        .proposal_hash
        .expect("proposal should emit a proposal hash");
    assert_eq!(summary.salt, salt_flag(SALT_HEX));

    // Verifying with the same script matches the on-chain execution hash.
    cli.verify_timelock_transaction(0, timelock, proposal_hash.clone(), script.clone())
        .await
        .expect("verify should match");

    // A different script (different baked-in salt -> different bytecode) does not match.
    let other_dir = TempDir::new().unwrap();
    let other_script = write_script(&other_dir, &resolution_script(timelock, OTHER_SALT_HEX));
    let mismatch = cli
        .verify_timelock_transaction(0, timelock, proposal_hash.clone(), other_script.clone())
        .await
        .expect_err("verify should report a mismatch");
    assert!(mismatch.to_string().contains("mismatch"));

    // The proposal is not yet executable (delay not elapsed).
    let txn_hash_bytes = hex::decode(proposal_hash.trim_start_matches("0x")).unwrap();
    assert!(
        !cli.timelock_can_be_executed(0, timelock, txn_hash_bytes)
            .await
    );

    // execute's pre-flight rejects before paying gas, with the delay message.
    let not_elapsed = cli
        .execute_timelock(0, timelock, proposal_hash.clone(), script.clone())
        .await
        .expect_err("execute should be rejected before the delay elapses");
    assert!(not_elapsed.to_string().contains("has not elapsed"));

    // Executing a script whose hash does not match the proposal is rejected at pre-flight.
    let wrong_script = cli
        .execute_timelock(0, timelock, proposal_hash, other_script)
        .await
        .expect_err("execute with the wrong script should be rejected");
    assert!(wrong_script.to_string().contains("mismatch"));
}

/// Proposing the same script + salt twice fails (duplicate transaction).
#[tokio::test]
async fn test_timelock_duplicate_proposal_fails() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");
    let dir = TempDir::new().unwrap();
    let script = write_script(&dir, &resolution_script(timelock, SALT_HEX));

    cli.create_timelock_transaction(
        0,
        timelock,
        script.clone(),
        DELAY_SECS,
        Some(salt_flag(SALT_HEX)),
        None,
    )
    .await
    .expect("first propose should succeed");

    cli.create_timelock_transaction(
        0,
        timelock,
        script,
        DELAY_SECS,
        Some(salt_flag(SALT_HEX)),
        None,
    )
    .await
    .expect_err("duplicate propose should fail");
}

/// A non-creator cannot propose.
#[tokio::test]
async fn test_timelock_non_creator_cannot_propose() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(2)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");
    let dir = TempDir::new().unwrap();
    let script = write_script(&dir, &resolution_script(timelock, SALT_HEX));

    // Account 1 is neither a creator nor an executor.
    cli.create_timelock_transaction(
        1,
        timelock,
        script,
        DELAY_SECS,
        Some(salt_flag(SALT_HEX)),
        None,
    )
    .await
    .expect_err("non-creator propose should fail");
}

/// A `--script-path-uri` longer than the on-chain max is rejected client-side, before submit.
#[tokio::test]
async fn test_timelock_script_path_uri_too_long_fails() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");
    let dir = TempDir::new().unwrap();
    let script = write_script(&dir, &resolution_script(timelock, SALT_HEX));

    let too_long = "x".repeat(257);
    cli.create_timelock_transaction(
        0,
        timelock,
        script,
        DELAY_SECS,
        Some(salt_flag(SALT_HEX)),
        Some(too_long),
    )
    .await
    .expect_err("over-long script-path-uri should be rejected");
}

// ----------------------------------------------------------------------------
// cancel
// ----------------------------------------------------------------------------

/// A creator can cancel; afterwards the proposal is not executable and `execute` reports it
/// as already executed/canceled, and a second cancel fails.
#[tokio::test]
async fn test_timelock_cancel_by_creator() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");
    let dir = TempDir::new().unwrap();
    let script = write_script(&dir, &resolution_script(timelock, SALT_HEX));

    let proposal_hash = cli
        .create_timelock_transaction(
            0,
            timelock,
            script.clone(),
            DELAY_SECS,
            Some(salt_flag(SALT_HEX)),
            None,
        )
        .await
        .expect("propose should succeed")
        .proposal_hash
        .expect("proposal should emit a proposal hash");

    cli.cancel_timelock_transaction(0, timelock, proposal_hash.clone())
        .await
        .expect("creator cancel should succeed");

    let txn_hash_bytes = hex::decode(proposal_hash.trim_start_matches("0x")).unwrap();
    assert!(
        !cli.timelock_can_be_executed(0, timelock, txn_hash_bytes)
            .await
    );

    let executed = cli
        .execute_timelock(0, timelock, proposal_hash.clone(), script)
        .await
        .expect_err("execute of a canceled proposal should be rejected");
    assert!(executed.to_string().contains("already been executed"));

    cli.cancel_timelock_transaction(0, timelock, proposal_hash)
        .await
        .expect_err("second cancel should fail");
}

/// A dedicated canceler (emergency-response role) can cancel even though it is not a creator,
/// while an executor — who can execute — cannot cancel.
#[tokio::test]
async fn test_timelock_canceler_cancels_executor_cannot() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(3)
        .await;
    let (creator, executor, canceler) = (0, 1, 2);

    let timelock = cli
        .create_timelock_with_cancelers(
            creator,
            vec![cli.account_id(creator)],
            vec![cli.account_id(executor)],
            vec![cli.account_id(canceler)],
            DELAY_SECS,
        )
        .await
        .expect("create should succeed");
    // The canceler holds only the canceler role.
    assert!(cli.timelock_is_canceler(0, cli.account_id(canceler), timelock).await);
    assert!(!cli.timelock_is_creator(0, cli.account_id(canceler), timelock).await);
    assert!(!cli.timelock_is_executor(0, cli.account_id(canceler), timelock).await);

    // Propose one transaction; the executor's cancel must be rejected, then the canceler cancels
    // that same still-pending proposal.
    let dir = TempDir::new().unwrap();
    let script = write_script(&dir, &resolution_script(timelock, SALT_HEX));
    let proposal_hash = cli
        .create_timelock_transaction(
            creator,
            timelock,
            script,
            DELAY_SECS,
            Some(salt_flag(SALT_HEX)),
            None,
        )
        .await
        .expect("propose should succeed")
        .proposal_hash
        .expect("proposal should emit a proposal hash");

    // The executor cannot cancel — it must be rejected specifically with the permission-denied
    // abort ENOT_CREATOR_OR_CANCELER (0x5000D), not some unrelated error.
    let err = cli
        .cancel_timelock_transaction(executor, timelock, proposal_hash.clone())
        .await
        .expect_err("executor must not be able to cancel")
        .to_string()
        .to_lowercase();
    assert!(
        err.contains("5000d"),
        "expected ENOT_CREATOR_OR_CANCELER (0x5000D) abort, got: {err}"
    );

    // The canceler can.
    cli.cancel_timelock_transaction(canceler, timelock, proposal_hash)
        .await
        .expect("canceler cancel should succeed");
}

/// An account that is neither a creator nor an executor cannot cancel.
#[tokio::test]
async fn test_timelock_cancel_by_non_member_fails() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(2)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");
    let dir = TempDir::new().unwrap();
    let script = write_script(&dir, &resolution_script(timelock, SALT_HEX));

    let proposal_hash = cli
        .create_timelock_transaction(
            0,
            timelock,
            script,
            DELAY_SECS,
            Some(salt_flag(SALT_HEX)),
            None,
        )
        .await
        .expect("propose should succeed")
        .proposal_hash
        .expect("proposal should emit a proposal hash");

    // Account 1 is neither creator nor executor.
    cli.cancel_timelock_transaction(1, timelock, proposal_hash)
        .await
        .expect_err("non-member cancel should fail");
}

// ----------------------------------------------------------------------------
// propose-by-hash, salt behavior, and not-found / validation paths
// ----------------------------------------------------------------------------

/// Propose with `--execution-hash` (no script compilation) and confirm the on-chain
/// proposal hash is `keccak256(execution_hash || salt)` as exposed by the
/// `get_proposal_hash` view.
#[tokio::test]
async fn test_timelock_propose_with_execution_hash() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");

    let execution_hash_hex = "11".repeat(32);
    let summary = cli
        .create_timelock_transaction_with_execution_hash(
            0,
            timelock,
            format!("0x{execution_hash_hex}"),
            DELAY_SECS,
            Some(salt_flag(SALT_HEX)),
            None,
        )
        .await
        .expect("propose by execution hash should succeed");

    assert_eq!(summary.execution_hash, format!("0x{execution_hash_hex}"));
    assert_eq!(summary.salt, salt_flag(SALT_HEX));
    let proposal_hash = summary
        .proposal_hash
        .expect("proposal should emit a proposal hash");

    let expected = cli
        .timelock_get_proposal_hash(
            0,
            hex::decode(&execution_hash_hex).unwrap(),
            hex::decode(SALT_HEX).unwrap(),
        )
        .await;
    assert_eq!(proposal_hash, expected);
}

/// Proposing the same execution hash twice without `--salt` succeeds both times because the
/// generated random salts differ, yielding distinct proposal hashes.
#[tokio::test]
async fn test_timelock_random_salt_distinct() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");
    let execution_hash = format!("0x{}", "22".repeat(32));

    let first = cli
        .create_timelock_transaction_with_execution_hash(
            0,
            timelock,
            execution_hash.clone(),
            DELAY_SECS,
            None,
            None,
        )
        .await
        .expect("first propose should succeed")
        .proposal_hash
        .expect("proposal should emit a proposal hash");
    let second = cli
        .create_timelock_transaction_with_execution_hash(
            0,
            timelock,
            execution_hash,
            DELAY_SECS,
            None,
            None,
        )
        .await
        .expect("second propose should succeed")
        .proposal_hash
        .expect("proposal should emit a proposal hash");

    assert_ne!(
        first, second,
        "random salts should yield distinct proposal hashes"
    );
}

/// verify, cancel, and execute against a proposal hash that was never proposed are all
/// rejected (the proposal is not found on-chain).
#[tokio::test]
async fn test_timelock_unknown_hash_is_rejected() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS)
        .await
        .expect("create should succeed");
    let dir = TempDir::new().unwrap();
    let script = write_script(&dir, &resolution_script(timelock, SALT_HEX));
    let unknown = format!("0x{}", "33".repeat(32));

    cli.verify_timelock_transaction(0, timelock, unknown.clone(), script.clone())
        .await
        .expect_err("verify of a non-existent proposal should fail");
    cli.cancel_timelock_transaction(0, timelock, unknown.clone())
        .await
        .expect_err("cancel of a non-existent proposal should fail");
    cli.execute_timelock(0, timelock, unknown, script)
        .await
        .expect_err("execute of a non-existent proposal should fail");
}

/// `create` rejects out-of-bounds delays (below the 3600s minimum, above the 7776000s / 90-day
/// maximum) and duplicate creators.
#[tokio::test]
async fn test_timelock_create_validation_fails() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    cli.create_timelock(0, vec![cli.account_id(0)], vec![], 100)
        .await
        .expect_err("delay below the minimum should fail");
    cli.create_timelock(0, vec![cli.account_id(0)], vec![], 7_776_001)
        .await
        .expect_err("delay above the maximum should fail");
    cli.create_timelock(
        0,
        vec![cli.account_id(0), cli.account_id(0)],
        vec![],
        DELAY_SECS,
    )
    .await
    .expect_err("duplicate creators should fail");
}

/// Proposing with a delay shorter than the timelock account's configured minimum is rejected.
#[tokio::test]
async fn test_timelock_propose_num_seconds_below_min_fails() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(1)
        .await;

    // Configure the account's minimum to twice the floor, then propose at the floor.
    let timelock = cli
        .create_timelock(0, vec![cli.account_id(0)], vec![], DELAY_SECS * 2)
        .await
        .expect("create should succeed");
    let execution_hash = format!("0x{}", "44".repeat(32));

    cli.create_timelock_transaction_with_execution_hash(
        0,
        timelock,
        execution_hash,
        DELAY_SECS,
        Some(salt_flag(SALT_HEX)),
        None,
    )
    .await
    .expect_err("num_seconds below the timelock minimum should fail");
}

/// `approve-resolution` is authorized like execution (an executor, or a creator when no executors)
/// AND, like `resolve`, requires the delay to have elapsed. A non-executor cannot approve, and even
/// an executor cannot approve before the delay elapses. The live swarm cannot fast-forward past the
/// 1-hour delay, so the successful post-delay approval is covered by the e2e (VM) tests; here we pin
/// the two pre-delay rejection paths.
#[tokio::test]
async fn test_timelock_approve_resolution_authorization() {
    let (_swarm, cli, _faucet) = SwarmBuilder::new_local(1)
        .with_aptos()
        .build_with_cli(3)
        .await;
    let (creator, executor, intruder) = (0, 1, 2);

    let timelock = cli
        .create_timelock(
            creator,
            vec![cli.account_id(creator)],
            vec![cli.account_id(executor)],
            DELAY_SECS,
        )
        .await
        .expect("create should succeed");

    // Propose by raw execution hash (no script compilation needed for the approval check).
    let proposal_hash = cli
        .create_timelock_transaction_with_execution_hash(
            creator,
            timelock,
            format!("0x{}", "55".repeat(32)),
            DELAY_SECS,
            Some(salt_flag(SALT_HEX)),
            None,
        )
        .await
        .expect("propose should succeed")
        .proposal_hash
        .expect("proposal should emit a proposal hash");

    // A non-executor cannot approve (authorization is checked before the delay, so this is
    // rejected even pre-delay).
    cli.approve_timelock_resolution(intruder, timelock, proposal_hash.clone())
        .await
        .expect_err("non-executor must not be able to approve resolution");

    // Even the executor cannot approve before the delay elapses: approval mirrors `resolve` and
    // aborts with ETIMELOCK_NOT_EXPIRED. (The post-delay success path is covered by e2e tests,
    // since the live swarm cannot fast-forward the delay.)
    cli.approve_timelock_resolution(executor, timelock, proposal_hash)
        .await
        .expect_err("executor approve-resolution before the delay must be rejected");
}

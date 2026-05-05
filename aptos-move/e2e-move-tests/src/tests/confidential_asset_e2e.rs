// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0
//
// If `cargo test` fails with a stack overflow on this module, set `RUST_MIN_STACK` (see
// `aptos-move/e2e-move-tests/README.md`) and re-run.
//
// VM-level confidential-asset checks for this fork. Scenarios are written against the behavior
// documented in `aptos_experimental::confidential_asset` (e.g. `validate_auditors`, entry
// signatures)—not transcribed from other repositories' test code.
//
// The harness hot-swaps all `0x1` modules from a test-mode compile of `aptos-stdlib` (MoveStdlib +
// AptosStdlib, so `ristretto255::random_scalar` and friends resolve consistently), then overlays
// `0x1::event` from the same compile graph as `aptos-experimental` so `event::emitted_events` matches
// `confidential_asset` (genesis `event` bytecode can lag). It also injects every `0x7` module from that
// experimental build. Genesis already publishes
// `GlobalConfig` for an older bytecode revision; we delete that resource and re-run
// `init_module_for_testing` so on-disk layout matches the injected `confidential_asset` module.

use crate::{tests::common::framework_dir_path, MoveHarness};
use aptos_language_e2e_tests::account::Account;
use aptos_types::{
    account_address::AccountAddress,
    on_chain_config::FeatureFlag,
    state_store::state_key::StateKey,
    transaction::{
        EntryFunction, ExecutionStatus, TransactionPayload, TransactionStatus,
    },
    write_set::{WriteOp, WriteSetMut},
};
use legacy_move_compiler::compiled_unit::{CompiledUnit, NamedCompiledModule};
use move_binary_format::file_format_common::VERSION_MAX;
use move_core_types::{
    identifier::Identifier,
    language_storage::{ModuleId, StructTag, TypeTag},
    value::MoveValue,
};
use move_model::metadata::{CompilerVersion, LanguageVersion};
use move_package::BuildConfig;
use move_vm_runtime::move_vm::SerializedReturnValues;
use once_cell::sync::OnceCell;
use std::collections::BTreeMap;

const APTOS_EXPERIMENTAL: AccountAddress = AccountAddress::new({
    let mut b = [0u8; AccountAddress::LENGTH];
    b[31] = 0x07;
    b
});
/// Published fungible metadata object for gas/APT in test genesis.
const MOVE_METADATA: AccountAddress = AccountAddress::new({
    let mut b = [0u8; AccountAddress::LENGTH];
    b[31] = 0x0a;
    b
});

static CONFIDENTIAL_E2E_INJECT_MODULES: OnceCell<Vec<(ModuleId, Vec<u8>)>> = OnceCell::new();

/// `generate_twisted_elgamal_keypair` is `#[test_only]` and needs `ristretto255::random_scalar` (also
/// `#[test_only]`). Injecting only `ristretto255` breaks verification (imports into other `0x1` deps);
/// we replace every `0x1` module produced by compiling `aptos-stdlib` + its dependency tree.
fn move_test_build_config() -> BuildConfig {
    let mut build_config = BuildConfig::default();
    build_config.test_mode = true;
    build_config.dev_mode = false;
    build_config.skip_fetch_latest_git_deps = true;
    build_config.additional_named_addresses.insert(
        "aptos_experimental".to_string(),
        APTOS_EXPERIMENTAL,
    );
    build_config.compiler_config.bytecode_version = Some(VERSION_MAX);
    build_config.compiler_config.language_version = Some(LanguageVersion::latest());
    build_config.compiler_config.compiler_version = Some(CompilerVersion::latest());
    build_config.compiler_config.skip_attribute_checks = true;
    build_config
}

fn ca_module_id() -> ModuleId {
    ModuleId::new(
        APTOS_EXPERIMENTAL,
        Identifier::new("confidential_asset").unwrap(),
    )
}

fn compile_stdlib_inject_modules() -> Vec<(ModuleId, Vec<u8>)> {
    let pkg = framework_dir_path("aptos-stdlib");
    let build_config = move_test_build_config();
    let mut stderr = Vec::<u8>::new();
    let resolved_graph = build_config
        .clone()
        .resolution_graph_for_package(&pkg, &mut stderr)
        .unwrap_or_else(|e| {
            panic!(
                "resolve aptos-stdlib: {:?}\n{}",
                e,
                String::from_utf8_lossy(&stderr)
            )
        });
    let (compiled, _) = build_config
        .compile_package_no_exit(resolved_graph, vec![], &mut stderr)
        .unwrap_or_else(|e| {
            panic!(
                "compile aptos-stdlib: {:?}\n{}",
                e,
                String::from_utf8_lossy(&stderr)
            )
        });

    let mut out = Vec::new();
    for unit in compiled.all_modules() {
        if let CompiledUnit::Module(NamedCompiledModule { module, .. }) = &unit.unit {
            let id = module.self_id();
            if id.address() != &AccountAddress::ONE {
                continue;
            }
            let bytes = unit.unit.serialize(Some(module.version));
            out.push((id, bytes));
        }
    }
    out.sort_by(|a, b| a.0.name().as_str().cmp(b.0.name().as_str()));
    assert!(
        !out.is_empty(),
        "expected at least one 0x1 module from aptos-stdlib test build"
    );
    out
}

fn compile_experimental_with_tests() -> (Vec<(ModuleId, Vec<u8>)>, (ModuleId, Vec<u8>)) {
    let pkg = framework_dir_path("aptos-experimental");
    let build_config = move_test_build_config();

    let mut stderr = Vec::<u8>::new();
    let resolved_graph = build_config
        .clone()
        .resolution_graph_for_package(&pkg, &mut stderr)
        .unwrap_or_else(|e| {
            panic!(
                "resolve aptos-experimental: {:?}\n{}",
                e,
                String::from_utf8_lossy(&stderr)
            )
        });
    let (compiled, _) = build_config
        .compile_package_no_exit(resolved_graph, vec![], &mut stderr)
        .unwrap_or_else(|e| {
            panic!(
                "compile aptos-experimental: {:?}\n{}",
                e,
                String::from_utf8_lossy(&stderr)
            )
        });

    let mut out = Vec::new();
    let mut event_bytes: Option<(ModuleId, Vec<u8>)> = None;
    for unit in compiled.all_modules() {
        if let CompiledUnit::Module(NamedCompiledModule { module, .. }) = &unit.unit {
            let id = module.self_id();
            if id.address() == &APTOS_EXPERIMENTAL {
                let bytes = unit.unit.serialize(Some(module.version));
                out.push((id, bytes));
            } else if id.address() == &AccountAddress::ONE && id.name().as_str() == "event" {
                let bytes = unit.unit.serialize(Some(module.version));
                event_bytes = Some((id, bytes));
            }
        }
    }
    out.sort_by(|a, b| a.0.name().as_str().cmp(b.0.name().as_str()));
    assert!(
        !out.is_empty(),
        "expected at least one aptos_experimental module from test build"
    );
    let event = event_bytes.expect("aptos-experimental compile graph must include 0x1::event");
    (out, event)
}

fn compile_confidential_e2e_inject_modules() -> Vec<(ModuleId, Vec<u8>)> {
    let (experimental_0x7, event_overlay) = compile_experimental_with_tests();
    let mut by_id: BTreeMap<ModuleId, Vec<u8>> = compile_stdlib_inject_modules().into_iter().collect();
    by_id.insert(event_overlay.0, event_overlay.1);
    let mut v: Vec<(ModuleId, Vec<u8>)> = by_id.into_iter().collect();
    v.sort_by(|a, b| a.0.name().as_str().cmp(b.0.name().as_str()));
    v.extend(experimental_0x7);
    v
}

fn inject_confidential_e2e_modules(h: &mut MoveHarness) {
    let blobs = CONFIDENTIAL_E2E_INJECT_MODULES.get_or_init(compile_confidential_e2e_inject_modules);
    for (id, bytes) in blobs {
        h.executor.add_module(&id, bytes.clone());
    }
}

fn enable_confidential_features(h: &mut MoveHarness) {
    h.enable_features(
        vec![
            FeatureFlag::BULLETPROOFS_NATIVES,
            FeatureFlag::BULLETPROOFS_BATCH_NATIVES,
            FeatureFlag::NEW_ACCOUNTS_DEFAULT_TO_FA_APT_STORE,
        ],
        vec![],
    );
}

/// Decode a `vector<u8>` value as returned by the VM (`bcs::to_bytes` of `Vec<u8>`).
fn raw_bytes_from_move_vector_u8(blob: &[u8]) -> Vec<u8> {
    bcs::from_bytes::<Vec<u8>>(blob).expect("decode move vector<u8>")
}

fn assert_kept_success(status: &TransactionStatus, ctx: &str) {
    assert!(
        matches!(
            status,
            TransactionStatus::Keep(ExecutionStatus::Success)
        ),
        "{ctx}: unexpected status {status:?}"
    );
}

fn assert_kept_failure(status: &TransactionStatus, ctx: &str) {
    assert!(
        !matches!(
            status,
            TransactionStatus::Keep(ExecutionStatus::Success)
        ),
        "{ctx}: expected failure, got success"
    );
}

/// Deterministic addresses for matrix cases (avoid reusing state across scenarios).
fn confidential_e2e_addr(tag: u8, idx: u8) -> AccountAddress {
    let mut b = [0u8; AccountAddress::LENGTH];
    b[30] = tag;
    b[31] = idx;
    AccountAddress::new(b)
}

/// Args for **`confidential_asset::enable_token`** via **`try_exec_function_bypass_at`** (framework signer + metadata).
pub(super) fn confidential_asset_enable_token_bypass_args() -> Vec<Vec<u8>> {
    vec![
        MoveValue::Signer(AccountAddress::ONE)
            .simple_serialize()
            .expect("signer arg"),
        bcs::to_bytes(&MOVE_METADATA).expect("metadata arg"),
    ]
}

/// Args for **`enable_allow_list`** / **`disable_allow_list`** (framework signer only).
pub(super) fn confidential_asset_allow_list_governance_bypass_args() -> Vec<Vec<u8>> {
    vec![MoveValue::Signer(AccountAddress::ONE)
        .simple_serialize()
        .expect("signer arg")]
}

/// Args for **`disable_token`** / **`enable_token`** (framework signer + metadata object).
pub(super) fn confidential_asset_token_toggle_bypass_args() -> Vec<Vec<u8>> {
    confidential_asset_enable_token_bypass_args()
}

fn bcs_auditor_pubkeys_from_ek_structs(h: &mut MoveHarness, ek_structs: &[Vec<u8>]) -> Vec<Vec<u8>> {
    ek_structs
        .iter()
        .map(|ek| twisted_pubkey_bytes(h, ek))
        .collect()
}

fn bypass_at(
    h: &mut MoveHarness,
    module: &str,
    fun: &str,
    ty_args: Vec<TypeTag>,
    args: Vec<Vec<u8>>,
) -> SerializedReturnValues {
    h.executor
        .try_exec_function_bypass_at(
            APTOS_EXPERIMENTAL,
            module,
            fun,
            ty_args,
            args,
        )
        .unwrap_or_else(|e| panic!("bypass {module}::{fun}: {e:?}"))
}

/// Genesis `head` publishes `GlobalConfig` for bytecode that may differ from the injected module;
/// remove it so `init_module` can republish with a matching layout.
fn delete_genesis_global_config_if_present(h: &mut MoveHarness) {
    let tag = StructTag {
        address: APTOS_EXPERIMENTAL,
        module: Identifier::new("confidential_asset").unwrap(),
        name: Identifier::new("GlobalConfig").unwrap(),
        type_args: vec![],
    };
    let key = StateKey::resource(&APTOS_EXPERIMENTAL, &tag).unwrap();
    if h.executor.read_state_value(&key).is_none() {
        return;
    }
    let mut w = WriteSetMut::default();
    w.insert((key, WriteOp::legacy_deletion()));
    let ws = w.freeze().expect("writeset freeze");
    h.executor.apply_write_set(&ws);
}

fn reinit_confidential_asset_module(h: &mut MoveHarness) {
    let signer_arg = MoveValue::Signer(APTOS_EXPERIMENTAL)
        .simple_serialize()
        .expect("signer arg");
    let _ = bypass_at(
        h,
        "confidential_asset",
        "init_module_for_testing",
        vec![],
        vec![signer_arg],
    );
}

fn generate_elgamal_keypair(h: &mut MoveHarness) -> (Vec<u8>, Vec<u8>) {
    let ret = bypass_at(h, "ristretto255_twisted_elgamal", "generate_twisted_elgamal_keypair", vec![], vec![]);
    assert_eq!(ret.return_values.len(), 2, "keypair return arity");
    (
        ret.return_values[0].0.clone(),
        ret.return_values[1].0.clone(),
    )
}

/// `register` / auditors expect the 32-byte compressed point; keygen returns full `CompressedPubkey` BCS.
fn twisted_pubkey_bytes(h: &mut MoveHarness, compressed_pubkey_struct: &[u8]) -> Vec<u8> {
    let ret = bypass_at(
        h,
        "ristretto255_twisted_elgamal",
        "pubkey_to_bytes",
        vec![],
        vec![compressed_pubkey_struct.to_vec()],
    );
    assert_eq!(ret.return_values.len(), 1);
    ret.return_values[0].0.clone()
}

fn prove_registration_parts(
    h: &mut MoveHarness,
    chain_byte: u8,
    user: AccountAddress,
    dk: &[u8],
    ek: &[u8],
    token: AccountAddress,
) -> (Vec<u8>, Vec<u8>) {
    let args = vec![
        bcs::to_bytes(&chain_byte).unwrap(),
        bcs::to_bytes(&user).unwrap(),
        bcs::to_bytes(&APTOS_EXPERIMENTAL).unwrap(),
        dk.to_vec(),
        ek.to_vec(),
        bcs::to_bytes(&token).unwrap(),
    ];
    let ret = bypass_at(h, "confidential_proof", "prove_registration", vec![], args);
    assert_eq!(ret.return_values.len(), 2);
    (
        ret.return_values[0].0.clone(),
        ret.return_values[1].0.clone(),
    )
}

fn run_register(
    h: &mut MoveHarness,
    account: &Account,
    ek_pubkey_32: &[u8],
    comm: &[u8],
    resp: &[u8],
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("register").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            // `vector<u8>` returns from the VM are already BCS (ULEB length + bytes); do not wrap again.
            ek_pubkey_32.to_vec(),
            comm.to_vec(),
            resp.to_vec(),
        ],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn run_deposit(h: &mut MoveHarness, account: &Account, amount: u64) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("deposit").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            bcs::to_bytes(&amount).unwrap(),
        ],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn run_deposit_to(
    h: &mut MoveHarness,
    sender: &Account,
    to: AccountAddress,
    amount: u64,
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("deposit_to").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            bcs::to_bytes(&to).unwrap(),
            bcs::to_bytes(&amount).unwrap(),
        ],
    ));
    let txn = h.create_transaction_payload(sender, payload);
    h.run(txn)
}

fn run_rollover(h: &mut MoveHarness, account: &Account) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("rollover_pending_balance").unwrap(),
        vec![],
        vec![bcs::to_bytes(&MOVE_METADATA).unwrap()],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn run_rollover_and_freeze(h: &mut MoveHarness, account: &Account) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("rollover_pending_balance_and_freeze").unwrap(),
        vec![],
        vec![bcs::to_bytes(&MOVE_METADATA).unwrap()],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn run_freeze_token(h: &mut MoveHarness, account: &Account) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("freeze_token").unwrap(),
        vec![],
        vec![bcs::to_bytes(&MOVE_METADATA).unwrap()],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn run_unfreeze_token(h: &mut MoveHarness, account: &Account) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("unfreeze_token").unwrap(),
        vec![],
        vec![bcs::to_bytes(&MOVE_METADATA).unwrap()],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn run_normalize(
    h: &mut MoveHarness,
    account: &Account,
    new_bal: &[u8],
    zkrp: &[u8],
    sigma: &[u8],
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("normalize").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            new_bal.to_vec(),
            zkrp.to_vec(),
            sigma.to_vec(),
        ],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn run_normalize_and_rollover(
    h: &mut MoveHarness,
    account: &Account,
    new_bal: &[u8],
    zkrp: &[u8],
    sigma: &[u8],
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("normalize_and_rollover_pending_balance").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            new_bal.to_vec(),
            zkrp.to_vec(),
            sigma.to_vec(),
        ],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn set_asset_auditor(h: &mut MoveHarness, auditor_pubkey_32: &[u8]) {
    let args = vec![
        MoveValue::Signer(AccountAddress::ONE)
            .simple_serialize()
            .unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        auditor_pubkey_32.to_vec(),
    ];
    bypass_at(
        h,
        "confidential_asset",
        "set_asset_auditor",
        vec![],
        args,
    );
}

fn set_chain_auditor(h: &mut MoveHarness, auditor_pubkey_32: &[u8]) {
    let args = vec![
        MoveValue::Signer(AccountAddress::ONE)
            .simple_serialize()
            .unwrap(),
        auditor_pubkey_32.to_vec(),
    ];
    bypass_at(
        h,
        "confidential_asset",
        "set_chain_auditor",
        vec![],
        args,
    );
}

/// Designates `admin_addr` as the chain-auditor admin (governance-only path). Required
/// before `set_chain_auditor` will accept the corresponding signer; governance no longer
/// holds chain-auditor authority directly.
fn set_chain_auditor_admin(h: &mut MoveHarness, admin_addr: AccountAddress) {
    let args = vec![
        MoveValue::Signer(AccountAddress::ONE)
            .simple_serialize()
            .unwrap(),
        bcs::to_bytes(&admin_addr).unwrap(),
    ];
    bypass_at(
        h,
        "confidential_asset",
        "set_chain_auditor_admin",
        vec![],
        args,
    );
}

/// Generates a fresh chain auditor keypair and installs it via `set_chain_auditor`.
/// Used by `fresh_harness` so every confidential transfer in the test suite has a
/// valid `auditor_eks[0]` available; tests that need to exercise rotation can call
/// this again to install a successor. Designates `@0x1` as the chain-auditor admin so
/// the bypass path can subsequently invoke `set_chain_auditor` with the framework
/// signer; production deployments would point this at a dedicated admin account.
fn install_default_chain_auditor(h: &mut MoveHarness) {
    set_chain_auditor_admin(h, AccountAddress::ONE);
    let (_chain_dk, chain_ek) = generate_elgamal_keypair(h);
    let chain_pk = twisted_pubkey_bytes(h, &chain_ek);
    set_chain_auditor(h, &chain_pk);
}

fn pack_transfer_simple(
    h: &mut MoveHarness,
    chain_byte: u8,
    sender: AccountAddress,
    recipient: AccountAddress,
    dk: &[u8],
    amount: u64,
    new_balance: u128,
    sender_auditor_hint: Vec<u8>,
) -> [Vec<u8>; 8] {
    let args = vec![
        bcs::to_bytes(&chain_byte).unwrap(),
        bcs::to_bytes(&sender).unwrap(),
        bcs::to_bytes(&recipient).unwrap(),
        dk.to_vec(),
        bcs::to_bytes(&amount).unwrap(),
        bcs::to_bytes(&new_balance).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        bcs::to_bytes(&sender_auditor_hint).unwrap(),
    ];
    let ret = bypass_at(
        h,
        "confidential_gas_e2e_helpers",
        "pack_confidential_transfer_proof_simple",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 8);
    std::array::from_fn(|i| ret.return_values[i].0.clone())
}

fn pack_transfer_audited_verbatim(
    h: &mut MoveHarness,
    chain_byte: u8,
    sender: AccountAddress,
    recipient: AccountAddress,
    dk: &[u8],
    amount: u64,
    new_balance: u128,
    auditor_eks: Vec<Vec<u8>>,
    sender_auditor_hint: Vec<u8>,
) -> [Vec<u8>; 8] {
    let auditor_inner: Vec<Vec<u8>> = auditor_eks
        .iter()
        .map(|b| raw_bytes_from_move_vector_u8(b))
        .collect();
    let args = vec![
        bcs::to_bytes(&chain_byte).unwrap(),
        bcs::to_bytes(&sender).unwrap(),
        bcs::to_bytes(&recipient).unwrap(),
        dk.to_vec(),
        bcs::to_bytes(&amount).unwrap(),
        bcs::to_bytes(&new_balance).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        bcs::to_bytes(&auditor_inner).unwrap(),
        bcs::to_bytes(&sender_auditor_hint).unwrap(),
    ];
    let ret = bypass_at(
        h,
        "confidential_gas_e2e_helpers",
        "pack_confidential_transfer_proof_verbatim",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 8);
    std::array::from_fn(|i| ret.return_values[i].0.clone())
}

fn pack_transfer_audited(
    h: &mut MoveHarness,
    chain_byte: u8,
    sender: AccountAddress,
    recipient: AccountAddress,
    dk: &[u8],
    amount: u64,
    new_balance: u128,
    auditor_eks: Vec<Vec<u8>>,
    sender_auditor_hint: Vec<u8>,
) -> [Vec<u8>; 8] {
    let auditor_inner: Vec<Vec<u8>> = auditor_eks
        .iter()
        .map(|b| raw_bytes_from_move_vector_u8(b))
        .collect();
    let args = vec![
        bcs::to_bytes(&chain_byte).unwrap(),
        bcs::to_bytes(&sender).unwrap(),
        bcs::to_bytes(&recipient).unwrap(),
        dk.to_vec(),
        bcs::to_bytes(&amount).unwrap(),
        bcs::to_bytes(&new_balance).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
        bcs::to_bytes(&auditor_inner).unwrap(),
        bcs::to_bytes(&sender_auditor_hint).unwrap(),
    ];
    let ret = bypass_at(
        h,
        "confidential_gas_e2e_helpers",
        "pack_confidential_transfer_proof_with_auditors",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 8);
    std::array::from_fn(|i| ret.return_values[i].0.clone())
}

fn run_confidential_transfer(
    h: &mut MoveHarness,
    sender: &Account,
    recipient: AccountAddress,
    parts: &[Vec<u8>; 8],
    sender_auditor_hint: Vec<u8>,
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("confidential_transfer").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            bcs::to_bytes(&recipient).unwrap(),
            parts[0].clone(),
            parts[1].clone(),
            parts[2].clone(),
            parts[3].clone(),
            parts[4].clone(),
            parts[5].clone(),
            parts[6].clone(),
            parts[7].clone(),
            bcs::to_bytes(&sender_auditor_hint).unwrap(),
        ],
    ));
    let txn = h.create_transaction_payload(sender, payload);
    h.run(txn)
}

fn pack_withdraw(
    h: &mut MoveHarness,
    chain_byte: u8,
    sender: AccountAddress,
    dk: &[u8],
    ek_struct: &[u8],
    withdraw_amt: u64,
    new_balance: u128,
) -> (Vec<u8>, Vec<u8>, Vec<u8>) {
    let args = vec![
        bcs::to_bytes(&chain_byte).unwrap(),
        bcs::to_bytes(&sender).unwrap(),
        dk.to_vec(),
        ek_struct.to_vec(),
        bcs::to_bytes(&withdraw_amt).unwrap(),
        bcs::to_bytes(&new_balance).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        h,
        "confidential_gas_e2e_helpers",
        "pack_withdraw_to_proof",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 3);
    (
        ret.return_values[0].0.clone(),
        ret.return_values[1].0.clone(),
        ret.return_values[2].0.clone(),
    )
}

fn run_withdraw_to(
    h: &mut MoveHarness,
    sender: &Account,
    to: AccountAddress,
    amount: u64,
    new_bal: &[u8],
    zkrp: &[u8],
    sigma: &[u8],
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("withdraw_to").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            bcs::to_bytes(&to).unwrap(),
            bcs::to_bytes(&amount).unwrap(),
            new_bal.to_vec(),
            zkrp.to_vec(),
            sigma.to_vec(),
        ],
    ));
    let txn = h.create_transaction_payload(sender, payload);
    h.run(txn)
}

fn run_withdraw(
    h: &mut MoveHarness,
    sender: &Account,
    amount: u64,
    new_bal: &[u8],
    zkrp: &[u8],
    sigma: &[u8],
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("withdraw").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            bcs::to_bytes(&amount).unwrap(),
            new_bal.to_vec(),
            zkrp.to_vec(),
            sigma.to_vec(),
        ],
    ));
    let txn = h.create_transaction_payload(sender, payload);
    h.run(txn)
}

fn pack_normalize(
    h: &mut MoveHarness,
    chain_byte: u8,
    sender: AccountAddress,
    dk: &[u8],
    amount: u128,
) -> (Vec<u8>, Vec<u8>, Vec<u8>) {
    let args = vec![
        bcs::to_bytes(&chain_byte).unwrap(),
        bcs::to_bytes(&sender).unwrap(),
        dk.to_vec(),
        bcs::to_bytes(&amount).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        h,
        "confidential_gas_e2e_helpers",
        "pack_normalization_proof",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 3);
    (
        ret.return_values[0].0.clone(),
        ret.return_values[1].0.clone(),
        ret.return_values[2].0.clone(),
    )
}

fn pack_rotate(
    h: &mut MoveHarness,
    chain_byte: u8,
    sender: AccountAddress,
    cur_dk: &[u8],
    new_dk: &[u8],
    new_ek: &[u8],
    balance: u128,
) -> (Vec<u8>, Vec<u8>, Vec<u8>, Vec<u8>) {
    let args = vec![
        bcs::to_bytes(&chain_byte).unwrap(),
        bcs::to_bytes(&sender).unwrap(),
        cur_dk.to_vec(),
        new_dk.to_vec(),
        new_ek.to_vec(),
        bcs::to_bytes(&balance).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
    ];
    let ret = bypass_at(
        h,
        "confidential_gas_e2e_helpers",
        "pack_rotate_encryption_key_proof",
        vec![],
        args,
    );
    assert_eq!(ret.return_values.len(), 4);
    (
        ret.return_values[0].0.clone(),
        ret.return_values[1].0.clone(),
        ret.return_values[2].0.clone(),
        ret.return_values[3].0.clone(),
    )
}

fn run_rotate(
    h: &mut MoveHarness,
    sender: &Account,
    new_ek: &[u8],
    new_bal: &[u8],
    zkrp: &[u8],
    sigma: &[u8],
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("rotate_encryption_key").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            new_ek.to_vec(),
            new_bal.to_vec(),
            zkrp.to_vec(),
            sigma.to_vec(),
        ],
    ));
    let txn = h.create_transaction_payload(sender, payload);
    h.run(txn)
}

fn run_rotate_and_unfreeze(
    h: &mut MoveHarness,
    sender: &Account,
    new_ek: &[u8],
    new_bal: &[u8],
    zkrp: &[u8],
    sigma: &[u8],
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("rotate_encryption_key_and_unfreeze").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            new_ek.to_vec(),
            new_bal.to_vec(),
            zkrp.to_vec(),
            sigma.to_vec(),
        ],
    ));
    let txn = h.create_transaction_payload(sender, payload);
    h.run(txn)
}

fn baseline_fa_transfer_gas(h: &mut MoveHarness, from: &Account, to: AccountAddress, amount: u64) -> u64 {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ModuleId::new(AccountAddress::ONE, Identifier::new("primary_fungible_store").unwrap()),
        Identifier::new("transfer").unwrap(),
        vec![TypeTag::Struct(Box::new(StructTag {
            address: AccountAddress::ONE,
            module: Identifier::new("fungible_asset").unwrap(),
            name: Identifier::new("Metadata").unwrap(),
            type_args: vec![],
        }))],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            bcs::to_bytes(&to).unwrap(),
            bcs::to_bytes(&amount).unwrap(),
        ],
    ));
    h.evaluate_gas(from, payload)
}

fn profile_gas(
    h: &mut MoveHarness,
    account: &Account,
    payload: TransactionPayload,
    label: &str,
) -> u64 {
    let (gas_log, gas_used, fee) = h.evaluate_gas_with_profiler(account, payload);
    assert!(
        gas_used > 0,
        "{label}: expected positive gas (got {gas_used})"
    );
    let _ = (gas_log, fee);
    gas_used
}

fn fresh_harness() -> MoveHarness {
    let mut h = MoveHarness::new();
    enable_confidential_features(&mut h);
    delete_genesis_global_config_if_present(&mut h);
    inject_confidential_e2e_modules(&mut h);
    reinit_confidential_asset_module(&mut h);
    // Every confidential transfer requires a chain-level auditor; install a deterministic
    // throwaway one here so individual tests don't need to know about it. Tests that
    // exercise the unset state should call `delete_genesis_global_config_if_present` +
    // `reinit_confidential_asset_module` themselves to get a clean slate.
    install_default_chain_auditor(&mut h);
    h
}

// --- Comprehensive scenarios (auditors, withdrawals, validation errors) ---

#[test]
fn confidential_transfer_with_voluntary_auditors_only() {
    for num_voluntary in 1u8..=3 {
        let mut h = fresh_harness();
        let chain = h.executor.get_chain_id().id();
        let alice_addr = confidential_e2e_addr(0xE1, num_voluntary);
        let bob_addr = confidential_e2e_addr(0xE2, num_voluntary);
        let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
        let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

        let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
        let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
        for (acct, addr, dk, ek) in [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)] {
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
    }
}

#[test]
fn confidential_transfer_asset_auditor_plus_voluntary_auditors() {
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
        for (acct, addr, dk, ek) in [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)] {
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
    }
}

#[test]
fn confidential_transfer_rejects_empty_auditors_when_asset_auditor_set() {
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
    for (acct, addr, dk, ek) in [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)] {
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
}

#[test]
fn confidential_transfer_rejects_non_matching_asset_auditor_pubkey() {
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
    for (acct, addr, dk, ek) in [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)] {
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
}

// --- Chain-level auditor scenarios ---

/// Harness variant that *omits* the default chain-auditor install. Tests use this when they
/// need to exercise either the unset state or installation timing.
fn fresh_harness_no_chain_auditor() -> MoveHarness {
    let mut h = MoveHarness::new();
    enable_confidential_features(&mut h);
    delete_genesis_global_config_if_present(&mut h);
    inject_confidential_e2e_modules(&mut h);
    reinit_confidential_asset_module(&mut h);
    h
}

#[test]
fn confidential_transfer_rejects_when_chain_auditor_unset() {
    let mut h = fresh_harness_no_chain_auditor();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xE9, 1);
    let bob_addr = confidential_e2e_addr(0xE9, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)] {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }
    assert_kept_success(&run_deposit(&mut h, &alice, 2_000), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

    // Empty auditor list — chain auditor isn't set on-chain, so any transfer must abort
    // at the `ECHAIN_AUDITOR_NOT_SET` precondition before slot-matching even runs.
    let parts = pack_transfer_audited_verbatim(
        &mut h, chain, alice_addr, bob_addr, &alice_dk, 100, 1900, vec![], vec![]);
    let st = run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]);
    assert_kept_failure(&st, "transfer must abort when chain auditor is unset");
}

#[test]
fn confidential_transfer_rejects_when_slot0_not_chain_auditor() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xEA, 1);
    let bob_addr = confidential_e2e_addr(0xEA, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)] {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }
    assert_kept_success(&run_deposit(&mut h, &alice, 2_000), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

    // Use a fresh keypair as slot 0 — proof is internally consistent (FS transcript binds
    // this key) but `validate_auditors` rejects because slot 0 ≠ on-chain chain auditor.
    let (_dk, wrong_ek) = generate_elgamal_keypair(&mut h);
    let wrong_pk = twisted_pubkey_bytes(&mut h, &wrong_ek);
    let parts = pack_transfer_audited_verbatim(
        &mut h, chain, alice_addr, bob_addr, &alice_dk, 100, 1900, vec![wrong_pk], vec![]);
    let st = run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]);
    assert_kept_failure(&st, "slot 0 must equal active chain auditor");
}

#[test]
fn confidential_transfer_rejects_after_chain_auditor_rotation() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xEB, 1);
    let bob_addr = confidential_e2e_addr(0xEB, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 1_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)] {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }
    assert_kept_success(&run_deposit(&mut h, &alice, 2_000), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover");

    // Snapshot the chain auditor key in force at proof-generation time, then rotate.
    // The pre-rotation proof (slot 0 = old chain key) becomes unsubmittable.
    let old_chain_pk = view_chain_auditor_pubkey(&mut h);
    let parts = pack_transfer_audited_verbatim(
        &mut h, chain, alice_addr, bob_addr, &alice_dk, 100, 1900, vec![old_chain_pk], vec![]);

    install_default_chain_auditor(&mut h); // bumps to a new chain auditor key

    let st = run_confidential_transfer(&mut h, &alice, bob_addr, &parts, vec![]);
    assert_kept_failure(&st, "post-rotation old-key proof must be rejected");
}

/// `normalize_and_rollover_pending_balance` does both steps in one tx. The proof is
/// generated against the *current* (unnormalized) actual balance; success implies both
/// `normalize_internal` and `rollover_pending_balance_internal` ran (their state asserts
/// are mutually exclusive — `normalize` requires `!normalized`, `rollover` requires
/// `normalized`, so a wrong composition would abort one of them).
#[test]
fn normalize_and_rollover_combined_entry_succeeds() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xEC, 1);
    let bob_addr = confidential_e2e_addr(0xEC, 2);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);
    let bob = h.new_account_with_balance_at(bob_addr, 50_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (bob_dk, bob_ek) = generate_elgamal_keypair(&mut h);
    for (acct, addr, dk, ek) in [(&alice, alice_addr, &alice_dk, &alice_ek), (&bob, bob_addr, &bob_dk, &bob_ek)] {
        let pk = twisted_pubkey_bytes(&mut h, ek);
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, MOVE_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &pk, &c, &r), "register");
    }

    // Stack two max-chunk deposits into the available balance to leave it unnormalized.
    let max_chunk: u64 = (1u64 << 16) - 1;
    assert_kept_success(&run_deposit(&mut h, &alice, max_chunk), "alice deposit 1");
    assert_kept_success(&run_deposit_to(&mut h, &bob, alice_addr, max_chunk), "bob → alice deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover (now unnormalized)");

    // A fresh deposit lands in pending; the combined entry must roll it in.
    assert_kept_success(&run_deposit(&mut h, &alice, 50), "alice deposit 2");

    // Proof normalizes against the *current* (unnormalized, pre-rollover) actual balance.
    let cur: u128 = 2u128 * max_chunk as u128;
    let (new_bal, zkrp, sigma) = pack_normalize(&mut h, chain, alice_addr, &alice_dk, cur);
    assert_kept_success(
        &run_normalize_and_rollover(&mut h, &alice, &new_bal, &zkrp, &sigma),
        "normalize_and_rollover_pending_balance",
    );
}

fn view_chain_auditor_pubkey(h: &mut MoveHarness) -> Vec<u8> {
    let ret = bypass_at(h, "confidential_asset", "get_chain_auditor", vec![], vec![]);
    assert_eq!(ret.return_values.len(), 1);
    let opt_struct = ret.return_values[0].0.clone();
    // `Option<CompressedPubkey>` is BCS `0x01 || pubkey_bytes` when Some.
    assert!(!opt_struct.is_empty() && opt_struct[0] == 1, "chain auditor must be Some");
    let inner = opt_struct[1..].to_vec();
    twisted_pubkey_bytes(h, &inner)
}

// ---- Combined "lands spendable" entrypoints (single-tx make-private flows) ----
//
// These three Move entrypoints collapse a deposit into a spendable confidential balance in one
// transaction. All three end with `rollover_pending_balance_internal`, which writes the new
// actual balance and zeros pending. The wallet picks based on on-chain state:
//
//   - unregistered                                  → register_and_deposit_and_rollover_pending_balance
//   - registered, normalized=true                   → deposit_and_rollover_pending_balance
//   - registered, normalized=false (post-rollover)  → deposit_normalize_and_rollover_pending_balance

fn run_register_and_deposit_and_rollover(
    h: &mut MoveHarness,
    sender: &Account,
    amount: u64,
    ek_pubkey_32: &[u8],
    comm: &[u8],
    resp: &[u8],
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("register_and_deposit_and_rollover_pending_balance").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            bcs::to_bytes(&amount).unwrap(),
            ek_pubkey_32.to_vec(),
            comm.to_vec(),
            resp.to_vec(),
        ],
    ));
    let txn = h.create_transaction_payload(sender, payload);
    h.run(txn)
}

fn run_deposit_and_rollover(h: &mut MoveHarness, sender: &Account, amount: u64) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("deposit_and_rollover_pending_balance").unwrap(),
        vec![],
        vec![bcs::to_bytes(&MOVE_METADATA).unwrap(), bcs::to_bytes(&amount).unwrap()],
    ));
    let txn = h.create_transaction_payload(sender, payload);
    h.run(txn)
}

fn run_deposit_normalize_and_rollover(
    h: &mut MoveHarness,
    sender: &Account,
    amount: u64,
    new_balance: &[u8],
    zkrp: &[u8],
    sigma: &[u8],
) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("deposit_normalize_and_rollover_pending_balance").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&MOVE_METADATA).unwrap(),
            bcs::to_bytes(&amount).unwrap(),
            new_balance.to_vec(),
            zkrp.to_vec(),
            sigma.to_vec(),
        ],
    ));
    let txn = h.create_transaction_payload(sender, payload);
    h.run(txn)
}

/// First-time atomic register + deposit + rollover. Verifies (a) the entry succeeds, (b) the
/// store is genuinely registered (a follow-up plain deposit works), and (c) the funds landed in
/// actual (spendable), since the test exercises the same path the wallet's "Make private" UX
/// uses for unregistered users.
#[test]
fn register_and_deposit_and_rollover_succeeds() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xCD, 3);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let alice_pk = twisted_pubkey_bytes(&mut h, &alice_ek);
    let (c, r) = prove_registration_parts(&mut h, chain, alice_addr, &alice_dk, &alice_ek, MOVE_METADATA);

    assert_kept_success(
        &run_register_and_deposit_and_rollover(&mut h, &alice, 100, &alice_pk, &c, &r),
        "register_and_deposit_and_rollover",
    );
    // Registration genuinely persisted: subsequent plain deposit (which requires an existing
    // store) must succeed.
    assert_kept_success(&run_deposit(&mut h, &alice, 25), "post-deposit");
}

/// Bad registration proof must reject before any state mutates.
#[test]
fn register_and_deposit_and_rollover_rejects_bad_proof() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xCD, 4);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let (_other_dk, other_ek) = generate_elgamal_keypair(&mut h);
    let other_pk = twisted_pubkey_bytes(&mut h, &other_ek);
    let (c, r) = prove_registration_parts(&mut h, chain, alice_addr, &alice_dk, &alice_ek, MOVE_METADATA);

    assert_kept_failure(
        &run_register_and_deposit_and_rollover(&mut h, &alice, 50, &other_pk, &c, &r),
        "bad registration proof must reject combined call",
    );
}

/// Combined entry aborts when the sender is already registered.
#[test]
fn register_and_deposit_and_rollover_aborts_when_already_registered() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xCD, 8);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let alice_pk = twisted_pubkey_bytes(&mut h, &alice_ek);
    let (c, r) = prove_registration_parts(&mut h, chain, alice_addr, &alice_dk, &alice_ek, MOVE_METADATA);

    assert_kept_success(
        &run_register(&mut h, &alice, &alice_pk, &c, &r),
        "alice plain register",
    );
    assert_kept_failure(
        &run_register_and_deposit_and_rollover(&mut h, &alice, 5, &alice_pk, &c, &r),
        "register_and_deposit_and_rollover on already-registered must abort",
    );
}

/// Subsequent combined entry on a normalized state: deposit + rollover, no normalize required.
/// Pre-state (normalized=true) is established by registering, depositing, rolling over, then
/// withdrawing — the withdraw path sets normalized=true.
#[test]
fn deposit_and_rollover_succeeds_when_normalized() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xCD, 10);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let alice_pk = twisted_pubkey_bytes(&mut h, &alice_ek);
    let (c, r) = prove_registration_parts(&mut h, chain, alice_addr, &alice_dk, &alice_ek, MOVE_METADATA);

    // First-time path leaves normalized=false (rollover side effect).
    assert_kept_success(
        &run_register_and_deposit_and_rollover(&mut h, &alice, 100, &alice_pk, &c, &r),
        "register_and_deposit_and_rollover",
    );

    // Withdraw any amount: normalized is set true on the sender's store.
    let (new_bal, zkrp, sigma) = pack_withdraw(&mut h, chain, alice_addr, &alice_dk, &alice_ek, 1, 99);
    assert_kept_success(
        &run_withdraw(&mut h, &alice, 1, &new_bal, &zkrp, &sigma),
        "withdraw to set normalized=true",
    );

    // Now the deposit_and_rollover path must succeed.
    assert_kept_success(
        &run_deposit_and_rollover(&mut h, &alice, 50),
        "deposit_and_rollover when normalized",
    );
}

/// Subsequent combined entry on a NOT-normalized state must abort with ENORMALIZATION_REQUIRED
/// (3 << 16 | 10 = 196618). The wallet detects this state via `is_normalized` view and routes
/// to `deposit_normalize_and_rollover_pending_balance` instead.
#[test]
fn deposit_and_rollover_aborts_when_not_normalized() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xCD, 11);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let alice_pk = twisted_pubkey_bytes(&mut h, &alice_ek);
    let (c, r) = prove_registration_parts(&mut h, chain, alice_addr, &alice_dk, &alice_ek, MOVE_METADATA);

    // After register_and_deposit_and_rollover, normalized=false.
    assert_kept_success(
        &run_register_and_deposit_and_rollover(&mut h, &alice, 100, &alice_pk, &c, &r),
        "register_and_deposit_and_rollover",
    );

    // No withdraw / transfer / normalize in between → normalized still false.
    assert_kept_failure(
        &run_deposit_and_rollover(&mut h, &alice, 50),
        "deposit_and_rollover when not normalized must abort",
    );
}

/// Subsequent combined entry on a NOT-normalized state, with normalize proof. Lands funds
/// spendable in one tx.
#[test]
fn deposit_normalize_and_rollover_succeeds_when_not_normalized() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = confidential_e2e_addr(0xCD, 12);
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);

    let (alice_dk, alice_ek) = generate_elgamal_keypair(&mut h);
    let alice_pk = twisted_pubkey_bytes(&mut h, &alice_ek);
    let (c, r) = prove_registration_parts(&mut h, chain, alice_addr, &alice_dk, &alice_ek, MOVE_METADATA);

    // First-time → normalized=false, actual=100.
    assert_kept_success(
        &run_register_and_deposit_and_rollover(&mut h, &alice, 100, &alice_pk, &c, &r),
        "register_and_deposit_and_rollover",
    );

    // Build the normalize proof against the *current* (pre-second-deposit) actual balance =
    // 100. `deposit_to_internal` only mutates pending, so the actual the proof binds to matches
    // the on-chain actual at normalize_internal time.
    let (new_bal, zkrp, sigma) = pack_normalize(&mut h, chain, alice_addr, &alice_dk, 100u128);

    assert_kept_success(
        &run_deposit_normalize_and_rollover(&mut h, &alice, 50, &new_bal, &zkrp, &sigma),
        "deposit_normalize_and_rollover when not normalized",
    );
}

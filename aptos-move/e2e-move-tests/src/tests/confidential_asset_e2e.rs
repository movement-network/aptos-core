// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0
//
// VM-level confidential-asset checks for this fork. Scenarios are written against the behavior
// documented in `aptos_experimental::confidential_asset` (e.g. `validate_auditors`, entry
// signatures)—not transcribed from other repositories' test code.
//
// The harness hot-swaps all `0x1` modules from a test-mode compile of `aptos-stdlib` (MoveStdlib +
// AptosStdlib, so `ristretto255::random_scalar` and friends resolve consistently), plus
// every `0x7` module from a matching `aptos-experimental` test compile. Genesis already publishes
// `FAController` for an older bytecode revision; we delete that resource and re-run
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

#[path = "confidential_asset_e2e_oracle_impl.rs"]
mod oracle;

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

fn compile_experimental_with_tests() -> Vec<(ModuleId, Vec<u8>)> {
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
    for unit in compiled.all_modules() {
        if let CompiledUnit::Module(NamedCompiledModule { module, .. }) = &unit.unit {
            let id = module.self_id();
            if id.address() != &APTOS_EXPERIMENTAL {
                continue;
            }
            let bytes = unit.unit.serialize(Some(module.version));
            out.push((id, bytes));
        }
    }
    out.sort_by(|a, b| a.0.name().as_str().cmp(b.0.name().as_str()));
    assert!(
        !out.is_empty(),
        "expected at least one aptos_experimental module from test build"
    );
    out
}

fn compile_confidential_e2e_inject_modules() -> Vec<(ModuleId, Vec<u8>)> {
    let mut v = compile_stdlib_inject_modules();
    v.extend(compile_experimental_with_tests());
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

/// Genesis `head` publishes `FAController` for bytecode that may differ from the injected module;
/// remove it so `init_module` can republish with a matching layout.
fn delete_genesis_fa_controller_if_present(h: &mut MoveHarness) {
    let tag = StructTag {
        address: APTOS_EXPERIMENTAL,
        module: Identifier::new("confidential_asset").unwrap(),
        name: Identifier::new("FAController").unwrap(),
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
        "set_auditor",
        vec![],
        args,
    );
}

fn pack_transfer_simple(
    h: &mut MoveHarness,
    chain_byte: u8,
    sender: AccountAddress,
    recipient: AccountAddress,
    dk: &[u8],
    amount: u64,
    new_balance: u128,
) -> [Vec<u8>; 8] {
    let args = vec![
        bcs::to_bytes(&chain_byte).unwrap(),
        bcs::to_bytes(&sender).unwrap(),
        bcs::to_bytes(&recipient).unwrap(),
        dk.to_vec(),
        bcs::to_bytes(&amount).unwrap(),
        bcs::to_bytes(&new_balance).unwrap(),
        bcs::to_bytes(&MOVE_METADATA).unwrap(),
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

fn pack_transfer_audited(
    h: &mut MoveHarness,
    chain_byte: u8,
    sender: AccountAddress,
    recipient: AccountAddress,
    dk: &[u8],
    amount: u64,
    new_balance: u128,
    auditor_eks: Vec<Vec<u8>>,
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
    delete_genesis_fa_controller_if_present(&mut h);
    inject_confidential_e2e_modules(&mut h);
    reinit_confidential_asset_module(&mut h);
    h
}

#[test]
fn confidential_asset_register_deposit_rollover_and_gas() {
    let _ = oracle::register_deposit_rollover_and_gas_cases();
}

#[test]
fn confidential_asset_rollover_and_freeze_only() {
    let _ = oracle::rollover_and_freeze_only_cases();
}

#[test]
fn confidential_asset_rotate_encryption_key_and_unfreeze_only() {
    let _ = oracle::rotate_encryption_key_and_unfreeze_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_matches_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_actual_balance_matches_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_zero_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_zero_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_is_frozen_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only() {
    let _ = oracle::is_frozen_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases();
}

#[test]
fn confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::encryption_key_view_matches_new_ek_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_actual_balance_rejects_stale_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_is_normalized_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::is_normalized_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_matches_second_deposit_after_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_matches_second_deposit_after_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_matches_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_actual_balance_matches_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_zero_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_rejects_zero_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_zero_after_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only(
) {
    let _ = oracle::verify_actual_balance_rejects_zero_after_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only_cases(
    );
}

#[test]
fn confidential_asset_balance_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only() {
    let _ = oracle::confidential_asset_balance_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_pending_balance_view_return_len_265_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::pending_balance_view_return_len_265_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_actual_balance_view_return_len_529_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::actual_balance_view_return_len_529_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_has_confidential_asset_store_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::has_confidential_asset_store_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_stale_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_rejects_stale_first_deposit_after_second_deposit_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_balance_matches_10003_after_post_unfreeze_deposit_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::confidential_asset_balance_matches_10003_after_post_unfreeze_deposit_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_is_token_allowed_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::is_token_allowed_true_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_get_auditor_returns_none_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::get_auditor_returns_none_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_matches_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_matches_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_is_allow_list_enabled_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::is_allow_list_enabled_false_after_deposit_rollover_freeze_and_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_wrong_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_rejects_wrong_sum_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_amount_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_actual_balance_rejects_wrong_amount_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_balance_matches_8901_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::confidential_asset_balance_matches_8901_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_sum_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_rejects_sum_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_actual_balance_rejects_amount_plus_one_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_encryption_key_view_matches_new_ek_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::encryption_key_view_matches_new_ek_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_is_frozen_false_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::is_frozen_false_after_two_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_balance_matches_6601_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::confidential_asset_balance_matches_6601_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_is_normalized_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::is_normalized_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_has_confidential_asset_store_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::has_confidential_asset_store_true_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_matches_sum_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_matches_sum_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::verify_pending_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only(
) {
    let _ = oracle::verify_actual_balance_rejects_zero_after_three_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_when_actual_nonzero_only_cases(
    );
}

#[test]
fn confidential_asset_balance_matches_7111_after_four_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only(
) {
    let _ = oracle::confidential_asset_balance_matches_7111_after_four_post_unfreeze_deposits_post_rotate_encryption_key_and_unfreeze_only_cases(
    );
}

#[test]
fn confidential_asset_rotate_encryption_key_aborts_when_pending_nonzero_after_deposit_rollover_and_second_deposit_only(
) {
    let _ = oracle::rotate_encryption_key_aborts_when_pending_nonzero_after_deposit_rollover_and_second_deposit_only_cases();
}

#[test]
fn confidential_asset_rotate_encryption_key_after_freeze_only() {
    let _ = oracle::rotate_encryption_key_after_freeze_only_cases();
}

#[test]
fn confidential_asset_freeze_then_unfreeze_only() {
    let _ = oracle::freeze_then_unfreeze_only_cases();
}

#[test]
fn confidential_asset_rollover_then_normalize_only() {
    let _ = oracle::rollover_then_normalize_only_cases();
}

#[test]
fn confidential_asset_is_normalized_false_after_rollover_only() {
    let _ = oracle::is_normalized_false_after_rollover_only_cases();
}

#[test]
fn confidential_asset_is_frozen_true_after_freeze_token_only() {
    let _ = oracle::is_frozen_true_after_freeze_token_only_cases();
}

#[test]
fn confidential_asset_has_confidential_asset_store_false_before_register_only() {
    let _ = oracle::has_confidential_asset_store_false_before_register_only_cases();
}

#[test]
fn confidential_asset_encryption_key_view_matches_registered_ek_only() {
    let _ = oracle::encryption_key_view_matches_registered_ek_only_cases();
}

#[test]
fn confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_and_rotate_only() {
    let _ = oracle::encryption_key_view_matches_new_ek_after_deposit_rollover_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_rotate_only() {
    let _ = oracle::verify_actual_balance_matches_after_deposit_rollover_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_rotate_only() {
    let _ = oracle::verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_rotate_only() {
    let _ = oracle::verify_pending_balance_zero_after_deposit_rollover_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_nonzero_with_stale_dk_after_deposit_rollover_and_rotate_only(
) {
    let _ = oracle::verify_pending_balance_rejects_nonzero_with_stale_dk_after_deposit_rollover_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_rotate_only() {
    let _ = oracle::verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only() {
    let _ = oracle::verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_rotate_only() {
    let _ = oracle::verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_zero_after_deposit_rollover_and_rotate_when_actual_nonzero_only(
) {
    let _ = oracle::verify_actual_balance_rejects_zero_after_deposit_rollover_and_rotate_when_actual_nonzero_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only() {
    let _ = oracle::verify_pending_balance_rejects_wrong_amount_after_deposit_rollover_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_rotate_only() {
    let _ = oracle::verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_matches_after_deposit_rollover_withdraw_and_rotate_only() {
    let _ = oracle::verify_actual_balance_matches_after_deposit_rollover_withdraw_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_withdraw_and_rotate_only() {
    let _ = oracle::verify_actual_balance_rejects_stale_dk_after_deposit_rollover_withdraw_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_matches_sum_after_two_deposits_rollover_and_rotate_only() {
    let _ = oracle::verify_actual_balance_matches_sum_after_two_deposits_rollover_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_stale_sum_after_two_deposits_rollover_and_rotate_only() {
    let _ = oracle::verify_pending_balance_rejects_stale_sum_after_two_deposits_rollover_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_zero_after_deposit_rollover_withdraw_and_rotate_only() {
    let _ = oracle::verify_pending_balance_zero_after_deposit_rollover_withdraw_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_withdraw_and_rotate_only(
) {
    let _ = oracle::verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_withdraw_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_matches_after_deposit_rollover_normalize_and_rotate_only() {
    let _ = oracle::verify_actual_balance_matches_after_deposit_rollover_normalize_and_rotate_only_cases();
}

#[test]
fn confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_normalize_and_rotate_only() {
    let _ = oracle::encryption_key_view_matches_new_ek_after_deposit_rollover_normalize_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_zero_after_deposit_rollover_normalize_and_rotate_only() {
    let _ = oracle::verify_pending_balance_zero_after_deposit_rollover_normalize_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_normalize_and_rotate_only() {
    let _ = oracle::verify_actual_balance_rejects_stale_dk_after_deposit_rollover_normalize_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_normalize_and_rotate_only(
) {
    let _ = oracle::verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_normalize_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_normalize_and_rotate_only(
) {
    let _ = oracle::verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_normalize_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_freeze_and_rotate_only() {
    let _ = oracle::verify_actual_balance_matches_after_deposit_rollover_and_freeze_and_rotate_only_cases();
}

#[test]
fn confidential_asset_encryption_key_view_matches_new_ek_after_deposit_rollover_and_freeze_and_rotate_only() {
    let _ = oracle::encryption_key_view_matches_new_ek_after_deposit_rollover_and_freeze_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_freeze_and_rotate_only() {
    let _ = oracle::verify_pending_balance_zero_after_deposit_rollover_and_freeze_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_freeze_and_rotate_only() {
    let _ = oracle::verify_actual_balance_rejects_stale_dk_after_deposit_rollover_and_freeze_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_freeze_and_rotate_only(
) {
    let _ = oracle::verify_pending_balance_rejects_nonzero_with_new_dk_after_deposit_rollover_and_freeze_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_is_frozen_true_after_deposit_rollover_and_freeze_and_rotate_only() {
    let _ = oracle::is_frozen_true_after_deposit_rollover_and_freeze_and_rotate_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_freeze_and_rotate_only(
) {
    let _ = oracle::verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_freeze_and_rotate_only_cases(
    );
}

#[test]
fn confidential_asset_has_confidential_asset_store_true_after_register_only() {
    let _ = oracle::has_confidential_asset_store_true_after_register_only_cases();
}

#[test]
fn confidential_asset_is_token_allowed_true_for_metadata_only() {
    let _ = oracle::is_token_allowed_true_for_metadata_only_cases();
}

#[test]
fn confidential_asset_is_allow_list_enabled_false_in_tests_only() {
    let _ = oracle::is_allow_list_enabled_false_in_tests_only_cases();
}

#[test]
fn confidential_asset_get_auditor_returns_none_for_move_metadata_no_fa_config_only() {
    let _ = oracle::get_auditor_returns_none_for_move_metadata_no_fa_config_only_cases();
}

#[test]
fn confidential_asset_is_normalized_true_after_register_only() {
    let _ = oracle::is_normalized_true_after_register_only_cases();
}

#[test]
fn confidential_asset_is_frozen_false_after_unfreeze_only() {
    let _ = oracle::is_frozen_false_after_unfreeze_only_cases();
}

#[test]
fn confidential_asset_is_frozen_false_after_register_only() {
    let _ = oracle::is_frozen_false_after_register_only_cases();
}

#[test]
fn confidential_asset_has_confidential_asset_store_false_for_peer_not_registered() {
    let _ = oracle::has_confidential_asset_store_false_for_peer_not_registered_cases();
}

#[test]
fn confidential_asset_is_frozen_true_after_rollover_and_freeze_only() {
    let _ = oracle::is_frozen_true_after_rollover_and_freeze_only_cases();
}

#[test]
fn confidential_asset_is_normalized_true_after_normalize_only() {
    let _ = oracle::is_normalized_true_after_normalize_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_normalize_only() {
    let _ = oracle::verify_actual_balance_matches_after_deposit_rollover_and_normalize_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_normalize_only() {
    let _ = oracle::verify_pending_balance_zero_after_deposit_rollover_and_normalize_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_normalize_only() {
    let _ = oracle::verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_normalize_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_normalize_only(
) {
    let _ = oracle::verify_actual_balance_rejects_amount_plus_one_after_deposit_rollover_and_normalize_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_zero_after_deposit_rollover_and_normalize_when_actual_nonzero(
) {
    let _ = oracle::verify_actual_balance_rejects_zero_after_deposit_rollover_and_normalize_when_actual_nonzero_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_nonzero_after_deposit_rollover_and_normalize_only() {
    let _ = oracle::verify_pending_balance_rejects_nonzero_after_deposit_rollover_and_normalize_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_normalize_only(
) {
    let _ = oracle::verify_pending_balance_rejects_stale_deposit_amount_after_deposit_rollover_and_normalize_only_cases();
}

#[test]
fn confidential_asset_balance_matches_single_deposit_only() {
    let _ = oracle::confidential_asset_balance_matches_single_deposit_only_cases();
}

#[test]
fn confidential_asset_balance_after_two_deposits_only() {
    let _ = oracle::confidential_asset_balance_after_two_deposits_only_cases();
}

#[test]
fn confidential_asset_balance_after_deposit_and_withdraw_only() {
    let _ = oracle::confidential_asset_balance_after_deposit_and_withdraw_only_cases();
}

#[test]
fn confidential_asset_balance_after_deposit_to_only() {
    let _ = oracle::confidential_asset_balance_after_deposit_to_only_cases();
}

#[test]
fn confidential_asset_balance_after_confidential_transfer_only() {
    let _ = oracle::confidential_asset_balance_after_confidential_transfer_only_cases();
}

#[test]
fn confidential_asset_balance_after_transfer_and_second_deposit_only() {
    let _ = oracle::confidential_asset_balance_after_transfer_and_second_deposit_only_cases();
}

#[test]
fn confidential_asset_balance_after_two_deposit_to_only() {
    let _ = oracle::confidential_asset_balance_after_two_deposit_to_only_cases();
}

#[test]
fn confidential_asset_deposit_to_cross_party_only() {
    let _ = oracle::deposit_to_cross_party_only_cases();
}

#[test]
fn confidential_asset_withdraw_entry_self_only() {
    let _ = oracle::withdraw_entry_self_only_cases();
}

#[test]
fn confidential_asset_transfer_withdraw_rotate_and_auditor() {
    let _ = oracle::transfer_withdraw_rotate_and_auditor_cases();
}

#[test]
fn confidential_asset_pending_balance_view_return_len_265_after_register_only() {
    let _ = oracle::pending_balance_view_return_len_265_after_register_only_cases();
}

#[test]
fn confidential_asset_actual_balance_view_return_len_529_after_register_only() {
    let _ = oracle::actual_balance_view_return_len_529_after_register_only_cases();
}

#[test]
fn confidential_asset_pending_balance_view_matches_deposit() {
    let _ = oracle::pending_balance_view_matches_deposit_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_zero_after_register_only() {
    let _ = oracle::verify_pending_balance_zero_after_register_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_nonzero_after_register_only() {
    let _ = oracle::verify_pending_balance_rejects_nonzero_after_register_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_zero_after_register_only() {
    let _ = oracle::verify_actual_balance_zero_after_register_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_nonzero_after_register_only() {
    let _ = oracle::verify_actual_balance_rejects_nonzero_after_register_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_matches_after_deposit_and_rollover_only() {
    let _ = oracle::verify_actual_balance_matches_after_deposit_and_rollover_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_matches_sum_after_two_deposits_and_rollover_only() {
    let _ = oracle::verify_actual_balance_matches_sum_after_two_deposits_and_rollover_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_matches_after_deposit_rollover_and_withdraw_only() {
    let _ = oracle::verify_actual_balance_matches_after_deposit_rollover_and_withdraw_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_withdraw_only() {
    let _ = oracle::verify_actual_balance_rejects_wrong_amount_after_deposit_rollover_and_withdraw_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_zero_after_deposit_rollover_and_withdraw_only() {
    let _ = oracle::verify_pending_balance_zero_after_deposit_rollover_and_withdraw_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_sum_after_two_deposits_and_rollover_only() {
    let _ = oracle::verify_actual_balance_rejects_wrong_sum_after_two_deposits_and_rollover_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_zero_after_deposit_and_rollover_only() {
    let _ = oracle::verify_pending_balance_zero_after_deposit_and_rollover_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_matches_after_deposit_only_no_rollover() {
    let _ = oracle::verify_pending_balance_matches_after_deposit_only_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_matches_sum_after_two_deposits_no_rollover() {
    let _ = oracle::verify_pending_balance_matches_sum_after_two_deposits_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_wrong_sum_after_two_deposits_no_rollover() {
    let _ = oracle::verify_pending_balance_rejects_wrong_sum_after_two_deposits_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_zero_after_two_deposits_no_rollover() {
    let _ = oracle::verify_pending_balance_rejects_zero_after_two_deposits_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_zero_after_deposit_only_no_rollover() {
    let _ = oracle::verify_pending_balance_rejects_zero_after_deposit_only_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_wrong_amount_after_deposit_only_no_rollover() {
    let _ = oracle::verify_pending_balance_rejects_wrong_amount_after_deposit_only_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_zero_after_deposit_only_no_rollover() {
    let _ = oracle::verify_actual_balance_zero_after_deposit_only_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_nonzero_after_deposit_only_no_rollover() {
    let _ = oracle::verify_actual_balance_rejects_nonzero_after_deposit_only_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_nonzero_sum_after_two_deposits_no_rollover() {
    let _ = oracle::verify_actual_balance_rejects_nonzero_sum_after_two_deposits_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_sum_after_two_deposits_no_rollover() {
    let _ = oracle::verify_actual_balance_rejects_wrong_sum_after_two_deposits_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_sum_plus_one_after_two_deposits_no_rollover() {
    let _ = oracle::verify_actual_balance_rejects_sum_plus_one_after_two_deposits_no_rollover_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_wrong_amount_after_deposit_and_rollover_only() {
    let _ = oracle::verify_actual_balance_rejects_wrong_amount_after_deposit_and_rollover_only_cases();
}

#[test]
fn confidential_asset_verify_actual_balance_rejects_zero_after_deposit_and_rollover_when_actual_nonzero(
) {
    let _ = oracle::verify_actual_balance_rejects_zero_after_deposit_and_rollover_when_actual_nonzero_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_nonzero_after_deposit_and_rollover_only() {
    let _ = oracle::verify_pending_balance_rejects_nonzero_after_deposit_and_rollover_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_stale_deposit_amount_after_deposit_and_rollover_only(
) {
    let _ = oracle::verify_pending_balance_rejects_stale_deposit_amount_after_deposit_and_rollover_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_stale_sum_after_two_deposits_and_rollover_only() {
    let _ = oracle::verify_pending_balance_rejects_stale_sum_after_two_deposits_and_rollover_only_cases();
}

#[test]
fn confidential_asset_verify_pending_balance_rejects_wrong_amount_after_two_deposits_and_rollover_only() {
    let _ = oracle::verify_pending_balance_rejects_wrong_amount_after_two_deposits_and_rollover_only_cases();
}

#[test]
fn confidential_asset_compare_plain_fa_transfer_gas() {
    let _ = oracle::compare_plain_fa_transfer_gas_cases();
}

// --- Comprehensive scenarios (auditors, withdrawals, validation errors) ---

#[test]
fn confidential_transfer_with_voluntary_auditors_only() {
    let _ = oracle::confidential_transfer_with_voluntary_auditors_only_cases();
}

#[test]
fn confidential_transfer_asset_auditor_plus_voluntary_auditors() {
    let _ = oracle::confidential_transfer_asset_auditor_plus_voluntary_auditors_cases();
}

#[test]
fn confidential_withdraw_without_asset_auditor() {
    let _ = oracle::confidential_withdraw_without_asset_auditor_cases();
}

#[test]
fn confidential_withdraw_after_asset_auditor_enabled() {
    let _ = oracle::confidential_withdraw_after_asset_auditor_enabled_cases();
}

#[test]
fn confidential_transfer_rejects_empty_auditors_when_asset_auditor_set() {
    let _ = oracle::confidential_transfer_rejects_empty_auditors_when_asset_auditor_set_cases();
}

#[test]
fn confidential_transfer_rejects_non_matching_asset_auditor_pubkey() {
    let _ = oracle::confidential_transfer_rejects_non_matching_asset_auditor_pubkey_cases();
}

#[test]
fn confidential_transfer_rejects_mismatched_sender_recipient_amount_ciphertexts() {
    let _ = oracle::confidential_transfer_rejects_mismatched_sender_recipient_amount_ciphertexts_cases();
}

#[test]
fn confidential_transfer_rejects_when_recipient_frozen() {
    let _ = oracle::confidential_transfer_rejects_when_recipient_frozen_cases();
}

#[test]
fn normalize_aborts_when_already_normalized_only() {
    let _ = oracle::normalize_aborts_when_already_normalized_only_cases();
}

#[test]
fn deposit_to_rejects_when_recipient_frozen() {
    let _ = oracle::deposit_to_rejects_when_recipient_frozen_cases();
}

#[test]
fn deposit_rejects_when_account_frozen_self_deposit_only() {
    let _ = oracle::deposit_rejects_when_account_frozen_self_deposit_only_cases();
}

#[test]
fn register_aborts_when_store_already_published_only() {
    let _ = oracle::register_aborts_when_store_already_published_only_cases();
}

#[test]
fn rollover_pending_balance_aborts_when_denormalized_only() {
    let _ = oracle::rollover_pending_balance_aborts_when_denormalized_only_cases();
}

#[test]
fn enable_token_aborts_when_already_enabled_only() {
    let _ = oracle::enable_token_aborts_when_already_enabled_only_cases();
}

#[test]
fn deposit_rejects_when_token_not_allowlisted_after_allow_list_enabled_only() {
    let _ = oracle::deposit_rejects_when_token_not_allowlisted_after_allow_list_enabled_only_cases();
}

#[test]
fn enable_allow_list_aborts_when_already_enabled_only() {
    let _ = oracle::enable_allow_list_aborts_when_already_enabled_only_cases();
}

#[test]
fn disable_allow_list_aborts_when_already_disabled_only() {
    let _ = oracle::disable_allow_list_aborts_when_already_disabled_only_cases();
}

#[test]
fn register_rejects_when_token_not_allowlisted_after_allow_list_enabled_first_only() {
    let _ = oracle::register_rejects_when_token_not_allowlisted_after_allow_list_enabled_first_only_cases();
}

#[test]
fn deposit_rejects_after_disable_token_with_allow_list_on_only() {
    let _ = oracle::deposit_rejects_after_disable_token_with_allow_list_on_only_cases();
}

#[test]
fn freeze_token_aborts_when_store_not_published_only() {
    let _ = oracle::freeze_token_aborts_when_store_not_published_only_cases();
}

#[test]
fn unfreeze_token_aborts_when_store_not_published_only() {
    let _ = oracle::unfreeze_token_aborts_when_store_not_published_only_cases();
}

#[test]
fn rollover_pending_balance_aborts_when_store_not_published_only() {
    let _ = oracle::rollover_pending_balance_aborts_when_store_not_published_only_cases();
}

#[test]
fn rollover_pending_balance_and_freeze_aborts_when_store_not_published_only() {
    let _ = oracle::rollover_pending_balance_and_freeze_aborts_when_store_not_published_only_cases();
}

#[test]
fn disable_token_aborts_when_already_disabled_only() {
    let _ = oracle::disable_token_aborts_when_already_disabled_only_cases();
}

#[test]
fn freeze_token_aborts_when_already_frozen_only() {
    let _ = oracle::freeze_token_aborts_when_already_frozen_only_cases();
}

#[test]
fn unfreeze_token_aborts_when_not_frozen_only() {
    let _ = oracle::unfreeze_token_aborts_when_not_frozen_only_cases();
}

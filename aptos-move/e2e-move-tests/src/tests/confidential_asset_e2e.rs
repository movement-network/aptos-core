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

const APTOS_EXPERIMENTAL: AccountAddress = AccountAddress::new({
    let mut b = [0u8; AccountAddress::LENGTH];
    b[31] = 0x07;
    b
});
/// Published fungible metadata object for gas/APT in test genesis.
const APT_METADATA: AccountAddress = AccountAddress::new({
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
            bcs::to_bytes(&APT_METADATA).unwrap(),
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
            bcs::to_bytes(&APT_METADATA).unwrap(),
            bcs::to_bytes(&amount).unwrap(),
        ],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn run_rollover(h: &mut MoveHarness, account: &Account) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("rollover_pending_balance").unwrap(),
        vec![],
        vec![bcs::to_bytes(&APT_METADATA).unwrap()],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn run_rollover_and_freeze(h: &mut MoveHarness, account: &Account) -> TransactionStatus {
    let payload = TransactionPayload::EntryFunction(EntryFunction::new(
        ca_module_id(),
        Identifier::new("rollover_pending_balance_and_freeze").unwrap(),
        vec![],
        vec![bcs::to_bytes(&APT_METADATA).unwrap()],
    ));
    let txn = h.create_transaction_payload(account, payload);
    h.run(txn)
}

fn set_asset_auditor(h: &mut MoveHarness, auditor_pubkey_32: &[u8]) {
    let args = vec![
        MoveValue::Signer(AccountAddress::ONE)
            .simple_serialize()
            .unwrap(),
        bcs::to_bytes(&APT_METADATA).unwrap(),
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
        bcs::to_bytes(&APT_METADATA).unwrap(),
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
        bcs::to_bytes(&APT_METADATA).unwrap(),
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
            bcs::to_bytes(&APT_METADATA).unwrap(),
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
        bcs::to_bytes(&APT_METADATA).unwrap(),
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
            bcs::to_bytes(&APT_METADATA).unwrap(),
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
        bcs::to_bytes(&APT_METADATA).unwrap(),
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
            bcs::to_bytes(&APT_METADATA).unwrap(),
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
            bcs::to_bytes(&APT_METADATA).unwrap(),
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
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let alice_addr = AccountAddress::from_hex_literal("0xa11e").unwrap();
    let alice = h.new_account_with_balance_at(alice_addr, 50_000_000_000_000);

    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (comm, resp) =
        prove_registration_parts(&mut h, chain, alice_addr, &dk, &ek_struct, APT_METADATA);
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
            bcs::to_bytes(&APT_METADATA).unwrap(),
            bcs::to_bytes(&1_000u64).unwrap(),
        ],
    ));
    let _ = profile_gas(&mut h, &alice, deposit_payload, "deposit (profile)");
}

#[test]
fn confidential_asset_transfer_withdraw_rotate_and_auditor() {
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
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek_struct, APT_METADATA);
        assert_kept_success(&run_register(&mut h, acct, &ek_pk, &c, &r), "register");
    }

    assert_kept_success(&run_deposit(&mut h, &alice, 10_000), "deposit");
    assert_kept_success(&run_rollover(&mut h, &alice), "rollover pre-transfer");

    let xfer_amt = 400u64;
    let mut remaining: u128 = 10_000 - xfer_amt as u128;
    let parts = pack_transfer_simple(
        &mut h,
        chain,
        alice_addr,
        bob_addr,
        &alice_dk,
        xfer_amt,
        remaining,
    );
    assert_kept_success(
        &run_confidential_transfer(&mut h, &alice, bob_addr, &parts),
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
    );
    assert_kept_success(
        &run_confidential_transfer(&mut h, &alice, bob_addr, &parts2),
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
    );
    assert_kept_success(
        &run_confidential_transfer(&mut h, &alice, bob_addr, &warm),
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
}

#[test]
fn confidential_asset_pending_balance_view_matches_deposit() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = AccountAddress::from_hex_literal("0xce11").unwrap();
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek_struct) = generate_elgamal_keypair(&mut h);
    let ek_pk = twisted_pubkey_bytes(&mut h, &ek_struct);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek_struct, APT_METADATA);
    assert_kept_success(&run_register(&mut h, &account, &ek_pk, &c, &r), "register");

    let deposit_amt: u64 = 777;
    assert_kept_success(&run_deposit(&mut h, &account, deposit_amt), "deposit");

    let args = vec![
        bcs::to_bytes(&u).unwrap(),
        bcs::to_bytes(&APT_METADATA).unwrap(),
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
}

#[test]
fn confidential_asset_compare_plain_fa_transfer_gas() {
    let mut h = fresh_harness();
    let a = AccountAddress::from_hex_literal("0xf1fa").unwrap();
    let b = AccountAddress::from_hex_literal("0xf2fa").unwrap();
    let alice = h.new_account_with_balance_at(a, 20_000_000_000_000);
    let _bob = h.new_account_with_balance_at(b, 1_000_000_000);
    let g = baseline_fa_transfer_gas(&mut h, &alice, b, 100);
    assert!(g > 0, "plain FA transfer should charge gas (got {g})");
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
            let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, APT_METADATA);
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
        );
        assert_kept_success(
            &run_confidential_transfer(&mut h, &alice, bob_addr, &parts),
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
        );
        assert_kept_success(
            &run_confidential_transfer(&mut h, &alice, bob_addr, &parts2),
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
            let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, APT_METADATA);
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
        );
        assert_kept_success(
            &run_confidential_transfer(&mut h, &alice, bob_addr, &parts),
            &format!("audited transfer asset auditor + {num_voluntary} voluntary"),
        );
    }
}

#[test]
fn confidential_withdraw_without_asset_auditor() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xE5, 1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);
    let (dk, ek) = generate_elgamal_keypair(&mut h);
    let pk = twisted_pubkey_bytes(&mut h, &ek);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek, APT_METADATA);
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
}

#[test]
fn confidential_withdraw_after_asset_auditor_enabled() {
    let mut h = fresh_harness();
    let chain = h.executor.get_chain_id().id();
    let u = confidential_e2e_addr(0xE6, 1);
    let account = h.new_account_with_balance_at(u, 40_000_000_000_000);

    let (_aud_dk, aud_ek) = generate_elgamal_keypair(&mut h);
    let aud_pk = twisted_pubkey_bytes(&mut h, &aud_ek);
    set_asset_auditor(&mut h, &aud_pk);

    let (dk, ek) = generate_elgamal_keypair(&mut h);
    let pk = twisted_pubkey_bytes(&mut h, &ek);
    let (c, r) = prove_registration_parts(&mut h, chain, u, &dk, &ek, APT_METADATA);
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
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, APT_METADATA);
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
    );
    let st = run_confidential_transfer(&mut h, &alice, bob_addr, &parts);
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
        let (c, r) = prove_registration_parts(&mut h, chain, addr, dk, ek, APT_METADATA);
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
    );
    let st = run_confidential_transfer(&mut h, &alice, bob_addr, &parts);
    assert_kept_failure(&st, "first auditor EK must match asset auditor");
}

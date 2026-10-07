// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Crash artifact replay tool.
//!
//! Deserializes fuzzer crash artifacts into RunnableState, prints module/function
//! info, verifies bytecode, and replays through FakeExecutor to confirm the crash.
//!
//! Usage:
//!     cargo run --bin crash_replay -- <crash_artifact_path> [--batch <dir>]

use aptos_language_e2e_tests::{account::Account, executor::FakeExecutor};
use aptos_transaction_simulation::GENESIS_CHANGE_SET_HEAD;
use aptos_types::{
    chain_id::ChainId,
    on_chain_config::Features,
    transaction::{
        EntryFunction, ExecutionStatus, Script, TransactionArgument, TransactionPayload,
        TransactionStatus,
    },
    write_set::WriteSet,
};
use aptos_vm::AptosVM;
use aptos_vm_environment::prod_configs;
use arbitrary::{Arbitrary, Unstructured};
use move_binary_format::{
    access::ModuleAccess,
    deserializer::DeserializerConfig,
    file_format::{CompiledModule, CompiledScript},
};
use move_core_types::vm_status::{StatusCode, StatusType};
use std::{
    collections::{BTreeMap, HashSet},
    env,
    fs,
    path::Path,
    process,
    sync::Arc,
};

mod utils;
use utils::vm::{
    check_for_invariant_violation, publish_group, sort_by_deps, ExecVariant,
    FuzzerRunnableAuthenticator, RunnableState,
};

// Re-use tdbg from utils/helpers.rs (imported via mod utils)

static VM_WRITE_SET: once_cell::sync::Lazy<WriteSet> =
    once_cell::sync::Lazy::new(|| GENESIS_CHANGE_SET_HEAD.write_set().clone());

static TP: once_cell::sync::Lazy<Arc<rayon::ThreadPool>> = once_cell::sync::Lazy::new(|| {
    Arc::new(
        rayon::ThreadPoolBuilder::new()
            .num_threads(1)
            .build()
            .unwrap(),
    )
});

fn print_runnable_state(state: &RunnableState) {
    println!("  Modules ({}):", state.dep_modules.len());
    for (i, m) in state.dep_modules.iter().enumerate() {
        println!(
            "    [{}] {}::{}  ({} functions, {} structs)",
            i,
            m.address(),
            m.name(),
            m.function_defs.len(),
            m.struct_defs.len(),
        );
        for (fi, fd) in m.function_defs.iter().enumerate() {
            let fh = &m.function_handles[fd.function.0 as usize];
            let name = &m.identifiers[fh.name.0 as usize];
            println!("      fn [{}]: {}", fi, name);
        }
    }

    match &state.exec_variant {
        ExecVariant::Script { script, type_args, args } => {
            println!("  Exec: Script (type_args={}, args={})", type_args.len(), args.len());
        },
        ExecVariant::CallFunction { module, function, type_args, args } => {
            println!(
                "  Exec: CallFunction {}::{} (fn_idx={}, type_args={}, args={})",
                module.address(),
                module.name(),
                function.0,
                type_args.len(),
                args.len(),
            );
        },
    }

    match &state.tx_auth_type {
        FuzzerRunnableAuthenticator::Ed25519 { .. } => println!("  Auth: Ed25519"),
        FuzzerRunnableAuthenticator::MultiAgent { secondary_signers, .. } => {
            println!("  Auth: MultiAgent ({} secondary)", secondary_signers.len())
        },
        FuzzerRunnableAuthenticator::FeePayer { secondary_signers, .. } => {
            println!("  Auth: FeePayer ({} secondary)", secondary_signers.len())
        },
    }
}

fn replay_crash(artifact_path: &str) -> Result<String, String> {
    // Read and deserialize
    let data = fs::read(artifact_path)
        .map_err(|e| format!("Failed to read {}: {}", artifact_path, e))?;

    let mut u = Unstructured::new(&data);
    let input = RunnableState::arbitrary_take_rest(u)
        .map_err(|e| format!("Failed to deserialize RunnableState: {}", e))?;

    print_runnable_state(&input);

    // Verify modules
    let verifier_config = prod_configs::aptos_prod_verifier_config(&Features::default());
    let deserializer_config = DeserializerConfig::new(8, 255);

    for (i, m) in input.dep_modules.iter().enumerate() {
        let mut module_code: Vec<u8> = vec![];
        m.serialize(&mut module_code)
            .map_err(|e| format!("Module {} serialize failed: {}", i, e))?;
        let m_de = CompiledModule::deserialize_with_config(&module_code, &deserializer_config)
            .map_err(|e| format!("Module {} deserialize failed: {}", i, e))?;
        match move_bytecode_verifier::verify_module_with_config(&verifier_config, &m_de) {
            Ok(()) => println!("  Verifier: module [{}] PASSED", i),
            Err(e) => {
                return Err(format!(
                    "Module [{}] REJECTED by verifier: {:?}",
                    i, e
                ));
            },
        }
    }

    if let ExecVariant::Script { script: s, .. } = &input.exec_variant {
        let mut script_code: Vec<u8> = vec![];
        s.serialize(&mut script_code)
            .map_err(|e| format!("Script serialize failed: {}", e))?;
        let s_de = CompiledScript::deserialize_with_config(&script_code, &deserializer_config)
            .map_err(|e| format!("Script deserialize failed: {}", e))?;
        match move_bytecode_verifier::verify_script_with_config(&verifier_config, &s_de) {
            Ok(()) => println!("  Verifier: script PASSED"),
            Err(e) => {
                return Err(format!("Script REJECTED by verifier: {:?}", e));
            },
        }
    }

    // Check no duplicates
    let mset: HashSet<_> = input.dep_modules.iter().map(|m| m.self_id()).collect();
    if mset.len() != input.dep_modules.len() {
        return Err("Duplicate module IDs".to_string());
    }

    // Topologically sort
    let all_modules = input.dep_modules.clone();
    let mut map = all_modules
        .into_iter()
        .map(|m| (m.self_id(), m))
        .collect::<BTreeMap<_, _>>();
    let mut order = vec![];
    for id in map.keys().cloned().collect::<Vec<_>>() {
        let mut visited = HashSet::new();
        sort_by_deps(&map, &mut order, id, &mut visited)
            .map_err(|_| "Cyclic dependency".to_string())?;
    }

    // Group into packages
    let mut packages = vec![];
    for cur_package_id in order.iter() {
        let mut cur = vec![];
        if !map.contains_key(cur_package_id) {
            continue;
        }
        for id in order.iter() {
            if id.address() == cur_package_id.address() {
                if let Some(module) = map.remove(cur_package_id) {
                    cur.push(module);
                }
            }
        }
        packages.push(cur)
    }

    // Execute
    AptosVM::set_concurrency_level_once(1);
    let mut vm = FakeExecutor::from_genesis_with_existing_thread_pool(
        &VM_WRITE_SET,
        ChainId::mainnet(),
        Arc::clone(&TP),
    )
    .set_not_parallel();

    // Publish
    for group in packages {
        let sender = *group[0].address();
        let acc = vm.new_account_at(sender);
        match publish_group(&mut vm, &acc, &group, 0) {
            Ok(()) => println!("  Publish: OK"),
            Err(_) => return Err("Publish failed (non-crash)".to_string()),
        }
    }

    // Build and execute transaction
    let sender_acc = vm
        .create_accounts(1, input.tx_auth_type.sender().fund_amount(), 0)
        .remove(0);

    let tx = match input.exec_variant.clone() {
        ExecVariant::Script { script, type_args, args } => {
            let mut script_bytes = vec![];
            script.serialize(&mut script_bytes).map_err(|e| format!("Script serialize: {}", e))?;
            sender_acc
                .transaction()
                .gas_unit_price(100)
                .max_gas_amount(1000)
                .sequence_number(0)
                .payload(TransactionPayload::Script(Script::new(
                    script_bytes,
                    type_args,
                    args.into_iter()
                        .map(|x| x.try_into())
                        .collect::<Result<Vec<TransactionArgument>, _>>()
                        .map_err(|_| "Arg conversion failed".to_string())?,
                )))
        },
        ExecVariant::CallFunction { module, function, type_args, args } => {
            let cm = input
                .dep_modules
                .iter()
                .find(|m| m.self_id() == module)
                .ok_or("Module not found for call".to_string())?;
            let fhi = cm.function_defs
                .get(function.0 as usize)
                .ok_or("Function def index out of range".to_string())?
                .function;
            let function_identifier_index = cm.function_handles
                .get(fhi.0 as usize)
                .ok_or("Function handle index out of range".to_string())?
                .name;
            let function_name = cm.identifiers
                .get(function_identifier_index.0 as usize)
                .ok_or("Function name index out of range".to_string())?
                .clone();
            sender_acc
                .transaction()
                .gas_unit_price(100)
                .max_gas_amount(1000)
                .sequence_number(0)
                .payload(TransactionPayload::EntryFunction(EntryFunction::new(
                    module,
                    function_name,
                    type_args,
                    args,
                )))
        },
    };

    let raw_tx = tx.raw();
    let tx = match input.tx_auth_type {
        FuzzerRunnableAuthenticator::Ed25519 { .. } => raw_tx
            .sign(&sender_acc.privkey, sender_acc.pubkey.as_ed25519().unwrap())
            .map_err(|_| "Signing failed".to_string())?
            .into_inner(),
        FuzzerRunnableAuthenticator::MultiAgent { ref secondary_signers, .. } => {
            if secondary_signers.len() > 10 {
                return Err("Too many secondary signers".to_string());
            }
            let secondary_accs: Vec<_> = secondary_signers
                .iter()
                .map(|acc| acc.convert_account(&mut vm))
                .collect();
            let secondary_signer_addrs = secondary_accs.iter().map(|acc| *acc.address()).collect();
            let secondary_private_keys = secondary_accs.iter().map(|acc| &acc.privkey).collect();
            raw_tx
                .sign_multi_agent(&sender_acc.privkey, secondary_signer_addrs, secondary_private_keys)
                .map_err(|_| "Multi-agent signing failed".to_string())?
                .into_inner()
        },
        FuzzerRunnableAuthenticator::FeePayer { ref secondary_signers, ref fee_payer, .. } => {
            if secondary_signers.len() > 10 {
                return Err("Too many secondary signers".to_string());
            }
            let secondary_accs: Vec<_> = secondary_signers
                .iter()
                .map(|acc| acc.convert_account(&mut vm))
                .collect();
            let secondary_signer_addrs = secondary_accs.iter().map(|acc| *acc.address()).collect();
            let secondary_private_keys = secondary_accs.iter().map(|acc| &acc.privkey).collect();
            let fee_payer_acc = fee_payer.convert_account(&mut vm);
            raw_tx
                .sign_fee_payer(
                    &sender_acc.privkey,
                    secondary_signer_addrs,
                    secondary_private_keys,
                    *fee_payer_acc.address(),
                    &fee_payer_acc.privkey,
                )
                .map_err(|_| "Fee payer signing failed".to_string())?
                .into_inner()
        },
    };

    println!("  Executing transaction...");

    // This is the critical part — if it crashes here, the bug is confirmed
    let res = vm.execute_block(vec![tx.clone()]);

    match res {
        Ok(mut outputs) => {
            let output = outputs.pop().expect("expected 1 output");
            match output.status() {
                TransactionStatus::Keep(status) => {
                    println!("  Result: Keep({:?})", status);
                    Ok(format!("Completed: {:?}", status))
                },
                TransactionStatus::Discard(e) => {
                    println!("  Result: Discard({:?})", e);
                    if e.status_type() == StatusType::InvariantViolation {
                        Ok(format!("INVARIANT VIOLATION (discard): {:?}", e))
                    } else {
                        Ok(format!("Discarded: {:?}", e))
                    }
                },
                other => {
                    println!("  Result: {:?}", other);
                    Ok(format!("Other: {:?}", other))
                },
            }
        },
        Err(e) => {
            println!("  Result: EXECUTION ERROR: {:?}", e);
            Ok(format!("Execution error: {:?}", e))
        },
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: {} <crash_artifact> [crash_artifact2 ...]", args[0]);
        eprintln!("       {} --batch <directory>", args[0]);
        process::exit(1);
    }

    if args[1] == "--batch" {
        if args.len() < 3 {
            eprintln!("Usage: {} --batch <directory>", args[0]);
            process::exit(1);
        }
        let dir = &args[2];
        let mut entries: Vec<_> = fs::read_dir(dir)
            .expect("Failed to read directory")
            .filter_map(|e| e.ok())
            .filter(|e| {
                e.file_name()
                    .to_str()
                    .map(|n| n.starts_with("crash-"))
                    .unwrap_or(false)
            })
            .collect();
        entries.sort_by_key(|e| e.file_name());

        let total = entries.len();
        let mut crashed = 0;
        let mut passed_verifier = 0;
        let mut rejected = 0;
        let mut deser_failed = 0;

        println!("=== Batch replay: {} crash artifacts ===\n", total);

        for (i, entry) in entries.iter().enumerate() {
            let path = entry.path();
            let name = entry.file_name();
            print!("[{}/{}] {} ... ", i + 1, total, name.to_string_lossy());

            match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                replay_crash(path.to_str().unwrap())
            })) {
                Ok(Ok(result)) => {
                    passed_verifier += 1;
                    println!("{}", result);
                },
                Ok(Err(e)) => {
                    if e.contains("REJECTED by verifier") {
                        rejected += 1;
                        println!("REJECTED: {}", e);
                    } else if e.contains("deserialize") || e.contains("Deserialize") {
                        deser_failed += 1;
                        println!("DESER FAIL: {}", e);
                    } else {
                        rejected += 1;
                        println!("SKIP: {}", e);
                    }
                },
                Err(_) => {
                    crashed += 1;
                    println!("CRASH DETECTED, possible bug");
                },
            }
        }

        println!("\n=== Summary ===");
        println!("Total:            {}", total);
        println!("Passed verifier:  {}", passed_verifier);
        println!("Crashed (possible bugs): {}", crashed);
        println!("Rejected by verifier: {}", rejected);
        println!("Deserialization failed: {}", deser_failed);
    } else {
        // Single or multiple files
        for artifact in &args[1..] {
            println!("=== Replaying: {} ===", artifact);
            match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                replay_crash(artifact)
            })) {
                Ok(Ok(result)) => println!("  Final: {}", result),
                Ok(Err(e)) => println!("  Error: {}", e),
                Err(_) => println!("  CRASH DETECTED, possible bug"),
            }
            println!();
        }
    }
}

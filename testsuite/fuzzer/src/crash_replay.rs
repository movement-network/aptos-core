// Crash artifact replay tool for aptosvm_publish_and_run fuzzer.
//
// Deserializes crash artifacts, verifies bytecode, and replays through
// FakeExecutor to confirm crashes and triage results.
//
// Usage:
//     crash_replay <artifact>              — replay single crash
//     crash_replay --batch <directory>     — triage all crash-* files

use aptos_cached_packages::aptos_stdlib::code_publish_package_txn;
use aptos_framework::natives::code::{
    ModuleMetadata, MoveOption, PackageDep, PackageMetadata, UpgradePolicy,
};
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
use arbitrary::Arbitrary;
use move_binary_format::{
    access::ModuleAccess,
    deserializer::DeserializerConfig,
    file_format::{CompiledModule, CompiledScript, FunctionDefinitionIndex},
};
use move_core_types::{
    language_storage::{ModuleId, TypeTag},
    value::MoveValue,
    vm_status::{StatusCode, StatusType},
};
use std::{
    collections::{BTreeMap, BTreeSet, HashSet},
    env, fs,
    sync::Arc,
};

// --- Types (mirrored from fuzz target utils) ---

#[derive(Debug, Arbitrary, Eq, PartialEq, Clone, Copy)]
enum FundAmount {
    Zero,
    Poor,
    Rich,
}

#[derive(Debug, Arbitrary, Eq, PartialEq, Clone, Copy)]
struct UserAccount {
    is_inited_and_funded: bool,
    fund: FundAmount,
}

impl UserAccount {
    fn fund_amount(&self) -> u64 {
        match self.fund {
            FundAmount::Zero => 0,
            FundAmount::Poor => 1_000,
            FundAmount::Rich => 1_000_000_000_000_000,
        }
    }

    fn convert_account(&self, vm: &mut FakeExecutor) -> Account {
        if self.is_inited_and_funded {
            vm.create_accounts(1, self.fund_amount(), 0).remove(0)
        } else {
            Account::new()
        }
    }
}

#[derive(Debug, Arbitrary, Eq, PartialEq, Clone)]
enum FuzzerRunnableAuthenticator {
    Ed25519 { sender: UserAccount },
    MultiAgent { sender: UserAccount, secondary_signers: Vec<UserAccount> },
    FeePayer { sender: UserAccount, secondary_signers: Vec<UserAccount>, fee_payer: UserAccount },
}

impl FuzzerRunnableAuthenticator {
    fn sender(&self) -> UserAccount {
        match self {
            Self::Ed25519 { sender } => *sender,
            Self::MultiAgent { sender, .. } => *sender,
            Self::FeePayer { sender, .. } => *sender,
        }
    }
}

#[derive(Debug, Arbitrary, Eq, PartialEq, Clone)]
enum ExecVariant {
    Script {
        script: CompiledScript,
        type_args: Vec<TypeTag>,
        args: Vec<MoveValue>,
    },
    CallFunction {
        module: ModuleId,
        function: FunctionDefinitionIndex,
        type_args: Vec<TypeTag>,
        args: Vec<Vec<u8>>,
    },
}

#[derive(Debug, Arbitrary, Eq, PartialEq, Clone)]
struct RunnableState {
    dep_modules: Vec<CompiledModule>,
    exec_variant: ExecVariant,
    tx_auth_type: FuzzerRunnableAuthenticator,
}

// --- Helpers ---

static VM_WRITE_SET: once_cell::sync::Lazy<WriteSet> =
    once_cell::sync::Lazy::new(|| GENESIS_CHANGE_SET_HEAD.write_set().clone());

static TP: once_cell::sync::Lazy<Arc<rayon::ThreadPool>> = once_cell::sync::Lazy::new(|| {
    Arc::new(rayon::ThreadPoolBuilder::new().num_threads(1).build().unwrap())
});

fn sort_by_deps(
    map: &BTreeMap<ModuleId, CompiledModule>,
    order: &mut Vec<ModuleId>,
    id: ModuleId,
    visited: &mut HashSet<ModuleId>,
) -> Result<(), String> {
    if visited.contains(&id) {
        return Err("cycle".into());
    }
    visited.insert(id.clone());
    if order.contains(&id) {
        return Ok(());
    }
    if let Some(compiled) = map.get(&id) {
        for dep in compiled.immediate_dependencies() {
            if map.contains_key(&dep) {
                sort_by_deps(map, order, dep, visited)?;
            }
        }
    }
    order.push(id);
    Ok(())
}

fn publish_transaction_payload(modules: &[CompiledModule]) -> TransactionPayload {
    let modules_metadatas: Vec<_> = modules
        .iter()
        .map(|cm| ModuleMetadata {
            name: cm.name().to_string(),
            source: vec![],
            source_map: vec![],
            extension: MoveOption::default(),
        })
        .collect();

    let all_immediate_deps: Vec<_> = modules
        .iter()
        .flat_map(|cm| cm.immediate_dependencies())
        .map(|mi| PackageDep {
            account: mi.address,
            package_name: mi.name.to_string(),
        })
        .collect::<BTreeSet<_>>()
        .into_iter()
        .filter(|c| &c.account != modules[0].address())
        .collect();

    let metadata = PackageMetadata {
        name: "fuzz_package".to_string(),
        upgrade_policy: UpgradePolicy::compat(),
        upgrade_number: 1,
        source_digest: "".to_string(),
        manifest: vec![],
        modules: modules_metadatas,
        deps: all_immediate_deps,
        extension: MoveOption::default(),
    };
    let pkg_metadata = bcs::to_bytes(&metadata).expect("PackageMetadata must serialize");
    let mut pkg_code: Vec<Vec<u8>> = vec![];
    for module in modules {
        let mut module_code: Vec<u8> = vec![];
        module.serialize(&mut module_code).expect("Module must serialize");
        pkg_code.push(module_code);
    }
    code_publish_package_txn(pkg_metadata, pkg_code)
}

fn publish_group(
    vm: &mut FakeExecutor,
    acc: &Account,
    group: &[CompiledModule],
    seq: u64,
) -> Result<(), String> {
    let tx = acc
        .transaction()
        .gas_unit_price(100)
        .sequence_number(seq)
        .payload(publish_transaction_payload(group))
        .sign();

    let res = vm
        .execute_block(vec![tx])
        .map_err(|e| format!("publish block error: {:?}", e))?
        .pop()
        .expect("expected 1 output");

    match res.status() {
        TransactionStatus::Keep(ExecutionStatus::Success) => {
            vm.apply_write_set(res.write_set());
            Ok(())
        },
        TransactionStatus::Keep(status) => Err(format!("publish kept but: {:?}", status)),
        TransactionStatus::Discard(e) => Err(format!("publish discarded: {:?}", e)),
        other => Err(format!("publish other: {:?}", other)),
    }
}

// --- Main replay logic ---

fn replay_crash(artifact_path: &str) -> Result<String, String> {
    let data = fs::read(artifact_path)
        .map_err(|e| format!("read error: {}", e))?;

    let u = arbitrary::Unstructured::new(&data);
    let input = RunnableState::arbitrary_take_rest(u)
        .map_err(|e| format!("deserialize RunnableState: {}", e))?;

    // Print info
    println!("  Modules: {}", input.dep_modules.len());
    for (i, m) in input.dep_modules.iter().enumerate() {
        println!("    [{}] {}::{} ({} fns)", i, m.address(), m.name(), m.function_defs.len());
    }
    match &input.exec_variant {
        ExecVariant::Script { type_args, args, .. } => {
            println!("  Exec: Script (type_args={}, args={})", type_args.len(), args.len());
        },
        ExecVariant::CallFunction { module, function, type_args, args } => {
            println!("  Exec: Call {}::{} fn_idx={}", module.address(), module.name(), function.0);
        },
    }

    // Verify
    let verifier_config = prod_configs::aptos_prod_verifier_config(&Features::default());
    let deserializer_config = DeserializerConfig::new(8, 255);

    for (i, m) in input.dep_modules.iter().enumerate() {
        let mut code: Vec<u8> = vec![];
        m.serialize(&mut code).map_err(|e| format!("module {} serialize: {}", i, e))?;
        let m_de = CompiledModule::deserialize_with_config(&code, &deserializer_config)
            .map_err(|e| format!("module {} deser: {}", i, e))?;
        move_bytecode_verifier::verify_module_with_config(&verifier_config, &m_de)
            .map_err(|e| format!("REJECTED by verifier [{}]: {:?}", i, e))?;
        println!("  Verifier [{}]: PASSED", i);
    }

    // Topo sort + group
    let all_modules = input.dep_modules.clone();
    let mut map: BTreeMap<_, _> = all_modules.into_iter().map(|m| (m.self_id(), m)).collect();

    let mset: HashSet<_> = input.dep_modules.iter().map(|m| m.self_id()).collect();
    if mset.len() != input.dep_modules.len() {
        return Err("duplicate modules".into());
    }

    let mut order = vec![];
    for id in map.keys().cloned().collect::<Vec<_>>() {
        let mut visited = HashSet::new();
        sort_by_deps(&map, &mut order, id, &mut visited)?;
    }

    let mut packages = vec![];
    for cur_id in order.iter() {
        if !map.contains_key(cur_id) {
            continue;
        }
        let mut cur = vec![];
        for id in order.iter() {
            if id.address() == cur_id.address() {
                if let Some(module) = map.remove(id) {
                    cur.push(module);
                }
            }
        }
        if !cur.is_empty() {
            packages.push(cur);
        }
    }

    // Execute
    AptosVM::set_concurrency_level_once(1);
    let mut vm = FakeExecutor::from_genesis_with_existing_thread_pool(
        &VM_WRITE_SET,
        ChainId::mainnet(),
        Arc::clone(&TP),
    )
    .set_not_parallel();

    for group in packages {
        let sender = *group[0].address();
        let acc = vm.new_account_at(sender);
        publish_group(&mut vm, &acc, &group, 0)?;
        println!("  Published OK");
    }

    let sender_acc = vm
        .create_accounts(1, input.tx_auth_type.sender().fund_amount(), 0)
        .remove(0);

    let tx = match input.exec_variant.clone() {
        ExecVariant::Script { script, type_args, args } => {
            let mut script_bytes = vec![];
            script.serialize(&mut script_bytes).map_err(|e| format!("{}", e))?;
            sender_acc.transaction()
                .gas_unit_price(100).max_gas_amount(1000).sequence_number(0)
                .payload(TransactionPayload::Script(Script::new(
                    script_bytes, type_args,
                    args.into_iter().map(|x| x.try_into())
                        .collect::<Result<Vec<TransactionArgument>, _>>()
                        .map_err(|_| "arg conversion".to_string())?,
                )))
        },
        ExecVariant::CallFunction { module, function, type_args, args } => {
            let cm = input.dep_modules.iter().find(|m| m.self_id() == module)
                .ok_or("module not found")?;
            let fhi = cm.function_defs.get(function.0 as usize)
                .ok_or("fn def oob")?.function;
            let fname_idx = cm.function_handles.get(fhi.0 as usize)
                .ok_or("fn handle oob")?.name;
            let fname = cm.identifiers.get(fname_idx.0 as usize)
                .ok_or("fn name oob")?.clone();
            sender_acc.transaction()
                .gas_unit_price(100).max_gas_amount(1000).sequence_number(0)
                .payload(TransactionPayload::EntryFunction(EntryFunction::new(
                    module, fname, type_args, args,
                )))
        },
    };

    let raw_tx = tx.raw();
    let signed_tx = match &input.tx_auth_type {
        FuzzerRunnableAuthenticator::Ed25519 { .. } => raw_tx
            .sign(&sender_acc.privkey, sender_acc.pubkey.as_ed25519().unwrap())
            .map_err(|_| "sign failed")?.into_inner(),
        FuzzerRunnableAuthenticator::MultiAgent { secondary_signers, .. } => {
            if secondary_signers.len() > 10 { return Err("too many signers".into()); }
            let accs: Vec<_> = secondary_signers.iter().map(|a| a.convert_account(&mut vm)).collect();
            let addrs = accs.iter().map(|a| *a.address()).collect();
            let keys = accs.iter().map(|a| &a.privkey).collect();
            raw_tx.sign_multi_agent(&sender_acc.privkey, addrs, keys)
                .map_err(|_| "multi sign failed")?.into_inner()
        },
        FuzzerRunnableAuthenticator::FeePayer { secondary_signers, fee_payer, .. } => {
            if secondary_signers.len() > 10 { return Err("too many signers".into()); }
            let accs: Vec<_> = secondary_signers.iter().map(|a| a.convert_account(&mut vm)).collect();
            let addrs = accs.iter().map(|a| *a.address()).collect();
            let keys = accs.iter().map(|a| &a.privkey).collect();
            let fp = fee_payer.convert_account(&mut vm);
            raw_tx.sign_fee_payer(&sender_acc.privkey, addrs, keys, *fp.address(), &fp.privkey)
                .map_err(|_| "fee payer sign failed")?.into_inner()
        },
    };

    println!("  Executing...");
    let res = vm.execute_block(vec![signed_tx]);

    match res {
        Ok(mut outputs) => {
            let output = outputs.pop().expect("1 output");
            match output.status() {
                TransactionStatus::Keep(status) => Ok(format!("Keep({:?})", status)),
                TransactionStatus::Discard(e) => {
                    if e.status_type() == StatusType::InvariantViolation {
                        Ok(format!("INVARIANT_VIOLATION(discard): {:?}", e))
                    } else {
                        Ok(format!("Discard({:?})", e))
                    }
                },
                other => Ok(format!("{:?}", other)),
            }
        },
        Err(e) => Ok(format!("BlockError: {:?}", e)),
    }
}

fn export_artifact(artifact_path: &str, out_dir: &str) -> Result<(), String> {
    let data = fs::read(artifact_path).map_err(|e| format!("read: {}", e))?;
    let u = arbitrary::Unstructured::new(&data);
    let input = RunnableState::arbitrary_take_rest(u)
        .map_err(|e| format!("deser: {}", e))?;

    fs::create_dir_all(out_dir).map_err(|e| format!("mkdir: {}", e))?;

    // Export each module as raw bytecode
    for (i, m) in input.dep_modules.iter().enumerate() {
        let mut code: Vec<u8> = vec![];
        m.serialize(&mut code).map_err(|e| format!("serialize: {}", e))?;
        let module_path = format!("{}/module_{}.mv", out_dir, i);
        fs::write(&module_path, &code).map_err(|e| format!("write: {}", e))?;
        println!("  Exported module [{}] {}::{} -> {} ({} bytes)",
            i, m.address(), m.name(), module_path, code.len());
    }

    // Export metadata JSON
    let meta = serde_json::json!({
        "artifact": artifact_path,
        "modules": input.dep_modules.iter().enumerate().map(|(i, m)| {
            serde_json::json!({
                "index": i,
                "address": format!("{}", m.address()),
                "name": format!("{}", m.name()),
                "functions": m.function_defs.len(),
                "structs": m.struct_defs.len(),
            })
        }).collect::<Vec<_>>(),
        "exec": match &input.exec_variant {
            ExecVariant::Script { .. } => serde_json::json!({"type": "script"}),
            ExecVariant::CallFunction { module, function, type_args, args } => {
                let cm = input.dep_modules.iter().find(|m| m.self_id() == *module);
                let fn_name = cm.and_then(|cm| {
                    cm.function_defs.get(function.0 as usize).and_then(|fd| {
                        cm.function_handles.get(fd.function.0 as usize).and_then(|fh| {
                            cm.identifiers.get(fh.name.0 as usize).map(|id| id.to_string())
                        })
                    })
                }).unwrap_or_else(|| format!("fn_idx_{}", function.0));
                serde_json::json!({
                    "type": "call_function",
                    "module_addr": format!("{}", module.address()),
                    "module_name": format!("{}", module.name()),
                    "function": fn_name,
                    "function_idx": function.0,
                    "type_args": type_args.len(),
                    "args": args.len(),
                })
            },
        },
    });
    let meta_path = format!("{}/metadata.json", out_dir);
    fs::write(&meta_path, serde_json::to_string_pretty(&meta).unwrap())
        .map_err(|e| format!("write meta: {}", e))?;
    println!("  Metadata -> {}", meta_path);
    Ok(())
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: {} <crash_artifact>", args[0]);
        eprintln!("       {} --batch <directory>", args[0]);
        eprintln!("       {} --export <artifact> <output_dir>", args[0]);
        std::process::exit(1);
    }

    if args[1] == "--export" {
        let artifact = args.get(2).expect("need artifact path");
        let out_dir = args.get(3).expect("need output directory");
        match export_artifact(artifact, out_dir) {
            Ok(()) => println!("Export complete."),
            Err(e) => { eprintln!("Export failed: {}", e); std::process::exit(1); },
        }
        return;
    }

    if args[1] == "--batch" {
        let dir = args.get(2).expect("need directory");
        let mut entries: Vec<_> = fs::read_dir(dir).expect("read dir")
            .filter_map(|e| e.ok())
            .filter(|e| e.file_name().to_str().map(|n| n.starts_with("crash-")).unwrap_or(false))
            .collect();
        entries.sort_by_key(|e| e.file_name());

        let total = entries.len();
        let (mut crashed, mut passed, mut rejected, mut other_err) = (0, 0, 0, 0);

        println!("=== Batch: {} artifacts ===\n", total);

        for (i, entry) in entries.iter().enumerate() {
            let path = entry.path();
            let name = entry.file_name();
            print!("[{}/{}] {} ... ", i + 1, total, name.to_string_lossy());

            match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                replay_crash(path.to_str().unwrap())
            })) {
                Ok(Ok(result)) => { passed += 1; println!("{}", result); },
                Ok(Err(e)) if e.contains("REJECTED") => { rejected += 1; println!("REJECTED"); },
                Ok(Err(e)) => { other_err += 1; println!("ERR: {}", e); },
                Err(_) => { crashed += 1; println!("CRASHED"); },
            }
        }

        println!("\n=== Results ===");
        println!("Total:       {}", total);
        println!("Executed:    {}", passed);
        println!("CRASHED:     {} <-- confirmed bugs", crashed);
        println!("Rejected:    {}", rejected);
        println!("Other error: {}", other_err);
    } else {
        for path in &args[1..] {
            println!("=== {} ===", path);
            match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| replay_crash(path))) {
                Ok(Ok(result)) => println!("  Result: {}", result),
                Ok(Err(e)) => println!("  Error: {}", e),
                Err(_) => println!("  CRASHED — bug confirmed"),
            }
            println!();
        }
    }
}

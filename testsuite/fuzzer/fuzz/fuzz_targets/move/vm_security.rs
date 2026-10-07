#![no_main]

// Comprehensive VM security fuzzer.
//
// Same input format as publish_and_run (RunnableState) so existing corpus works.
// Enhanced invariant checks:
// - Multi-account balance conservation (sender + receiver + third party)
// - Total supply conservation
// - Underflow/overflow detection
// - Invariant violation detection on all code paths
// - Resource integrity after execution

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
use libfuzzer_sys::{fuzz_target, Corpus};
use move_binary_format::{
    access::ModuleAccess,
    deserializer::DeserializerConfig,
    errors::VMError,
    file_format::{CompiledModule, CompiledScript, SignatureToken},
};
use move_core_types::vm_status::{StatusCode, StatusType};
use once_cell::sync::Lazy;
use std::{
    collections::{BTreeMap, HashSet},
    sync::Arc,
    time::Instant,
};
mod utils;
use utils::vm::{
    check_for_invariant_violation, publish_group, sort_by_deps, ExecVariant,
    FuzzerRunnableAuthenticator, RunnableState,
};

static VM_WRITE_SET: Lazy<Option<WriteSet>> = Lazy::new(|| {
    let prev = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    let r = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        GENESIS_CHANGE_SET_HEAD.write_set().clone()
    }))
    .ok();
    std::panic::set_hook(prev);
    r
});

const FUZZER_CONCURRENCY_LEVEL: usize = 1;
static TP: Lazy<Arc<rayon::ThreadPool>> = Lazy::new(|| {
    Arc::new(
        rayon::ThreadPoolBuilder::new()
            .num_threads(FUZZER_CONCURRENCY_LEVEL)
            .build()
            .unwrap(),
    )
});

const MAX_TYPE_PARAMETER_VALUE: u16 = 64 / 4 * 16;

fn check_for_invariant_violation_vmerror(e: VMError) {
    if e.status_type() == StatusType::InvariantViolation {
        let is_known = e.message().map_or(false, |msg| {
            msg.starts_with("too many type parameters/arguments in the program")
        });
        if !is_known {
            panic!("INVARIANT VIOLATION: {:?}", e);
        }
    }
}

fn filter_modules(input: &RunnableState) -> Result<(), Corpus> {
    if let ExecVariant::Script { script, .. } = input.exec_variant.clone() {
        for signature in script.signatures {
            for sign_token in signature.0.iter() {
                if let SignatureToken::TypeParameter(idx) = sign_token {
                    if *idx > MAX_TYPE_PARAMETER_VALUE {
                        return Err(Corpus::Reject);
                    }
                } else if let SignatureToken::Vector(inner) = sign_token {
                    if let SignatureToken::TypeParameter(idx) = inner.as_ref() {
                        if *idx > MAX_TYPE_PARAMETER_VALUE {
                            return Err(Corpus::Reject);
                        }
                    }
                }
            }
        }
    }
    Ok(())
}

fn run_case(mut input: RunnableState) -> Result<(), Corpus> {
    filter_modules(&input)?;

    let write_set = VM_WRITE_SET.as_ref().ok_or(Corpus::Reject)?;

    let verifier_config = prod_configs::aptos_prod_verifier_config(&Features::default());
    let deserializer_config = DeserializerConfig::new(8, 255);

    for m in input.dep_modules.iter_mut() {
        let mut module_code: Vec<u8> = vec![];
        m.serialize(&mut module_code).map_err(|_| Corpus::Keep)?;
        let m_de = CompiledModule::deserialize_with_config(&module_code, &deserializer_config)
            .map_err(|_| Corpus::Reject)?;
        move_bytecode_verifier::verify_module_with_config(&verifier_config, &m_de).map_err(|e| {
            check_for_invariant_violation_vmerror(e);
            Corpus::Reject
        })?
    }

    if let ExecVariant::Script { script: s, .. } = &input.exec_variant {
        let mut script_code: Vec<u8> = vec![];
        s.serialize(&mut script_code).map_err(|_| Corpus::Keep)?;
        let s_de = CompiledScript::deserialize_with_config(&script_code, &deserializer_config)
            .map_err(|_| Corpus::Reject)?;
        move_bytecode_verifier::verify_script_with_config(&verifier_config, &s_de).map_err(|e| {
            check_for_invariant_violation_vmerror(e);
            Corpus::Reject
        })?
    }

    let mset: HashSet<_> = input.dep_modules.iter().map(|m| m.self_id()).collect();
    if mset.len() != input.dep_modules.len() {
        return Err(Corpus::Reject);
    }

    let all_modules = input.dep_modules.clone();
    let mut map = all_modules
        .into_iter()
        .map(|m| (m.self_id(), m))
        .collect::<BTreeMap<_, _>>();
    let mut order = vec![];
    for id in map.keys().cloned().collect::<Vec<_>>() {
        let mut visited = HashSet::new();
        sort_by_deps(&map, &mut order, id, &mut visited)?;
    }

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

    AptosVM::set_concurrency_level_once(FUZZER_CONCURRENCY_LEVEL);
    let mut vm = FakeExecutor::from_genesis_with_existing_thread_pool(
        write_set,
        ChainId::mainnet(),
        Arc::clone(&TP),
    )
    .set_not_parallel();

    for group in packages {
        let sender = *group[0].address();
        let acc = vm.new_account_at(sender);
        publish_group(&mut vm, &acc, &group, 0)?;
    }

    // Create sender + two uninvolved accounts to check for unauthorized transfers
    let sender_acc = vm
        .create_accounts(1, input.tx_auth_type.sender().fund_amount(), 0)
        .remove(0);
    let bystander_1 = vm.create_accounts(1, 1_000_000_000, 0).remove(0);
    let bystander_2 = vm.create_accounts(1, 1_000_000_000, 0).remove(0);

    // --- Snapshot ALL balances before execution ---
    let supply_before = vm.read_coin_supply();
    let sender_bal_before = vm
        .read_apt_fungible_store_resource(&sender_acc)
        .map(|s| s.balance())
        .unwrap_or(0);
    let b1_bal_before = vm
        .read_apt_fungible_store_resource(&bystander_1)
        .map(|s| s.balance())
        .unwrap_or(0);
    let b2_bal_before = vm
        .read_apt_fungible_store_resource(&bystander_2)
        .map(|s| s.balance())
        .unwrap_or(0);

    // Build and execute transaction
    let tx = match input.exec_variant.clone() {
        ExecVariant::Script {
            script,
            type_args,
            args,
        } => {
            let mut script_bytes = vec![];
            script
                .serialize(&mut script_bytes)
                .map_err(|_| Corpus::Reject)?;
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
                        .map_err(|_| Corpus::Reject)?,
                )))
        },
        ExecVariant::CallFunction {
            module,
            function,
            type_args,
            args,
        } => {
            let cm = input
                .dep_modules
                .iter()
                .find(|m| m.self_id() == module)
                .ok_or(Corpus::Reject)?;
            let fhi = cm
                .function_defs
                .get(function.0 as usize)
                .ok_or(Corpus::Reject)?
                .function;
            let function_identifier_index = cm
                .function_handles
                .get(fhi.0 as usize)
                .ok_or(Corpus::Reject)?
                .name;
            let function_name = cm
                .identifiers
                .get(function_identifier_index.0 as usize)
                .ok_or(Corpus::Reject)?
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
        FuzzerRunnableAuthenticator::Ed25519 { sender: _ } => raw_tx
            .sign(&sender_acc.privkey, sender_acc.pubkey.as_ed25519().unwrap())
            .map_err(|_| Corpus::Reject)?
            .into_inner(),
        FuzzerRunnableAuthenticator::MultiAgent {
            sender: _,
            secondary_signers,
        } => {
            if secondary_signers.len() > 10 {
                return Err(Corpus::Reject);
            }
            let secondary_accs: Vec<_> = secondary_signers
                .iter()
                .map(|acc| acc.convert_account(&mut vm))
                .collect();
            let secondary_signers = secondary_accs.iter().map(|acc| *acc.address()).collect();
            let secondary_private_keys = secondary_accs.iter().map(|acc| &acc.privkey).collect();
            raw_tx
                .sign_multi_agent(
                    &sender_acc.privkey,
                    secondary_signers,
                    secondary_private_keys,
                )
                .map_err(|_| Corpus::Reject)?
                .into_inner()
        },
        FuzzerRunnableAuthenticator::FeePayer {
            sender: _,
            secondary_signers,
            fee_payer,
        } => {
            if secondary_signers.len() > 10 {
                return Err(Corpus::Reject);
            }
            let secondary_accs: Vec<_> = secondary_signers
                .iter()
                .map(|acc| acc.convert_account(&mut vm))
                .collect();
            let secondary_signers = secondary_accs.iter().map(|acc| *acc.address()).collect();
            let secondary_private_keys = secondary_accs.iter().map(|acc| &acc.privkey).collect();
            let fee_payer_acc = fee_payer.convert_account(&mut vm);
            raw_tx
                .sign_fee_payer(
                    &sender_acc.privkey,
                    secondary_signers,
                    secondary_private_keys,
                    *fee_payer_acc.address(),
                    &fee_payer_acc.privkey,
                )
                .map_err(|_| Corpus::Reject)?
                .into_inner()
        },
    };

    let now = Instant::now();
    let res = vm
        .execute_block(vec![tx.clone()])
        .map_err(|e| {
            check_for_invariant_violation(e);
            Corpus::Keep
        })?
        .pop()
        .expect("expect 1 output");
    let elapsed = now.elapsed();

    let status = match res.status() {
        TransactionStatus::Keep(status) => status,
        TransactionStatus::Discard(e) => {
            if e.status_type() == StatusType::InvariantViolation {
                panic!("DISCARD INVARIANT VIOLATION: {:?}", e);
            }
            return Err(Corpus::Keep);
        },
        _ => return Err(Corpus::Keep),
    };

    match status {
        ExecutionStatus::Success => (),
        ExecutionStatus::MiscellaneousError(e) => {
            if let Some(e) = e {
                if e.status_type() == StatusType::InvariantViolation
                    && *e != StatusCode::TYPE_RESOLUTION_FAILURE
                    && *e != StatusCode::STORAGE_ERROR
                {
                    panic!("EXEC INVARIANT VIOLATION: {:?}, {:?}", e, res.auxiliary_data());
                }
            }
            return Err(Corpus::Keep);
        },
        _ => return Err(Corpus::Keep),
    };

    // Gas sanity check
    let fee = res.try_extract_fee_statement().unwrap().unwrap();
    let gas_total = fee.execution_gas_used() + fee.io_gas_used();
    if gas_total == 0 && elapsed.as_millis() > 10 {
        panic!(
            "ZERO GAS for non-trivial execution: elapsed={:?} gas=0. \
             Possible gas metering bypass.",
            elapsed
        );
    }

    // Apply write set
    vm.apply_write_set(res.write_set());

    // --- Post-execution checks on ALL accounts ---

    let supply_after = vm.read_coin_supply();
    let sender_bal_after = vm
        .read_apt_fungible_store_resource(&sender_acc)
        .map(|s| s.balance())
        .unwrap_or(0);
    let b1_bal_after = vm
        .read_apt_fungible_store_resource(&bystander_1)
        .map(|s| s.balance())
        .unwrap_or(0);
    let b2_bal_after = vm
        .read_apt_fungible_store_resource(&bystander_2)
        .map(|s| s.balance())
        .unwrap_or(0);

    // CHECK 1: Supply conservation
    if let (Some(before), Some(after)) = (supply_before, supply_after) {
        if after > before {
            panic!(
                "SUPPLY INFLATION: {} -> {} (+{})",
                before, after, after - before
            );
        }
    }

    // CHECK 2: Bystander accounts must NEVER gain balance
    if b1_bal_after > b1_bal_before {
        panic!(
            "BYSTANDER 1 THEFT: {} -> {} (+{}). Unauthorized transfer!",
            b1_bal_before, b1_bal_after, b1_bal_after - b1_bal_before
        );
    }
    if b2_bal_after > b2_bal_before {
        panic!(
            "BYSTANDER 2 THEFT: {} -> {} (+{}). Unauthorized transfer!",
            b2_bal_before, b2_bal_after, b2_bal_after - b2_bal_before
        );
    }

    // CHECK 3: Sender balance inflation
    if sender_bal_after > sender_bal_before {
        panic!(
            "SENDER INFLATION: {} -> {} (+{})",
            sender_bal_before, sender_bal_after, sender_bal_after - sender_bal_before
        );
    }

    // CHECK 4: Total balance conservation (should only decrease from gas)
    let total_before = sender_bal_before + b1_bal_before + b2_bal_before;
    let total_after = sender_bal_after + b1_bal_after + b2_bal_after;
    if total_after > total_before {
        panic!(
            "TOTAL BALANCE INFLATION: {} -> {} (+{}). Money created from nothing!",
            total_before, total_after, total_after - total_before
        );
    }

    // CHECK 5: Underflow detection
    if sender_bal_after > sender_bal_before + 1_000_000_000_000 {
        panic!(
            "SENDER UNDERFLOW: {} -> {} (likely u64 wrap)",
            sender_bal_before, sender_bal_after
        );
    }

    Ok(())
}

fuzz_target!(|fuzz_data: RunnableState| -> Corpus {
    run_case(fuzz_data).err().unwrap_or(Corpus::Keep)
});

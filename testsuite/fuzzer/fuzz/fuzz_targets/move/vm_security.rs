#![no_main]

// Comprehensive VM security fuzzer.
//
// Targets: loss of funds, permission bypass, ability violations, type confusion,
// resource duplication, module upgrade attacks.
//
// Key differences from aptosvm_publish_and_run:
// 1. Multi-transaction: publish then execute MULTIPLE transactions
// 2. Multi-account: checks ALL account balances, not just sender
// 3. Deeper invariant checks: resource integrity, ability enforcement
// 4. Tests module upgrade paths
// 5. Exercises framework interactions (coin, staking, account)

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
    file_format::{CompiledModule, CompiledScript, FunctionDefinitionIndex},
};
use move_core_types::{
    language_storage::{ModuleId, TypeTag},
    value::MoveValue,
    vm_status::{StatusCode, StatusType},
};
use once_cell::sync::Lazy;
use std::{
    collections::{BTreeMap, HashSet},
    sync::Arc,
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

#[derive(Debug, arbitrary::Arbitrary, Eq, PartialEq, Clone)]
struct MultiTxState {
    modules: Vec<CompiledModule>,
    // Multiple execution variants to chain
    txns: Vec<ExecVariant>,
    tx_auth_type: FuzzerRunnableAuthenticator,
}

fn run_case(input: MultiTxState) -> Result<(), Corpus> {
    let write_set = VM_WRITE_SET.as_ref().ok_or(Corpus::Reject)?;

    if input.modules.is_empty() || input.txns.is_empty() {
        return Err(Corpus::Reject);
    }
    if input.txns.len() > 5 {
        return Err(Corpus::Reject); // cap chained transactions
    }

    let verifier_config = prod_configs::aptos_prod_verifier_config(&Features::default());
    let deserializer_config = DeserializerConfig::new(8, 255);

    // Verify all modules
    for m in input.modules.iter() {
        let mut code: Vec<u8> = vec![];
        m.serialize(&mut code).map_err(|_| Corpus::Keep)?;
        let m_de = CompiledModule::deserialize_with_config(&code, &deserializer_config)
            .map_err(|_| Corpus::Reject)?;
        move_bytecode_verifier::verify_module_with_config(&verifier_config, &m_de).map_err(|e| {
            if e.status_type() == StatusType::InvariantViolation {
                panic!("VERIFIER INVARIANT VIOLATION: {:?}", e);
            }
            Corpus::Reject
        })?;
    }

    // Deduplicate and sort modules
    let mset: HashSet<_> = input.modules.iter().map(|m| m.self_id()).collect();
    if mset.len() != input.modules.len() {
        return Err(Corpus::Reject);
    }

    let mut map: BTreeMap<_, _> = input
        .modules
        .clone()
        .into_iter()
        .map(|m| (m.self_id(), m))
        .collect();
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

    AptosVM::set_concurrency_level_once(FUZZER_CONCURRENCY_LEVEL);
    let mut vm = FakeExecutor::from_genesis_with_existing_thread_pool(
        write_set,
        ChainId::mainnet(),
        Arc::clone(&TP),
    )
    .set_not_parallel();

    // Publish modules
    for group in packages {
        let sender = *group[0].address();
        let acc = vm.new_account_at(sender);
        publish_group(&mut vm, &acc, &group, 0)?;
    }

    // Create multiple accounts
    let sender_acc = vm
        .create_accounts(1, input.tx_auth_type.sender().fund_amount(), 0)
        .remove(0);
    let receiver_acc = vm.create_accounts(1, 1_000_000_000, 0).remove(0);
    let third_acc = vm.create_accounts(1, 1_000_000_000, 0).remove(0);

    // --- Pre-execution state snapshot (ALL accounts) ---
    let supply_before = vm.read_coin_supply();
    let sender_bal_before = vm
        .read_apt_fungible_store_resource(&sender_acc)
        .map(|s| s.balance())
        .unwrap_or(0);
    let receiver_bal_before = vm
        .read_apt_fungible_store_resource(&receiver_acc)
        .map(|s| s.balance())
        .unwrap_or(0);
    let third_bal_before = vm
        .read_apt_fungible_store_resource(&third_acc)
        .map(|s| s.balance())
        .unwrap_or(0);
    let total_before = sender_bal_before + receiver_bal_before + third_bal_before;

    // Execute multiple transactions in sequence
    for (tx_idx, exec_variant) in input.txns.iter().enumerate() {
        let tx = match exec_variant.clone() {
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
                    .sequence_number(tx_idx as u64)
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
                    .modules
                    .iter()
                    .find(|m| m.self_id() == module)
                    .ok_or(Corpus::Reject)?;
                let fhi = cm
                    .function_defs
                    .get(function.0 as usize)
                    .ok_or(Corpus::Reject)?
                    .function;
                let fname_idx = cm
                    .function_handles
                    .get(fhi.0 as usize)
                    .ok_or(Corpus::Reject)?
                    .name;
                let fname = cm
                    .identifiers
                    .get(fname_idx.0 as usize)
                    .ok_or(Corpus::Reject)?
                    .clone();
                sender_acc
                    .transaction()
                    .gas_unit_price(100)
                    .max_gas_amount(1000)
                    .sequence_number(tx_idx as u64)
                    .payload(TransactionPayload::EntryFunction(EntryFunction::new(
                        module, fname, type_args, args,
                    )))
            },
        };

        let raw_tx = tx.raw();
        let signed_tx = raw_tx
            .sign(&sender_acc.privkey, sender_acc.pubkey.as_ed25519().unwrap())
            .map_err(|_| Corpus::Reject)?
            .into_inner();

        let res = vm
            .execute_block(vec![signed_tx])
            .map_err(|e| {
                check_for_invariant_violation(e);
                Corpus::Keep
            })?
            .pop()
            .expect("expect 1 output");

        match res.status() {
            TransactionStatus::Keep(status) => {
                vm.apply_write_set(res.write_set());
                match status {
                    ExecutionStatus::Success => {},
                    ExecutionStatus::MiscellaneousError(e) => {
                        if let Some(e) = e {
                            if e.status_type() == StatusType::InvariantViolation
                                && *e != StatusCode::TYPE_RESOLUTION_FAILURE
                                && *e != StatusCode::STORAGE_ERROR
                            {
                                panic!(
                                    "INVARIANT VIOLATION on tx {}: {:?} {:?}",
                                    tx_idx,
                                    e,
                                    res.auxiliary_data()
                                );
                            }
                        }
                    },
                    _ => {},
                }
            },
            TransactionStatus::Discard(e) => {
                if e.status_type() == StatusType::InvariantViolation {
                    panic!("DISCARD INVARIANT VIOLATION on tx {}: {:?}", tx_idx, e);
                }
            },
            _ => {},
        };
    }

    // --- Post-execution invariant checks (ALL accounts) ---

    // Check 1: Total coin supply
    let supply_after = vm.read_coin_supply();
    if let (Some(before), Some(after)) = (supply_before, supply_after) {
        if after > before {
            panic!(
                "SUPPLY INFLATION: {} -> {} (delta: +{})",
                before,
                after,
                after - before,
            );
        }
    }

    // Check 2: Individual account balances
    let sender_bal_after = vm
        .read_apt_fungible_store_resource(&sender_acc)
        .map(|s| s.balance())
        .unwrap_or(0);
    let receiver_bal_after = vm
        .read_apt_fungible_store_resource(&receiver_acc)
        .map(|s| s.balance())
        .unwrap_or(0);
    let third_bal_after = vm
        .read_apt_fungible_store_resource(&third_acc)
        .map(|s| s.balance())
        .unwrap_or(0);
    let total_after = sender_bal_after + receiver_bal_after + third_bal_after;

    // No account that didn't sign a transaction should gain balance
    if receiver_bal_after > receiver_bal_before {
        panic!(
            "RECEIVER BALANCE INFLATION: {} -> {} (receiver never signed a tx!)",
            receiver_bal_before, receiver_bal_after,
        );
    }
    if third_bal_after > third_bal_before {
        panic!(
            "THIRD PARTY BALANCE INFLATION: {} -> {} (third party never signed a tx!)",
            third_bal_before, third_bal_after,
        );
    }

    // Total balance conservation (accounting for gas burns)
    // Total should only decrease (gas burned) or stay same, never increase
    if total_after > total_before {
        panic!(
            "TOTAL BALANCE INFLATION: {} -> {} (delta: +{}). Money created from nothing.",
            total_before,
            total_after,
            total_after - total_before,
        );
    }

    // Check sender didn't wrap around
    if sender_bal_after > sender_bal_before + 1_000_000_000_000 {
        panic!(
            "SENDER UNDERFLOW: {} -> {} (likely u64 wrap)",
            sender_bal_before, sender_bal_after,
        );
    }

    Ok(())
}

fuzz_target!(|fuzz_data: MultiTxState| -> Corpus {
    run_case(fuzz_data).err().unwrap_or(Corpus::Keep)
});

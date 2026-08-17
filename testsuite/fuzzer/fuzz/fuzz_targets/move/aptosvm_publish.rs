#![no_main]

// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

mod utils;
use aptos_language_e2e_tests::executor::FakeExecutor;
use aptos_transaction_simulation::GENESIS_CHANGE_SET_HEAD;
use aptos_types::{chain_id::ChainId, on_chain_config::Features, write_set::WriteSet};
use aptos_vm::AptosVM;
use aptos_vm_environment::prod_configs;
use libfuzzer_sys::{fuzz_target, Corpus};
use move_binary_format::{
    access::ModuleAccess,
    deserializer::DeserializerConfig,
    file_format::{CompiledModule, CompiledScript},
};
use once_cell::sync::Lazy;
use std::{
    collections::{BTreeMap, HashSet},
    sync::Arc,
};
use utils::vm::{publish_group, sort_by_deps, ExecVariant, RunnableState};

// genesis write set generated once for each fuzzing session
static VM: Lazy<Option<WriteSet>> = Lazy::new(|| {
    let prev = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    let r = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        GENESIS_CHANGE_SET_HEAD.write_set().clone()
    }))
    .ok();
    std::panic::set_hook(prev);
    r
});

const TEST_UPGRADE: bool = true;
const FUZZER_CONCURRENCY_LEVEL: usize = 1;
static TP: Lazy<Arc<rayon::ThreadPool>> = Lazy::new(|| {
    Arc::new(
        rayon::ThreadPoolBuilder::new()
            .num_threads(FUZZER_CONCURRENCY_LEVEL)
            .build()
            .unwrap(),
    )
});

fn run_case(mut input: RunnableState) -> Result<(), Corpus> {
    tdbg!(&input);

    let verifier_config = prod_configs::aptos_prod_verifier_config(&Features::default());
    let deserializer_config = DeserializerConfig::new(8, 255);

    for m in input.dep_modules.iter_mut() {
        // m.metadata = vec![]; // we could optimize metadata to only contain aptos metadata
        // m.version = VERSION_MAX;

        // reject bad modules fast
        let mut module_code: Vec<u8> = vec![];
        m.serialize(&mut module_code).map_err(|_| Corpus::Keep)?;
        let m_de = CompiledModule::deserialize_with_config(&module_code, &deserializer_config)
            .map_err(|_| Corpus::Reject)?;
        move_bytecode_verifier::verify_module_with_config(&verifier_config, &m_de)
            .map_err(|_| Corpus::Reject)?;
    }

    if let ExecVariant::Script {
        script: s,
        type_args: _,
        args: _,
    } = &input.exec_variant
    {
        // reject bad scripts fast
        let mut script_code: Vec<u8> = vec![];
        s.serialize(&mut script_code).map_err(|_| Corpus::Keep)?;
        let s_de = CompiledScript::deserialize_with_config(&script_code, &deserializer_config)
            .map_err(|_| Corpus::Reject)?;
        move_bytecode_verifier::verify_script_with_config(&verifier_config, &s_de)
            .map_err(|_| Corpus::Reject)?;
    }

    // check no duplicates
    let mset: HashSet<_> = input.dep_modules.iter().map(|m| m.self_id()).collect();
    if mset.len() != input.dep_modules.len() {
        return Err(Corpus::Reject);
    }

    // topologically order modules {
    let all_modules = input.dep_modules.clone();
    let mut map = all_modules
        .into_iter()
        .map(|m| (m.self_id(), m))
        .collect::<BTreeMap<_, _>>();
    let mut order = vec![];
    for id in map.keys() {
        let mut visited = HashSet::new();
        sort_by_deps(&map, &mut order, id.clone(), &mut visited)?;
    }
    // }

    // group same address modules in packages. keep local ordering.
    let mut packages = vec![];
    for cur_package_id in order.iter() {
        let mut cur = vec![];
        if !map.contains_key(cur_package_id) {
            continue;
        }
        // this makes sure we keep the order in packages
        for id in order.iter() {
            // check if part of current package
            if id.address() == cur_package_id.address() {
                if let Some(module) = map.remove(cur_package_id) {
                    cur.push(module);
                }
            }
        }
        packages.push(cur)
    }

    AptosVM::set_concurrency_level_once(FUZZER_CONCURRENCY_LEVEL);
    let write_set = VM.as_ref().ok_or(Corpus::Reject)?;
    let mut vm = FakeExecutor::from_genesis_with_existing_thread_pool(
        write_set,
        ChainId::mainnet(),
        Arc::clone(&TP),
    )
    .set_not_parallel();

    // publish all packages
    for group in packages {
        let sender = *group[0].address();
        let acc = vm.new_account_at(sender);

        // First publish attempt
        publish_group(&mut vm, &acc, &group, 0)?;

        // Test upgrade path
        if TEST_UPGRADE {
            // Second publish attempt
            publish_group(&mut vm, &acc, &group, 1)?;
        }

        tdbg!("published");
    }

    Ok(())
}

fuzz_target!(|fuzz_data: RunnableState| -> Corpus {
    run_case(fuzz_data).err().unwrap_or(Corpus::Keep)
});

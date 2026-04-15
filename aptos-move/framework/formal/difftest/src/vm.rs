use anyhow::{Context, Result};
use aptos_gas_schedule::{MiscGasParameters, NativeGasParameters, LATEST_GAS_FEATURE_VERSION};
use aptos_types::on_chain_config::{FeatureFlag, Features, TimedFeaturesBuilder};
use aptos_vm::natives::aptos_natives;
use move_binary_format::errors::{Location, PartialVMError};
use move_binary_format::file_format::CompiledModule;
use move_binary_format::file_format_common::VERSION_MAX;
use move_core_types::{
    account_address::AccountAddress,
    identifier::Identifier,
    language_storage::{ModuleId, StructTag, TypeTag},
    value::{MoveTypeLayout, MoveValue},
};
use move_vm_runtime::{
    data_cache::TransactionDataCache,
    module_traversal::{TraversalContext, TraversalStorage},
    move_vm::MoveVM,
    AsUnsyncModuleStorage, ModuleStorage, RuntimeEnvironment,
};
use move_vm_test_utils::InMemoryStorage;
use move_vm_types::gas::UnmeteredGasMeter;
use move_vm_types::resolver::ResourceResolver;
use serde::{Deserialize, Serialize};

use crate::schema::{TestResult, TypedValue};
use crate::typed_value::{move_value_to_typed, typed_value_to_move};

pub const STD_ADDR: AccountAddress = AccountAddress::ONE;

pub enum RunResult {
    Returned(Vec<(MoveValue, MoveTypeLayout)>),
    Aborted(u64),
}

/// Aptos VM natives + on-chain feature flags required for confidential-asset modules
/// (Ristretto, Bulletproofs batch, …).
pub fn difftest_features() -> Features {
    let mut features = Features::default();
    features.enable(FeatureFlag::SHA_512_AND_RIPEMD_160_NATIVES);
    features.enable(FeatureFlag::BULLETPROOFS_NATIVES);
    features.enable(FeatureFlag::BULLETPROOFS_BATCH_NATIVES);
    features
}

/// In-memory storage backed by **Aptos** natives (full framework surface).
pub fn setup_storage_aptos() -> Result<InMemoryStorage> {
    let natives = aptos_natives(
        LATEST_GAS_FEATURE_VERSION,
        NativeGasParameters::zeros(),
        MiscGasParameters::zeros(),
        TimedFeaturesBuilder::enable_all().build(),
        difftest_features(),
    );
    let runtime_environment = RuntimeEnvironment::new(natives);
    Ok(InMemoryStorage::new_with_runtime_environment(
        runtime_environment,
    ))
}

/// Load every bytecode module from the head release bundle (Move stdlib + Aptos + experimental).
/// Serialize a freshly compiled module for loading into the VM (match framework bundle version).
pub fn module_blob(module: &CompiledModule) -> Result<Vec<u8>> {
    let mut blob = vec![];
    module.serialize_for_version(Some(VERSION_MAX), &mut blob)?;
    Ok(blob)
}

pub fn load_head_release_bundle(storage: &mut InMemoryStorage) -> Result<()> {
    for module in aptos_cached_packages::head_release_bundle().compiled_modules() {
        let mut blob = vec![];
        module.serialize_for_version(Some(VERSION_MAX), &mut blob)?;
        storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
    }
    Ok(())
}

#[derive(Debug, Deserialize, Serialize)]
struct MoveStdFeatures {
    features: Vec<u8>,
}

/// `std::features::SHA_512_AND_RIPEMD_160_NATIVES` (see `move-stdlib/.../features.move`).
const SHA_512_AND_RIPEMD_160_FEATURE_ID: u64 = 3;

fn merge_move_stdlib_feature_bit(vec: &mut Vec<u8>, feature_id: u64) {
    let byte_index = (feature_id / 8) as usize;
    let bit_mask = 1u8 << ((feature_id % 8) as u8);
    while vec.len() <= byte_index {
        vec.push(0);
    }
    vec[byte_index] |= bit_mask;
}

fn partial_vm_err(err: PartialVMError) -> anyhow::Error {
    anyhow::anyhow!("{:?}", err.finish(Location::Undefined))
}

/// `aptos_hash::sha3_512` consults `std::features::sha_512_and_ripemd_160_enabled()`, which reads
/// the on-chain `Features` resource at `@std` (`0x1`), not the Rust `Features` passed into
/// `aptos_natives`. Merge the SHA-512 feature bit into that resource after loading genesis/bundle.
pub fn ensure_sha512_move_stdlib_feature(storage: &mut InMemoryStorage) -> Result<()> {
    let addr = AccountAddress::ONE;
    let tag = StructTag {
        address: addr,
        module: Identifier::new("features")?,
        name: Identifier::new("Features")?,
        type_args: vec![],
    };
    let (existing, _) = storage
        .get_resource_bytes_with_metadata_and_layout(&addr, &tag, &[], None)
        .map_err(partial_vm_err)?;

    let mut f = if let Some(bytes) = existing {
        bcs::from_bytes::<MoveStdFeatures>(&bytes)
            .with_context(|| "decode 0x1::features::Features (BCS)")?
    } else {
        MoveStdFeatures { features: vec![] }
    };
    merge_move_stdlib_feature_bit(&mut f.features, SHA_512_AND_RIPEMD_160_FEATURE_ID);
    let blob = bcs::to_bytes(&f)?;
    storage.publish_or_overwrite_resource(addr, tag, blob);
    Ok(())
}

pub fn run_function(
    storage: &mut InMemoryStorage,
    module_addr: AccountAddress,
    module_name: &str,
    function_name: &str,
    ty_args: &[TypeTag],
    args: Vec<MoveValue>,
) -> Result<RunResult> {
    let traversal_storage = TraversalStorage::new();

    let module_id = ModuleId::new(module_addr, Identifier::new(module_name)?);
    let func_name = Identifier::new(function_name)?;

    let mut data_cache = TransactionDataCache::empty();
    let exec_result = {
        let module_storage = storage.as_unsync_module_storage();
        let func = module_storage
            .load_function(&module_id, &func_name, ty_args)
            .map_err(|e| anyhow::anyhow!("failed to load function: {:?}", e))?;

        let serialized_args: Vec<Vec<u8>> = args
            .iter()
            .map(|v| {
                v.simple_serialize()
                    .ok_or_else(|| anyhow::anyhow!("failed to serialize argument: {:?}", v))
            })
            .collect::<Result<_>>()?;

        let mut extensions = aptos_vm::natives::new_unit_test_native_extensions();
        MoveVM::execute_loaded_function(
            func,
            serialized_args,
            &mut data_cache,
            &mut UnmeteredGasMeter,
            &mut TraversalContext::new(&traversal_storage),
            &mut extensions,
            &module_storage,
            storage,
        )
    };

    match exec_result {
        Ok(serialized_return) => {
            let module_storage = storage.as_unsync_module_storage();
            let change_set = data_cache.into_effects(&module_storage).map_err(|e| {
                anyhow::anyhow!("into_effects: {:?}", e.finish(Location::Undefined))
            })?;
            drop(module_storage);
            storage
                .apply(change_set)
                .map_err(|e| anyhow::anyhow!("storage.apply: {:?}", e))?;

            let mut decoded = Vec::new();
            for (blob, layout) in &serialized_return.return_values {
                let val = MoveValue::simple_deserialize(blob, layout)
                    .map_err(|e| anyhow::anyhow!("failed to deserialize return: {:?}", e))?;
                decoded.push((val, layout.clone()));
            }
            Ok(RunResult::Returned(decoded))
        },
        Err(vm_error) => {
            if let Some(abort_code) = vm_error.sub_status() {
                Ok(RunResult::Aborted(abort_code))
            } else {
                Err(anyhow::anyhow!("VM error: {:?}", vm_error))
            }
        },
    }
}

pub fn run_test_case(
    storage: &mut InMemoryStorage,
    module_addr: AccountAddress,
    module_name: &str,
    function: &str,
    args: &[TypedValue],
) -> Result<TestResult> {
    let move_args: Vec<MoveValue> = args
        .iter()
        .map(|tv| typed_value_to_move(tv).map(|(v, _)| v))
        .collect::<Result<_>>()?;

    let result = run_function(storage, module_addr, module_name, function, &[], move_args)?;
    match result {
        RunResult::Returned(vals) => {
            let typed: Vec<TypedValue> = vals
                .iter()
                .map(|(v, l)| move_value_to_typed(v, l))
                .collect();
            Ok(TestResult::Returned { values: typed })
        },
        RunResult::Aborted(code) => Ok(TestResult::Aborted { abort_code: code }),
    }
}

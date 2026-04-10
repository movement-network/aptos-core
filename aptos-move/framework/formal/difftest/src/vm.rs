use anyhow::Result;
use codespan_reporting::term::termcolor::Buffer;
use legacy_move_compiler::compiled_unit::AnnotatedCompiledUnit;
use move_core_types::{
    account_address::AccountAddress,
    identifier::Identifier,
    language_storage::{ModuleId, TypeTag},
    value::{MoveTypeLayout, MoveValue},
};
use move_model::metadata::LanguageVersion;
use move_vm_runtime::{
    data_cache::TransactionDataCache,
    module_traversal::{TraversalContext, TraversalStorage},
    move_vm::MoveVM,
    native_extensions::NativeContextExtensions,
    AsUnsyncModuleStorage, ModuleStorage, RuntimeEnvironment,
};
use move_vm_test_utils::InMemoryStorage;
use move_vm_types::gas::UnmeteredGasMeter;
use crate::schema::{TestResult, TypedValue};
use crate::typed_value::{move_value_to_typed, typed_value_to_move};

pub const STD_ADDR: AccountAddress = AccountAddress::ONE;

pub enum RunResult {
    Returned(Vec<(MoveValue, MoveTypeLayout)>),
    Aborted(u64),
}

pub fn setup_storage() -> Result<InMemoryStorage> {
    let natives = move_stdlib::natives::all_natives(
        STD_ADDR,
        move_stdlib::natives::GasParameters::zeros(),
    );
    let runtime_environment = RuntimeEnvironment::new(natives);
    Ok(InMemoryStorage::new_with_runtime_environment(runtime_environment))
}

pub fn load_stdlib_modules(storage: &mut InMemoryStorage) -> Result<()> {
    let stdlib_files = move_stdlib::move_stdlib_files();
    let named_addresses = move_stdlib::move_stdlib_named_addresses();

    let options = move_compiler_v2::Options {
        sources: stdlib_files,
        dependencies: vec![],
        named_address_mapping: named_addresses
            .into_iter()
            .map(|(alias, addr)| format!("{}={}", alias, addr))
            .collect(),
        known_attributes: legacy_move_compiler::shared::known_attributes::KnownAttribute::get_all_attribute_names().clone(),
        language_version: Some(LanguageVersion::latest_stable()),
        ..move_compiler_v2::Options::default()
    };

    let mut error_writer = Buffer::no_color();
    let result = {
        let mut emitter = options.error_emitter(&mut error_writer);
        move_compiler_v2::run_move_compiler(emitter.as_mut(), options)
    };
    let error_str = String::from_utf8_lossy(&error_writer.into_inner()).to_string();
    let (_, units) =
        result.map_err(|_| anyhow::anyhow!("stdlib compilation failed:\n{}", error_str))?;

    for unit in units {
        if let AnnotatedCompiledUnit::Module(m) = unit {
            let module = m.named_module.module;
            let mut blob = vec![];
            module.serialize(&mut blob)?;
            storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
        }
    }
    Ok(())
}

pub fn run_function(
    storage: &InMemoryStorage,
    module_name: &str,
    function_name: &str,
    ty_args: &[TypeTag],
    args: Vec<MoveValue>,
) -> Result<RunResult> {
    let module_storage = storage.as_unsync_module_storage();
    let traversal_storage = TraversalStorage::new();

    let module_id = ModuleId::new(STD_ADDR, Identifier::new(module_name)?);
    let func_name = Identifier::new(function_name)?;

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

    match MoveVM::execute_loaded_function(
        func,
        serialized_args,
        &mut TransactionDataCache::empty(),
        &mut UnmeteredGasMeter,
        &mut TraversalContext::new(&traversal_storage),
        &mut NativeContextExtensions::default(),
        &module_storage,
        storage,
    ) {
        Ok(serialized_return) => {
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
    storage: &InMemoryStorage,
    module_name: &str,
    function: &str,
    args: &[TypedValue],
) -> Result<TestResult> {
    let move_args: Vec<MoveValue> = args
        .iter()
        .map(|tv| typed_value_to_move(tv).map(|(v, _)| v))
        .collect::<Result<_>>()?;

    let result = run_function(storage, module_name, function, &[], move_args)?;
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

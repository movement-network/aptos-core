use anyhow::Result;
use codespan_reporting::term::termcolor::Buffer;
use legacy_move_compiler::compiled_unit::AnnotatedCompiledUnit;
use move_binary_format::file_format::CompiledModule;
use move_model::metadata::LanguageVersion;
use std::collections::BTreeMap;
use tempfile::tempdir;

pub fn compile_with_stdlib(source: &str) -> Result<Vec<CompiledModule>> {
    let dir = tempdir()?;
    let path = dir.path().join("test_module.move");
    std::fs::write(&path, source)?;

    let named_addresses: BTreeMap<String, _> = move_stdlib::move_stdlib_named_addresses();
    let stdlib_files = move_stdlib::move_stdlib_files();

    let options = move_compiler_v2::Options {
        sources: vec![path.to_str().unwrap().to_string()],
        dependencies: stdlib_files,
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
        result.map_err(|_| anyhow::anyhow!("Move compilation failed:\n{}", error_str))?;

    let modules: Vec<CompiledModule> = units
        .into_iter()
        .filter_map(|unit| match unit {
            AnnotatedCompiledUnit::Module(m) => Some(m.named_module.module),
            _ => None,
        })
        .collect();

    dir.close()?;
    Ok(modules)
}

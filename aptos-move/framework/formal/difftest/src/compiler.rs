use anyhow::{Context, Result};
use codespan_reporting::term::termcolor::Buffer;
use legacy_move_compiler::compiled_unit::AnnotatedCompiledUnit;
use move_binary_format::file_format::CompiledModule;
use move_model::metadata::{CompilerVersion, LanguageVersion};
use std::collections::BTreeMap;
use std::path::Path;
use tempfile::tempdir;

/// Compile one or more Move sources (typically `difftest/move/*.move` helpers + inline harness)
/// against the **head** Aptos framework release bundle.
///
/// `extra_move_paths` are compiled first (sorted for deterministic builds), then `user_source`
/// is written to `difftest_user.move` in the temp dir and appended.
pub fn compile_with_aptos_head_bundle_extras(
    user_source: &str,
    extra_move_paths: &[&Path],
) -> Result<Vec<CompiledModule>> {
    let dir = tempdir()?;

    let mut sources: Vec<String> = Vec::new();
    let mut extra_sorted: Vec<&Path> = extra_move_paths.to_vec();
    extra_sorted.sort_by_key(|p| p.to_string_lossy());
    for p in extra_sorted {
        sources.push(
            p.canonicalize()
                .with_context(|| format!("difftest Move helper not found: {}", p.display()))?
                .to_string_lossy()
                .into_owned(),
        );
    }

    let main_path = dir.path().join("difftest_user.move");
    std::fs::write(&main_path, user_source)?;
    sources.push(
        main_path
            .canonicalize()
            .expect("just wrote difftest_user.move")
            .to_string_lossy()
            .into_owned(),
    );

    let bundle = aptos_cached_packages::head_release_bundle();
    let dependencies = bundle
        .files()
        .context("head_release_bundle: missing source_dirs (rebuild cached-packages)")?;

    let named_address_mapping: Vec<String> = aptos_framework::named_addresses()
        .iter()
        .map(|(alias, addr)| format!("{}={}", alias, addr))
        .collect();

    let options = move_compiler_v2::Options {
        sources,
        dependencies,
        named_address_mapping,
        known_attributes: aptos_framework::extended_checks::get_all_attribute_names().clone(),
        language_version: Some(LanguageVersion::latest()),
        compiler_version: Some(CompilerVersion::latest()),
        skip_attribute_checks: true,
        // `#[test_only]` paths (e.g. `confidential_asset::serialize_auditor_*`,
        // `ristretto255_bulletproofs::prove_range_pedersen`) are exercised by the difftest harness.
        testing: true,
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

/// Compile a single inline harness module (no extra `difftest/move` helpers).
pub fn compile_with_aptos_head_bundle(user_source: &str) -> Result<Vec<CompiledModule>> {
    compile_with_aptos_head_bundle_extras(user_source, &[])
}

/// Legacy path: compile only against **Move stdlib** (no Aptos framework).
/// Kept for reference; all harness suites use [`compile_with_aptos_head_bundle`].
#[allow(dead_code)]
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
        known_attributes:
            legacy_move_compiler::shared::known_attributes::KnownAttribute::get_all_attribute_names(
            )
            .clone(),
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

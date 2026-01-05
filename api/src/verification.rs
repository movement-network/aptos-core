// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! On-demand bytecode verification for PackageRegistry source code.
//!
//! Verifies that source code stored in PackageRegistry compiles to the same
//! bytecode as what's deployed on-chain. Enabled via `api.bytecode_verification_enabled`.

use anyhow::{Context, Result};
use aptos_framework::{natives::code::PackageRegistry, unzip_metadata_str};
use aptos_types::{
    account_address::AccountAddress,
    state_store::{state_key::StateKey, TStateView},
};
use codespan_reporting::term::termcolor::Buffer;
use legacy_move_compiler::shared::known_attributes::KnownAttribute;
use move_core_types::identifier::Identifier;
use move_model::metadata::LanguageVersion;
use poem_openapi::Object;
use serde::{Deserialize, Serialize};
use std::{fs::File, io::Write};
use tempfile::tempdir;

/// Verification status enum for local storage/caching
///
/// This enum is used internally for caching verification results.
/// The API returns a boolean (true = verified_success, false = verified_failure).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum VerificationStatus {
    /// Source code compiles to matching bytecode
    VerifiedSuccess,
    /// Source code compiles but bytecode doesn't match
    VerifiedFailure,
    /// No source code available in PackageRegistry
    Unverified,
}

impl VerificationStatus {
    /// Convert to boolean for API response
    /// Returns Some(true) for VerifiedSuccess, Some(false) for VerifiedFailure, None for Unverified
    pub fn to_bool(&self) -> Option<bool> {
        match self {
            VerificationStatus::VerifiedSuccess => Some(true),
            VerificationStatus::VerifiedFailure => Some(false),
            VerificationStatus::Unverified => None,
        }
    }
}

/// Response for module verification status endpoint
#[derive(Clone, Debug, Serialize, Deserialize, Object)]
pub struct ModuleVerificationStatusResponse {
    /// Whether the source code compiles to the same bytecode as on-chain
    /// true = verified_success (bytecode matches)
    /// false = verified_failure (bytecode doesn't match)
    pub verified: bool,
}

/// Verification result for a single module
#[derive(Clone, Debug, Serialize, Deserialize, Object)]
pub struct ModuleVerificationResult {
    pub module_name: String,
    /// Whether source compiles to the same bytecode as on-chain
    pub bytecode_matches: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

/// Verification status for a single package
#[derive(Clone, Debug, Serialize, Deserialize, Object)]
pub struct PackageVerificationStatus {
    pub name: String,
    /// Overall verification status (all modules with source match)
    pub bytecode_verified: bool,
    /// Number of modules that have source code provided
    pub modules_with_source: u32,
    /// Number of modules without source code
    pub modules_without_source: u32,
    /// Detailed verification results per module
    pub module_results: Vec<ModuleVerificationResult>,
}

/// Verification response for PackageRegistry
#[derive(Clone, Debug, Serialize, Deserialize, Object)]
pub struct PackageRegistryVerification {
    /// Overall verification status
    pub source_verified: bool,
    /// Verification status for each package
    pub packages: Vec<PackageVerificationStatus>,
}

fn compile_module_source(
    source_code: &str,
    module_name: &str,
    address: AccountAddress,
) -> Result<Vec<u8>> {
    // Extract named address from module declaration (e.g., "verification_test" from "module verification_test::greeter_valid")
    let named_address_from_source = source_code
        .lines()
        .find_map(|line| {
            let line = line.trim();
            if line.starts_with("module") {
                // Parse "module <named_address>::<module_name>"
                let parts: Vec<&str> = line.split("::").collect();
                if parts.len() >= 2 {
                    // Extract the named address part (remove "module " prefix)
                    parts[0].trim_start_matches("module").trim().to_string().into()
                } else {
                    None
                }
            } else {
                None
            }
        });

    // Create a temp directory for the source file
    let dir = tempdir().context("Failed to create temp directory")?;
    let file_path = dir.path().join(format!("{}.move", module_name));
    
    // Write source to temp file
    let mut file = File::create(&file_path)
        .with_context(|| format!("Failed to create temp file for module {}", module_name))?;
    writeln!(file, "{}", source_code)
        .with_context(|| format!("Failed to write source for module {}", module_name))?;
    drop(file);

    // Get minimal framework dependency - just move-stdlib for basic types like string
    // Keep it minimal to avoid stack overflow from processing large frameworks
    let deps: Vec<String> = vec![
        aptos_framework::path_in_crate("move-stdlib/sources").to_string_lossy().to_string(),
    ];

    // Set up named address mapping
    let mut named_addresses = vec![
        format!("std=0x1"),
        format!("aptos_std=0x1"),
        format!("aptos_framework=0x1"),
        format!("aptos_fungible_asset=0xA"),
        format!("aptos_token=0x3"),
        format!("core_resources=0xA550C18"),
        format!("vm_reserved=0x0"),
        // Map common named addresses to the deployer's address
        format!("deployer={}", address),
    ];
    
    // If we found a named address in the source, map it to the deployer's address
    // (since that's how it was compiled originally)
    if let Some(named_addr) = named_address_from_source {
        if !named_addr.is_empty() && named_addr != "0x1" && named_addr != "0xA" && named_addr != "0x3" {
            named_addresses.push(format!("{}={}", named_addr, address));
        }
    }

    let options = move_compiler_v2::Options {
        sources: vec![file_path.to_str().unwrap().to_string()],
        dependencies: deps,
        named_address_mapping: named_addresses,
        known_attributes: KnownAttribute::get_all_attribute_names().clone(),
        language_version: Some(LanguageVersion::latest_stable()),
        ..move_compiler_v2::Options::default()
    };

    let mut error_writer = Buffer::no_color();
    let result = {
        let mut emitter = options.error_emitter(&mut error_writer);
        move_compiler_v2::run_move_compiler(emitter.as_mut(), options)
    };

    let error_str = String::from_utf8_lossy(&error_writer.into_inner()).to_string();
    let (_, mut units) = result.map_err(|_| {
        anyhow::anyhow!("Compilation failed for module {}: {}", module_name, error_str)
    })?;

    // Clean up temp directory
    let _ = dir.close();

    // Extract compiled module
    if units.is_empty() {
        anyhow::bail!("No compiled units produced for module {}", module_name);
    }

    let unit = units.pop().unwrap();
    match unit {
        legacy_move_compiler::compiled_unit::AnnotatedCompiledUnit::Module(annot_module) => {
            let compiled = annot_module.named_module.module;
            let mut bytecode = Vec::new();
            compiled
                .serialize(&mut bytecode)
                .context("Failed to serialize compiled module")?;
            Ok(bytecode)
        },
        legacy_move_compiler::compiled_unit::AnnotatedCompiledUnit::Script(_) => {
            anyhow::bail!("Expected module but got script for {}", module_name)
        },
    }
}

/// Fetch on-chain bytecode for a module
fn fetch_on_chain_bytecode(
    state_view: &impl TStateView<Key = StateKey>,
    address: AccountAddress,
    module_name: &str,
) -> Result<Vec<u8>> {
    let identifier = Identifier::new(module_name)
        .with_context(|| format!("Invalid module name: {}", module_name))?;

    let state_key = StateKey::module(&address, &identifier);
    let bytes = state_view
        .get_state_value_bytes(&state_key)
        .with_context(|| format!("Failed to fetch bytecode for module {}", module_name))?
        .ok_or_else(|| anyhow::anyhow!("Module {} not found on-chain", module_name))?;

    Ok(bytes.to_vec())
}

/// Verify a single module's source against on-chain bytecode
fn verify_module_bytecode(
    module_metadata: &aptos_framework::natives::code::ModuleMetadata,
    address: AccountAddress,
    state_view: &impl TStateView<Key = StateKey>,
) -> ModuleVerificationResult {
    if module_metadata.source.is_empty() {
        return ModuleVerificationResult {
            module_name: module_metadata.name.clone(),
            bytecode_matches: false,
            error: Some("No source code provided in metadata".to_string()),
        };
    }

    // Ungzip source
    let source_code = match unzip_metadata_str(&module_metadata.source) {
        Ok(code) => code,
        Err(e) => {
            return ModuleVerificationResult {
                module_name: module_metadata.name.clone(),
                bytecode_matches: false,
                error: Some(format!("Failed to ungzip source: {}", e)),
            };
        },
    };

    // Fetch on-chain bytecode
    let on_chain_bytecode = match fetch_on_chain_bytecode(state_view, address, &module_metadata.name)
    {
        Ok(bytes) => bytes,
        Err(e) => {
            return ModuleVerificationResult {
                module_name: module_metadata.name.clone(),
                bytecode_matches: false,
                error: Some(format!("Failed to fetch on-chain bytecode: {}", e)),
            };
        },
    };

    // Compile source code
    let compiled_bytecode =
        match compile_module_source(&source_code, &module_metadata.name, address) {
            Ok(bytes) => bytes,
            Err(e) => {
                return ModuleVerificationResult {
                    module_name: module_metadata.name.clone(),
                    bytecode_matches: false,
                    error: Some(format!("Compilation failed: {}", e)),
                };
            },
        };

    // Compare bytecode by deserializing and comparing module structure
    // This is more robust than byte comparison as it ignores metadata differences
    let matches = compare_module_bytecode(&compiled_bytecode, &on_chain_bytecode);

    ModuleVerificationResult {
        module_name: module_metadata.name.clone(),
        bytecode_matches: matches,
        error: if matches {
            None
        } else {
            Some("Compiled bytecode does not match on-chain bytecode".to_string())
        },
    }
}

/// Compare two module bytecodes by deserializing them
/// Returns true if the modules are functionally equivalent
fn compare_module_bytecode(compiled: &[u8], on_chain: &[u8]) -> bool {
    use move_binary_format::CompiledModule;

    // First try exact byte comparison (fastest)
    if compiled == on_chain {
        return true;
    }

    // If bytes differ, deserialize and compare module structure
    let mut compiled_module = match CompiledModule::deserialize(compiled) {
        Ok(m) => m,
        Err(_) => return false,
    };
    
    let mut on_chain_module = match CompiledModule::deserialize(on_chain) {
        Ok(m) => m,
        Err(_) => return false,
    };

    // Clear metadata fields to compare only the core module structure
    compiled_module.metadata.clear();
    on_chain_module.metadata.clear();

    // Re-serialize both to normalize and compare
    let mut compiled_normalized = Vec::new();
    let mut on_chain_normalized = Vec::new();
    
    if compiled_module.serialize(&mut compiled_normalized).is_err() {
        return false;
    }
    if on_chain_module.serialize(&mut on_chain_normalized).is_err() {
        return false;
    }

    compiled_normalized == on_chain_normalized
}

/// Verify a single module's source code against on-chain bytecode and return status
///
/// This function is used by the on-demand verification endpoint.
/// It looks up the module in the PackageRegistry, extracts the source code,
/// compiles it, and compares with on-chain bytecode.
///
/// Returns:
/// - VerifiedSuccess if bytecode matches
/// - VerifiedFailure if bytecode doesn't match
/// - Unverified if no source code is available
pub fn verify_module_on_demand(
    registry: &PackageRegistry,
    address: AccountAddress,
    module_name: &str,
    state_view: &impl TStateView<Key = StateKey>,
) -> VerificationStatus {
    // Find the module in the registry
    for package in &registry.packages {
        for module_metadata in &package.modules {
            if module_metadata.name == module_name {
                // Check if source code exists
                if module_metadata.source.is_empty() {
                    return VerificationStatus::Unverified;
                }

                // Perform verification
                let result = verify_module_bytecode(module_metadata, address, state_view);
                
                if result.bytecode_matches {
                    return VerificationStatus::VerifiedSuccess;
                } else {
                    return VerificationStatus::VerifiedFailure;
                }
            }
        }
    }

    // Module not found in registry
    VerificationStatus::Unverified
}

/// Verify PackageRegistry source fields against on-chain bytecode
pub fn verify_package_registry_bytecode(
    registry: &PackageRegistry,
    address: AccountAddress,
    state_view: &impl TStateView<Key = StateKey>,
) -> Result<PackageRegistryVerification> {
    let mut packages = Vec::new();
    let mut all_verified = true;

    for package in &registry.packages {
        let mut module_results = Vec::new();
        let mut modules_with_source = 0;
        let mut modules_without_source = 0;
        let mut package_verified = true;

        for module_metadata in &package.modules {
            let result = verify_module_bytecode(module_metadata, address, state_view);

            if module_metadata.source.is_empty() {
                modules_without_source += 1;
            } else {
                modules_with_source += 1;
            }

            if !result.bytecode_matches {
                package_verified = false;
                all_verified = false;
            }

            module_results.push(result);
        }

        packages.push(PackageVerificationStatus {
            name: package.name.clone(),
            bytecode_verified: package_verified && modules_with_source > 0,
            modules_with_source,
            modules_without_source,
            module_results,
        });
    }

    Ok(PackageRegistryVerification {
        source_verified: all_verified && !packages.is_empty(),
        packages,
    })
}

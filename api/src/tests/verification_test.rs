// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use super::new_test_context_with_config;
use aptos_cached_packages::aptos_stdlib;
use crate::verification::verify_module_on_demand;
use aptos_api_test_context::{current_function_name, TestContext};
use aptos_api_types::AsConverter;
use aptos_config::config::NodeConfig;
use aptos_framework::{natives::code::PackageRegistry, zip_metadata_str, unzip_metadata_str, BuildOptions, BuiltPackage};
use aptos_types::state_store::TStateView;
use aptos_sdk::bcs;
use move_core_types::language_storage::StructTag;
use std::path::PathBuf;
use std::str::FromStr;

/// Helper function to set up a test context with verification enabled and deploy a test package
async fn setup_test_with_package(test_name: String) -> (TestContext, aptos_sdk::types::LocalAccount) {
    let mut node_config = NodeConfig::default();
    node_config.api.bytecode_verification_enabled = true;
    let mut context = new_test_context_with_config(test_name, node_config);
    let mut account = context.create_account().await;

    // Build package with source code included (with_srcs: true)
    let path = PathBuf::from(std::env!("CARGO_MANIFEST_DIR"))
        .join("src/tests/move/pack_verification_test");
    let mut build_options = BuildOptions::default();
    build_options.with_srcs = true;
    build_options.named_addresses.insert("test_module".to_string(), account.address());
    let package = BuiltPackage::build(path, build_options).unwrap();
    let code = package.extract_code();
    let metadata = package.extract_metadata().unwrap();
    let txn = aptos_stdlib::code_publish_package_txn(bcs::to_bytes(&metadata).unwrap(), code);
    context.publish_package(&mut account, txn).await;

    (context, account)
}

/// Tests that the verification endpoint returns `verified: true` for a module where the source code in PackageRegistry compiles to the same bytecode as what's deployed on-chain.
/// Why: This is the happy path that ensures the core verification functionality works correctly and validates that the named address extraction and compilation logic correctly matches the original deployment compilation process.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_module_verification_status_valid() {
    let (context, account) = setup_test_with_package(current_function_name!()).await;

    // Test verification status endpoint
    let module_name = "test_module";
    let url = format!(
        "/accounts/{}/modules/{}/verification_status",
        account.address(),
        module_name
    );
    let resp = context.get(&url).await;

    // Verify response
    assert_eq!(
        resp["verified"],
        true,
        "Verification should succeed for matching source and bytecode"
    );
}

/// Diagnostic test to compare on-chain bytecode vs recompiled bytecode and print debug info.
/// Why: Helps identify why verification might fail by showing the actual source code, bytecode lengths, and API response.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_bytecode_comparison_diagnostic() {
    use crate::verification::compile_module_source_for_test;
    
    let (context, account) = setup_test_with_package(current_function_name!()).await;

    // Get the PackageRegistry from on-chain
    let state_view = context.latest_state_view();
    let tag = StructTag::from_str("0x1::code::PackageRegistry").unwrap();
    let registry_bytes = state_view
        .as_converter(context.db.clone(), context.get_indexer_readers().cloned())
        .find_resource(&state_view, account.address().into(), &tag)
        .unwrap()
        .unwrap();
    let registry: PackageRegistry = bcs::from_bytes(&registry_bytes).unwrap();

    // Find the module and get its source
    let module_metadata = registry.packages[0].modules.iter()
        .find(|m| m.name == "test_module")
        .expect("Module not found in registry");
    
    // Check if source exists
    println!("=== SOURCE CODE ===");
    println!("Source code length (gzipped): {}", module_metadata.source.len());
    assert!(!module_metadata.source.is_empty(), "Source code should be present");

    // Ungzip the source
    let source_code = unzip_metadata_str(&module_metadata.source)
        .expect("Failed to ungzip source");
    println!("Source code:\n{}", source_code);

    // Get on-chain bytecode
    println!("\n=== ON-CHAIN BYTECODE ===");
    let module_id = move_core_types::language_storage::ModuleId::new(
        account.address(),
        move_core_types::identifier::Identifier::new("test_module").unwrap(),
    );
    let state_key = aptos_types::state_store::state_key::StateKey::module_id(&module_id);
    let on_chain_bytecode = state_view
        .get_state_value_bytes(&state_key)
        .expect("Failed to get state value")
        .expect("Module not found on chain");
    
    println!("On-chain bytecode length: {}", on_chain_bytecode.len());
    println!("On-chain bytecode (first 50 bytes): {:02x?}", &on_chain_bytecode[..50.min(on_chain_bytecode.len())]);

    // Recompile the source code - with manual compilation to see all details
    println!("\n=== RECOMPILATION ATTEMPT ===");
    println!("Compiling with address: {}", account.address());
    
    // Extract named address from source
    let named_addr = source_code.lines()
        .find_map(|line| {
            let line = line.trim();
            if line.starts_with("module") {
                let parts: Vec<&str> = line.split("::").collect();
                if parts.len() >= 2 {
                    Some(parts[0].trim_start_matches("module").trim().to_string())
                } else {
                    None
                }
            } else {
                None
            }
        });
    println!("Extracted named address: {:?}", named_addr);
    
    // Show what named address mappings would be used
    let mut named_addresses = vec![
        format!("std=0x1"),
        format!("aptos_std=0x1"),
        format!("aptos_framework=0x1"),
        format!("deployer={}", account.address()),
    ];
    if let Some(ref addr) = named_addr {
        if !addr.is_empty() && addr != "0x1" {
            named_addresses.push(format!("{}={}", addr, account.address()));
        }
    }
    println!("Named address mappings: {:?}", named_addresses);
    
    // Show actual deps being used (just move-stdlib now)
    let deps = vec![
        aptos_framework::path_in_crate("move-stdlib/sources").to_string_lossy().to_string(),
    ];
    println!("Deps count: {}", deps.len());
    for dep in &deps {
        println!("  Dep: {}", dep);
    }
    
    match compile_module_source_for_test(&source_code, "test_module", account.address()) {
        Ok(recompiled_bytecode) => {
            println!("\n=== RECOMPILED BYTECODE ===");
            println!("Recompiled bytecode length: {}", recompiled_bytecode.len());
            println!("Recompiled bytecode (first 50 bytes): {:02x?}", &recompiled_bytecode[..50.min(recompiled_bytecode.len())]);
            
            // Compare
            println!("\n=== COMPARISON ===");
            println!("Length match: {}", on_chain_bytecode.len() == recompiled_bytecode.len());
            println!("Raw bytecode match: {}", on_chain_bytecode.as_ref() == recompiled_bytecode.as_slice());
            
            if on_chain_bytecode.as_ref() != recompiled_bytecode.as_slice() {
                // Find first difference
                for (i, (a, b)) in on_chain_bytecode.iter().zip(recompiled_bytecode.iter()).enumerate() {
                    if a != b {
                        println!("First difference at byte {}: on-chain=0x{:02x}, recompiled=0x{:02x}", i, a, b);
                        break;
                    }
                }
            }
            
            // Test normalized comparison (deserialize, clear metadata, re-serialize, compare)
            println!("\n=== NORMALIZED COMPARISON (metadata cleared) ===");
            use move_binary_format::CompiledModule;
            
            let mut compiled_mod = CompiledModule::deserialize(&recompiled_bytecode).expect("deserialize compiled");
            let mut on_chain_mod = CompiledModule::deserialize(on_chain_bytecode.as_ref()).expect("deserialize on-chain");
            
            println!("Compiled metadata entries: {}", compiled_mod.metadata.len());
            println!("On-chain metadata entries: {}", on_chain_mod.metadata.len());
            
            // Clear metadata for comparison
            compiled_mod.metadata.clear();
            on_chain_mod.metadata.clear();
            
            let mut compiled_normalized = Vec::new();
            let mut on_chain_normalized = Vec::new();
            compiled_mod.serialize(&mut compiled_normalized).expect("serialize compiled");
            on_chain_mod.serialize(&mut on_chain_normalized).expect("serialize on-chain");
            
            println!("Normalized compiled length (no metadata): {}", compiled_normalized.len());
            println!("Normalized on-chain length (no metadata): {}", on_chain_normalized.len());
            println!("Normalized match: {}", compiled_normalized == on_chain_normalized);
            
            if compiled_normalized != on_chain_normalized {
                for (i, (a, b)) in compiled_normalized.iter().zip(on_chain_normalized.iter()).enumerate() {
                    if a != b {
                        println!("First normalized diff at byte {}: compiled=0x{:02x}, on-chain=0x{:02x}", i, a, b);
                        break;
                    }
                }
            }
        },
        Err(e) => {
            println!("Compilation FAILED: {:?}", e);
        }
    }

    // API response
    println!("\n=== API RESPONSE ===");
    let url = format!(
        "/accounts/{}/modules/{}/verification_status",
        account.address(),
        "test_module"
    );
    let resp = context.get(&url).await;
    println!("API response: {}", resp);
    
    // Just check we get a boolean response
    assert!(resp["verified"].is_boolean(), "Should return a boolean verified field");
}

/// Tests that the verification endpoint returns `verified: false` when source code doesn't match on-chain bytecode.
/// Why: Ensures verification correctly detects mismatched source code, the core security feature preventing incorrect source display.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_module_verification_status_mismatch() {
    let (context, account) = setup_test_with_package(current_function_name!()).await;

    // Get the PackageRegistry from on-chain
    let state_view = context.latest_state_view();
    let tag = StructTag::from_str("0x1::code::PackageRegistry").unwrap();
    let bytes = state_view
        .as_converter(context.db.clone(), context.get_indexer_readers().cloned())
        .find_resource(&state_view, account.address().into(), &tag)
        .unwrap()
        .unwrap();
    let mut registry: PackageRegistry = bcs::from_bytes(&bytes).unwrap();

    // Modify the source code in PackageRegistry to be different (mismatched)
    // This simulates a scenario where deployer provided incorrect source code
    let mismatched_source = r#"module test_module::test_module {
    use std::string::{Self, String};

    #[view]
    public fun greet(): String {
        string::utf8(b"Different source code that doesn't match")
    }
}"#;
    let mismatched_source_gzipped = zip_metadata_str(mismatched_source).unwrap();

    // Update the source code in the registry
    for package in &mut registry.packages {
        for module in &mut package.modules {
            if module.name == "test_module" {
                module.source = mismatched_source_gzipped.clone();
                break;
            }
        }
    }

    // Test verification with the modified registry
    // Note: We test the verification function directly since the API endpoint
    // reads from on-chain PackageRegistry, which still has the original source.
    // Reuse the same state_view to avoid potential issues
    let status = verify_module_on_demand(
        &registry,
        account.address(),
        "test_module",
        &state_view,
    );

    // Verify it returns VerifiedFailure
    assert_eq!(
        status.to_bool(),
        Some(false),
        "Verification should fail when source code doesn't match bytecode"
    );
}

/// Tests that the verification endpoint returns HTTP 503 with error code "api_disabled" when `api.bytecode_verification_enabled` is set to `false` in the node configuration.
/// Why: Ensures that nodes with verification disabled properly reject verification requests rather than silently failing or returning incorrect results, and validates that the feature flag correctly gates access to the verification functionality.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_module_verification_status_disabled() {
    // Create test context with bytecode verification disabled
    let mut node_config = NodeConfig::default();
    node_config.api.bytecode_verification_enabled = false;
    let mut context = new_test_context_with_config(current_function_name!(), node_config);
    let mut account = context.create_account().await;

    // Build package with source code included
    let path = PathBuf::from(std::env!("CARGO_MANIFEST_DIR"))
        .join("src/tests/move/pack_verification_test");
    let mut build_options = BuildOptions::default();
    build_options.with_srcs = true;
    build_options.named_addresses.insert("test_module".to_string(), account.address());
    let package = BuiltPackage::build(path, build_options).unwrap();
    let code = package.extract_code();
    let metadata = package.extract_metadata().unwrap();
    let txn = aptos_stdlib::code_publish_package_txn(bcs::to_bytes(&metadata).unwrap(), code);
    context.publish_package(&mut account, txn).await;

    // Test verification status endpoint - should return 503
    let module_name = "test_module";
    let url = format!(
        "/accounts/{}/modules/{}/verification_status",
        account.address(),
        module_name
    );
    let resp = context
        .expect_status_code(503)
        .get(&url)
        .await;

    // Verify error response
    assert_eq!(
        resp["error_code"],
        "api_disabled",
        "Should return service unavailable when verification is disabled"
    );
}

/// Tests that the verification endpoint returns HTTP 404 with error code "resource_not_found" when querying for a module that doesn't exist at the given account address.
/// Why: Ensures proper error handling for invalid module queries and validates that the endpoint correctly distinguishes between "module not found" and other error conditions (e.g., verification disabled, verification failure).
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_module_verification_status_not_found() {
    // Create test context with bytecode verification enabled
    let mut node_config = NodeConfig::default();
    node_config.api.bytecode_verification_enabled = true;
    let mut context = new_test_context_with_config(current_function_name!(), node_config);
    let account = context.create_account().await;

    // Test verification status for non-existent module - should return 404
    let module_name = "nonexistent_module";
    let url = format!(
        "/accounts/{}/modules/{}/verification_status",
        account.address(),
        module_name
    );
    let resp = context
        .expect_status_code(404)
        .get(&url)
        .await;

    // Verify error response
    assert_eq!(
        resp["error_code"],
        "resource_not_found",
        "Should return not found for non-existent module"
    );
}


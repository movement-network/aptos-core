//! Unit tests for bytecode verification API endpoint.

use super::new_test_context_with_config;
use aptos_cached_packages::aptos_stdlib;
use aptos_api_test_context::current_function_name;
use aptos_api_types::AsConverter;
use aptos_config::config::NodeConfig;
use aptos_framework::{natives::code::PackageRegistry, zip_metadata_str, BuildOptions, BuiltPackage};
use aptos_sdk::bcs;
use crate::verification::verify_module_on_demand;
use move_core_types::language_storage::StructTag;
use std::path::PathBuf;
use std::str::FromStr;

/// Build and publish test package, returning the transaction payload
fn build_test_package(account_address: aptos_types::account_address::AccountAddress) -> aptos_types::transaction::TransactionPayload {
    let path = PathBuf::from(std::env!("CARGO_MANIFEST_DIR"))
        .join("src/tests/move/pack_verification_test");
    let mut build_options = BuildOptions::default();
    build_options.with_srcs = true;
    build_options.named_addresses.insert("test_module".to_string(), account_address);
    let package = BuiltPackage::build(path, build_options).unwrap();
    aptos_stdlib::code_publish_package_txn(
        bcs::to_bytes(&package.extract_metadata().unwrap()).unwrap(),
        package.extract_code(),
    )
}

/// Tests verification returns `true` when source matches bytecode.
/// Why: Core happy path validation.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_module_verification_status_valid() {
    let mut node_config = NodeConfig::default();
    node_config.api.bytecode_verification_enabled = true;
    let mut context = new_test_context_with_config(current_function_name!(), node_config);
    let mut account = context.create_account().await;
    
    let txn = build_test_package(account.address());
    context.publish_package(&mut account, txn).await;

    let resp = context.get(&format!(
        "/accounts/{}/modules/test_module/verification_status",
        account.address()
    )).await;

    assert_eq!(resp["verified"], true);
}

/// Tests verification returns `false` when source doesn't match bytecode.
/// Why: Core security feature - detecting mismatched source code.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_module_verification_status_mismatch() {
    let mut node_config = NodeConfig::default();
    node_config.api.bytecode_verification_enabled = true;
    let mut context = new_test_context_with_config(current_function_name!(), node_config);
    let mut account = context.create_account().await;
    
    let txn = build_test_package(account.address());
    context.publish_package(&mut account, txn).await;

    // Get PackageRegistry and modify source to simulate mismatch
    let state_view = context.latest_state_view();
    let tag = StructTag::from_str("0x1::code::PackageRegistry").unwrap();
    let bytes = state_view
        .as_converter(context.db.clone(), context.get_indexer_readers().cloned())
        .find_resource(&state_view, account.address().into(), &tag)
        .unwrap()
        .unwrap();
    let mut registry: PackageRegistry = bcs::from_bytes(&bytes).unwrap();

    // Replace source with mismatched code
    let mismatched_source = r#"module test_module::test_module {
    use std::string::{Self, String};
    #[view]
    public fun greet(): String { string::utf8(b"WRONG") }
}"#;
    let mismatched_gzipped = zip_metadata_str(mismatched_source).unwrap();
    for package in &mut registry.packages {
        for module in &mut package.modules {
            if module.name == "test_module" {
                module.source = mismatched_gzipped.clone();
            }
        }
    }

    // Test directly (API reads original on-chain registry)
    let status = verify_module_on_demand(&registry, account.address(), "test_module", &state_view);
    assert_eq!(status.to_bool(), Some(false));
}

/// Tests verification returns HTTP 503 when feature is disabled.
/// Why: Ensures feature flag correctly gates access.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_module_verification_status_disabled() {
    let mut node_config = NodeConfig::default();
    node_config.api.bytecode_verification_enabled = false;
    let mut context = new_test_context_with_config(current_function_name!(), node_config);
    let mut account = context.create_account().await;
    
    let txn = build_test_package(account.address());
    context.publish_package(&mut account, txn).await;

    let resp = context.expect_status_code(503).get(&format!(
        "/accounts/{}/modules/test_module/verification_status",
        account.address()
    )).await;

    assert_eq!(resp["error_code"], "api_disabled");
}

/// Tests verification returns HTTP 404 for non-existent module.
/// Why: Proper error handling for invalid queries.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_module_verification_status_not_found() {
    let mut node_config = NodeConfig::default();
    node_config.api.bytecode_verification_enabled = true;
    let context = new_test_context_with_config(current_function_name!(), node_config);

    let resp = context.expect_status_code(404).get(
        "/accounts/0x1/modules/nonexistent_module/verification_status"
    ).await;

    assert_eq!(resp["error_code"], "resource_not_found");
}

// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Enforcement of the on-chain transaction permission table
//! (`0x1::transaction_permissions`), gated by the `TRANSACTION_PERMISSIONS`
//! feature flag.
//!
//! Enforcement happens at two points, because no single point can classify
//! all transaction kinds:
//! - At validation ([`check_transaction_permitted_at_validation`]): scripts
//!   and "other" transactions. A denial discards the transaction with no gas
//!   charged, in mempool, at execution, and in simulation alike.
//! - At the code-publish funnel in the VM: deploy vs. upgrade, which is only
//!   knowable once the publish request exists. A denial there keeps the
//!   transaction and charges gas, so denied publishes are not free compute.
//!
//! Hardcoded self-bricking guard: approved governance scripts, framework
//! reserved and core-resources senders, and `0x1::aptos_governance` entry
//! functions are never denied, so the governance path that edits the table
//! stays open no matter what the table contains.

use aptos_types::{
    account_config::{aptos_test_root_address, CORE_CODE_ADDRESS},
    on_chain_config::{
        ConfigStorage, FeatureFlag, Features, OnChainConfig, TransactionPermissionKind,
        TransactionPermissions,
    },
    transaction::{EntryFunction, TransactionExecutableRef},
};
use aptos_vm_types::module_and_script_storage::module_storage::AptosModuleStorage;
use move_binary_format::CompiledModule;
use move_core_types::{
    account_address::AccountAddress,
    vm_status::{StatusCode, VMStatus},
};

/// Senders that can never be denied: the framework reserved addresses
/// (0x1..0xa and friends) and the core-resources account.
fn is_exempt_sender(sender: AccountAddress) -> bool {
    sender.is_special() || sender == aptos_test_root_address()
}

/// Entry functions that perform a code publish. These are exempt from the
/// "other" check at validation and judged as deploy/upgrade at the publish
/// funnel instead. A miss here is safe: the transaction is then checked as
/// "other" at validation and still as deploy/upgrade at the funnel.
fn is_publish_entry_function(entry_fn: &EntryFunction) -> bool {
    let module = entry_fn.module();
    module.address() == &CORE_CODE_ADDRESS
        && matches!(
            (module.name().as_str(), entry_fn.function().as_str()),
            ("code", "publish_package_txn")
                | ("object_code_deployment", "publish")
                | ("object_code_deployment", "upgrade")
                | (
                    "resource_account",
                    "create_resource_account_and_publish_package"
                )
        )
}

/// Part of the self-bricking guard: `aptos_governance` entry functions
/// (proposal creation, voting, resolution helpers) are never denied, so a
/// wildcard "deny other" rule cannot block the governance flow that fixes
/// the table.
fn is_governance_entry_function(entry_fn: &EntryFunction) -> bool {
    let module = entry_fn.module();
    module.address() == &CORE_CODE_ADDRESS && module.name().as_str() == "aptos_governance"
}

/// Check A: classify the transaction as script or other and consult the rule
/// table. Publish entry functions are skipped here and judged at the publish
/// funnel. Returns a discard status on denial.
pub(crate) fn check_transaction_permitted_at_validation(
    features: &Features,
    resolver: &impl ConfigStorage,
    sender: AccountAddress,
    executable: &TransactionExecutableRef,
    is_approved_gov_script: bool,
) -> Result<(), VMStatus> {
    if !features.is_enabled(FeatureFlag::TRANSACTION_PERMISSIONS) {
        return Ok(());
    }
    if is_approved_gov_script || is_exempt_sender(sender) {
        return Ok(());
    }
    let kind = match executable {
        TransactionExecutableRef::Script(_) => TransactionPermissionKind::Script,
        TransactionExecutableRef::EntryFunction(entry_fn) => {
            if is_publish_entry_function(entry_fn) || is_governance_entry_function(entry_fn) {
                return Ok(());
            }
            TransactionPermissionKind::Other
        },
        // The inner payload of a multisig transaction is stored on-chain; the
        // outer transaction is classified by its sender like any other.
        TransactionExecutableRef::Empty => TransactionPermissionKind::Other,
    };
    let permissions = match TransactionPermissions::fetch_config(resolver) {
        Some(permissions) => permissions,
        None => return Ok(()),
    };
    if permissions.is_allowed(sender, kind) {
        Ok(())
    } else {
        Err(VMStatus::error(
            StatusCode::TRANSACTION_NOT_PERMITTED,
            Some(format!(
                "transaction permission table denies {:?} transactions from {}",
                kind, sender
            )),
        ))
    }
}

/// Check B: classify a code publish as deploy or upgrade and consult the rule
/// table. An upgrade is a bundle in which any module already exists at the
/// destination. Returns a kept (gas-charged) failure status on denial.
pub(crate) fn check_publish_permitted(
    features: &Features,
    resolver: &impl ConfigStorage,
    module_storage: &impl AptosModuleStorage,
    modules: &[CompiledModule],
    sender: AccountAddress,
    is_approved_gov_script: bool,
) -> Result<(), VMStatus> {
    if !features.is_enabled(FeatureFlag::TRANSACTION_PERMISSIONS) {
        return Ok(());
    }
    if is_approved_gov_script || is_exempt_sender(sender) {
        return Ok(());
    }
    let permissions = match TransactionPermissions::fetch_config(resolver) {
        Some(permissions) => permissions,
        None => return Ok(()),
    };
    let mut is_upgrade = false;
    for module in modules {
        if module_storage
            .fetch_module_size_in_bytes(module.self_addr(), module.self_name())
            .map_err(|err| err.into_vm_status())?
            .is_some()
        {
            is_upgrade = true;
            break;
        }
    }
    let kind = if is_upgrade {
        TransactionPermissionKind::Upgrade
    } else {
        TransactionPermissionKind::Deploy
    };
    if permissions.is_allowed(sender, kind) {
        Ok(())
    } else {
        Err(VMStatus::error(
            StatusCode::MODULE_PUBLISHING_NOT_PERMITTED,
            Some(format!(
                "transaction permission table denies {:?} by {}",
                kind, sender
            )),
        ))
    }
}

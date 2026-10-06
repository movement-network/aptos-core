// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Enforcement of the on-chain transaction permission table
//! (`0x1::transaction_permissions`), gated by the `TRANSACTION_PERMISSIONS`
//! feature flag.
//!
//! Transaction-level rules (no module pattern) are enforced at two points,
//! because no single point can classify all transaction kinds:
//! - At validation ([`check_transaction_permitted_at_validation`]): scripts
//!   and "other" transactions. A denial discards the transaction with no gas
//!   charged, in mempool, at execution, and in simulation alike.
//! - At the code-publish funnel in the VM ([`check_publish_permitted`]):
//!   deploy vs. upgrade, which is only knowable once the publish request
//!   exists. A denial there keeps the transaction and charges gas, so denied
//!   publishes are not free compute.
//!
//! Module rules (rules with a module pattern) are enforced per module:
//! - for deploy/upgrade kinds, against each module of a publish bundle at the
//!   publish funnel;
//! - for script/other kinds, against every module the transaction loads
//!   during payload execution, via [`PermissionCheckedCodeStorage`] — a
//!   decorator around the session's module storage, so entry points,
//!   transitive calls, resource-type loads, closure resolution, and lazy
//!   loading are all covered uniformly. Validation additionally pre-checks an
//!   entry function's own module so the common case is rejected in mempool.
//!
//! Modules at special addresses (0x0..0xf) are always accessible: every
//! transaction loads framework code, so a rule against those would halt the
//! chain. The publish process itself (bundle fetches, init_module) runs on
//! raw storage; publishing is governed solely by the publish check.
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
    state_store::state_value::StateValueMetadata,
    transaction::{EntryFunction, TransactionExecutableRef},
};
use aptos_vm_types::module_and_script_storage::module_storage::AptosModuleStorage;
use bytes::Bytes;
use move_binary_format::{
    errors::{PartialVMError, PartialVMResult, VMResult},
    CompiledModule,
};
use move_core_types::{
    account_address::AccountAddress,
    identifier::IdentStr,
    language_storage::ModuleId,
    metadata::Metadata,
    vm_status::{StatusCode, VMStatus},
};
use move_vm_runtime::{
    CodeStorage, Module, ModuleStorage, RuntimeEnvironment, Script, WithRuntimeEnvironment,
};
use std::{cell::RefCell, collections::HashSet, sync::Arc};

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

/// The kind used for module-access rules while this payload executes.
pub(crate) fn access_kind_of(executable: &TransactionExecutableRef) -> TransactionPermissionKind {
    match executable {
        TransactionExecutableRef::Script(_) => TransactionPermissionKind::Script,
        TransactionExecutableRef::EntryFunction(_) | TransactionExecutableRef::Empty => {
            TransactionPermissionKind::Other
        },
    }
}

/// Fetches the permission table for enforcement against this transaction, or
/// `None` when nothing applies (feature off, exempt sender, approved
/// governance script, or no table on chain).
pub(crate) fn permissions_for(
    features: &Features,
    resolver: &impl ConfigStorage,
    sender: AccountAddress,
    is_approved_gov_script: bool,
) -> Option<TransactionPermissions> {
    if !features.is_enabled(FeatureFlag::TRANSACTION_PERMISSIONS) {
        return None;
    }
    if is_approved_gov_script || is_exempt_sender(sender) {
        return None;
    }
    TransactionPermissions::fetch_config(resolver)
}

/// Check A: classify the transaction as script or other and consult the
/// transaction-level rules; for an entry function, additionally pre-check its
/// own module against the module-access rules so the direct case is rejected
/// in mempool. Publish entry functions are skipped here and judged at the
/// publish funnel. Returns a discard status on denial.
pub(crate) fn check_transaction_permitted_at_validation(
    features: &Features,
    resolver: &impl ConfigStorage,
    sender: AccountAddress,
    executable: &TransactionExecutableRef,
    is_approved_gov_script: bool,
) -> Result<(), VMStatus> {
    let permissions = match permissions_for(features, resolver, sender, is_approved_gov_script) {
        Some(permissions) => permissions,
        None => return Ok(()),
    };
    let kind = match executable {
        TransactionExecutableRef::Script(_) => TransactionPermissionKind::Script,
        TransactionExecutableRef::EntryFunction(entry_fn) => {
            if is_publish_entry_function(entry_fn) || is_governance_entry_function(entry_fn) {
                return Ok(());
            }
            // Fast path for the module-access rules: the entry function's own
            // module is known here, so the common case is discarded before
            // execution. Transitive accesses are enforced by the storage
            // decorator during execution.
            let entry_module = entry_fn.module();
            if !entry_module.address().is_special()
                && !permissions.is_module_access_allowed(
                    sender,
                    TransactionPermissionKind::Other,
                    entry_module,
                )
            {
                return Err(VMStatus::error(
                    StatusCode::TRANSACTION_NOT_PERMITTED,
                    Some(format!(
                        "transaction permission table denies {} access to {}",
                        sender, entry_module,
                    )),
                ));
            }
            TransactionPermissionKind::Other
        },
        // The inner payload of a multisig transaction is stored on-chain; the
        // outer transaction is classified by its sender like any other.
        TransactionExecutableRef::Empty => TransactionPermissionKind::Other,
    };
    if permissions.is_tx_allowed(sender, kind) {
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

/// Check B: classify each published module as deploy (it does not exist yet)
/// or upgrade and consult the rules; module patterns match the published
/// module, and transaction-level deploy/upgrade rules match any module.
/// Returns a kept (gas-charged) failure status on denial.
pub(crate) fn check_publish_permitted(
    features: &Features,
    resolver: &impl ConfigStorage,
    module_storage: &impl AptosModuleStorage,
    modules: &[CompiledModule],
    sender: AccountAddress,
    is_approved_gov_script: bool,
) -> Result<(), VMStatus> {
    let permissions = match permissions_for(features, resolver, sender, is_approved_gov_script) {
        Some(permissions) => permissions,
        None => return Ok(()),
    };
    for module in modules {
        let exists = module_storage
            .fetch_module_size_in_bytes(module.self_addr(), module.self_name())
            .map_err(|err| err.into_vm_status())?
            .is_some();
        let kind = if exists {
            TransactionPermissionKind::Upgrade
        } else {
            TransactionPermissionKind::Deploy
        };
        let module_id = module.self_id();
        if !permissions.is_publish_allowed(sender, kind, &module_id) {
            return Err(VMStatus::error(
                StatusCode::MODULE_PUBLISHING_NOT_PERMITTED,
                Some(format!(
                    "transaction permission table denies {:?} of {} by {}",
                    kind, module_id, sender
                )),
            ));
        }
    }
    Ok(())
}

/// A decorator around the payload session's code storage that enforces
/// module-access rules on every module fetch. Wrap only the user payload
/// execution; system sessions (prologue, epilogue, publish resolution) use
/// the raw storage.
pub(crate) struct PermissionCheckedCodeStorage<'a, S> {
    inner: &'a S,
    /// `None` disables checking entirely (feature off, exempt transaction, or
    /// no module rules for this kind): the wrapper is then a passthrough.
    permissions: Option<TransactionPermissions>,
    sender: AccountAddress,
    kind: TransactionPermissionKind,
    /// Modules already checked and allowed, so each distinct module costs one
    /// table scan per transaction.
    allowed: RefCell<HashSet<ModuleId>>,
}

impl<'a, S> PermissionCheckedCodeStorage<'a, S> {
    /// `permissions` should come from [`permissions_for`]; it is dropped here
    /// when it holds no module rules for this kind, making the wrapper free.
    pub(crate) fn new(
        inner: &'a S,
        permissions: Option<TransactionPermissions>,
        sender: AccountAddress,
        kind: TransactionPermissionKind,
    ) -> Self {
        let permissions = permissions.filter(|p| p.has_module_rules(kind));
        Self {
            inner,
            permissions,
            sender,
            kind,
            allowed: RefCell::new(HashSet::new()),
        }
    }

    fn check(&self, address: &AccountAddress, module_name: &IdentStr) -> PartialVMResult<()> {
        let permissions = match &self.permissions {
            Some(permissions) => permissions,
            None => return Ok(()),
        };
        // Framework and other special-address modules are always accessible:
        // every transaction loads them.
        if address.is_special() {
            return Ok(());
        }
        let module_id = ModuleId::new(*address, module_name.to_owned());
        if self.allowed.borrow().contains(&module_id) {
            return Ok(());
        }
        if permissions.is_module_access_allowed(self.sender, self.kind, &module_id) {
            self.allowed.borrow_mut().insert(module_id);
            Ok(())
        } else {
            Err(
                PartialVMError::new(StatusCode::MODULE_ACCESS_DENIED).with_message(format!(
                    "transaction permission table denies {} access to {}",
                    self.sender, module_id
                )),
            )
        }
    }

    fn check_vm(&self, address: &AccountAddress, module_name: &IdentStr) -> VMResult<()> {
        self.check(address, module_name)
            .map_err(|err| err.finish(move_binary_format::errors::Location::Undefined))
    }
}

impl<'a, S: WithRuntimeEnvironment> WithRuntimeEnvironment for PermissionCheckedCodeStorage<'a, S> {
    fn runtime_environment(&self) -> &RuntimeEnvironment {
        self.inner.runtime_environment()
    }
}

impl<'a, S: ModuleStorage> ModuleStorage for PermissionCheckedCodeStorage<'a, S> {
    fn check_module_exists(
        &self,
        address: &AccountAddress,
        module_name: &IdentStr,
    ) -> VMResult<bool> {
        self.check_vm(address, module_name)?;
        self.inner.check_module_exists(address, module_name)
    }

    fn fetch_module_bytes(
        &self,
        address: &AccountAddress,
        module_name: &IdentStr,
    ) -> VMResult<Option<Bytes>> {
        self.check_vm(address, module_name)?;
        self.inner.fetch_module_bytes(address, module_name)
    }

    fn fetch_module_size_in_bytes(
        &self,
        address: &AccountAddress,
        module_name: &IdentStr,
    ) -> VMResult<Option<usize>> {
        self.check_vm(address, module_name)?;
        self.inner.fetch_module_size_in_bytes(address, module_name)
    }

    fn fetch_module_metadata(
        &self,
        address: &AccountAddress,
        module_name: &IdentStr,
    ) -> VMResult<Option<Vec<Metadata>>> {
        self.check_vm(address, module_name)?;
        self.inner.fetch_module_metadata(address, module_name)
    }

    fn fetch_deserialized_module(
        &self,
        address: &AccountAddress,
        module_name: &IdentStr,
    ) -> VMResult<Option<Arc<CompiledModule>>> {
        self.check_vm(address, module_name)?;
        self.inner.fetch_deserialized_module(address, module_name)
    }

    fn fetch_verified_module(
        &self,
        address: &AccountAddress,
        module_name: &IdentStr,
    ) -> VMResult<Option<Arc<Module>>> {
        self.check_vm(address, module_name)?;
        self.inner.fetch_verified_module(address, module_name)
    }

    #[cfg(fuzzing)]
    fn fetch_module_skip_verification(
        &self,
        address: &AccountAddress,
        module_name: &IdentStr,
    ) -> VMResult<Option<Arc<Module>>> {
        self.check_vm(address, module_name)?;
        self.inner
            .fetch_module_skip_verification(address, module_name)
    }
}

impl<'a, S: CodeStorage> CodeStorage for PermissionCheckedCodeStorage<'a, S> {
    // Scripts themselves are not modules; the modules a script uses are
    // checked when the loader fetches them through this wrapper.
    fn deserialize_and_cache_script(
        &self,
        serialized_script: &[u8],
    ) -> VMResult<Arc<move_binary_format::file_format::CompiledScript>> {
        self.inner.deserialize_and_cache_script(serialized_script)
    }

    fn verify_and_cache_script(&self, serialized_script: &[u8]) -> VMResult<Arc<Script>> {
        self.inner.verify_and_cache_script(serialized_script)
    }

    // `load_script` keeps its default implementation: it calls
    // `verify_and_cache_script` and `fetch_ty` on `self`, so type-argument
    // module loads go through this wrapper and are checked.
}

impl<'a, S: AptosModuleStorage> AptosModuleStorage for PermissionCheckedCodeStorage<'a, S> {
    fn fetch_state_value_metadata(
        &self,
        address: &AccountAddress,
        module_name: &IdentStr,
    ) -> PartialVMResult<Option<StateValueMetadata>> {
        self.check(address, module_name)?;
        self.inner.fetch_state_value_metadata(address, module_name)
    }
}

// Copyright (c) The Move Contributors
// SPDX-License-Identifier: Apache-2.0

//! Resource access control has been removed, so access specifiers are rejected regardless of
//! configuration. Only hand-crafted bytecode can still carry them; no compiler emits them.

use move_binary_format::{
    file_format::{
        basic_test_module, empty_script, AccessKind, AccessSpecifier, AddressIdentifierIndex,
        AddressSpecifier, ResourceSpecifier, TableIndex,
    },
    CompiledModule,
};
use move_bytecode_verifier::VerifierConfig;
use move_core_types::{account_address::AccountAddress, vm_status::StatusCode};

/// An access specifier reading any resource declared at the address added to `addresses`.
fn reads_any_at_new_address(addresses: &mut Vec<AccountAddress>) -> AccessSpecifier {
    let addr = AddressIdentifierIndex::new(addresses.len() as TableIndex);
    addresses.push(AccountAddress::ONE);
    AccessSpecifier {
        kind: AccessKind::Reads,
        negated: false,
        resource: ResourceSpecifier::DeclaredAtAddress(addr),
        address: AddressSpecifier::Any,
    }
}

fn module_with_access_specifiers() -> CompiledModule {
    let mut m = basic_test_module();
    let specifier = reads_any_at_new_address(&mut m.address_identifiers);
    m.function_handles[0].access_specifiers = Some(vec![specifier]);
    m
}

#[test]
fn module_access_specifiers_are_rejected() {
    let m = module_with_access_specifiers();
    let err = move_bytecode_verifier::verify_module_with_config(&VerifierConfig::production(), &m)
        .unwrap_err();
    assert_eq!(err.major_status(), StatusCode::FEATURE_NOT_ENABLED);
}

#[test]
fn script_access_specifiers_are_rejected() {
    let mut s = empty_script();
    let specifier = reads_any_at_new_address(&mut s.address_identifiers);
    s.access_specifiers = Some(vec![specifier]);
    let err = move_bytecode_verifier::verify_script_with_config(&VerifierConfig::production(), &s)
        .unwrap_err();
    assert_eq!(err.major_status(), StatusCode::FEATURE_NOT_ENABLED);
}

/// The same module without access specifiers must verify, so that the rejections above are
/// attributable to the specifiers rather than to an unrelated defect in the test fixtures.
#[test]
fn module_without_access_specifiers_is_accepted() {
    let mut m = module_with_access_specifiers();
    m.function_handles[0].access_specifiers = None;
    assert!(
        move_bytecode_verifier::verify_module_with_config(&VerifierConfig::production(), &m)
            .is_ok()
    );
}

#[test]
fn script_without_access_specifiers_is_accepted() {
    let s = empty_script();
    assert!(s.access_specifiers.is_none());
    assert!(
        move_bytecode_verifier::verify_script_with_config(&VerifierConfig::production(), &s)
            .is_ok()
    );
}

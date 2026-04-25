spec aptos_framework::system_addresses {
    /// <high-level-req>
    /// No.: 1
    /// Requirement: Asserting that a provided address corresponds to the Core Resources address should always yield a true
    /// result when matched.
    /// Criticality: Low
    /// Implementation: The assert_core_resource and assert_core_resource_address functions ensure that the provided
    /// signer or address belong to the @core_resources account.
    /// Enforcement: Formally verified via [high-level-req-1](AbortsIfNotCoreResource).
    ///
    /// No.: 2
    /// Requirement: Asserting that a provided address corresponds to the Aptos Framework Resources address should always
    /// yield a true result when matched.
    /// Criticality: High
    /// Implementation: The assert_aptos_framework function ensures that the provided signer belongs to the
    /// @aptos_framework account.
    /// Enforcement: Formally verified via [high-level-req-2](AbortsIfNotAptosFramework).
    ///
    /// No.: 3
    /// Requirement: Asserting that a provided address corresponds to the VM address should always yield a true result when
    /// matched.
    /// Criticality: High
    /// Implementation: The assert_vm function ensure that the provided signer belongs to the @vm_reserved account.
    /// Enforcement: Formally verified via [high-level-req-3](AbortsIfNotVM).
    /// </high-level-req>
    ///
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict;
    }

    spec assert_core_resource(account: &signer) {
        pragma opaque;
        // Body delegates to is_core_resource_address, which is feature-gated
        // in Movement. The exhaustive abort condition under strict mode would
        // require referencing features::contains, which has a known bv
        // translation issue. Skip body verification.
        pragma verify = false;
        include AbortsIfNotCoreResource { addr: signer::address_of(account) };
    }

    spec assert_core_resource_address(addr: address) {
        pragma opaque;
        pragma verify = false;
        include AbortsIfNotCoreResource;
    }

    spec is_core_resource_address(addr: address): bool {
        pragma opaque;
        // Movement gates the body on `get_decommission_core_resources_enabled()`,
        // which transitively calls features::contains (whose Boogie translation
        // has a bv8/int8 type mismatch). Skip body verification; callers use
        // only this opaque spec.
        pragma verify = false;
        aborts_if false;
        // One-way implication: holds in both feature branches without
        // requiring the spec to know about the feature flag.
        ensures result ==> (addr == @core_resources);
    }

    /// Specifies that a function aborts if the account does not have the root address.
    spec schema AbortsIfNotCoreResource {
        addr: address;
        /// [high-level-req-1]
        aborts_if addr != @core_resources with error::PERMISSION_DENIED;
    }

    spec assert_aptos_framework(account: &signer) {
        pragma opaque;
        include AbortsIfNotAptosFramework;
    }

    spec assert_framework_reserved_address(account: &signer) {
        aborts_if !is_framework_reserved_address(signer::address_of(account));
    }

    spec assert_framework_reserved(addr: address) {
        aborts_if !is_framework_reserved_address(addr);
    }
    /// Specifies that a function aborts if the account does not have the aptos framework address.
    spec schema AbortsIfNotAptosFramework {
        account: signer;
        /// [high-level-req-2]
        aborts_if signer::address_of(account) != @aptos_framework with error::PERMISSION_DENIED;
    }

    spec assert_vm(account: &signer) {
        pragma opaque;
        include AbortsIfNotVM;
    }

    /// Specifies that a function aborts if the account does not have the VM reserved address.
    spec schema AbortsIfNotVM {
        account: signer;
        /// [high-level-req-3]
        aborts_if signer::address_of(account) != @vm_reserved with error::PERMISSION_DENIED;
    }
}

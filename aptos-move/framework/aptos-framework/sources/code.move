/// This module supports functionality related to code management.
module aptos_framework::code {
    use std::string::String;
    use std::error;
    use std::signer;
    use std::vector;
    use std::features;

    use aptos_framework::util;
    use aptos_framework::system_addresses;
    use aptos_std::copyable_any::Any;
    use std::option::Option;
    use std::string;
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::permissioned_signer;
    use aptos_framework::allowlist::{Self, Allowlist};
    use aptos_framework::transaction_context;

    friend aptos_framework::object_code_deployment;

    // ----------------------------------------------------------------------
    // Code Publishing

    /// The package registry at the given address.
    struct PackageRegistry has key, store, drop {
        /// Packages installed at this address.
        packages: vector<PackageMetadata>,
    }

    /// Metadata for a package. All byte blobs are represented as base64-of-gzipped-bytes
    struct PackageMetadata has copy, drop, store {
        /// Name of this package.
        name: String,
        /// The upgrade policy of this package.
        upgrade_policy: UpgradePolicy,
        /// The numbers of times this module has been upgraded. Also serves as the on-chain version.
        /// This field will be automatically assigned on successful upgrade.
        upgrade_number: u64,
        /// The source digest of the sources in the package. This is constructed by first building the
        /// sha256 of each individual source, than sorting them alphabetically, and sha256 them again.
        source_digest: String,
        /// The package manifest, in the Move.toml format. Gzipped text.
        manifest: vector<u8>,
        /// The list of modules installed by this package.
        modules: vector<ModuleMetadata>,
        /// Holds PackageDeps.
        deps: vector<PackageDep>,
        /// For future extension
        extension: Option<Any>
    }

    /// A dependency to a package published at address
    struct PackageDep has store, drop, copy {
        account: address,
        package_name: String
    }

    /// Metadata about a module in a package.
    struct ModuleMetadata has copy, drop, store {
        /// Name of the module.
        name: String,
        /// Source text, gzipped String. Empty if not provided.
        source: vector<u8>,
        /// Source map, in compressed BCS. Empty if not provided.
        source_map: vector<u8>,
        /// For future extensions.
        extension: Option<Any>,
    }

    /// Describes an upgrade policy
    struct UpgradePolicy has store, copy, drop {
        policy: u8
    }

    #[event]
    /// Event emitted when code is published to an address.
    struct PublishPackage has drop, store {
        code_address: address,
        is_upgrade: bool,
    }

    /// Package contains duplicate module names with existing modules publised in other packages on this address
    const EMODULE_NAME_CLASH: u64 = 0x1;

    /// Cannot upgrade an immutable package
    const EUPGRADE_IMMUTABLE: u64 = 0x2;

    /// Cannot downgrade a package's upgradability policy
    const EUPGRADE_WEAKER_POLICY: u64 = 0x3;

    /// Cannot delete a module that was published in the same package
    const EMODULE_MISSING: u64 = 0x4;

    /// Dependency could not be resolved to any published package.
    const EPACKAGE_DEP_MISSING: u64 = 0x5;

    /// A dependency cannot have a weaker upgrade policy.
    const EDEP_WEAKER_POLICY: u64 = 0x6;

    /// A dependency to an `arbitrary` package must be on the same address.
    const EDEP_ARBITRARY_NOT_SAME_ADDRESS: u64 = 0x7;

    /// Creating a package with incompatible upgrade policy is disabled.
    const EINCOMPATIBLE_POLICY_DISABLED: u64 = 0x8;

    /// Not the owner of the package registry.
    const ENOT_PACKAGE_OWNER: u64 = 0x9;

    /// `code_object` does not exist.
    const ECODE_OBJECT_DOES_NOT_EXIST: u64 = 0xA;

    /// Current permissioned signer cannot publish codes.
    const ENO_CODE_PERMISSION: u64 = 0xB;

    /// The primary transaction sender is not approved for publishing.
    const EPUBLISHING_NOT_ALLOWED: u64 = 0xC;
    /// Publishing allowlist administration requires initialization.
    const EPUBLISH_ALLOWLIST_NOT_INITIALIZED: u64 = 0xD;

    struct CodePublishingPermission has copy, drop, store {}

    struct PublishAllowlist has key {
        allowlist: Allowlist,
    }

    #[event]
    struct PublishAllowlistEnabledChanged has drop, store {
        enabled: bool,
    }

    #[event]
    struct PublishAllowedSenderChanged has drop, store {
        sender: address,
        allowed: bool,
    }

    public entry fun initialize_publish_allowlist(framework: &signer) {
        system_addresses::assert_aptos_framework(framework);
        if (!exists<PublishAllowlist>(@aptos_framework)) {
            move_to(framework, PublishAllowlist { allowlist: allowlist::new() });
        };
    }

    public entry fun enable_publish_allowlist(framework: &signer) acquires PublishAllowlist {
        system_addresses::assert_aptos_framework(framework);
        assert!(exists<PublishAllowlist>(@aptos_framework), error::not_found(EPUBLISH_ALLOWLIST_NOT_INITIALIZED));
        let list = &mut borrow_global_mut<PublishAllowlist>(@aptos_framework).allowlist;
        if (allowlist::enable(list)) {
            event::emit(PublishAllowlistEnabledChanged { enabled: true });
        };
    }

    public entry fun disable_publish_allowlist(framework: &signer) acquires PublishAllowlist {
        system_addresses::assert_aptos_framework(framework);
        assert!(exists<PublishAllowlist>(@aptos_framework), error::not_found(EPUBLISH_ALLOWLIST_NOT_INITIALIZED));
        let list = &mut borrow_global_mut<PublishAllowlist>(@aptos_framework).allowlist;
        if (allowlist::disable(list)) {
            event::emit(PublishAllowlistEnabledChanged { enabled: false });
        };
    }

    public entry fun add_publish_allowlist_sender(
        framework: &signer, sender: address
    ) acquires PublishAllowlist {
        system_addresses::assert_aptos_framework(framework);
        assert!(exists<PublishAllowlist>(@aptos_framework), error::not_found(EPUBLISH_ALLOWLIST_NOT_INITIALIZED));
        let list = &mut borrow_global_mut<PublishAllowlist>(@aptos_framework).allowlist;
        if (allowlist::add(list, sender)) {
            event::emit(PublishAllowedSenderChanged { sender, allowed: true });
        };
    }

    public entry fun remove_publish_allowlist_sender(
        framework: &signer, sender: address
    ) acquires PublishAllowlist {
        system_addresses::assert_aptos_framework(framework);
        assert!(exists<PublishAllowlist>(@aptos_framework), error::not_found(EPUBLISH_ALLOWLIST_NOT_INITIALIZED));
        let list = &mut borrow_global_mut<PublishAllowlist>(@aptos_framework).allowlist;
        if (allowlist::remove(list, sender)) {
            event::emit(PublishAllowedSenderChanged { sender, allowed: false });
        };
    }

    #[view]
    public fun is_publish_allowlist_enabled(): bool acquires PublishAllowlist {
        exists<PublishAllowlist>(@aptos_framework)
            && allowlist::is_enabled(&PublishAllowlist[@aptos_framework].allowlist)
    }

    /// Returns configured membership, regardless of whether publishing enforcement is enabled.
    #[view]
    public fun is_publish_allowlisted(sender: address): bool acquires PublishAllowlist {
        exists<PublishAllowlist>(@aptos_framework)
            && allowlist::is_allowed(&PublishAllowlist[@aptos_framework].allowlist, sender)
    }

    #[view]
    public fun get_publish_allowed_senders(): vector<address> acquires PublishAllowlist {
        if (exists<PublishAllowlist>(@aptos_framework)) {
            allowlist::get_allowed_senders(&PublishAllowlist[@aptos_framework].allowlist)
        } else {
            vector[]
        }
    }

    #[test]
    fun test_publish_allowlist_defaults_disabled() acquires PublishAllowlist {
        assert!(!is_publish_allowlist_enabled(), 0);
        assert!(!is_publish_allowlisted(@0xcafe), 1);
        assert!(get_publish_allowed_senders().is_empty(), 2);
    }

    #[test(framework = @aptos_framework)]
    fun test_publish_allowlist_initialize_preserves_state(framework: signer) acquires PublishAllowlist {
        initialize_publish_allowlist(&framework);
        add_publish_allowlist_sender(&framework, @0xcafe);
        enable_publish_allowlist(&framework);
        initialize_publish_allowlist(&framework);
        assert!(is_publish_allowlist_enabled(), 0);
        assert!(is_publish_allowlisted(@0xcafe), 1);
        assert!(get_publish_allowed_senders().length() == 1, 2);
    }

    #[test(framework = @aptos_framework)]
    fun test_enabled_empty_publish_allowlist(framework: signer) acquires PublishAllowlist {
        initialize_publish_allowlist(&framework);
        enable_publish_allowlist(&framework);
        assert!(is_publish_allowlist_enabled(), 0);
        assert!(!is_publish_allowlisted(@0xcafe), 1);
    }

    #[test(attacker = @0xcafe)]
    #[expected_failure(abort_code = 0x50003, location = aptos_framework::system_addresses)]
    fun test_publish_allowlist_admin_requires_framework(attacker: signer) {
        initialize_publish_allowlist(&attacker);
    }

    /// Permissions
    public(friend) fun check_code_publishing_permission(s: &signer) {
        assert!(
            permissioned_signer::check_permission_exists(s, CodePublishingPermission {}),
            error::permission_denied(ENO_CODE_PERMISSION),
        );
    }

    /// Grant permission to publish code on behalf of the master signer.
    public fun grant_permission(master: &signer, permissioned_signer: &signer) {
        permissioned_signer::authorize_unlimited(master, permissioned_signer, CodePublishingPermission {})
    }

    /// Whether unconditional code upgrade with no compatibility check is allowed. This
    /// publication mode should only be used for modules which aren't shared with user others.
    /// The developer is responsible for not breaking memory layout of any resources he already
    /// stored on chain.
    public fun upgrade_policy_arbitrary(): UpgradePolicy {
        UpgradePolicy { policy: 0 }
    }

    /// Whether a compatibility check should be performed for upgrades. The check only passes if
    /// a new module has (a) the same public functions (b) for existing resources, no layout change.
    public fun upgrade_policy_compat(): UpgradePolicy {
        UpgradePolicy { policy: 1 }
    }

    /// Whether the modules in the package are immutable and cannot be upgraded.
    public fun upgrade_policy_immutable(): UpgradePolicy {
        UpgradePolicy { policy: 2 }
    }

    /// Whether the upgrade policy can be changed. In general, the policy can be only
    /// strengthened but not weakened.
    public fun can_change_upgrade_policy_to(from: UpgradePolicy, to: UpgradePolicy): bool {
        from.policy <= to.policy
    }

    /// Initialize package metadata for Genesis.
    fun initialize(aptos_framework: &signer, package_owner: &signer, metadata: PackageMetadata)
    acquires PackageRegistry {
        system_addresses::assert_aptos_framework(aptos_framework);
        let addr = signer::address_of(package_owner);
        if (!exists<PackageRegistry>(addr)) {
            move_to(package_owner, PackageRegistry { packages: vector[metadata] })
        } else {
            vector::push_back(&mut borrow_global_mut<PackageRegistry>(addr).packages, metadata)
        }
    }

    /// Publishes a package at the given signer's address. The caller must provide package metadata describing the
    /// package.
    public fun publish_package(owner: &signer, pack: PackageMetadata, code: vector<vector<u8>>) acquires PackageRegistry, PublishAllowlist {
        if (is_publish_allowlist_enabled()) {
            assert!(
                is_publish_allowlisted(transaction_context::sender_internal()),
                error::permission_denied(EPUBLISHING_NOT_ALLOWED),
            );
        };
        check_code_publishing_permission(owner);
        // Disallow incompatible upgrade mode. Governance can decide later if this should be reconsidered.
        assert!(
            pack.upgrade_policy.policy > upgrade_policy_arbitrary().policy,
            error::invalid_argument(EINCOMPATIBLE_POLICY_DISABLED),
        );

        let addr = signer::address_of(owner);
        if (!exists<PackageRegistry>(addr)) {
            move_to(owner, PackageRegistry { packages: vector::empty() })
        };

        // Checks for valid dependencies to other packages
        let allowed_deps = check_dependencies(addr, &pack);

        // Check package against conflicts
        // To avoid prover compiler error on spec
        // the package need to be an immutable variable
        let module_names = get_module_names(&pack);
        let package_immutable = &borrow_global<PackageRegistry>(addr).packages;
        let len = vector::length(package_immutable);
        let index = len;
        let upgrade_number = 0;
        vector::enumerate_ref(package_immutable
        , |i, old| {
            let old: &PackageMetadata = old;
            if (old.name == pack.name) {
                upgrade_number = old.upgrade_number + 1;
                check_upgradability(old, &pack, &module_names);
                index = i;
            } else {
                check_coexistence(old, &module_names)
            };
        });

        // Assign the upgrade counter.
        pack.upgrade_number = upgrade_number;

        let packages = &mut borrow_global_mut<PackageRegistry>(addr).packages;
        // Update registry
        let policy = pack.upgrade_policy;
        if (index < len) {
            *vector::borrow_mut(packages, index) = pack
        } else {
            vector::push_back(packages, pack)
        };

        event::emit(PublishPackage {
            code_address: addr,
            is_upgrade: upgrade_number > 0
        });

        // Request publish
        if (features::code_dependency_check_enabled())
            request_publish_with_allowed_deps(addr, module_names, allowed_deps, code, policy.policy)
        else
        // The new `request_publish_with_allowed_deps` has not yet rolled out, so call downwards
        // compatible code.
            request_publish(addr, module_names, code, policy.policy)
    }

    public fun freeze_code_object(publisher: &signer, code_object: Object<PackageRegistry>) acquires PackageRegistry {
        check_code_publishing_permission(publisher);
        let code_object_addr = object::object_address(&code_object);
        assert!(exists<PackageRegistry>(code_object_addr), error::not_found(ECODE_OBJECT_DOES_NOT_EXIST));
        assert!(
            object::is_owner(code_object, signer::address_of(publisher)),
            error::permission_denied(ENOT_PACKAGE_OWNER)
        );

        let registry = borrow_global_mut<PackageRegistry>(code_object_addr);
        vector::for_each_mut(&mut registry.packages, |pack| {
            let package: &mut PackageMetadata = pack;
            package.upgrade_policy = upgrade_policy_immutable();
        });

        // We unfortunately have to make a copy of each package to avoid borrow checker issues as check_dependencies
        // needs to borrow PackageRegistry from the dependency packages.
        // This would increase the amount of gas used, but this is a rare operation and it's rare to have many packages
        // in a single code object.
        vector::for_each(registry.packages, |pack| {
            check_dependencies(code_object_addr, &pack);
        });
    }

    /// Same as `publish_package` but as an entry function which can be called as a transaction. Because
    /// of current restrictions for txn parameters, the metadata needs to be passed in serialized form.
    public entry fun publish_package_txn(owner: &signer, metadata_serialized: vector<u8>, code: vector<vector<u8>>)
    acquires PackageRegistry, PublishAllowlist {
        publish_package(owner, util::from_bytes<PackageMetadata>(metadata_serialized), code)
    }

    // Helpers
    // -------

    /// Checks whether the given package is upgradable, and returns true if a compatibility check is needed.
    fun check_upgradability(
        old_pack: &PackageMetadata, new_pack: &PackageMetadata, new_modules: &vector<String>) {
        assert!(old_pack.upgrade_policy.policy < upgrade_policy_immutable().policy,
            error::invalid_argument(EUPGRADE_IMMUTABLE));
        assert!(can_change_upgrade_policy_to(old_pack.upgrade_policy, new_pack.upgrade_policy),
            error::invalid_argument(EUPGRADE_WEAKER_POLICY));
        let old_modules = get_module_names(old_pack);

        vector::for_each_ref(&old_modules, |old_module| {
            assert!(
                vector::contains(new_modules, old_module),
                EMODULE_MISSING
            );
        });
    }

    /// Checks whether a new package with given names can co-exist with old package.
    fun check_coexistence(old_pack: &PackageMetadata, new_modules: &vector<String>) {
        // The modules introduced by each package must not overlap with `names`.
        vector::for_each_ref(&old_pack.modules, |old_mod| {
            let old_mod: &ModuleMetadata = old_mod;
            let j = 0;
            while (j < vector::length(new_modules)) {
                let name = vector::borrow(new_modules, j);
                assert!(&old_mod.name != name, error::already_exists(EMODULE_NAME_CLASH));
                j = j + 1;
            };
        });
    }

    /// Check that the upgrade policies of all packages are equal or higher quality than this package. Also
    /// compute the list of module dependencies which are allowed by the package metadata. The later
    /// is passed on to the native layer to verify that bytecode dependencies are actually what is pretended here.
    fun check_dependencies(publish_address: address, pack: &PackageMetadata): vector<AllowedDep>
    acquires PackageRegistry {
        let allowed_module_deps = vector::empty();
        let deps = &pack.deps;
        vector::for_each_ref(deps, |dep| {
            let dep: &PackageDep = dep;
            assert!(exists<PackageRegistry>(dep.account), error::not_found(EPACKAGE_DEP_MISSING));
            if (is_policy_exempted_address(dep.account)) {
                // Allow all modules from this address, by using "" as a wildcard in the AllowedDep
                let account: address = dep.account;
                let module_name = string::utf8(b"");
                vector::push_back(&mut allowed_module_deps, AllowedDep { account, module_name });
            } else {
                let registry = borrow_global<PackageRegistry>(dep.account);
                let found = vector::any(&registry.packages, |dep_pack| {
                    let dep_pack: &PackageMetadata = dep_pack;
                    if (dep_pack.name == dep.package_name) {
                        // Check policy
                        assert!(
                            dep_pack.upgrade_policy.policy >= pack.upgrade_policy.policy,
                            error::invalid_argument(EDEP_WEAKER_POLICY)
                        );
                        if (dep_pack.upgrade_policy == upgrade_policy_arbitrary()) {
                            assert!(
                                dep.account == publish_address,
                                error::invalid_argument(EDEP_ARBITRARY_NOT_SAME_ADDRESS)
                            )
                        };
                        // Add allowed deps
                        let account = dep.account;
                        let k = 0;
                        let r = vector::length(&dep_pack.modules);
                        while (k < r) {
                            let module_name = vector::borrow(&dep_pack.modules, k).name;
                            vector::push_back(&mut allowed_module_deps, AllowedDep { account, module_name });
                            k = k + 1;
                        };
                        true
                    } else {
                        false
                    }
                });
                assert!(found, error::not_found(EPACKAGE_DEP_MISSING));
            };
        });
        allowed_module_deps
    }

    /// Core addresses which are exempted from the check that their policy matches the referring package. Without
    /// this exemption, it would not be possible to define an immutable package based on the core system, which
    /// requires to be upgradable for maintenance and evolution, and is configured to be `compatible`.
    fun is_policy_exempted_address(addr: address): bool {
        addr == @1 || addr == @2 || addr == @3 || addr == @4 || addr == @5 ||
            addr == @6 || addr == @7 || addr == @8 || addr == @9 || addr == @10
    }

    /// Get the names of the modules in a package.
    fun get_module_names(pack: &PackageMetadata): vector<String> {
        let module_names = vector::empty();
        vector::for_each_ref(&pack.modules, |pack_module| {
            let pack_module: &ModuleMetadata = pack_module;
            vector::push_back(&mut module_names, pack_module.name);
        });
        module_names
    }

    /// Native function to initiate module loading
    native fun request_publish(
        owner: address,
        expected_modules: vector<String>,
        bundle: vector<vector<u8>>,
        policy: u8
    );

    /// A helper type for request_publish_with_allowed_deps
    struct AllowedDep has drop {
        /// Address of the module.
        account: address,
        /// Name of the module. If this is the empty string, then this serves as a wildcard for
        /// all modules from this address. This is used for speeding up dependency checking for packages from
        /// well-known framework addresses, where we can assume that there are no malicious packages.
        module_name: String
    }

    /// Native function to initiate module loading, including a list of allowed dependencies.
    native fun request_publish_with_allowed_deps(
        owner: address,
        expected_modules: vector<String>,
        allowed_deps: vector<AllowedDep>,
        bundle: vector<vector<u8>>,
        policy: u8
    );
}

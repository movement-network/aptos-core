// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

use aptos_framework::{BuildOptions, BuiltPackage};
use aptos_package_builder::PackageBuilder;
use std::path::Path;

#[test]
fn publish_allowlist_migration_scripts_compile() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let framework = root.join("../framework/aptos-framework");
    let scripts = root.join("../../movement-migration/governance");
    for name in [
        "initialize_publish_allowlist.move",
        "add_publish_allowlist_sender.move",
        "remove_publish_allowlist_sender.move",
        "enable_publish_allowlist.move",
        "disable_publish_allowlist.move",
        "disable_publish_allowlist_by_proposal.move",
    ] {
        let mut builder = PackageBuilder::new("MigrationScript");
        builder.add_local_dep("AptosFramework", framework.to_str().unwrap());
        builder.add_source(name, &std::fs::read_to_string(scripts.join(name)).unwrap());
        let path = builder.write_to_temp().unwrap();
        let package = BuiltPackage::build(path.path().to_owned(), BuildOptions::default())
            .unwrap_or_else(|error| panic!("{name}: {error}"));
        assert_eq!(package.extract_script_code().len(), 1);
    }
}

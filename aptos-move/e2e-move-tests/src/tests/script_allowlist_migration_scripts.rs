// Copyright © Move Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{assert_success, MoveHarness};
use aptos_framework::{BuildOptions, BuiltPackage};
use aptos_package_builder::PackageBuilder;
use aptos_types::{
    account_address::AccountAddress,
    account_config::aptos_test_root_address,
    transaction::{ExecutionStatus, TransactionStatus},
};
use move_core_types::vm_status::AbortLocation;
use std::path::Path;

#[test]
fn script_allowlist_migration_scripts_compile() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let framework = root.join("../framework/aptos-framework");
    let scripts = root.join("../../movement-migration/script-execution-allowlist/scripts");
    for name in [
        "initialize.move",
        "add.move",
        "remove.move",
        "enable.move",
        "disable.move",
        "disable_by_proposal.move",
    ] {
        let mut builder = PackageBuilder::new("MigrationScript");
        builder.add_local_dep("AptosFramework", framework.to_str().unwrap());
        builder.add_source(name, &std::fs::read_to_string(scripts.join(name)).unwrap());
        let path = builder.write_to_temp().unwrap();
        let package = BuiltPackage::build(path.path().to_owned(), BuildOptions::default())
            .unwrap_or_else(|error| panic!("{name}: {error}"));
        let scripts = package.extract_script_code();
        assert_eq!(scripts.len(), 1);
        if name == "enable.move" {
            let mut h = MoveHarness::new();
            let core = h.new_account_at(aptos_test_root_address());
            let framework = h.aptos_framework_account();
            assert_success!(h.run_entry_function(
                &framework,
                "0x1::script_execution_allowlist::initialize"
                    .parse()
                    .unwrap(),
                vec![],
                vec![],
            ));
            let tx = h.create_script(&core, scripts[0].clone(), vec![], vec![]);
            assert!(matches!(
                h.run(tx),
                TransactionStatus::Keep(ExecutionStatus::MoveAbort {
                    location: AbortLocation::Script,
                    code: 2,
                    ..
                })
            ));
            assert_success!(h.run_entry_function(
                &framework,
                "0x1::script_execution_allowlist::add".parse().unwrap(),
                vec![],
                vec![bcs::to_bytes(core.address()).unwrap()],
            ));
            // Only core is listed: neither a recovery sender nor 0x1 is needed.
            // The second call also proves core can administer after activation.
            for _ in 0..2 {
                let tx = h.create_script(&core, scripts[0].clone(), vec![], vec![]);
                assert_success!(h.run(tx));
            }
            let result = h.execute_view_function(
                "0x1::script_execution_allowlist::get_allowed_senders"
                    .parse()
                    .unwrap(),
                vec![],
                vec![],
            );
            assert_eq!(
                bcs::from_bytes::<Vec<AccountAddress>>(&result.values.unwrap()[0]).unwrap(),
                vec![*core.address()],
            );
            let result = h.execute_view_function(
                "0x1::script_execution_allowlist::is_enabled"
                    .parse()
                    .unwrap(),
                vec![],
                vec![],
            );
            assert!(bcs::from_bytes::<bool>(&result.values.unwrap()[0]).unwrap());
        }
    }
}

//! `borrow_global` + on-chain resource at `@std` (`0x1`), without FA (see `confidential_asset` e2e for FA).

use anyhow::{Context, Result};
use move_core_types::{identifier::Identifier, language_storage::StructTag};
use move_vm_test_utils::InMemoryStorage;
use serde::Serialize;
use std::path::Path;

use crate::compiler::compile_with_aptos_head_bundle_extras;
use crate::schema::TestCase;
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_global_smoke";

const EXTRA_MOVE: &[&str] = &[concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/move/difftest_global_smoke.move"
)];

const TEST_SOURCE: &str = r#"
module 0x1::difftest_global_smoke_tests {
    public fun test_read_std_counter(): u64 {
        0x1::difftest_global_smoke::read_std_counter()
    }
}
"#;

/// BCS layout for `0x1::difftest_global_smoke::Counter { n: u64 }` (single field).
#[derive(Serialize)]
struct CounterResource {
    n: u64,
}

const COUNTER_MAGIC: u64 = 12_345;

pub struct GlobalResourceSmokeSuite;

impl DiffTestSuite for GlobalResourceSmokeSuite {
    fn id(&self) -> &'static str {
        "global_resource_smoke"
    }

    fn name(&self) -> &str {
        "0x1::difftest_global_smoke (borrow_global)"
    }

    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()> {
        let paths: Vec<&Path> = EXTRA_MOVE.iter().map(Path::new).collect();
        let modules = compile_with_aptos_head_bundle_extras(TEST_SOURCE, &paths)?;
        for module in &modules {
            let blob = module_blob(module)?;
            storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
        }

        let tag = StructTag {
            address: STD_ADDR,
            module: Identifier::new(MODULE_NAME)?,
            name: Identifier::new("Counter")?,
            type_args: vec![],
        };
        let blob = bcs::to_bytes(&CounterResource { n: COUNTER_MAGIC })
            .context("BCS serialize Counter")?;
        storage.publish_or_overwrite_resource(STD_ADDR, tag, blob);
        Ok(())
    }

    fn generate_test_cases(&self, storage: &mut InMemoryStorage) -> Result<Vec<TestCase>> {
        let result = run_test_case(
            storage,
            STD_ADDR,
            "difftest_global_smoke_tests",
            "test_read_std_counter",
            &[],
        )?;
        Ok(vec![TestCase {
            function: "test_read_std_counter [borrow_global]".into(),
            type_args: None,
            args: vec![],
            result,
            // VM-only: Lean `realModuleEnv` does not embed this harness module; CA-free branch
            // keeps VM↔Lean parity for stdlib catalogs without modeling arbitrary `borrow_global`.
            skip_lean: true,
        }])
    }
}

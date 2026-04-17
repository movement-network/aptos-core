use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::typed_value::make_u64;
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_error";

/// Matches `aptos-move/framework/move-stdlib/sources/error.move` public API (no `cancelled(r)` wrapper).
const TEST_SOURCE: &str = r#"
    module 0x1::difftest_error {
        use std::error;

        public fun test_error_canonical(category: u64, reason: u64): u64 {
            error::canonical(category, reason)
        }

        public fun test_error_invalid_argument(r: u64): u64 {
            error::invalid_argument(r)
        }

        public fun test_error_out_of_range(r: u64): u64 {
            error::out_of_range(r)
        }

        public fun test_error_invalid_state(r: u64): u64 {
            error::invalid_state(r)
        }

        public fun test_error_unauthenticated(r: u64): u64 {
            error::unauthenticated(r)
        }

        public fun test_error_permission_denied(r: u64): u64 {
            error::permission_denied(r)
        }

        public fun test_error_not_found(r: u64): u64 {
            error::not_found(r)
        }

        public fun test_error_aborted(r: u64): u64 {
            error::aborted(r)
        }

        public fun test_error_already_exists(r: u64): u64 {
            error::already_exists(r)
        }

        public fun test_error_resource_exhausted(r: u64): u64 {
            error::resource_exhausted(r)
        }

        public fun test_error_internal(r: u64): u64 {
            error::internal(r)
        }

        public fun test_error_not_implemented(r: u64): u64 {
            error::not_implemented(r)
        }

        public fun test_error_unavailable(r: u64): u64 {
            error::unavailable(r)
        }
    }
"#;

pub struct ErrorSuite;

impl DiffTestSuite for ErrorSuite {
    fn id(&self) -> &'static str {
        "error"
    }

    fn name(&self) -> &str {
        "0x1::difftest_error"
    }

    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()> {
        let modules = compile_with_aptos_head_bundle(TEST_SOURCE)?;
        for module in &modules {
            let blob = module_blob(module)?;
            storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
        }
        Ok(())
    }

    fn generate_test_cases(&self, storage: &mut InMemoryStorage) -> Result<Vec<TestCase>> {
        let mut cases = Vec::new();

        // (category, reason) for canonical — small values stay in 16-bit reason layout.
        let canonical_cases: Vec<((u64, u64), &str)> = vec![
            ((1, 0), "cat1_r0"),
            ((2, 42), "cat2_r42"),
            ((0xD, 0xFFFF), "catD_rFFFF"),
        ];
        for ((cat, reason), label) in canonical_cases {
            let args = vec![make_u64(cat), make_u64(reason)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_error_canonical",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_error_canonical [{}]", label),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let wrappers: Vec<(&str, u64, &str)> = vec![
            ("test_error_invalid_argument", 7, "r7"),
            ("test_error_out_of_range", 1, "r1"),
            ("test_error_invalid_state", 99, "r99"),
            ("test_error_unauthenticated", 0, "r0"),
            ("test_error_permission_denied", 3, "r3"),
            ("test_error_not_found", 100, "r100"),
            ("test_error_aborted", 8, "r8"),
            ("test_error_already_exists", 2, "r2"),
            ("test_error_resource_exhausted", 0x1234, "r1234"),
            ("test_error_internal", 5, "r5"),
            ("test_error_not_implemented", 0, "r0b"),
            ("test_error_unavailable", 77, "r77"),
        ];

        for (fname, r, label) in wrappers {
            let args = vec![make_u64(r)];
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, fname, &args)?;
            cases.push(TestCase {
                function: format!("{} [{}]", fname, label),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        Ok(cases)
    }
}

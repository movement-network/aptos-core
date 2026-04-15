use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::typed_value::{make_bool, make_u128_str, make_u64, make_u8};
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_bcs";

const TEST_SOURCE: &str = r#"
    module 0x1::difftest_bcs {
        use std::bcs;

        public fun test_bcs_u8(x: u8): vector<u8> {
            bcs::to_bytes(&x)
        }

        public fun test_bcs_u64(x: u64): vector<u8> {
            bcs::to_bytes(&x)
        }

        public fun test_bcs_u128(x: u128): vector<u8> {
            bcs::to_bytes(&x)
        }

        public fun test_bcs_bool(b: bool): vector<u8> {
            bcs::to_bytes(&b)
        }
    }
"#;

pub struct BcsSuite;

impl DiffTestSuite for BcsSuite {
    fn id(&self) -> &'static str {
        "bcs"
    }

    fn name(&self) -> &str {
        "0x1::difftest_bcs"
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

        for (label, arg) in [
            ("zero", make_u8(0)),
            ("max", make_u8(255)),
            ("ascii_A", make_u8(65)),
        ] {
            push_case(storage, &mut cases, "test_bcs_u8", label, vec![arg])?;
        }

        for (label, arg) in [
            ("zero", make_u64(0)),
            ("small", make_u64(42)),
            ("large", make_u64(0xdeadbeefcafe)),
        ] {
            push_case(storage, &mut cases, "test_bcs_u64", label, vec![arg])?;
        }

        for (label, s) in [
            ("zero", "0"),
            ("one", "1"),
            ("large", "12345678901234567890"),
        ] {
            push_case(
                storage,
                &mut cases,
                "test_bcs_u128",
                label,
                vec![make_u128_str(s)],
            )?;
        }

        for (label, arg) in [("false", make_bool(false)), ("true", make_bool(true))] {
            push_case(storage, &mut cases, "test_bcs_bool", label, vec![arg])?;
        }

        Ok(cases)
    }
}

fn push_case(
    storage: &mut InMemoryStorage,
    cases: &mut Vec<TestCase>,
    function: &str,
    label: &str,
    args: Vec<crate::schema::TypedValue>,
) -> Result<()> {
    let result = run_test_case(storage, STD_ADDR, MODULE_NAME, function, &args)?;
    cases.push(TestCase {
        function: format!("{} [{}]", function, label),
        type_args: None,
        args,
        result,
        skip_lean: false,
    });
    Ok(())
}

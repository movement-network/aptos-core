use anyhow::{Context, Result};
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::{TestCase, TestResult, TypedValue};
use crate::typed_value::make_address_hex;
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_acl";

const TEST_SOURCE: &str = r#"
    module 0x1::difftest_acl {
        use std::acl;

        public fun test_acl_empty(): acl::ACL {
            acl::empty()
        }

        public fun test_acl_contains(a: acl::ACL, addr: address): bool {
            acl::contains(&a, addr)
        }

        public fun test_acl_add(a: acl::ACL, addr: address): acl::ACL {
            let x = a;
            acl::add(&mut x, addr);
            x
        }

        public fun test_acl_remove(a: acl::ACL, addr: address): acl::ACL {
            let x = a;
            acl::remove(&mut x, addr);
            x
        }

        public fun test_acl_assert_contains(a: acl::ACL, addr: address) {
            acl::assert_contains(&a, addr);
        }
    }
"#;

pub struct AclSuite;

fn first_returned_clone(res: &TestResult) -> Result<TypedValue> {
    match res {
        TestResult::Returned { values } => values.first().cloned().context("empty return values"),
        TestResult::Aborted { .. } => anyhow::bail!("aborted"),
    }
}

impl DiffTestSuite for AclSuite {
    fn id(&self) -> &'static str {
        "acl"
    }

    fn name(&self) -> &'static str {
        "0x1::difftest_acl"
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

        let empty_res = run_test_case(storage, STD_ADDR, MODULE_NAME, "test_acl_empty", &[])?;
        let empty_acl = first_returned_clone(&empty_res)?;
        cases.push(TestCase {
            function: "test_acl_empty [oracle]".into(),
            type_args: None,
            args: vec![],
            result: empty_res,
            skip_lean: false,
        });

        let a1 = "0x1";
        let a2 = "0x42";
        let a3 = "0x00000000000000000000000000000000000000000000000000000000000000ab";
        let a4 = "0x00000000000000000000000000000000000000000000000000000000000000cd";

        for (label, addr) in [("empty_not_a1", a1), ("empty_not_a2", a2)] {
            let args = vec![empty_acl.clone(), make_address_hex(addr)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_acl_contains",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_acl_contains [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let one_res = run_test_case(
            storage,
            STD_ADDR,
            MODULE_NAME,
            "test_acl_add",
            &[empty_acl.clone(), make_address_hex(a1)],
        )?;
        let one_acl = first_returned_clone(&one_res)?;
        cases.push(TestCase {
            function: "test_acl_add [first]".into(),
            type_args: None,
            args: vec![empty_acl.clone(), make_address_hex(a1)],
            result: one_res,
            skip_lean: false,
        });

        for (label, addr) in [("one_has_a1", a1), ("one_not_a2", a2)] {
            let args = vec![one_acl.clone(), make_address_hex(addr)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_acl_contains",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_acl_contains [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let two_res = run_test_case(
            storage,
            STD_ADDR,
            MODULE_NAME,
            "test_acl_add",
            &[one_acl.clone(), make_address_hex(a2)],
        )?;
        let two_acl = first_returned_clone(&two_res)?;
        cases.push(TestCase {
            function: "test_acl_add [second_on_one]".into(),
            type_args: None,
            args: vec![one_acl.clone(), make_address_hex(a2)],
            result: two_res,
            skip_lean: false,
        });

        let after_rm1 = run_test_case(
            storage,
            STD_ADDR,
            MODULE_NAME,
            "test_acl_remove",
            &[two_acl.clone(), make_address_hex(a1)],
        )?;
        let after_rm1_acl = first_returned_clone(&after_rm1)?;
        cases.push(TestCase {
            function: "test_acl_remove [drop_first_of_two]".into(),
            type_args: None,
            args: vec![two_acl.clone(), make_address_hex(a1)],
            result: after_rm1,
            skip_lean: false,
        });

        let after_rm2 = run_test_case(
            storage,
            STD_ADDR,
            MODULE_NAME,
            "test_acl_remove",
            &[after_rm1_acl.clone(), make_address_hex(a2)],
        )?;
        cases.push(TestCase {
            function: "test_acl_remove [drop_remaining]".into(),
            type_args: None,
            args: vec![after_rm1_acl, make_address_hex(a2)],
            result: after_rm2,
            skip_lean: false,
        });

        let base_a3_res = run_test_case(
            storage,
            STD_ADDR,
            MODULE_NAME,
            "test_acl_add",
            &[empty_acl.clone(), make_address_hex(a3)],
        )?;
        let base_a3 = first_returned_clone(&base_a3_res)?;
        let pair_res = run_test_case(
            storage,
            STD_ADDR,
            MODULE_NAME,
            "test_acl_add",
            &[base_a3.clone(), make_address_hex(a4)],
        )?;
        let pair_acl = first_returned_clone(&pair_res)?;
        cases.push(TestCase {
            function: "test_acl_add [pair_a3_a4]".into(),
            type_args: None,
            args: vec![base_a3, make_address_hex(a4)],
            result: pair_res,
            skip_lean: false,
        });

        for (label, addr) in [("member_cd", a4), ("member_ab", a3)] {
            let args = vec![pair_acl.clone(), make_address_hex(addr)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_acl_assert_contains",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_acl_assert_contains [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        Ok(cases)
    }
}

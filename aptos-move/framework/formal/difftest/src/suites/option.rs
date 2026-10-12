use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::typed_value::{make_bool, make_u64, make_u64_vec};
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_option";

const TEST_SOURCE: &str = r#"
    module 0x1::difftest_option {
        use std::option;

        fun mk(is_some: bool, inner: u64): option::Option<u64> {
            if (is_some) {
                option::some(inner)
            } else {
                option::none()
            }
        }

        public fun test_option_is_none(is_some: bool, inner: u64): bool {
            let o = mk(is_some, inner);
            option::is_none(&o)
        }

        public fun test_option_is_some(is_some: bool, inner: u64): bool {
            let o = mk(is_some, inner);
            option::is_some(&o)
        }

        public fun test_option_contains(is_some: bool, inner: u64, e: u64): bool {
            let o = mk(is_some, inner);
            option::contains(&o, &e)
        }

        public fun test_option_get_with_default(is_some: bool, inner: u64, dflt: u64): u64 {
            let o = mk(is_some, inner);
            option::get_with_default(&o, dflt)
        }

        public fun test_option_borrow_with_default(is_some: bool, inner: u64, dflt: u64): u64 {
            let o = mk(is_some, inner);
            *option::borrow_with_default(&o, &dflt)
        }

        public fun test_option_destroy_with_default(is_some: bool, inner: u64, dflt: u64): u64 {
            let o = mk(is_some, inner);
            option::destroy_with_default(o, dflt)
        }

        public fun test_option_borrow(is_some: bool, inner: u64): u64 {
            let o = mk(is_some, inner);
            *option::borrow(&o)
        }

        public fun test_option_fill(is_some: bool, inner: u64, e: u64) {
            let o = mk(is_some, inner);
            option::fill(&mut o, e);
        }

        public fun test_option_extract(is_some: bool, inner: u64): u64 {
            let o = mk(is_some, inner);
            option::extract(&mut o)
        }

        public fun test_option_swap(is_some: bool, inner: u64, e: u64): u64 {
            let o = mk(is_some, inner);
            option::swap(&mut o, e)
        }

        public fun test_option_swap_or_fill(is_some: bool, inner: u64, e: u64): option::Option<u64> {
            let o = mk(is_some, inner);
            option::swap_or_fill(&mut o, e)
        }

        public fun test_option_destroy_none(is_some: bool, inner: u64) {
            let o = mk(is_some, inner);
            option::destroy_none(o);
        }

        public fun test_option_destroy_some(is_some: bool, inner: u64): u64 {
            let o = mk(is_some, inner);
            option::destroy_some(o)
        }

        public fun test_option_to_vec(is_some: bool, inner: u64): vector<u64> {
            let o = mk(is_some, inner);
            option::to_vec(o)
        }

        public fun test_option_from_vec(v: vector<u64>): option::Option<u64> {
            option::from_vec(v)
        }

        /// Direct `std::option::none<u64>()` (constructor API; distinct from `mk(false, …)`).
        public fun test_option_std_none(): option::Option<u64> {
            option::none()
        }

        /// Direct `std::option::some` (constructor API).
        public fun test_option_std_some(x: u64): option::Option<u64> {
            option::some(x)
        }
    }
"#;

pub struct OptionSuite;

impl DiffTestSuite for OptionSuite {
    fn id(&self) -> &'static str {
        "option"
    }

    fn name(&self) -> &'static str {
        "0x1::difftest_option"
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

        let two_arg_labels: Vec<(&str, bool, u64)> = vec![
            ("none_z", false, 0),
            ("some_7", true, 7),
            ("some_big", true, 1 << 40),
        ];

        for (label, is_some, inner) in &two_arg_labels {
            let args = vec![make_bool(*is_some), make_u64(*inner)];
            for test_fn in ["test_option_is_none", "test_option_is_some"] {
                let result = run_test_case(storage, STD_ADDR, MODULE_NAME, test_fn, &args)?;
                cases.push(TestCase {
                    function: format!("{test_fn} [{label}]"),
                    type_args: None,
                    args: args.clone(),
                    result,
                    skip_lean: false,
                });
            }
        }

        let contains_cases: Vec<(&str, bool, u64, u64)> = vec![
            ("none_cmp5", false, 0, 5),
            ("some5_eq", true, 5, 5),
            ("some5_ne6", true, 5, 6),
        ];
        for (label, is_some, inner, e) in contains_cases {
            let args = vec![make_bool(is_some), make_u64(inner), make_u64(e)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_option_contains",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_option_contains [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let gwd_cases: Vec<(&str, bool, u64, u64)> = vec![
            ("none_d99", false, 0, 99),
            ("some7_d0", true, 7, 0),
        ];
        for &(label, is_some, inner, d) in &gwd_cases {
            let args = vec![make_bool(is_some), make_u64(inner), make_u64(d)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_option_get_with_default",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_option_get_with_default [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for &(label, is_some, inner, d) in &gwd_cases {
            let args = vec![make_bool(is_some), make_u64(inner), make_u64(d)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_option_borrow_with_default",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_option_borrow_with_default [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for &(label, is_some, inner, d) in &gwd_cases {
            let args = vec![make_bool(is_some), make_u64(inner), make_u64(d)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_option_destroy_with_default",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_option_destroy_with_default [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, inner) in [("v42", 42u64), ("v0", 0u64)] {
            let args = vec![make_bool(true), make_u64(inner)];
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_borrow", &args)?;
            cases.push(TestCase {
                function: format!("test_option_borrow [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let args = vec![make_bool(false), make_u64(0)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_borrow", &args)?;
            cases.push(TestCase {
                function: "test_option_borrow [none_EOPTION_NOT_SET]".to_string(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, pad, e) in [("fill77", 0u64, 77u64), ("fill1", 99u64, 1u64)] {
            let args = vec![make_bool(false), make_u64(pad), make_u64(e)];
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_fill", &args)?;
            cases.push(TestCase {
                function: format!("test_option_fill [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let args = vec![make_bool(true), make_u64(7), make_u64(99)];
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_fill", &args)?;
            cases.push(TestCase {
                function: "test_option_fill [some_EOPTION_IS_SET]".to_string(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, inner) in [("v33", 33u64), ("v_max", u64::MAX)] {
            let args = vec![make_bool(true), make_u64(inner)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_extract", &args)?;
            cases.push(TestCase {
                function: format!("test_option_extract [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let args = vec![make_bool(false), make_u64(0)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_extract", &args)?;
            cases.push(TestCase {
                function: "test_option_extract [none_EOPTION_NOT_SET]".to_string(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, inner, e) in [("v10_e50", 10u64, 50u64), ("v0_e0", 0u64, 0u64)] {
            let args = vec![make_bool(true), make_u64(inner), make_u64(e)];
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_swap", &args)?;
            cases.push(TestCase {
                function: format!("test_option_swap [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let args = vec![make_bool(false), make_u64(0), make_u64(50)];
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_swap", &args)?;
            cases.push(TestCase {
                function: "test_option_swap [none_EOPTION_NOT_SET]".to_string(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let sof_cases: Vec<(&str, bool, u64, u64)> = vec![
            ("none_fill5", false, 0, 5),
            ("some_1_2", true, 1, 2),
            ("some_max_0", true, u64::MAX, 0),
        ];
        for (label, is_some, inner, e) in sof_cases {
            let args = vec![make_bool(is_some), make_u64(inner), make_u64(e)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_option_swap_or_fill",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_option_swap_or_fill [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, pad) in [("none_z", 0u64), ("none_9", 9u64)] {
            let args = vec![make_bool(false), make_u64(pad)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_destroy_none", &args)?;
            cases.push(TestCase {
                function: format!("test_option_destroy_none [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let args = vec![make_bool(true), make_u64(42)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_destroy_none", &args)?;
            cases.push(TestCase {
                function: "test_option_destroy_none [some_EOPTION_IS_SET]".to_string(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, v) in [("v88", 88u64), ("v1", 1u64)] {
            let args = vec![make_bool(true), make_u64(v)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_destroy_some", &args)?;
            cases.push(TestCase {
                function: format!("test_option_destroy_some [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let args = vec![make_bool(false), make_u64(0)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_destroy_some", &args)?;
            cases.push(TestCase {
                function: "test_option_destroy_some [none_EOPTION_NOT_SET]".to_string(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let to_vec_cases: Vec<(&str, bool, u64)> = vec![
            ("none_empty", false, 0),
            ("some_7", true, 7),
            ("some_big", true, 1 << 40),
        ];
        for &(label, is_some, inner) in &to_vec_cases {
            let args = vec![make_bool(is_some), make_u64(inner)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_to_vec", &args)?;
            cases.push(TestCase {
                function: format!("test_option_to_vec [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let from_vec_cases: Vec<(&str, &[u64])> =
            vec![("empty_none", &[]), ("one99", &[99u64]), ("one0", &[0u64])];
        for &(label, elems) in &from_vec_cases {
            let args = vec![make_u64_vec(elems)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_from_vec", &args)?;
            cases.push(TestCase {
                function: format!("test_option_from_vec [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let args = vec![make_u64_vec(&[1u64, 2u64])];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_from_vec", &args)?;
            cases.push(TestCase {
                function: "test_option_from_vec [two_elems_EOPTION_VEC_TOO_LONG]".to_string(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let args = Vec::new();
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_std_none", &args)?;
            cases.push(TestCase {
                function: "test_option_std_none [unit]".to_string(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, x) in [("v0", 0u64), ("v42", 42u64), ("v_max", u64::MAX)] {
            let args = vec![make_u64(x)];
            let result =
                run_test_case(storage, STD_ADDR, MODULE_NAME, "test_option_std_some", &args)?;
            cases.push(TestCase {
                function: format!("test_option_std_some [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        Ok(cases)
    }
}

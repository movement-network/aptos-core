use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::typed_value::make_u64;
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_fixed_point32";

const TEST_SOURCE: &str = r#"
module 0x1::difftest_fixed_point32 {
    use std::fixed_point32;

    public fun test_fp32_create_from_rational(n: u64, d: u64): u64 {
        fixed_point32::get_raw_value(fixed_point32::create_from_rational(n, d))
    }

    public fun test_fp32_create_from_u64(v: u64): u64 {
        fixed_point32::get_raw_value(fixed_point32::create_from_u64(v))
    }

    public fun test_fp32_create_from_raw_value(v: u64): u64 {
        fixed_point32::get_raw_value(fixed_point32::create_from_raw_value(v))
    }

    public fun test_fp32_multiply_u64(val: u64, mult_raw: u64): u64 {
        let m = fixed_point32::create_from_raw_value(mult_raw);
        fixed_point32::multiply_u64(val, m)
    }

    public fun test_fp32_divide_u64(val: u64, div_raw: u64): u64 {
        let d = fixed_point32::create_from_raw_value(div_raw);
        fixed_point32::divide_u64(val, d)
    }

    public fun test_fp32_get_raw_value(v: u64): u64 {
        let fp = fixed_point32::create_from_raw_value(v);
        fixed_point32::get_raw_value(fp)
    }

    public fun test_fp32_is_zero(v: u64): bool {
        let fp = fixed_point32::create_from_raw_value(v);
        fixed_point32::is_zero(fp)
    }

    public fun test_fp32_floor(v: u64): u64 {
        let fp = fixed_point32::create_from_raw_value(v);
        fixed_point32::floor(fp)
    }

    public fun test_fp32_ceil(v: u64): u64 {
        let fp = fixed_point32::create_from_raw_value(v);
        fixed_point32::ceil(fp)
    }

    public fun test_fp32_round(v: u64): u64 {
        let fp = fixed_point32::create_from_raw_value(v);
        fixed_point32::round(fp)
    }

    public fun test_fp32_min(a: u64, b: u64): u64 {
        let x = fixed_point32::create_from_raw_value(a);
        let y = fixed_point32::create_from_raw_value(b);
        fixed_point32::get_raw_value(fixed_point32::min(x, y))
    }

    public fun test_fp32_max(a: u64, b: u64): u64 {
        let x = fixed_point32::create_from_raw_value(a);
        let y = fixed_point32::create_from_raw_value(b);
        fixed_point32::get_raw_value(fixed_point32::max(x, y))
    }
}
"#;

pub struct FixedPoint32Suite;

impl DiffTestSuite for FixedPoint32Suite {
    fn id(&self) -> &'static str {
        "fixed_point32"
    }

    fn name(&self) -> &str {
        "0x1::difftest_fixed_point32"
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

        let rational_cases: Vec<((u64, u64), &str)> = vec![
            ((1, 1), "one_one"),
            ((3, 2), "three_halves"),
            ((100, 10), "ten_point_zero"),
        ];
        for ((n, d), label) in rational_cases {
            let args = vec![make_u64(n), make_u64(d)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_fp32_create_from_rational",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_fp32_create_from_rational [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let u64_create: Vec<(u64, &str)> = vec![(0, "zero"), (1, "one"), (1000, "1k")];
        for (v, label) in u64_create {
            let args = vec![make_u64(v)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_fp32_create_from_u64",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_fp32_create_from_u64 [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let raw_vals: Vec<(u64, &str)> = vec![(0, "zero"), (42, "fortytwo"), (1u64 << 32, "one_dot_zero")];
        for (v, label) in raw_vals {
            let args = vec![make_u64(v)];
            for (fname, fname_label) in [
                ("test_fp32_create_from_raw_value", "raw_roundtrip"),
                ("test_fp32_get_raw_value", "get_raw"),
                ("test_fp32_floor", "floor"),
                ("test_fp32_ceil", "ceil"),
                ("test_fp32_round", "round"),
            ] {
                let result = run_test_case(storage, STD_ADDR, MODULE_NAME, fname, &args)?;
                cases.push(TestCase {
                    function: format!("{fname} [{label}_{fname_label}]"),
                    type_args: None,
                    args: args.clone(),
                    result,
                    skip_lean: false,
                });
            }
        }

        for (v, label) in [(0u64, "zero"), (1u64 << 31, "half_frac")] {
            let args = vec![make_u64(v)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_fp32_is_zero",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_fp32_is_zero [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let mul_cases: Vec<((u64, u64), &str)> = vec![
            ((10, 1 << 32), "ten_times_one"),
            ((7, 1 << 31), "seven_times_half"),
        ];
        for ((val, mult_raw), label) in mul_cases {
            let args = vec![make_u64(val), make_u64(mult_raw)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_fp32_multiply_u64",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_fp32_multiply_u64 [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let div_cases: Vec<((u64, u64), &str)> = vec![
            ((100, 1 << 32), "hundred_div_one"),
            ((50, 1 << 31), "fifty_div_half"),
        ];
        for ((val, div_raw), label) in div_cases {
            let args = vec![make_u64(val), make_u64(div_raw)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_fp32_divide_u64",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_fp32_divide_u64 [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for ((a, b), label) in [((3u64, 5u64), "3_5"), ((100u64, 7u64), "100_7")] {
            let args = vec![make_u64(a), make_u64(b)];
            for fname in ["test_fp32_min", "test_fp32_max"] {
                let result = run_test_case(storage, STD_ADDR, MODULE_NAME, fname, &args)?;
                cases.push(TestCase {
                    function: format!("{fname} [{label}]"),
                    type_args: None,
                    args: args.clone(),
                    result,
                    skip_lean: false,
                });
            }
        }

        Ok(cases)
    }
}

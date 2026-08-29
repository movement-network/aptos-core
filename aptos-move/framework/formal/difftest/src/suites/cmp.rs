use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::typed_value::{
    make_address_hex, make_bool, make_u128_str, make_u16, make_u256_str, make_u32, make_u64,
    make_u8,
};
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_cmp";

/// `std::cmp`: native `compare` + `Ordering` predicates on scalars including `u256` (`cmp.move`).
const TEST_SOURCE: &str = r#"
    module 0x1::difftest_cmp {
        use std::cmp;

        public fun test_cmp_is_eq(a: u64, b: u64): bool {
            cmp::is_eq(&cmp::compare(&a, &b))
        }

        public fun test_cmp_is_ne(a: u64, b: u64): bool {
            cmp::is_ne(&cmp::compare(&a, &b))
        }

        public fun test_cmp_is_lt(a: u64, b: u64): bool {
            cmp::is_lt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_is_le(a: u64, b: u64): bool {
            cmp::is_le(&cmp::compare(&a, &b))
        }

        public fun test_cmp_is_gt(a: u64, b: u64): bool {
            cmp::is_gt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_is_ge(a: u64, b: u64): bool {
            cmp::is_ge(&cmp::compare(&a, &b))
        }

        public fun test_cmp_bool_is_eq(a: bool, b: bool): bool {
            cmp::is_eq(&cmp::compare(&a, &b))
        }

        public fun test_cmp_bool_is_ne(a: bool, b: bool): bool {
            cmp::is_ne(&cmp::compare(&a, &b))
        }

        public fun test_cmp_bool_is_lt(a: bool, b: bool): bool {
            cmp::is_lt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_bool_is_le(a: bool, b: bool): bool {
            cmp::is_le(&cmp::compare(&a, &b))
        }

        public fun test_cmp_bool_is_gt(a: bool, b: bool): bool {
            cmp::is_gt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_bool_is_ge(a: bool, b: bool): bool {
            cmp::is_ge(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u8_is_eq(a: u8, b: u8): bool {
            cmp::is_eq(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u8_is_ne(a: u8, b: u8): bool {
            cmp::is_ne(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u8_is_lt(a: u8, b: u8): bool {
            cmp::is_lt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u8_is_le(a: u8, b: u8): bool {
            cmp::is_le(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u8_is_gt(a: u8, b: u8): bool {
            cmp::is_gt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u8_is_ge(a: u8, b: u8): bool {
            cmp::is_ge(&cmp::compare(&a, &b))
        }

        public fun test_cmp_address_is_eq(a: address, b: address): bool {
            cmp::is_eq(&cmp::compare(&a, &b))
        }

        public fun test_cmp_address_is_ne(a: address, b: address): bool {
            cmp::is_ne(&cmp::compare(&a, &b))
        }

        public fun test_cmp_address_is_lt(a: address, b: address): bool {
            cmp::is_lt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_address_is_le(a: address, b: address): bool {
            cmp::is_le(&cmp::compare(&a, &b))
        }

        public fun test_cmp_address_is_gt(a: address, b: address): bool {
            cmp::is_gt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_address_is_ge(a: address, b: address): bool {
            cmp::is_ge(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u128_is_eq(a: u128, b: u128): bool {
            cmp::is_eq(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u128_is_ne(a: u128, b: u128): bool {
            cmp::is_ne(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u128_is_lt(a: u128, b: u128): bool {
            cmp::is_lt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u128_is_le(a: u128, b: u128): bool {
            cmp::is_le(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u128_is_gt(a: u128, b: u128): bool {
            cmp::is_gt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u128_is_ge(a: u128, b: u128): bool {
            cmp::is_ge(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u16_is_eq(a: u16, b: u16): bool {
            cmp::is_eq(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u16_is_ne(a: u16, b: u16): bool {
            cmp::is_ne(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u16_is_lt(a: u16, b: u16): bool {
            cmp::is_lt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u16_is_le(a: u16, b: u16): bool {
            cmp::is_le(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u16_is_gt(a: u16, b: u16): bool {
            cmp::is_gt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u16_is_ge(a: u16, b: u16): bool {
            cmp::is_ge(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u32_is_eq(a: u32, b: u32): bool {
            cmp::is_eq(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u32_is_ne(a: u32, b: u32): bool {
            cmp::is_ne(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u32_is_lt(a: u32, b: u32): bool {
            cmp::is_lt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u32_is_le(a: u32, b: u32): bool {
            cmp::is_le(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u32_is_gt(a: u32, b: u32): bool {
            cmp::is_gt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u32_is_ge(a: u32, b: u32): bool {
            cmp::is_ge(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u256_is_eq(a: u256, b: u256): bool {
            cmp::is_eq(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u256_is_ne(a: u256, b: u256): bool {
            cmp::is_ne(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u256_is_lt(a: u256, b: u256): bool {
            cmp::is_lt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u256_is_le(a: u256, b: u256): bool {
            cmp::is_le(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u256_is_gt(a: u256, b: u256): bool {
            cmp::is_gt(&cmp::compare(&a, &b))
        }

        public fun test_cmp_u256_is_ge(a: u256, b: u256): bool {
            cmp::is_ge(&cmp::compare(&a, &b))
        }
    }
"#;

pub struct CmpSuite;

impl DiffTestSuite for CmpSuite {
    fn id(&self) -> &'static str {
        "cmp"
    }

    fn name(&self) -> &str {
        "0x1::difftest_cmp"
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

        let u64_pairs: Vec<(u64, u64, &str)> = vec![
            (1, 2, "lt_1_2"),
            (5, 5, "eq_5_5"),
            (9, 3, "gt_9_3"),
            (0, 0, "eq_0_0"),
            (0, u64::MAX, "lt_0_max"),
            (u64::MAX, 0, "gt_max_0"),
        ];
        let u64_fns = [
            "test_cmp_is_eq",
            "test_cmp_is_ne",
            "test_cmp_is_lt",
            "test_cmp_is_le",
            "test_cmp_is_gt",
            "test_cmp_is_ge",
        ];
        for (a, b, label) in u64_pairs {
            let args = vec![make_u64(a), make_u64(b)];
            for test_fn in u64_fns {
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

        let bool_pairs: Vec<(bool, bool, &str)> = vec![
            (false, false, "ff"),
            (false, true, "ft"),
            (true, false, "tf"),
            (true, true, "tt"),
        ];
        let bool_fns = [
            "test_cmp_bool_is_eq",
            "test_cmp_bool_is_ne",
            "test_cmp_bool_is_lt",
            "test_cmp_bool_is_le",
            "test_cmp_bool_is_gt",
            "test_cmp_bool_is_ge",
        ];
        for (a, b, label) in bool_pairs {
            let args = vec![make_bool(a), make_bool(b)];
            for test_fn in bool_fns {
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

        let u8_pairs: Vec<(u8, u8, &str)> = vec![
            (0, 1, "lt_0_1"),
            (5, 5, "eq_5_5"),
            (200, 3, "gt_200_3"),
            (255, 0, "gt_255_0"),
        ];
        let u8_fns = [
            "test_cmp_u8_is_eq",
            "test_cmp_u8_is_ne",
            "test_cmp_u8_is_lt",
            "test_cmp_u8_is_le",
            "test_cmp_u8_is_gt",
            "test_cmp_u8_is_ge",
        ];
        for (a, b, label) in u8_pairs {
            let args = vec![make_u8(a), make_u8(b)];
            for test_fn in u8_fns {
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

        // 32-byte addresses; lexicographic `address` order matches Rust `AccountAddress` (`Ord`).
        const ADDR_ALL_ZERO: &str =
            "0x0000000000000000000000000000000000000000000000000000000000000000";
        const ADDR_LAST_BYTE_1: &str =
            "0x0000000000000000000000000000000000000000000000000000000000000001";
        const ADDR_FIRST_BYTE_1: &str =
            "0x0100000000000000000000000000000000000000000000000000000000000000";

        let address_pairs: Vec<(&str, &str, &str)> = vec![
            (ADDR_ALL_ZERO, ADDR_ALL_ZERO, "eq_zero"),
            (ADDR_ALL_ZERO, ADDR_LAST_BYTE_1, "lt_zero_last1"),
            (ADDR_FIRST_BYTE_1, ADDR_ALL_ZERO, "gt_first1_zero"),
            (ADDR_LAST_BYTE_1, ADDR_FIRST_BYTE_1, "lt_last1_first1"),
            (ADDR_FIRST_BYTE_1, ADDR_FIRST_BYTE_1, "eq_first1"),
        ];
        let address_fns = [
            "test_cmp_address_is_eq",
            "test_cmp_address_is_ne",
            "test_cmp_address_is_lt",
            "test_cmp_address_is_le",
            "test_cmp_address_is_gt",
            "test_cmp_address_is_ge",
        ];
        for (a, b, label) in address_pairs {
            let args = vec![make_address_hex(a), make_address_hex(b)];
            for test_fn in address_fns {
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

        let u128_pairs: Vec<(&str, &str, &str)> = vec![
            ("0", "1", "lt_0_1"),
            ("5", "5", "eq_5_5"),
            ("12345678901234567890", "0", "gt_big_0"),
            ("1", "2", "lt_1_2"),
            ("0", "340282366920938463463374607431768211455", "lt_0_max128"),
        ];
        let u128_fns = [
            "test_cmp_u128_is_eq",
            "test_cmp_u128_is_ne",
            "test_cmp_u128_is_lt",
            "test_cmp_u128_is_le",
            "test_cmp_u128_is_gt",
            "test_cmp_u128_is_ge",
        ];
        for (a, b, label) in u128_pairs {
            let args = vec![make_u128_str(a), make_u128_str(b)];
            for test_fn in u128_fns {
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

        let u16_pairs: Vec<(u16, u16, &str)> = vec![
            (1, 2, "lt_1_2"),
            (5, 5, "eq_5_5"),
            (100, 50, "gt_100_50"),
            (0, u16::MAX, "lt_0_max"),
        ];
        let u16_fns = [
            "test_cmp_u16_is_eq",
            "test_cmp_u16_is_ne",
            "test_cmp_u16_is_lt",
            "test_cmp_u16_is_le",
            "test_cmp_u16_is_gt",
            "test_cmp_u16_is_ge",
        ];
        for (a, b, label) in u16_pairs {
            let args = vec![make_u16(a), make_u16(b)];
            for test_fn in u16_fns {
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

        let u32_pairs: Vec<(u32, u32, &str)> = vec![
            (1, 2, "lt_1_2"),
            (5, 5, "eq_5_5"),
            (9, 3, "gt_9_3"),
            (0, u32::MAX, "lt_0_max"),
        ];
        let u32_fns = [
            "test_cmp_u32_is_eq",
            "test_cmp_u32_is_ne",
            "test_cmp_u32_is_lt",
            "test_cmp_u32_is_le",
            "test_cmp_u32_is_gt",
            "test_cmp_u32_is_ge",
        ];
        for (a, b, label) in u32_pairs {
            let args = vec![make_u32(a), make_u32(b)];
            for test_fn in u32_fns {
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

        let u256_pairs: Vec<(&str, &str, &str)> = vec![
            ("0", "1", "lt_0_1"),
            ("5", "5", "eq_5_5"),
            (
                "123456789012345678901234567890123456789012345678901234567890",
                "0",
                "gt_big_0",
            ),
            ("1", "2", "lt_1_2"),
            (
                "0",
                "115792089237316195423570985008687907853269984665640564039457584007913129639935",
                "lt_0_max256",
            ),
        ];
        let u256_fns = [
            "test_cmp_u256_is_eq",
            "test_cmp_u256_is_ne",
            "test_cmp_u256_is_lt",
            "test_cmp_u256_is_le",
            "test_cmp_u256_is_gt",
            "test_cmp_u256_is_ge",
        ];
        for (a, b, label) in u256_pairs {
            let args = vec![make_u256_str(a), make_u256_str(b)];
            for test_fn in u256_fns {
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

        Ok(cases)
    }
}

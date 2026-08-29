use anyhow::{Context, Result};
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::{TestCase, TestResult, TypedValue};
use crate::typed_value::make_u64;
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_bit_vector";

const TEST_SOURCE: &str = r#"
    module 0x1::difftest_bit_vector {
        use std::bit_vector;

        public fun test_bit_vector_new(len: u64): bit_vector::BitVector {
            bit_vector::new(len)
        }

        public fun test_bit_vector_set(bv: bit_vector::BitVector, idx: u64): bit_vector::BitVector {
            let x = bv;
            bit_vector::set(&mut x, idx);
            x
        }

        public fun test_bit_vector_unset(bv: bit_vector::BitVector, idx: u64): bit_vector::BitVector {
            let x = bv;
            bit_vector::unset(&mut x, idx);
            x
        }

        public fun test_bit_vector_is_index_set(
            bv: bit_vector::BitVector,
            idx: u64,
        ): bool {
            bit_vector::is_index_set(&bv, idx)
        }

        public fun test_bit_vector_shift_left(
            bv: bit_vector::BitVector,
            amount: u64,
        ): bit_vector::BitVector {
            let x = bv;
            bit_vector::shift_left(&mut x, amount);
            x
        }
    }
"#;

pub struct BitVectorSuite;

fn first_returned(res: TestResult) -> Result<TypedValue> {
    match res {
        TestResult::Returned { values } => values.into_iter().next().context("empty return values"),
        TestResult::Aborted { abort_code } => {
            anyhow::bail!("VM aborted with code {abort_code}")
        },
    }
}

fn oracle_new(storage: &mut InMemoryStorage, len: u64) -> Result<TypedValue> {
    let r = run_test_case(
        storage,
        STD_ADDR,
        MODULE_NAME,
        "test_bit_vector_new",
        &[make_u64(len)],
    )?;
    first_returned(r)
}

impl DiffTestSuite for BitVectorSuite {
    fn id(&self) -> &'static str {
        "bit_vector"
    }

    fn name(&self) -> &'static str {
        "0x1::difftest_bit_vector"
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

        for (label, len) in [
            ("len8", 8u64),
            ("len16", 16u64),
            ("len101", 101u64),
        ] {
            let args = vec![make_u64(len)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_new",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_bit_vector_new [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, len, idx) in [
            ("set0", 8u64, 0u64),
            ("set3", 8u64, 3u64),
            ("set7", 8u64, 7u64),
            ("set_mid", 64u64, 31u64),
        ] {
            let bv = oracle_new(storage, len)?;
            let args = vec![bv, make_u64(idx)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_set",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_bit_vector_set [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, len, set_idx, unset_idx) in [
            ("unset0_after_set", 5u64, 0u64, 0u64),
            ("unset4_after_set", 9u64, 4u64, 4u64),
        ] {
            let fresh = oracle_new(storage, len)?;
            let after_set = first_returned(run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_set",
                &[fresh, make_u64(set_idx)],
            )?)?;
            let args = vec![after_set, make_u64(unset_idx)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_unset",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_bit_vector_unset [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, len, qidx) in [("unset_bit5_on_fresh12", 12u64, 5u64)] {
            let bv = oracle_new(storage, len)?;
            let args = vec![bv, make_u64(qidx)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_is_index_set",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_bit_vector_is_index_set [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let bv = oracle_new(storage, 20)?;
            let set_at = 11u64;
            let bv_set = first_returned(run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_set",
                &[bv, make_u64(set_at)],
            )?)?;
            let args = vec![bv_set, make_u64(set_at)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_is_index_set",
                &args,
            )?;
            cases.push(TestCase {
                function: "test_bit_vector_is_index_set [set11_query11]".into(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        for (label, len, amt) in [
            ("shift2_on_empty8", 8u64, 2u64),
            ("shift0_on_empty16", 16u64, 0u64),
            ("shift_ge_len_zeros", 8u64, 10u64),
            ("shift3_pattern", 32u64, 3u64),
        ] {
            let bv = oracle_new(storage, len)?;
            let args = vec![bv, make_u64(amt)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_shift_left",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_bit_vector_shift_left [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        {
            let bv = oracle_new(storage, 24)?;
            let bv = first_returned(run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_set",
                &[bv, make_u64(10)],
            )?)?;
            let bv = first_returned(run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_set",
                &[bv, make_u64(15)],
            )?)?;
            let args = vec![bv, make_u64(4u64)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_bit_vector_shift_left",
                &args,
            )?;
            cases.push(TestCase {
                function: "test_bit_vector_shift_left [two_bits_shift4]".into(),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        Ok(cases)
    }
}

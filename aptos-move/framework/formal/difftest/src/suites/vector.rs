use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::typed_value::{make_u64, make_u64_vec};
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_vector";

const TEST_SOURCE: &str = r#"
    module 0x1::difftest_vector {
        use std::vector;

        public fun test_contains(v: vector<u64>, elem: u64): bool {
            vector::contains(&v, &elem)
        }

        public fun test_index_of(v: vector<u64>, elem: u64): (bool, u64) {
            vector::index_of(&v, &elem)
        }

        public fun test_reverse(v: vector<u64>): vector<u64> {
            vector::reverse(&mut v);
            v
        }

        public fun test_is_empty(v: vector<u64>): bool {
            vector::is_empty(&v)
        }

        public fun test_length(v: vector<u64>): u64 {
            vector::length(&v)
        }

        public fun test_remove(v: vector<u64>, i: u64): (vector<u64>, u64) {
            let elem = vector::remove(&mut v, i);
            (v, elem)
        }

        public fun test_swap_remove(v: vector<u64>, i: u64): (vector<u64>, u64) {
            let elem = vector::swap_remove(&mut v, i);
            (v, elem)
        }

        public fun test_append(v1: vector<u64>, v2: vector<u64>): vector<u64> {
            vector::append(&mut v1, v2);
            v1
        }

        public fun test_singleton(elem: u64): vector<u64> {
            vector::singleton(elem)
        }
    }
"#;

pub struct VectorSuite;

impl DiffTestSuite for VectorSuite {
    fn id(&self) -> &'static str {
        "vector"
    }

    fn name(&self) -> &str {
        "0x1::difftest_vector"
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

        gen_contains(storage, &mut cases)?;
        gen_index_of(storage, &mut cases)?;
        gen_reverse(storage, &mut cases)?;
        gen_remove(storage, &mut cases)?;
        gen_swap_remove(storage, &mut cases)?;
        gen_append(storage, &mut cases)?;
        gen_singleton(storage, &mut cases)?;
        gen_is_empty(storage, &mut cases)?;
        gen_length(storage, &mut cases)?;

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

fn gen_contains(storage: &mut InMemoryStorage, cases: &mut Vec<TestCase>) -> Result<()> {
    let inputs: Vec<(&[u64], u64, &str)> = vec![
        (&[10, 20, 30], 20, "found_middle"),
        (&[10, 20, 30], 10, "found_first"),
        (&[10, 20, 30], 30, "found_last"),
        (&[10, 20, 30], 99, "not_found"),
        (&[], 1, "empty_vec"),
        (&[42], 42, "singleton_found"),
        (&[42], 0, "singleton_not_found"),
    ];
    for (vec_vals, elem, label) in &inputs {
        push_case(
            storage,
            cases,
            "test_contains",
            label,
            vec![make_u64_vec(vec_vals), make_u64(*elem)],
        )?;
    }
    Ok(())
}

fn gen_index_of(storage: &mut InMemoryStorage, cases: &mut Vec<TestCase>) -> Result<()> {
    let inputs: Vec<(&[u64], u64, &str)> = vec![
        (&[10, 20, 30], 20, "found_at_1"),
        (&[10, 20, 30], 10, "found_at_0"),
        (&[10, 20, 30], 30, "found_at_2"),
        (&[10, 20, 30], 99, "not_found"),
        (&[], 1, "empty_vec"),
        (&[5, 5, 5], 5, "duplicates_returns_first"),
    ];
    for (vec_vals, elem, label) in &inputs {
        push_case(
            storage,
            cases,
            "test_index_of",
            label,
            vec![make_u64_vec(vec_vals), make_u64(*elem)],
        )?;
    }
    Ok(())
}

fn gen_reverse(storage: &mut InMemoryStorage, cases: &mut Vec<TestCase>) -> Result<()> {
    let inputs: Vec<(&[u64], &str)> = vec![
        (&[1, 2, 3, 4, 5], "five_elements"),
        (&[1, 2, 3], "three_elements"),
        (&[1, 2], "two_elements"),
        (&[42], "singleton"),
        (&[], "empty"),
        (&[10, 20, 30, 40, 50, 60], "six_elements"),
    ];
    for (vec_vals, label) in &inputs {
        push_case(
            storage,
            cases,
            "test_reverse",
            label,
            vec![make_u64_vec(vec_vals)],
        )?;
    }
    Ok(())
}

fn gen_remove(storage: &mut InMemoryStorage, cases: &mut Vec<TestCase>) -> Result<()> {
    let inputs: Vec<(&[u64], u64, &str)> = vec![
        (&[10, 20, 30], 0, "remove_first"),
        (&[10, 20, 30], 1, "remove_middle"),
        (&[10, 20, 30], 2, "remove_last"),
        (&[42], 0, "remove_singleton"),
    ];
    for (vec_vals, idx, label) in &inputs {
        push_case(
            storage,
            cases,
            "test_remove",
            label,
            vec![make_u64_vec(vec_vals), make_u64(*idx)],
        )?;
    }
    Ok(())
}

fn gen_swap_remove(storage: &mut InMemoryStorage, cases: &mut Vec<TestCase>) -> Result<()> {
    let inputs: Vec<(&[u64], u64, &str)> = vec![
        (&[10, 20, 30], 0, "swap_remove_first"),
        (&[10, 20, 30], 1, "swap_remove_middle"),
        (&[10, 20, 30], 2, "swap_remove_last"),
        (&[42], 0, "swap_remove_singleton"),
    ];
    for (vec_vals, idx, label) in &inputs {
        push_case(
            storage,
            cases,
            "test_swap_remove",
            label,
            vec![make_u64_vec(vec_vals), make_u64(*idx)],
        )?;
    }
    Ok(())
}

fn gen_append(storage: &mut InMemoryStorage, cases: &mut Vec<TestCase>) -> Result<()> {
    let inputs: Vec<(&[u64], &[u64], &str)> = vec![
        (&[1, 2], &[3, 4], "two_plus_two"),
        (&[], &[1, 2, 3], "empty_plus_three"),
        (&[1, 2, 3], &[], "three_plus_empty"),
        (&[], &[], "empty_plus_empty"),
    ];
    for (v1, v2, label) in &inputs {
        push_case(
            storage,
            cases,
            "test_append",
            label,
            vec![make_u64_vec(v1), make_u64_vec(v2)],
        )?;
    }
    Ok(())
}

fn gen_singleton(storage: &mut InMemoryStorage, cases: &mut Vec<TestCase>) -> Result<()> {
    for val in &[0u64, 42, u64::MAX] {
        push_case(
            storage,
            cases,
            "test_singleton",
            &val.to_string(),
            vec![make_u64(*val)],
        )?;
    }
    Ok(())
}

fn gen_is_empty(storage: &mut InMemoryStorage, cases: &mut Vec<TestCase>) -> Result<()> {
    let inputs: Vec<(&[u64], &str)> = vec![
        (&[], "empty"),
        (&[1], "singleton"),
        (&[1, 2, 3], "non_empty"),
    ];
    for (vec_vals, label) in &inputs {
        push_case(
            storage,
            cases,
            "test_is_empty",
            label,
            vec![make_u64_vec(vec_vals)],
        )?;
    }
    Ok(())
}

fn gen_length(storage: &mut InMemoryStorage, cases: &mut Vec<TestCase>) -> Result<()> {
    let inputs: Vec<(&[u64], &str)> = vec![
        (&[], "empty"),
        (&[1], "singleton"),
        (&[1, 2, 3, 4, 5], "five"),
    ];
    for (vec_vals, label) in &inputs {
        push_case(
            storage,
            cases,
            "test_length",
            label,
            vec![make_u64_vec(vec_vals)],
        )?;
    }
    Ok(())
}

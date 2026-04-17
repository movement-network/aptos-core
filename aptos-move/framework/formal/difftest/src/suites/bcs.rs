use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::typed_value::{
    make_address_hex, make_bool, make_u128_str, make_u64, make_u8, make_u8_vec,
};
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_bcs";

const TEST_SOURCE: &str = r#"
    module 0x1::difftest_bcs {
        use std::bcs;
        use std::option;

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

        public fun test_bcs_vec_u8(v: vector<u8>): vector<u8> {
            bcs::to_bytes(&v)
        }

        public fun test_bcs_address(a: address): vector<u8> {
            bcs::to_bytes(&a)
        }

        public fun test_serialized_size_u8(x: u8): u64 {
            bcs::serialized_size(&x)
        }

        public fun test_serialized_size_u64(x: u64): u64 {
            bcs::serialized_size(&x)
        }

        public fun test_serialized_size_u128(x: u128): u64 {
            bcs::serialized_size(&x)
        }

        public fun test_serialized_size_bool(b: bool): u64 {
            bcs::serialized_size(&b)
        }

        public fun test_serialized_size_vec_u8(v: vector<u8>): u64 {
            bcs::serialized_size(&v)
        }

        public fun test_serialized_size_address(a: address): u64 {
            bcs::serialized_size(&a)
        }

        public fun test_constant_size_u8(): u64 {
            *option::borrow(&bcs::constant_serialized_size<u8>())
        }

        public fun test_constant_size_u64(): u64 {
            *option::borrow(&bcs::constant_serialized_size<u64>())
        }

        public fun test_constant_size_u128(): u64 {
            *option::borrow(&bcs::constant_serialized_size<u128>())
        }

        public fun test_constant_size_bool(): u64 {
            *option::borrow(&bcs::constant_serialized_size<bool>())
        }

        public fun test_constant_size_address(): u64 {
            *option::borrow(&bcs::constant_serialized_size<address>())
        }

        public fun test_constant_size_vec_u8_is_none(): bool {
            option::is_none(&bcs::constant_serialized_size<vector<u8>>())
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
            ("u8_65_A", make_u8(65)),
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

        for (label, bytes) in [
            ("empty", &[][..]),
            ("one_byte_0f", &[0x0fu8][..]),
            ("bytes_abc", b"abc".as_slice()),
            ("len127", &[7u8; 127][..]),
            ("len128", &[8u8; 128][..]),
            ("len200", &[9u8; 200][..]),
        ] {
            push_case(
                storage,
                &mut cases,
                "test_bcs_vec_u8",
                label,
                vec![make_u8_vec(bytes)],
            )?;
        }

        for (label, hex) in [
            ("addr_0x1", "0x1"),
            ("addr_0xcafe", "0xcafe"),
            ("addr_max", "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"),
        ] {
            push_case(
                storage,
                &mut cases,
                "test_bcs_address",
                label,
                vec![make_address_hex(hex)],
            )?;
        }

        // serialized_size mirrors the same inputs
        for (label, arg) in [("one", make_u8(1)), ("max", make_u8(255))] {
            push_case(storage, &mut cases, "test_serialized_size_u8", label, vec![arg])?;
        }
        for (label, arg) in [("small", make_u64(42)), ("large", make_u64(0xdeadbeefcafe))] {
            push_case(
                storage,
                &mut cases,
                "test_serialized_size_u64",
                label,
                vec![arg],
            )?;
        }
        for (label, s) in [("one", "1"), ("large", "12345678901234567890")] {
            push_case(
                storage,
                &mut cases,
                "test_serialized_size_u128",
                label,
                vec![make_u128_str(s)],
            )?;
        }
        for (label, arg) in [("false", make_bool(false)), ("true", make_bool(true))] {
            push_case(
                storage,
                &mut cases,
                "test_serialized_size_bool",
                label,
                vec![arg],
            )?;
        }
        for (label, bytes) in [
            ("empty", &[][..]),
            ("one_byte", &[0x0fu8][..]),
            ("len128", &[8u8; 128][..]),
        ] {
            push_case(
                storage,
                &mut cases,
                "test_serialized_size_vec_u8",
                label,
                vec![make_u8_vec(bytes)],
            )?;
        }
        for (label, hex) in [("0x1", "0x1"), ("0xcafe", "0xcafe")] {
            push_case(
                storage,
                &mut cases,
                "test_serialized_size_address",
                label,
                vec![make_address_hex(hex)],
            )?;
        }

        // constant_serialized_size — nullary Move functions
        for (name, label) in [
            ("test_constant_size_u8", "fixed1"),
            ("test_constant_size_u64", "fixed8"),
            ("test_constant_size_u128", "fixed16"),
            ("test_constant_size_bool", "fixed1"),
            ("test_constant_size_address", "fixed32"),
        ] {
            push_case(storage, &mut cases, name, label, vec![])?;
        }
        push_case(
            storage,
            &mut cases,
            "test_constant_size_vec_u8_is_none",
            "expect_true",
            vec![],
        )?;

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

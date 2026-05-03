use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::typed_value::{make_u64, make_u8_vec};
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_string";

/// Exercises `std::string` UTF-8 native `internal_check_utf8` and public wrappers (`utf8` +
/// `sub_string` / `index_of`). `internal_is_char_boundary` is module-private in current `string.move`,
/// so boundary behavior is covered indirectly via `sub_string` cases. Semantics match
/// `move-stdlib/src/natives/string.rs`.
const TEST_SOURCE: &str = r#"
    module 0x1::difftest_string {
        use std::string;
        use std::vector;

        public fun test_string_internal_check_utf8(b: vector<u8>): bool {
            string::internal_check_utf8(&b)
        }

        public fun test_string_index_of(hay: vector<u8>, needle: vector<u8>): u64 {
            let hs = string::utf8(hay);
            let ns = string::utf8(needle);
            string::index_of(&hs, &ns)
        }

        public fun test_string_sub_string(bytes: vector<u8>, i: u64, j: u64): vector<u8> {
            let s = string::utf8(bytes);
            let t = string::sub_string(&s, i, j);
            let r = string::bytes(&t);
            vector::slice(r, 0, vector::length(r))
        }
    }
"#;

pub struct StringSuite;

impl DiffTestSuite for StringSuite {
    fn id(&self) -> &'static str {
        "string"
    }

    fn name(&self) -> &'static str {
        "0x1::difftest_string"
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

        let check_utf8_inputs: Vec<(&[u8], &str)> = vec![
            (&[], "empty"),
            (&[0x48, 0x69], "hi"),
            (&[0xff], "invalid_ff"),
            (&[0xe2, 0x82, 0xac], "euro_utf8"),
            (
                &[116, 101, 115, 116, 105, 110, 103],
                "testing",
            ),
        ];
        for (bytes, label) in check_utf8_inputs {
            let args = vec![make_u8_vec(bytes)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_string_internal_check_utf8",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_string_internal_check_utf8 [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let index_of_cases: Vec<(&[u8], &[u8], &str)> = vec![
            (&[], &[], "both_empty"),
            (&[97], &[], "empty_needle_in_a"),
            (&[97, 98, 99], &[98, 99], "bc_in_abc"),
            (&[97, 98, 99], &[100], "missing_returns_len"),
            (&[240, 159, 152, 128], &[240, 159, 152, 128], "emoji_self"),
            (&[99, 97, 102, 195, 169], &[195, 169], "e_acute_in_cafe"),
        ];
        for (hay, needle, label) in index_of_cases {
            let args = vec![make_u8_vec(hay), make_u8_vec(needle)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_string_index_of",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_string_index_of [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        let sub_string_cases: Vec<(&[u8], u64, u64, &str)> = vec![
            (&[], 0, 0, "empty_0_0"),
            (&[97, 98, 99], 0, 3, "abc_full"),
            (&[97, 98, 99], 1, 2, "b_only"),
            (&[104, 105], 0, 1, "h_only"),
            (&[99, 97, 102, 195, 169], 0, 3, "caf_prefix"),
            (&[99, 97, 102, 195, 169], 3, 5, "e_acute_suffix"),
        ];
        for (bytes, i, j, label) in sub_string_cases {
            let args = vec![make_u8_vec(bytes), make_u64(i), make_u64(j)];
            let result = run_test_case(
                storage,
                STD_ADDR,
                MODULE_NAME,
                "test_string_sub_string",
                &args,
            )?;
            cases.push(TestCase {
                function: format!("test_string_sub_string [{label}]"),
                type_args: None,
                args,
                result,
                skip_lean: false,
            });
        }

        Ok(cases)
    }
}

use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_stdlib;
use crate::schema::TestCase;
use crate::typed_value::make_u8_vec;
use crate::vm::run_test_case;

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_hash";

const TEST_SOURCE: &str = r#"
    module 0x1::difftest_hash {
        use std::hash;

        public fun test_sha3_256(data: vector<u8>): vector<u8> {
            hash::sha3_256(data)
        }
    }
"#;

pub struct HashSuite;

impl DiffTestSuite for HashSuite {
    fn id(&self) -> &'static str {
        "hash"
    }

    fn name(&self) -> &str {
        "0x1::difftest_hash"
    }

    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()> {
        let modules = compile_with_stdlib(TEST_SOURCE)?;
        for module in &modules {
            let mut blob = vec![];
            module.serialize(&mut blob)?;
            storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
        }
        Ok(())
    }

    fn generate_test_cases(&self, storage: &InMemoryStorage) -> Result<Vec<TestCase>> {
        let mut cases = Vec::new();

        let inputs: Vec<(&[u8], &str)> = vec![
            (&[], "empty"),
            (&[97, 98, 99], "abc"),
            (&[116, 101, 115, 116, 105, 110, 103], "testing"),
            (
                &[
                    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c,
                    0x0d, 0x0e, 0x0f,
                ],
                "sixteen_bytes",
            ),
        ];

        for (bytes, label) in inputs {
            let args = vec![make_u8_vec(bytes)];
            let result = run_test_case(storage, MODULE_NAME, "test_sha3_256", &args)?;
            cases.push(TestCase {
                function: format!("test_sha3_256 [{}]", label),
                type_args: None,
                args,
                result,
            });
        }

        Ok(cases)
    }
}

use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::typed_value::make_signer_hex;
use crate::vm::{module_blob, run_test_case, STD_ADDR};

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_signer";

const TEST_SOURCE: &str = r#"
    module 0x1::difftest_signer {
        use std::signer;

        public fun test_signer_borrow_address(s: &signer): address {
            *signer::borrow_address(s)
        }

        public fun test_signer_address_of(s: &signer): address {
            signer::address_of(s)
        }
    }
"#;

pub struct SignerSuite;

impl DiffTestSuite for SignerSuite {
    fn id(&self) -> &'static str {
        "signer"
    }

    fn name(&self) -> &'static str {
        "0x1::difftest_signer"
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

        let signers: Vec<(&str, &str)> = vec![
            ("0x1", "addr_one"),
            ("0x42", "addr_0x42"),
            (
                "0x00000000000000000000000000000000000000000000000000000000000000ab",
                "addr_padded_ab",
            ),
        ];

        for (hex, label) in signers {
            let arg = vec![make_signer_hex(hex)];
            for test_fn in ["test_signer_borrow_address", "test_signer_address_of"] {
                let result = run_test_case(storage, STD_ADDR, MODULE_NAME, test_fn, &arg)?;
                cases.push(TestCase {
                    function: format!("{test_fn} [{label}]"),
                    type_args: None,
                    args: arg.clone(),
                    result,
                    skip_lean: false,
                });
            }
        }

        Ok(cases)
    }
}

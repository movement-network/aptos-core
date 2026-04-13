//! FA stub alignment: VM returns fixed `u64` constants; Lean matches via `MachineState.faBalances`
//! (**read-only** seed for `test_fa_stub_balance_answer`) or **`faWriteBalance` + `faReadBalance`**
//! from **`MachineState.empty`** (`Programs/Confidential.lean` indices **52** / **169** + `Runner` seeds).

use crate::compiler::compile_with_aptos_head_bundle;
use crate::schema::TestCase;
use crate::vm::{module_blob, run_test_case, STD_ADDR};
use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use super::DiffTestSuite;

const MODULE_NAME: &str = "difftest_fa_stub";

/// Must match `Runner.lean` `faBalances` seed for `test_fa_stub_balance_answer`.
pub const FA_STUB_BALANCE: u64 = 12_345;

/// Must match Lean `faStubWriteReadProgram` (`faWriteBalance` then `faReadBalance` for `(1,2)`).
pub const FA_STUB_WRITE_THEN_READ_BALANCE: u64 = 9999;

fn test_source() -> String {
    format!(
        r#"
module 0x1::difftest_fa_stub {{
    /// Constant aligned with the Lean FA stub table (`(meta=1, owner=2) ↦` this value).
    public fun test_fa_stub_balance_answer(): u64 {{
        {FA_STUB_BALANCE}
    }}

    /// Constant aligned with Lean **`faWriteBalance`** + **`faReadBalance`** on empty `faBalances`.
    public fun test_fa_stub_write_then_read_balance(): u64 {{
        {FA_STUB_WRITE_THEN_READ_BALANCE}
    }}
}}
"#
    )
}

pub struct FaStubSuite;

impl DiffTestSuite for FaStubSuite {
    fn id(&self) -> &'static str {
        "fa_stub"
    }

    fn name(&self) -> &str {
        "0x1::difftest_fa_stub (FA Lean stub alignment)"
    }

    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()> {
        let modules = compile_with_aptos_head_bundle(&test_source())?;
        for module in &modules {
            let blob = module_blob(module)?;
            storage.add_module_bytes(module.self_addr(), module.self_name(), blob.into());
        }
        Ok(())
    }

    fn generate_test_cases(&self, storage: &mut InMemoryStorage) -> Result<Vec<TestCase>> {
        let mut cases = Vec::new();
        for (function, label) in [
            ("test_fa_stub_balance_answer", "fa_stub"),
            ("test_fa_stub_write_then_read_balance", "fa_stub_write_read"),
        ] {
            let result = run_test_case(storage, STD_ADDR, MODULE_NAME, function, &[])?;
            cases.push(TestCase {
                function: format!("{} [{}]", function, label),
                type_args: None,
                args: vec![],
                result,
                skip_lean: false,
            });
        }
        Ok(cases)
    }
}

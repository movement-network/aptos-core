//! Helpers for oracle rows consumed by `lake exe difftest`.
//! Prefer **`vm_lean_row`** when Lean should evaluate; use **`vm_only_row`** only for deliberate
//! VM-only rows (`skip_lean: true`).

use crate::schema::{TestCase, TestResult, TypedValue};

/// One VM-ground-truth row; Lean skips evaluation when `skip_lean` is `true`.
pub fn vm_only_row(
    function: impl Into<String>,
    args: Vec<TypedValue>,
    result: TestResult,
) -> TestCase {
    TestCase {
        function: function.into(),
        type_args: None,
        args,
        result,
        skip_lean: true,
    }
}

/// VM-ground-truth row that Lean also evaluates (`skip_lean: false`).
///
/// Used when the Lean column implements a **compact witness** for the same JSON outcome as the VM
/// (for example transactional CA e2e summaries), not a byte-level replay of framework entrypoints.
pub fn vm_lean_row(
    function: impl Into<String>,
    args: Vec<TypedValue>,
    result: TestResult,
) -> TestCase {
    TestCase {
        function: function.into(),
        type_args: None,
        args,
        result,
        skip_lean: false,
    }
}

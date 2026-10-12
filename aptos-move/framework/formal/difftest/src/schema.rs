use serde::{Deserialize, Serialize};

fn is_false(b: &bool) -> bool {
    !*b
}

/// Bump this and document in `ORACLE_CHANGELOG.md` when the JSON shape changes incompatibly.
pub const CURRENT_SCHEMA_VERSION: u32 = 1;

fn default_schema_version() -> u32 {
    CURRENT_SCHEMA_VERSION
}

/// VM-only fragment for `move-lean-difftest merge` (`{"test_cases":[...]}`).
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OracleFragment {
    pub test_cases: Vec<TestCase>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TestSuite {
    #[serde(default = "default_schema_version")]
    pub schema_version: u32,
    pub generator: String,
    pub module: String,
    pub test_cases: Vec<TestCase>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TestCase {
    pub function: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub type_args: Option<Vec<String>>,
    pub args: Vec<TypedValue>,
    pub result: TestResult,
    /// When `true`, `lake exe difftest` skips the Lean evaluator for this row (VM oracle only).
    /// Omitted or `false` preserves existing VM↔Lean behavior.
    #[serde(default)]
    #[serde(skip_serializing_if = "is_false")]
    pub skip_lean: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TypedValue {
    #[serde(rename = "type")]
    pub ty: String,
    pub value: serde_json::Value,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "status")]
pub enum TestResult {
    #[serde(rename = "returned")]
    Returned { values: Vec<TypedValue> },
    #[serde(rename = "aborted")]
    Aborted { abort_code: u64 },
}

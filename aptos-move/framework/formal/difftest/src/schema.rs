use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TestSuite {
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

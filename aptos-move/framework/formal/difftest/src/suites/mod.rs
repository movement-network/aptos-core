pub mod bcs;
pub mod hash;
pub mod vector;

use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::schema::TestCase;

pub trait DiffTestSuite {
    /// Short id for `--suite` filtering (`vector`, `bcs`, `hash`).
    fn id(&self) -> &'static str;
    fn name(&self) -> &str;
    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()>;
    fn generate_test_cases(&self, storage: &InMemoryStorage) -> Result<Vec<TestCase>>;
}

pub fn all_suites() -> Vec<Box<dyn DiffTestSuite>> {
    vec![
        Box::new(vector::VectorSuite),
        Box::new(bcs::BcsSuite),
        Box::new(hash::HashSuite),
    ]
}

/// Select suites by id; empty `filter` means all. Unknown ids are an error.
pub fn suites_filtered(filter: &[String]) -> Result<Vec<Box<dyn DiffTestSuite>>> {
    if filter.is_empty() {
        return Ok(all_suites());
    }
    let mut out = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for id in filter {
        if !seen.insert(id.as_str()) {
            continue;
        }
        let suite: Box<dyn DiffTestSuite> = match id.as_str() {
            "vector" => Box::new(vector::VectorSuite),
            "bcs" => Box::new(bcs::BcsSuite),
            "hash" => Box::new(hash::HashSuite),
            other => anyhow::bail!("unknown suite id '{other}' (expected vector, bcs, or hash)"),
        };
        out.push(suite);
    }
    Ok(out)
}

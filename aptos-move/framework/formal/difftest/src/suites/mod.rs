pub mod acl;
pub mod bcs;
pub mod cmp;
pub mod bit_vector;
pub mod error;
pub mod fixed_point32;
pub mod global_resource_smoke;
pub mod hash;
pub mod option;
pub mod signer;
pub mod string;
pub mod vector;

use anyhow::Result;
use move_vm_test_utils::InMemoryStorage;

use crate::schema::TestCase;

pub trait DiffTestSuite {
    /// Short id for `--suite` filtering (see `all_suite_ids()`).
    fn id(&self) -> &'static str;
    fn name(&self) -> &str;
    fn load_module(&self, storage: &mut InMemoryStorage) -> Result<()>;
    fn generate_test_cases(&self, storage: &mut InMemoryStorage) -> Result<Vec<TestCase>>;
}

/// Single registry for VM oracle suites. Add new `DiffTestSuite` impls here only —
/// help text, `--list-suites`, and unknown-id errors are derived from this list.
pub fn all_suites() -> Vec<Box<dyn DiffTestSuite>> {
    vec![
        Box::new(vector::VectorSuite),
        Box::new(acl::AclSuite),
        Box::new(bcs::BcsSuite),
        Box::new(bit_vector::BitVectorSuite),
        Box::new(error::ErrorSuite),
        Box::new(hash::HashSuite),
        Box::new(signer::SignerSuite),
        Box::new(string::StringSuite),
        Box::new(cmp::CmpSuite),
        Box::new(fixed_point32::FixedPoint32Suite),
        Box::new(option::OptionSuite),
        Box::new(global_resource_smoke::GlobalResourceSmokeSuite),
    ]
}

/// Stable ids for `--suite` / docs (same order as `all_suites`).
pub fn all_suite_ids() -> Vec<&'static str> {
    all_suites().iter().map(|s| s.id()).collect()
}

/// Select suites by id; empty `filter` means all. Unknown ids are an error.
pub fn suites_filtered(filter: &[String]) -> Result<Vec<Box<dyn DiffTestSuite>>> {
    if filter.is_empty() {
        return Ok(all_suites());
    }
    let mut out = Vec::new();
    for id in filter {
        let suite: Box<dyn DiffTestSuite> = match id.as_str() {
            "vector" => Box::new(vector::VectorSuite),
            "acl" => Box::new(acl::AclSuite),
            "bcs" => Box::new(bcs::BcsSuite),
            "bit_vector" => Box::new(bit_vector::BitVectorSuite),
            "error" => Box::new(error::ErrorSuite),
            "hash" => Box::new(hash::HashSuite),
            "signer" => Box::new(signer::SignerSuite),
            "string" => Box::new(string::StringSuite),
            "cmp" => Box::new(cmp::CmpSuite),
            "fixed_point32" => Box::new(fixed_point32::FixedPoint32Suite),
            "option" => Box::new(option::OptionSuite),
            "global_resource_smoke" => Box::new(global_resource_smoke::GlobalResourceSmokeSuite),
            other => anyhow::bail!(
                "unknown suite id '{other}' (expected one of: {})",
                all_suite_ids().join(", ")
            ),
        };
        out.push(suite);
    }
    Ok(out)
}

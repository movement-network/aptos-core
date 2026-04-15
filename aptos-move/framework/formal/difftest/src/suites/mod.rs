pub mod bcs;
pub mod confidential_asset;
pub mod confidential_balance;
pub mod confidential_elgamal;
pub mod confidential_proof;
pub mod fa_stub;
pub mod global_resource_smoke;
pub mod hash;
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
///
/// Note: `confidential` is **not** a separate suite here; see [`suites_filtered`] which expands
/// it to `confidential_balance`, `confidential_proof`, and `confidential_asset`.
pub fn all_suites() -> Vec<Box<dyn DiffTestSuite>> {
    vec![
        Box::new(vector::VectorSuite),
        Box::new(bcs::BcsSuite),
        Box::new(hash::HashSuite),
        Box::new(global_resource_smoke::GlobalResourceSmokeSuite),
        Box::new(confidential_balance::ConfidentialBalanceSuite),
        Box::new(confidential_elgamal::ConfidentialElGamalSuite),
        Box::new(confidential_proof::ConfidentialProofSuite),
        Box::new(confidential_asset::ConfidentialAssetLayerSuite),
        Box::new(fa_stub::FaStubSuite),
    ]
}

/// Stable ids for `--suite` / docs (same order as `all_suites`, plus meta id `confidential`).
pub fn all_suite_ids() -> Vec<&'static str> {
    let mut v: Vec<&'static str> = all_suites().iter().map(|s| s.id()).collect();
    v.push("confidential");
    v
}

fn expand_confidential_meta(filter: &[String]) -> Vec<String> {
    let mut out = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for id in filter {
        if id == "confidential" {
            for sub in [
                "confidential_balance",
                "confidential_elgamal",
                "confidential_proof",
                "confidential_asset",
            ] {
                if seen.insert(sub) {
                    out.push(sub.to_string());
                }
            }
        } else if seen.insert(id.as_str()) {
            out.push(id.clone());
        }
    }
    out
}

/// Select suites by id; empty `filter` means all. Unknown ids are an error.
/// The meta id **`confidential`** runs the three confidential suites in dependency order.
pub fn suites_filtered(filter: &[String]) -> Result<Vec<Box<dyn DiffTestSuite>>> {
    if filter.is_empty() {
        return Ok(all_suites());
    }
    let expanded = expand_confidential_meta(filter);
    let mut out = Vec::new();
    for id in expanded {
        let suite: Box<dyn DiffTestSuite> = match id.as_str() {
            "vector" => Box::new(vector::VectorSuite),
            "bcs" => Box::new(bcs::BcsSuite),
            "hash" => Box::new(hash::HashSuite),
            "global_resource_smoke" => Box::new(global_resource_smoke::GlobalResourceSmokeSuite),
            "confidential_balance" => Box::new(confidential_balance::ConfidentialBalanceSuite),
            "confidential_elgamal" => Box::new(confidential_elgamal::ConfidentialElGamalSuite),
            "confidential_proof" => Box::new(confidential_proof::ConfidentialProofSuite),
            "confidential_asset" => Box::new(confidential_asset::ConfidentialAssetLayerSuite),
            "fa_stub" => Box::new(fa_stub::FaStubSuite),
            other => anyhow::bail!(
                "unknown suite id '{other}' (expected one of: {})",
                all_suite_ids().join(", ")
            ),
        };
        out.push(suite);
    }
    Ok(out)
}

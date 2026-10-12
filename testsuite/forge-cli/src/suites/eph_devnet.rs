// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

use crate::suites::ungrouped::GetMetadata;
use aptos_forge::{ForgeConfig, NodeResourceOverride};
use std::{num::NonZeroUsize, sync::Arc};

/// Matches the test name to the ephemeral devnet suite.
pub(crate) fn get_eph_devnet_test(test_name: &str) -> Option<ForgeConfig> {
    let test = match test_name {
        "eph_devnet" => eph_devnet(),
        _ => return None,
    };
    Some(test)
}

/// A mainnet-aligned ephemeral devnet: four validators with Movement mainnet
/// chain parameters, deployed and kept alive (`--keep`) for a developer to
/// test a branch build against, then torn down.
///
/// Chain parameters mirror the ephemeral-devnet prototype
/// (movement-infra/cdktf-mvmt-networks#156): compressed timings and mainnet
/// staking bounds queried from Movement mainnet. Chain id is 126
/// (`NamedChain::MOVEMAINNET`), so `ChainId::is_movement_mainnet` is true and a
/// branch exercises under the same chain identity and staking config as
/// Movement mainnet. The residual post-genesis migration (governed gas pool
/// extension, treasury reward feature) runs separately. Genesis already
/// initializes the base governed gas pool.
pub(crate) fn eph_devnet() -> ForgeConfig {
    ForgeConfig::default()
        .with_initial_validator_count(NonZeroUsize::new(4).unwrap())
        .add_admin_test(GetMetadata)
        // Fit one validator per m6a.2xlarge (8 vCPU / 32 GiB), leaving headroom
        // for system pods. Without this the chart default (30 vCPU) is unschedulable.
        .with_validator_resource_override(NodeResourceOverride {
            cpu_cores: Some(6),
            memory_gib: Some(24),
            storage_gib: Some(100),
        })
        .with_genesis_helm_config_fn(Arc::new(|helm_values| {
            let chain = &mut helm_values["chain"];
            chain["chain_id"] = 126.into();
            chain["allow_new_validators"] = true.into();
            chain["epoch_duration_secs"] = 600.into();
            chain["is_test"] = true.into();
            chain["min_stake"] = 10_000_000_000_000i64.into();
            chain["max_stake"] = 100_000_000_000_000_000i64.into();
            chain["recurring_lockup_duration_secs"] = 3600.into();
            chain["rewards_apy_percentage"] = 10.into();
            chain["voting_duration_secs"] = 1800.into();
            chain["voting_power_increase_limit"] = 20.into();

            // Single cluster: validators/fullnodes discover each other by
            // in-cluster service name, so on-chain (DNS domain) discovery is off.
            helm_values["genesis"]["validator"]["enable_onchain_discovery"] = false.into();
            helm_values["genesis"]["fullnode"]["enable_onchain_discovery"] = false.into();
        }))
}

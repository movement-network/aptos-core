// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

use aptos_forge::{forge_main, ForgeConfig, InitialVersion, LocalFactory, Options, Result};
use aptos_testcases::compatibility_test::SimpleValidatorUpgrade;
use std::{env, num::NonZeroUsize};

fn main() -> Result<()> {
    ::aptos_logger::Logger::init_for_testing();

    let tests = ForgeConfig::default()
        .with_initial_validator_count(NonZeroUsize::new(4).unwrap())
        .with_initial_version(InitialVersion::Oldest)
        .add_network_test(SimpleValidatorUpgrade);

    let options = Options::parse();
    let epoch_duration_secs = env::var("FORGE_COMPAT_EPOCH_DURATION_SECS")
        .ok()
        .map(|v| v.parse::<u64>())
        .transpose()?
        .unwrap_or(SimpleValidatorUpgrade::EPOCH_DURATION_SECS);
    let factory = match (
        env::var("FORGE_COMPAT_OLD_REVISION").ok(),
        env::var("FORGE_COMPAT_NEW_REVISION").ok(),
    ) {
        (Some(old_revision), Some(new_revision)) => {
            LocalFactory::with_revisions(&old_revision, &new_revision)?
        },
        (None, None) => LocalFactory::with_upstream_merge_base_and_workspace()?,
        _ => {
            anyhow::bail!(
                "set both FORGE_COMPAT_OLD_REVISION and FORGE_COMPAT_NEW_REVISION, or neither"
            )
        },
    }
    .with_epoch_duration_secs(epoch_duration_secs);
    forge_main(
        tests,
        factory,
        &options,
    )
}

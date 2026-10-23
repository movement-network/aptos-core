// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    randomness::{
        decrypt_key_map, first_new_block_version_for_epoch, get_on_chain_resource_at_version,
        governance_activation_epoch_and_version, governance_gas_options,
        script_to_disable_main_logic, verify_dkg_transcript,
    },
    smoke_test_environment::SwarmBuilder,
};
use aptos_forge::{Node, Swarm, SwarmExt};
use aptos_logger::{debug, info};
use aptos_types::{
    dkg::DKGState, on_chain_config::OnChainRandomnessConfig, randomness::PerBlockRandomness,
};
use std::{sync::Arc, time::Duration};

/// Disable on-chain randomness by only disabling randomness main logic.
#[tokio::test]
async fn disable_feature_0() {
    let epoch_duration_secs = 20;

    let (swarm, mut cli, _faucet) = SwarmBuilder::new_local(4)
        .with_num_fullnodes(1)
        .with_aptos()
        .with_init_genesis_config(Arc::new(move |conf| {
            conf.epoch_duration_secs = epoch_duration_secs;
            conf.allow_new_validators = true;

            // Ensure randomness is enabled.
            conf.consensus_config.enable_validator_txns();
            conf.randomness_config_override = Some(OnChainRandomnessConfig::default_enabled());
        }))
        .build_with_cli(0)
        .await;

    let root_addr = swarm.chain_info().root_account().address();
    let root_idx = cli.add_account_with_address_to_cli(swarm.root_key(), root_addr);

    let decrypt_key_map = decrypt_key_map(&swarm);

    let client_endpoint = swarm.validators().nth(1).unwrap().rest_api_endpoint();
    let client = aptos_rest_client::Client::new(client_endpoint.clone());

    swarm
        .wait_for_all_nodes_to_catchup_to_epoch(3, Duration::from_secs(epoch_duration_secs * 2))
        .await
        .expect("Waited too long for epoch 3.");

    info!("Now in epoch 3. Disabling randomness main logic.");
    let txn_summary = cli
        .run_script_with_gas_options(
            root_idx,
            script_to_disable_main_logic().as_str(),
            Some(governance_gas_options()),
        )
        .await
        .expect("Txn execution error.");
    debug!("txn_summary={:?}", txn_summary);

    let (activation_epoch, activation_version) = governance_activation_epoch_and_version(
        &client,
        &txn_summary,
        Duration::from_secs(epoch_duration_secs * 2),
    )
    .await;

    info!(
        "Randomness main logic disabled in epoch {} at version {}.",
        activation_epoch, activation_version
    );
    let dkg_session = get_on_chain_resource_at_version::<DKGState>(&client, activation_version)
        .await
        .last_completed
        .expect("dkg result for the activation epoch should be present");
    assert_eq!(activation_epoch, dkg_session.target_epoch());
    assert!(verify_dkg_transcript(&dkg_session, &decrypt_key_map).is_ok());

    let randomness_seed =
        get_on_chain_resource_at_version::<PerBlockRandomness>(&client, activation_version).await;
    assert!(randomness_seed.seed.is_none());

    let next_epoch = activation_epoch + 1;
    let next_epoch_version = first_new_block_version_for_epoch(
        &client,
        next_epoch,
        Duration::from_secs(epoch_duration_secs * 2),
    )
    .await;

    info!(
        "Checking that the DKG transcript and randomness seed are unavailable in epoch {}.",
        next_epoch
    );
    let maybe_last_complete =
        get_on_chain_resource_at_version::<DKGState>(&client, next_epoch_version)
            .await
            .last_completed;
    assert!(
        maybe_last_complete.is_none()
            || maybe_last_complete.as_ref().unwrap().target_epoch() != next_epoch
    );

    let randomness_seed =
        get_on_chain_resource_at_version::<PerBlockRandomness>(&client, next_epoch_version).await;
    assert!(randomness_seed.seed.is_none());
}

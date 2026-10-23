// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    randomness::{
        decrypt_key_map, first_new_block_version_for_epoch, get_on_chain_resource_at_version,
        governance_activation_epoch_and_version, governance_gas_options,
        script_to_enable_main_logic, script_to_update_consensus_config, verify_dkg_transcript,
    },
    smoke_test_environment::SwarmBuilder,
    utils::get_current_consensus_config,
};
use aptos_forge::{Node, Swarm, SwarmExt};
use aptos_logger::{debug, info};
use aptos_types::{dkg::DKGState, on_chain_config::OnChainRandomnessConfig};
use std::{sync::Arc, time::Duration};

/// Enable on-chain randomness in the following steps.
/// - Enable randomness main logic in epoch `e`.
/// - Enable validator transactions in consensus config in epoch `e + 1`.
#[tokio::test]
async fn enable_feature_0() {
    let epoch_duration_secs = 20;
    let estimated_dkg_latency_secs = 40;

    let (swarm, mut cli, _faucet) = SwarmBuilder::new_local(4)
        .with_num_fullnodes(1)
        .with_aptos()
        .with_init_genesis_config(Arc::new(move |conf| {
            conf.epoch_duration_secs = epoch_duration_secs;
            conf.allow_new_validators = true;

            // start with vtxn disabled and randomness off.
            conf.consensus_config.disable_validator_txns();
            conf.randomness_config_override = Some(OnChainRandomnessConfig::default_disabled());
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

    info!("Now in epoch 3. Enabling randomness main logic.");
    let enable_dkg_script = script_to_enable_main_logic();

    let txn_summary = cli
        .run_script_with_gas_options(
            root_idx,
            enable_dkg_script.as_str(),
            Some(governance_gas_options()),
        )
        .await
        .expect("Txn execution error.");
    debug!("enabling_dkg_summary={:?}", txn_summary);

    let (main_logic_epoch, _) = governance_activation_epoch_and_version(
        &client,
        &txn_summary,
        Duration::from_secs(epoch_duration_secs * 2),
    )
    .await;

    info!(
        "Randomness main logic enabled in epoch {}. Enabling validator transactions.",
        main_logic_epoch
    );
    let mut config = get_current_consensus_config(&client).await;
    config.enable_validator_txns();
    let enable_vtxn_script = script_to_update_consensus_config(&config);
    debug!("enable_vtxn_script={}", enable_vtxn_script);
    let txn_summary = cli
        .run_script_with_gas_options(
            root_idx,
            enable_vtxn_script.as_str(),
            Some(governance_gas_options()),
        )
        .await
        .expect("Txn execution error.");
    debug!("enabling_vtxn_summary={:?}", txn_summary);

    let (activation_epoch, activation_version) = governance_activation_epoch_and_version(
        &client,
        &txn_summary,
        Duration::from_secs(epoch_duration_secs * 2),
    )
    .await;

    info!(
        "DKG and validator transactions enabled in epoch {} at version {}. No DKG result should be present for that epoch.",
        activation_epoch, activation_version
    );
    let maybe_last_complete =
        get_on_chain_resource_at_version::<DKGState>(&client, activation_version)
            .await
            .last_completed;
    assert!(
        maybe_last_complete.is_none()
            || maybe_last_complete.as_ref().unwrap().target_epoch() != activation_epoch
    );

    let next_epoch = activation_epoch + 1;
    let next_epoch_version = first_new_block_version_for_epoch(
        &client,
        next_epoch,
        Duration::from_secs(epoch_duration_secs + estimated_dkg_latency_secs),
    )
    .await;

    let dkg_session = get_on_chain_resource_at_version::<DKGState>(&client, next_epoch_version)
        .await
        .last_completed
        .expect("dkg result for the epoch after activation should be present");
    assert_eq!(next_epoch, dkg_session.target_epoch());
    assert!(verify_dkg_transcript(&dkg_session, &decrypt_key_map).is_ok());
}

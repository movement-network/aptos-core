// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::utils;
use anyhow::{anyhow, ensure, Result};
use aptos_crypto::{compat::Sha3_256, Uniform};
use aptos_dkg::weighted_vuf::traits::WeightedVUF;
use aptos_forge::LocalSwarm;
use aptos_logger::info;
use aptos_rest_client::Client;
use aptos_types::{
    dkg::{DKGSessionState, DKGState, DKGTrait, DefaultDKG},
    on_chain_config::{ConfigurationResource, OnChainConfig, OnChainConsensusConfig},
    randomness::{PerBlockRandomness, RandMetadata, WVUF},
    validator_verifier::ValidatorConsensusInfo,
};
use digest::Digest;
use move_core_types::{account_address::AccountAddress, language_storage::CORE_CODE_ADDRESS};
use movement::common::types::{GasOptions, TransactionSummary};
use rand::{prelude::StdRng, SeedableRng};
use std::{collections::HashMap, time::Duration};
use tokio::time::Instant;

mod disable_feature_0;
mod disable_feature_1;
mod dkg_with_validator_down;
mod dkg_with_validator_join_leave;
mod e2e_basic_consumption;
mod e2e_correctness;
mod enable_feature_0;
mod enable_feature_1;
mod enable_feature_2;
mod entry_func_attrs;
mod randomness_stall_recovery;
mod validator_restart_during_dkg;

#[allow(dead_code)]
async fn get_current_version(rest_client: &Client) -> u64 {
    rest_client
        .get_ledger_information()
        .await
        .unwrap()
        .inner()
        .version
}

#[allow(dead_code)]
async fn get_on_chain_resource_at_version<T: OnChainConfig>(
    rest_client: &Client,
    version: u64,
) -> T {
    let maybe_response = rest_client
        .get_account_resource_at_version_bcs::<T>(
            CORE_CODE_ADDRESS,
            T::struct_tag().to_canonical_string().as_str(),
            version,
        )
        .await;
    let response = maybe_response.unwrap();
    response.into_inner()
}

/// Return the ledger version of the first committed block in `target_epoch`.
///
/// The configuration change transaction records the epoch it applies to only in
/// its pre-state.  Read the resources asserted by these tests at that epoch's
/// first block, rather than at whatever later epoch the compiler/runtime has
/// reached.
async fn first_new_block_version_for_epoch(
    rest_client: &Client,
    target_epoch: u64,
    time_limit: Duration,
) -> u64 {
    const PAGE_SIZE: u16 = 100;

    let deadline = Instant::now() + time_limit;
    let (_, state) = rest_client
        .get_new_block_events_bcs(None, Some(1))
        .await
        .expect("failed to determine the new-block event cursor")
        .into_parts();
    let mut cursor = state.oldest_block_height;

    loop {
        let events = rest_client
            .get_new_block_events_bcs(Some(cursor), Some(PAGE_SIZE))
            .await
            .expect("failed to fetch new-block events")
            .into_inner();

        for event in events {
            match event.event.epoch().cmp(&target_epoch) {
                std::cmp::Ordering::Less => cursor = event.sequence_number + 1,
                std::cmp::Ordering::Equal => return event.version,
                std::cmp::Ordering::Greater => panic!(
                    "first retained new-block event for epoch {} is already after target epoch {}",
                    event.event.epoch(),
                    target_epoch,
                ),
            }
        }

        assert!(
            Instant::now() < deadline,
            "timed out waiting for a committed new-block event in epoch {target_epoch}"
        );
        tokio::time::sleep(Duration::from_millis(100)).await;
    }
}

/// Avoid a reconfiguration transaction being capped by a simulation from a
/// different execution state. Keep the normal estimated gas price and expiry.
fn governance_gas_options() -> GasOptions {
    GasOptions {
        max_gas: Some(2_000_000),
        ..Default::default()
    }
}

/// Identify the epoch in which a governance reconfiguration transaction takes
/// effect and a stable ledger version for assertions about that epoch.
async fn governance_activation_epoch_and_version(
    rest_client: &Client,
    txn_summary: &TransactionSummary,
    time_limit: Duration,
) -> (u64, u64) {
    let transaction_version = txn_summary
        .version
        .expect("governance reconfiguration transaction did not report a version");
    tokio::time::timeout(
        time_limit,
        rest_client.wait_for_version(transaction_version),
    )
    .await
    .expect("timed out waiting for the historical reader to reach the governance transaction")
    .expect("historical reader failed while waiting for the governance transaction");

    let pre_state_version = transaction_version
        .checked_sub(1)
        .expect("governance reconfiguration transaction has no pre-state version");
    let activation_epoch =
        get_on_chain_resource_at_version::<ConfigurationResource>(rest_client, pre_state_version)
            .await
            .epoch()
            .checked_add(1)
            .expect("configuration epoch overflow");
    let activation_version =
        first_new_block_version_for_epoch(rest_client, activation_epoch, time_limit).await;

    (activation_epoch, activation_version)
}

/// Poll the on-chain state until we see a DKG session finishes.
/// Return a `DKGSessionState` of the DKG session seen.
#[allow(dead_code)]
async fn wait_for_dkg_finish(
    client: &Client,
    target_epoch: Option<u64>,
    time_limit_secs: u64,
) -> DKGSessionState {
    let mut dkg_state = utils::get_on_chain_resource::<DKGState>(client).await;
    let timer = Instant::now();
    while timer.elapsed().as_secs() < time_limit_secs
        && !(dkg_state.in_progress.is_none()
            && dkg_state.last_completed.is_some()
            && (target_epoch.is_none()
                || dkg_state
                    .last_completed
                    .as_ref()
                    .map(|session| session.metadata.dealer_epoch + 1)
                    == target_epoch))
    {
        tokio::time::sleep(Duration::from_secs(1)).await;
        dkg_state = utils::get_on_chain_resource::<DKGState>(client).await;
    }
    assert!(timer.elapsed().as_secs() < time_limit_secs);
    dkg_state.last_complete().clone()
}

/// Verify that DKG transcript of epoch i (stored in `new_dkg_state`) is correctly generated
/// by the validator set in epoch i-1 (stored in `new_dkg_state`).
fn verify_dkg_transcript(
    dkg_session: &DKGSessionState,
    decrypt_key_map: &HashMap<AccountAddress, <DefaultDKG as DKGTrait>::NewValidatorDecryptKey>,
) -> Result<()> {
    info!(
        "Verifying the transcript generated in epoch {}.",
        dkg_session.metadata.dealer_epoch,
    );
    let pub_params = DefaultDKG::new_public_params(&dkg_session.metadata);
    let transcript = bcs::from_bytes(dkg_session.transcript.as_slice()).map_err(|e| {
        anyhow!("DKG transcript verification failed with transcript deserialization error: {e}")
    })?;
    println!("transcript={:?}", transcript);
    DefaultDKG::verify_transcript(&pub_params, &transcript)?;

    info!("Double-verifying by reconstructing the dealt secret.");
    let dealt_secret_from_shares = dealt_secret_from_shares(
        dkg_session
            .metadata
            .target_validator_consensus_infos_cloned(),
        decrypt_key_map,
        &pub_params,
        &transcript,
    );

    println!("dealt_secret_from_shares={:?}", dealt_secret_from_shares);

    let dealt_secret_from_inputs = dealt_secret_from_input(
        &transcript,
        &pub_params,
        &pub_params.session_metadata.dealer_consensus_infos_cloned(),
    );
    println!("dealt_secret_from_inputs={:?}", dealt_secret_from_inputs);

    ensure!(
        dealt_secret_from_shares == dealt_secret_from_inputs,
        "dkg transcript verification failed with final check failure"
    );
    Ok(())
}

fn dealt_secret_from_shares(
    target_validator_set: Vec<ValidatorConsensusInfo>,
    decrypt_key_map: &HashMap<AccountAddress, <DefaultDKG as DKGTrait>::NewValidatorDecryptKey>,
    pub_params: &<DefaultDKG as DKGTrait>::PublicParams,
    transcript: &<DefaultDKG as DKGTrait>::Transcript,
) -> <DefaultDKG as DKGTrait>::DealtSecret {
    let player_share_pairs = target_validator_set
        .iter()
        .enumerate()
        .map(|(idx, validator_info)| {
            let dk = decrypt_key_map.get(&validator_info.address).unwrap();
            let (secret_share, _pub_key_share) = DefaultDKG::decrypt_secret_share_from_transcript(
                pub_params, transcript, idx as u64, dk,
            )
            .unwrap();
            (idx as u64, secret_share)
        })
        .collect();

    DefaultDKG::reconstruct_secret_from_shares(pub_params, player_share_pairs).unwrap()
}

fn dealt_secret_from_input(
    trx: &<DefaultDKG as DKGTrait>::Transcript,
    pub_params: &<DefaultDKG as DKGTrait>::PublicParams,
    dealer_validator_infos: &[ValidatorConsensusInfo],
) -> <DefaultDKG as DKGTrait>::DealtSecret {
    let dealers = DefaultDKG::get_dealers(trx);
    println!("dealers={:?}", dealers);
    let input_secrets = dealers
        .into_iter()
        .map(|dealer_idx| {
            let cur_addr = dealer_validator_infos[dealer_idx as usize].address;
            // Same seed is used in `DKGManager::setup_deal_broadcast` for smoke tests.
            let mut rng = StdRng::from_seed(cur_addr.into_bytes());
            <DefaultDKG as DKGTrait>::InputSecret::generate(&mut rng)
        })
        .collect();

    let aggregated_input_secret = DefaultDKG::aggregate_input_secret(input_secrets);
    DefaultDKG::dealt_secret_from_input(pub_params, &aggregated_input_secret)
}

#[allow(dead_code)]
fn num_validators(dkg_state: &DKGSessionState) -> usize {
    dkg_state.metadata.target_validator_set.len()
}

fn decrypt_key_map(
    swarm: &LocalSwarm,
) -> HashMap<AccountAddress, <DefaultDKG as DKGTrait>::NewValidatorDecryptKey> {
    swarm
        .validators()
        .map(|validator| {
            let dk = validator
                .config()
                .consensus
                .safety_rules
                .initial_safety_rules_config
                .identity_blob()
                .unwrap()
                .try_into_dkg_new_validator_decrypt_key()
                .unwrap();
            (validator.peer_id(), dk)
        })
        .collect::<HashMap<_, _>>()
}

/// Fetch the DKG result and the block randomness (from aggregation) for a specific version.
/// Derive the distributed secret from DKG result.
/// Verify that the randomness from aggregation (the actual one store on chain) equals to
/// the randomness from direct evaluation using the distributed secret (the expected one).
async fn verify_randomness(
    decrypt_key_map: &HashMap<AccountAddress, <DefaultDKG as DKGTrait>::NewValidatorDecryptKey>,
    rest_client: &Client,
    version: u64,
) -> Result<()> {
    // Fetch resources.
    let (dkg_state, on_chain_block_randomness) = tokio::join!(
        get_on_chain_resource_at_version::<DKGState>(rest_client, version),
        get_on_chain_resource_at_version::<PerBlockRandomness>(rest_client, version)
    );

    ensure!(
        on_chain_block_randomness.seed.is_some(),
        "randomness verification failed with seed missing"
    );

    // Derive the shared secret.
    let dkg_session = dkg_state
        .last_completed
        .ok_or_else(|| anyhow!("randomness verification failed with missing dkg result"))?;
    let dkg_pub_params = DefaultDKG::new_public_params(&dkg_session.metadata);
    let transcript =
        bcs::from_bytes::<<DefaultDKG as DKGTrait>::Transcript>(dkg_session.transcript.as_slice())
            .map_err(|_| {
                anyhow!(
                "randomness verification failed with on-chain dkg transcript deserialization error"
            )
            })?;
    let dealt_secret = dealt_secret_from_shares(
        dkg_session
            .metadata
            .target_validator_consensus_infos_cloned(),
        decrypt_key_map,
        &dkg_pub_params,
        &transcript,
    );

    // Compare the outputs from 2 paths.
    let rand_metadata = RandMetadata {
        epoch: on_chain_block_randomness.epoch,
        round: on_chain_block_randomness.round,
    };
    let input = bcs::to_bytes(&rand_metadata).unwrap();
    let output = WVUF::eval(&dealt_secret, input.as_slice());
    let output_serialized = bcs::to_bytes(&output).unwrap();
    let expected_randomness_seed = Sha3_256::digest(output_serialized.as_slice()).to_vec();

    ensure!(
        expected_randomness_seed == on_chain_block_randomness.seed.clone().unwrap(),
        "randomness verification failed with final check failure"
    );
    Ok(())
}

fn script_to_enable_main_logic() -> String {
    r#"
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::randomness_config;
    use aptos_std::fixed_point64;

    fun main(core_resources: &signer) {
        let framework_signer = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        let config = randomness_config::new_v1(
            fixed_point64::create_from_rational(1, 2),
            fixed_point64::create_from_rational(2, 3)
        );
        randomness_config::set_for_next_epoch(&framework_signer, config);
        aptos_governance::reconfigure(&framework_signer);
    }
}
"#
    .to_string()
}

fn script_to_disable_main_logic() -> String {
    r#"
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::randomness_config;
    fun main(core_resources: &signer) {
        let framework_signer = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        let config = randomness_config::new_off();
        randomness_config::set_for_next_epoch(&framework_signer, config);
        aptos_governance::reconfigure(&framework_signer);
    }
}
"#
    .to_string()
}

fn script_to_update_consensus_config(config: &OnChainConsensusConfig) -> String {
    let config_bytes = bcs::to_bytes(config).unwrap();
    format!(
        r#"
script {{
    use aptos_framework::aptos_governance;
    use aptos_framework::consensus_config;

    fun main(core_resources: &signer) {{
        let framework_signer = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        let config_bytes = vector{:?};
        consensus_config::set_for_next_epoch(&framework_signer, config_bytes);
        aptos_governance::reconfigure(&framework_signer);
    }}
}}
    "#,
        config_bytes
    )
}

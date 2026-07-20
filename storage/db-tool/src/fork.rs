// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use anyhow::{ensure, format_err, Context, Result};
use aptos_config::config::{
    InitialSafetyRulesConfig, NodeConfig, RocksdbConfigs, StorageDirPaths, WaypointConfig,
    BUFFERED_STATE_TARGET_ITEMS, DEFAULT_MAX_NUM_NODES_PER_LRU_CACHE_SHARD,
    NO_OP_STORAGE_PRUNER_CONFIG,
};
use aptos_db::AptosDB;
use aptos_executor::db_bootstrapper::{calculate_genesis, generate_waypoint};
use aptos_genesis::builder::{validator_set_from_local_validators, Builder, ValidatorNodeConfig};
use aptos_storage_interface::{
    state_store::state_view::db_state_view::LatestDbStateCheckpointView, DbReaderWriter,
};
use aptos_types::{
    account_address::AccountAddress,
    account_config::{
        new_block_event_key, BlockResource, ChainIdResource, NewBlockEvent, CORE_CODE_ADDRESS,
        NEW_EPOCH_EVENT_V2_MOVE_TYPE_TAG,
    },
    chain_id::ChainId,
    contract_event::ContractEvent,
    event::EventHandle,
    on_chain_config::{
        CommitHistoryResource, ConfigurationResource, CurrentTimeMicroseconds, OnChainConfig,
        ValidatorSet,
    },
    state_store::{state_key::StateKey, table::TableHandle, TStateView},
    transaction::{ChangeSet, Transaction, WriteSetPayload},
    validator_config::ValidatorConfig,
    validator_performances::{ValidatorPerformance, ValidatorPerformances},
    waypoint::Waypoint,
    write_set::{WriteOp, WriteSetMut},
};
use aptos_vm::aptos_vm::AptosVMBlockExecutor;
use clap::Parser;
use move_core_types::{
    language_storage::TypeTag, move_resource::MoveStructType, parser::parse_struct_tag,
};
use rand::rngs::OsRng;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::{
    collections::HashSet,
    fs::{self, File},
    io::Write,
    num::NonZeroUsize,
    path::{Path, PathBuf},
};

const GENESIS_BLOB: &str = "genesis.blob";
const MANIFEST: &str = "fork-manifest.json";
const VALIDATOR_IDENTITY: &str = "validator-identity.yaml";

#[derive(Parser)]
#[clap(
    name = "aptos-db-fork",
    about = "Copy a local Aptos DB and commit a fork reconfiguration with a new chain ID and local validator set."
)]
pub struct Command {
    #[clap(long, value_parser)]
    source_db_dir: PathBuf,

    #[clap(long, value_parser)]
    output_db_dir: PathBuf,

    #[clap(long, value_parser)]
    config_dir: Option<PathBuf>,

    #[clap(long, value_parser)]
    fork_chain_id: u8,

    #[clap(long, default_value_t = 1)]
    validators: usize,

    #[clap(long)]
    enable_storage_sharding: bool,
}

impl Command {
    pub fn run(self) -> Result<()> {
        let validators = NonZeroUsize::new(self.validators)
            .ok_or_else(|| format_err!("--validators must be greater than 0"))?;
        let fork_chain_id = validate_requested_chain_id(self.fork_chain_id)?;
        validate_output_paths(&self.source_db_dir, &self.output_db_dir)?;
        let config_dir = self
            .config_dir
            .clone()
            .unwrap_or_else(|| default_config_dir(&self.output_db_dir));
        validate_config_path(&self.source_db_dir, &self.output_db_dir, &config_dir)?;

        let source_info = inspect_db(&self.source_db_dir, self.enable_storage_sharding, false)
            .with_context(|| format!("failed to inspect source DB {:?}", self.source_db_dir))?;
        ensure!(
            fork_chain_id != source_info.chain_id,
            "fork chain ID must differ from source chain ID {}",
            source_info.chain_id.id(),
        );

        fs::create_dir_all(&self.output_db_dir)
            .with_context(|| format!("failed to create {:?}", self.output_db_dir))?;
        AptosDB::create_checkpoint(
            &self.source_db_dir,
            &self.output_db_dir,
            self.enable_storage_sharding,
        )
        .with_context(|| {
            format!(
                "failed to create checkpoint from {:?} to {:?}",
                self.source_db_dir, self.output_db_dir
            )
        })?;

        fs::create_dir_all(&config_dir)
            .with_context(|| format!("failed to create config dir {:?}", config_dir))?;
        let (_root_key, generated_genesis, _generated_waypoint, validators) = Builder::new(
            &config_dir,
            aptos_cached_packages::head_release_bundle().clone(),
        )?
        .with_num_validators(validators)
        .build(OsRng)?;
        let validator_set = validator_set_from_local_validators(&validators)?;
        let generated_validator_addresses = validator_set.active_validators();

        let (fork_txn, waypoint) = commit_fork_transaction(
            &self.output_db_dir,
            self.enable_storage_sharding,
            fork_chain_id,
            &validator_set,
            &generated_genesis,
        )?;

        let output_info = inspect_db(&self.output_db_dir, self.enable_storage_sharding, true)
            .with_context(|| format!("failed to inspect output DB {:?}", self.output_db_dir))?;
        ensure!(
            output_info.chain_id == fork_chain_id,
            "output chain ID readback mismatch: expected {}, got {}",
            fork_chain_id.id(),
            output_info.chain_id.id(),
        );
        ensure!(
            output_info.validator_set == validator_set,
            "output ValidatorSet readback mismatch",
        );
        ensure!(
            output_info.waypoint == Some(waypoint),
            "output waypoint readback mismatch: manifest {}, DB {}",
            waypoint,
            output_info
                .waypoint
                .map(|waypoint| waypoint.to_string())
                .unwrap_or_else(|| "<none>".to_string()),
        );
        ensure!(
            output_info.validator_set != source_info.validator_set,
            "fork did not replace ValidatorSet",
        );

        let node_config_paths = write_fork_configs(
            &validators,
            &self.output_db_dir,
            &fork_txn,
            waypoint,
            fork_chain_id,
            self.enable_storage_sharding,
        )?;
        let manifest_path = write_manifest(
            &config_dir,
            &self.source_db_dir,
            &self.output_db_dir,
            &node_config_paths,
            &source_info,
            &output_info,
            fork_chain_id,
            &generated_validator_addresses,
        )?;

        println!("Fork DB written to: {}", self.output_db_dir.display());
        println!("Fork waypoint: {}", waypoint);
        println!("Fork manifest: {}", manifest_path.display());
        Ok(())
    }
}

#[derive(Clone)]
struct DbInfo {
    version: u64,
    chain_id: ChainId,
    validator_set: ValidatorSet,
    waypoint: Option<Waypoint>,
    accumulator_root: String,
    state_root: String,
    epoch: u64,
    next_epoch: Option<u64>,
    new_block_event_count: u64,
    block_height: u64,
    current_time_microseconds: u64,
    commit_history_length: Option<u64>,
    commit_history_next_idx: Option<u32>,
}

#[derive(Deserialize, Serialize)]
struct BlockResourceWrite {
    height: u64,
    epoch_interval: u64,
    new_block_events: EventHandle,
    update_epoch_interval_events: EventHandle,
}

#[derive(Deserialize, Serialize)]
struct TableWithLengthWrite {
    handle: TableHandle,
    length: u64,
}

#[derive(Deserialize, Serialize)]
struct CommitHistoryResourceWrite {
    max_capacity: u32,
    next_idx: u32,
    table: TableWithLengthWrite,
}

fn validate_requested_chain_id(chain_id: u8) -> Result<ChainId> {
    ensure!(
        chain_id != 0 && chain_id != 1,
        "fork chain ID must not be 0 or mainnet (1)",
    );
    Ok(ChainId::new(chain_id))
}

fn validate_output_paths(source_db_dir: &Path, output_db_dir: &Path) -> Result<()> {
    ensure!(source_db_dir.exists(), "source DB dir does not exist");
    ensure!(
        !output_db_dir.exists(),
        "output DB dir already exists; refusing to mutate an existing path",
    );
    let source = source_db_dir.canonicalize()?;
    let output_parent = output_db_dir
        .parent()
        .unwrap_or_else(|| Path::new("."))
        .canonicalize()?;
    let output_name = output_db_dir
        .file_name()
        .ok_or_else(|| format_err!("output DB dir must name a child path"))?;
    let output = output_parent.join(output_name);
    ensure!(source != output, "source and output DB paths must differ");
    ensure!(
        !output.starts_with(&source) && !source.starts_with(&output),
        "source and output DB paths must not be nested",
    );
    Ok(())
}

fn validate_config_path(
    source_db_dir: &Path,
    output_db_dir: &Path,
    config_dir: &Path,
) -> Result<()> {
    if config_dir.exists() {
        ensure!(
            config_dir.read_dir()?.next().is_none(),
            "config dir already exists and is not empty",
        );
    }
    let source = source_db_dir.canonicalize()?;
    let output = output_db_dir
        .parent()
        .unwrap_or_else(|| Path::new("."))
        .canonicalize()?
        .join(
            output_db_dir
                .file_name()
                .ok_or_else(|| format_err!("output DB dir must name a child path"))?,
        );
    let config_parent = config_dir
        .parent()
        .unwrap_or_else(|| Path::new("."))
        .canonicalize()?;
    let config_name = config_dir
        .file_name()
        .ok_or_else(|| format_err!("config dir must name a child path"))?;
    let config = config_parent.join(config_name);
    ensure!(
        !config.starts_with(&source),
        "config dir must not be nested under source DB dir",
    );
    ensure!(
        !config.starts_with(&output),
        "config dir must not be nested under output DB dir",
    );
    Ok(())
}

fn default_config_dir(output_db_dir: &Path) -> PathBuf {
    let name = output_db_dir
        .file_name()
        .map(|name| format!("{}-configs", name.to_string_lossy()))
        .unwrap_or_else(|| "fork-configs".to_string());
    output_db_dir
        .parent()
        .unwrap_or_else(|| Path::new("."))
        .join(name)
}

fn inspect_db(db_dir: &Path, sharding: bool, require_epoch_waypoint: bool) -> Result<DbInfo> {
    let db = open_db(db_dir, true, sharding)?;
    let view = db.reader.latest_state_checkpoint_view()?;
    let chain_id = ChainIdResource::fetch_config(&view)
        .ok_or_else(|| format_err!("ChainIdResource missing"))?
        .chain_id();
    let validator_set =
        ValidatorSet::fetch_config(&view).ok_or_else(|| format_err!("ValidatorSet missing"))?;
    let block_resource = view
        .get_state_value_bytes(&StateKey::resource_typed::<BlockResource>(&CORE_CODE_ADDRESS)?)?
        .ok_or_else(|| format_err!("BlockResource missing"))?;
    let block_resource = bcs::from_bytes::<BlockResource>(&block_resource)?;
    let current_time = CurrentTimeMicroseconds::fetch_config(&view)
        .ok_or_else(|| format_err!("CurrentTimeMicroseconds missing"))?;
    let commit_history = CommitHistoryResource::fetch_config(&view);
    let ledger_info = db.reader.get_latest_ledger_info()?;
    let ledger_summary = db.reader.get_pre_committed_ledger_summary()?;
    let waypoint = if ledger_info.ledger_info().ends_epoch() {
        Some(Waypoint::new_epoch_boundary(ledger_info.ledger_info())?)
    } else {
        ensure!(
            !require_epoch_waypoint,
            "latest ledger info is not an epoch boundary",
        );
        None
    };
    Ok(DbInfo {
        version: ledger_info.ledger_info().version(),
        chain_id,
        validator_set,
        waypoint,
        accumulator_root: ledger_info
            .ledger_info()
            .commit_info()
            .executed_state_id()
            .to_string(),
        state_root: ledger_summary.state_summary.root_hash().to_string(),
        epoch: ledger_info.ledger_info().epoch(),
        next_epoch: ledger_info
            .ledger_info()
            .next_epoch_state()
            .map(|state| state.epoch),
        new_block_event_count: block_resource.new_block_events().count(),
        block_height: block_resource.height(),
        current_time_microseconds: current_time.microseconds,
        commit_history_length: commit_history.as_ref().map(CommitHistoryResource::length),
        commit_history_next_idx: commit_history
            .as_ref()
            .map(CommitHistoryResource::next_idx),
    })
}

fn commit_fork_transaction(
    output_db_dir: &Path,
    sharding: bool,
    fork_chain_id: ChainId,
    validator_set: &ValidatorSet,
    generated_genesis: &Transaction,
) -> Result<(Transaction, Waypoint)> {
    let db = open_db(output_db_dir, false, sharding)?;
    let view = db.reader.latest_state_checkpoint_view()?;
    let configuration = ConfigurationResource::fetch_config(&view)
        .ok_or_else(|| format_err!("ConfigurationResource missing"))?;
    let source_validator_set =
        ValidatorSet::fetch_config(&view).ok_or_else(|| format_err!("ValidatorSet missing"))?;
    let current_time = CurrentTimeMicroseconds::fetch_config(&view)
        .ok_or_else(|| format_err!("CurrentTimeMicroseconds missing"))?;
    let block_resource_key = StateKey::resource_typed::<BlockResource>(&CORE_CODE_ADDRESS)?;
    let block_resource = view
        .get_state_value_bytes(&block_resource_key)?
        .ok_or_else(|| format_err!("BlockResource missing"))?;
    let mut block_resource = bcs::from_bytes::<BlockResourceWrite>(&block_resource)?;
    let new_block_event_sequence = block_resource.new_block_events.count();
    block_resource.height = new_block_event_sequence;
    *block_resource.new_block_events.count_mut() = new_block_event_sequence + 1;
    let next_configuration = configuration.bump_epoch_for_reconfiguration();
    let new_block_event = NewBlockEvent::new(
        CORE_CODE_ADDRESS,
        configuration.epoch(),
        u64::MAX,
        new_block_event_sequence,
        vec![],
        AccountAddress::ZERO,
        vec![],
        current_time.microseconds,
    );
    let mut writes = vec![
        (
            StateKey::on_chain_config::<ChainIdResource>()?,
            WriteOp::legacy_modification(
                bcs::to_bytes(&ChainIdResource::new(fork_chain_id))?.into(),
            ),
        ),
        (
            StateKey::on_chain_config::<ValidatorSet>()?,
            WriteOp::legacy_modification(bcs::to_bytes(validator_set)?.into()),
        ),
        (
            StateKey::on_chain_config::<ConfigurationResource>()?,
            WriteOp::legacy_modification(bcs::to_bytes(&next_configuration)?.into()),
        ),
        (
            block_resource_key,
            WriteOp::legacy_modification(bcs::to_bytes(&block_resource)?.into()),
        ),
    ];
    writes.extend(commit_history_writes(&view, &new_block_event)?);
    writes.extend(validator_config_writes(
        &view,
        &source_validator_set,
        validator_set,
    )?);
    writes.extend(validator_stake_writes(
        &view,
        validator_set,
        generated_genesis,
    )?);
    let ledger_summary = db.reader.get_pre_committed_ledger_summary()?;
    let fork_txn = Transaction::GenesisTransaction(WriteSetPayload::Direct(ChangeSet::new(
        WriteSetMut::new(writes).freeze()?,
        vec![
            ContractEvent::new_v2(NEW_EPOCH_EVENT_V2_MOVE_TYPE_TAG.clone(), vec![])?,
            ContractEvent::new_v1(
                new_block_event_key(),
                new_block_event_sequence,
                TypeTag::Struct(Box::new(NewBlockEvent::struct_tag())),
                bcs::to_bytes(&new_block_event)?,
            )?,
        ],
    )));
    let waypoint = generate_waypoint::<AptosVMBlockExecutor>(&db, &fork_txn)?;
    let committer = calculate_genesis::<AptosVMBlockExecutor>(&db, ledger_summary, &fork_txn)?;
    ensure!(
        waypoint == committer.waypoint(),
        "fork waypoint changed between calculation passes",
    );
    committer.commit()?;
    Ok((fork_txn, waypoint))
}

fn validator_stake_writes(
    view: &impl TStateView<Key = StateKey>,
    validator_set: &ValidatorSet,
    generated_genesis: &Transaction,
) -> Result<Vec<(StateKey, WriteOp)>> {
    let Transaction::GenesisTransaction(WriteSetPayload::Direct(generated_change_set)) =
        generated_genesis
    else {
        return Err(format_err!(
            "generated validator genesis must be a direct write-set"
        ));
    };
    let stake_pool_tag = parse_struct_tag("0x1::stake::StakePool")?;
    let mut writes = Vec::with_capacity(validator_set.num_validators() + 1);
    for validator in validator_set.active_validators() {
        let stake_pool_key = StateKey::resource(&validator, &stake_pool_tag)?;
        ensure!(
            view.get_state_value_bytes(&stake_pool_key)?.is_none(),
            "generated validator address {} already has a StakePool in source state",
            validator,
        );
        let stake_pool_write = generated_change_set
            .write_set()
            .get_write_op(&stake_pool_key)
            .cloned()
            .ok_or_else(|| {
                format_err!(
                    "generated genesis is missing StakePool for validator {}",
                    validator
                )
            })?;
        writes.push((stake_pool_key, stake_pool_write));
    }

    let validator_performance_key = StateKey::resource(
        &CORE_CODE_ADDRESS,
        &parse_struct_tag("0x1::stake::ValidatorPerformance")?,
    )?;
    let validator_performances = ValidatorPerformances {
        validators: vec![
            ValidatorPerformance {
                successful_proposals: 0,
                failed_proposals: 0,
            };
            validator_set.num_validators()
        ],
    };
    writes.push((
        validator_performance_key,
        WriteOp::legacy_modification(bcs::to_bytes(&validator_performances)?.into()),
    ));
    Ok(writes)
}

fn commit_history_writes(
    view: &impl TStateView<Key = StateKey>,
    new_block_event: &NewBlockEvent,
) -> Result<Vec<(StateKey, WriteOp)>> {
    let commit_history_key = StateKey::on_chain_config::<CommitHistoryResource>()?;
    let Some(commit_history) = view.get_state_value_bytes(&commit_history_key)? else {
        return Ok(vec![]);
    };
    let mut commit_history = bcs::from_bytes::<CommitHistoryResourceWrite>(&commit_history)?;
    ensure!(
        commit_history.max_capacity > 0,
        "CommitHistory max_capacity must be non-zero",
    );
    let table_key = bcs::to_bytes(&commit_history.next_idx)?;
    let table_state_key = StateKey::table_item(&commit_history.table.handle, &table_key);
    let replacing_existing_slot = view.get_state_value_bytes(&table_state_key)?.is_some();
    let table_write_op = if replacing_existing_slot {
        WriteOp::legacy_modification(bcs::to_bytes(new_block_event)?.into())
    } else {
        commit_history.table.length += 1;
        WriteOp::legacy_creation(bcs::to_bytes(new_block_event)?.into())
    };
    commit_history.next_idx = (commit_history.next_idx + 1) % commit_history.max_capacity;
    Ok(vec![
        (table_state_key, table_write_op),
        (
            commit_history_key,
            WriteOp::legacy_modification(bcs::to_bytes(&commit_history)?.into()),
        ),
    ])
}

fn validator_config_writes(
    view: &impl TStateView<Key = StateKey>,
    source_validator_set: &ValidatorSet,
    validator_set: &ValidatorSet,
) -> Result<Vec<(StateKey, WriteOp)>> {
    let new_addresses = validator_set
        .active_validators
        .iter()
        .chain(validator_set.pending_inactive.iter())
        .chain(validator_set.pending_active.iter())
        .map(|validator| validator.account_address)
        .collect::<HashSet<_>>();
    let mut writes = vec![];
    for validator in source_validator_set
        .active_validators
        .iter()
        .chain(source_validator_set.pending_inactive.iter())
        .chain(source_validator_set.pending_active.iter())
    {
        if new_addresses.contains(&validator.account_address) {
            continue;
        }
        let key = StateKey::resource_typed::<ValidatorConfig>(&validator.account_address)?;
        if view.get_state_value_bytes(&key)?.is_some() {
            writes.push((key, WriteOp::legacy_deletion()));
        }
    }

    for validator in validator_set
        .active_validators
        .iter()
        .chain(validator_set.pending_inactive.iter())
        .chain(validator_set.pending_active.iter())
    {
        let key = StateKey::resource_typed::<ValidatorConfig>(&validator.account_address)?;
        let bytes = bcs::to_bytes(validator.config())?.into();
        let write_op = if view.get_state_value_bytes(&key)?.is_some() {
            WriteOp::legacy_modification(bytes)
        } else {
            WriteOp::legacy_creation(bytes)
        };
        writes.push((key, write_op));
    }
    Ok(writes)
}

fn open_db(db_dir: &Path, readonly: bool, sharding: bool) -> Result<DbReaderWriter> {
    let rocksdb_configs = RocksdbConfigs {
        enable_storage_sharding: sharding,
        ..Default::default()
    };
    let db = AptosDB::open(
        StorageDirPaths::from_path(db_dir),
        readonly,
        NO_OP_STORAGE_PRUNER_CONFIG,
        rocksdb_configs,
        false,
        BUFFERED_STATE_TARGET_ITEMS,
        DEFAULT_MAX_NUM_NODES_PER_LRU_CACHE_SHARD,
        None,
    )?;
    Ok(DbReaderWriter::new(db))
}

fn write_fork_configs(
    validators: &[ValidatorNodeConfig],
    output_db_dir: &Path,
    fork_txn: &Transaction,
    waypoint: Waypoint,
    fork_chain_id: ChainId,
    enable_storage_sharding: bool,
) -> Result<Vec<PathBuf>> {
    validators
        .iter()
        .map(|validator| {
            let config_path = validator.validator_config_path();
            let mut config = NodeConfig::load_from_path(&config_path)?;
            let validator_db_dir = validator.dir.join("fork-db");
            fs::create_dir_all(&validator_db_dir).with_context(|| {
                format!(
                    "failed to create validator {} DB directory at {:?}",
                    validator.index, validator_db_dir
                )
            })?;
            AptosDB::create_checkpoint(
                output_db_dir,
                &validator_db_dir,
                enable_storage_sharding,
            )
            .with_context(|| {
                format!(
                    "failed to create validator {} DB checkpoint at {:?}",
                    validator.index, validator_db_dir
                )
            })?;
            config.storage.dir = validator_db_dir;
            config.base.waypoint = WaypointConfig::FromConfig(waypoint);
            config.execution.genesis = Some(fork_txn.clone());
            config.execution.genesis_waypoint = Some(WaypointConfig::FromConfig(waypoint));
            config.execution.genesis_file_location = validator.dir.join(GENESIS_BLOB);
            config.consensus.safety_rules.initial_safety_rules_config =
                InitialSafetyRulesConfig::from_file(
                    validator.dir.join(VALIDATOR_IDENTITY),
                    vec![],
                    WaypointConfig::FromConfig(waypoint),
                );
            File::create(&config.execution.genesis_file_location)?
                .write_all(&bcs::to_bytes(fork_txn)?)?;
            config.save_to_path(&config_path)?;
            fs::write(
                validator.dir.join("chain_id"),
                fork_chain_id.id().to_string(),
            )?;
            Ok(config_path)
        })
        .collect()
}

fn write_manifest(
    config_dir: &Path,
    source_db_dir: &Path,
    output_db_dir: &Path,
    node_config_paths: &[PathBuf],
    source_info: &DbInfo,
    output_info: &DbInfo,
    fork_chain_id: ChainId,
    validator_addresses: &[AccountAddress],
) -> Result<PathBuf> {
    let manifest = json!({
        "source_db_dir": source_db_dir,
        "output_db_dir": output_db_dir,
        "source_ledger": ledger_json(source_info),
        "output_ledger": ledger_json(output_info),
        "chain_id_change": {
            "source": source_info.chain_id.id(),
            "fork": fork_chain_id.id(),
        },
        "validator_replacement": {
            "source_validator_count": source_info.validator_set.num_validators(),
            "fork_validator_count": output_info.validator_set.num_validators(),
            "source_validator_addresses": source_info.validator_set.active_validators(),
            "fork_validator_addresses": validator_addresses,
        },
        "generated_config_paths": node_config_paths,
        "waypoint": output_info.waypoint.map(|waypoint| waypoint.to_string()),
    });
    let manifest_path = config_dir.join(MANIFEST);
    fs::write(&manifest_path, serde_json::to_vec_pretty(&manifest)?)?;
    Ok(manifest_path)
}

fn ledger_json(info: &DbInfo) -> serde_json::Value {
    json!({
        "version": info.version,
        "epoch": info.epoch,
        "next_epoch": info.next_epoch,
        "waypoint": info.waypoint.map(|waypoint| waypoint.to_string()),
        "accumulator_root": info.accumulator_root,
        "state_root": info.state_root,
        "chain_id": info.chain_id.id(),
        "new_block_event_count": info.new_block_event_count,
        "block_height": info.block_height,
        "current_time_microseconds": info.current_time_microseconds,
        "commit_history_length": info.commit_history_length,
        "commit_history_next_idx": info.commit_history_next_idx,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use aptos_cached_packages::aptos_stdlib;
    use aptos_crypto::PrivateKey;
    use aptos_executor::block_executor::BlockExecutor;
    use aptos_executor_test_helpers::{bootstrap_genesis, gen_block_id};
    use aptos_executor_types::BlockExecutorTrait;
    use aptos_temppath::TempPath;
    use aptos_types::{
        aggregate_signature::AggregateSignature,
        block_info::BlockInfo,
        account_config::AccountResource,
        ledger_info::{LedgerInfo, LedgerInfoWithSignatures},
        test_helpers::transaction_test_helpers::{
            block, get_test_signed_transaction, TEST_BLOCK_EXECUTOR_ONCHAIN_CONFIG,
        },
    };
    use std::{
        process::{Child, Command as ProcessCommand, Stdio},
        time::Duration,
    };

    struct NodeProcesses(Vec<Child>);

    impl Drop for NodeProcesses {
        fn drop(&mut self) {
            for child in &mut self.0 {
                let _ = child.kill();
                let _ = child.wait();
            }
        }
    }

    #[test]
    fn rejects_reserved_chain_ids() {
        assert!(validate_requested_chain_id(0).is_err());
        assert!(validate_requested_chain_id(1).is_err());
        assert_eq!(validate_requested_chain_id(42).unwrap().id(), 42);
    }

    #[test]
    fn rejects_aliasing_and_nested_output_paths() {
        let root = TempPath::new();
        root.create_as_dir().unwrap();
        let source = root.path().join("source");
        fs::create_dir_all(&source).unwrap();
        assert!(validate_output_paths(&source, &source).is_err());
        assert!(validate_output_paths(&source, &source.join("child")).is_err());
        assert!(validate_output_paths(&source, &root.path().join("output")).is_ok());
    }

    fn bootstrap_source_db() -> (
        TempPath,
        TempPath,
        aptos_crypto::ed25519::Ed25519PrivateKey,
        Vec<ValidatorNodeConfig>,
    ) {
        let source_db_dir = TempPath::new();
        source_db_dir.create_as_dir().unwrap();
        let source_config_dir = TempPath::new();
        source_config_dir.create_as_dir().unwrap();
        let (root_key, genesis, _waypoint, validators) = Builder::new(
            source_config_dir.path(),
            aptos_cached_packages::head_release_bundle().clone(),
        )
        .unwrap()
        .with_num_validators(NonZeroUsize::new(1).unwrap())
        .build(OsRng)
        .unwrap();

        {
            let source_db = DbReaderWriter::new(AptosDB::new_for_test(source_db_dir.path()));
            bootstrap_genesis::<AptosVMBlockExecutor>(&source_db, &genesis).unwrap();
        }

        (source_db_dir, source_config_dir, root_key, validators)
    }

    fn commit_non_reconfiguration_transaction(
        source_db_dir: &Path,
        root_key: aptos_crypto::ed25519::Ed25519PrivateKey,
    ) {
        let db = open_db(source_db_dir, false, false).unwrap();
        let block_id = gen_block_id(7);
        let txn = Transaction::UserTransaction(get_test_signed_transaction(
            aptos_types::account_config::aptos_test_root_address(),
            0,
            &root_key,
            root_key.public_key(),
            Some(aptos_stdlib::aptos_account_create_account(
                AccountAddress::TWO,
            )),
            u64::MAX,
            0,
            None,
        ));
        let executor = BlockExecutor::<AptosVMBlockExecutor>::new(db.clone());
        let output = executor
            .execute_block(
                (block_id, block(vec![txn])).into(),
                executor.committed_block_id(),
                TEST_BLOCK_EXECUTOR_ONCHAIN_CONFIG,
            )
            .unwrap();
        let latest_li = db.reader.get_latest_ledger_info().unwrap();
        let ledger_info_with_sigs = LedgerInfoWithSignatures::new(
            LedgerInfo::new(
                BlockInfo::new(
                    latest_li.ledger_info().next_block_epoch(),
                    0,
                    block_id,
                    output.root_hash(),
                    output.expect_last_version(),
                    0,
                    None,
                ),
                gen_block_id(0),
            ),
            AggregateSignature::empty(),
        );
        executor
            .commit_blocks(vec![block_id], ledger_info_with_sigs)
            .unwrap();
        assert!(inspect_db(source_db_dir, false, false)
            .unwrap()
            .waypoint
            .is_none());
    }

    fn read_validator_config(db_dir: &Path, address: AccountAddress) -> Option<ValidatorConfig> {
        let db = open_db(db_dir, true, false).unwrap();
        let view = db.reader.latest_state_checkpoint_view().unwrap();
        let bytes = view
            .get_state_value_bytes(&StateKey::resource_typed::<ValidatorConfig>(&address).unwrap())
            .unwrap()?;
        Some(bcs::from_bytes(&bytes).unwrap())
    }

    fn read_account_resource(db_dir: &Path, address: AccountAddress) -> Option<AccountResource> {
        let db = open_db(db_dir, true, false).unwrap();
        let view = db.reader.latest_state_checkpoint_view().unwrap();
        let bytes = view
            .get_state_value_bytes(&StateKey::resource_typed::<AccountResource>(&address).unwrap())
            .unwrap()?;
        Some(bcs::from_bytes(&bytes).unwrap())
    }

    fn resource_exists(db_dir: &Path, address: AccountAddress, type_name: &str) -> bool {
        let db = open_db(db_dir, true, false).unwrap();
        let view = db.reader.latest_state_checkpoint_view().unwrap();
        view.get_state_value_bytes(
            &StateKey::resource(&address, &parse_struct_tag(type_name).unwrap()).unwrap(),
        )
        .unwrap()
        .is_some()
    }

    #[test]
    fn fork_commits_chain_id_validator_set_and_waypoint_to_output_db() {
        let (source_db_dir, _source_config_dir, root_key, _validators) = bootstrap_source_db();
        commit_non_reconfiguration_transaction(source_db_dir.path(), root_key);

        let source_info_before = inspect_db(source_db_dir.path(), false, false).unwrap();
        assert!(
            source_info_before.version > 0,
            "source DB must have committed post-genesis transactions before fork",
        );
        let source_account = read_account_resource(source_db_dir.path(), AccountAddress::TWO)
            .expect("0x2::account::Account must exist before fork");
        assert_eq!(source_account.sequence_number(), 0);
        let source_validator = source_info_before
            .validator_set
            .active_validators
            .first()
            .unwrap();
        let source_validator_address = source_validator.account_address;
        let source_validator_config = read_validator_config(
            source_db_dir.path(),
            source_validator_address,
        )
        .expect("source validator config must exist before fork");
        assert_eq!(&source_validator_config, source_validator.config());
        let output_root = TempPath::new();
        output_root.create_as_dir().unwrap();
        let output_db_dir = output_root.path().join("fork-db");
        let config_dir = output_root.path().join("fork-configs");
        let fork_chain_id = ChainId::new(42);

        Command {
            source_db_dir: source_db_dir.path().to_path_buf(),
            output_db_dir: output_db_dir.clone(),
            config_dir: Some(config_dir.clone()),
            fork_chain_id: fork_chain_id.id(),
            validators: 2,
            enable_storage_sharding: false,
        }
        .run()
        .unwrap();

        let source_info_after = inspect_db(source_db_dir.path(), false, false).unwrap();
        let output_info = inspect_db(&output_db_dir, false, true).unwrap();
        assert_eq!(source_info_after.chain_id, source_info_before.chain_id);
        assert_eq!(
            source_info_after.validator_set,
            source_info_before.validator_set
        );
        assert_eq!(
            read_validator_config(source_db_dir.path(), source_validator_address).unwrap(),
            source_validator_config,
        );
        assert_eq!(
            read_account_resource(source_db_dir.path(), AccountAddress::TWO).unwrap(),
            source_account,
        );
        assert_eq!(output_info.chain_id, fork_chain_id);
        assert_ne!(output_info.chain_id, source_info_before.chain_id);
        assert_ne!(output_info.validator_set, source_info_before.validator_set);
        assert_eq!(output_info.validator_set.num_validators(), 2);
        for validator in output_info.validator_set.active_validators() {
            assert!(
                resource_exists(&output_db_dir, validator, "0x1::stake::StakePool"),
                "replacement validator must have a StakePool",
            );
        }
        assert_eq!(
            output_info.waypoint.unwrap().version(),
            source_info_before.version + 1
        );
        assert!(output_info.next_epoch.is_some());
        assert!(config_dir.join(MANIFEST).exists());
        assert_eq!(
            output_info.new_block_event_count,
            source_info_before.new_block_event_count + 1
        );
        assert_eq!(
            output_info.block_height,
            source_info_before.new_block_event_count
        );
        assert_eq!(
            output_info.current_time_microseconds,
            source_info_before.current_time_microseconds
        );
        assert_eq!(
            output_info.commit_history_length,
            source_info_before
                .commit_history_length
                .map(|length| length + 1)
        );
        assert_eq!(
            output_info.commit_history_next_idx,
            source_info_before
                .commit_history_next_idx
                .map(|next_idx| next_idx + 1)
        );
        assert_eq!(
            read_account_resource(&output_db_dir, AccountAddress::TWO).unwrap(),
            source_account,
        );
        for validator_index in 0..2 {
            let validator_db_dir = config_dir
                .join(validator_index.to_string())
                .join("fork-db");
            let validator_info = inspect_db(&validator_db_dir, false, true).unwrap();
            assert_eq!(validator_info.chain_id, fork_chain_id);
            assert_eq!(validator_info.validator_set, output_info.validator_set);
            assert_eq!(
                read_account_resource(&validator_db_dir, AccountAddress::TWO).unwrap(),
                source_account,
            );
            let node_config = NodeConfig::load_from_path(
                &config_dir
                    .join(validator_index.to_string())
                    .join("node.yaml"),
            )
            .unwrap();
            assert_eq!(
                node_config.storage.dir().canonicalize().unwrap(),
                validator_db_dir.canonicalize().unwrap(),
            );
        }

        let output_validator = output_info
            .validator_set
            .active_validators
            .first()
            .unwrap();
        let output_validator_address = output_validator.account_address;
        assert_ne!(output_validator_address, source_validator_address);
        assert!(
            read_validator_config(&output_db_dir, source_validator_address).is_none(),
            "old validator config must not remain in fork output",
        );
        let output_validator_config =
            read_validator_config(&output_db_dir, output_validator_address)
                .expect("generated validator config must exist in fork output");
        assert_eq!(&output_validator_config, output_validator.config());
        assert_ne!(
            output_validator_config.validator_network_addresses,
            source_validator_config.validator_network_addresses,
        );
        assert_ne!(
            output_validator_config.fullnode_network_addresses,
            source_validator_config.fullnode_network_addresses,
        );
        assert_ne!(
            output_validator_config.consensus_public_key,
            source_validator_config.consensus_public_key,
        );

        let genesis_txn = {
            let bytes = fs::read(config_dir.join("0").join(GENESIS_BLOB)).unwrap();
            bcs::from_bytes::<Transaction>(&bytes).unwrap()
        };
        let Transaction::GenesisTransaction(WriteSetPayload::Direct(change_set)) = genesis_txn else {
            panic!("fork transaction must be a direct genesis write-set");
        };
        let new_block_event = change_set
            .events()
            .iter()
            .find(|event| event.event_key() == Some(&new_block_event_key()))
            .expect("fork transaction must emit NewBlockEvent");
        assert_eq!(
            new_block_event.v1().unwrap().sequence_number(),
            source_info_before.new_block_event_count
        );
        let new_block_event = NewBlockEvent::try_from_bytes(new_block_event.event_data()).unwrap();
        assert_eq!(new_block_event.height(), source_info_before.new_block_event_count);
        assert_eq!(new_block_event.round(), u64::MAX);
        assert_eq!(new_block_event.proposer(), AccountAddress::ZERO);
        assert_eq!(
            new_block_event.proposed_time(),
            source_info_before.current_time_microseconds,
        );
    }

    #[tokio::test]
    #[ignore = "requires APTOS_NODE_BINARY pointing to an aptos-node binary"]
    async fn two_validator_fork_bootstraps_and_commits_blocks() {
        let node_binary = PathBuf::from(
            std::env::var_os("APTOS_NODE_BINARY")
                .expect("APTOS_NODE_BINARY must point to an aptos-node binary"),
        );
        let node_binary = if node_binary.is_absolute() {
            node_binary
        } else {
            Path::new(env!("CARGO_MANIFEST_DIR"))
                .join("../..")
                .join(node_binary)
        }
        .canonicalize()
        .expect("APTOS_NODE_BINARY must resolve to an aptos-node binary");
        let (source_db_dir, _source_config_dir, root_key, _validators) = bootstrap_source_db();
        commit_non_reconfiguration_transaction(source_db_dir.path(), root_key);
        let source_account = read_account_resource(source_db_dir.path(), AccountAddress::TWO)
            .expect("post-genesis account must exist");

        let output_root = TempPath::new();
        output_root.create_as_dir().unwrap();
        let output_db_dir = output_root.path().join("fork-db");
        let config_dir = output_root.path().join("fork-configs");
        Command {
            source_db_dir: source_db_dir.path().to_path_buf(),
            output_db_dir,
            config_dir: Some(config_dir.clone()),
            fork_chain_id: 42,
            validators: 2,
            enable_storage_sharding: false,
        }
        .run()
        .unwrap();

        let mut api_addresses = Vec::new();
        let mut children = Vec::new();
        for validator_index in 0..2 {
            let validator_dir = config_dir.join(validator_index.to_string());
            let config_path = validator_dir.join("node.yaml");
            let config = NodeConfig::load_from_path(&config_path).unwrap();
            api_addresses.push(config.api.address);
            let log = File::create(validator_dir.join("live-smoke.log")).unwrap();
            children.push(
                ProcessCommand::new(&node_binary)
                    .current_dir(&validator_dir)
                    .arg("-f")
                    .arg(config_path)
                    .stdout(Stdio::from(log.try_clone().unwrap()))
                    .stderr(Stdio::from(log))
                    .spawn()
                    .unwrap(),
            );
        }
        let mut nodes = NodeProcesses(children);
        let client = reqwest::Client::new();
        let deadline = tokio::time::Instant::now() + Duration::from_secs(60);
        let mut starting_versions = None;
        while tokio::time::Instant::now() < deadline {
            for child in &mut nodes.0 {
                assert!(child.try_wait().unwrap().is_none(), "validator exited early");
            }
            let mut ledger_infos = Vec::new();
            for address in &api_addresses {
                if let Ok(response) = client
                    .get(format!("http://{}/v1/", address))
                    .send()
                    .await
                {
                    if let Ok(info) = response.json::<serde_json::Value>().await {
                        ledger_infos.push(info);
                    }
                }
            }
            if ledger_infos.len() == 2 {
                assert!(ledger_infos.iter().all(|info| info["chain_id"] == 42));
                let versions = ledger_infos
                    .iter()
                    .map(|info| {
                        info["ledger_version"]
                            .as_str()
                            .unwrap()
                            .parse::<u64>()
                            .unwrap()
                    })
                    .collect::<Vec<_>>();
                let initial_versions = starting_versions.get_or_insert_with(|| versions.clone());
                if versions
                    .iter()
                    .zip(initial_versions.iter())
                    .all(|(current, initial)| current > initial)
                {
                    for address in &api_addresses {
                        let account = client
                            .get(format!(
                                "http://{}/v1/accounts/0x2/resource/0x1::account::Account",
                                address
                            ))
                            .send()
                            .await
                            .unwrap()
                            .error_for_status()
                            .unwrap()
                            .json::<serde_json::Value>()
                            .await
                            .unwrap();
                        assert_eq!(
                            account["data"]["sequence_number"],
                            source_account.sequence_number().to_string(),
                        );
                    }
                    return;
                }
            }
            tokio::time::sleep(Duration::from_millis(500)).await;
        }
        panic!("two-validator fork did not commit a block before the deadline");
    }
}

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
    on_chain_config::{ConfigurationResource, OnChainConfig, ValidatorSet},
    state_store::{state_key::StateKey, TStateView},
    transaction::{ChangeSet, Transaction, WriteSetPayload},
    waypoint::Waypoint,
    write_set::{WriteOp, WriteSetMut},
};
use aptos_vm::aptos_vm::AptosVMBlockExecutor;
use clap::Parser;
use move_core_types::{language_storage::TypeTag, move_resource::MoveStructType};
use rand::rngs::OsRng;
use serde_json::json;
use std::{
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
        ensure!(
            validators.get() == 1,
            "--validators > 1 is not supported until per-validator DB output is implemented",
        );
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
        let (_root_key, _generated_genesis, _generated_waypoint, validators) = Builder::new(
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
    })
}

fn commit_fork_transaction(
    output_db_dir: &Path,
    sharding: bool,
    fork_chain_id: ChainId,
    validator_set: &ValidatorSet,
) -> Result<(Transaction, Waypoint)> {
    let db = open_db(output_db_dir, false, sharding)?;
    let view = db.reader.latest_state_checkpoint_view()?;
    let configuration = ConfigurationResource::fetch_config(&view)
        .ok_or_else(|| format_err!("ConfigurationResource missing"))?;
    let block_resource = view
        .get_state_value_bytes(&StateKey::resource_typed::<BlockResource>(&CORE_CODE_ADDRESS)?)?
        .ok_or_else(|| format_err!("BlockResource missing"))?;
    let block_resource = bcs::from_bytes::<BlockResource>(&block_resource)?;
    let next_configuration = configuration.bump_epoch_for_reconfiguration();
    let new_block_event = NewBlockEvent::new(
        CORE_CODE_ADDRESS,
        configuration.epoch(),
        0,
        block_resource.height() + 1,
        vec![],
        CORE_CODE_ADDRESS,
        vec![],
        next_configuration.last_reconfiguration_time_micros(),
    );
    let ledger_summary = db.reader.get_pre_committed_ledger_summary()?;
    let fork_txn = Transaction::GenesisTransaction(WriteSetPayload::Direct(ChangeSet::new(
        WriteSetMut::new(vec![
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
                WriteOp::legacy_modification(
                    bcs::to_bytes(&next_configuration)?.into(),
                ),
            ),
        ])
        .freeze()?,
        vec![
            ContractEvent::new_v2(NEW_EPOCH_EVENT_V2_MOVE_TYPE_TAG.clone(), vec![])?,
            ContractEvent::new_v1(
                new_block_event_key(),
                block_resource.new_block_events().count(),
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
) -> Result<Vec<PathBuf>> {
    validators
        .iter()
        .map(|validator| {
            let config_path = validator.validator_config_path();
            let mut config = NodeConfig::load_from_path(&config_path)?;
            config.storage.dir = output_db_dir.to_path_buf();
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
        ledger_info::{LedgerInfo, LedgerInfoWithSignatures},
        test_helpers::transaction_test_helpers::{
            block, get_test_signed_transaction, TEST_BLOCK_EXECUTOR_ONCHAIN_CONFIG,
        },
    };

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

    #[test]
    fn rejects_multi_validator_single_db_output() {
        let root = TempPath::new();
        root.create_as_dir().unwrap();
        let source = root.path().join("source");
        let output = root.path().join("output");
        fs::create_dir_all(&source).unwrap();
        let error = Command {
            source_db_dir: source,
            output_db_dir: output,
            config_dir: None,
            fork_chain_id: 42,
            validators: 2,
            enable_storage_sharding: false,
        }
        .run()
        .unwrap_err();
        assert!(error
            .to_string()
            .contains("--validators > 1 is not supported"));
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

    #[test]
    fn fork_commits_chain_id_validator_set_and_waypoint_to_output_db() {
        let (source_db_dir, _source_config_dir, root_key, _validators) = bootstrap_source_db();
        commit_non_reconfiguration_transaction(source_db_dir.path(), root_key);

        let source_info_before = inspect_db(source_db_dir.path(), false, false).unwrap();
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
            validators: 1,
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
        assert_eq!(output_info.chain_id, fork_chain_id);
        assert_ne!(output_info.chain_id, source_info_before.chain_id);
        assert_ne!(output_info.validator_set, source_info_before.validator_set);
        assert_eq!(output_info.validator_set.num_validators(), 1);
        assert_eq!(
            output_info.waypoint.unwrap().version(),
            source_info_before.version + 1
        );
        assert!(output_info.next_epoch.is_some());
        assert!(config_dir.join(MANIFEST).exists());

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
        NewBlockEvent::try_from_bytes(new_block_event.event_data()).unwrap();
    }
}

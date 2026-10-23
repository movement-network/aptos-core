// Copyright (c) Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    metrics::{CHUNK_OTHER_TIMERS, VM_EXECUTE_CHUNK},
    workflow::do_get_execution_output::DoGetExecutionOutput,
};
use anyhow::{ensure, Result};
use aptos_executor_types::execution_output::ExecutionOutput;
use aptos_experimental_runtimes::thread_manager::optimal_min_len;
use aptos_logger::info;
use aptos_metrics_core::TimerHelper;
use aptos_storage_interface::state_store::{
    state::LedgerState, state_view::cached_state_view::CachedStateView,
};
use aptos_types::{
    block_executor::{
        config::BlockExecutorConfigFromOnchain,
        transaction_slice_metadata::TransactionSliceMetadata,
    },
    transaction::{Transaction, TransactionInfo, TransactionOutput, Version},
};
use aptos_vm::VMBlockExecutor;
use once_cell::sync::Lazy;
use rayon::iter::{IndexedParallelIterator, IntoParallelIterator, ParallelIterator};
use std::sync::Arc;

pub static SIG_VERIFY_POOL: Lazy<Arc<rayon::ThreadPool>> = Lazy::new(|| {
    Arc::new(
        rayon::ThreadPoolBuilder::new()
            .num_threads(8) // More than 8 threads doesn't seem to help much
            .thread_name(|index| format!("chunk-sig-check-{}", index))
            .build()
            .unwrap(),
    )
});

pub trait TransactionChunk {
    fn first_version(&self) -> Version;

    fn len(&self) -> usize;

    fn is_empty(&self) -> bool {
        self.len() == 0
    }

    fn into_output<V: VMBlockExecutor>(
        self,
        parent_state: &LedgerState,
        state_view_factory: impl Fn(&LedgerState) -> Result<CachedStateView>,
    ) -> Result<ExecutionOutput>;
}

pub struct ChunkToExecute {
    pub transactions: Vec<Transaction>,
    pub transaction_infos: Vec<TransactionInfo>,
    pub first_version: Version,
}

impl TransactionChunk for ChunkToExecute {
    fn first_version(&self) -> Version {
        self.first_version
    }

    fn len(&self) -> usize {
        self.transactions.len()
    }

    fn into_output<V: VMBlockExecutor>(
        self,
        parent_state: &LedgerState,
        state_view_factory: impl Fn(&LedgerState) -> Result<CachedStateView>,
    ) -> Result<ExecutionOutput> {
        let ChunkToExecute {
            transactions,
            transaction_infos,
            first_version,
        } = self;

        ensure!(
            transactions.len() == transaction_infos.len(),
            "Chunk carries {} transactions but {} transaction infos",
            transactions.len(),
            transaction_infos.len(),
        );

        let execution_output = execute_transaction_slice::<V>(
            transactions.clone(),
            parent_state,
            state_view_factory(parent_state)?,
        )?;
        let combined_validation = ensure_outputs_match_transaction_infos(
            &execution_output,
            first_version,
            &transaction_infos,
        );
        let Err(combined_validation_error) = combined_validation else {
            return Ok(execution_output);
        };

        let block_ranges = historical_block_ranges(&transactions);
        if block_ranges.len() < 2 {
            return Err(combined_validation_error);
        }
        info!(
            first_version = first_version,
            num_transactions = transactions.len(),
            num_historical_blocks = block_ranges.len(),
            error = ?combined_validation_error,
            "Combined state-sync execution did not match transaction infos; retrying at historical block boundaries"
        );

        let mut result_state = parent_state.clone();
        let mut transaction_outputs = Vec::with_capacity(transactions.len());
        for range in block_ranges {
            let output = execute_transaction_slice::<V>(
                transactions[range.clone()].to_vec(),
                &result_state,
                state_view_factory(&result_state)?,
            )?;
            ensure_outputs_match_transaction_infos(
                &output,
                first_version + range.start as Version,
                &transaction_infos[range.clone()],
            )?;
            transaction_outputs.extend(output.to_commit.transaction_outputs.iter().cloned());
            result_state = output.result_state.clone();
        }

        DoGetExecutionOutput::by_transaction_output(
            transactions,
            transaction_outputs,
            parent_state,
            state_view_factory(parent_state)?,
        )
    }
}

fn execute_transaction_slice<V: VMBlockExecutor>(
    transactions: Vec<Transaction>,
    parent_state: &LedgerState,
    state_view: CachedStateView,
) -> Result<ExecutionOutput> {
    // TODO(skedia) In the chunk executor path, we ideally don't need to verify the signature
    // as only transactions with verified signatures are committed to the storage.
    let sig_verified_txns = {
        let _timer = CHUNK_OTHER_TIMERS.timer_with(&["sig_verify"]);

        let num_txns = transactions.len();
        SIG_VERIFY_POOL.install(|| {
            transactions
                .into_par_iter()
                .with_min_len(optimal_min_len(num_txns, 32))
                .map(|t| t.into())
                .collect::<Vec<_>>()
        })
    };

    let _timer = VM_EXECUTE_CHUNK.start_timer();
    DoGetExecutionOutput::by_transaction_execution::<V>(
        &V::new(),
        sig_verified_txns.into(),
        parent_state,
        state_view,
        BlockExecutorConfigFromOnchain::new_no_block_limit(),
        TransactionSliceMetadata::unknown(),
    )
}

fn ensure_outputs_match_transaction_infos(
    execution_output: &ExecutionOutput,
    first_version: Version,
    transaction_infos: &[TransactionInfo],
) -> Result<()> {
    ensure!(
        execution_output.to_retry.is_empty() && execution_output.to_discard.is_empty(),
        "Chunk execution retried or discarded transactions"
    );
    ensure!(
        execution_output.to_commit.transaction_outputs.len() == transaction_infos.len(),
        "Chunk execution did not produce an output for every transaction in {}..{}",
        first_version,
        first_version + transaction_infos.len() as Version,
    );
    for (offset, (output, transaction_info)) in execution_output
        .to_commit
        .transaction_outputs
        .iter()
        .zip(transaction_infos)
        .enumerate()
    {
        output.ensure_match_transaction_info(
            first_version + offset as Version,
            transaction_info,
            None,
            None,
        )?;
    }
    Ok(())
}

fn historical_block_ranges(transactions: &[Transaction]) -> Vec<std::ops::Range<usize>> {
    let mut ranges = Vec::new();
    let mut begin = 0;
    for index in 1..transactions.len() {
        if transactions[index].is_block_start()
            || transactions[index - 1].is_non_reconfig_block_ending()
        {
            ranges.push(begin..index);
            begin = index;
        }
    }
    if begin < transactions.len() {
        ranges.push(begin..transactions.len());
    }
    ranges
}

pub struct ChunkToApply {
    pub transactions: Vec<Transaction>,
    pub transaction_outputs: Vec<TransactionOutput>,
    pub first_version: Version,
}

impl TransactionChunk for ChunkToApply {
    fn first_version(&self) -> Version {
        self.first_version
    }

    fn len(&self) -> usize {
        self.transactions.len()
    }

    fn into_output<V: VMBlockExecutor>(
        self,
        parent_state: &LedgerState,
        state_view_factory: impl Fn(&LedgerState) -> Result<CachedStateView>,
    ) -> Result<ExecutionOutput> {
        let Self {
            transactions,
            transaction_outputs,
            first_version: _,
        } = self;

        DoGetExecutionOutput::by_transaction_output(
            transactions,
            transaction_outputs,
            parent_state,
            state_view_factory(parent_state)?,
        )
    }
}

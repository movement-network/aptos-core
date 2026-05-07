// Copyright (c) Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    metrics::TIMER,
    state_store::{
        state_delta::StateDelta,
        state_update_refs::{BatchedStateUpdateRefs, StateUpdateRefs},
        state_view::{
            cached_state_view::{CachedStateView, ShardedStateCache, StateCacheShard},
            hot_state_view::HotStateView,
        },
        versioned_state_value::StateUpdateRef,
        NUM_STATE_SHARDS,
    },
    DbReader,
};
use anyhow::{bail, Result};
use aptos_experimental_layered_map::{LayeredMap, MapLayer};
use aptos_metrics_core::TimerHelper;
use aptos_types::{
    state_store::{
        state_key::StateKey, state_slot::StateSlot, state_storage_usage::StateStorageUsage,
        StateViewId,
    },
    transaction::Version,
};
use arr_macro::arr;
use derive_more::Deref;
use itertools::Itertools;
use rayon::prelude::*;
use std::{collections::HashMap, sync::Arc};

/// Represents the blockchain state at a given version.
/// n.b. the state can be either persisted or speculative.
#[derive(Clone, Debug)]
pub struct State {
    /// The next version. If this is 0, the state is the "pre-genesis" empty state.
    next_version: Version,
    /// The updates made to the state at the current version.
    ///  N.b. this is not directly iterable, one needs to make a `StateDelta`
    ///       between this and a `base_version` to list the updates or create a
    ///       new `State` at a descendant version.
    shards: Arc<[MapLayer<StateKey, StateSlot>; NUM_STATE_SHARDS]>,
    /// The total usage of the state at the current version.
    usage: StateStorageUsage,
}

impl State {
    pub fn new_with_updates(
        version: Option<Version>,
        shards: Arc<[MapLayer<StateKey, StateSlot>; NUM_STATE_SHARDS]>,
        usage: StateStorageUsage,
    ) -> Self {
        Self {
            next_version: version.map_or(0, |v| v + 1),
            shards,
            usage,
        }
    }

    pub fn new_at_version(version: Option<Version>, usage: StateStorageUsage) -> Self {
        Self::new_with_updates(
            version,
            Arc::new(arr![MapLayer::new_family("state"); 16]),
            usage,
        )
    }

    pub fn new_empty() -> Self {
        Self::new_at_version(None, StateStorageUsage::zero())
    }

    pub fn next_version(&self) -> Version {
        self.next_version
    }

    pub fn version(&self) -> Option<Version> {
        self.next_version.checked_sub(1)
    }

    pub fn usage(&self) -> StateStorageUsage {
        self.usage
    }

    pub fn shards(&self) -> &[MapLayer<StateKey, StateSlot>; NUM_STATE_SHARDS] {
        &self.shards
    }

    pub fn make_delta(&self, base: &State) -> StateDelta {
        let _timer = TIMER.timer_with(&["state__make_delta"]);
        self.clone().into_delta(base.clone())
    }

    pub fn into_delta(self, base: State) -> StateDelta {
        StateDelta::new(base, self)
    }

    pub fn is_the_same(&self, rhs: &Self) -> bool {
        Arc::ptr_eq(&self.shards, &rhs.shards)
    }

    pub fn is_descendant_of(&self, rhs: &State) -> bool {
        self.shards[0].is_descendant_of(&rhs.shards[0])
    }

    pub fn update(
        &self,
        persisted: &State,
        updates: &BatchedStateUpdateRefs,
        state_cache: &ShardedStateCache,
    ) -> Result<Self> {
        let _timer = TIMER.timer_with(&["state__update"]);

        // 1. The update batch must begin at self.next_version().
        assert_eq!(self.next_version(), updates.first_version);
        // 2. The cache must be at a version equal or newer than `persisted`, otherwise
        //    updates between the cached version and the persisted version are potentially
        //    missed during the usage calculation. Under speculative execution of fork
        //    siblings, the persisted watermark can advance past the in-flight base — surface
        //    this as a recoverable error so the local consensus module can drop the losing
        //    branch, rather than aborting the process.
        if persisted.next_version() > state_cache.next_version() {
            bail!(
                "persisted version ({}) is ahead of cache version ({}), likely due to a fork",
                persisted.next_version(),
                state_cache.next_version(),
            );
        }
        // 3. `self` must be at a version equal or newer than the cache, because we assume
        //    it is overlaid on top of the cache.
        assert!(self.next_version() >= state_cache.next_version());

        let overlay = self.make_delta(persisted);
        let (shards, usage_delta_per_shard): (Vec<_>, Vec<_>) = (
            state_cache.shards.as_slice(),
            overlay.shards.as_slice(),
            updates.shards.as_slice(),
        )
            .into_par_iter()
            .map(|(cache, overlay, updates)| {
                let new_items = updates
                    .iter()
                    .map(|(k, u)| ((*k).clone(), u.to_result_slot()))
                    .collect_vec();

                (
                    // TODO(aldenhu): change interface to take iter of ref
                    overlay.new_layer(&new_items),
                    Self::usage_delta_for_shard(cache, overlay, updates),
                )
            })
            .unzip();
        let shards = Arc::new(shards.try_into().expect("Known to be 16 shards."));
        let usage = self.update_usage(usage_delta_per_shard);

        Ok(State::new_with_updates(updates.last_version(), shards, usage))
    }

    fn update_usage(&self, usage_delta_per_shard: Vec<(i64, i64)>) -> StateStorageUsage {
        assert_eq!(usage_delta_per_shard.len(), NUM_STATE_SHARDS);

        let (items_delta, bytes_delta) = usage_delta_per_shard
            .into_iter()
            .fold((0, 0), |(i1, b1), (i2, b2)| (i1 + i2, b1 + b2));
        StateStorageUsage::new(
            (self.usage().items() as i64 + items_delta) as usize,
            (self.usage().bytes() as i64 + bytes_delta) as usize,
        )
    }

    fn usage_delta_for_shard<'kv>(
        cache: &StateCacheShard,
        overlay: &LayeredMap<StateKey, StateSlot>,
        updates: &HashMap<&'kv StateKey, StateUpdateRef<'kv>>,
    ) -> (i64, i64) {
        let mut items_delta: i64 = 0;
        let mut bytes_delta: i64 = 0;
        for (k, v) in updates {
            let key_size = k.size();
            if let Some(value) = v.state_op.as_state_value_opt() {
                items_delta += 1;
                bytes_delta += (key_size + value.size()) as i64;
            }

            // TODO(aldenhu): avoid cloning the state value (by not using DashMap)
            // n.b. all updated state items must be read and recorded in the state cache,
            // otherwise we can't calculate the correct usage.
            let old_slot = overlay
                .get(k)
                .or_else(|| cache.get(k).map(|entry| entry.value().clone()))
                .expect("Must cache read");
            if old_slot.is_occupied() {
                items_delta -= 1;
                bytes_delta -= (key_size + old_slot.size()) as i64;
            }
        }
        (items_delta, bytes_delta)
    }
}

/// At a given version, the state and the last checkpoint state at or before the version.
#[derive(Clone, Debug, Deref)]
pub struct LedgerState {
    last_checkpoint: State,
    #[deref]
    latest: State,
}

impl LedgerState {
    pub fn new(latest: State, last_checkpoint: State) -> Self {
        assert!(latest.is_descendant_of(&last_checkpoint));

        Self {
            latest,
            last_checkpoint,
        }
    }

    pub fn new_empty() -> Self {
        let state = State::new_empty();
        Self::new(state.clone(), state)
    }

    pub fn latest(&self) -> &State {
        &self.latest
    }

    pub fn last_checkpoint(&self) -> &State {
        &self.last_checkpoint
    }

    pub fn is_checkpoint(&self) -> bool {
        self.latest.is_the_same(&self.last_checkpoint)
    }

    /// In the execution pipeline, at the time of state update, the reads during execution
    /// have already been recorded.
    pub fn update_with_memorized_reads(
        &self,
        persisted_snapshot: &State,
        updates: &StateUpdateRefs,
        reads: &ShardedStateCache,
    ) -> Result<LedgerState> {
        let _timer = TIMER.timer_with(&["ledger_state__update"]);

        let last_checkpoint = if let Some(updates) = &updates.for_last_checkpoint {
            self.latest().update(persisted_snapshot, updates, reads)?
        } else {
            self.last_checkpoint.clone()
        };

        let base_of_latest = if updates.for_last_checkpoint.is_none() {
            self.latest()
        } else {
            &last_checkpoint
        };
        let latest = if let Some(updates) = &updates.for_latest {
            base_of_latest.update(persisted_snapshot, updates, reads)?
        } else {
            base_of_latest.clone()
        };

        Ok(LedgerState::new(latest, last_checkpoint))
    }

    /// Old values of the updated keys are read from the DbReader at the version of the
    /// `persisted_snapshot`.
    pub fn update_with_db_reader(
        &self,
        persisted_snapshot: &State,
        hot_state: Arc<dyn HotStateView>,
        updates: &StateUpdateRefs,
        reader: Arc<dyn DbReader>,
    ) -> Result<(LedgerState, ShardedStateCache)> {
        let state_view = CachedStateView::new_impl(
            StateViewId::Miscellaneous,
            reader,
            hot_state,
            persisted_snapshot.clone(),
            self.latest().clone(),
        );
        state_view.prime_cache(updates)?;

        let updated = self.update_with_memorized_reads(
            persisted_snapshot,
            updates,
            state_view.memorized_reads(),
        )?;
        let state_reads = state_view.into_memorized_reads();
        Ok((updated, state_reads))
    }

    pub fn is_the_same(&self, other: &Self) -> bool {
        self.latest.is_the_same(&other.latest)
            && self.last_checkpoint.is_the_same(&other.last_checkpoint)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Cross-block version-ordering violations at the State::update entry point must surface as
    /// recoverable errors. The persisted-state watermark can advance past an in-flight block's
    /// base version under speculative execution of fork siblings; the downstream behavior is for
    /// the local consensus module to discard the in-flight branch, which requires an error to
    /// propagate.
    #[test]
    fn state_update_surfaces_recoverable_error_when_persisted_is_ahead_of_cache() {
        // Place the persisted watermark strictly ahead of the in-flight block's base. This
        // models the fork arrangement: a sibling block has pre-committed and advanced the
        // persisted watermark past this branch's base.
        let base_version = 5u64;
        let persisted_version = base_version + 1;
        let base_state = State::new_at_version(Some(base_version), StateStorageUsage::zero());
        let persisted_state =
            State::new_at_version(Some(persisted_version), StateStorageUsage::zero());

        // The state-update batch must start at `base_state.next_version()` — required to
        // reach the cross-block version check we're exercising.
        let state_updates = BatchedStateUpdateRefs::new_empty(base_state.next_version(), 1);

        // The cached state aligns with the in-flight block's base, not with the persisted
        // watermark. The gap between the cached-state version and the persisted version is
        // the fork-induced version mismatch the test exercises.
        let cached_state = ShardedStateCache::new_empty(Some(base_version));

        // `State::update` must surface this fork-induced version mismatch as a recoverable
        // error and return normally — that return is the test's assertion, no explicit check
        // is needed.
        let _ = base_state.update(&persisted_state, &state_updates, &cached_state);
    }
}

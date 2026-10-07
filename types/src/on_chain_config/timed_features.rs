// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::chain_id::{ChainId, NamedChain};
use chrono::{DateTime, TimeZone, Utc};
use chrono_tz::America::Los_Angeles;
use serde::Serialize;
use strum::{EnumCount, IntoEnumIterator};
use strum_macros::{EnumCount as EnumCountMacro, EnumIter};

#[derive(Debug, EnumCountMacro, EnumIter, Clone, Copy, Eq, PartialEq)]
pub enum TimedFeatureFlag {
    DisableInvariantViolationCheckInSwapLoc,
    // Was always enabled.
    _LimitTypeTagSize,
    // Enabled on mainnet, cannot be disabled.
    _ModuleComplexityCheck,
    EntryCompatibility,
    ChargeBytesForPrints,

    // Fixes the bug of table natives not tracking the memory usage of the global values they create.
    FixMemoryUsageTracking,

    /// Fixes the bug that table natives double count the memory usage of the global values.
    FixTableNativesMemoryDoubleCounting,

    /// Fixes the bug in deep type tag conversion.
    FixCryptoAlgebraNativesTypeTagConversion,

    /// Uses full transaction size when computing transaction metadata.
    UseFullTransactionSizeForTransactionMetadata,

    /// Bill execution gas for walking a materialized Move value graph.
    ///
    /// Covers deserialize paths (`from_bytes`, resource / table / object
    /// loads) and serialize-side BCS walks (`to_bytes`, `serialized_size`).
    /// Without this, a small BCS blob can expand into a huge node graph
    /// while only paying for the blob length.
    MeterValueNodesOnDeserialize,
}

/// Representation of features that are gated by the block timestamps.
#[derive(Debug, Clone)]
enum TimedFeaturesImpl {
    OnNamedChain {
        named_chain: NamedChain,
        // Unix Epoch timestamp in microseconds.
        timestamp_micros: u64,
    },
    EnableAll,
}

#[derive(Debug, Clone, Serialize)]
pub enum TimedFeatureOverride {
    Replay,
    Testing,
}

impl TimedFeatureOverride {
    #[allow(unused, clippy::match_single_binding)]
    const fn get_override(&self, flag: TimedFeatureFlag) -> Option<bool> {
        use TimedFeatureFlag::*;
        use TimedFeatureOverride::*;

        Some(match self {
            Replay => match flag {
                _LimitTypeTagSize => true,
                _ModuleComplexityCheck => true,
                // Add overrides for replay here.
                _ => return None,
            },
            Testing => match flag {
                EntryCompatibility => true,
                _ => return None, // Activate all flags
            },
        })
    }
}

const BEGINNING_OF_TIME: DateTime<Utc> = DateTime::UNIX_EPOCH;

#[allow(dead_code)]
const END_OF_TIME: DateTime<Utc> = DateTime::<Utc>::MAX_UTC;

impl TimedFeatureFlag {
    /// Returns the activation time of the feature on the given chain.
    pub fn activation_time_on(&self, chain_id: &NamedChain) -> DateTime<Utc> {
        use NamedChain::*;
        use TimedFeatureFlag::*;

        match (self, chain_id) {
            (UseFullTransactionSizeForTransactionMetadata, MOVEMAINNET | MOVETESTNET) => {
                Los_Angeles
                    .with_ymd_and_hms(2026, 5, 4, 9, 45, 0)
                    .unwrap()
                    .with_timezone(&Utc)
            },
            // Must precede the Movement catch-all so this flag does not
            // activate on 2025-08-11 (already in the past).
            (MeterValueNodesOnDeserialize, MOVETESTNET) => Los_Angeles
                .with_ymd_and_hms(2026, 10, 15, 9, 0, 0)
                .unwrap()
                .with_timezone(&Utc),
            (MeterValueNodesOnDeserialize, MOVEMAINNET) => Los_Angeles
                .with_ymd_and_hms(2026, 10, 22, 9, 0, 0)
                .unwrap()
                .with_timezone(&Utc),
            (_, MOVEMAINNET | MOVETESTNET) => Los_Angeles
                .with_ymd_and_hms(2025, 8, 11, 17, 0, 0)
                .unwrap()
                .with_timezone(&Utc),
            // Enabled from the beginning of time.
            (DisableInvariantViolationCheckInSwapLoc, TESTNET) => BEGINNING_OF_TIME,
            (DisableInvariantViolationCheckInSwapLoc, MAINNET) => BEGINNING_OF_TIME,

            // Note: These have been enabled since the start due to a bug.
            (_LimitTypeTagSize, TESTNET) => BEGINNING_OF_TIME,
            (_LimitTypeTagSize, MAINNET) => BEGINNING_OF_TIME,

            (_ModuleComplexityCheck, TESTNET) => Los_Angeles
                .with_ymd_and_hms(2024, 6, 25, 16, 0, 0)
                .unwrap()
                .with_timezone(&Utc),
            (_ModuleComplexityCheck, MAINNET) => Los_Angeles
                .with_ymd_and_hms(2024, 7, 3, 12, 0, 0)
                .unwrap()
                .with_timezone(&Utc),

            (EntryCompatibility, TESTNET) => Los_Angeles
                .with_ymd_and_hms(2024, 11, 6, 12, 0, 0)
                .unwrap()
                .with_timezone(&Utc),
            (EntryCompatibility, MAINNET) => Los_Angeles
                .with_ymd_and_hms(2024, 11, 12, 12, 0, 0)
                .unwrap()
                .with_timezone(&Utc),

            // Note: Activation time set to 1 hour after the beginning of time
            //       so we can test the old and new behaviors in tests.
            (FixMemoryUsageTracking, TESTING) => Utc.with_ymd_and_hms(1970, 1, 1, 1, 0, 0).unwrap(),
            (FixMemoryUsageTracking, TESTNET) => Los_Angeles
                .with_ymd_and_hms(2025, 3, 7, 12, 0, 0)
                .unwrap()
                .with_timezone(&Utc),
            (FixMemoryUsageTracking, MAINNET) => Los_Angeles
                .with_ymd_and_hms(2025, 3, 11, 17, 0, 0)
                .unwrap()
                .with_timezone(&Utc),

            (ChargeBytesForPrints, TESTNET) => Los_Angeles
                .with_ymd_and_hms(2025, 3, 7, 12, 0, 0)
                .unwrap()
                .with_timezone(&Utc),
            (ChargeBytesForPrints, MAINNET) => Los_Angeles
                .with_ymd_and_hms(2025, 3, 11, 17, 0, 0)
                .unwrap()
                .with_timezone(&Utc),

            (FixTableNativesMemoryDoubleCounting, TESTNET) => Los_Angeles
                .with_ymd_and_hms(2025, 10, 16, 17, 0, 0)
                .unwrap()
                .with_timezone(&Utc),
            (FixTableNativesMemoryDoubleCounting, MAINNET) => Los_Angeles
                .with_ymd_and_hms(2025, 10, 21, 10, 0, 0)
                .unwrap()
                .with_timezone(&Utc),

            // 1 hour after the beginning of time
            (FixCryptoAlgebraNativesTypeTagConversion, _) => {
                Utc.with_ymd_and_hms(1970, 1, 1, 1, 0, 0).unwrap()
            },

            // Irrelevant for us except for testing
            (UseFullTransactionSizeForTransactionMetadata, _) => BEGINNING_OF_TIME,

            // Three hours after the Unix epoch so a single `new_epoch()`
            // (two hours) leaves the flag off. Tests that need the charge
            // advance two epochs. Existing tests that only roll one epoch
            // keep the historical unmetered behavior.
            (MeterValueNodesOnDeserialize, TESTING) => {
                Utc.with_ymd_and_hms(1970, 1, 1, 3, 0, 0).unwrap()
            },
            (MeterValueNodesOnDeserialize, TESTNET) => Los_Angeles
                .with_ymd_and_hms(2026, 10, 15, 14, 0, 0)
                .unwrap()
                .with_timezone(&Utc),
            (MeterValueNodesOnDeserialize, MAINNET) => Los_Angeles
                .with_ymd_and_hms(2026, 10, 22, 14, 0, 0)
                .unwrap()
                .with_timezone(&Utc),

            // For chains other than testnet and mainnet, a timed feature is considered enabled from
            // the very beginning, if left unspecified.
            (_, TESTING | DEVNET | PREMAINNET) => BEGINNING_OF_TIME,
        }
    }
}

#[derive(Debug, Clone)]
pub struct TimedFeaturesBuilder {
    inner: TimedFeaturesImpl,
    override_: Option<TimedFeatureOverride>,
}

impl TimedFeaturesBuilder {
    /// `timestamp_micros` is a Unix Epoch timestamp in microseconds.
    pub fn new(chain_id: ChainId, timestamp_micros: u64) -> Self {
        let inner = match NamedChain::from_chain_id(&chain_id) {
            Ok(named_chain) => TimedFeaturesImpl::OnNamedChain {
                named_chain,
                timestamp_micros,
            },
            Err(_) => TimedFeaturesImpl::EnableAll, // Unknown chain => enable all features by default.
        };
        Self {
            inner,
            override_: None,
        }
    }

    pub fn enable_all() -> Self {
        Self {
            inner: TimedFeaturesImpl::EnableAll,
            override_: None,
        }
    }

    pub fn with_override_profile(self, profile: TimedFeatureOverride) -> Self {
        Self {
            inner: self.inner,
            override_: Some(profile),
        }
    }

    /// Determine whether the given feature should be enabled or not.
    fn is_enabled(&self, flag: TimedFeatureFlag) -> bool {
        use TimedFeaturesImpl::*;

        if let Some(override_) = &self.override_ {
            if let Some(enabled) = override_.get_override(flag) {
                return enabled;
            }
        }

        match &self.inner {
            OnNamedChain {
                named_chain,
                timestamp_micros,
            } => {
                *timestamp_micros >= flag.activation_time_on(named_chain).timestamp_micros() as u64
            },
            EnableAll => true,
        }
    }

    pub fn build(self) -> TimedFeatures {
        let mut enabled = [false; TimedFeatureFlag::COUNT];
        for flag in TimedFeatureFlag::iter() {
            enabled[flag as usize] = self.is_enabled(flag)
        }

        TimedFeatures(enabled)
    }
}

#[derive(Clone, Debug, Serialize, Eq, PartialEq)]
pub struct TimedFeatures([bool; TimedFeatureFlag::COUNT]);

impl TimedFeatures {
    pub fn is_enabled(&self, flag: TimedFeatureFlag) -> bool {
        self.0[flag as usize]
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use crate::chain_id::NamedChain;
    use claims::assert_ok;

    #[test]
    fn timed_features_override_is_serializable() {
        let replay = assert_ok!(bcs::to_bytes(&TimedFeatureOverride::Replay));
        let testing = assert_ok!(bcs::to_bytes(&TimedFeatureOverride::Testing));
        assert_ne!(replay, testing);
    }

    #[test]
    fn test_micros_conversion() {
        use NamedChain::*;

        assert_eq!(
            Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0)
                .unwrap()
                .timestamp_micros(),
            1_704_067_200_000_000
        );

        assert_eq!(
            Utc.with_ymd_and_hms(2024, 11, 15, 0, 0, 0)
                .unwrap()
                .timestamp_micros(),
            1_731_628_800_000_000
        );

        assert_eq!(
            TimedFeatureFlag::_ModuleComplexityCheck
                .activation_time_on(&TESTNET)
                .timestamp_micros(),
            1_719_356_400_000_000
        );
        assert_eq!(
            TimedFeatureFlag::_ModuleComplexityCheck
                .activation_time_on(&MAINNET)
                .timestamp_micros(),
            1_720_033_200_000_000
        );

        assert_eq!(
            TimedFeatureFlag::EntryCompatibility
                .activation_time_on(&TESTNET)
                .timestamp_micros(),
            1_730_923_200_000_000
        );
        assert_eq!(
            TimedFeatureFlag::EntryCompatibility
                .activation_time_on(&MAINNET)
                .timestamp_micros(),
            1_731_441_600_000_000
        );
    }

    #[test]
    fn test_timed_features_activation() {
        use TimedFeatureFlag::*;
        let jan_1_2024_micros = Utc
            .with_ymd_and_hms(2024, 1, 1, 0, 0, 0)
            .unwrap()
            .timestamp_micros() as u64;
        let nov_15_2024_micros = Utc
            .with_ymd_and_hms(2024, 11, 15, 0, 0, 0)
            .unwrap()
            .timestamp_micros() as u64;

        // Check testnet on Jan 1, 2024.
        let testnet_jan_1_2024 = TimedFeaturesBuilder::new(ChainId::testnet(), jan_1_2024_micros);
        assert!(
            testnet_jan_1_2024.is_enabled(DisableInvariantViolationCheckInSwapLoc),
            "DisableInvariantViolationCheckInSwapLoc should always be enabled"
        );
        assert!(
            testnet_jan_1_2024.is_enabled(_LimitTypeTagSize),
            "LimitTypeTagSize should always be enabled"
        );
        assert!(
            !testnet_jan_1_2024.is_enabled(_ModuleComplexityCheck),
            "ModuleComplexityCheck should be disabled on Jan 1, 2024 on testnet"
        );
        assert!(
            !testnet_jan_1_2024.is_enabled(EntryCompatibility),
            "EntryCompatibility should be disabled on Jan 1, 2024 on testnet"
        );
        // Check testnet on Nov 15, 2024.
        let testnet_nov_15_2024 = TimedFeaturesBuilder::new(ChainId::testnet(), nov_15_2024_micros);
        assert!(
            testnet_nov_15_2024.is_enabled(DisableInvariantViolationCheckInSwapLoc),
            "DisableInvariantViolationCheckInSwapLoc should always be enabled"
        );
        assert!(
            testnet_nov_15_2024.is_enabled(_LimitTypeTagSize),
            "LimitTypeTagSize should always be enabled"
        );
        assert!(
            testnet_nov_15_2024.is_enabled(_ModuleComplexityCheck),
            "ModuleComplexityCheck should be enabled on Nov 15, 2024 on testnet"
        );
        assert!(
            testnet_nov_15_2024.is_enabled(EntryCompatibility),
            "EntryCompatibility should be enabled on Nov 15, 2024 on testnet"
        );
        // Check mainnet on Jan 1, 2024.
        let mainnet_jan_1_2024 = TimedFeaturesBuilder::new(ChainId::mainnet(), jan_1_2024_micros);
        assert!(
            mainnet_jan_1_2024.is_enabled(DisableInvariantViolationCheckInSwapLoc),
            "DisableInvariantViolationCheckInSwapLoc should always be enabled"
        );
        assert!(
            mainnet_jan_1_2024.is_enabled(_LimitTypeTagSize),
            "LimitTypeTagSize should always be enabled"
        );
        assert!(
            !mainnet_jan_1_2024.is_enabled(_ModuleComplexityCheck),
            "ModuleComplexityCheck should be disabled on Jan 1, 2024 on mainnet"
        );
        assert!(
            !mainnet_jan_1_2024.is_enabled(EntryCompatibility),
            "EntryCompatibility should be disabled on Jan 1, 2024 on mainnet"
        );
        // Check mainnet on Nov 15, 2024.
        let mainnet_nov_15_2024 = TimedFeaturesBuilder::new(ChainId::mainnet(), nov_15_2024_micros);
        assert!(
            mainnet_nov_15_2024.is_enabled(DisableInvariantViolationCheckInSwapLoc),
            "DisableInvariantViolationCheckInSwapLoc should always be enabled"
        );
        assert!(
            mainnet_nov_15_2024.is_enabled(_LimitTypeTagSize),
            "LimitTypeTagSize should always be enabled"
        );
        assert!(
            mainnet_nov_15_2024.is_enabled(_ModuleComplexityCheck),
            "ModuleComplexityCheck should be enabled on Nov 15, 2024 on mainnet"
        );
        assert!(
            mainnet_nov_15_2024.is_enabled(EntryCompatibility),
            "EntryCompatibility should be enabled on Nov 15, 2024 on mainnet"
        );
    }

    #[test]
    fn value_graph_flag_stays_off_until_its_own_activation() {
        use TimedFeatureFlag::*;

        let genesis = 0;
        let two_hours_micros = 2 * 3_600 * 1_000_000;
        let four_hours_micros = 4 * 3_600 * 1_000_000;

        let testing_genesis = TimedFeaturesBuilder::new(ChainId::test(), genesis);
        assert!(
            !testing_genesis.is_enabled(MeterValueNodesOnDeserialize),
            "flag must be off at testing genesis so historical gas stays unchanged"
        );

        let after_one_epoch = TimedFeaturesBuilder::new(ChainId::test(), two_hours_micros);
        assert!(
            !after_one_epoch.is_enabled(MeterValueNodesOnDeserialize),
            "a single two-hour epoch must not enable the charge"
        );

        let after_two_epochs = TimedFeaturesBuilder::new(ChainId::test(), four_hours_micros);
        assert!(
            after_two_epochs.is_enabled(MeterValueNodesOnDeserialize),
            "two epochs (four hours) must cross the three-hour testing gate"
        );

        // Movement's unnamed-flag catch-all is 2025-08-11; this flag must not
        // inherit that date or it would be live immediately.
        let movement_now = Utc
            .with_ymd_and_hms(2026, 9, 6, 0, 0, 0)
            .unwrap()
            .timestamp_micros() as u64;
        let movement =
            TimedFeaturesBuilder::new(ChainId::new(NamedChain::MOVETESTNET.id()), movement_now);
        assert!(
            !movement.is_enabled(MeterValueNodesOnDeserialize),
            "Movement testnet must wait for the explicit October 2026 activation"
        );
    }
}

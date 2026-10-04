// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::wire_bls::WireBlsSignature;
use aptos_bitvec::BitVec;
use aptos_crypto::{bls12381, CryptoMaterialError};
use aptos_crypto_derive::{BCSCryptoHash, CryptoHasher};
use move_core_types::account_address::AccountAddress;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// This struct represents a BLS multi-signature or aggregated signature:
/// it stores a bit mask representing the set of validators participating in the signing process
/// and the multi-signature/aggregated signature itself,
/// which was aggregated from these validators' partial BLS signatures.
///
/// The signature payload stays in compressed wire form so a later
/// `LedgerInfo` equality check can inspect bitmask and commit info without
/// paying G2 decompression. Verification paths call [`Self::try_group_element`].
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, CryptoHasher, BCSCryptoHash)]
pub struct AggregateSignature {
    validator_bitmask: BitVec,
    sig: Option<WireBlsSignature>,
}

impl AggregateSignature {
    pub fn new(
        validator_bitmask: BitVec,
        aggregated_signature: Option<bls12381::Signature>,
    ) -> Self {
        Self {
            validator_bitmask,
            sig: aggregated_signature.map(WireBlsSignature::from),
        }
    }

    pub fn empty() -> Self {
        Self {
            validator_bitmask: BitVec::default(),
            sig: None,
        }
    }

    pub fn get_signers_bitvec(&self) -> &BitVec {
        &self.validator_bitmask
    }

    pub fn get_signers_addresses(
        &self,
        validator_addresses: &[AccountAddress],
    ) -> Vec<AccountAddress> {
        validator_addresses
            .iter()
            .enumerate()
            .filter_map(|(index, addr)| {
                if self.validator_bitmask.is_set(index as u16) {
                    Some(*addr)
                } else {
                    None
                }
            })
            .collect()
    }

    pub fn get_num_voters(&self) -> usize {
        self.validator_bitmask.count_ones() as usize
    }

    /// Compressed payload, if present. Does not recover a group element.
    pub fn wire_sig(&self) -> Option<&WireBlsSignature> {
        self.sig.as_ref()
    }

    /// Recover the aggregated group element. `Ok(None)` means no signature
    /// was stored; `Err` means the 96-byte payload is not a G2 point.
    pub fn try_group_element(&self) -> Result<Option<bls12381::Signature>, CryptoMaterialError> {
        match self.sig {
            None => Ok(None),
            Some(wire) => wire.recover_group_element().map(Some),
        }
    }

    /// Historical accessor. Recovers the group element when the payload is a
    /// valid point; unrecoverable 96-byte payloads are reported as `None`.
    /// Verify paths should prefer [`Self::try_group_element`] to distinguish
    /// "missing" from "malformed".
    pub fn sig(&self) -> Option<bls12381::Signature> {
        self.try_group_element().ok().flatten()
    }
}

/// Partial signature from a set of validators. This struct is only used when aggregating the votes
/// from different validators. It is only kept in memory and never sent through the network.
#[derive(Clone, Debug, Deserialize, Eq, PartialEq)]
pub struct PartialSignatures {
    signatures: BTreeMap<AccountAddress, bls12381::Signature>,
}

impl PartialSignatures {
    pub fn new(signatures: BTreeMap<AccountAddress, bls12381::Signature>) -> Self {
        Self { signatures }
    }

    pub fn empty() -> Self {
        Self::new(BTreeMap::new())
    }

    pub fn is_empty(&self) -> bool {
        self.signatures.is_empty()
    }

    pub fn remove_signature(&mut self, validator: AccountAddress) -> Option<bls12381::Signature> {
        self.signatures.remove(&validator)
    }

    pub fn add_signature(&mut self, validator: AccountAddress, signature: bls12381::Signature) {
        self.signatures.insert(validator, signature);
    }

    pub fn unpack(self) -> BTreeMap<AccountAddress, bls12381::Signature> {
        self.signatures
    }

    pub fn signatures_iter(&self) -> impl Iterator<Item = (&AccountAddress, &bls12381::Signature)> {
        self.signatures.iter()
    }

    pub fn signatures(&self) -> &BTreeMap<AccountAddress, bls12381::Signature> {
        &self.signatures
    }

    pub fn contains_voter(&self, voter: &AccountAddress) -> bool {
        self.signatures.contains_key(voter)
    }
}

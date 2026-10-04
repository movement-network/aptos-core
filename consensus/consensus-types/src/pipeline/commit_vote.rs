// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

use crate::common::{Author, Round};
use anyhow::{ensure, Context};
use aptos_crypto::{bls12381, CryptoMaterialError};
use aptos_short_hex_str::AsShortHexStr;
use aptos_types::{
    block_info::BlockInfo,
    ledger_info::{LedgerInfo, SignatureWithStatus},
    validator_signer::ValidatorSigner,
    validator_verifier::ValidatorVerifier,
};
use serde::{Deserialize, Serialize};
use std::fmt::{Debug, Display, Formatter};

#[derive(Deserialize, Serialize, Clone, PartialEq, Eq)]
pub struct CommitVote {
    author: Author,
    ledger_info: LedgerInfo,
    /// Signature on the LedgerInfo along with a status on whether the signature is verified.
    signature: SignatureWithStatus,
}

// this is required by structured log
impl Debug for CommitVote {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        write!(f, "{}", self)
    }
}

impl Display for CommitVote {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        write!(
            f,
            "CommitProposal: [author: {}, {}]",
            self.author.short_str(),
            self.ledger_info
        )
    }
}

impl CommitVote {
    /// Generates a new CommitProposal
    pub fn new(
        author: Author,
        ledger_info_placeholder: LedgerInfo,
        validator_signer: &ValidatorSigner,
    ) -> Result<Self, CryptoMaterialError> {
        let signature = validator_signer.sign(&ledger_info_placeholder)?;
        Ok(Self::new_with_signature(
            author,
            ledger_info_placeholder,
            signature,
        ))
    }

    /// Generates a new CommitProposal using a signature over the specified ledger_info
    pub fn new_with_signature(
        author: Author,
        ledger_info: LedgerInfo,
        signature: bls12381::Signature,
    ) -> Self {
        Self {
            author,
            ledger_info,
            signature: SignatureWithStatus::from(signature),
        }
    }

    /// Return the author of the commit proposal
    pub fn author(&self) -> Author {
        self.author
    }

    /// Return the LedgerInfo associated with this commit proposal
    pub fn ledger_info(&self) -> &LedgerInfo {
        &self.ledger_info
    }

    /// Whether this vote is a signature over `expected` in full (`commit_info`
    /// and `consensus_data_hash`). Partial-proof aggregation must use this,
    /// not `commit_info` alone.
    pub fn signs_same_ledger_info(&self, expected: &LedgerInfo) -> bool {
        &self.ledger_info == expected
    }

    /// Recover the group element of the commit-vote signature.
    /// LedgerInfo matching must use [`Self::ledger_info`] / [`Self::signature_with_status`].
    pub fn signature(&self) -> Result<bls12381::Signature, CryptoMaterialError> {
        self.signature.recover_group_element()
    }

    /// Returns the signature along with the verification status of the signature.
    // Note: SignatureWithStatus has interior mutability for verification status.
    // Need to make sure the verification status is set to true only the verification is successful.
    pub fn signature_with_status(&self) -> &SignatureWithStatus {
        &self.signature
    }

    pub fn round(&self) -> Round {
        self.ledger_info.round()
    }

    pub fn epoch(&self) -> u64 {
        self.ledger_info.epoch()
    }

    /// Checks that `sender` is the vote author and that the signature is valid
    /// for *this* vote's `ledger_info`. That does not bind the vote to any
    /// other node's commit message: a partial proof must still compare the
    /// entire `LedgerInfo` before inserting the signature.
    pub fn verify(&self, sender: Author, validator: &ValidatorVerifier) -> anyhow::Result<()> {
        ensure!(
            self.author() == sender,
            "Commit vote author {:?} doesn't match with the sender {:?}",
            self.author(),
            sender
        );
        validator
            .optimistic_verify(self.author(), &self.ledger_info, &self.signature)
            .context("Failed to verify Commit Vote")
    }

    pub fn commit_info(&self) -> &BlockInfo {
        self.ledger_info().commit_info()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use aptos_crypto::HashValue;

    #[test]
    fn signs_same_ledger_info_requires_consensus_data_hash() {
        let signer = ValidatorSigner::random([7; 32]);
        let commit = BlockInfo::empty();
        let expected = LedgerInfo::new(commit.clone(), HashValue::zero());
        let other = LedgerInfo::new(commit, HashValue::from_u64(9));
        let vote = CommitVote::new(signer.author(), other, &signer).unwrap();
        assert_eq!(vote.commit_info(), expected.commit_info());
        assert!(!vote.signs_same_ledger_info(&expected));
        assert!(vote.signs_same_ledger_info(vote.ledger_info()));
    }
}

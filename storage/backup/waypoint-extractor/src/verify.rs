// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Chain verification, split so that the expensive part is embarrassingly parallel.
//!
//! * [`verify_chunk`]: given the ledger info for epoch `s-1` (`prev`) and the ledger infos for
//!   epochs `s..`, checks each ledger info against *its predecessor only* (signatures from the
//!   predecessor's `next_epoch_state`, epoch numbering, `ends_epoch`, version monotonicity). Chunks
//!   do not depend on one another, so many can run at once and, within a chunk, rayon spreads the
//!   BLS verification across all cores.
//! * [`Linker`]: the cheap sequential pass. It anchors the chain at the trusted waypoint and checks
//!   that each chunk's `prev` is byte-for-byte the previous chunk's last ledger info, so the
//!   independently verified chunks form one chain.

use anyhow::{anyhow, Result};
use aptos_bitvec::BitVec;
use aptos_crypto::{bls12381::PublicKey, traits::Signature};
use aptos_types::{
    ledger_info::{LedgerInfo, LedgerInfoWithSignatures},
    validator_verifier::ValidatorVerifier,
    waypoint::Waypoint,
};
use rayon::prelude::*;
use std::{collections::HashMap, fmt, sync::Arc};

/// Failure in the chain, with the epoch whose ledger info failed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChainError {
    pub epoch: u64,
    pub reason: String,
}

impl fmt::Display for ChainError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "verification failed at epoch {}: {}",
            self.epoch, self.reason
        )
    }
}

impl std::error::Error for ChainError {}

fn err(epoch: u64, reason: impl Into<String>) -> ChainError {
    ChainError {
        epoch,
        reason: reason.into(),
    }
}

/// The trust root: a waypoint and the epoch whose ending ledger info it commits to
/// (0 for the genesis waypoint).
#[derive(Debug, Clone, Copy)]
pub struct TrustedStart {
    pub waypoint: Waypoint,
    pub epoch: u64,
}

/// A downloaded range of consecutive epoch-ending ledger infos. `prev` is the ledger info for
/// epoch `first_epoch - 1` (the validator-set source for `lis[0]`), `lis[i]` is epoch
/// `first_epoch + i`.
pub struct Chunk {
    pub first_epoch: u64,
    pub prev: LedgerInfoWithSignatures,
    pub lis: Vec<LedgerInfoWithSignatures>,
}

/// Result of verifying a chunk, small enough to queue.
pub struct VerifiedChunk {
    pub first_epoch: u64,
    pub prev: LedgerInfoWithSignatures,
    /// The last ledger info of the chunk (or `prev` when the chunk is empty).
    pub last: LedgerInfoWithSignatures,
    pub num_verified: u64,
    /// `(epoch, waypoint)` for epochs selected by the interval.
    pub waypoints: Vec<(u64, Waypoint)>,
}

/// Per-thread cache of aggregated public keys for the validator set in use. Consecutive epochs
/// usually share a validator set and signer subset, so the aggregation is reused.
struct SigCache {
    verifier: Option<Arc<ValidatorVerifier>>,
    aggregated: HashMap<Vec<u8>, PublicKey>,
}

impl SigCache {
    fn new() -> Self {
        Self {
            verifier: None,
            aggregated: HashMap::new(),
        }
    }

    fn select(&mut self, verifier: &Arc<ValidatorVerifier>) {
        let same = match &self.verifier {
            Some(v) => Arc::ptr_eq(v, verifier) || **v == **verifier,
            None => false,
        };
        if !same {
            self.verifier = Some(verifier.clone());
            self.aggregated.clear();
        }
    }

    /// Equivalent to `ValidatorVerifier::verify_multi_signatures` but with the aggregated key
    /// cached, and without the test-only shortcut for a zero quorum.
    fn verify(
        &mut self,
        verifier: &Arc<ValidatorVerifier>,
        li: &LedgerInfoWithSignatures,
    ) -> Result<(), String> {
        if verifier.is_empty() || verifier.quorum_voting_power() == 0 {
            return Err("predecessor's next validator set is empty or has zero quorum".into());
        }
        self.select(verifier);
        let sigs = li.signatures();
        let bitvec: &BitVec = sigs.get_signers_bitvec();
        let n = verifier.len();
        if n > u16::MAX as usize
            || bitvec.num_buckets() != BitVec::required_buckets(n as u16)
            || bitvec.last_set_bit().is_some_and(|b| b as usize >= n)
        {
            return Err("invalid signer bitmask".into());
        }
        let addresses: Vec<_> = verifier.get_ordered_account_addresses();
        let authors: Vec<_> = bitvec.iter_ones().map(|i| addresses[i]).collect();
        verifier
            .check_voting_power(authors.iter(), true)
            .map_err(|e| format!("insufficient voting power: {e}"))?;
        let sig = sigs.sig().as_ref().ok_or("missing aggregate signature")?;
        let key_id = bcs::to_bytes(bitvec).map_err(|e| e.to_string())?;
        if !self.aggregated.contains_key(&key_id) {
            let keys: Vec<PublicKey> = bitvec
                .iter_ones()
                .map(|i| {
                    verifier
                        .get_public_key(&addresses[i])
                        .expect("index in range")
                })
                .collect();
            let agg = PublicKey::aggregate(keys.iter().collect())
                .map_err(|_| "failed to aggregate public keys".to_string())?;
            self.aggregated.insert(key_id.clone(), agg);
        }
        let agg = &self.aggregated[&key_id];
        sig.verify(li.ledger_info(), agg)
            .map_err(|_| "invalid aggregate signature".to_string())
    }
}

/// Checks `cur` (expected to be epoch `expected_epoch`) against its predecessor.
fn check_link(
    cache: &mut SigCache,
    prev: &LedgerInfoWithSignatures,
    cur: &LedgerInfoWithSignatures,
    expected_epoch: u64,
) -> Result<(), ChainError> {
    let p = prev.ledger_info();
    let c = cur.ledger_info();
    if c.epoch() != expected_epoch {
        return Err(err(
            expected_epoch,
            format!(
                "ledger info carries epoch {} (gap, duplicate or reorder)",
                c.epoch()
            ),
        ));
    }
    if !c.ends_epoch() {
        return Err(err(expected_epoch, "ledger info does not end its epoch"));
    }
    let next = c
        .next_epoch_state()
        .expect("ends_epoch implies next_epoch_state");
    if next.epoch != expected_epoch + 1 {
        return Err(err(
            expected_epoch,
            format!(
                "next_epoch_state is for epoch {}, expected {}",
                next.epoch,
                expected_epoch + 1
            ),
        ));
    }
    if c.version() <= p.version() {
        return Err(err(
            expected_epoch,
            format!(
                "version {} does not exceed previous epoch's {}",
                c.version(),
                p.version()
            ),
        ));
    }
    let signers = p.next_epoch_state().ok_or_else(|| {
        err(
            expected_epoch,
            "previous ledger info does not carry a next epoch state",
        )
    })?;
    if signers.epoch != expected_epoch {
        return Err(err(
            expected_epoch,
            format!("previous ledger info hands over to epoch {}", signers.epoch),
        ));
    }
    cache
        .verify(&signers.verifier, cur)
        .map_err(|e| err(expected_epoch, e))
}

/// Signature/structure verification of one chunk, parallel across all rayon threads.
/// `waypoint_every` selects epochs divisible by it (0 disables).
pub fn verify_chunk(chunk: Chunk, waypoint_every: u64) -> Result<VerifiedChunk, ChainError> {
    const SUB: usize = 32;
    let Chunk {
        first_epoch,
        prev,
        lis,
    } = chunk;
    if let Some(e) = lis
        .par_chunks(SUB)
        .enumerate()
        .map(|(ci, sub)| {
            let mut cache = SigCache::new();
            for (k, cur) in sub.iter().enumerate() {
                let idx = ci * SUB + k;
                let p = if idx == 0 { &prev } else { &lis[idx - 1] };
                if let Err(e) = check_link(&mut cache, p, cur, first_epoch + idx as u64) {
                    return Some(e);
                }
            }
            None
        })
        .find_map_first(|x| x)
    {
        return Err(e);
    }

    let waypoints = if waypoint_every == 0 {
        vec![]
    } else {
        lis.iter()
            .filter(|li| li.ledger_info().epoch() % waypoint_every == 0)
            .map(|li| {
                Waypoint::new_epoch_boundary(li.ledger_info())
                    .map(|w| (li.ledger_info().epoch(), w))
                    .map_err(|e| err(li.ledger_info().epoch(), e.to_string()))
            })
            .collect::<Result<Vec<_>, _>>()?
    };
    let num_verified = lis.len() as u64;
    let last = lis.into_iter().next_back().unwrap_or_else(|| prev.clone());
    Ok(VerifiedChunk {
        first_epoch,
        prev,
        last,
        num_verified,
        waypoints,
    })
}

/// Sequential pass anchoring and joining verified chunks (which must be fed in epoch order).
pub struct Linker {
    trusted: TrustedStart,
    last: Option<LedgerInfo>,
    next_epoch: u64,
    pub waypoints: Vec<(u64, Waypoint)>,
    pub verified_epochs: u64,
}

impl Linker {
    pub fn new(trusted: TrustedStart) -> Self {
        Self {
            trusted,
            last: None,
            next_epoch: trusted.epoch + 1,
            waypoints: vec![],
            verified_epochs: 0,
        }
    }

    pub fn accept(&mut self, chunk: VerifiedChunk) -> Result<(), ChainError> {
        let t = self.trusted;
        match &self.last {
            None => {
                // The first chunk's `prev` is the ledger info the trusted waypoint commits to.
                let p = chunk.prev.ledger_info();
                if p.epoch() != t.epoch {
                    return Err(err(
                        t.epoch,
                        format!(
                            "trusted waypoint is for epoch {} but server's ledger info is epoch {}",
                            t.epoch,
                            p.epoch()
                        ),
                    ));
                }
                if !p.ends_epoch() {
                    return Err(err(
                        t.epoch,
                        "trusted-epoch ledger info does not end its epoch",
                    ));
                }
                t.waypoint
                    .verify(p)
                    .map_err(|e| err(t.epoch, format!("trusted waypoint mismatch: {e}")))?;
            },
            Some(last) => {
                if chunk.prev.ledger_info() != last {
                    return Err(err(
                        chunk.first_epoch.saturating_sub(1),
                        "chunk boundary mismatch: the server returned a different ledger info for the overlap epoch",
                    ));
                }
            },
        }
        if chunk.first_epoch != self.next_epoch {
            return Err(err(
                self.next_epoch,
                format!(
                    "chunk starts at epoch {} (gap or overlap)",
                    chunk.first_epoch
                ),
            ));
        }
        self.waypoints.extend(chunk.waypoints);
        self.verified_epochs += chunk.num_verified;
        self.next_epoch += chunk.num_verified;
        self.last = Some(chunk.last.ledger_info().clone());
        Ok(())
    }

    /// `(epoch, waypoint)` of the newest verified (or trusted, if nothing newer) epoch end.
    pub fn latest(&self) -> Result<(u64, Waypoint), ChainError> {
        match &self.last {
            None => Err(err(self.trusted.epoch, "no chunks were verified")),
            Some(li) => Ok((
                li.epoch(),
                Waypoint::new_epoch_boundary(li).map_err(|e| err(li.epoch(), e.to_string()))?,
            )),
        }
    }
}

/// Convenience: verify a whole in-memory chain (`lis[0]` is the epoch-`trusted.epoch` ledger info)
/// in one chunk and return the final linker state. Used by tests and small runs.
pub fn verify_chain(
    trusted: TrustedStart,
    lis: Vec<LedgerInfoWithSignatures>,
    waypoint_every: u64,
) -> Result<Linker, ChainError> {
    let mut it = lis.into_iter();
    let prev = it
        .next()
        .ok_or_else(|| err(trusted.epoch, "no ledger infos supplied"))?;
    let chunk = Chunk {
        first_epoch: trusted.epoch + 1,
        prev,
        lis: it.collect(),
    };
    let mut linker = Linker::new(trusted);
    linker.accept(verify_chunk(chunk, waypoint_every)?)?;
    Ok(linker)
}

/// Request ranges `(start, end)` (end exclusive) such that every chunk carries its predecessor as
/// the first record. Covers epochs `trusted_epoch+1 .. end_epoch`; if that is empty, a single
/// one-record range fetching the trusted epoch's own ledger info.
pub fn plan_ranges(trusted_epoch: u64, end_epoch: u64, chunk_size: u64) -> Vec<(u64, u64)> {
    let chunk_size = chunk_size.max(1);
    let mut v = vec![];
    let mut s = trusted_epoch + 1;
    while s < end_epoch {
        let e = (s + chunk_size).min(end_epoch);
        v.push((s - 1, e));
        s = e;
    }
    if v.is_empty() {
        v.push((trusted_epoch, trusted_epoch + 1));
    }
    v
}

/// Decodes a raw response body (records are epoch `start..`) into a [`Chunk`], in parallel.
pub fn decode_chunk(start_epoch: u64, body: &[u8]) -> Result<Chunk> {
    let records = crate::framing::split_records(body)?;
    let mut lis: Vec<LedgerInfoWithSignatures> = records
        .par_iter()
        .enumerate()
        .map(|(i, r)| {
            bcs::from_bytes(r).map_err(|e| {
                anyhow!(
                    "epoch {}: ledger info failed to decode: {e}",
                    start_epoch + i as u64
                )
            })
        })
        .collect::<Result<_>>()?;
    if lis.is_empty() {
        return Err(anyhow!("epoch {start_epoch}: empty response"));
    }
    let prev = lis.remove(0);
    Ok(Chunk {
        first_epoch: start_epoch + 1,
        prev,
        lis,
    })
}

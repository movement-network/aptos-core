// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Wire framing of the backup service's record streams.
//!
//! The backup service (`storage/backup/backup-service/src/handlers/bytes_sender.rs`) streams a
//! sequence of records, each encoded as a 4 byte big-endian length followed by that many bytes of
//! BCS. This is a copy of the small amount of logic in `aptos-backup-cli`, so this crate does not
//! depend on the database.

use anyhow::{bail, ensure, Result};
use serde::de::DeserializeOwned;

/// Upper bound for a single record. An epoch-ending ledger info is far smaller than this; the bound
/// stops a corrupt length prefix from driving a huge allocation or a runaway parse.
pub const MAX_RECORD_BYTES: usize = 64 * 1024 * 1024;

/// Splits a complete response body into its record payloads (without length prefixes).
pub fn split_records(mut buf: &[u8]) -> Result<Vec<&[u8]>> {
    let mut records = Vec::new();
    while !buf.is_empty() {
        ensure!(
            buf.len() >= 4,
            "truncated stream: {} trailing byte(s), expected a 4 byte length prefix",
            buf.len()
        );
        let (len_bytes, rest) = buf.split_at(4);
        let len = u32::from_be_bytes(len_bytes.try_into().expect("4 bytes")) as usize;
        if len > MAX_RECORD_BYTES {
            bail!(
                "record length {} exceeds the {} byte limit",
                len,
                MAX_RECORD_BYTES
            );
        }
        ensure!(
            rest.len() >= len,
            "truncated stream: record declares {} bytes but only {} remain",
            len,
            rest.len()
        );
        let (record, rest) = rest.split_at(len);
        records.push(record);
        buf = rest;
    }
    Ok(records)
}

/// Decodes every record of a response body as BCS `T`.
pub fn decode_records<T: DeserializeOwned>(buf: &[u8]) -> Result<Vec<T>> {
    split_records(buf)?
        .into_iter()
        .enumerate()
        .map(|(i, r)| {
            bcs::from_bytes(r).map_err(|e| anyhow::anyhow!("record {} failed to decode: {}", i, e))
        })
        .collect()
}

/// Encodes records the way the backup service does (used by tests and the mock server).
pub fn encode_records<T: serde::Serialize>(records: &[T]) -> Result<Vec<u8>> {
    let mut out = Vec::new();
    for r in records {
        let bytes = bcs::to_bytes(r)?;
        out.extend_from_slice(&(bytes.len() as u32).to_be_bytes());
        out.extend_from_slice(&bytes);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip() {
        let v = vec![1u64, 2, 300];
        let enc = encode_records(&v).unwrap();
        assert_eq!(decode_records::<u64>(&enc).unwrap(), v);
    }

    #[test]
    fn empty_body_is_zero_records() {
        assert!(decode_records::<u64>(&[]).unwrap().is_empty());
    }

    #[test]
    fn truncated_prefix_and_body_fail() {
        let enc = encode_records(&[7u64]).unwrap();
        assert!(decode_records::<u64>(&enc[..2]).is_err());
        assert!(decode_records::<u64>(&enc[..enc.len() - 1]).is_err());
    }

    #[test]
    fn oversized_length_fails_without_allocating() {
        let mut enc = u32::MAX.to_be_bytes().to_vec();
        enc.extend_from_slice(&[0; 8]);
        assert!(split_records(&enc).is_err());
    }

    #[test]
    fn trailing_bytes_inside_record_fail() {
        // A record whose BCS payload has an extra byte must not decode silently.
        let mut enc = 9u32.to_be_bytes().to_vec();
        enc.extend_from_slice(&[1, 0, 0, 0, 0, 0, 0, 0, 0]);
        assert!(decode_records::<u64>(&enc).is_err());
    }
}

// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Minimal HTTP client for the backup service endpoints this tool needs.
//!
//! * `GET /db_state` -> BCS `Option<DbState>`
//! * `GET /epoch_ending_ledger_infos/<start_epoch>/<end_epoch>` -> size-prefixed BCS
//!   `LedgerInfoWithSignatures` records for epochs `[start_epoch, end_epoch)`.
//!
//! The server's iterator silently stops at the first ledger info that does not end an epoch, so a
//! short response is not an HTTP error. Callers must check the record count.

use crate::framing;
use anyhow::{anyhow, bail, Context, Result};
use bytes::Bytes;
use serde::{Deserialize, Serialize};
use std::time::Duration;

/// Mirror of `aptos_db::backup::backup_handler::DbState` (copied to avoid depending on the DB).
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct DbState {
    pub epoch: u64,
    pub committed_version: u64,
}

#[derive(Clone)]
pub struct BackupClient {
    base: String,
    http: reqwest::Client,
    retries: u32,
}

impl BackupClient {
    pub fn new(base_url: &str, retries: u32) -> Result<Self> {
        let http = reqwest::Client::builder()
            .no_proxy()
            .connect_timeout(Duration::from_secs(10))
            .timeout(Duration::from_secs(300))
            .build()?;
        Ok(Self {
            base: base_url.trim_end_matches('/').to_string(),
            http,
            retries,
        })
    }

    async fn get_once(&self, path: &str) -> Result<Bytes> {
        let url = format!("{}/{}", self.base, path);
        let resp = self
            .http
            .get(&url)
            .send()
            .await
            .with_context(|| format!("GET {url}"))?
            .error_for_status()
            .with_context(|| format!("GET {url}"))?;
        resp.bytes()
            .await
            .with_context(|| format!("reading body of GET {url}"))
    }

    async fn get(&self, path: &str) -> Result<Bytes> {
        let mut attempt = 0;
        loop {
            match self.get_once(path).await {
                Ok(b) => return Ok(b),
                Err(e) if attempt < self.retries => {
                    attempt += 1;
                    let backoff = Duration::from_millis(200 * (1 << attempt.min(6)));
                    eprintln!(
                        "warn: {e:#}; retry {attempt}/{} in {backoff:?}",
                        self.retries
                    );
                    tokio::time::sleep(backoff).await;
                },
                Err(e) => return Err(e),
            }
        }
    }

    pub async fn db_state(&self) -> Result<Option<DbState>> {
        let body = self.get("db_state").await?;
        bcs::from_bytes(&body).map_err(|e| anyhow!("db_state response did not decode: {e}"))
    }

    /// Raw framed body for epochs `[start_epoch, end_epoch)`. Validates framing and the record
    /// count (the server stops silently early) but leaves BCS decoding to the caller so it can run
    /// on the verification thread pool.
    pub async fn epoch_ending_ledger_infos_raw(
        &self,
        start_epoch: u64,
        end_epoch: u64,
    ) -> Result<Bytes> {
        let body = self
            .get(&format!(
                "epoch_ending_ledger_infos/{start_epoch}/{end_epoch}"
            ))
            .await?;
        let n = framing::split_records(&body)
            .with_context(|| format!("epochs [{start_epoch}, {end_epoch})"))?
            .len() as u64;
        let want = end_epoch - start_epoch;
        if n != want {
            bail!(
                "server returned {n} epoch-ending ledger infos for epochs [{start_epoch}, {end_epoch}), expected {want} \
                 (the backup service stops silently at the first non-epoch-ending entry or at the end of its data)"
            );
        }
        Ok(body)
    }

    /// Number of records the server returns for `[start_epoch, end_epoch)`, without the strict
    /// count check. Used to probe whether the newest ledger info itself ends an epoch.
    pub async fn probe_epoch_ending_count(&self, start_epoch: u64, end_epoch: u64) -> Result<u64> {
        let body = self
            .get(&format!(
                "epoch_ending_ledger_infos/{start_epoch}/{end_epoch}"
            ))
            .await?;
        Ok(framing::split_records(&body)?.len() as u64)
    }
}

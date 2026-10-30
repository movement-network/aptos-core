// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Fetch/verify pipeline: many concurrent range requests feed rayon verification as responses
//! arrive, in order, with bounded buffering so download and verification overlap.

use crate::{
    client::BackupClient,
    verify::{decode_chunk, plan_ranges, verify_chunk, Linker, TrustedStart},
};
use anyhow::{anyhow, Result};
use aptos_types::waypoint::Waypoint;
use futures::{stream, StreamExt};
use std::{
    sync::{
        atomic::{AtomicU64, Ordering::Relaxed},
        Arc,
    },
    time::{Duration, Instant},
};

#[derive(Clone, Debug)]
pub struct PipelineConfig {
    pub trusted: TrustedStart,
    /// Exclusive. `None` = everything the server has finished (see [`resolve_end_epoch`]).
    pub end_epoch: Option<u64>,
    /// Number of epochs per range request.
    pub chunk_size: u64,
    /// Concurrent range requests in flight (and chunks buffered awaiting in-order delivery).
    pub fetch_concurrency: usize,
    /// Chunks being decoded/verified at once (each is itself spread over all rayon threads).
    pub verify_concurrency: usize,
    /// Collect a waypoint for epochs divisible by this (0 = none).
    pub waypoint_interval: u64,
    pub progress_interval: Duration,
}

#[derive(Default)]
pub struct Counters {
    pub fetched_epochs: AtomicU64,
    pub verified_epochs: AtomicU64,
    pub bytes: AtomicU64,
    /// Sum over requests of wall time spent in the HTTP request (overlapping across requests).
    pub fetch_nanos: AtomicU64,
    /// Sum over chunks of wall time spent decoding+verifying (overlapping across chunks).
    pub verify_nanos: AtomicU64,
}

pub struct Outcome {
    pub latest_epoch: u64,
    pub latest_waypoint: Waypoint,
    pub waypoints: Vec<(u64, Waypoint)>,
    pub start_epoch: u64,
    pub end_epoch: u64,
    pub verified_epochs: u64,
    pub wall: Duration,
    pub fetch_cumulative: Duration,
    pub verify_cumulative: Duration,
    pub bytes: u64,
}

/// Picks the exclusive end epoch: the server's current epoch (certainly complete), plus one more if
/// the newest ledger info itself ends an epoch.
pub async fn resolve_end_epoch(client: &BackupClient) -> Result<u64> {
    let st = client
        .db_state()
        .await?
        .ok_or_else(|| anyhow!("backup service has no ledger info (db_state is empty)"))?;
    let mut end = st.epoch;
    if client.probe_epoch_ending_count(end, end + 1).await? == 1 {
        end += 1;
    }
    Ok(end)
}

pub async fn run(client: BackupClient, cfg: PipelineConfig) -> Result<Outcome> {
    let t0 = Instant::now();
    let end_epoch = match cfg.end_epoch {
        Some(e) => e,
        None => resolve_end_epoch(&client).await?,
    };
    let start_epoch = cfg.trusted.epoch;
    if end_epoch <= start_epoch {
        return Err(anyhow!(
            "end epoch {end_epoch} is not beyond the trusted epoch {start_epoch}; nothing newer to verify"
        ));
    }
    let ranges = plan_ranges(start_epoch, end_epoch, cfg.chunk_size);
    let total = end_epoch - start_epoch - 1;
    let counters = Arc::new(Counters::default());

    let progress = tokio::spawn(progress_task(
        counters.clone(),
        total,
        cfg.progress_interval,
    ));

    let interval = cfg.waypoint_interval;
    let fetch_counters = counters.clone();
    let verify_counters = counters.clone();
    let fetched = stream::iter(ranges)
        .map(move |(s, e)| {
            let client = client.clone();
            let c = fetch_counters.clone();
            async move {
                let t = Instant::now();
                let body = client.epoch_ending_ledger_infos_raw(s, e).await?;
                c.fetch_nanos
                    .fetch_add(t.elapsed().as_nanos() as u64, Relaxed);
                c.bytes.fetch_add(body.len() as u64, Relaxed);
                c.fetched_epochs.fetch_add(e - s - 1, Relaxed);
                Ok::<_, anyhow::Error>((s, body))
            }
        })
        .buffered(cfg.fetch_concurrency.max(1));
    let mut verified = fetched
        .map(move |res| {
            let c = verify_counters.clone();
            async move {
                let (s, body) = res?;
                let (tx, rx) = tokio::sync::oneshot::channel();
                rayon::spawn(move || {
                    let t = Instant::now();
                    let r: Result<_, anyhow::Error> = (|| {
                        let chunk = decode_chunk(s, &body)?;
                        verify_chunk(chunk, interval).map_err(anyhow::Error::from)
                    })();
                    c.verify_nanos
                        .fetch_add(t.elapsed().as_nanos() as u64, Relaxed);
                    let _ = tx.send(r);
                });
                rx.await.map_err(|_| anyhow!("verification task dropped"))?
            }
        })
        .buffered(cfg.verify_concurrency.max(1));

    let mut linker = Linker::new(cfg.trusted);
    let mut result: Result<()> = Ok(());
    while let Some(item) = verified.next().await {
        let step = item.and_then(|vc| {
            let n = vc.num_verified;
            linker.accept(vc).map_err(anyhow::Error::from)?;
            counters.verified_epochs.fetch_add(n, Relaxed);
            Ok(())
        });
        if let Err(e) = step {
            result = Err(e);
            break;
        }
    }
    drop(verified);
    progress.abort();
    result?;

    let (latest_epoch, latest_waypoint) = linker.latest().map_err(anyhow::Error::from)?;
    Ok(Outcome {
        latest_epoch,
        latest_waypoint,
        waypoints: linker.waypoints,
        start_epoch,
        end_epoch,
        verified_epochs: linker.verified_epochs,
        wall: t0.elapsed(),
        fetch_cumulative: Duration::from_nanos(counters.fetch_nanos.load(Relaxed)),
        verify_cumulative: Duration::from_nanos(counters.verify_nanos.load(Relaxed)),
        bytes: counters.bytes.load(Relaxed),
    })
}

async fn progress_task(c: Arc<Counters>, total: u64, every: Duration) {
    let t0 = Instant::now();
    let mut tick = tokio::time::interval(every);
    tick.tick().await;
    loop {
        tick.tick().await;
        let f = c.fetched_epochs.load(Relaxed);
        let v = c.verified_epochs.load(Relaxed);
        let secs = t0.elapsed().as_secs_f64().max(1e-9);
        let rate = v as f64 / secs;
        let eta = if rate > 0.0 {
            format!("{:.0}s", (total.saturating_sub(v)) as f64 / rate)
        } else {
            "?".into()
        };
        eprintln!(
            "progress: fetched {f}/{total} verified {v}/{total} ({:.1}%) fetch {:.0}/s verify {rate:.0}/s {:.1} MiB eta {eta}",
            100.0 * v as f64 / total.max(1) as f64,
            f as f64 / secs,
            c.bytes.load(Relaxed) as f64 / 1_048_576.0,
        );
    }
}

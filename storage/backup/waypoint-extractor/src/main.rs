// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use anyhow::{Context, Result};
use aptos_types::waypoint::Waypoint;
use aptos_waypoint_extractor::{
    client::BackupClient,
    pipeline::{run, PipelineConfig},
    verify::TrustedStart,
};
use clap::Parser;
use std::{io::Write, path::PathBuf, time::Duration};

/// Fetch every epoch-ending ledger info from a node's backup service, verify the chain from a
/// trusted waypoint using all cores, and print the latest verified waypoint on stdout.
#[derive(Parser, Debug)]
#[command(name = "aptos-waypoint-extractor", version)]
struct Args {
    /// Base URL of the node's backup service.
    #[arg(long, default_value = "http://127.0.0.1:6186")]
    backup_url: String,

    /// Trust root: the genesis waypoint, or a waypoint this tool verified earlier
    /// (`<version>:<hash>`).
    #[arg(long)]
    trusted_waypoint: Waypoint,

    /// Epoch whose ending ledger info `--trusted-waypoint` commits to (0 for the genesis waypoint;
    /// the epoch column of a waypoints file otherwise).
    #[arg(long, default_value_t = 0)]
    trusted_epoch: u64,

    /// Verify epochs up to but excluding this one. Default: every epoch the server has completed.
    #[arg(long)]
    end_epoch: Option<u64>,

    /// Epochs per range request.
    #[arg(long, default_value_t = 2000)]
    chunk_size: u64,

    /// Range requests in flight.
    #[arg(long, default_value_t = 16)]
    concurrency: usize,

    /// Chunks decoded/verified concurrently (default: number of CPUs).
    #[arg(long)]
    verify_concurrency: Option<usize>,

    /// Rayon worker threads (default: number of CPUs).
    #[arg(long)]
    threads: Option<usize>,

    /// Retries per failed HTTP request.
    #[arg(long, default_value_t = 5)]
    retries: u32,

    /// Also record the waypoint of every epoch divisible by this value (plus the final one).
    #[arg(long, default_value_t = 0)]
    waypoint_interval: u64,

    /// Write the collected waypoints here, one `<epoch> <version>:<hash>` per line.
    #[arg(long)]
    waypoints_out: Option<PathBuf>,

    /// Seconds between progress lines on stderr.
    #[arg(long, default_value_t = 5)]
    progress_secs: u64,
}

fn main() {
    if let Err(e) = real_main() {
        eprintln!("FAILED: {e:#}");
        std::process::exit(1);
    }
}

fn real_main() -> Result<()> {
    let args = Args::parse();
    if let Some(t) = args.threads {
        rayon::ThreadPoolBuilder::new()
            .num_threads(t)
            .build_global()
            .context("configuring rayon")?;
    }
    let cpus = std::thread::available_parallelism().map_or(4, |n| n.get());
    let client = BackupClient::new(&args.backup_url, args.retries)?;
    let cfg = PipelineConfig {
        trusted: TrustedStart {
            waypoint: args.trusted_waypoint,
            epoch: args.trusted_epoch,
        },
        end_epoch: args.end_epoch,
        chunk_size: args.chunk_size,
        fetch_concurrency: args.concurrency,
        verify_concurrency: args.verify_concurrency.unwrap_or(cpus),
        waypoint_interval: args.waypoint_interval,
        progress_interval: Duration::from_secs(args.progress_secs.max(1)),
    };
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;
    let out = rt.block_on(run(client, cfg))?;

    if let Some(path) = &args.waypoints_out {
        let mut f = std::io::BufWriter::new(
            std::fs::File::create(path).with_context(|| format!("creating {}", path.display()))?,
        );
        writeln!(f, "# epoch version:hash (verified from epoch {} by aptos-waypoint-extractor)", out.start_epoch)?;
        let mut wps = out.waypoints.clone();
        if wps.last().map(|(e, _)| *e) != Some(out.latest_epoch) {
            wps.push((out.latest_epoch, out.latest_waypoint));
        }
        for (e, w) in wps {
            writeln!(f, "{e} {w}")?;
        }
        f.flush()?;
    }

    let wall = out.wall.as_secs_f64();
    eprintln!("verified epochs {}..={} ({} epochs) from trusted epoch {}", out.start_epoch + 1, out.latest_epoch, out.verified_epochs, out.start_epoch);
    eprintln!("latest verified epoch: {}", out.latest_epoch);
    eprintln!(
        "summary: wall {wall:.1}s | fetch (sum of request times, overlapping) {:.1}s | verify (sum of chunk decode+verify times, overlapping) {:.1}s | {:.1} MiB | {:.0} epochs/s",
        out.fetch_cumulative.as_secs_f64(),
        out.verify_cumulative.as_secs_f64(),
        out.bytes as f64 / 1_048_576.0,
        out.verified_epochs as f64 / wall.max(1e-9),
    );
    eprintln!(
        "to bootstrap a node: base.waypoint.from_config: \"{}\" and state_sync.state_sync_driver.start_epoch: {}",
        out.latest_waypoint, out.latest_epoch
    );
    println!("{}", out.latest_waypoint);
    Ok(())
}

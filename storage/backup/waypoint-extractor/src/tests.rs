// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    client::{BackupClient, DbState},
    framing,
    pipeline::{run, PipelineConfig},
    verify::{plan_ranges, verify_chain, verify_chunk, Chunk, Linker, TrustedStart},
};
use aptos_crypto::HashValue;
use aptos_types::{
    aggregate_signature::AggregateSignature,
    block_info::BlockInfo,
    epoch_state::EpochState,
    ledger_info::{generate_ledger_info_with_sig, LedgerInfo, LedgerInfoWithSignatures},
    validator_signer::ValidatorSigner,
    validator_verifier::{ValidatorConsensusInfo, ValidatorVerifier},
    waypoint::Waypoint,
};
use std::{sync::Arc, time::Duration};

const SET_LEN: u8 = 4;
/// The validator set changes every `ROTATE` epochs so tests cover both cache hits and set changes.
const ROTATE: u64 = 3;

fn set_for(epoch: u64) -> Vec<ValidatorSigner> {
    let gen = epoch / ROTATE;
    (0..SET_LEN)
        .map(|i| ValidatorSigner::random([(gen as u8).wrapping_mul(16).wrapping_add(i + 1); 32]))
        .collect()
}

fn verifier_of(signers: &[ValidatorSigner]) -> ValidatorVerifier {
    ValidatorVerifier::new(
        signers
            .iter()
            .map(|s| ValidatorConsensusInfo::new(s.author(), s.public_key(), 1))
            .collect(),
    )
}

fn block_info(epoch: u64, version: u64) -> BlockInfo {
    BlockInfo::new(
        epoch,
        epoch * 10,
        HashValue::zero(),
        HashValue::zero(),
        version,
        1_000 + epoch,
        Some(EpochState::new(epoch + 1, verifier_of(&set_for(epoch + 1)))),
    )
}

/// Ledger info for the end of `epoch`, signed by `signers`.
fn signed_li(epoch: u64, version: u64, signers: &[ValidatorSigner]) -> LedgerInfoWithSignatures {
    generate_ledger_info_with_sig(
        signers,
        LedgerInfo::new(block_info(epoch, version), HashValue::zero()),
    )
}

/// Valid chain for epochs `0..n`. Epoch 0 is the unsigned genesis ledger info.
fn chain(n: u64) -> Vec<LedgerInfoWithSignatures> {
    (0..n)
        .map(|e| {
            if e == 0 {
                LedgerInfoWithSignatures::new(
                    LedgerInfo::new(block_info(0, 0), HashValue::zero()),
                    AggregateSignature::empty(),
                )
            } else {
                signed_li(e, e * 22, &set_for(e))
            }
        })
        .collect()
}

fn genesis_trust(chain: &[LedgerInfoWithSignatures]) -> TrustedStart {
    TrustedStart {
        waypoint: Waypoint::new_epoch_boundary(chain[0].ledger_info()).unwrap(),
        epoch: 0,
    }
}

#[test]
fn valid_chain_passes_and_yields_latest_waypoint() {
    let c = chain(20);
    let want = Waypoint::new_epoch_boundary(c[19].ledger_info()).unwrap();
    let l = verify_chain(genesis_trust(&c), c.clone(), 5).unwrap();
    assert_eq!(l.verified_epochs, 19);
    assert_eq!(l.latest().unwrap(), (19, want));
    let epochs: Vec<_> = l.waypoints.iter().map(|(e, _)| *e).collect();
    assert_eq!(epochs, vec![5, 10, 15]);
    assert_eq!(
        l.waypoints[0].1,
        Waypoint::new_epoch_boundary(c[5].ledger_info()).unwrap()
    );
}

#[test]
fn incremental_run_from_a_later_waypoint_passes() {
    let c = chain(20);
    let trust = TrustedStart {
        waypoint: Waypoint::new_epoch_boundary(c[10].ledger_info()).unwrap(),
        epoch: 10,
    };
    let l = verify_chain(trust, c[10..].to_vec(), 0).unwrap();
    assert_eq!(l.verified_epochs, 9);
    assert_eq!(l.latest().unwrap().0, 19);
}

#[test]
fn bad_signature_fails_at_that_epoch() {
    let mut c = chain(20);
    // Epoch 7 carries the (valid) signature of epoch 8 over a different message.
    let other = signed_li(8, 8 * 22, &set_for(7));
    c[7] = LedgerInfoWithSignatures::new(c[7].ledger_info().clone(), other.signatures().clone());
    let e = verify_chain(genesis_trust(&c), c, 0).err().unwrap();
    assert_eq!(e.epoch, 7, "{e}");
}

#[test]
fn missing_signature_fails() {
    let mut c = chain(10);
    c[4] = LedgerInfoWithSignatures::new(c[4].ledger_info().clone(), AggregateSignature::empty());
    assert_eq!(
        verify_chain(genesis_trust(&c), c, 0).err().unwrap().epoch,
        4
    );
}

#[test]
fn insufficient_voting_power_fails() {
    let mut c = chain(10);
    // 2 of 4 signers is below the 2f+1 quorum.
    c[6] = signed_li(6, 6 * 22, &set_for(6)[..2]);
    assert_eq!(
        verify_chain(genesis_trust(&c), c, 0).err().unwrap().epoch,
        6
    );
}

#[test]
fn gap_fails() {
    let mut c = chain(10);
    c.remove(5);
    let e = verify_chain(genesis_trust(&c), c, 0).err().unwrap();
    assert_eq!(e.epoch, 5, "{e}");
}

#[test]
fn wrong_validator_set_fails() {
    let mut c = chain(12);
    // Epoch 8 signed by the set of a different generation (full-power, validly formed, wrong keys).
    c[8] = signed_li(8, 8 * 22, &set_for(8 + ROTATE));
    let e = verify_chain(genesis_trust(&c), c, 0).err().unwrap();
    assert_eq!(e.epoch, 8, "{e}");
}

#[test]
fn first_failing_epoch_is_reported_when_several_fail() {
    let mut c = chain(200);
    c[150] = signed_li(150, 150 * 22, &set_for(1));
    c[40] = signed_li(40, 40 * 22, &set_for(1));
    assert_eq!(
        verify_chain(genesis_trust(&c), c, 0).err().unwrap().epoch,
        40
    );
}

#[test]
fn waypoint_mismatch_fails() {
    let c = chain(10);
    let mut t = genesis_trust(&c);
    t.waypoint = Waypoint::new_epoch_boundary(c[1].ledger_info()).unwrap();
    let e = verify_chain(t, c.clone(), 0).err().unwrap();
    assert_eq!(e.epoch, 0);
    assert!(e.reason.contains("waypoint"), "{e}");

    // Right waypoint, wrong claimed epoch.
    let mut t = genesis_trust(&c);
    t.epoch = 1;
    assert!(verify_chain(t, c, 0).is_err());
}

#[test]
fn non_epoch_ending_and_version_regression_fail() {
    let mut c = chain(10);
    let bi = BlockInfo::new(5, 50, HashValue::zero(), HashValue::zero(), 5 * 22, 1, None);
    c[5] = generate_ledger_info_with_sig(&set_for(5), LedgerInfo::new(bi, HashValue::zero()));
    assert_eq!(
        verify_chain(genesis_trust(&c), c, 0).err().unwrap().epoch,
        5
    );

    let mut c = chain(10);
    c[6] = signed_li(6, 5 * 22, &set_for(6)); // not above epoch 5's version
    assert_eq!(
        verify_chain(genesis_trust(&c), c, 0).err().unwrap().epoch,
        6
    );
}

#[test]
fn chunks_link_and_tampered_overlap_is_rejected() {
    let c = chain(30);
    let trust = genesis_trust(&c);
    let mk = |s: usize, e: usize| Chunk {
        first_epoch: s as u64,
        prev: c[s - 1].clone(),
        lis: c[s..e].to_vec(),
    };
    let mut l = Linker::new(trust);
    for (s, e) in [(1, 10), (10, 20), (20, 30)] {
        l.accept(verify_chunk(mk(s, e), 0).unwrap()).unwrap();
    }
    assert_eq!(l.verified_epochs, 29);

    // The second chunk's overlap record differs from what the first chunk ended with.
    let mut l = Linker::new(trust);
    l.accept(verify_chunk(mk(1, 10), 0).unwrap()).unwrap();
    let mut bad = mk(10, 20);
    bad.prev = signed_li(9, 9 * 22 + 1, &set_for(9));
    // Individually the bad chunk may still verify against its own (forged) predecessor...
    let vc = verify_chunk(bad, 0);
    // ...but it can never join the chain.
    if let Ok(vc) = vc {
        assert!(l.accept(vc).is_err());
    }

    // Skipped chunk (gap between chunks).
    let mut l = Linker::new(trust);
    l.accept(verify_chunk(mk(1, 10), 0).unwrap()).unwrap();
    assert!(l.accept(verify_chunk(mk(11, 20), 0).unwrap()).is_err());
}

#[test]
fn zero_quorum_empty_set_is_rejected() {
    // A predecessor handing over an empty validator set must not make everything verify.
    let li0 = LedgerInfoWithSignatures::new(
        LedgerInfo::new(
            BlockInfo::new(
                0,
                0,
                HashValue::zero(),
                HashValue::zero(),
                0,
                0,
                Some(EpochState::new(1, ValidatorVerifier::new(vec![]))),
            ),
            HashValue::zero(),
        ),
        AggregateSignature::empty(),
    );
    let li1 = LedgerInfoWithSignatures::new(
        LedgerInfo::new(block_info(1, 22), HashValue::zero()),
        AggregateSignature::empty(),
    );
    let t = TrustedStart {
        waypoint: Waypoint::new_epoch_boundary(li0.ledger_info()).unwrap(),
        epoch: 0,
    };
    assert_eq!(verify_chain(t, vec![li0, li1], 0).err().unwrap().epoch, 1);
}

#[test]
fn cached_verification_agrees_with_library_verifier() {
    let c = chain(12);
    for e in 1..12usize {
        let v: Arc<ValidatorVerifier> = c[e - 1]
            .ledger_info()
            .next_epoch_state()
            .unwrap()
            .verifier
            .clone();
        c[e].verify_signatures(&v).unwrap();
    }
    // And on a corrupted one, both reject.
    let bad = signed_li(5, 5 * 22, &set_for(1));
    let v = c[4]
        .ledger_info()
        .next_epoch_state()
        .unwrap()
        .verifier
        .clone();
    assert!(bad.verify_signatures(&v).is_err());
}

#[test]
fn plan_ranges_cover_epochs_with_one_record_overlap() {
    assert_eq!(plan_ranges(0, 11, 4), vec![(0, 5), (4, 9), (8, 11)]);
    assert_eq!(plan_ranges(5, 6, 4), vec![(5, 6)]);
    assert_eq!(plan_ranges(0, 2, 100), vec![(0, 2)]);
}

// ---- mock backup service --------------------------------------------------------------------

use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
};

/// Serves the backup service protocol for an in-memory chain on an ephemeral port.
async fn mock_server(chain: Vec<LedgerInfoWithSignatures>, short_by: u64) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let chain = Arc::new(chain);
    tokio::spawn(async move {
        loop {
            let Ok((mut sock, _)) = listener.accept().await else {
                return;
            };
            let chain = chain.clone();
            tokio::spawn(async move {
                let mut buf = vec![0u8; 4096];
                let n = sock.read(&mut buf).await.unwrap_or(0);
                let req = String::from_utf8_lossy(&buf[..n]).to_string();
                let path = req.split_whitespace().nth(1).unwrap_or("").to_string();
                let parts: Vec<&str> = path.trim_matches('/').split('/').collect();
                let body: Option<Vec<u8>> = match parts.as_slice() {
                    ["db_state"] => Some(
                        bcs::to_bytes(&Some(DbState {
                            epoch: chain.len() as u64,
                            committed_version: 1_000_000,
                        }))
                        .unwrap(),
                    ),
                    ["epoch_ending_ledger_infos", s, e] => {
                        let (s, e): (usize, usize) = (s.parse().unwrap(), e.parse().unwrap());
                        // Like the real iterator: stops silently when data runs out.
                        let e = e.min(chain.len().saturating_sub(short_by as usize));
                        let recs = if s < e { &chain[s..e] } else { &chain[0..0] };
                        Some(framing::encode_records(recs).unwrap())
                    },
                    _ => None,
                };
                let resp = match body {
                    Some(b) => {
                        let mut r = format!(
                            "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                            b.len()
                        )
                        .into_bytes();
                        r.extend(b);
                        r
                    },
                    None => {
                        b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                            .to_vec()
                    },
                };
                let _ = sock.write_all(&resp).await;
                let _ = sock.shutdown().await;
            });
        }
    });
    format!("http://{addr}")
}

fn cfg(trusted: TrustedStart) -> PipelineConfig {
    PipelineConfig {
        trusted,
        end_epoch: None,
        chunk_size: 7,
        fetch_concurrency: 4,
        verify_concurrency: 4,
        waypoint_interval: 10,
        progress_interval: Duration::from_secs(60),
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn mock_server_end_to_end() {
    let c = chain(60);
    let url = mock_server(c.clone(), 0).await;
    let client = BackupClient::new(&url, 0).unwrap();

    let st = client.db_state().await.unwrap().unwrap();
    assert_eq!(st.epoch, 60);

    let out = run(client, cfg(genesis_trust(&c))).await.unwrap();
    assert_eq!(out.latest_epoch, 59);
    assert_eq!(out.verified_epochs, 59);
    assert_eq!(
        out.latest_waypoint,
        Waypoint::new_epoch_boundary(c[59].ledger_info()).unwrap()
    );
    assert_eq!(
        out.waypoints.iter().map(|w| w.0).collect::<Vec<_>>(),
        vec![10, 20, 30, 40, 50]
    );
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn mock_server_tampered_chain_reports_epoch() {
    let mut c = chain(60);
    c[33] = signed_li(33, 33 * 22, &set_for(1));
    let url = mock_server(c.clone(), 0).await;
    let client = BackupClient::new(&url, 0).unwrap();
    let e = run(client, cfg(genesis_trust(&c))).await.err().unwrap();
    assert!(format!("{e}").contains("epoch 33"), "{e}");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn mock_server_short_response_is_an_error_not_a_shorter_chain() {
    let c = chain(60);
    // Server advertises 60 epochs (db_state) but only serves 58 of them.
    let url = mock_server(c.clone(), 2).await;
    let client = BackupClient::new(&url, 0).unwrap();
    let mut conf = cfg(genesis_trust(&c));
    conf.end_epoch = Some(60);
    let e = run(client, conf).await.err().unwrap();
    assert!(format!("{e:#}").contains("expected"), "{e:#}");
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn mock_server_wrong_trusted_waypoint_fails() {
    let c = chain(20);
    let url = mock_server(c.clone(), 0).await;
    let client = BackupClient::new(&url, 0).unwrap();
    let mut t = genesis_trust(&c);
    t.waypoint = Waypoint::new_epoch_boundary(c[2].ledger_info()).unwrap();
    assert!(run(client, cfg(t)).await.is_err());
}

/// Throughput smoke measurement:
/// `cargo test -p aptos-waypoint-extractor --release -- --ignored --nocapture`
#[test]
#[ignore]
fn verify_throughput() {
    let c = chain(20_000);
    let t = genesis_trust(&c);
    let start = std::time::Instant::now();
    let l = verify_chain(t, c, 0).unwrap();
    let secs = start.elapsed().as_secs_f64();
    eprintln!(
        "verified {} epochs in {secs:.2}s = {:.0} epochs/s on {} threads",
        l.verified_epochs,
        l.verified_epochs as f64 / secs,
        rayon::current_num_threads()
    );
}

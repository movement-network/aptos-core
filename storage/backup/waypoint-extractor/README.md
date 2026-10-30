# aptos-waypoint-extractor

Fetches every epoch-ending ledger info from a synced node's backup service, verifies the whole
chain from a trusted starting point using all CPU cores (network I/O overlapped with
verification), and prints the latest verified waypoint. Optionally writes waypoints for every N
epochs.

Purpose: on Movement mainnet an epoch ends every ~22 transactions (~10.8M epochs at version
~236M). A node fast-syncing from the genesis waypoint verifies every epoch-change ledger info one
after another, which takes hours and a lot of memory. With a recent *verified* waypoint the node
only needs the state snapshot and recent transactions.

## Build

```
cargo build -p aptos-waypoint-extractor --release
```

The crate depends on `aptos-types`/`aptos-crypto` only (no `aptos-db`, no RocksDB, no
`aptos-backup-cli`). The small backup-service framing logic is copied in `src/framing.rs`.

## Usage

```
aptos-waypoint-extractor \
  --backup-url http://<node>:6186 \
  --trusted-waypoint <version>:<hash> \      # the genesis waypoint, or an earlier verified one
  [--trusted-epoch N] \                      # epoch that waypoint commits to (0 for genesis)
  [--end-epoch M] \                          # exclusive; default: all completed epochs
  [--waypoint-interval 100000 --waypoints-out waypoints.txt] \
  [--chunk-size 2000 --concurrency 16 --verify-concurrency 20 --threads 20 --retries 5]
```

* stdout: one line, the latest verified waypoint (`<version>:<hash>`).
* stderr: progress every `--progress-secs` (epochs fetched/verified, rate, ETA) and a final summary
  (wall time; summed request time; summed decode+verify time; bytes). The summed times overlap
  each other and the wall time, since requests and verification run concurrently.
* `--waypoints-out`: lines `<epoch> <version>:<hash>` for every epoch divisible by the interval,
  plus the final one. The epoch column is what you pass as `--trusted-epoch` to resume from that
  waypoint (incremental runs), and what you set as `start_epoch` on a node (below).
* Exit status is non-zero on any failure. The message names the failing epoch
  (`verification failed at epoch N: ...`), or the fetch error.

The backup service listens on port 6186 by default (`storage.backup_service_address`); it is
unauthenticated, so keep it off public networks and reach it via a port-forward or private address.

## What is verified

For each epoch `i` in `trusted_epoch+1 ..< end`:

1. the ledger info is for epoch `i`, ends its epoch, and carries `next_epoch_state` for `i+1`;
2. its version is greater than epoch `i-1`'s;
3. its aggregate BLS signature verifies, with a quorum of voting power, under the validator set in
   epoch `i-1`'s `next_epoch_state` (the aggregated public key is cached per validator set and signer
   bitmap, since consecutive epochs mostly share both);
4. (anchor) the ledger info at `trusted_epoch` hashes to the trusted waypoint.

Checks 1-3 for epoch `i` depend only on epoch `i-1`'s ledger info, so each range request also
carries its predecessor as its first record and chunks verify independently, in parallel; rayon
spreads the signature checks over all cores. A cheap sequential pass then joins the chunks: each
chunk's predecessor record must equal the previous chunk's last ledger info, and epochs must be
contiguous. Short server responses (the backup service silently stops at the end of its data or at
the first non-epoch-ending entry) are errors, not shorter chains.

## Trust model

The output is trusted exactly as far as its input: the trust root is `--trusted-waypoint`, which
you obtain out of band (the genesis waypoint of the chain, or a waypoint produced by an earlier run
of this tool that started from genesis). The backup service that serves the data is **not**
trusted: every byte it returns is checked against signatures chained back to the trust root, and a
malicious server can at worst make the run fail. Unsigned data it could still influence are not
part of the output.

Caveats: a waypoint says "the chain contains this ledger info"; like any validator-set chain
check, it does not protect against a long-range attack by retired validator keys, which is why the
root should be your own genesis waypoint or something you verified yourself. Verification assumes
the BLS keys in each `next_epoch_state` are the on-chain proof-of-possession-checked keys, as for
every Aptos node.

## Using the result on a node

Set the node's trusted waypoint and tell state sync which epoch it commits to:

```yaml
base:
  waypoint:
    from_config: "<version>:<hash>"       # the tool's stdout
state_sync:
  state_sync_driver:
    start_epoch: <epoch>                   # the epoch column of the waypoints file / "latest verified epoch"
    bootstrapping_mode: DownloadLatestStates   # fast sync
```

The `TRUST_WAYPOINT` input of the native-restore script (not part of this repository) is expected to map to `base.waypoint.from_config`; it must also set `start_epoch`.

Notes on what the node code does (checked against commit `4be787e50`, see
`state-sync/state-sync-driver/src/bootstrapper.rs`): the bootstrapper, when asked to fetch epoch
ending ledger infos for an empty database, starts the stream at `state_sync_driver.start_epoch`
when that is set (otherwise at the node's local epoch, i.e. genesis), and the first ledger info it
receives whose version equals the configured waypoint's version is checked by waypoint hash instead
of by signatures. So `start_epoch` must be the epoch of the waypoint's ledger info.

## Tests

```
cargo test -p aptos-waypoint-extractor
```

Unit tests generate rotating validator sets and signatures: a valid chain passes; bad signature,
missing signature, insufficient quorum, gap, wrong validator set, waypoint mismatch, non-ending
ledger info, version regression, tampered chunk boundary and empty validator set each fail with
the expected epoch. A mock backup-service HTTP server tests framing, end-to-end runs, silent
short responses, tampering over the wire and wrong trust roots. The tests need no node and no
network beyond localhost.

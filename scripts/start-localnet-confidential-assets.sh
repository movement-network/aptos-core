#!/usr/bin/env bash
# Start Movement localnet (validator REST + faucet, no Docker indexer), enable confidential-assets
# feature flag 87 (BULLETPROOFS_BATCH_NATIVES) via mint.key, then bootstrap the chain and asset
# auditors using the account in .movement/config.yaml (see MOVEMENT_PROFILE).
#
# confidential_asset ships in the Aptos framework, so it is already on-chain at 0x1 after genesis.
# Nothing needs publishing for it; this script only flips the feature flag and sets the auditors.
#
# From repo root:
#   ./scripts/start-localnet-confidential-assets.sh
#
# If $REPO_ROOT/.movement/config.yaml is missing (no `movement init` yet), this script creates one
# automatically after the localnet REST API is up: generates an Ed25519 key and runs
# `movement init --network custom --rest-url $NODE_URL` so the auditor bootstrap has a signer without
# a prior manual init. Existing configs are left unchanged if `movement config show-profiles` succeeds
# for MOVEMENT_PROFILE. Set SKIP_MOVEMENT_CONFIG_INIT=1 to disable auto-init (the auditor bootstrap
# fails if no config).
#
# Ports (not the same service):
#   • 8080 — fullnode REST API (ledger), what `move run-script --url` uses. Your log line
#            "REST API endpoint: http://127.0.0.1:8080" is this.
#   • 8070 — localnet "ready server" only: a tiny HTTP endpoint the CLI runs so clients can wait
#            until configured services pass health checks (node + faucet for this stack). It is NOT
#            the blockchain API. The CLI prints: Readiness endpoint: http://127.0.0.1:8070/
#   To wait only for the node REST API (8080), set:  WAIT_STRATEGY=node
#
# Environment:
#   MOVEMENT      — movement CLI (default: $REPO_ROOT/target/release/movement, built via
#                   `cargo build -p movement --release` if missing). Override with
#                   MOVEMENT=/path/to/binary. The local build keeps the on-chain framework
#                   in sync with this checked-out repo.
#   SKIP_MOVEMENT_BUILD=1 — do not build movement CLI; fall back to `movement` on $PATH if
#                   $REPO_ROOT/target/release/movement isn't already built.
#   REPO_ROOT     — repo root (default: parent of scripts/)
#   APTOS_LOCALNET_TEST_DIR — localnet data dir (default: $REPO_ROOT/.movement/testnet)
#   NODE_URL      — REST base for `move run-script` (default: http://127.0.0.1:8080; refreshed from
#                   $TEST_DIR/0/node.yaml when that file appears)
#   READY_URL     — ready-server URL (default: http://127.0.0.1:8070/) when WAIT_STRATEGY=ready.
#   WAIT_STRATEGY — ready | node (default: ready). "node" polls only NODE_URL/v1 (validator up).
#   NODE_WAIT_TIMEOUT_SECS — max poll time (default: 120). When everything is healthy, localnet
#          usually becomes ready in ~20s; raise this on slow hosts.
#   SKIP_START=1  — skip starting localnet; only run the feature-flag transaction
#   BACKGROUND=0  — run localnet in the foreground (blocks; run feature step separately)
#   KEEP_LOCALNET — after success, keep localnet running (default: 1). Set to 0 to always stop on exit.
#          On failure, localnet is always shut down if this script started it (no orphan process).
#   LOCALNET_ATTACH — when KEEP_LOCALNET=1 and this script started localnet in the background (default: 1),
#          block at the end on `wait` until the localnet process exits or you press Ctrl+C (which stops
#          localnet via the EXIT trap). Set to 0 to return to the shell immediately while localnet keeps
#          running (then stop with: kill "$(cat .movement/localnet.pid)" from REPO_ROOT).
#   NODE_REST_WAIT_SECS — after the ready server, max time to wait for NODE_URL/v1 (default: 90).
#   CORE_RESOURCES_ADDRESS — on-chain @core_resources address (default: 0xa550c18). Genesis creates
#          this account at a fixed address then rotates its auth key to mint.key, so it is NOT the
#          same as the address the CLI derives from the public key alone. We fund both via faucet,
#          and pass --sender-account here so move run-script pays fees from 0xa550c18.
#   FAUCET_URL — passed to fund-with-faucet (default: http://127.0.0.1:8081)
#   FAUCET_WAIT_TIMEOUT_SECS — max time to keep polling for a ready faucet (default: 180). The script
#          does NOT sleep a fixed 180s: it polls GET $FAUCET_URL/ every POLL_INTERVAL_SECS until the
#          response body is tap:ok (official tap health), then runs fund-with-faucet immediately.
#          If tap:ok never appears within this budget, the script exits with an error.
#   FAUCET_HTTP_MAX_TIME — per-request curl --max-time when probing the faucet (default: 5)
#   FAUCET_AMOUNT — Octas to request (default: 10000000000)
#   SKIP_FAUCET=1 — skip the pre-flight fund step (otherwise python3 is used once to derive the
#          pubkey-based address for the second fund-with-faucet call)
#   MOVE_RUN_SCRIPT_MAX_GAS — --max-gas for move run-script (default: 2000000). On-chain
#          maximum_number_of_gas_units is capped (e.g. 2_000_000 in config/global-constants for
#          production genesis); higher values fail with MAX_GAS_UNITS_EXCEEDS_MAX_GAS_UNITS_BOUND.
#   MOVEMENT_PROFILE — profile in $REPO_ROOT/.movement/config.yaml whose account is designated
#          chain_auditor_admin and signs set_chain_auditor (default: default).
#   SKIP_MOVEMENT_CONFIG_INIT=1 — do not auto-create .movement/config.yaml when missing (requires
#          an existing usable profile when SKIP_AUDITOR_BOOTSTRAP=0).
#   SKIP_AUDITOR_BOOTSTRAP=1 — skip the chain-auditor bootstrap (admin designation +
#          set_chain_auditor) after the feature-flag script
#   SKIP_ASSET_AUDITOR=1 — skip setting the MOVE (FA @0xa) asset auditor key

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_default_repo_root="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="${REPO_ROOT:-$_default_repo_root}"
# Use a locally-built movement binary so the on-chain framework matches this checked-out repo.
# Build it if missing. Override the binary path with MOVEMENT=/path/to/binary; skip the build
# (e.g. to use whatever's on $PATH) with SKIP_MOVEMENT_BUILD=1.
_local_movement="${REPO_ROOT}/target/release/movement"
SKIP_MOVEMENT_BUILD="${SKIP_MOVEMENT_BUILD:-0}"
if [[ -z "${MOVEMENT:-}" ]]; then
  if [[ ! -x "$_local_movement" && "$SKIP_MOVEMENT_BUILD" != "1" ]]; then
    echo "Building movement CLI (cargo build -p movement --release; first build can take 10+ minutes)..."
    (cd "$REPO_ROOT" && cargo build -p movement --release)
  fi
  if [[ -x "$_local_movement" ]]; then
    MOVEMENT="$_local_movement"
  fi
fi
MOVEMENT="${MOVEMENT:-movement}"
TEST_DIR="${APTOS_LOCALNET_TEST_DIR:-$REPO_ROOT/.movement/testnet}"
LOCALNET_LOG="${REPO_ROOT}/.movement/localnet.log"
LOCALNET_PID_FILE="${REPO_ROOT}/.movement/localnet.pid"
NODE_URL="${NODE_URL:-http://127.0.0.1:8080}"
READY_URL="${READY_URL:-http://127.0.0.1:8070}"
FRAMEWORK_DIR="$REPO_ROOT/aptos-move/framework/aptos-framework"
SKIP_START="${SKIP_START:-0}"
BACKGROUND="${BACKGROUND:-1}"
NODE_WAIT_TIMEOUT_SECS="${NODE_WAIT_TIMEOUT_SECS:-120}"
MINT_KEY_WAIT_SECS="${MINT_KEY_WAIT_SECS:-60}"
POLL_INTERVAL_SECS="${POLL_INTERVAL_SECS:-0.5}"
WAIT_STRATEGY="${WAIT_STRATEGY:-ready}"
KEEP_LOCALNET="${KEEP_LOCALNET:-1}"
LOCALNET_ATTACH="${LOCALNET_ATTACH:-1}"
NODE_REST_WAIT_SECS="${NODE_REST_WAIT_SECS:-90}"
CORE_RESOURCES_ADDRESS="${CORE_RESOURCES_ADDRESS:-0xa550c18}"
FAUCET_URL="${FAUCET_URL:-http://127.0.0.1:8081}"
FAUCET_WAIT_TIMEOUT_SECS="${FAUCET_WAIT_TIMEOUT_SECS:-180}"
FAUCET_HTTP_MAX_TIME="${FAUCET_HTTP_MAX_TIME:-5}"
FAUCET_AMOUNT="${FAUCET_AMOUNT:-10000000000}"
SKIP_FAUCET="${SKIP_FAUCET:-0}"
FAUCET_FUND_CONN_TIMEOUT_SECS="${FAUCET_FUND_CONN_TIMEOUT_SECS:-45}"
MOVE_RUN_SCRIPT_MAX_GAS="${MOVE_RUN_SCRIPT_MAX_GAS:-2000000}"
MOVEMENT_PROFILE="${MOVEMENT_PROFILE:-default}"
SKIP_AUDITOR_BOOTSTRAP="${SKIP_AUDITOR_BOOTSTRAP:-0}"
SKIP_MOVEMENT_CONFIG_INIT="${SKIP_MOVEMENT_CONFIG_INIT:-0}"
# Set to 1 only after we nohup localnet in this shell (EXIT trap uses this).
STARTED_LOCALNET_BG=0

if ! command -v "$MOVEMENT" >/dev/null 2>&1; then
  echo "error: '$MOVEMENT' not found. Set MOVEMENT or add it to PATH." >&2
  exit 1
fi

if [[ ! -d "$FRAMEWORK_DIR" ]]; then
  echo "error: framework not found at $FRAMEWORK_DIR" >&2
  exit 1
fi

# Parse REST bind from generated validator config (host for curl).
refresh_node_url_from_node_yaml() {
  local f="$TEST_DIR/0/node.yaml"
  [[ -f "$f" ]] || return 1
  local addr
  addr=$(awk '
    /^api:/ { in_api=1; next }
    in_api && /^[a-zA-Z]/ && $0 !~ /^  / { exit }
    in_api && /^  address:/ {
      sub(/^  address:[[:space:]]+/, "")
      gsub(/"/, "")
      print
      exit
    }
  ' "$f")
  [[ -n "$addr" ]] || return 1
  addr="${addr//0.0.0.0/127.0.0.1}"
  NODE_URL="http://${addr}"
}

dump_failure_hints() {
  echo "" >&2
  echo "---- last lines of $LOCALNET_LOG (nohup stdout/stderr) ----" >&2
  tail -n 40 "$LOCALNET_LOG" 2>/dev/null || echo "(no log file)" >&2
  echo "----" >&2
  echo "Per-service trace logs are often under: $TEST_DIR" >&2
  echo "Wait strategy: WAIT_STRATEGY=$WAIT_STRATEGY (ready=$READY_URL vs node=$NODE_URL/v1)" >&2
}

# Returns 0 when the chosen wait target responds (curl -sf).
localnet_responds() {
  refresh_node_url_from_node_yaml || true
  case "$WAIT_STRATEGY" in
    node)
      curl -sf "${NODE_URL}/v1" >/dev/null 2>&1
      ;;
    ready | *)
      curl -sf "$READY_URL" >/dev/null 2>&1
      ;;
  esac
}

wait_target_description() {
  case "$WAIT_STRATEGY" in
    node) echo "node REST ${NODE_URL}/v1" ;;
    *) echo "ready server $READY_URL (node + faucet health checks)" ;;
  esac
}

# Ready on 8070 can be a stale 200 if an old process left the port open; always confirm REST /v1.
ensure_node_rest_responds() {
  local start=$SECONDS
  local max=$NODE_REST_WAIT_SECS
  echo "Checking node REST at ${NODE_URL}/v1 (max ${max}s) ..."
  while (( SECONDS - start < max )); do
    refresh_node_url_from_node_yaml || true
    if curl -sf "${NODE_URL}/v1" >/dev/null 2>&1; then
      echo "Node REST is accepting connections."
      return 0
    fi
    sleep "$POLL_INTERVAL_SECS"
  done
  echo "error: ${NODE_URL}/v1 never responded (connection refused or timeout)." >&2
  echo "      The ready server can lie if port 8070 was reused; ensure no stale localnet is bound." >&2
  return 1
}

shutdown_localnet_bg() {
  [[ "$STARTED_LOCALNET_BG" == "1" ]] || return 0
  if [[ ! -f "$LOCALNET_PID_FILE" ]]; then
    STARTED_LOCALNET_BG=0
    return 0
  fi
  local pid
  pid=$(cat "$LOCALNET_PID_FILE" 2>/dev/null || true)
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "Shutting down localnet (pid $pid, SIGTERM) ..."
    kill -TERM "$pid" 2>/dev/null || true
    local i=0
    while kill -0 "$pid" 2>/dev/null && (( i < 120 )); do
      sleep 0.5
      i=$((i + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo "Localnet did not exit; sending SIGKILL to pid $pid" >&2
      kill -KILL "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$LOCALNET_PID_FILE"
  STARTED_LOCALNET_BG=0
}

cleanup_on_exit() {
  local ec=$?
  trap - EXIT INT TERM
  # Always tear down on failure; on success, tear down only if KEEP_LOCALNET=0.
  if [[ "$STARTED_LOCALNET_BG" == "1" ]]; then
    if [[ "$ec" != "0" ]] || [[ "$KEEP_LOCALNET" == "0" ]]; then
      shutdown_localnet_bg
    fi
  fi
  exit "$ec"
}

trap cleanup_on_exit EXIT INT TERM

wait_for_localnet_ready() {
  local pid=$1
  local start=$SECONDS
  local deadline=$((SECONDS + NODE_WAIT_TIMEOUT_SECS))
  local next_hint=$((SECONDS + 15))
  echo "Waiting for $(wait_target_description) (max ${NODE_WAIT_TIMEOUT_SECS}s; WAIT_STRATEGY=$WAIT_STRATEGY)."
  echo "REST for move run-script: $NODE_URL (refreshed from $TEST_DIR/0/node.yaml when present)."
  while (( SECONDS < deadline )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "error: movement process (pid $pid) exited before localnet became ready." >&2
      dump_failure_hints
      exit 1
    fi

    if localnet_responds; then
      refresh_node_url_from_node_yaml || true
      echo "Ready after $((SECONDS - start))s. Using NODE_URL=$NODE_URL for move run-script."
      return 0
    fi
    if (( SECONDS >= next_hint )); then
      echo "  ... still waiting ($((SECONDS - start))s / ${NODE_WAIT_TIMEOUT_SECS}s). Tip: tail -f \"$LOCALNET_LOG\""
      next_hint=$((SECONDS + 15))
    fi
    sleep "$POLL_INTERVAL_SECS"
  done
  echo "error: timed out waiting for $(wait_target_description)." >&2
  dump_failure_hints
  exit 1
}

# Creates $REPO_ROOT/.movement/config.yaml when missing so the auditor bootstrap can sign. movement
# init contacts NODE_URL; only call after localnet REST is accepting connections.
ensure_movement_cli_config_for_signing() {
  if [[ "$SKIP_AUDITOR_BOOTSTRAP" == "1" ]]; then
    return 0
  fi
  if [[ "$SKIP_MOVEMENT_CONFIG_INIT" == "1" ]]; then
    return 0
  fi
  local cfg="$REPO_ROOT/.movement/config.yaml"
  if [[ -f "$cfg" ]]; then
    if (cd "$REPO_ROOT" && "$MOVEMENT" config show-profiles 2>/dev/null) | python3 -c "import json,sys
raw=sys.stdin.read().strip()
if not raw:
    sys.exit(1)
d=json.loads(raw)
if not isinstance(d, dict) or d.get('Error'):
    sys.exit(1)
if 'Result' not in d or sys.argv[1] not in d['Result']:
    sys.exit(1)
sys.exit(0)" "$MOVEMENT_PROFILE" 2>/dev/null
    then
      echo "Using existing Movement CLI config at $cfg (profile: $MOVEMENT_PROFILE)."
      return 0
    fi
    echo "error: $cfg exists but 'movement config show-profiles' does not expose profile \"$MOVEMENT_PROFILE\"." >&2
    echo "      Fix the file, remove it to allow auto-init, or set SKIP_MOVEMENT_CONFIG_INIT=1 and create a profile manually." >&2
    exit 1
  fi

  echo "No Movement CLI config at $cfg; creating profile \"$MOVEMENT_PROFILE\" for this localnet (REST=$NODE_URL) ..."
  mkdir -p "$REPO_ROOT/.movement"
  local tmpk
  tmpk=$(mktemp "$REPO_ROOT/.movement/.local-publish-key.XXXXXX")
  rm -f "${tmpk}.pub"
  if ! "$MOVEMENT" key generate --output-file "$tmpk" --encoding hex --assume-yes >/dev/null; then
    rm -f "$tmpk" "${tmpk}.pub"
    echo "error: movement key generate failed" >&2
    exit 1
  fi
  if ! (cd "$REPO_ROOT" && "$MOVEMENT" init --assume-yes --network custom \
    --rest-url "$NODE_URL" \
    --faucet-url "$FAUCET_URL" \
    --skip-faucet \
    --private-key-file "$tmpk" --encoding hex \
    --profile "$MOVEMENT_PROFILE"); then
    rm -f "$tmpk" "${tmpk}.pub"
    echo "error: movement init failed (see messages above)" >&2
    exit 1
  fi
  rm -f "$tmpk" "${tmpk}.pub"
  echo "Wrote $cfg — auditor-bootstrap signer is profile \"$MOVEMENT_PROFILE\"."
}

# Address move run-script uses if you only pass --private-key-file (auth key preimage of pubkey).
mint_key_derived_address() {
  local tmp pubfile addr
  tmp=$(mktemp)
  rm -f "${tmp}.pub"
  if ! "$MOVEMENT" key extract-public-key \
    --private-key-file "$TEST_DIR/mint.key" \
    --encoding bcs \
    --output-file "$tmp" \
    --assume-yes >/dev/null 2>&1; then
    echo "error: could not extract public key from $TEST_DIR/mint.key" >&2
    rm -f "$tmp" "${tmp}.pub"
    return 1
  fi
  pubfile="${tmp}.pub"
  if [[ ! -f "$pubfile" ]]; then
    echo "error: missing $pubfile after extract-public-key" >&2
    rm -f "$tmp"
    return 1
  fi
  addr=$(python3 -c '
import hashlib, sys
path = sys.argv[1]
data = open(path, "rb").read()
if len(data) < 32:
    sys.exit("public key file too short: %d bytes" % len(data))
pk = data[-32:]
print("0x" + hashlib.sha3_256(pk + bytes([0])).hexdigest())
' "$pubfile")
  rm -f "$tmp" "$pubfile"
  printf "%s" "$addr"
}

# Account address for MOVEMENT_PROFILE from $REPO_ROOT/.movement/config.yaml (via CLI).
profile_account_hex() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "error: python3 is required to read movement profile account" >&2
    return 1
  fi
  local _cfg="$REPO_ROOT/.movement/config.yaml"
  # show-profiles must run from REPO_ROOT so ConfigSearchMode::CurrentDir finds .movement/config.yaml.
  # Output is JSON: {\"Result\":{...}} on success, or {\"Error\":\"...\"} on failure. Some Movement builds
  # may differ; we fall back to parsing config.yaml if JSON has no Result.
  (cd "$REPO_ROOT" && "$MOVEMENT" config show-profiles) | python3 -c "
import json, re, sys

def account_from_config_yaml(text, profile):
    lines = text.splitlines()
    in_profiles = False
    in_profile = False
    indent_profile = '  ' + profile + ':'
    for line in lines:
        if line.rstrip() == 'profiles:':
            in_profiles = True
            continue
        if not in_profiles:
            continue
        if line.startswith(indent_profile):
            in_profile = True
            continue
        if in_profile:
            if re.match(r'^  [^ ].*', line) and not line.startswith('    '):
                break
            m = re.match(r'^\\s+account:\\s*(0x[0-9a-fA-F]+)\\s*\$', line)
            if m:
                return m.group(1)
    return None

profile = sys.argv[1]
cfg_path = sys.argv[2]
raw = sys.stdin.read().strip()
if not raw:
    print('empty output from movement config show-profiles (run from repo root; is .movement/config.yaml present?)', file=sys.stderr)
    sys.exit(1)
try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    print('movement config show-profiles did not return JSON:', e, file=sys.stderr)
    print(raw[:1200], file=sys.stderr)
    sys.exit(1)
if isinstance(data, dict) and 'Error' in data:
    print('movement config show-profiles:', data['Error'], file=sys.stderr)
    sys.exit(1)
acc = None
if isinstance(data, dict) and 'Result' in data and profile in data['Result']:
    acc = data['Result'][profile].get('account')
if acc is None and cfg_path:
    try:
        text = open(cfg_path, encoding='utf-8').read()
    except OSError as e:
        print(f'could not read {cfg_path}: {e}', file=sys.stderr)
        sys.exit(1)
    acc = account_from_config_yaml(text, profile)
if acc is None or acc == '':
    print('Could not resolve profile account for profile=%r (no Result.%s.account in CLI JSON and no account: in %s).' % (profile, profile, cfg_path or 'config'), file=sys.stderr)
    print('CLI JSON keys: %s' % (list(data.keys()) if isinstance(data, dict) else type(data),), file=sys.stderr)
    sys.exit(1)
acc = str(acc)
sys.stdout.write(acc if acc.startswith('0x') else '0x' + acc)
" "$MOVEMENT_PROFILE" "$_cfg"
}

# Faucet serves GET / → plain text "tap:ok" when the funder is healthy (see aptos-faucet BasicApi).
wait_for_faucet_healthy() {
  local base start max next_hint body
  base="${FAUCET_URL%/}"
  start=$SECONDS
  max=$FAUCET_WAIT_TIMEOUT_SECS
  next_hint=$((SECONDS + 15))
  echo "Waiting until faucet is ready (polling ${base}/ until response is tap:ok; abort after ${max}s if not) ..."
  while (( SECONDS - start < max )); do
    body=$(curl -sf --max-time "$FAUCET_HTTP_MAX_TIME" "${base}/" 2>/dev/null || true)
    if [[ "$body" == "tap:ok" ]]; then
      echo "Faucet is ready."
      return 0
    fi
    if (( SECONDS >= next_hint )); then
      echo "  ... faucet not ready yet ($((SECONDS - start))s / ${max}s). Tip: tail -f \"$LOCALNET_LOG\""
      next_hint=$((SECONDS + 15))
    fi
    sleep "$POLL_INTERVAL_SECS"
  done
  echo "error: faucet ${base}/ never returned tap:ok (last body: ${body:-<empty or curl failed>})." >&2
  echo "      The node can be up before the tap; raise FAUCET_WAIT_TIMEOUT_SECS or check the faucet port in the localnet log." >&2
  exit 1
}

fund_mint_related_accounts() {
  if [[ "$SKIP_FAUCET" == "1" ]]; then
    echo "SKIP_FAUCET=1: skipping faucet fund step."
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "error: python3 is required for the second faucet target (pubkey-derived address)." >&2
    exit 1
  fi
  wait_for_faucet_healthy
  echo "Funding core-resources account $CORE_RESOURCES_ADDRESS via faucet ($FAUCET_URL) ..."
  "$MOVEMENT" account fund-with-faucet \
    --url "$NODE_URL" \
    --faucet-url "$FAUCET_URL" \
    --connection-timeout-secs "$FAUCET_FUND_CONN_TIMEOUT_SECS" \
    --account "$CORE_RESOURCES_ADDRESS" \
    --amount "$FAUCET_AMOUNT"
  local derived
  derived=$(mint_key_derived_address) || exit 1
  echo "Funding pubkey-derived account $derived via faucet ($FAUCET_URL) ..."
  "$MOVEMENT" account fund-with-faucet \
    --url "$NODE_URL" \
    --faucet-url "$FAUCET_URL" \
    --connection-timeout-secs "$FAUCET_FUND_CONN_TIMEOUT_SECS" \
    --account "$derived" \
    --amount "$FAUCET_AMOUNT"
  if [[ "$SKIP_AUDITOR_BOOTSTRAP" != "1" ]]; then
    local prof_acct
    prof_acct=$(profile_account_hex) || exit 1
    echo "Funding auditor-bootstrap signer ($MOVEMENT_PROFILE profile) $prof_acct via faucet ($FAUCET_URL) ..."
    "$MOVEMENT" account fund-with-faucet \
      --url "$NODE_URL" \
      --faucet-url "$FAUCET_URL" \
      --connection-timeout-secs "$FAUCET_FUND_CONN_TIMEOUT_SECS" \
      --account "$prof_acct" \
      --amount "$FAUCET_AMOUNT"
  fi
}

wait_for_mint_key() {
  local deadline=$((SECONDS + MINT_KEY_WAIT_SECS))
  echo "Waiting for $TEST_DIR/mint.key ..."
  while (( SECONDS < deadline )); do
    if [[ -f "$TEST_DIR/mint.key" ]]; then
      echo "Found mint.key."
      return 0
    fi
    sleep "$POLL_INTERVAL_SECS"
  done
  echo "error: timed out waiting for mint.key under $TEST_DIR" >&2
  exit 1
}

run_localnet() {
  mkdir -p "$REPO_ROOT/.movement"
  cd "$REPO_ROOT"
  if [[ "$BACKGROUND" == "1" ]]; then
    echo "Starting localnet in background (logs: $LOCALNET_LOG) ..."
    nohup "$MOVEMENT" node run-localnet \
      --force-restart \
      --assume-yes \
      --do-not-delegate \
      --with-indexer-api \
      --test-dir "$TEST_DIR" \
      >"$LOCALNET_LOG" 2>&1 &
    echo $! >"$LOCALNET_PID_FILE"
    STARTED_LOCALNET_BG=1
    local pid
    pid=$(cat "$LOCALNET_PID_FILE")
    echo "PID $pid (stops on failure, or on success if KEEP_LOCALNET=0; default keeps localnet after success)"
    wait_for_mint_key
    wait_for_localnet_ready "$pid"
    ensure_node_rest_responds
  else
    echo "Starting localnet in foreground; run feature script in another shell with SKIP_START=1."
    exec "$MOVEMENT" node run-localnet \
      --force-restart \
      --assume-yes \
      --do-not-delegate \
      --with-indexer-api \
      --test-dir "$TEST_DIR"
  fi
}

if [[ "$SKIP_START" != "1" ]]; then
  run_localnet
else
  echo "SKIP_START=1: waiting for $(wait_target_description) ..."
  start=$SECONDS
  deadline=$((SECONDS + NODE_WAIT_TIMEOUT_SECS))
  next_hint=$((SECONDS + 15))
  while (( SECONDS < deadline )); do
    if localnet_responds; then
      refresh_node_url_from_node_yaml || true
      echo "Ready after $((SECONDS - start))s. NODE_URL=$NODE_URL"
      break
    fi
    if [[ -f "$LOCALNET_PID_FILE" ]]; then
      pid=$(cat "$LOCALNET_PID_FILE")
      if ! kill -0 "$pid" 2>/dev/null; then
        echo "error: movement (pid $pid from $LOCALNET_PID_FILE) is not running." >&2
        dump_failure_hints
        exit 1
      fi
    fi
    if (( SECONDS >= next_hint )); then
      echo "  ... still waiting ($((SECONDS - start))s / ${NODE_WAIT_TIMEOUT_SECS}s)"
      next_hint=$((SECONDS + 15))
    fi
    sleep "$POLL_INTERVAL_SECS"
  done
  if ! localnet_responds; then
    echo "error: timed out waiting for $(wait_target_description)" >&2
    dump_failure_hints
    exit 1
  fi
  ensure_node_rest_responds
  if [[ ! -f "$TEST_DIR/mint.key" ]]; then
    echo "error: SKIP_START=1 but $TEST_DIR/mint.key missing" >&2
    exit 1
  fi
fi

cd "$REPO_ROOT"

ensure_movement_cli_config_for_signing

fund_mint_related_accounts

echo "Enabling feature flag 87 (BULLETPROOFS_BATCH_NATIVES) ..."
# Generated inline (the governance proposal repo holds the canonical copy of this script).
FEATURE_SCRIPT_DIR="$(mktemp -d)"
FEATURE_SCRIPT="$FEATURE_SCRIPT_DIR/enable-confidential-assets-feature-87.move"
cat > "$FEATURE_SCRIPT" <<'EOF'
// Enables on-chain feature flag 87 (BULLETPROOFS_BATCH_NATIVES) and reconfigures.
// Sender must be the core resources account (localnet: key in <test-dir>/mint.key).
script {
    use aptos_framework::aptos_governance;
    use std::features;

    fun main(core_resources: &signer) {
        let core_signer = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        let framework_signer = &core_signer;

        let enabled_blob: vector<u64> = vector[87];
        let disabled_blob: vector<u64> = vector[];

        features::change_feature_flags_for_next_epoch(framework_signer, enabled_blob, disabled_blob);
        aptos_governance::reconfigure(framework_signer);
    }
}
EOF
"$MOVEMENT" move run-script \
  --assume-yes \
  --url "$NODE_URL" \
  --private-key-file "$TEST_DIR/mint.key" \
  --encoding bcs \
  --sender-account "$CORE_RESOURCES_ADDRESS" \
  --max-gas "$MOVE_RUN_SCRIPT_MAX_GAS" \
  --framework-local-dir "$FRAMEWORK_DIR" \
  --script-path "$FEATURE_SCRIPT"
rm -rf "$FEATURE_SCRIPT_DIR"

# Bootstrap the chain-auditor: governance (mint.key) designates the CLI-profile
# account as `chain_auditor_admin`, then that admin sets a known TwistedElGamal
# pubkey as the chain auditor. Without this, every `confidential_transfer` aborts
# with ECHAIN_AUDITOR_NOT_SET because the GlobalConfig.chain_auditor_ek starts as
# None.
#
# CHAIN_AUDITOR_EK is a fixed test-only key. Re-running the script bumps the
# on-chain `chain_auditor_epoch` (harmless for tests; localnet state is wiped on
# fresh starts). Private key for this pubkey (only needed if a test ever wants
# to actually decrypt as the chain auditor):
#   priv: 0xb17fdd9dd18e25a3c5f7b2004142b76c3998eab4f91372ea543830ece670b5cb
CHAIN_AUDITOR_BOOTSTRAP_DIR="$SCRIPT_DIR/chain-auditor-bootstrap"
CHAIN_AUDITOR_EK="${CHAIN_AUDITOR_EK:-0x5e7cbfdf6b100216d7541b0439704748225a90005cd4908a1ee3c90d1ab1ea00}"

if [[ "${SKIP_AUDITOR_BOOTSTRAP:-0}" != "1" ]]; then
  if [[ ! -d "$CHAIN_AUDITOR_BOOTSTRAP_DIR" ]]; then
    echo "error: missing $CHAIN_AUDITOR_BOOTSTRAP_DIR" >&2
    exit 1
  fi
  admin_addr=$(profile_account_hex) || exit 1

  # `move run-script` does not accept --named-addresses, so compile the bootstrap
  # script package separately and feed the resulting bytecode in via
  # --compiled-script-path.
  echo "Compiling chain-auditor bootstrap script ..."
  "$MOVEMENT" move compile-script \
    --package-dir "$CHAIN_AUDITOR_BOOTSTRAP_DIR" \
    --output-file "$CHAIN_AUDITOR_BOOTSTRAP_DIR/build/set_chain_auditor_admin.mv"

  echo "Designating $admin_addr (profile \"$MOVEMENT_PROFILE\") as chain_auditor_admin ..."
  "$MOVEMENT" move run-script \
    --assume-yes \
    --url "$NODE_URL" \
    --private-key-file "$TEST_DIR/mint.key" \
    --encoding bcs \
    --sender-account "$CORE_RESOURCES_ADDRESS" \
    --max-gas "$MOVE_RUN_SCRIPT_MAX_GAS" \
    --compiled-script-path "$CHAIN_AUDITOR_BOOTSTRAP_DIR/build/set_chain_auditor_admin.mv" \
    --args "address:$admin_addr"

  echo "Setting chain auditor encryption key to $CHAIN_AUDITOR_EK ..."
  "$MOVEMENT" move run \
    --assume-yes \
    --url "$NODE_URL" \
    --profile "$MOVEMENT_PROFILE" \
    --max-gas "$MOVE_RUN_SCRIPT_MAX_GAS" \
    --function-id "0x1::confidential_asset::set_chain_auditor" \
    --args "hex:$CHAIN_AUDITOR_EK"
fi

# Set the asset-specific auditor key for the MOVE fungible asset (metadata object @0xa).
# `set_asset_auditor` must be signed by `object::root_owner(token)`, which for the MOVE/APT
# FA at 0xa is @aptos_framework (0x1). So this runs as a governance script: mint.key gets the
# @0x1 signer via `get_signer_testnet_only`, then calls 0x1::confidential_asset::set_asset_auditor.
# Pass an empty ASSET_AUDITOR_EK to skip (the entry function would clear the key on empty input,
# so we just don't run the step). Re-running bumps the on-chain asset_auditor_epoch.
ASSET_AUDITOR_EK="${ASSET_AUDITOR_EK:-0x5e7cbfdf6b100216d7541b0439704748225a90005cd4908a1ee3c90d1ab1ea00}"
SKIP_ASSET_AUDITOR="${SKIP_ASSET_AUDITOR:-0}"

if [[ "$SKIP_ASSET_AUDITOR" != "1" ]]; then
  echo "Setting MOVE (FA @0xa) asset auditor encryption key to $ASSET_AUDITOR_EK ..."
  ASSET_AUDITOR_SCRIPT_DIR="$(mktemp -d)"
  ASSET_AUDITOR_SCRIPT="$ASSET_AUDITOR_SCRIPT_DIR/set-move-asset-auditor.move"
  cat > "$ASSET_AUDITOR_SCRIPT" <<'EOF'
// Sets the asset-specific auditor key for the MOVE fungible asset (metadata object @0xa).
// Sender must be the core resources account (localnet: key in <test-dir>/mint.key); the script
// obtains the @0x1 framework signer (root owner of the MOVE FA) via governance.
script {
    use aptos_framework::aptos_governance;
    use aptos_framework::confidential_asset;
    use aptos_framework::object;
    use aptos_framework::fungible_asset::Metadata;

    fun main(core_resources: &signer, auditor_ek: vector<u8>) {
        let core_signer = aptos_governance::get_signer_testnet_only(core_resources, @0x1);
        let framework_signer = &core_signer;

        let move_metadata = object::address_to_object<Metadata>(
            @0x000000000000000000000000000000000000000000000000000000000000000a
        );

        confidential_asset::set_asset_auditor(framework_signer, move_metadata, auditor_ek);
    }
}
EOF
  "$MOVEMENT" move run-script \
    --assume-yes \
    --url "$NODE_URL" \
    --private-key-file "$TEST_DIR/mint.key" \
    --encoding bcs \
    --sender-account "$CORE_RESOURCES_ADDRESS" \
    --max-gas "$MOVE_RUN_SCRIPT_MAX_GAS" \
    --framework-local-dir "$FRAMEWORK_DIR" \
    --script-path "$ASSET_AUDITOR_SCRIPT" \
    --args "hex:$ASSET_AUDITOR_EK"
  rm -rf "$ASSET_AUDITOR_SCRIPT_DIR"
fi

echo "Done — feature flag and (if enabled) auditor bootstrap finished."
echo "REST: $NODE_URL/v1  (ready probe: $READY_URL — set WAIT_STRATEGY=node to wait only on REST)"

# Hold this shell so localnet is not an invisible background process (default). Ctrl+C stops localnet.
if [[ "$STARTED_LOCALNET_BG" == "1" ]] && [[ "$KEEP_LOCALNET" == "1" ]] && [[ "${LOCALNET_ATTACH:-1}" == "1" ]]; then
  if [[ -f "$LOCALNET_PID_FILE" ]]; then
    pid=$(cat "$LOCALNET_PID_FILE" 2>/dev/null || true)
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      echo ""
      echo "━━━━━━━━ Localnet is running — this terminal stays attached ━━━━━━━━"
      echo "  REST API:     ${NODE_URL}/v1"
      echo "  Ready check:  $READY_URL"
      echo "  Process pid:  $pid   (also in $LOCALNET_PID_FILE)"
      echo "  Live logs:    tail -f \"$LOCALNET_LOG\""
      echo "  Stop:         Ctrl+C here, or in another shell: kill $pid"
      echo "  Detach next time (return to prompt while localnet runs): LOCALNET_ATTACH=0"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      # Ctrl+C yields non-zero exit; EXIT trap runs shutdown_localnet_bg.
      wait "$pid" || true
      shutdown_localnet_bg
    fi
  fi
elif [[ "$STARTED_LOCALNET_BG" == "1" ]] && [[ "$KEEP_LOCALNET" == "1" ]] && [[ "${LOCALNET_ATTACH:-1}" != "1" ]]; then
  if [[ -f "$LOCALNET_PID_FILE" ]]; then
    pid=$(cat "$LOCALNET_PID_FILE" 2>/dev/null || true)
    echo "Localnet left running in the background (pid ${pid:-?}). Stop from repo root: kill \"\$(cat .movement/localnet.pid)\""
  fi
fi

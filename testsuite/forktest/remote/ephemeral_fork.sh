#!/usr/bin/env bash

# Copyright © Aptos Foundation
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

PROGRAM=$(basename "$0")
DEFAULT_CHAIN_ID=42
DEFAULT_VALIDATORS=2
DEFAULT_HEALTH_TIMEOUT=120
STATE_DIR_NAME=".ephemeral-fork"

usage() {
  cat <<EOF
Create and manage an isolated network forked from a post-genesis state checkpoint.

Usage:
  $PROGRAM start --source-db PATH --source-is-disposable \\
    --fork-tool PATH --node-binary PATH --test-account-address ADDRESS [OPTIONS]
  $PROGRAM status --work-dir PATH
  $PROGRAM stop --work-dir PATH

Start options:
  --source-db PATH                 Writable, disposable source DB checkpoint.
  --source-is-disposable          Required acknowledgement that source recovery is safe.
  --fork-tool PATH                aptos-debugger binary containing 'aptos-db fork'.
  --node-binary PATH               Candidate aptos-node binary to test.
  --test-account-address ADDRESS  Existing funded account to re-key in the fork.
  --test-account-private-key KEY  Override the fork tool's default key (0xabc).
  --work-dir PATH                 Output directory. Defaults to a new temporary directory.
  --validators COUNT              Replacement validator count. Default: $DEFAULT_VALIDATORS.
  --chain-id ID                   Non-production fork chain ID. Default: $DEFAULT_CHAIN_ID.
  --health-timeout SECONDS        Startup and ledger-progress timeout. Default: $DEFAULT_HEALTH_TIMEOUT.

The start command returns after all validators are healthy and the ledger has
advanced beyond the fork waypoint. Validators bind only to addresses generated
by the fork tool; this wrapper rejects non-loopback REST addresses.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

resolve_binary() {
  local binary=$1
  local resolved
  if [[ "$binary" == */* ]]; then
    [[ -x "$binary" ]] || die "binary is not executable: $binary"
    resolved=$(cd "$(dirname "$binary")" && pwd -P)/$(basename "$binary")
  else
    resolved=$(command -v "$binary") || die "binary not found: $binary"
  fi
  printf '%s\n' "$resolved"
}

validate_positive_integer() {
  local name=$1
  local value=$2
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "$name must be a positive integer"
}

validate_chain_id() {
  local chain_id=$1
  validate_positive_integer "--chain-id" "$chain_id"
  ((chain_id <= 255 && chain_id != 126)) ||
    die "--chain-id must be between 1 and 255 and must not be Movement mainnet (126)"
}

validate_account_address() {
  local address=$1
  [[ "$address" =~ ^0x[0-9a-fA-F]{1,64}$ ]] ||
    die "--test-account-address must be a 0x-prefixed account address"
}

state_path() {
  local work_dir=$1
  local name=$2
  printf '%s/%s/%s\n' "$work_dir" "$STATE_DIR_NAME" "$name"
}

read_state() {
  local work_dir=$1
  local name=$2
  local path
  path=$(state_path "$work_dir" "$name")
  [[ -f "$path" ]] || die "missing fork state file: $path"
  cat "$path"
}

api_address_from_config() {
  local config=$1
  awk '
    /^api:$/ { in_api = 1; next }
    in_api && /^[^ ]/ { in_api = 0 }
    in_api && $1 == "address:" {
      value = $2
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "$config"
}

ensure_loopback_address() {
  local address=$1
  case "$address" in
    127.0.0.1:* | localhost:* | "[::1]:"*) ;;
    *) die "generated REST address is not loopback-only: $address" ;;
  esac
}

normalize_candidate_config() {
  local config=$1
  local normalized="$config.normalized"

  awk '
    function incompatible(section, key) {
      return \
        (section == "api" && key == "simulation_filter") || \
        (section == "consensus" && (key == "channel_size" || key == "enable_pipeline")) || \
        (section == "consensus_observer" && key == "enable_pipeline") || \
        (section == "execution" && key == "transaction_filter")
    }

    skip {
      if (/^    / || /^[[:space:]]*$/) {
        next
      }
      skip = 0
    }
    /^[^ ]/ {
      section = $1
      sub(/:$/, "", section)
    }
    /^  [^ ]/ {
      key = $1
      sub(/:$/, "", key)
      if (incompatible(section, key)) {
        skip = 1
        next
      }
    }
    { print }
  ' "$config" >"$normalized"
  mv "$normalized" "$config"
}

ledger_summary() {
  python3 -c '
import json
import sys

data = json.load(sys.stdin)
print(
    "chain_id={chain_id} epoch={epoch} ledger_version={ledger_version}".format(
        chain_id=data["chain_id"],
        epoch=data["epoch"],
        ledger_version=data["ledger_version"],
    )
)
'
}

ledger_version() {
  python3 -c 'import json, sys; print(json.load(sys.stdin)["ledger_version"])'
}

manifest_output_version() {
  local manifest=$1
  python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as manifest:
    print(json.load(manifest)["output_ledger"]["version"])
' "$manifest"
}

stop_nodes() {
  local config_dir=$1
  local quiet=${2:-false}
  local config pid_file pid command attempt

  for config in "$config_dir"/*/node.yaml; do
    [[ -f "$config" ]] || continue
    pid_file="$(dirname "$config")/node.pid"
    [[ -f "$pid_file" ]] || continue
    pid=$(cat "$pid_file")
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || die "invalid PID in $pid_file"

    if ! kill -0 "$pid" 2>/dev/null; then
      [[ "$quiet" == true ]] || echo "Validator PID $pid is already stopped."
      continue
    fi

    command=$(ps -p "$pid" -o command=)
    case "$command" in
      *"$config"*) ;;
      *) die "refusing to stop PID $pid because it is not using $config" ;;
    esac

    kill "$pid"
    for ((attempt = 0; attempt < 50; attempt++)); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then
      die "validator PID $pid did not stop after SIGTERM"
    fi
    [[ "$quiet" == true ]] || echo "Stopped validator PID $pid."
  done
}

wait_for_network() {
  local config_dir=$1
  local rest_urls_file=$2
  local fork_version=$3
  local timeout=$4
  local deadline=$((SECONDS + timeout))
  local index pid response version all_ready

  while ((SECONDS < deadline)); do
    all_ready=true
    index=0
    while IFS= read -r url; do
      pid=$(cat "$config_dir/$index/node.pid")
      if ! kill -0 "$pid" 2>/dev/null; then
        echo "Validator $index exited during startup:" >&2
        tail -n 80 "$config_dir/$index/node.log" >&2 || true
        return 1
      fi
      response=$(curl --fail --silent --max-time 2 "$url/v1/" 2>/dev/null || true)
      if [[ -z "$response" ]]; then
        all_ready=false
      else
        version=$(printf '%s' "$response" | ledger_version)
        if ((version <= fork_version)); then
          all_ready=false
        fi
      fi
      index=$((index + 1))
    done <"$rest_urls_file"

    if [[ "$all_ready" == true ]]; then
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for all validators to advance beyond version $fork_version." >&2
  return 1
}

print_handoff() {
  local work_dir=$1
  local config_dir=$2
  local rest_url=$3
  local test_account=$4
  local key_file="$config_dir/test-account-private-key"
  local manifest="$config_dir/fork-manifest.json"

  echo
  echo "Ephemeral fork is healthy."
  echo "  Work directory:      $work_dir"
  echo "  REST URL:            $rest_url"
  echo "  Test account:        $test_account"
  echo "  Private key file:    $key_file"
  echo "  Fork manifest:       $manifest"
  echo
  echo "The private key is public test material and must never be used on production."
  echo
  echo "Contract publishing pattern:"
  echo "  movement move publish --package-dir <MOVE_PACKAGE> \\"
  echo "    --sender-account $test_account \\"
  echo "    --private-key-file $key_file --url $rest_url --assume-yes"
  echo
  echo "Status: $PROGRAM status --work-dir $work_dir"
  echo "Stop:   $PROGRAM stop --work-dir $work_dir"
}

start_fork() {
  local source_db=""
  local source_is_disposable=false
  local fork_tool=""
  local node_binary=""
  local test_account=""
  local test_private_key=""
  local work_dir=""
  local validators=$DEFAULT_VALIDATORS
  local chain_id=$DEFAULT_CHAIN_ID
  local health_timeout=$DEFAULT_HEALTH_TIMEOUT

  while (($#)); do
    case "$1" in
      --source-db)
        [[ $# -ge 2 ]] || die "--source-db requires a value"
        source_db=$2
        shift 2
        ;;
      --source-is-disposable)
        source_is_disposable=true
        shift
        ;;
      --fork-tool)
        [[ $# -ge 2 ]] || die "--fork-tool requires a value"
        fork_tool=$2
        shift 2
        ;;
      --node-binary)
        [[ $# -ge 2 ]] || die "--node-binary requires a value"
        node_binary=$2
        shift 2
        ;;
      --test-account-address)
        [[ $# -ge 2 ]] || die "--test-account-address requires a value"
        test_account=$2
        shift 2
        ;;
      --test-account-private-key)
        [[ $# -ge 2 ]] || die "--test-account-private-key requires a value"
        test_private_key=$2
        shift 2
        ;;
      --work-dir)
        [[ $# -ge 2 ]] || die "--work-dir requires a value"
        work_dir=$2
        shift 2
        ;;
      --validators)
        [[ $# -ge 2 ]] || die "--validators requires a value"
        validators=$2
        shift 2
        ;;
      --chain-id)
        [[ $# -ge 2 ]] || die "--chain-id requires a value"
        chain_id=$2
        shift 2
        ;;
      --health-timeout)
        [[ $# -ge 2 ]] || die "--health-timeout requires a value"
        health_timeout=$2
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown start option: $1"
        ;;
    esac
  done

  [[ -n "$source_db" ]] || die "--source-db is required"
  [[ "$source_is_disposable" == true ]] ||
    die "--source-is-disposable is required; the source DB may be recovered or mutated"
  [[ -d "$source_db" ]] || die "source DB directory does not exist: $source_db"
  [[ -w "$source_db" ]] || die "source DB must be writable and disposable: $source_db"
  [[ -n "$fork_tool" ]] || die "--fork-tool is required"
  [[ -n "$node_binary" ]] || die "--node-binary is required"
  [[ -n "$test_account" ]] || die "--test-account-address is required for contract testing"

  require_command curl
  require_command nohup
  require_command ps
  require_command python3
  validate_positive_integer "--validators" "$validators"
  validate_positive_integer "--health-timeout" "$health_timeout"
  validate_chain_id "$chain_id"
  validate_account_address "$test_account"
  fork_tool=$(resolve_binary "$fork_tool")
  node_binary=$(resolve_binary "$node_binary")
  source_db=$(cd "$source_db" && pwd -P)

  if [[ -z "$work_dir" ]]; then
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/aptos-ephemeral-fork.XXXXXX")
  else
    mkdir -p "$work_dir"
    [[ -z "$(ls -A "$work_dir")" ]] || die "work directory must be empty: $work_dir"
    work_dir=$(cd "$work_dir" && pwd -P)
  fi

  local output_db="$work_dir/fork-db"
  local config_dir="$work_dir/configs"
  local state_dir="$work_dir/$STATE_DIR_NAME"
  local manifest="$config_dir/fork-manifest.json"
  local rest_urls_file="$state_dir/rest-urls"
  local fork_command=(
    "$fork_tool" aptos-db fork
    --source-db-dir "$source_db"
    --output-db-dir "$output_db"
    --config-dir "$config_dir"
    --fork-chain-id "$chain_id"
    --validators "$validators"
    --test-account-address "$test_account"
  )
  if [[ -n "$test_private_key" ]]; then
    fork_command+=(--test-account-private-key "$test_private_key")
  fi

  echo "Creating fork in $work_dir..."
  "${fork_command[@]}"
  [[ -f "$manifest" ]] || die "fork tool did not create manifest: $manifest"
  [[ -f "$config_dir/test-account-private-key" ]] ||
    die "fork tool did not create the test account key"

  mkdir -p "$state_dir"
  printf '%s\n' "$config_dir" >"$state_dir/config-dir"
  printf '%s\n' "$node_binary" >"$state_dir/node-binary"
  printf '%s\n' "$chain_id" >"$state_dir/chain-id"
  printf '%s\n' "$test_account" >"$state_dir/test-account"
  : >"$rest_urls_file"

  local start_complete=false
  trap 'if [[ "${start_complete:-false}" != true && -n "${config_dir:-}" ]]; then stop_nodes "$config_dir" true || true; fi' EXIT
  trap 'exit 130' INT TERM

  local index config api_address rest_url
  for ((index = 0; index < validators; index++)); do
    config="$config_dir/$index/node.yaml"
    [[ -f "$config" ]] || die "missing generated node config: $config"
    normalize_candidate_config "$config"
    api_address=$(api_address_from_config "$config")
    [[ -n "$api_address" ]] || die "could not read REST address from $config"
    ensure_loopback_address "$api_address"
    rest_url="http://$api_address"
    printf '%s\n' "$rest_url" >>"$rest_urls_file"

    nohup "$node_binary" -f "$config" >"$config_dir/$index/node.log" 2>&1 </dev/null &
    printf '%s\n' "$!" >"$config_dir/$index/node.pid"
  done

  local fork_version
  fork_version=$(manifest_output_version "$manifest")
  echo "Waiting for $validators validators to advance beyond fork version $fork_version..."
  wait_for_network "$config_dir" "$rest_urls_file" "$fork_version" "$health_timeout"

  start_complete=true
  trap - EXIT INT TERM
  print_handoff "$work_dir" "$config_dir" "$(head -n 1 "$rest_urls_file")" "$test_account"
}

status_fork() {
  local work_dir=""
  while (($#)); do
    case "$1" in
      --work-dir)
        [[ $# -ge 2 ]] || die "--work-dir requires a value"
        work_dir=$2
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown status option: $1"
        ;;
    esac
  done
  [[ -n "$work_dir" ]] || die "--work-dir is required"
  [[ -d "$work_dir" ]] || die "work directory does not exist: $work_dir"

  require_command curl
  require_command python3
  local config_dir rest_urls_file index=0 url pid response failed=false
  config_dir=$(read_state "$work_dir" config-dir)
  rest_urls_file=$(state_path "$work_dir" rest-urls)
  [[ -f "$rest_urls_file" ]] || die "missing REST URL state: $rest_urls_file"

  while IFS= read -r url; do
    pid=$(cat "$config_dir/$index/node.pid")
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "validator=$index pid=$pid status=stopped"
      failed=true
    else
      response=$(curl --fail --silent --max-time 2 "$url/v1/" 2>/dev/null || true)
      if [[ -z "$response" ]]; then
        echo "validator=$index pid=$pid status=unhealthy rest_url=$url"
        failed=true
      else
        printf 'validator=%s pid=%s status=healthy rest_url=%s ' "$index" "$pid" "$url"
        printf '%s' "$response" | ledger_summary
      fi
    fi
    index=$((index + 1))
  done <"$rest_urls_file"

  [[ "$failed" == false ]]
}

stop_fork() {
  local work_dir=""
  while (($#)); do
    case "$1" in
      --work-dir)
        [[ $# -ge 2 ]] || die "--work-dir requires a value"
        work_dir=$2
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown stop option: $1"
        ;;
    esac
  done
  [[ -n "$work_dir" ]] || die "--work-dir is required"
  [[ -d "$work_dir" ]] || die "work directory does not exist: $work_dir"

  local config_dir
  config_dir=$(read_state "$work_dir" config-dir)
  stop_nodes "$config_dir"
}

main() {
  local action=${1:-}
  if [[ -z "$action" ]]; then
    usage
    exit 1
  fi
  shift

  case "$action" in
    start) start_fork "$@" ;;
    status) status_fork "$@" ;;
    stop) stop_fork "$@" ;;
    -h | --help | help) usage ;;
    *) die "unknown command: $action" ;;
  esac
}

main "$@"

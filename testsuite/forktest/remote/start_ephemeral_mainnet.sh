#!/usr/bin/env bash

# Copyright © Aptos Foundation
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

PROGRAM=$(basename "$0")
RUN_ROOT=${EPHEMERAL_RUN_ROOT:-/mnt/mainnet-volume/fork-run-20260722}
SERVICE_ROOT=${EPHEMERAL_SERVICE_ROOT:-/mnt/mainnet-volume/ephemeral-mainnet}
SOURCE_DB=${EPHEMERAL_SOURCE_DB:-$RUN_ROOT/staging-db-v5}
FORK_TOOL=${EPHEMERAL_FORK_TOOL:-$RUN_ROOT/target/release/aptos-debugger}
FORK_LAUNCHER=${EPHEMERAL_FORK_LAUNCHER:-$RUN_ROOT/bin/ephemeral_fork.sh}
TCP_FORWARDER=${EPHEMERAL_TCP_FORWARDER:-$RUN_ROOT/bin/tcp_forward.py}
CARGO_HOME=${CARGO_HOME:-$RUN_ROOT/cargo}
RUSTUP_HOME=${RUSTUP_HOME:-$RUN_ROOT/rustup}
TEST_ACCOUNT=${EPHEMERAL_TEST_ACCOUNT:-0x573537299646e0dfab6ca81086edccf73f77b841f30dde6bfbd730ed428479bf}
VALIDATORS=${EPHEMERAL_VALIDATORS:-2}
CHAIN_ID=${EPHEMERAL_CHAIN_ID:-42}
HEALTH_TIMEOUT=${EPHEMERAL_HEALTH_TIMEOUT:-180}
PUBLIC_API_PORT=${EPHEMERAL_PUBLIC_API_PORT:-8080}
PUBLIC_API_ENABLED=${EPHEMERAL_PUBLIC_API_ENABLED:-true}
ALREADY_RUNNING_EXIT=3
export PATH="$CARGO_HOME/bin:$PATH"

usage() {
  cat <<EOF
Host-side launcher for an ephemeral mainnet fork.

Usage:
  $PROGRAM preflight
  $PROGRAM start FULL_GITHUB_SHA SOURCE_ARCHIVE.tar.gz
  $PROGRAM endpoint
  $PROGRAM test-key
  $PROGRAM expose-api [PUBLIC_PORT]
  $PROGRAM stop-api

This command is intended to be invoked by
testsuite/forktest/start_remote_ephemeral_mainnet.sh.
It refuses to build or start while any aptos-node process is already running.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
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

config_from_command() {
  local command=$1
  sed -n 's/.*[[:space:]]-f[[:space:]]\([^[:space:]]*\).*/\1/p' <<<"$command"
}

report_running_network() {
  local pids
  pids=$(pgrep -x aptos-node || true)
  [[ -n "$pids" ]] || return 1

  local active_sha="unknown"
  if [[ -f "$SERVICE_ROOT/active/sha" ]]; then
    active_sha=$(cat "$SERVICE_ROOT/active/sha")
  fi
  echo "An ephemeral network is already running; refusing to replace it."
  echo "  Recorded SHA: $active_sha"
  if public_api_running; then
    echo "  Public submission port: $(cat "$SERVICE_ROOT/public-api/port")"
  fi

  local pid command config api response
  while IFS= read -r pid; do
    command=$(ps -p "$pid" -o command=)
    config=$(config_from_command "$command")
    echo "  PID $pid: $command"
    if [[ -n "$config" && -f "$config" ]]; then
      api=$(api_address_from_config "$config")
      if [[ -n "$api" ]]; then
        response=$(curl --fail --silent --max-time 2 "http://$api/v1/" 2>/dev/null || true)
        if [[ -n "$response" ]]; then
          python3 -c '
import json
import sys

info = json.load(sys.stdin)
print(
    "    REST=http://{api} chain_id={chain_id} epoch={epoch} ledger_version={version}".format(
        api=sys.argv[1],
        chain_id=info["chain_id"],
        epoch=info["epoch"],
        version=info["ledger_version"],
    )
)
' "$api" <<<"$response"
        else
          echo "    REST=http://$api status=unhealthy"
        fi
      fi
    fi
  done <<<"$pids"
  return 0
}

public_api_running() {
  local pid_file="$SERVICE_ROOT/public-api/pid"
  [[ -f "$pid_file" ]] || return 1
  local pid
  pid=$(cat "$pid_file")
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

active_api_endpoint() {
  local pids pid command config api candidate=""
  pids=$(pgrep -x aptos-node || true)
  [[ -n "$pids" ]] || die "no aptos-node process is running"
  while IFS= read -r pid; do
    command=$(ps -p "$pid" -o command=)
    config=$(config_from_command "$command")
    if [[ -n "$config" && -f "$config" ]]; then
      api=$(api_address_from_config "$config")
      if [[ "$api" == 127.0.0.1:* ]]; then
        candidate=$api
      fi
    fi
  done <<<"$pids"
  [[ -n "$candidate" ]] ||
    die "running validators do not expose a loopback REST endpoint"
  printf '%s\n' "$candidate"
}

active_test_key() {
  local work_dir
  [[ -f "$SERVICE_ROOT/active/work-dir" ]] ||
    die "active network metadata does not contain a work directory"
  work_dir=$(cat "$SERVICE_ROOT/active/work-dir")
  local key_file="$work_dir/configs/test-account-private-key"
  [[ -f "$key_file" ]] || die "active network test key is missing: $key_file"
  cat "$key_file"
}

expose_public_api_locked() {
  local public_port=${1:-$PUBLIC_API_PORT}
  if ! [[ "$public_port" =~ ^[1-9][0-9]*$ ]] ||
    ((public_port > 65535)); then
    die "public API port must be between 1 and 65535"
  fi
  [[ -x "$TCP_FORWARDER" ]] || die "TCP forwarder is missing: $TCP_FORWARDER"
  require_command ss

  local target target_port
  target=$(active_api_endpoint)
  target_port=${target##*:}
  if public_api_running; then
    local existing_port existing_target
    existing_port=$(cat "$SERVICE_ROOT/public-api/port")
    existing_target=$(cat "$SERVICE_ROOT/public-api/target")
    if [[ "$existing_port" == "$public_port" && "$existing_target" == "$target" ]]; then
      echo "Public submission proxy is already running on port $public_port"
      return
    fi
    die "a managed public API proxy is already running for $existing_target on port $existing_port"
  fi

  if ss -ltnH "sport = :$public_port" | grep -q .; then
    die "TCP port $public_port is already in use"
  fi

  local proxy_dir="$SERVICE_ROOT/public-api"
  mkdir -p "$proxy_dir"
  nohup "$TCP_FORWARDER" \
    --listen-host 0.0.0.0 \
    --listen-port "$public_port" \
    --target-host 127.0.0.1 \
    --target-port "$target_port" \
    >"$proxy_dir/proxy.log" 2>&1 </dev/null 9>&- &
  local proxy_pid
  proxy_pid=$!
  printf '%s\n' "$proxy_pid" >"$proxy_dir/pid"
  printf '%s\n' "$public_port" >"$proxy_dir/port"
  printf '%s\n' "$target" >"$proxy_dir/target"

  local attempt
  for ((attempt = 0; attempt < 30; attempt++)); do
    if ! kill -0 "$proxy_pid" 2>/dev/null; then
      tail -n 80 "$proxy_dir/proxy.log" >&2 || true
      die "public API proxy exited during startup"
    fi
    if curl --fail --silent --max-time 2 "http://127.0.0.1:$public_port/v1/" >/dev/null 2>&1; then
      echo "Public submission proxy is healthy on port $public_port"
      return
    fi
    sleep 1
  done
  die "public API proxy did not become healthy"
}

expose_public_api() {
  mkdir -p "$SERVICE_ROOT"
  exec 9>"$SERVICE_ROOT/launcher.lock"
  flock 9
  expose_public_api_locked "$@"
}

stop_public_api_locked() {
  local pid_file="$SERVICE_ROOT/public-api/pid"
  if [[ ! -f "$pid_file" ]]; then
    echo "No managed public API proxy is recorded."
    return
  fi

  local pid
  pid=$(cat "$pid_file")
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || die "invalid public API proxy PID: $pid"
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Managed public API proxy PID $pid is already stopped."
    rm -f "$pid_file"
    return
  fi

  local command
  command=$(ps -p "$pid" -o command=)
  case "$command" in
    *"$TCP_FORWARDER"*) ;;
    *) die "refusing to stop PID $pid because it is not the managed TCP forwarder" ;;
  esac

  kill "$pid"
  local attempt
  for ((attempt = 0; attempt < 50; attempt++)); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill -0 "$pid" 2>/dev/null &&
    die "public API proxy PID $pid did not stop after SIGTERM"
  rm -f "$pid_file"
  echo "Stopped managed public API proxy PID $pid."
}

stop_public_api() {
  mkdir -p "$SERVICE_ROOT"
  exec 9>"$SERVICE_ROOT/launcher.lock"
  flock 9
  stop_public_api_locked
}

preflight() {
  mkdir -p "$SERVICE_ROOT"
  exec 9>"$SERVICE_ROOT/launcher.lock"
  flock 9
  if report_running_network; then
    return "$ALREADY_RUNNING_EXIT"
  fi
  echo "No aptos-node process is running; remote host is ready."
}

verify_archive() {
  local expected_sha=$1
  local archive=$2
  [[ -f "$archive" ]] || die "source archive does not exist: $archive"

  local archive_sha
  archive_sha=$(
    gzip -cd "$archive" |
      {
        git get-tar-commit-id
        cat >/dev/null
      }
  ) ||
    die "source archive does not contain a Git commit ID"
  [[ "$archive_sha" == "$expected_sha" ]] ||
    die "archive commit $archive_sha does not match requested SHA $expected_sha"
}

build_node() {
  local sha=$1
  local archive=$2
  local build_root="$SERVICE_ROOT/builds/$sha"
  local source_dir="$build_root/source"
  local target_dir="$build_root/target"
  local node_binary="$target_dir/release/aptos-node"

  if [[ -x "$node_binary" ]]; then
    echo "Reusing aptos-node already built for $sha." >&2
    printf '%s\n' "$node_binary"
    return
  fi

  if [[ -e "$source_dir" ]]; then
    mv "$source_dir" "$source_dir.incomplete.$(date +%s)"
  fi
  mkdir -p "$source_dir" "$target_dir"
  tar -xzf "$archive" -C "$source_dir"

  echo "Building aptos-node for origin commit $sha..." >&2
  (
    export CARGO_HOME RUSTUP_HOME
    export CARGO_TARGET_DIR="$target_dir"
    export CXXFLAGS="${CXXFLAGS:--include cstdint}"
    cd "$source_dir"
    cargo build --release -p aptos-node
  )
  [[ -x "$node_binary" ]] || die "build did not produce $node_binary"
  printf '%s\n' "$node_binary"
}

start_network() {
  local sha=${1:-}
  local archive=${2:-}
  local public_api_port=${3:-$PUBLIC_API_PORT}
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "start requires a full lowercase GitHub SHA"
  [[ -n "$archive" ]] || die "start requires a source archive path"

  require_command cargo
  require_command curl
  require_command flock
  require_command git
  require_command gzip
  require_command pgrep
  require_command ps
  require_command python3
  require_command tar
  [[ -d "$SOURCE_DB" ]] || die "disposable source DB is missing: $SOURCE_DB"
  [[ -w "$SOURCE_DB" ]] || die "disposable source DB is not writable: $SOURCE_DB"
  [[ -x "$FORK_TOOL" ]] || die "fork tool is missing or not executable: $FORK_TOOL"
  [[ -x "$FORK_LAUNCHER" ]] || die "fork launcher is missing or not executable: $FORK_LAUNCHER"

  mkdir -p "$SERVICE_ROOT"
  exec 9>"$SERVICE_ROOT/launcher.lock"
  flock 9
  if report_running_network; then
    return "$ALREADY_RUNNING_EXIT"
  fi

  verify_archive "$sha" "$archive"
  local node_binary
  node_binary=$(build_node "$sha" "$archive")
  local work_dir
  work_dir="$SERVICE_ROOT/runs/$sha-$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$(dirname "$work_dir")"

  "$FORK_LAUNCHER" start \
    --source-db "$SOURCE_DB" \
    --source-is-disposable \
    --fork-tool "$FORK_TOOL" \
    --node-binary "$node_binary" \
    --test-account-address "$TEST_ACCOUNT" \
    --validators "$VALIDATORS" \
    --chain-id "$CHAIN_ID" \
    --health-timeout "$HEALTH_TIMEOUT" \
    --work-dir "$work_dir" \
    9>&-

  mkdir -p "$SERVICE_ROOT/active"
  printf '%s\n' "$sha" >"$SERVICE_ROOT/active/sha"
  printf '%s\n' "$work_dir" >"$SERVICE_ROOT/active/work-dir"
  if [[ "$PUBLIC_API_ENABLED" == true ]]; then
    expose_public_api_locked "$public_api_port"
  fi
  echo "Remote ephemeral mainnet started from origin commit $sha."
}

main() {
  local action=${1:-}
  shift || true
  case "$action" in
    preflight) preflight "$@" ;;
    start) start_network "$@" ;;
    endpoint) active_api_endpoint "$@" ;;
    test-key) active_test_key "$@" ;;
    expose-api) expose_public_api "$@" ;;
    stop-api) stop_public_api "$@" ;;
    -h | --help | help) usage ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"

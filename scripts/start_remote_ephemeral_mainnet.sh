#!/usr/bin/env bash

# Copyright © Aptos Foundation
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

PROGRAM=$(basename "$0")
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
DEFAULT_HOST="ubuntu@34.231.241.232"
DEFAULT_IDENTITY="$HOME/movement/mainnet-fork.pem"
DEFAULT_REMOTE_SCRIPT="/mnt/mainnet-volume/fork-run-20260722/bin/start_ephemeral_mainnet.sh"
DEFAULT_REMOTE_INCOMING="/mnt/mainnet-volume/ephemeral-mainnet/incoming"
DEFAULT_PUBLIC_API_PORT=8080
ALREADY_RUNNING_EXIT=3
ARCHIVE_TO_CLEAN=""

usage() {
  cat <<EOF
Build and start an ephemeral mainnet fork on the configured remote host.

Usage:
  $PROGRAM GITHUB_SHA [OPTIONS]

Options:
  --host USER@HOST       SSH destination. Default: $DEFAULT_HOST
  --identity PATH        SSH private key. Default: $DEFAULT_IDENTITY
  --remote-script PATH   Installed host launcher. Default: $DEFAULT_REMOTE_SCRIPT
  --remote-incoming PATH Archive upload directory. Default: $DEFAULT_REMOTE_INCOMING
  --public-api-port PORT Public submission endpoint port. Default: $DEFAULT_PUBLIC_API_PORT

The SHA must resolve to a commit contained in origin/m1. If an aptos-node
process is already running on the host, the command reports it and exits
without uploading source, building, stopping, or replacing anything.

After a successful start, one remote loopback REST endpoint is forwarded to
http://34.231.241.232:<public-api-port>. Validator P2P and native REST listeners
remain loopback-only; only the managed submission proxy binds publicly.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

cleanup() {
  if [[ -n "$ARCHIVE_TO_CLEAN" ]]; then
    rm -f "$ARCHIVE_TO_CLEAN"
  fi
}

run_preflight() {
  local destination=$1
  local identity=$2
  local remote_script=$3
  local status

  set +e
  ssh -i "$identity" "$destination" "$remote_script" preflight
  status=$?
  set -e
  if ((status == ALREADY_RUNNING_EXIT)); then
    exit "$ALREADY_RUNNING_EXIT"
  fi
  ((status == 0)) || die "remote preflight failed with exit code $status"
}

main() {
  local requested_sha=${1:-}
  [[ -n "$requested_sha" ]] || {
    usage
    exit 1
  }
  if [[ "$requested_sha" == "-h" || "$requested_sha" == "--help" ]]; then
    usage
    exit 0
  fi
  shift

  local destination=$DEFAULT_HOST
  local identity=$DEFAULT_IDENTITY
  local remote_script=$DEFAULT_REMOTE_SCRIPT
  local remote_incoming=$DEFAULT_REMOTE_INCOMING
  local public_api_port=$DEFAULT_PUBLIC_API_PORT
  while (($#)); do
    case "$1" in
      --host)
        [[ $# -ge 2 ]] || die "--host requires a value"
        destination=$2
        shift 2
        ;;
      --identity)
        [[ $# -ge 2 ]] || die "--identity requires a value"
        identity=$2
        shift 2
        ;;
      --remote-script)
        [[ $# -ge 2 ]] || die "--remote-script requires a value"
        remote_script=$2
        shift 2
        ;;
      --remote-incoming)
        [[ $# -ge 2 ]] || die "--remote-incoming requires a value"
        remote_incoming=$2
        shift 2
        ;;
      --public-api-port)
        [[ $# -ge 2 ]] || die "--public-api-port requires a value"
        public_api_port=$2
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done

  [[ "$requested_sha" =~ ^[0-9a-fA-F]{7,40}$ ]] ||
    die "GITHUB_SHA must contain 7 to 40 hexadecimal characters"
  if ! [[ "$public_api_port" =~ ^[1-9][0-9]*$ ]] ||
    ((public_api_port > 65535)); then
    die "--public-api-port must be between 1 and 65535"
  fi
  [[ -f "$identity" ]] || die "SSH identity file does not exist: $identity"
  require_command git
  require_command gzip
  require_command mktemp
  require_command scp
  require_command ssh

  git -C "$REPO_ROOT" fetch origin m1
  local full_sha
  full_sha=$(git -C "$REPO_ROOT" rev-parse --verify "${requested_sha}^{commit}") ||
    die "commit does not exist after fetching origin/m1: $requested_sha"
  git -C "$REPO_ROOT" merge-base --is-ancestor "$full_sha" origin/m1 ||
    die "commit $full_sha is not contained in origin/m1"

  run_preflight "$destination" "$identity" "$remote_script"

  local archive
  archive=$(mktemp "${TMPDIR:-/tmp}/ephemeral-mainnet.${full_sha}.XXXXXX.tar.gz")
  ARCHIVE_TO_CLEAN=$archive
  trap cleanup EXIT
  echo "Archiving m1 commit $full_sha..."
  git -C "$REPO_ROOT" archive --format=tar "$full_sha" | gzip -1 >"$archive"

  local remote_archive="$remote_incoming/$full_sha.tar.gz"
  echo "Uploading source archive to $destination..."
  ssh -i "$identity" "$destination" mkdir -p "$remote_incoming"
  scp -i "$identity" "$archive" "$destination:$remote_archive.uploading"
  ssh -i "$identity" "$destination" \
    mv "$remote_archive.uploading" "$remote_archive"

  echo "Starting remote build and fork..."
  set +e
  ssh -i "$identity" "$destination" \
    "$remote_script" start "$full_sha" "$remote_archive" "$public_api_port"
  local status=$?
  set -e
  if ((status == ALREADY_RUNNING_EXIT)); then
    exit "$ALREADY_RUNNING_EXIT"
  fi
  ((status == 0)) || die "remote launcher failed with exit code $status"

  local key_dir="${XDG_CACHE_HOME:-$HOME/.cache}/aptos-ephemeral-mainnet"
  local key_file="$key_dir/$full_sha.key"
  mkdir -p "$key_dir"
  (
    umask 077
    ssh -i "$identity" "$destination" "$remote_script" test-key >"$key_file"
  )
  [[ -s "$key_file" ]] || die "remote launcher returned an empty test key"

  local public_host=${destination#*@}
  echo
  echo "Submission endpoint: http://$public_host:$public_api_port"
  echo "Local test key:      $key_file"
  echo "Validator P2P and native REST remain loopback-only."
  echo
  echo "Contract publishing pattern:"
  echo "  movement move publish --package-dir <MOVE_PACKAGE> \\"
  echo "    --sender-account 0x573537299646e0dfab6ca81086edccf73f77b841f30dde6bfbd730ed428479bf \\"
  echo "    --private-key-file $key_file \\"
  echo "    --url http://$public_host:$public_api_port --assume-yes"
}

main "$@"

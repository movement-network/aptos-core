#!/usr/bin/env bash

# Copyright © Aptos Foundation
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd -P)
LAUNCHER="$ROOT/testsuite/forktest/remote/start_ephemeral_mainnet.sh"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/remote-ephemeral-mainnet-test.XXXXXX")

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p \
  "$TEST_ROOT/repo" \
  "$TEST_ROOT/source-db" \
  "$TEST_ROOT/run/cargo/bin" \
  "$TEST_ROOT/run/rustup"

git -C "$TEST_ROOT/repo" init -q
git -C "$TEST_ROOT/repo" config user.name "Ephemeral Fork Test"
git -C "$TEST_ROOT/repo" config user.email "ephemeral-fork@example.com"
printf '%s\n' "test source" >"$TEST_ROOT/repo/source.txt"
git -C "$TEST_ROOT/repo" add source.txt
git -C "$TEST_ROOT/repo" commit -q -m "test source"
SHA=$(git -C "$TEST_ROOT/repo" rev-parse HEAD)
git -C "$TEST_ROOT/repo" archive --format=tar "$SHA" |
  gzip -1 >"$TEST_ROOT/source.tar.gz"

mkdir -p "$TEST_ROOT/service/builds/$SHA/target/release"
ln -s /usr/bin/true "$TEST_ROOT/service/builds/$SHA/target/release/aptos-node"

# macOS does not provide flock; the remote Linux host does. The no-op shim is
# sufficient because this test invokes one launcher process at a time.
if ! command -v flock >/dev/null 2>&1; then
  ln -s /usr/bin/true "$TEST_ROOT/run/cargo/bin/flock"
fi

launcher_env=(
  "EPHEMERAL_RUN_ROOT=$TEST_ROOT/run"
  "EPHEMERAL_SERVICE_ROOT=$TEST_ROOT/service"
  "EPHEMERAL_SOURCE_DB=$TEST_ROOT/source-db"
  "EPHEMERAL_FORK_TOOL=/usr/bin/true"
  "EPHEMERAL_FORK_LAUNCHER=/usr/bin/true"
  "EPHEMERAL_PUBLIC_API_ENABLED=false"
  "CARGO_HOME=$TEST_ROOT/run/cargo"
  "RUSTUP_HOME=$TEST_ROOT/run/rustup"
)

env "${launcher_env[@]}" "$LAUNCHER" start "$SHA" "$TEST_ROOT/source.tar.gz"
[[ $(cat "$TEST_ROOT/service/active/sha") == "$SHA" ]]
[[ -n $(cat "$TEST_ROOT/service/active/work-dir") ]]

set +e
env \
  "${launcher_env[@]}" \
  "EPHEMERAL_SERVICE_ROOT=$TEST_ROOT/service-mismatch" \
  "$LAUNCHER" start \
  0000000000000000000000000000000000000000 \
  "$TEST_ROOT/source.tar.gz" >/dev/null 2>&1
mismatch_status=$?
set -e
[[ "$mismatch_status" -ne 0 ]]

echo "remote ephemeral mainnet launcher test passed"

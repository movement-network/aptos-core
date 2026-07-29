#!/usr/bin/env bash

# Copyright © Aptos Foundation
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../.." && pwd -P)
LAUNCHER="$ROOT/testsuite/forktest/remote/ephemeral_fork.sh"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ephemeral-fork-test.XXXXXX")
SOURCE_DB="$TEST_ROOT/source-db"
WORK_DIR="$TEST_ROOT/work"
MOCK_FORK_TOOL="$TEST_ROOT/mock-aptos-debugger"
MOCK_NODE="$TEST_ROOT/mock-aptos-node"

cleanup() {
  if [[ -d "$WORK_DIR/.ephemeral-fork" ]]; then
    "$LAUNCHER" stop --work-dir "$WORK_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$SOURCE_DB"

read -r MOCK_PORT_0 MOCK_PORT_1 < <(
  python3 -c '
import socket

sockets = []
ports = []
for _ in range(2):
    sock = socket.socket()
    sock.bind(("127.0.0.1", 0))
    sockets.append(sock)
    ports.append(sock.getsockname()[1])
print(*ports)
'
)
export MOCK_PORT_0 MOCK_PORT_1

cat >"$MOCK_FORK_TOOL" <<'MOCK_FORK'
#!/usr/bin/env bash
set -euo pipefail

[[ "$1 $2 $3" == "aptos-db fork --source-db-dir" ]]
shift 2
output_db=""
config_dir=""
validators=""
test_account=""
while (($#)); do
  case "$1" in
    --source-db-dir | --fork-chain-id)
      shift 2
      ;;
    --output-db-dir)
      output_db=$2
      shift 2
      ;;
    --config-dir)
      config_dir=$2
      shift 2
      ;;
    --validators)
      validators=$2
      shift 2
      ;;
    --test-account-address)
      test_account=$2
      shift 2
      ;;
    --test-account-private-key)
      shift 2
      ;;
    *)
      echo "unexpected mock fork argument: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$output_db" "$config_dir"
for ((index = 0; index < validators; index++)); do
  port_name="MOCK_PORT_$index"
  port=${!port_name}
  mkdir -p "$config_dir/$index"
  cat >"$config_dir/$index/node.yaml" <<EOF
api:
  enabled: true
  address: "127.0.0.1:$port"
base:
  role: "validator"
EOF
done

printf '%s\n' "$test_account" >"$config_dir/test-account-address"
printf '%s\n' \
  "0x0000000000000000000000000000000000000000000000000000000000000abc" \
  >"$config_dir/test-account-private-key"
chmod 600 "$config_dir/test-account-private-key"
cat >"$config_dir/fork-manifest.json" <<EOF
{
  "output_ledger": {"version": 10},
  "waypoint": "10:mock",
  "test_account_rekey": {"address": "$test_account"}
}
EOF
MOCK_FORK
chmod +x "$MOCK_FORK_TOOL"

cat >"$MOCK_NODE" <<'MOCK_NODE'
#!/usr/bin/env python3
import argparse
import http.server
import json
import re

parser = argparse.ArgumentParser()
parser.add_argument("-f", dest="config", required=True)
args = parser.parse_args()
with open(args.config, encoding="utf-8") as config_file:
    config = config_file.read()
match = re.search(r'address: "127\.0\.0\.1:(\d+)"', config)
if match is None:
    raise RuntimeError("mock node config has no REST port")
port = int(match.group(1))


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps(
            {
                "chain_id": 42,
                "epoch": "7",
                "ledger_version": "11",
            }
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format, *_args):
        return


http.server.HTTPServer(("127.0.0.1", port), Handler).serve_forever()
MOCK_NODE
chmod +x "$MOCK_NODE"

start_output=$(
  "$LAUNCHER" start \
    --source-db "$SOURCE_DB" \
    --source-is-disposable \
    --fork-tool "$MOCK_FORK_TOOL" \
    --node-binary "$MOCK_NODE" \
    --test-account-address 0x1234 \
    --work-dir "$WORK_DIR" \
    --health-timeout 10
)
grep -q "Ephemeral fork is healthy." <<<"$start_output"
grep -q "Private key file:" <<<"$start_output"
grep -q "movement move publish" <<<"$start_output"

status_output=$("$LAUNCHER" status --work-dir "$WORK_DIR")
[[ $(grep -c "status=healthy" <<<"$status_output") -eq 2 ]]
grep -q "chain_id=42" <<<"$status_output"
grep -q "ledger_version=11" <<<"$status_output"

expected_key="0x0000000000000000000000000000000000000000000000000000000000000abc"
[[ $(cat "$WORK_DIR/configs/test-account-private-key") == "$expected_key" ]]

"$LAUNCHER" stop --work-dir "$WORK_DIR" >/dev/null
if "$LAUNCHER" status --work-dir "$WORK_DIR" >/dev/null 2>&1; then
  echo "status unexpectedly succeeded after validators stopped" >&2
  exit 1
fi

if "$LAUNCHER" start \
  --source-db "$SOURCE_DB" \
  --fork-tool "$MOCK_FORK_TOOL" \
  --node-binary "$MOCK_NODE" \
  --test-account-address 0x1234 \
  --work-dir "$TEST_ROOT/missing-ack" >/dev/null 2>&1; then
  echo "start unexpectedly accepted a source without disposable acknowledgement" >&2
  exit 1
fi

if "$LAUNCHER" start \
  --source-db "$SOURCE_DB" \
  --source-is-disposable \
  --fork-tool "$MOCK_FORK_TOOL" \
  --node-binary "$MOCK_NODE" \
  --test-account-address 0x1234 \
  --chain-id 126 \
  --work-dir "$TEST_ROOT/mainnet-chain-id" >/dev/null 2>&1; then
  echo "start unexpectedly accepted Movement mainnet chain ID 126" >&2
  exit 1
fi

echo "ephemeral fork lifecycle test passed"

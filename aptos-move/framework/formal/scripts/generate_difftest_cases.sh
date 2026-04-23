#!/usr/bin/env bash
# generate_difftest_cases.sh
# Generates concrete difftest test cases from templates
# Usage: ./generate_difftest_cases.sh --operation transfer --count 5

set -euo pipefail

OPERATION=""
COUNT=3
TYPE="happy_path"

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--operation) OPERATION="$2"; shift 2 ;;
        -c|--count) COUNT="$2"; shift 2 ;;
        -t|--type) TYPE="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

[[ -z "$OPERATION" ]] && { echo "Missing --operation"; exit 1; }

generate_happy_path() {
    local op="$1"
    local idx="$2"
    
    cat <<JSON
{
  "id": "${op}_happy_$(printf "%03d" $idx)",
  "operation": "$op",
  "type": "happy_path",
  "description": "Valid proof, standard inputs (case $idx)",
  "input": {
    "proof": "$(openssl rand -hex 128)",
    "public_inputs": "$(openssl rand -hex 64)",
    "account_state": {
      "address": "0x$(openssl rand -hex 16)",
      "frozen": false,
      "pending_balance": "$(openssl rand -hex 32)",
      "actual_balance": "$(openssl rand -hex 32)"
    }
  },
  "expected": {
    "result": "Success",
    "state_changes": {
      "pending_balance": "$(openssl rand -hex 32)"
    }
  },
  "tags": ["$op", "happy_path", "valid_proof"]
}
JSON
}

generate_error_path() {
    local op="$1"
    local idx="$2"
    
    cat <<JSON
{
  "id": "${op}_error_$(printf "%03d" $idx)",
  "operation": "$op",
  "type": "error_path",
  "description": "Invalid proof (verification fails)",
  "input": {
    "proof": "$(openssl rand -hex 128)",
    "public_inputs": "$(openssl rand -hex 64)",
    "account_state": {
      "address": "0x$(openssl rand -hex 16)",
      "frozen": false,
      "pending_balance": "$(openssl rand -hex 32)",
      "actual_balance": "$(openssl rand -hex 32)"
    }
  },
  "expected": {
    "result": "Aborted",
    "abort_code": 65537,
    "state_changes": {}
  },
  "tags": ["$op", "error_path", "invalid_proof"]
}
JSON
}

echo "["
for ((i=1; i<=COUNT; i++)); do
    if [[ "$TYPE" == "happy_path" ]]; then
        generate_happy_path "$OPERATION" "$i"
    else
        generate_error_path "$OPERATION" "$i"
    fi
    [[ $i -lt $COUNT ]] && echo ","
done
echo "]"

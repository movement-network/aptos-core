#!/usr/bin/env bash
set -euo pipefail

#
# generate_difftest_test.sh
#
# Purpose: Generate difftest test case JSON template for a given operation and scenario.
# Creates skeleton with initial state, inputs, expected outputs, and Lean alignment.
#
# Usage:
#   ./generate_difftest_test.sh --operation <name> --scenario <type> [OPTIONS]
#
# Options:
#   --operation <name>  Operation name (required): transfer, withdrawal, rotation, etc.
#   --scenario <type>   Scenario type (required): happy_path, frozen, proof_invalid, etc.
#   --output <file>     Output file (default: difftest/confidential_asset/<operation>_<scenario>.json)
#   --addresses <csv>   Comma-separated addresses to use (default: auto-generate)
#   --verbose           Show detailed generation info
#
# Scenarios:
#   happy_path          - Successful execution
#   frozen              - Account frozen error
#   proof_invalid       - Proof verification failed
#   insufficient_balance - Balance too low error
#   recipient_rejected  - Allow list rejection (transfer only)
#
# Examples:
#   ./generate_difftest_test.sh --operation transfer --scenario happy_path
#   ./generate_difftest_test.sh --operation withdrawal --scenario frozen --output custom_test.json
#   ./generate_difftest_test.sh --operation rotation --scenario proof_invalid --addresses "0xA11CE,0xB0B"
#

# Configuration
OPERATION=""
SCENARIO=""
OUTPUT_FILE=""
ADDRESSES=""
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default test addresses
DEFAULT_ADDRESSES=(
  "0xA11CE"
  "0xB0B"
  "0xCA101"
  "0xDE1E7E"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --operation)
      OPERATION="$2"
      shift 2
      ;;
    --scenario)
      SCENARIO="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --addresses)
      ADDRESSES="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      head -n 35 "$0" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage"
      exit 1
      ;;
  esac
done

# Validate arguments
if [[ -z "$OPERATION" ]]; then
  echo -e "${RED}Error: --operation is required${NC}"
  echo "Run with --help for usage"
  exit 1
fi

if [[ -z "$SCENARIO" ]]; then
  echo -e "${RED}Error: --scenario is required${NC}"
  echo "Run with --help for usage"
  exit 1
fi

# Set default output file
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_DIR="difftest/confidential_asset"
  mkdir -p "$OUTPUT_DIR"
  OUTPUT_FILE="${OUTPUT_DIR}/${OPERATION}_${SCENARIO}.json"
fi

# Parse addresses or use defaults
if [[ -n "$ADDRESSES" ]]; then
  IFS=',' read -ra ADDR_ARRAY <<< "$ADDRESSES"
else
  ADDR_ARRAY=("${DEFAULT_ADDRESSES[@]}")
fi

ALICE="${ADDR_ARRAY[0]}"
BOB="${ADDR_ARRAY[1]:-${DEFAULT_ADDRESSES[1]}}"

echo -e "${BLUE}=== Difftest Test Generator ===${NC}"
echo "Operation: $OPERATION"
echo "Scenario: $SCENARIO"
echo "Output: $OUTPUT_FILE"
echo "Addresses: ${ADDR_ARRAY[*]}"
echo ""

# Determine abort code based on scenario
declare -A ABORT_CODES
ABORT_CODES["frozen"]=196612
ABORT_CODES["proof_invalid"]=65537
ABORT_CODES["insufficient_balance"]=65538
ABORT_CODES["recipient_rejected"]=196613

ABORT_CODE="${ABORT_CODES[$SCENARIO]:-0}"

# Generate test JSON based on operation and scenario
generate_test() {
  local op=$1
  local scenario=$2

  cat <<ENDOFJSON
{
  "test_id": "${op}_${scenario}",
  "operation": "$op",
  "description": "$(generate_description "$op" "$scenario")",
  "initial_state": $(generate_initial_state "$op" "$scenario"),
  "inputs": $(generate_inputs "$op" "$scenario"),
  "expected_output": $(generate_expected_output "$op" "$scenario"),
  "lean_model_alignment": $(generate_lean_alignment "$op" "$scenario")
}
ENDOFJSON
}

# Generate human-readable description
generate_description() {
  local op=$1
  local scenario=$2

  case "$scenario" in
    happy_path)
      case "$op" in
        transfer) echo "Successful confidential transfer from Alice to Bob" ;;
        withdrawal) echo "Successful withdrawal from encrypted to plaintext balance" ;;
        rotation) echo "Successful encryption key rotation with balance re-encryption" ;;
        normalization) echo "Successful balance normalization (chunk compaction)" ;;
        registration) echo "Successful account registration for confidential assets" ;;
        *) echo "Successful $op operation" ;;
      esac
      ;;
    frozen)
      echo "${op^} fails when account is frozen"
      ;;
    proof_invalid)
      echo "${op^} fails when zero-knowledge proof is invalid"
      ;;
    insufficient_balance)
      echo "${op^} fails when encrypted balance is insufficient"
      ;;
    recipient_rejected)
      echo "Transfer fails when recipient's allow list rejects sender"
      ;;
    *)
      echo "TODO: Add description for $op $scenario"
      ;;
  esac
}

# Generate initial state
generate_initial_state() {
  local op=$1
  local scenario=$2

  if [[ "$scenario" == "happy_path" ]]; then
    case "$op" in
      transfer)
        cat <<'ENDOFJSON'
{
    "alice": {
      "address": "ALICE_ADDR",
      "pending_balance": [
        {
          "left": "0x1234...",
          "right": "0x5678..."
        }
      ],
      "frozen": false,
      "plaintext_balance_encrypted": 1000
    },
    "bob": {
      "address": "BOB_ADDR",
      "pending_balance": [
        {
          "left": "0xABCD...",
          "right": "0xEF01..."
        }
      ],
      "frozen": false,
      "incoming_allow_list": ["ALICE_ADDR"],
      "plaintext_balance_encrypted": 500
    }
  }
ENDOFJSON
        ;;
      withdrawal)
        cat <<'ENDOFJSON'
{
    "alice": {
      "address": "ALICE_ADDR",
      "pending_balance": [
        {
          "left": "0x1234...",
          "right": "0x5678..."
        }
      ],
      "frozen": false,
      "plaintext_balance_encrypted": 1000
    }
  }
ENDOFJSON
        ;;
      *)
        echo '{"alice": {"address": "ALICE_ADDR", "frozen": false}}'
        ;;
    esac
  else
    # Error scenarios
    case "$scenario" in
      frozen)
        echo '{"alice": {"address": "ALICE_ADDR", "frozen": true}}'
        ;;
      *)
        echo '{"alice": {"address": "ALICE_ADDR", "frozen": false}}'
        ;;
    esac
  fi | sed "s/ALICE_ADDR/$ALICE/g" | sed "s/BOB_ADDR/$BOB/g"
}

# Generate inputs
generate_inputs() {
  local op=$1
  local scenario=$2

  local proof_validity="valid"
  if [[ "$scenario" == "proof_invalid" ]]; then
    proof_validity="INVALID"
  fi

  case "$op" in
    transfer)
      cat <<ENDOFJSON
{
    "sender": "$ALICE",
    "receiver": "$BOB",
    "transfer_proof": {
      "range_proof": "0x${proof_validity}...",
      "amount_commitment": "0x...",
      "sender_new_balance_ciphertext": {
        "left": "0x...",
        "right": "0x..."
      },
      "receiver_new_balance_ciphertext": {
        "left": "0x...",
        "right": "0x..."
      },
      "sender_balance_proof": "0x...",
      "receiver_balance_proof": "0x...",
      "sender_signature": "0x..."
    },
    "transfer_amount_plaintext": 100
  }
ENDOFJSON
      ;;
    withdrawal)
      cat <<ENDOFJSON
{
    "owner": "$ALICE",
    "withdrawal_proof": {
      "range_proof": "0x${proof_validity}...",
      "amount_commitment": "0x...",
      "withdrawal_amount": 100,
      "new_balance_ciphertext": {
        "left": "0x...",
        "right": "0x..."
      },
      "balance_proof": "0x...",
      "owner_signature": "0x..."
    }
  }
ENDOFJSON
      ;;
    rotation)
      cat <<ENDOFJSON
{
    "owner": "$ALICE",
    "rotation_proof": {
      "new_public_key": "0xNEW_KEY...",
      "re_encrypted_chunks": [
        {
          "left": "0xNEW1...",
          "right": "0xNEW2..."
        }
      ],
      "re_encryption_proof": "0x${proof_validity}...",
      "owner_signature": "0x..."
    }
  }
ENDOFJSON
      ;;
    *)
      echo '{"owner": "'"$ALICE"'", "proof": "TODO"}'
      ;;
  esac
}

# Generate expected output
generate_expected_output() {
  local op=$1
  local scenario=$2

  if [[ "$scenario" == "happy_path" ]]; then
    case "$op" in
      transfer)
        cat <<'ENDOFJSON'
{
    "status": "success",
    "alice": {
      "pending_balance_length": 2,
      "plaintext_balance_encrypted": 900
    },
    "bob": {
      "pending_balance_length": 2,
      "plaintext_balance_encrypted": 600
    },
    "total_balance_conserved": true
  }
ENDOFJSON
        ;;
      withdrawal)
        cat <<'ENDOFJSON'
{
    "status": "success",
    "alice": {
      "pending_balance_length": 2,
      "plaintext_balance_encrypted": 900
    },
    "balance_conserved": true
  }
ENDOFJSON
        ;;
      *)
        echo '{"status": "success"}'
        ;;
    esac
  else
    # Error scenario
    cat <<ENDOFJSON
{
    "status": "aborted",
    "abort_code": $ABORT_CODE,
    "abort_message": "$(get_abort_message "$scenario")",
    "state_unchanged": true
  }
ENDOFJSON
  fi
}

# Get abort message for scenario
get_abort_message() {
  local scenario=$1

  case "$scenario" in
    frozen) echo "account is frozen" ;;
    proof_invalid) echo "proof verification failed" ;;
    insufficient_balance) echo "insufficient balance" ;;
    recipient_rejected) echo "recipient rejected transfer" ;;
    *) echo "error" ;;
  esac
}

# Generate Lean alignment metadata
generate_lean_alignment() {
  local op=$1
  local scenario=$2

  if [[ "$scenario" == "happy_path" ]]; then
    cat <<ENDOFJSON
{
    "oracle_calls": [
      {
        "function": "verify$(echo "${op:0:1}" | tr '[:lower:]' '[:upper:]')${op:1}Proof",
        "input": "proof",
        "output": "some(true)"
      }
    ],
    "final_pc": 0,
    "execution_result": "returned"
  }
ENDOFJSON
  else
    # Error scenario
    local final_pc=5
    if [[ "$scenario" == "proof_invalid" ]]; then
      final_pc=14
    fi

    cat <<ENDOFJSON
{
    "oracle_calls": [],
    "final_pc": $final_pc,
    "execution_result": "error \"$(get_abort_message "$scenario")\""
  }
ENDOFJSON
  fi
}

# Generate test JSON
TEST_JSON=$(generate_test "$OPERATION" "$SCENARIO")

# Write to file
echo "$TEST_JSON" | jq '.' > "$OUTPUT_FILE" 2>/dev/null || echo "$TEST_JSON" > "$OUTPUT_FILE"

echo -e "${GREEN}✅ Difftest test case generated!${NC}"
echo ""
echo "Output file: $OUTPUT_FILE"
echo ""

if [[ -f "$OUTPUT_FILE" ]]; then
  FILE_SIZE=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
  echo "File size: ${FILE_SIZE} bytes"
fi

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the generated test case: cat $OUTPUT_FILE | jq '.'"
echo "  2. Fill in TODO placeholders (proof values, ciphertexts, etc.)"
echo "  3. Update Lean alignment metadata (final_pc, oracle calls)"
echo "  4. Run difftest: ./scripts/manage_difftest_corpus.sh test ${OPERATION}"
echo ""
echo -e "${BLUE}Tip: Use actual VM output to populate proof values and ciphertexts${NC}"
echo "  aptos move run --function-id 0x1::confidential_asset::${OPERATION} ..."
echo ""
echo -e "${BLUE}Tip: See DIFFTEST_CA_INVENTORY.md for test matrix coverage${NC}"

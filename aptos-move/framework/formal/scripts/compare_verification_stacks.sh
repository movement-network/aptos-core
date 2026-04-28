#!/usr/bin/env bash
set -euo pipefail

#
# compare_verification_stacks.sh
#
# Purpose: Compare verification results across the three stacks (Lean, Move Prover, Difftest)
# to detect inconsistencies and ensure all three agree on the same properties.
#
# Usage:
#   ./compare_verification_stacks.sh [OPTIONS]
#
# Options:
#   --operation <name>   Compare stacks for a specific operation (required)
#   --property <name>    Check a specific property (abort codes, balance conservation, etc.)
#   --format <type>      Output format: text (default), json, markdown
#   --verbose            Show detailed comparison
#
# Examples:
#   ./compare_verification_stacks.sh --operation transfer --property abort_codes
#   ./compare_verification_stacks.sh --operation normalization --format json
#   ./compare_verification_stacks.sh --operation withdrawal --verbose
#

# Configuration
OPERATION=""
PROPERTY="all"
FORMAT="text"
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --operation)
      OPERATION="$2"
      shift 2
      ;;
    --property)
      PROPERTY="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      head -n 20 "$0" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
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
  echo "Error: --operation is required"
  echo "Run with --help for usage"
  exit 1
fi

# Normalize operation name (capitalize first letter)
OPERATION_NORMALIZED="$(echo "${OPERATION:0:1}" | tr '[:lower:]' '[:upper:]')${OPERATION:1}"

# File paths
LEAN_DIR="lean/MovementFormal/Experimental/ConfidentialAsset/$OPERATION_NORMALIZED"
MSL_SPEC="aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.spec.move"
DIFFTEST_DIR="examples/difftest"

# Initialize results
declare -A lean_results
declare -A msl_results
declare -A difftest_results

# Helper: Extract abort codes from Lean functional sim
extract_lean_abort_codes() {
  local functional_sim="$LEAN_DIR/FunctionalSim.lean"

  if [[ ! -f "$functional_sim" ]]; then
    echo "Lean functional sim not found: $functional_sim" >&2
    return 1
  fi

  # Look for .aborted <code> patterns
  grep -oE "\.aborted [0-9]+" "$functional_sim" | sed 's/.aborted //' | sort -u
}

# Helper: Extract abort codes from MSL spec
extract_msl_abort_codes() {
  if [[ ! -f "$MSL_SPEC" ]]; then
    echo "MSL spec not found: $MSL_SPEC" >&2
    return 1
  fi

  # Look for "aborts_if ... with E<NAME>" patterns
  # Extract error constant names, then resolve them
  grep -oE "with E[A-Z_]+" "$MSL_SPEC" | sed 's/with //' | sort -u
}

# Helper: Extract abort codes from difftest corpus
extract_difftest_abort_codes() {
  if [[ ! -d "$DIFFTEST_DIR" ]]; then
    echo "Difftest directory not found: $DIFFTEST_DIR" >&2
    return 1
  fi

  # Find test cases for this operation with abort outcomes
  find "$DIFFTEST_DIR" -name "${OPERATION}*.json" -type f | while read -r test_file; do
    if grep -q '"status": "aborted"' "$test_file"; then
      grep -oE '"abort_code": "[0-9]+"' "$test_file" | sed 's/"abort_code": "//' | sed 's/"//'
    fi
  done | sort -u
}

# Helper: Check balance conservation property
check_balance_conservation() {
  local has_lean=false
  local has_msl=false
  local has_difftest=false

  # Lean: look for balance sum theorems
  if [[ -f "$LEAN_DIR/Phase6Composition.lean" ]]; then
    if grep -q "sum.*balance" "$LEAN_DIR/Phase6Composition.lean"; then
      has_lean=true
    fi
  fi

  # MSL: look for sum_balance ensures clauses
  if grep -q "sum_balance.*ensures" "$MSL_SPEC"; then
    has_msl=true
  fi

  # Difftest: look for test cases that check balance sums
  if find "$DIFFTEST_DIR" -name "${OPERATION}*.json" -type f -exec grep -l "old_sum\|new_sum" {} \; | head -1 | read; then
    has_difftest=true
  fi

  echo "Lean: $has_lean, MSL: $has_msl, Difftest: $has_difftest"
}

# Helper: Compare abort codes across stacks
compare_abort_codes() {
  echo "Comparing abort codes for operation: $OPERATION"
  echo ""

  echo "Lean abort codes:"
  extract_lean_abort_codes | while read -r code; do
    echo "  - $code"
  done
  echo ""

  echo "MSL abort error constants:"
  extract_msl_abort_codes | while read -r const; do
    echo "  - $const"
  done
  echo ""

  echo "Difftest abort codes:"
  extract_difftest_abort_codes | while read -r code; do
    echo "  - $code"
  done
  echo ""

  # TODO: Cross-reference error constants to numeric codes
  echo "Note: MSL error constants need to be resolved to numeric codes for comparison."
  echo "See aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.move for mappings."
}

# Main logic
case $PROPERTY in
  abort_codes)
    compare_abort_codes
    ;;

  balance_conservation)
    echo "Checking balance conservation across stacks:"
    echo ""
    check_balance_conservation
    ;;

  all)
    echo "=== Stack Comparison: $OPERATION ==="
    echo ""
    echo "Checking abort codes..."
    compare_abort_codes
    echo ""
    echo "Checking balance conservation..."
    check_balance_conservation
    ;;

  *)
    echo "Error: Unknown property: $PROPERTY"
    echo "Supported properties: abort_codes, balance_conservation, all"
    exit 1
    ;;
esac

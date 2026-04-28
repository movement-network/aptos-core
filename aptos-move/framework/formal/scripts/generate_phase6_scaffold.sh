#!/usr/bin/env bash
set -euo pipefail

#
# generate_phase6_scaffold.sh
#
# Purpose: Generate Phase 6 composition proof scaffolds for a given operation.
# Creates shape lemmas, composition theorem structure, and helper definitions.
#
# Usage:
#   ./generate_phase6_scaffold.sh --operation <name> [OPTIONS]
#
# Options:
#   --operation <name>  Operation name (required): normalization, withdrawal, transfer, rotation
#   --output-dir <dir>  Output directory (default: lean/MovementFormal/Experimental/ConfidentialAsset/<Operation>)
#   --overwrite         Overwrite existing files
#
# Examples:
#   ./generate_phase6_scaffold.sh --operation normalization
#   ./generate_phase6_scaffold.sh --operation transfer --overwrite
#

# Configuration
OPERATION=""
OUTPUT_DIR=""
OVERWRITE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --operation)
      OPERATION="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --overwrite)
      OVERWRITE=true
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

# Normalize operation name
OPERATION_LOWER=$(echo "$OPERATION" | tr '[:upper:]' '[:lower:]')
OPERATION_CAPITALIZED="$(echo "${OPERATION:0:1}" | tr '[:lower:]' '[:upper:]')${OPERATION:1}"

# Set default output directory
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="lean/MovementFormal/Experimental/ConfidentialAsset/$OPERATION_CAPITALIZED"
fi

# Check if directory exists
if [[ ! -d "$OUTPUT_DIR" ]]; then
  echo "Creating directory: $OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"
fi

# Output file
OUTPUT_FILE="$OUTPUT_DIR/Phase6Composition.lean"

# Check if file exists
if [[ -f "$OUTPUT_FILE" ]] && [[ "$OVERWRITE" != "true" ]]; then
  echo "Error: File already exists: $OUTPUT_FILE"
  echo "Use --overwrite to replace it"
  exit 1
fi

echo "Generating Phase 6 scaffold for operation: $OPERATION"
echo "Output file: $OUTPUT_FILE"

# Generate the scaffold
cat > "$OUTPUT_FILE" << 'ENDOFFILE'
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Refs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.Experimental.ConfidentialAsset.OPERATION_CAPITALIZED.EvalEquiv
import MovementFormal.Experimental.ConfidentialAsset.OPERATION_CAPITALIZED.FunctionalSim

/-!
# Phase 6 Composition: OPERATION_CAPITALIZED

Proves that the `eval` execution trace is semantically equivalent to the
high-level functional simulation `verifyOPERATION_CAPITALIZEDBytecodeResult`.

Main theorem: `OPERATION_LOWER_eval_equiv_functional_sim`

## Structure

1. **Shape lemmas** — one per oracle outcome (verify-failed, success, etc.)
2. **Main composition theorem** — dispatches to shape lemmas via case-split

## Status

Currently: All lemmas scaffolded with `sorry`. Fill in the proofs following
the pattern in §3 of `PHASE_6_PC_CHAINING_IMPLEMENTATION_GUIDE.md`.

Build time target: < 1 minute (as of scaffolding, builds in ~0.1s with sorry).

-/

namespace MovementFormal.Experimental.ConfidentialAsset.OPERATION_CAPITALIZED.Phase6Composition

open MovementFormal.MoveModel
open MovementFormal.Experimental.ConfidentialAsset.OPERATION_CAPITALIZED.EvalEquiv
open MovementFormal.Experimental.ConfidentialAsset.OPERATION_CAPITALIZED.FunctionalSim

/-! ## Shape Lemma: Proof Verification Failed

Proves that when the oracle returns `none`, the execution errors.
-/

theorem OPERATION_LOWER_shape_verifyFailed
    (oracle : OPERATION_CAPITALIZEDNativeOracle)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_verify : oracle.verifyOPERATION_CAPITALIZEDProof proofRef = none) :
    run env (OPERATION_LOWER InitFrame [proofRef]) cs ms =
      .error "OPERATION_LOWER proof verification failed" := by
  sorry
  -- TODO: Unfold run, chain through PCs up to the native call,
  -- substitute h_verify, apply step_call_native_none

/-! ## Shape Lemma: Proof Verification Succeeded

Proves that when the oracle returns `some proof`, the execution succeeds.
-/

theorem OPERATION_LOWER_shape_success
    (oracle : OPERATION_CAPITALIZEDNativeOracle)
    (proofRef : RefValue)
    (proof : OPERATION_CAPITALIZEDProof)
    (cs : CallStack)
    (ms : MachineState)
    (h_verify : oracle.verifyOPERATION_CAPITALIZEDProof proofRef = some proof) :
    run env (OPERATION_LOWER InitFrame [proofRef]) cs ms =
      .returned [] ms := by
  sorry
  -- TODO: Unfold run, chain through all PCs,
  -- substitute h_verify, apply step_call_native_some

/-! ## Main Composition Theorem

Connects `run` (low-level bytecode execution) to `verifyOPERATION_CAPITALIZEDBytecodeResult`
(high-level functional simulation).

This is the key theorem for Phase 6.
-/

theorem OPERATION_LOWER_eval_equiv_functional_sim
    (oracle : OPERATION_CAPITALIZEDNativeOracle)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState) :
    run env (OPERATION_LOWER InitFrame [proofRef]) cs ms =
      verifyOPERATION_CAPITALIZEDBytecodeResult oracle proofRef := by
  -- Unfold the functional sim definition
  unfold verifyOPERATION_CAPITALIZEDBytecodeResult

  -- Case-split on the oracle result
  cases h : oracle.verifyOPERATION_CAPITALIZEDProof proofRef
  case none =>
    -- Dispatch to verify-failed shape lemma
    exact OPERATION_LOWER_shape_verifyFailed oracle proofRef cs ms h
  case some proof =>
    -- Dispatch to success shape lemma
    exact OPERATION_LOWER_shape_success oracle proofRef proof cs ms h

end MovementFormal.Experimental.ConfidentialAsset.OPERATION_CAPITALIZED.Phase6Composition
ENDOFFILE

# Replace placeholders
sed -i.bak "s/OPERATION_CAPITALIZED/$OPERATION_CAPITALIZED/g" "$OUTPUT_FILE"
sed -i.bak "s/OPERATION_LOWER/$OPERATION_LOWER/g" "$OUTPUT_FILE"
rm "${OUTPUT_FILE}.bak"

echo ""
echo "✅ Scaffold generated successfully!"
echo ""
echo "Next steps:"
echo "  1. Review the generated file: $OUTPUT_FILE"
echo "  2. Fill in the sorry placeholders following the guide in:"
echo "     PHASE_6_PC_CHAINING_IMPLEMENTATION_GUIDE.md"
echo "  3. Test build: lake build MovementFormal.Experimental.ConfidentialAsset.$OPERATION_CAPITALIZED.Phase6Composition"
echo "  4. Target build time: < 1 minute"
echo ""
echo "Shape lemmas to implement:"
echo "  - ${OPERATION_LOWER}_shape_verifyFailed (error path)"
echo "  - ${OPERATION_LOWER}_shape_success (happy path)"
echo ""
echo "Main theorem:"
echo "  - ${OPERATION_LOWER}_eval_equiv_functional_sim"

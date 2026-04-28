#!/usr/bin/env bash
# generate_pc_chain_proof.sh — Automated PC-chaining proof scaffold generator
#
# Generates structured proof scaffolding for Phase 6 composition theorems by analyzing
# existing step theorems and creating the run_succ_ok_of_step chain boilerplate.
#
# Usage:
#   ./generate_pc_chain_proof.sh <operation> <start_pc> <end_pc>
#
# Example:
#   ./generate_pc_chain_proof.sh normalization 5 8
#   ./generate_pc_chain_proof.sh withdrawal 0 15
#
# Output: Prints Lean proof code to stdout (redirect to file or copy-paste)

set -euo pipefail

OPERATION="${1:-}"
START_PC="${2:-}"
END_PC="${3:-}"

if [[ -z "$OPERATION" ]] || [[ -z "$START_PC" ]] || [[ -z "$END_PC" ]]; then
    echo "Usage: $0 <operation> <start_pc> <end_pc>" >&2
    echo "" >&2
    echo "Available operations:" >&2
    echo "  normalization, withdrawal, transfer, rotation" >&2
    exit 1
fi

# Validate PC range
if [[ "$START_PC" -ge "$END_PC" ]]; then
    echo "Error: start_pc must be less than end_pc" >&2
    exit 1
fi

FUEL_NEEDED=$((END_PC - START_PC))

# Operation-specific configuration
case "$OPERATION" in
    normalization)
        OPERATION_CAP="Normalization"
        MODULE_ENV="normalizationModuleEnv"
        CODE="verifyNormalizationProofCode"
        ;;
    withdrawal)
        OPERATION_CAP="Withdrawal"
        MODULE_ENV="withdrawalModuleEnv"
        CODE="verifyWithdrawalProofCode"
        ;;
    transfer)
        OPERATION_CAP="Transfer"
        MODULE_ENV="transferModuleEnv"
        CODE="verifyTransferProofCode"
        ;;
    rotation)
        OPERATION_CAP="Rotation"
        MODULE_ENV="rotationModuleEnv"
        CODE="verifyRotationProofCode"
        ;;
    *)
        echo "Error: Unknown operation '$OPERATION'" >&2
        echo "Supported: normalization, withdrawal, transfer, rotation" >&2
        exit 1
        ;;
esac

# Read the EvalEquiv file to extract step theorem signatures
EVAL_EQUIV_FILE="lean/MovementFormal/Experimental/ConfidentialAsset/${OPERATION_CAP}/EvalEquiv.lean"

if [[ ! -f "$EVAL_EQUIV_FILE" ]]; then
    echo "Error: EvalEquiv file not found: $EVAL_EQUIV_FILE" >&2
    exit 1
fi

echo "/-!"
echo "  Auto-generated PC-chaining proof scaffold"
echo "  Operation: $OPERATION"
echo "  PC range: $START_PC to $END_PC (${FUEL_NEEDED} steps)"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "-/"
echo ""

# Generate theorem signature
echo "theorem ${OPERATION}_run_pc${START_PC}_to_pc${END_PC}"

# Extract parameters from the first step theorem
# This is heuristic-based; may need manual adjustment
echo "    (o : ${OPERATION_CAP}ModuleOracle)"
echo "    (frame_start : Frame)"
echo "    (cs : List Frame)"
echo "    (stack_start : List MoveValue)"
echo "    (ms_start : MachineState)"
echo "    (hcode : frame_start.code = $CODE)"
echo "    (hpc : frame_start.pc = $START_PC)"
echo "    (fuel : Nat)"
echo "    (hfuel : fuel ≥ $FUEL_NEEDED)"

# Add operation-specific parameters (these are placeholders)
echo "    -- TODO: Add operation-specific hypotheses (locals contents, ref validity, etc.)"

echo "    :"

# Generate conclusion
echo "    run ($MODULE_ENV o) frame_start cs stack_start ms_start fuel ="
echo "    run ($MODULE_ENV o)"
echo "        { frame_start with pc := $END_PC }"
echo "        cs"
echo "        stack_end  -- TODO: Specify final stack state"
echo "        ms_end     -- TODO: Specify final machine state"
echo "        (fuel - $FUEL_NEEDED) := by"

echo "  -- Fuel decomposition"
echo "  have hfuel_decomp : fuel = (fuel - $FUEL_NEEDED) + $FUEL_NEEDED := by omega"

# Generate per-PC chaining pattern
for ((pc = START_PC; pc < END_PC; pc++)); do
    next_pc=$((pc + 1))
    remaining=$((END_PC - next_pc))

    echo ""
    echo "  -- PC $pc → PC $next_pc"

    # Check if this PC has a step theorem defined
    if grep -q "theorem step_${OPERATION}_pc${pc} " "$EVAL_EQUIV_FILE" 2>/dev/null; then
        echo "  -- Step theorem: step_${OPERATION}_pc${pc}"

        # Try to extract the instruction type from bytecode lemma
        instr_line=$(grep -A 1 "code_pc${pc}.*=" "$EVAL_EQUIV_FILE" | tail -1 | sed 's/.*\.//' | sed 's/ .*//' || echo "unknown")

        echo "  -- Instruction: .$instr_line"
        echo "  have step_pc${pc} : step ($MODULE_ENV o) frame${pc} cs stack${pc} ms${pc} ="
        echo "      .ok frame${next_pc} cs stack${next_pc} ms${next_pc} := by"
        echo "    apply step_${OPERATION}_pc${pc} o frame${pc} cs stack${pc} ms${pc} rfl rfl"
        echo "    sorry  -- TODO: Provide step theorem arguments"
        echo ""

        if [[ $remaining -gt 0 ]]; then
            echo "  rw [show (fuel - $FUEL_NEEDED) + $((END_PC - pc)) = ((fuel - $FUEL_NEEDED) + $remaining) + 1 from by omega]"
            echo "  rw [run_succ_ok_of_step ((fuel - $FUEL_NEEDED) + $remaining) frame${next_pc} cs stack${next_pc} ms${next_pc} step_pc${pc}]"
        else
            echo "  rw [show (fuel - $FUEL_NEEDED) + 1 = (fuel - $FUEL_NEEDED) + 1 from rfl]"
            echo "  rw [run_succ_ok_of_step (fuel - $FUEL_NEEDED) frame${next_pc} cs stack${next_pc} ms${next_pc} step_pc${pc}]"
        fi

        echo ""
        echo "  -- Frame state after PC $pc"
        echo "  set frame${next_pc} : Frame := sorry  -- TODO: Specify frame evolution"
        echo "  set stack${next_pc} : List MoveValue := sorry  -- TODO: Specify stack evolution"
        echo "  set ms${next_pc} : MachineState := sorry  -- TODO: Specify machine state evolution"
    else
        echo "  -- WARNING: No step theorem found for PC $pc"
        echo "  -- You may need to create step_${OPERATION}_pc${pc} first"
        echo "  sorry"
    fi
done

echo ""
echo "  -- Final state simplification"
echo "  rfl"

echo ""
echo ""
echo "/-! ## Usage Notes"
echo ""
echo "This generated scaffold provides the structural skeleton for a PC-chaining proof."
echo "You need to fill in:"
echo ""
echo "1. **Operation-specific hypotheses** in the theorem signature:"
echo "   - Locals contents (e.g., hlocals_at_K : locals[K] = some val)"
echo "   - Reference validity (e.g., hread : containers.read rid = some struct)"
echo "   - Field counts and bounds"
echo ""
echo "2. **Step theorem arguments** at each sorry:"
echo "   - Most step theorems need: values from locals, ref IDs, array bounds"
echo "   - Check the step theorem signature in ${OPERATION_CAP}/EvalEquiv.lean"
echo ""
echo "3. **Frame/stack/ms evolution** at each set:"
echo "   - moveLoc: updates locals[K] := none, pushes to stack"
echo "   - copyLoc: keeps locals unchanged, pushes to stack"
echo "   - immBorrowField: allocates new ref in containers"
echo "   - call: may mutate containers and globals"
echo ""
echo "4. **Final state specification**:"
echo "   - stack_end: list of values on stack after $END_PC PCs"
echo "   - ms_end: machine state (especially containers if allocations occurred)"
echo ""
echo "Example manual fills:"
echo ""
echo "  For moveLoc K:"
echo "    have step_pcN : ... := by"
echo "      apply step_${OPERATION}_pcN o frameN cs stackN msN rfl rfl"
echo "        val_K"
echo "        (by simp [frameN]; omega)  -- prove K < locals.size"
echo "        hlocals_at_K               -- prove locals[K] = some val_K"
echo "        (by left; simp [frameN]; omega)  -- prove localRefs[K] = none"
echo ""
echo "  For immBorrowField F:"
echo "    have step_pcN : ... := by"
echo "      apply step_${OPERATION}_pcN o frameN cs stackN_rest msN rfl rfl"
echo "        rid fields containers' fid ref"
echo "        hRef                       -- getRefId ref = some rid"
echo "        hread                      -- containers.read rid = some (.struct_ fields)"
echo "        (by omega)                 -- F < fields.length"
echo "        halloc                     -- containers.alloc fields[F] = (containers', fid)"
echo ""
echo "See NORMALIZATION_PHASE6_COMPLETE_PROOF_IMPLEMENTATION.md for worked examples."
echo "-/"

# Generate summary statistics
echo ""
echo "/-! ## Generated Scaffold Statistics"
echo ""
echo "  PCs covered: $FUEL_NEEDED (PC $START_PC through PC $((END_PC - 1)))"

step_count=0
missing_count=0
for ((pc = START_PC; pc < END_PC; pc++)); do
    if grep -q "theorem step_${OPERATION}_pc${pc} " "$EVAL_EQUIV_FILE" 2>/dev/null; then
        ((step_count++)) || true
    else
        ((missing_count++)) || true
    fi
done

echo "  Step theorems found: $step_count / $FUEL_NEEDED"
echo "  Missing step theorems: $missing_count"
echo ""
echo "  Estimated completion effort:"
echo "    - If all step theorems exist: ~10-15 lines per PC = $((FUEL_NEEDED * 12)) lines"
echo "    - If step theorems missing: +20 lines per missing theorem = +$((missing_count * 20)) lines"
echo "    - Total: ~$((FUEL_NEEDED * 12 + missing_count * 20)) lines"
echo ""
echo "  Estimated time: $(((FUEL_NEEDED * 12 + missing_count * 20) / 60)) hours (at 60 lines/hour)"
echo "-/"

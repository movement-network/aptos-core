#!/usr/bin/env bash
# extract_stack_evolution.sh — Generate stack evolution table from step theorems
#
# Analyzes the step theorem signatures in an EvalEquiv.lean file to extract
# the stack state at each PC. Produces a markdown table showing:
# - PC number
# - Instruction type
# - Stack input pattern (from theorem parameters)
# - Stack output pattern (from .ok result)
#
# Usage:
#   ./extract_stack_evolution.sh <operation>
#
# Example:
#   ./extract_stack_evolution.sh normalization > NORMALIZATION_STACK_EVOLUTION.md
#   ./extract_stack_evolution.sh withdrawal > WITHDRAWAL_STACK_EVOLUTION.md

set -euo pipefail

OPERATION_LOWER="${1:-}"

if [[ -z "$OPERATION_LOWER" ]]; then
    echo "Usage: $0 <operation>" >&2
    echo "" >&2
    echo "Available operations:" >&2
    echo "  normalization, withdrawal, transfer, rotation" >&2
    exit 1
fi

# Convert to lowercase for theorem names (in case user passes capitalized)
OPERATION=$(echo "$OPERATION_LOWER" | tr '[:upper:]' '[:lower:]')

# Capitalize first letter for file path
OPERATION_CAP="$(tr '[:lower:]' '[:upper:]' <<< "${OPERATION:0:1}")${OPERATION:1}"

EVAL_FILE="lean/MovementFormal/Experimental/ConfidentialAsset/${OPERATION_CAP}/EvalEquiv.lean"

if [[ ! -f "$EVAL_FILE" ]]; then
    echo "Error: EvalEquiv file not found: $EVAL_FILE" >&2
    exit 1
fi

echo "# ${OPERATION_CAP} Stack Evolution Table"
echo ""
echo "Auto-generated from \`${EVAL_FILE}\`"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "## Stack State Per PC"
echo ""
echo "| PC | Instruction | Stack Input | Stack Output | Notes |"
echo "|----|-------------|-------------|--------------|-------|"

max_pc=30  # Upper bound for PC search

for pc in $(seq 0 $max_pc); do
    # Find the step theorem for this PC (theorem name may be followed by newline, underscore, or space)
    # Note: Use double quotes to allow $ as regex end-of-line, not variable interpolation
    if ! grep -qE "^theorem step_${OPERATION}_pc${pc}(_|$| )" "$EVAL_FILE" 2>/dev/null; then
        continue
    fi

    theorem_start=$(grep -nE "^theorem step_${OPERATION}_pc${pc}(_|$| )" "$EVAL_FILE" | head -1 | cut -d: -f1)

    # Extract 30 lines from theorem start (should cover signature + body start)
    theorem_block=$(sed -n "${theorem_start},$((theorem_start + 30))p" "$EVAL_FILE")

    # Extract instruction type from bytecode access lemma
    instr=$(grep "private theorem code_pc${pc} " "$EVAL_FILE" -A 1 | tail -1 | \
            sed 's/.*= \.//' | sed 's/ .*//' | sed 's/\]$//' || echo "unknown")

    # Extract stack input pattern from theorem parameters
    # Look for lines like: "(stack : List MoveValue)" or "(rest : List MoveValue)"
    stack_in_line=$(echo "$theorem_block" | grep -E "^\s+\(.*stack.*:" | head -1 || echo "")

    if echo "$stack_in_line" | grep -q "rest"; then
        # Pattern: (ref :: rest) or similar
        stack_in="(specific pattern)"
    elif echo "$stack_in_line" | grep -q "stack"; then
        stack_in="(generic)"
    else
        stack_in="(empty or implicit)"
    fi

    # Extract stack output from .ok constructor
    # Look for: ".ok { frame with ... } cs (STACK_EXPR) ms"
    ok_line=$(echo "$theorem_block" | grep -E "^\s+\.ok " | head -1 || echo "")

    if [[ -n "$ok_line" ]]; then
        # Extract the stack expression between "cs (" and ") ms"
        stack_out=$(echo "$ok_line" | sed -n 's/.*cs (\(.*\)) ms.*/\1/p' || echo "(complex)")

        # If extraction failed, try alternate pattern: "cs STACK ms"
        if [[ "$stack_out" == "(complex)" ]]; then
            stack_out=$(echo "$ok_line" | sed -n 's/.*cs \([^ ]*\) ms.*/\1/p' || echo "(see code)")
        fi
    else
        # Might be an error case (.error) or return case (.returned)
        if echo "$theorem_block" | grep -q "= \.error"; then
            stack_out="ERROR"
        elif echo "$theorem_block" | grep -q "= \.returned"; then
            stack_out="RETURNED"
        else
            stack_out="(unknown)"
        fi
    fi

    # Extract notes from docstring or comments
    notes=""

    # Check if this is an error variant (pc8_none, pc12_none pattern)
    if grep -q "theorem step_${OPERATION}_pc${pc}_none " "$EVAL_FILE" 2>/dev/null; then
        notes="Has error variant: pc${pc}_none"
    fi

    # Check if instruction is a native call
    if [[ "$instr" == "call" ]]; then
        # Extract which function is called
        call_idx=$(grep "code_pc${pc} " "$EVAL_FILE" -A 1 | tail -1 | sed 's/.*call //' | sed 's/).*//')
        notes="Native call ${call_idx}"
    fi

    # Truncate long stack expressions for readability
    if [[ ${#stack_in} -gt 40 ]]; then
        stack_in="${stack_in:0:37}..."
    fi
    if [[ ${#stack_out} -gt 40 ]]; then
        stack_out="${stack_out:0:37}..."
    fi

    echo "| $pc | \`$instr\` | $stack_in | $stack_out | $notes |"
done

echo ""
echo "## Detailed Theorem Signatures"
echo ""
echo "For exact type signatures, see the step theorems in \`${EVAL_FILE}\`."
echo ""

# Count total PCs covered
pc_count=$(grep -c "theorem step_${OPERATION}_pc[0-9]" "$EVAL_FILE" || echo 0)
echo "**Total step theorems:** $pc_count"

# Count error variants
error_count=$(grep -c "theorem step_${OPERATION}_pc[0-9].*_none " "$EVAL_FILE" || echo 0)
echo "**Error variants:** $error_count"

# Check for shape lemmas
if grep -q "verifyResult.*_success" "$EVAL_FILE"; then
    echo "**Shape lemmas:** present (success, error cases)"
fi

echo ""
echo "---"
echo ""
echo "## Usage in Phase 6 Proofs"
echo ""
echo "Use this table to:"
echo "1. Verify stack state assumptions in PC-chaining proofs"
echo "2. Identify which PCs mutate locals vs stack"
echo "3. Plan fuel decomposition (each PC consumes 1 fuel)"
echo "4. Track container allocations (immBorrowField PCs)"
echo ""
echo "Example:"
echo '```lean'
echo "-- At PC N, stack should match the 'Stack Output' column from PC (N-1)"
echo "set stackN := [...values from table...]"
echo ""
echo "have step_pcN : step env frameN cs stackN ms ="
echo "    .ok frameN' cs stackN' ms' := by"
echo "  apply step_${OPERATION}_pcN ... "
echo '```'

#!/usr/bin/env bash
# Generate comprehensive test matrix for CA verification
set -euo pipefail

cd "$(dirname "$0")/.."
FORMAL_DIR="$(pwd)"

echo "=== Confidential Assets Verification Test Matrix ==="
echo ""
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Test categories
echo "## Test Coverage Matrix"
echo ""
echo "| Operation | Step Theorems | Eval↔Run | Build Status |"
echo "|-----------|---------------|----------|--------------|"

# Function to count theorems in a file
count_theorems() {
    local file=$1
    grep -c "^theorem" "$file" 2>/dev/null || echo "0"
}

# Test each operation
for op in Normalization Withdrawal Transfer Rotation; do
    eval_file="lean/MovementFormal/Experimental/ConfidentialAsset/$op/EvalEquiv.lean"

    if [ -f "$eval_file" ]; then
        step_count=$(count_theorems "$eval_file")

        # Check for eval_eq_run theorem
        if grep -q "theorem eval_.*_eq_run" "$eval_file"; then
            eval_run="✅"
        else
            eval_run="❌"
        fi

        # Quick build check
        if cd lean && timeout 10s lake build "MovementFormal.Experimental.ConfidentialAsset.$op.EvalEquiv" &>/dev/null; then
            build_status="✅"
        else
            build_status="⚠️"
        fi
        cd "$FORMAL_DIR"

        echo "| $op | $step_count theorems | $eval_run | $build_status |"
    fi
done

echo ""
echo "## Sorry Distribution"
echo ""

total_sorries=0
for op in Normalization Withdrawal Transfer Rotation; do
    sorry_count=$(grep "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/$op/*.lean 2>/dev/null | wc -l | tr -d ' ')
    echo "$op: $sorry_count sorries"
    total_sorries=$((total_sorries + sorry_count))
done
echo "**Total: $total_sorries sorries**"

echo ""
echo "## Validation Status"
echo ""
./scripts/validate_sorry_inventory.sh 2>&1 | grep -E "✅|❌" | head -1

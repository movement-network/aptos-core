#!/usr/bin/env bash
# Validate that SORRY_CATEGORIZATION.md matches actual sorry count
set -euo pipefail

cd "$(dirname "$0")/.."
FORMAL_DIR="$(pwd)"

echo "=== Sorry Inventory Validation ==="
echo ""

# Count actual sorries (excluding comments)
actual_norm=$(grep -n "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/*.lean 2>/dev/null | wc -l | tr -d ' ')
actual_with=$(grep -n "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/*.lean 2>/dev/null | wc -l | tr -d ' ')
actual_rot=$(grep -n "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/*.lean 2>/dev/null | wc -l | tr -d ' ')
actual_trans=$(grep -n "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/*.lean 2>/dev/null | wc -l | tr -d ' ')
actual_total=$((actual_norm + actual_with + actual_rot + actual_trans))

# Expected counts from SORRY_CATEGORIZATION.md
expected_norm=3
expected_with=5
expected_rot=1
expected_trans=2
expected_total=11

echo "Normalization: $actual_norm (expected $expected_norm)"
echo "Withdrawal:    $actual_with (expected $expected_with)"
echo "Rotation:      $actual_rot (expected $expected_rot)"
echo "Transfer:      $actual_trans (expected $expected_trans)"
echo "Total:         $actual_total (expected $expected_total)"
echo ""

# Validate
if [ "$actual_norm" != "$expected_norm" ]; then
    echo "❌ Normalization count mismatch!"
    exit 1
fi

if [ "$actual_with" != "$expected_with" ]; then
    echo "❌ Withdrawal count mismatch!"
    exit 1
fi

if [ "$actual_rot" != "$expected_rot" ]; then
    echo "❌ Rotation count mismatch!"
    exit 1
fi

if [ "$actual_trans" != "$expected_trans" ]; then
    echo "❌ Transfer count mismatch!"
    exit 1
fi

echo "✅ All counts match SORRY_CATEGORIZATION.md"
echo ""

# List all sorry locations for cross-reference
echo "=== Detailed Sorry Locations ==="
echo ""
echo "## Normalization"
grep -n "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/*.lean 2>/dev/null || true
echo ""
echo "## Withdrawal"
grep -n "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/*.lean 2>/dev/null || true
echo ""
echo "## Rotation"
grep -n "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/*.lean 2>/dev/null || true
echo ""
echo "## Transfer"
grep -n "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/*.lean 2>/dev/null || true

echo ""
echo "✅ Validation complete"

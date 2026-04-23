#!/usr/bin/env bash
# Analyze all sorry placeholders and categorize by blocker type
set -euo pipefail

FORMAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FORMAL_DIR/lean"

echo "=== Sorry Analysis for Confidential Assets ==="
echo ""

# Find all sorries
SORRIES=$(grep -rn "sorry" MovementFormal/Experimental/ConfidentialAsset --include="*.lean" | grep -v "^--" || true)

if [ -z "$SORRIES" ]; then
    echo "✓ NO SORRIES FOUND - Phase 6 complete!"
    exit 0
fi

# Count by operation
echo "## Count by Operation"
echo ""
for op in Registration Normalization Withdrawal Transfer Rotation; do
    count=$(echo "$SORRIES" | grep "$op" | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        echo "$op: $count sorries"
    fi
done

echo ""
echo "## Blocker Categories"
echo ""

# Array elaboration blockers
array_count=$(echo "$SORRIES" | grep -i "array\|elaboration\|free variable" | wc -l | tr -d ' ')
echo "Array elaboration: $array_count"

# PC-chaining blockers
chain_count=$(echo "$SORRIES" | grep -i "PC.*chain\|15-PC\|24-PC" | wc -l | tr -d ' ')
echo "PC-chaining: $chain_count"

# Match simplification
match_count=$(echo "$SORRIES" | grep -i "match.*tree\|simplify.*match" | wc -l | tr -d ' ')
echo "Match simplification: $match_count"

# Proof irrelevance
irrel_count=$(echo "$SORRIES" | grep -i "proof.*irrelevance\|proof.*irrel" | wc -l | tr -d ' ')
echo "Proof irrelevance: $irrel_count"

# Unreachable
unreach_count=$(echo "$SORRIES" | grep -i "unreachable\|impossible" | wc -l | tr -d ' ')
echo "Unreachable cases: $unreach_count"

echo ""
echo "## Total: $(echo "$SORRIES" | wc -l | tr -d ' ') sorries"
echo ""
echo "## Details"
echo "$SORRIES" | head -20

#!/usr/bin/env bash
# Quick sorry counter for Confidential Assets (counts declarations, not occurrences)
#
# Uses grep to find sorry statements, then counts unique line numbers per file
# to approximate declaration count. For exact count, use: lake build 2>&1 | grep "declaration uses 'sorry'"
set -euo pipefail

FORMAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FORMAL_DIR/lean"

echo "=== Sorry Analysis for Confidential Assets ==="
echo ""

# Count by operation using grep, but deduplicate nearby sorries (likely same declaration)
echo "## Count by Operation (approximation)"
echo ""
TOTAL=0
for op in Registration Normalization Withdrawal Transfer Rotation; do
    # Find sorry lines, extract line numbers, count unique declarations
    # (assumes sorries within 50 lines are part of same declaration)
    FILES=$(find MovementFormal/Experimental/ConfidentialAsset/$op -name "*.lean" 2>/dev/null || true)
    if [ -z "$FILES" ]; then
        continue
    fi

    count=0
    for file in $FILES; do
        sorry_lines=$(grep -n "sorry$" "$file" 2>/dev/null | cut -d: -f1 || echo "")
        if [ -n "$sorry_lines" ]; then
            # Count as separate declarations if >50 lines apart
            file_count=1
            prev=0
            for line in $sorry_lines; do
                if [ $((line - prev)) -gt 50 ]; then
                    file_count=$((file_count + 1))
                fi
                prev=$line
            done
            count=$((count + file_count - 1))
        fi
    done

    if [ "$count" -gt 0 ]; then
        echo "$op: ~$count declarations"
        TOTAL=$((TOTAL + count))
    fi
done

echo ""
echo "**ESTIMATED TOTAL: ~$TOTAL declarations with sorry**"
echo ""
echo "Note: This is an approximation. For exact count, run:"
echo "  lake build MovementFormal.Experimental.ConfidentialAsset 2>&1 | grep \"declaration uses 'sorry'\" | wc -l"
echo ""
echo "See audit/SORRY_CATEGORIZATION.md for detailed blocker analysis."

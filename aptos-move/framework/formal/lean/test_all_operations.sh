#!/usr/bin/env bash
# Complete test suite for all CA operations across all stacks
set -euo pipefail

cd "$(dirname "$0")/.."
PASS=0
FAIL=0

test_op() {
    local op=$1
    local stack=$2
    echo -n "Testing $op ($stack)... "
    if ./audit/verify-ca.sh --op "$op" --stack "$stack" &>/dev/null; then
        echo "✓"
        ((PASS++))
    else
        echo "✗"
        ((FAIL++))
    fi
}

echo "=== Lean Stack Tests ==="
for op in register normalize withdraw transfer rotate; do
    test_op "$op" "lean"
done

echo ""
echo "=== Move Prover Stack Tests ==="
for op in register normalize withdraw transfer rotate; do
    test_op "$op" "move-prover"
done

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
[ $FAIL -eq 0 ] && echo "✓ ALL TESTS PASSED" || echo "✗ SOME TESTS FAILED"
exit $FAIL

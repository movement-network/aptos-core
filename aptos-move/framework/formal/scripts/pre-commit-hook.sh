#!/usr/bin/env bash
# scripts/pre-commit-hook.sh — Pre-commit verification checks
#
# Catches common verification issues before commit. Install with:
#   ln -s ../../aptos-move/framework/formal/scripts/pre-commit-hook.sh .git/hooks/pre-commit
#
# Checks:
#   1. No new sorry in Lean files
#   2. No new axioms without documentation
#   3. Lean builds successfully
#   4. Trust boundaries reconcile
#   5. No verification escapes added
#
# Skip with: git commit --no-verify

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Running pre-commit verification checks..."

# Find formal root
if [ -d "aptos-move/framework/formal" ]; then
    FORMAL_ROOT="aptos-move/framework/formal"
elif [ -d "formal" ]; then
    FORMAL_ROOT="formal"
else
    echo -e "${YELLOW}⚠️  Not in CA formal verification repo, skipping checks${NC}"
    exit 0
fi

cd "$FORMAL_ROOT"

FAILED=0

# Check 1: No new sorry
echo -n "Checking for sorry... "
SORRY_COUNT=$(git diff --cached --diff-filter=ACMRTUXB -- 'lean/**/*.lean' | grep -c "^+.*sorry" || echo 0)
if [ "$SORRY_COUNT" -gt 0 ]; then
    echo -e "${RED}❌ FAIL${NC}"
    echo "  Found $SORRY_COUNT new sorry placeholders in staged changes"
    echo "  Complete proofs before committing or use --no-verify to override"
    FAILED=1
else
    echo -e "${GREEN}✅ PASS${NC}"
fi

# Check 2: No new axioms without documentation
echo -n "Checking for undocumented axioms... "
NEW_AXIOMS=$(git diff --cached --diff-filter=ACMRTUXB -- 'lean/**/*.lean' | grep -c "^+.*axiom " || echo 0)
if [ "$NEW_AXIOMS" -gt 0 ]; then
    # Check if AXIOM_INVENTORY.md also updated
    if git diff --cached --name-only | grep -q "audit/AXIOM_INVENTORY.md"; then
        echo -e "${GREEN}✅ PASS${NC} (AXIOM_INVENTORY.md updated)"
    else
        echo -e "${RED}❌ FAIL${NC}"
        echo "  Found $NEW_AXIOMS new axiom(s) but AXIOM_INVENTORY.md not updated"
        echo "  Add rationale to audit/AXIOM_INVENTORY.md or use --no-verify"
        FAILED=1
    fi
else
    echo -e "${GREEN}✅ PASS${NC}"
fi

# Check 3: Lean builds (quick check on modified files only)
echo -n "Checking Lean builds... "
MODIFIED_LEAN=$(git diff --cached --name-only --diff-filter=ACMRTUXB -- 'lean/**/*.lean' | head -1)
if [ -n "$MODIFIED_LEAN" ]; then
    cd lean
    if lake build > /tmp/pre-commit-lean.log 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
        echo "  Lean build failed (see /tmp/pre-commit-lean.log)"
        echo "  Fix errors before committing or use --no-verify"
        FAILED=1
    fi
    cd ..
else
    echo -e "${GREEN}✅ SKIP${NC} (no Lean files modified)"
fi

# Check 4: Trust boundaries reconcile (if TRUST_BOUNDARIES.md modified)
if git diff --cached --name-only | grep -q "audit/TRUST_BOUNDARIES.md"; then
    echo -n "Checking trust boundaries... "
    if ./scripts/reconcile_trust_boundaries.sh > /tmp/pre-commit-trust.log 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${YELLOW}⚠️  WARNING${NC}"
        echo "  Trust boundaries may be out of sync (see /tmp/pre-commit-trust.log)"
        echo "  Run: ./scripts/reconcile_trust_boundaries.sh"
        # Don't fail, just warn
    fi
fi

# Check 5: No new verification escapes
echo -n "Checking for verification escapes... "
NEW_ESCAPES=$(git diff --cached --diff-filter=ACMRTUXB -- '**/*.spec.move' | grep -cE "^\+.*pragma (verify = false|deactivated_proof|aborts_if_is_partial)" || echo 0)
if [ "$NEW_ESCAPES" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    echo "  Found $NEW_ESCAPES new verification escape(s)"
    echo "  Document in TRUST_BOUNDARIES.md if intentional"
    # Don't fail, just warn
else
    echo -e "${GREEN}✅ PASS${NC}"
fi

# Summary
echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All pre-commit checks passed${NC}"
    exit 0
else
    echo -e "${RED}❌ Some checks failed${NC}"
    echo ""
    echo "Fix issues above or bypass with: git commit --no-verify"
    exit 1
fi

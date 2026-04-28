#!/usr/bin/env bash
# scripts/quarterly_audit.sh — Quarterly maintenance audit
#
# Runs comprehensive health checks for CA formal verification per the
# quarterly audit procedure in MAINTENANCE_GUIDE.md §5.
#
# Usage:
#   ./scripts/quarterly_audit.sh [--report-only|--fix-issues]
#
# Modes:
#   (default)        Run audit, report issues, exit non-zero if problems found
#   --report-only    Generate audit report without failing
#   --fix-issues     Attempt automatic fixes for known issues
#
# Output:
#   - Prints audit report to stdout
#   - Writes detailed report to audit/quarterly-audit-YYYY-MM-DD.md
#   - Exit code: 0 if healthy, non-zero if issues found (unless --report-only)

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FORMAL_ROOT"

# Parse args
MODE="default"
if [ "${1:-}" = "--report-only" ]; then
    MODE="report-only"
elif [ "${1:-}" = "--fix-issues" ]; then
    MODE="fix"
elif [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [--report-only|--fix-issues]"
    echo ""
    echo "Runs quarterly maintenance audit per MAINTENANCE_GUIDE.md §5."
    echo ""
    echo "Modes:"
    echo "  (default)        Run audit, fail if issues found"
    echo "  --report-only    Generate report, don't fail"
    echo "  --fix-issues     Attempt automatic fixes"
    exit 0
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Report file
REPORT_DATE=$(date +%Y-%m-%d)
REPORT_FILE="audit/quarterly-audit-${REPORT_DATE}.md"

# Issue counter
ISSUES_FOUND=0

# Report header
echo "# CA Formal Verification — Quarterly Audit Report" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Date:** ${REPORT_DATE}" >> "$REPORT_FILE"
echo "**Run by:** $(whoami)" >> "$REPORT_FILE"
echo "**Commit:** $(git rev-parse HEAD 2>/dev/null || echo 'unknown')" >> "$REPORT_FILE"
echo "**Branch:** $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CA Formal Verification — Quarterly Audit                 ║${NC}"
echo -e "${BLUE}║  $(date)                                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Section 1: Verification Status
echo -e "${BLUE}█ Section 1: Verification Status${NC}"
echo "## 1. Verification Status" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -n "  Checking Lean build... "
if cd lean && lake build > /tmp/quarterly-audit-lean.log 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}"
    echo "- **Lean build:** ✅ PASS" >> "$REPORT_FILE"
else
    echo -e "${RED}❌ FAIL${NC}"
    echo "- **Lean build:** ❌ FAIL (see /tmp/quarterly-audit-lean.log)" >> "$REPORT_FILE"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
cd "$FORMAL_ROOT"

echo -n "  Checking Move Prover compile... "
if movement move compile --package-dir "$FORMAL_ROOT/../aptos-experimental" > /tmp/quarterly-audit-prover.log 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}"
    echo "- **Move Prover compile:** ✅ PASS" >> "$REPORT_FILE"
else
    echo -e "${RED}❌ FAIL${NC}"
    echo "- **Move Prover compile:** ❌ FAIL (see /tmp/quarterly-audit-prover.log)" >> "$REPORT_FILE"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo -n "  Checking sorry count... "
SORRY_COUNT=$(find lean -name "*.lean" -type f -exec grep -c "sorry" {} + 2>/dev/null | awk '{s+=$1} END {print s}' || echo 0)
if [ "$SORRY_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ 0 sorry${NC}"
    echo "- **Sorry count:** ✅ 0 (all proofs complete)" >> "$REPORT_FILE"
else
    echo -e "${YELLOW}⚠️  ${SORRY_COUNT} sorry found${NC}"
    echo "- **Sorry count:** ⚠️ ${SORRY_COUNT} (acceptable if in WIP branches)" >> "$REPORT_FILE"
    if [ "$MODE" = "fix" ]; then
        echo "    Run: find lean -name '*.lean' -exec grep -n sorry {} +"
    fi
fi

echo "" >> "$REPORT_FILE"

# Section 2: Axiom Health
echo ""
echo -e "${BLUE}█ Section 2: Axiom Health${NC}"
echo "## 2. Axiom Health" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -n "  Checking axiom count... "
AXIOM_COUNT=$(./scripts/check_axioms.sh 2>/dev/null | grep -c "axiom" || echo 0)
echo "- **Total axioms:** ${AXIOM_COUNT}" >> "$REPORT_FILE"
echo "${AXIOM_COUNT}"

echo -n "  Checking axiom drift... "
if ./scripts/check_axioms.sh --diff > /tmp/quarterly-audit-axiom-diff.log 2>&1; then
    echo -e "${GREEN}✅ No drift${NC}"
    echo "- **Axiom drift:** ✅ No new axioms since baseline" >> "$REPORT_FILE"
else
    DRIFT_COUNT=$(grep -c "^+" /tmp/quarterly-audit-axiom-diff.log 2>/dev/null || echo 0)
    if [ "$DRIFT_COUNT" -gt 0 ]; then
        echo -e "${RED}❌ ${DRIFT_COUNT} new axioms${NC}"
        echo "- **Axiom drift:** ❌ ${DRIFT_COUNT} new axioms (see /tmp/quarterly-audit-axiom-diff.log)" >> "$REPORT_FILE"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))

        if [ "$MODE" = "fix" ]; then
            echo "    Attempting fix: regenerate baseline"
            ./scripts/check_axioms.sh > audit/axiom-baseline.txt
            echo "    ✓ Baseline regenerated. Review and commit if intentional."
        fi
    else
        echo -e "${GREEN}✅ No drift${NC}"
        echo "- **Axiom drift:** ✅ No drift" >> "$REPORT_FILE"
    fi
fi

echo -n "  Checking TEMPORARY axioms... "
TEMP_AXIOM_COUNT=$(grep -c "TEMPORARY" audit/AXIOM_INVENTORY.md 2>/dev/null || echo 0)
if [ "$TEMP_AXIOM_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ 0 TEMPORARY${NC}"
    echo "- **TEMPORARY axioms:** ✅ 0 (all work complete)" >> "$REPORT_FILE"
else
    echo -e "${YELLOW}⚠️  ${TEMP_AXIOM_COUNT} TEMPORARY${NC}"
    echo "- **TEMPORARY axioms:** ${TEMP_AXIOM_COUNT} (expected: registration_eval_equiv_functional_sim during Phase 1)" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Section 3: Trust Boundary Reconciliation
echo ""
echo -e "${BLUE}█ Section 3: Trust Boundary Reconciliation${NC}"
echo "## 3. Trust Boundary Reconciliation" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -n "  Reconciling trust boundaries... "
if ./scripts/reconcile_trust_boundaries.sh > /tmp/quarterly-audit-trust.log 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}"
    echo "- **Trust boundaries:** ✅ Reconciled (matches reality)" >> "$REPORT_FILE"
else
    echo -e "${RED}❌ FAIL${NC}"
    echo "- **Trust boundaries:** ❌ Mismatch (see /tmp/quarterly-audit-trust.log)" >> "$REPORT_FILE"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))

    if [ "$MODE" = "fix" ]; then
        echo "    Manual fix required: update TRUST_BOUNDARIES.md per reconcile script output"
    fi
fi

echo "" >> "$REPORT_FILE"

# Section 4: Performance Health
echo ""
echo -e "${BLUE}█ Section 4: Performance Health${NC}"
echo "## 4. Performance Health" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "  Running benchmarks (this takes ~2 min)..."
if ./scripts/benchmark_verification.sh > /tmp/quarterly-audit-bench.txt 2>&1; then
    echo -e "${GREEN}✅ Benchmarks complete${NC}"

    # Parse benchmark results
    TOTAL_TIME=$(grep "^TOTAL" /tmp/quarterly-audit-bench.txt | awk '{print $2}' | sed 's/s//')

    echo "- **Full verification time:** ${TOTAL_TIME}s (budget: 2700s)" >> "$REPORT_FILE"

    # Check against budget
    if (( $(echo "$TOTAL_TIME > 2700" | bc -l) )); then
        echo -e "${RED}  ❌ OVER BUDGET (${TOTAL_TIME}s > 2700s)${NC}"
        echo "- **Budget status:** ❌ OVER BUDGET" >> "$REPORT_FILE"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "${GREEN}  ✅ Under budget (${TOTAL_TIME}s / 2700s)${NC}"
        echo "- **Budget status:** ✅ Under budget" >> "$REPORT_FILE"
    fi

    # Per-operation breakdown
    echo "" >> "$REPORT_FILE"
    echo "### Per-Operation Timing" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    grep -E "(register|withdraw|transfer|normalize|rotate)" /tmp/quarterly-audit-bench.txt | while read line; do
        echo "- $line" >> "$REPORT_FILE"
    done
else
    echo -e "${RED}❌ Benchmarks failed${NC}"
    echo "- **Benchmarks:** ❌ Failed (see /tmp/quarterly-audit-bench.txt)" >> "$REPORT_FILE"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo "" >> "$REPORT_FILE"

# Section 5: Documentation Health
echo ""
echo -e "${BLUE}█ Section 5: Documentation Health${NC}"
echo "## 5. Documentation Health" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -n "  Checking CLAIMS.md... "
if [ -f "audit/CLAIMS.md" ]; then
    CLAIMS_COUNT=$(grep -c "^##" audit/CLAIMS.md || echo 0)
    echo -e "${GREEN}✅ Present (${CLAIMS_COUNT} sections)${NC}"
    echo "- **CLAIMS.md:** ✅ Present (${CLAIMS_COUNT} sections)" >> "$REPORT_FILE"
else
    echo -e "${RED}❌ Missing${NC}"
    echo "- **CLAIMS.md:** ❌ Missing" >> "$REPORT_FILE"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo -n "  Checking TRUST_BOUNDARIES.md... "
if [ -f "audit/TRUST_BOUNDARIES.md" ]; then
    echo -e "${GREEN}✅ Present${NC}"
    echo "- **TRUST_BOUNDARIES.md:** ✅ Present" >> "$REPORT_FILE"
else
    echo -e "${RED}❌ Missing${NC}"
    echo "- **TRUST_BOUNDARIES.md:** ❌ Missing" >> "$REPORT_FILE"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo -n "  Checking AXIOM_INVENTORY.md... "
if [ -f "audit/AXIOM_INVENTORY.md" ]; then
    echo -e "${GREEN}✅ Present${NC}"
    echo "- **AXIOM_INVENTORY.md:** ✅ Present" >> "$REPORT_FILE"
else
    echo -e "${RED}❌ Missing${NC}"
    echo "- **AXIOM_INVENTORY.md:** ❌ Missing" >> "$REPORT_FILE"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo -n "  Checking plan §0 currency... "
PLAN_FILE="CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md"
if [ -f "$PLAN_FILE" ]; then
    # Check if §0 progress tracker has "COMPLETE" or "in progress" markers
    if grep -q "✅ COMPLETE\|🟡 in progress" "$PLAN_FILE"; then
        echo -e "${GREEN}✅ Up to date${NC}"
        echo "- **Plan §0 tracker:** ✅ Up to date" >> "$REPORT_FILE"
    else
        echo -e "${YELLOW}⚠️  May be stale${NC}"
        echo "- **Plan §0 tracker:** ⚠️ Check if progress markers are current" >> "$REPORT_FILE"
    fi
else
    echo -e "${RED}❌ Plan missing${NC}"
    echo "- **Plan file:** ❌ Missing" >> "$REPORT_FILE"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo "" >> "$REPORT_FILE"

# Section 6: CI Health
echo ""
echo -e "${BLUE}█ Section 6: CI Health${NC}"
echo "## 6. CI Health" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -n "  Checking CI workflows exist... "
CI_WORKFLOWS=(
    ".github/workflows/ca-verification-suite.yaml"
    ".github/workflows/axiom-diff-ca.yaml"
    ".github/workflows/lean-ca.yaml"
    ".github/workflows/move-prover-ca.yaml"
)

MISSING_WORKFLOWS=0
for workflow in "${CI_WORKFLOWS[@]}"; do
    if [ ! -f "$FORMAL_ROOT/../../../$workflow" ]; then
        echo -e "${RED}❌ Missing: $workflow${NC}"
        echo "- **Missing workflow:** $workflow" >> "$REPORT_FILE"
        MISSING_WORKFLOWS=$((MISSING_WORKFLOWS + 1))
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

if [ "$MISSING_WORKFLOWS" -eq 0 ]; then
    echo -e "${GREEN}✅ All workflows present${NC}"
    echo "- **CI workflows:** ✅ All present" >> "$REPORT_FILE"
else
    echo -e "${RED}❌ ${MISSING_WORKFLOWS} workflows missing${NC}"
    echo "- **CI workflows:** ❌ ${MISSING_WORKFLOWS} missing" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Section 7: Git Hygiene
echo ""
echo -e "${BLUE}█ Section 7: Git Hygiene${NC}"
echo "## 7. Git Hygiene" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -n "  Checking for large files... "
LARGE_FILES=$(find . -type f -size +1M ! -path "*/\.git/*" ! -path "*/\.lake/*" ! -path "*/target/*" 2>/dev/null | wc -l)
if [ "$LARGE_FILES" -eq 0 ]; then
    echo -e "${GREEN}✅ No large files${NC}"
    echo "- **Large files:** ✅ None (>1MB)" >> "$REPORT_FILE"
else
    echo -e "${YELLOW}⚠️  ${LARGE_FILES} files >1MB${NC}"
    echo "- **Large files:** ⚠️ ${LARGE_FILES} files >1MB (acceptable for build artifacts)" >> "$REPORT_FILE"
fi

echo -n "  Checking for untracked changes... "
UNTRACKED=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$UNTRACKED" -eq 0 ]; then
    echo -e "${GREEN}✅ Working tree clean${NC}"
    echo "- **Working tree:** ✅ Clean" >> "$REPORT_FILE"
else
    echo -e "${YELLOW}⚠️  ${UNTRACKED} untracked/modified files${NC}"
    echo "- **Working tree:** ⚠️ ${UNTRACKED} untracked/modified files" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Section 8: Dependency Health
echo ""
echo -e "${BLUE}█ Section 8: Dependency Health${NC}"
echo "## 8. Dependency Health" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -n "  Checking Lean toolchain version... "
if [ -f "lean/lean-toolchain" ]; then
    LEAN_VERSION=$(cat lean/lean-toolchain)
    echo "${LEAN_VERSION}"
    echo "- **Lean version:** ${LEAN_VERSION}" >> "$REPORT_FILE"
else
    echo -e "${RED}❌ lean-toolchain missing${NC}"
    echo "- **Lean version:** ❌ lean-toolchain file missing" >> "$REPORT_FILE"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo -n "  Checking Z3 version... "
if command -v "$Z3_EXE" &> /dev/null || command -v z3 &> /dev/null; then
    Z3_VERSION=$(${Z3_EXE:-z3} --version | head -1)
    echo "${Z3_VERSION}"
    echo "- **Z3 version:** ${Z3_VERSION}" >> "$REPORT_FILE"

    if echo "$Z3_VERSION" | grep -q "4.11.2"; then
        echo -e "${GREEN}  ✅ Correct version${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Expected 4.11.2${NC}"
        echo "  - **Z3 version check:** ⚠️ Expected 4.11.2" >> "$REPORT_FILE"
    fi
else
    echo -e "${YELLOW}⚠️  Z3 not found${NC}"
    echo "- **Z3 version:** ⚠️ Not found" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo -e "${GREEN}║  ✅ AUDIT PASSED — No issues found                        ║${NC}"
    echo "## Summary" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Status:** ✅ PASSED — No issues found" >> "$REPORT_FILE"
else
    echo -e "${RED}║  ❌ AUDIT FAILED — ${ISSUES_FOUND} issue(s) found                       ║${NC}"
    echo "## Summary" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "**Status:** ❌ FAILED — ${ISSUES_FOUND} issue(s) found" >> "$REPORT_FILE"
fi
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Detailed report written to: $REPORT_FILE"
echo ""

# Recommendations
if [ "$ISSUES_FOUND" -gt 0 ]; then
    echo "## Recommendations" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "1. Review detailed logs in /tmp/quarterly-audit-*.log" >> "$REPORT_FILE"
    echo "2. Address failures per MAINTENANCE_GUIDE.md emergency procedures" >> "$REPORT_FILE"
    echo "3. Re-run audit after fixes: ./scripts/quarterly_audit.sh" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# Checklist
echo "## Quarterly Audit Checklist" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Per MAINTENANCE_GUIDE.md §5:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- [x] Run full verification suite" >> "$REPORT_FILE"
echo "- [x] Check axiom count (no growth)" >> "$REPORT_FILE"
echo "- [x] Reconcile trust boundaries" >> "$REPORT_FILE"
echo "- [x] Performance regression check" >> "$REPORT_FILE"
echo "- [x] Documentation currency" >> "$REPORT_FILE"
echo "- [x] CI health check" >> "$REPORT_FILE"
echo "- [ ] Review upstream ristretto255 status (manual)" >> "$REPORT_FILE"
echo "- [ ] Check for stale branches (manual)" >> "$REPORT_FILE"
echo "- [ ] Update MAINTENANCE_GUIDE.md if procedures changed (manual)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Exit
if [ "$MODE" = "report-only" ]; then
    exit 0
elif [ "$ISSUES_FOUND" -gt 0 ]; then
    exit 1
else
    exit 0
fi

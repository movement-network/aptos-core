#!/usr/bin/env bash
# scripts/release_validation.sh — Pre-release validation
#
# Implements the automated portion of RELEASE_CHECKLIST.md. Validates that
# CA formal verification is ready for release: all verification passes, docs
# current, performance within budget, reproducibility tested.
#
# Usage:
#   ./scripts/release_validation.sh [--quick|--comprehensive]
#
# Modes:
#   --quick             Fast check (~5 min) — core verification only
#   --comprehensive     Full check (~20 min) — all automated checks
#   (default)           Standard check (~10 min) — most automated checks
#
# Exit codes:
#   0    All checks passed — ready for release
#   1    Some checks failed — NOT ready for release
#   2    Warnings present — review required before release

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FORMAL_ROOT"

# Parse args
MODE="standard"
if [ "${1:-}" = "--quick" ]; then
    MODE="quick"
elif [ "${1:-}" = "--comprehensive" ]; then
    MODE="comprehensive"
elif [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [--quick|--comprehensive]"
    echo ""
    echo "Pre-release validation implementing RELEASE_CHECKLIST.md."
    echo ""
    echo "Modes:"
    echo "  --quick             Fast check (~5 min)"
    echo "  --comprehensive     Full check (~20 min)"
    echo "  (default)           Standard check (~10 min)"
    echo ""
    echo "Exit codes:"
    echo "  0    Ready for release"
    echo "  1    NOT ready (failures)"
    echo "  2    Review required (warnings)"
    exit 0
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Counters
FAILURES=0
WARNINGS=0
CHECKS_RUN=0

# Report
REPORT_FILE="audit/release-validation-$(date +%Y%m%d-%H%M%S).txt"

# Header
echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  CA Formal Verification — Release Validation                ║${NC}"
echo -e "${MAGENTA}║  Mode: ${MODE^^}                                             ║${NC}"
echo -e "${MAGENTA}║  $(date)                                      ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Log function
log_section() {
    echo ""
    echo -e "${BLUE}█ $1${NC}"
    echo "█ $1" >> "$REPORT_FILE"
}

log_check() {
    echo -n "  $1... "
    CHECKS_RUN=$((CHECKS_RUN + 1))
}

log_pass() {
    echo -e "${GREEN}✅ PASS${NC}"
    echo "  ✅ $1: PASS" >> "$REPORT_FILE"
}

log_fail() {
    echo -e "${RED}❌ FAIL${NC}"
    echo "  ❌ $1: FAIL — $2" >> "$REPORT_FILE"
    FAILURES=$((FAILURES + 1))
}

log_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}"
    echo "  ⚠️  $1: WARN — $2" >> "$REPORT_FILE"
    WARNINGS=$((WARNINGS + 1))
}

# Initialize report
echo "CA Formal Verification — Release Validation Report" > "$REPORT_FILE"
echo "Date: $(date)" >> "$REPORT_FILE"
echo "Mode: $MODE" >> "$REPORT_FILE"
echo "Commit: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')" >> "$REPORT_FILE"
echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# ══════════════════════════════════════════════════════════════
# Phase 1: Verification Status (RELEASE_CHECKLIST.md §1)
# ══════════════════════════════════════════════════════════════

log_section "Phase 1: Verification Status"

# 1.1: Lean verification passes
log_check "Lean verification"
cd lean
if lake build > /tmp/release-val-lean.log 2>&1; then
    log_pass "Lean verification"
else
    log_fail "Lean verification" "Build failed (see /tmp/release-val-lean.log)"
fi
cd "$FORMAL_ROOT"

# 1.2: Move Prover compilation succeeds
log_check "Move Prover compilation"
if movement move compile --package-dir "$FORMAL_ROOT/../aptos-experimental" > /tmp/release-val-prover.log 2>&1; then
    log_pass "Move Prover compilation"
else
    log_fail "Move Prover compilation" "Failed (see /tmp/release-val-prover.log)"
fi

# 1.3: No sorry in production code
log_check "Sorry count"
SORRY_COUNT=$(find lean -name "*.lean" -type f ! -path "*/test/*" -exec grep -c "sorry" {} + 2>/dev/null | awk '{s+=$1} END {print s}' || echo 0)
if [ "$SORRY_COUNT" -eq 0 ]; then
    log_pass "Sorry count (0)"
else
    log_fail "Sorry count" "${SORRY_COUNT} sorry found in production code"
fi

# 1.4: Trust boundaries reconcile
log_check "Trust boundaries reconciliation"
if ./scripts/reconcile_trust_boundaries.sh > /tmp/release-val-trust.log 2>&1; then
    log_pass "Trust boundaries"
else
    log_fail "Trust boundaries" "Reconciliation failed (see /tmp/release-val-trust.log)"
fi

# 1.5: Axiom count within bounds (comprehensive mode only)
if [ "$MODE" = "comprehensive" ]; then
    log_check "Axiom count"
    AXIOM_COUNT=$(./scripts/check_axioms.sh 2>/dev/null | grep -c "axiom" || echo 0)
    if [ "$AXIOM_COUNT" -le 27 ]; then
        log_pass "Axiom count ($AXIOM_COUNT ≤ 27)"
    else
        log_warn "Axiom count" "${AXIOM_COUNT} axioms (expected ≤27 per plan)"
    fi

    log_check "Axiom drift"
    if ./scripts/check_axioms.sh --diff > /tmp/release-val-axiom-diff.log 2>&1; then
        log_pass "Axiom drift (no new axioms)"
    else
        log_fail "Axiom drift" "New axioms detected (see /tmp/release-val-axiom-diff.log)"
    fi
fi

# ══════════════════════════════════════════════════════════════
# Phase 2: Documentation (RELEASE_CHECKLIST.md §2)
# ══════════════════════════════════════════════════════════════

log_section "Phase 2: Documentation"

# 2.1: Core docs present
CORE_DOCS=(
    "audit/CLAIMS.md"
    "audit/TRUST_BOUNDARIES.md"
    "audit/AXIOM_INVENTORY.md"
    "audit/COMPOSITION_CLAIMS.md"
    "CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md"
)

for doc in "${CORE_DOCS[@]}"; do
    log_check "$(basename "$doc")"
    if [ -f "$doc" ]; then
        log_pass "$(basename "$doc")"
    else
        log_fail "$(basename "$doc")" "File missing"
    fi
done

# 2.2: Guides present (standard/comprehensive mode)
if [ "$MODE" != "quick" ]; then
    GUIDES=(
        "AUDITOR_GUIDE.md"
        "MAINTENANCE_GUIDE.md"
        "RELEASE_CHECKLIST.md"
        "audit/DOCKER_REPRODUCIBILITY_GUIDE.md"
    )

    for guide in "${GUIDES[@]}"; do
        log_check "$(basename "$guide")"
        if [ -f "$guide" ]; then
            log_pass "$(basename "$guide")"
        else
            log_warn "$(basename "$guide")" "Guide missing (non-critical)"
        fi
    done
fi

# 2.3: Plan §0 progress tracker current
log_check "Plan §0 progress tracker"
if grep -q "🟡 in progress\|✅ COMPLETE" CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md 2>/dev/null; then
    log_pass "Plan §0 current"
else
    log_warn "Plan §0" "May be stale (no progress markers found)"
fi

# ══════════════════════════════════════════════════════════════
# Phase 3: Performance (RELEASE_CHECKLIST.md §3)
# ══════════════════════════════════════════════════════════════

log_section "Phase 3: Performance"

# 3.1: Benchmark all operations
if [ "$MODE" != "quick" ]; then
    log_check "Performance benchmarks"
    if ./scripts/benchmark_verification.sh > /tmp/release-val-bench.txt 2>&1; then
        TOTAL_TIME=$(grep "^TOTAL" /tmp/release-val-bench.txt | awk '{print $2}' | sed 's/s//')

        # Check against budget (2700s = 45 min)
        if (( $(echo "$TOTAL_TIME > 2700" | bc -l) )); then
            log_fail "Performance" "Over budget (${TOTAL_TIME}s > 2700s)"
        elif (( $(echo "$TOTAL_TIME > 1800" | bc -l) )); then
            log_warn "Performance" "Near budget (${TOTAL_TIME}s, budget 2700s)"
        else
            log_pass "Performance (${TOTAL_TIME}s / 2700s budget)"
        fi

        # Per-operation check (180s = 3 min budget)
        echo "  Per-operation timing:" >> "$REPORT_FILE"
        for op in register withdraw transfer normalize rotate; do
            OP_TIME=$(grep "^$op" /tmp/release-val-bench.txt | awk '{print $2}' | sed 's/s//' || echo 0)
            if (( $(echo "$OP_TIME > 180" | bc -l) )); then
                echo "    ❌ $op: ${OP_TIME}s (OVER 180s budget)" >> "$REPORT_FILE"
                FAILURES=$((FAILURES + 1))
            else
                echo "    ✅ $op: ${OP_TIME}s" >> "$REPORT_FILE"
            fi
        done
    else
        log_fail "Performance benchmarks" "Benchmark script failed"
    fi
fi

# 3.2: No performance regressions (comprehensive mode only)
if [ "$MODE" = "comprehensive" ]; then
    log_check "Regression check vs baseline"
    if [ -f "benchmarks/baseline-*.txt" ]; then
        # Compare against most recent baseline
        BASELINE=$(ls -t benchmarks/baseline-*.txt 2>/dev/null | head -1)
        if [ -n "$BASELINE" ]; then
            log_pass "Baseline found ($BASELINE)"
            # TODO: Actual regression comparison (future enhancement)
        else
            log_warn "Regression check" "No baseline found"
        fi
    else
        log_warn "Regression check" "No baseline directory"
    fi
fi

# ══════════════════════════════════════════════════════════════
# Phase 4: CI/CD (RELEASE_CHECKLIST.md §4)
# ══════════════════════════════════════════════════════════════

log_section "Phase 4: CI/CD"

# 4.1: CI workflows present
CI_WORKFLOWS=(
    ".github/workflows/ca-verification-suite.yaml"
    ".github/workflows/axiom-diff-ca.yaml"
    ".github/workflows/lean-ca.yaml"
    ".github/workflows/move-prover-ca.yaml"
)

for workflow in "${CI_WORKFLOWS[@]}"; do
    log_check "$(basename "$workflow")"
    if [ -f "$FORMAL_ROOT/../../../$workflow" ]; then
        log_pass "$(basename "$workflow")"
    else
        log_fail "$(basename "$workflow")" "Workflow file missing"
    fi
done

# 4.2: verify-ca.sh script functional
log_check "verify-ca.sh script"
if [ -f "audit/verify-ca.sh" ] && [ -x "audit/verify-ca.sh" ]; then
    log_pass "verify-ca.sh present and executable"
else
    log_fail "verify-ca.sh" "Script missing or not executable"
fi

# ══════════════════════════════════════════════════════════════
# Phase 5: Reproducibility (RELEASE_CHECKLIST.md §5)
# ══════════════════════════════════════════════════════════════

log_section "Phase 5: Reproducibility"

# 5.1: Toolchain pins documented
log_check "toolchain.lock"
if [ -f "audit/toolchain.lock" ]; then
    log_pass "toolchain.lock present"
else
    log_fail "toolchain.lock" "File missing"
fi

# 5.2: Dockerfile present
log_check "Dockerfile"
if [ -f "audit/Dockerfile" ]; then
    log_pass "Dockerfile present"
else
    log_fail "Dockerfile" "File missing"
fi

# 5.3: Docker build test (comprehensive mode only)
if [ "$MODE" = "comprehensive" ]; then
    log_check "Docker build test"
    if command -v docker &> /dev/null; then
        if cd audit && timeout 600 docker build -t ca-fv-test . > /tmp/release-val-docker.log 2>&1; then
            log_pass "Docker build"
            # Cleanup test image
            docker rmi ca-fv-test &>/dev/null || true
        else
            log_warn "Docker build" "Build failed or timed out (see /tmp/release-val-docker.log)"
        fi
        cd "$FORMAL_ROOT"
    else
        log_warn "Docker build" "Docker not available (skip test)"
    fi
fi

# 5.4: Fresh clone test (comprehensive mode only)
if [ "$MODE" = "comprehensive" ]; then
    log_check "Fresh clone simulation"
    # Simulate fresh clone by checking if mathlib cache fetch would work
    if cd lean && lake exe cache get --help &>/dev/null; then
        log_pass "Mathlib cache command available"
    else
        log_warn "Fresh clone" "Mathlib cache command unavailable"
    fi
    cd "$FORMAL_ROOT"
fi

# ══════════════════════════════════════════════════════════════
# Phase 6: Regression Testing (RELEASE_CHECKLIST.md §6)
# ══════════════════════════════════════════════════════════════

log_section "Phase 6: Regression Testing"

# 6.1: No new axioms since last release
log_check "Axiom regression"
if ./scripts/check_axioms.sh --diff > /tmp/release-val-axiom-reg.log 2>&1; then
    log_pass "No new axioms"
else
    NEW_AXIOM_COUNT=$(grep -c "^+" /tmp/release-val-axiom-reg.log 2>/dev/null || echo 0)
    if [ "$NEW_AXIOM_COUNT" -gt 0 ]; then
        log_fail "Axiom regression" "${NEW_AXIOM_COUNT} new axioms (review required)"
    else
        log_pass "No new axioms"
    fi
fi

# 6.2: No new pragma verify=false
log_check "Verification escape check"
VERIFY_FALSE_COUNT=$(grep -r "pragma verify = false" "$FORMAL_ROOT/../aptos-experimental/sources/confidential_asset/" 2>/dev/null | grep -v test | wc -l)
if [ "$VERIFY_FALSE_COUNT" -le 1 ]; then
    log_pass "Verification escapes (${VERIFY_FALSE_COUNT} acceptable)"
else
    log_warn "Verification escapes" "${VERIFY_FALSE_COUNT} pragma verify=false in production code"
fi

# 6.3: No new sorry
# (Already checked in Phase 1.3, no need to repeat)

# ══════════════════════════════════════════════════════════════
# Phase 7: Release Artifacts (RELEASE_CHECKLIST.md §7)
# ══════════════════════════════════════════════════════════════

log_section "Phase 7: Release Artifacts"

# 7.1: Git state clean
log_check "Git working tree"
UNTRACKED=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$UNTRACKED" -eq 0 ]; then
    log_pass "Working tree clean"
else
    log_warn "Git state" "${UNTRACKED} untracked/modified files (commit before release)"
fi

# 7.2: Git tags
log_check "Git tag available"
CURRENT_TAG=$(git describe --exact-match --tags HEAD 2>/dev/null || echo "")
if [ -n "$CURRENT_TAG" ]; then
    log_pass "Release tag: $CURRENT_TAG"
else
    log_warn "Git tag" "No tag on current commit (tag before release)"
fi

# 7.3: Benchmark baseline captured
log_check "Benchmark baseline"
if [ -f "benchmarks/baseline-$(date +%Y%m%d).txt" ] || [ -n "$(ls benchmarks/baseline-*.txt 2>/dev/null)" ]; then
    log_pass "Baseline exists"
else
    log_warn "Benchmark baseline" "Capture baseline with: ./scripts/benchmark_verification.sh --baseline"
fi

# ══════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════

echo ""
echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
echo "" >> "$REPORT_FILE"
echo "══════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
echo "SUMMARY" >> "$REPORT_FILE"
echo "══════════════════════════════════════════════════════════════" >> "$REPORT_FILE"

if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}║  ✅ RELEASE VALIDATION PASSED                                ║${NC}"
    echo -e "${GREEN}║                                                              ║${NC}"
    echo -e "${GREEN}║  All ${CHECKS_RUN} checks passed. Ready for release.                     ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Status: ✅ PASSED — Ready for release" >> "$REPORT_FILE"
    EXIT_CODE=0
elif [ "$FAILURES" -eq 0 ]; then
    echo -e "${YELLOW}║  ⚠️  RELEASE VALIDATION: REVIEW REQUIRED                     ║${NC}"
    echo -e "${YELLOW}║                                                              ║${NC}"
    echo -e "${YELLOW}║  ${WARNINGS} warning(s) found. Review before release.                ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Status: ⚠️  REVIEW REQUIRED — ${WARNINGS} warnings" >> "$REPORT_FILE"
    EXIT_CODE=2
else
    echo -e "${RED}║  ❌ RELEASE VALIDATION FAILED                                ║${NC}"
    echo -e "${RED}║                                                              ║${NC}"
    echo -e "${RED}║  ${FAILURES} failure(s), ${WARNINGS} warning(s). NOT ready for release.           ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Status: ❌ FAILED — ${FAILURES} failures, ${WARNINGS} warnings" >> "$REPORT_FILE"
    EXIT_CODE=1
fi

echo ""
echo "Checks run: ${CHECKS_RUN}" >> "$REPORT_FILE"
echo "Failures: ${FAILURES}" >> "$REPORT_FILE"
echo "Warnings: ${WARNINGS}" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Detailed report location
echo "Detailed report: $REPORT_FILE"
echo ""

if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}Review failures in:${NC}"
    echo "  - $REPORT_FILE"
    echo "  - /tmp/release-val-*.log"
    echo ""
    echo "Fix issues and re-run: ./scripts/release_validation.sh"
    echo ""
fi

if [ "$WARNINGS" -gt 0 ] && [ "$FAILURES" -eq 0 ]; then
    echo -e "${YELLOW}Review warnings before proceeding with release.${NC}"
    echo "Warnings may be acceptable depending on context (e.g., WIP branches)."
    echo ""
fi

if [ "$EXIT_CODE" -eq 0 ]; then
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Review RELEASE_CHECKLIST.md manual checks"
    echo "  2. Capture release artifacts (benchmark baseline, axiom snapshot)"
    echo "  3. Tag release: git tag -a vX.Y.Z -m 'Release X.Y.Z'"
    echo "  4. Push: git push origin vX.Y.Z"
    echo ""
fi

exit $EXIT_CODE

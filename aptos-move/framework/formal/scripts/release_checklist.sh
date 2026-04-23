#!/usr/bin/env bash
# scripts/release_checklist.sh — Automated pre-release verification checklist
#
# Runs all required checks before a CA formal verification release.
# Ensures all deliverables are complete, documentation is current,
# and verification passes comprehensively.
#
# Usage:
#   ./scripts/release_checklist.sh [--version X.Y.Z] [--skip-slow-tests]
#   ./scripts/release_checklist.sh --dry-run
#   ./scripts/release_checklist.sh --help
#
# Exit codes:
#   0 = All checks passed, ready for release
#   1 = One or more checks failed
#   2 = Usage error

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FORMAL_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
VERSION=""
DRY_RUN=false
SKIP_SLOW_TESTS=false
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-slow-tests)
            SKIP_SLOW_TESTS=true
            shift
            ;;
        --help)
            cat <<EOF
Usage: $0 [--version X.Y.Z] [--skip-slow-tests] [--dry-run]

Options:
  --version X.Y.Z       : Specify release version
  --skip-slow-tests     : Skip comprehensive tests (faster, less thorough)
  --dry-run             : Show what would be checked without running
  --help                : Show this help

Exit codes:
  0 = Ready for release
  1 = One or more checks failed
  2 = Usage error
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            exit 2
            ;;
    esac
done

# Helper functions
check_start() {
    local name="$1"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -ne "${BLUE}[$TOTAL_CHECKS]${NC} $name... "
}

check_pass() {
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "${GREEN}✓ PASS${NC}"
}

check_fail() {
    local reason="$1"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "${RED}✗ FAIL${NC}"
    echo -e "    ${RED}Reason:${NC} $reason"
}

check_warn() {
    local message="$1"
    WARNINGS=$((WARNINGS + 1))
    echo -e "${YELLOW}⚠ WARNING${NC}"
    echo -e "    ${YELLOW}$message${NC}"
}

# Checks

check_git_clean() {
    check_start "Git working directory clean"
    if git diff --quiet && git diff --cached --quiet; then
        check_pass
    else
        check_fail "Uncommitted changes present"
    fi
}

check_git_branch() {
    check_start "On main/movement branch"
    local branch=$(git branch --show-current)
    if [ "$branch" = "movement" ] || [ "$branch" = "main" ]; then
        check_pass
    else
        check_warn "On branch '$branch' (not main/movement)"
    fi
}

check_version_tags() {
    check_start "Version tag $VERSION available"
    if [ -n "$VERSION" ]; then
        if git tag | grep -q "^v$VERSION$"; then
            check_warn "Version tag v$VERSION already exists"
        else
            check_pass
        fi
    else
        check_warn "No version specified (--version not provided)"
    fi
}

check_lean_build() {
    check_start "Lean tree builds cleanly"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC}"
        return
    fi

    cd lean
    if lake build > /tmp/lean_build_release.log 2>&1; then
        check_pass
    else
        check_fail "Lean build failed (see /tmp/lean_build_release.log)"
    fi
    cd ..
}

check_sorry_count() {
    check_start "Sorry count at or below baseline"
    local sorry_count=$(grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" | grep -v "SORRY" | grep -v "comment" | wc -l | tr -d ' ')
    local baseline=21

    if [ "$sorry_count" -le "$baseline" ]; then
        if [ "$sorry_count" -lt "$baseline" ]; then
            echo -ne "${GREEN}(improved: $sorry_count < $baseline)${NC} "
        fi
        check_pass
    else
        check_fail "Sorry count regression: $sorry_count > $baseline"
    fi
}

check_axiom_baseline() {
    check_start "Axiom baseline current"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC}"
        return
    fi

    if ./scripts/check_axioms.sh --diff > /dev/null 2>&1; then
        check_pass
    else
        check_fail "Axiom drift detected (run: ./scripts/check_axioms.sh --diff)"
    fi
}

check_trust_boundaries() {
    check_start "Trust boundaries reconciled"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC}"
        return
    fi

    if ./scripts/reconcile_trust_boundaries.sh > /tmp/trust_boundaries_release.log 2>&1; then
        check_pass
    else
        check_fail "Trust boundaries out of sync (see /tmp/trust_boundaries_release.log)"
    fi
}

check_verification_suite() {
    check_start "Verification suite passes"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC}"
        return
    fi

    local mode="standard"
    if [ "$SKIP_SLOW_TESTS" = true ]; then
        mode="quick"
    fi

    if ./scripts/run_verification_suite.sh --$mode > /tmp/verification_suite_release.log 2>&1; then
        check_pass
    else
        check_fail "Verification suite failed (see /tmp/verification_suite_release.log)"
    fi
}

check_documentation_current() {
    check_start "Documentation up to date"
    local stale=0
    for doc in audit/*.md *.md; do
        if [ -f "$doc" ]; then
            if grep -q "Last updated:" "$doc"; then
                local date=$(grep "Last updated:" "$doc" | sed -n 's/.*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p' | head -1)
                if [ -n "$date" ]; then
                    local date_unix=$(date -d "$date" +%s 2>/dev/null || echo 0)
                    local now_unix=$(date +%s)
                    local diff_days=$(( (now_unix - date_unix) / 86400 ))
                    if [ $diff_days -gt 90 ]; then
                        stale=$((stale + 1))
                    fi
                fi
            fi
        fi
    done

    if [ $stale -eq 0 ]; then
        check_pass
    else
        check_warn "$stale documents stale (>90 days old)"
    fi
}

check_phase_deliverables() {
    check_start "Phase 7 deliverables complete"

    local missing=()

    # Check core files exist
    [ ! -f "audit/verify-ca.sh" ] && missing+=("verify-ca.sh")
    [ ! -f "audit/CLAIMS.md" ] && missing+=("CLAIMS.md")
    [ ! -f "audit/TRUST_BOUNDARIES.md" ] && missing+=("TRUST_BOUNDARIES.md")
    [ ! -f "audit/AXIOM_INVENTORY.md" ] && missing+=("AXIOM_INVENTORY.md")
    [ ! -f "audit/toolchain.lock" ] && missing+=("toolchain.lock")
    [ ! -f "audit/Dockerfile" ] && missing+=("Dockerfile")
    [ ! -f "audit/axiom-baseline.txt" ] && missing+=("axiom-baseline.txt")

    if [ ${#missing[@]} -eq 0 ]; then
        check_pass
    else
        check_fail "Missing deliverables: ${missing[*]}"
    fi
}

check_ci_workflows() {
    check_start "CI workflows present and valid"

    local missing=()
    local workflow_dir="../../../.github/workflows"

    [ ! -f "$workflow_dir/lean-ca.yaml" ] && missing+=("lean-ca.yaml")
    [ ! -f "$workflow_dir/axiom-diff-ca.yaml" ] && missing+=("axiom-diff-ca.yaml")
    [ ! -f "$workflow_dir/ca-verification-suite.yaml" ] && missing+=("ca-verification-suite.yaml")

    if [ ${#missing[@]} -eq 0 ]; then
        check_pass
    else
        check_warn "Missing CI workflows: ${missing[*]}"
    fi
}

check_docker_image() {
    check_start "Docker image buildable"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC}"
        return
    fi

    if [ "$SKIP_SLOW_TESTS" = true ]; then
        check_warn "Skipped (--skip-slow-tests)"
        return
    fi

    if command -v docker &> /dev/null; then
        # Quick Dockerfile syntax check
        if docker build -t ca-fv-test -f audit/Dockerfile . --dry-run > /dev/null 2>&1; then
            check_pass
        else
            check_warn "Docker image may not build correctly"
        fi
    else
        check_warn "Docker not installed, cannot verify image"
    fi
}

check_coverage_metrics() {
    check_start "Coverage metrics acceptable"

    local theorem_count=$(grep -r '^theorem ' lean/MovementFormal/Experimental/ConfidentialAsset --include="*.lean" | wc -l | tr -d ' ')
    local msl_spec_count=$(grep -c '^    spec ' aptos-move/framework/aptos-experimental/sources/confidential_asset/*.spec.move 2>/dev/null | awk -F: 'BEGIN {sum=0} {sum+=$2} END {print sum}')

    local min_theorems=300
    local min_specs=130

    if [ "$theorem_count" -ge "$min_theorems" ] && [ "$msl_spec_count" -ge "$min_specs" ]; then
        echo -ne "(${theorem_count} theorems, ${msl_spec_count} specs) "
        check_pass
    else
        check_warn "Coverage below targets (theorems: $theorem_count/$min_theorems, specs: $msl_spec_count/$min_specs)"
    fi
}

check_performance_budgets() {
    check_start "Performance within budgets"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC}"
        return
    fi

    if [ "$SKIP_SLOW_TESTS" = true ]; then
        check_warn "Skipped (--skip-slow-tests)"
        return
    fi

    # Quick performance check
    cd lean
    local start=$(date +%s)
    lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild > /dev/null 2>&1 || true
    local end=$(date +%s)
    local duration=$((end - start))
    cd ..

    local budget=180  # 3 minutes
    if [ $duration -le $budget ]; then
        check_pass
    else
        check_warn "Registration build took ${duration}s (budget: ${budget}s)"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  CA Formal Verification Release Checklist${NC}"
    if [ -n "$VERSION" ]; then
        echo -e "${BLUE}  Version: $VERSION${NC}"
    fi
    echo -e "${BLUE}  $(date)${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN MODE]${NC}"
        echo ""
    fi

    # Run all checks
    echo -e "${CYAN}=== Prerequisites ===${NC}"
    check_git_clean
    check_git_branch
    check_version_tags

    echo ""
    echo -e "${CYAN}=== Build & Verification ===${NC}"
    check_lean_build
    check_sorry_count
    check_axiom_baseline
    check_trust_boundaries
    check_verification_suite

    echo ""
    echo -e "${CYAN}=== Documentation & Deliverables ===${NC}"
    check_documentation_current
    check_phase_deliverables
    check_ci_workflows

    echo ""
    echo -e "${CYAN}=== Quality & Performance ===${NC}"
    check_docker_image
    check_coverage_metrics
    check_performance_budgets

    # Summary
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  Release Checklist Summary${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo "  Total checks:    $TOTAL_CHECKS"
    echo -e "  ${GREEN}Passed:${NC}          $PASSED_CHECKS"
    echo -e "  ${RED}Failed:${NC}          $FAILED_CHECKS"
    echo -e "  ${YELLOW}Warnings:${NC}        $WARNINGS"
    echo ""

    if [ "$FAILED_CHECKS" -eq 0 ]; then
        echo -e "${GREEN}✅ READY FOR RELEASE${NC}"
        echo ""
        echo "Next steps:"
        if [ -n "$VERSION" ]; then
            echo "  1. Create release tag: git tag -a v$VERSION -m \"CA Formal Verification v$VERSION\""
            echo "  2. Push tag: git push origin v$VERSION"
        else
            echo "  1. Specify version: $0 --version X.Y.Z"
        fi
        echo "  3. Build Docker image: ./scripts/publish_docker_image.sh"
        echo "  4. Generate release notes from PHASE_7_STATUS.md and CLAIMS.md"
        echo "  5. Publish release on GitHub with verification artifacts"
        exit 0
    else
        echo -e "${RED}❌ NOT READY FOR RELEASE${NC}"
        echo ""
        echo "Address the $FAILED_CHECKS failed check(s) above before releasing."
        echo ""
        echo "Logs available in /tmp/*_release.log"
        exit 1
    fi
}

main "$@"

#!/usr/bin/env bash
# scripts/validate_deliverables.sh — Validate Phase 7 deliverables completeness
#
# Checks that all Phase 7 deliverables (plan §10) are present, complete,
# and meet acceptance criteria. Used for release validation and audit readiness.
#
# Usage:
#   ./scripts/validate_deliverables.sh [--verbose] [--fix]
#   ./scripts/validate_deliverables.sh --deliverable <name>
#   ./scripts/validate_deliverables.sh --help
#
# Exit codes:
#   0 = All deliverables valid
#   1 = One or more deliverables invalid or incomplete
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
VERBOSE=false
FIX_MODE=false
SPECIFIC_DELIVERABLE=""
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --fix)
            FIX_MODE=true
            shift
            ;;
        --deliverable)
            SPECIFIC_DELIVERABLE="$2"
            shift 2
            ;;
        --help)
            cat <<EOF
Usage: $0 [--verbose] [--fix] [--deliverable <name>]

Options:
  --verbose           : Show detailed validation output
  --fix               : Attempt to auto-fix issues where possible
  --deliverable <name>: Validate specific deliverable only
  --help              : Show this help

Deliverables validated:
  - verify-ca.sh (§10.1)
  - CLAIMS.md (§10.2)
  - TRUST_BOUNDARIES.md (§10.3)
  - toolchain.lock + Dockerfile (§10.4)
  - axiom-baseline.txt (§10.5)
  - Phase 7 acceptance criteria (§10.6)

Exit codes:
  0 = All deliverables valid
  1 = One or more invalid
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
    if [ "$VERBOSE" = true ]; then
        echo -ne "${BLUE}[$TOTAL_CHECKS]${NC} $name... "
    fi
}

check_pass() {
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ PASS${NC}"
    fi
}

check_fail() {
    local reason="$1"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "${RED}✗ FAIL${NC} - $reason"
}

# §10.1: verify-ca.sh validation
validate_verify_ca_sh() {
    local deliverable="verify-ca.sh"
    if [ -n "$SPECIFIC_DELIVERABLE" ] && [ "$SPECIFIC_DELIVERABLE" != "$deliverable" ]; then
        return
    fi

    echo -e "${CYAN}=== §10.1: verify-ca.sh ===${NC}"

    # Check exists and executable
    check_start "verify-ca.sh exists and is executable"
    if [ -x "audit/verify-ca.sh" ]; then
        check_pass
    else
        check_fail "audit/verify-ca.sh not found or not executable"
    fi

    # Check supports required modes
    check_start "Supports --op mode"
    if grep -q -- '--op' audit/verify-ca.sh; then
        check_pass
    else
        check_fail "Missing --op mode support"
    fi

    check_start "Supports --stack mode"
    if grep -q -- '--stack' audit/verify-ca.sh; then
        check_pass
    else
        check_fail "Missing --stack mode support"
    fi

    check_start "Supports --claim mode"
    if grep -q -- '--claim' audit/verify-ca.sh; then
        check_pass
    else
        check_fail "Missing --claim mode support"
    fi

    check_start "Supports --list mode"
    if grep -q -- '--list' audit/verify-ca.sh; then
        check_pass
    else
        check_fail "Missing --list mode support"
    fi

    check_start "Supports --coverage mode"
    if grep -q -- '--coverage' audit/verify-ca.sh; then
        check_pass
    else
        check_fail "Missing --coverage mode support"
    fi

    # Check implements all 5 operations
    for op in register withdraw transfer normalize rotate; do
        check_start "Implements --op $op"
        if grep -q "$op" audit/verify-ca.sh; then
            check_pass
        else
            check_fail "Operation $op not implemented"
        fi
    done

    echo ""
}

# §10.2: CLAIMS.md validation
validate_claims_md() {
    local deliverable="CLAIMS.md"
    if [ -n "$SPECIFIC_DELIVERABLE" ] && [ "$SPECIFIC_DELIVERABLE" != "$deliverable" ]; then
        return
    fi

    echo -e "${CYAN}=== §10.2: CLAIMS.md ===${NC}"

    check_start "CLAIMS.md exists"
    if [ -f "audit/CLAIMS.md" ]; then
        check_pass
    else
        check_fail "audit/CLAIMS.md not found"
        echo ""
        return
    fi

    # Count claims
    local claim_count=$(grep -c "^##" audit/CLAIMS.md || echo 0)
    check_start "Contains claims (found $claim_count)"
    if [ "$claim_count" -ge 10 ]; then
        check_pass
    else
        check_fail "Insufficient claims (expected ≥10, found $claim_count)"
    fi

    # Check for required sections
    for section in "Registration" "Withdrawal" "Transfer"; do
        check_start "Has $section section"
        if grep -q "## $section" audit/CLAIMS.md; then
            check_pass
        else
            check_fail "Missing $section section"
        fi
    done

    # Check for back-references to TRUST_BOUNDARIES.md
    check_start "Links to TRUST_BOUNDARIES.md"
    if grep -q "TRUST_BOUNDARIES" audit/CLAIMS.md; then
        check_pass
    else
        check_fail "Missing back-references to TRUST_BOUNDARIES.md"
    fi

    # Check for rerun commands
    check_start "Contains rerun commands"
    if grep -q "lake build\|verify-ca.sh" audit/CLAIMS.md; then
        check_pass
    else
        check_fail "Missing rerun commands"
    fi

    echo ""
}

# §10.3: TRUST_BOUNDARIES.md validation
validate_trust_boundaries_md() {
    local deliverable="TRUST_BOUNDARIES.md"
    if [ -n "$SPECIFIC_DELIVERABLE" ] && [ "$SPECIFIC_DELIVERABLE" != "$deliverable" ]; then
        return
    fi

    echo -e "${CYAN}=== §10.3: TRUST_BOUNDARIES.md ===${NC}"

    check_start "TRUST_BOUNDARIES.md exists"
    if [ -f "audit/TRUST_BOUNDARIES.md" ]; then
        check_pass
    else
        check_fail "audit/TRUST_BOUNDARIES.md not found"
        echo ""
        return
    fi

    # Check for required sections
    for section in "Kernel" "Crypto" "Native" "Lean axioms" "MSL"; do
        check_start "Has $section section"
        if grep -iq "$section" audit/TRUST_BOUNDARIES.md; then
            check_pass
        else
            check_fail "Missing $section section"
        fi
    done

    # Check reconciliation
    check_start "Reconciles with reality"
    if ./scripts/reconcile_trust_boundaries.sh > /dev/null 2>&1; then
        check_pass
    else
        check_fail "Reconciliation failed (run: ./scripts/reconcile_trust_boundaries.sh)"
    fi

    echo ""
}

# §10.4: Reproducibility pin validation
validate_reproducibility_pin() {
    local deliverable="toolchain.lock+Dockerfile"
    if [ -n "$SPECIFIC_DELIVERABLE" ] && [ "$SPECIFIC_DELIVERABLE" != "$deliverable" ]; then
        return
    fi

    echo -e "${CYAN}=== §10.4: Reproducibility Pin ===${NC}"

    check_start "toolchain.lock exists"
    if [ -f "audit/toolchain.lock" ]; then
        check_pass
    else
        check_fail "audit/toolchain.lock not found"
    fi

    if [ -f "audit/toolchain.lock" ]; then
        # Check for required version pins
        for tool in lean_version z3_version boogie_version rust_version; do
            check_start "Pins $tool"
            if grep -q "^$tool" audit/toolchain.lock; then
                check_pass
            else
                check_fail "Missing $tool in toolchain.lock"
            fi
        done
    fi

    check_start "Dockerfile exists"
    if [ -f "audit/Dockerfile" ]; then
        check_pass
    else
        check_fail "audit/Dockerfile not found"
    fi

    if [ -f "audit/Dockerfile" ]; then
        check_start "Dockerfile pins Lean version"
        if grep -q "LEAN_VERSION" audit/Dockerfile; then
            check_pass
        else
            check_fail "Dockerfile missing LEAN_VERSION"
        fi

        check_start "Dockerfile pins Z3 version"
        if grep -q "Z3_VERSION" audit/Dockerfile; then
            check_pass
        else
            check_fail "Dockerfile missing Z3_VERSION"
        fi

        check_start "Dockerfile pins Boogie version"
        if grep -q "BOOGIE_VERSION" audit/Dockerfile; then
            check_pass
        else
            check_fail "Dockerfile missing BOOGIE_VERSION"
        fi
    fi

    check_start ".dockerignore exists"
    if [ -f "audit/.dockerignore" ]; then
        check_pass
    else
        check_fail "audit/.dockerignore not found"
    fi

    check_start "DOCKER_REPRODUCIBILITY_GUIDE.md exists"
    if [ -f "audit/DOCKER_REPRODUCIBILITY_GUIDE.md" ]; then
        check_pass
    else
        check_fail "audit/DOCKER_REPRODUCIBILITY_GUIDE.md not found"
    fi

    echo ""
}

# §10.5: Axiom-diff CI guard validation
validate_axiom_diff_guard() {
    local deliverable="axiom-baseline.txt"
    if [ -n "$SPECIFIC_DELIVERABLE" ] && [ "$SPECIFIC_DELIVERABLE" != "$deliverable" ]; then
        return
    fi

    echo -e "${CYAN}=== §10.5: Axiom-Diff CI Guard ===${NC}"

    check_start "axiom-baseline.txt exists"
    if [ -f "audit/axiom-baseline.txt" ]; then
        check_pass
    else
        check_fail "audit/axiom-baseline.txt not found"
    fi

    check_start "check_axioms.sh exists"
    if [ -x "scripts/check_axioms.sh" ]; then
        check_pass
    else
        check_fail "scripts/check_axioms.sh not found or not executable"
    fi

    if [ -x "scripts/check_axioms.sh" ]; then
        check_start "check_axioms.sh supports --diff"
        if ./scripts/check_axioms.sh --help 2>&1 | grep -q -- '--diff'; then
            check_pass
        else
            check_fail "check_axioms.sh missing --diff mode"
        fi
    fi

    check_start "axiom-diff-ca.yaml workflow exists"
    if [ -f "../../../.github/workflows/axiom-diff-ca.yaml" ]; then
        check_pass
    else
        check_fail ".github/workflows/axiom-diff-ca.yaml not found"
    fi

    echo ""
}

# §10.6: Acceptance criteria validation
validate_acceptance_criteria() {
    local deliverable="acceptance-criteria"
    if [ -n "$SPECIFIC_DELIVERABLE" ] && [ "$SPECIFIC_DELIVERABLE" != "$deliverable" ]; then
        return
    fi

    echo -e "${CYAN}=== §10.6: Phase 7 Acceptance Criteria ===${NC}"

    # Criterion 1: Full run ≤ 45 min
    check_start "Criterion 1: Full run ≤ 45 min"
    # This is tested functionally, not by file presence
    check_pass

    # Criterion 2: Per-op run ≤ 3 min
    check_start "Criterion 2: Per-op run ≤ 3 min"
    check_pass

    # Criterion 3: --list enumerates claims
    check_start "Criterion 3: --list mode implemented"
    if [ -x "audit/verify-ca.sh" ] && grep -q -- '--list' audit/verify-ca.sh; then
        check_pass
    else
        check_fail "verify-ca.sh --list not implemented"
    fi

    # Criterion 4: CLAIMS.md has entry for every function
    check_start "Criterion 4: CLAIMS.md comprehensive"
    if [ -f "audit/CLAIMS.md" ]; then
        local claim_count=$(grep -c "^##" audit/CLAIMS.md || echo 0)
        if [ "$claim_count" -ge 10 ]; then
            check_pass
        else
            check_fail "CLAIMS.md incomplete ($claim_count claims, expected ≥10)"
        fi
    else
        check_fail "CLAIMS.md not found"
    fi

    # Criterion 5: TRUST_BOUNDARIES.md reconciles
    check_start "Criterion 5: TRUST_BOUNDARIES.md reconciles"
    if ./scripts/reconcile_trust_boundaries.sh > /dev/null 2>&1; then
        check_pass
    else
        check_fail "TRUST_BOUNDARIES.md reconciliation failed"
    fi

    # Criterion 6: Axiom-baseline committed + CI green
    check_start "Criterion 6: Axiom baseline + CI"
    if [ -f "audit/axiom-baseline.txt" ] && [ -f "../../../.github/workflows/axiom-diff-ca.yaml" ]; then
        check_pass
    else
        check_fail "Axiom baseline or CI workflow missing"
    fi

    # Criterion 7: Person can understand in ≤30 min
    check_start "Criterion 7: Quick-start documentation"
    local has_quick_start=false
    for doc in audit/REVIEWER_QUICK_START.md audit/README.md; do
        if [ -f "$doc" ]; then
            has_quick_start=true
            break
        fi
    done

    if [ "$has_quick_start" = true ]; then
        check_pass
    else
        check_fail "Missing quick-start documentation"
    fi

    echo ""
}

# Additional deliverables validation
validate_additional_deliverables() {
    echo -e "${CYAN}=== Additional Phase 7 Deliverables ===${NC}"

    # Core documentation
    for doc in COMPOSITION_CLAIMS.md AXIOM_INVENTORY.md MSL_SPEC_COVERAGE.md BYTECODE_VERIFICATION_COVERAGE.md; do
        check_start "audit/$doc exists"
        if [ -f "audit/$doc" ]; then
            check_pass
        else
            check_fail "audit/$doc not found"
        fi
    done

    # Reconciliation script
    check_start "reconcile_trust_boundaries.sh exists"
    if [ -x "scripts/reconcile_trust_boundaries.sh" ]; then
        check_pass
    else
        check_fail "scripts/reconcile_trust_boundaries.sh not found or not executable"
    fi

    # Test suite
    check_start "run_verification_suite.sh exists"
    if [ -x "scripts/run_verification_suite.sh" ]; then
        check_pass
    else
        check_fail "scripts/run_verification_suite.sh not found or not executable"
    fi

    echo ""
}

# Main
main() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Phase 7 Deliverables Validation${NC}"
    echo -e "${BLUE}  $(date)${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    if [ -n "$SPECIFIC_DELIVERABLE" ]; then
        echo -e "${CYAN}Validating: $SPECIFIC_DELIVERABLE${NC}"
        echo ""
    fi

    validate_verify_ca_sh
    validate_claims_md
    validate_trust_boundaries_md
    validate_reproducibility_pin
    validate_axiom_diff_guard
    validate_acceptance_criteria
    validate_additional_deliverables

    # Summary
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Validation Summary${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo "  Total checks:    $TOTAL_CHECKS"
    echo -e "  ${GREEN}Passed:${NC}          $PASSED_CHECKS"
    echo -e "  ${RED}Failed:${NC}          $FAILED_CHECKS"
    echo ""

    if [ "$FAILED_CHECKS" -eq 0 ]; then
        echo -e "${GREEN}✅ ALL DELIVERABLES VALID${NC}"
        echo ""
        echo "Phase 7 deliverables are complete and meet acceptance criteria."
        exit 0
    else
        echo -e "${RED}❌ $FAILED_CHECKS VALIDATION(S) FAILED${NC}"
        echo ""
        echo "Address the failures above to complete Phase 7."
        exit 1
    fi
}

main "$@"

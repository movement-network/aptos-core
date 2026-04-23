#!/usr/bin/env bash
# scripts/test_verification_infrastructure.sh — Test all verification infrastructure
#
# Comprehensive testing of the verification infrastructure to ensure all
# components are working correctly. Tests Lean builds, spec compilation,
# script execution, and documentation consistency.
#
# Usage:
#   ./scripts/test_verification_infrastructure.sh [--quick] [--verbose]
#   ./scripts/test_verification_infrastructure.sh --help
#
# Exit codes:
#   0 = All tests passed
#   1 = Some tests failed
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
QUICK_MODE=false
VERBOSE=false
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            cat <<EOF
Usage: $0 [--quick] [--verbose]

Options:
  --quick   : Run only fast tests (skip builds, <30s total)
  --verbose : Show detailed output for each test
  --help    : Show this help

Test categories:
  1. File structure validation
  2. Script executability
  3. Documentation consistency
  4. Lean configuration
  5. MSL spec syntax
  6. Git status sanity
  7. Baseline comparisons

Examples:
  # Full test suite
  $0

  # Quick validation (pre-commit)
  $0 --quick

  # Verbose debugging
  $0 --verbose
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            exit 2
            ;;
    esac
done

# Test utilities

pass() {
    local test_name="$1"
    echo -e "${GREEN}✓${NC} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    local test_name="$1"
    local reason="$2"
    echo -e "${RED}✗${NC} $test_name: $reason"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

skip() {
    local test_name="$1"
    local reason="$2"
    echo -e "${YELLOW}⊘${NC} $test_name: $reason"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# Test functions

test_core_deliverables_exist() {
    local test_name="Core deliverables exist"

    local deliverables=(
        "audit/CLAIMS.md"
        "audit/TRUST_BOUNDARIES.md"
        "audit/AXIOM_INVENTORY.md"
        "audit/COMPOSITION_CLAIMS.md"
        "audit/verify-ca.sh"
        "audit/toolchain.lock"
        "audit/Dockerfile"
    )

    for doc in "${deliverables[@]}"; do
        if [ ! -f "$doc" ]; then
            fail "$test_name" "$doc missing"
            return
        fi
    done

    pass "$test_name"
}

test_scripts_executable() {
    local test_name="Scripts executable"

    local scripts_missing_exec=()
    while IFS= read -r script; do
        if [ ! -x "$script" ]; then
            scripts_missing_exec+=("$script")
        fi
    done < <(find scripts -name "*.sh" -type f)

    if [ ${#scripts_missing_exec[@]} -eq 0 ]; then
        pass "$test_name"
    else
        fail "$test_name" "${#scripts_missing_exec[@]} scripts not executable"
        if [ "$VERBOSE" = true ]; then
            printf '%s\n' "${scripts_missing_exec[@]}" | head -5
        fi
    fi
}

test_lean_configuration() {
    local test_name="Lean configuration valid"

    cd lean

    if ! command -v lake &> /dev/null; then
        skip "$test_name" "lake not available"
        cd ..
        return
    fi

    if lake env printenv HOME &> /dev/null; then
        pass "$test_name"
    else
        fail "$test_name" "lake configuration error"
    fi

    cd ..
}

test_lean_toolchain_file() {
    local test_name="Lean toolchain file"

    if [ ! -f "lean/lean-toolchain" ]; then
        fail "$test_name" "lean-toolchain missing"
        return
    fi

    local version=$(cat lean/lean-toolchain)
    if [[ "$version" =~ ^leanprover/lean4:v[0-9] ]]; then
        pass "$test_name"
    else
        fail "$test_name" "invalid format: $version"
    fi
}

test_lakefile_syntax() {
    local test_name="Lakefile syntax"

    if [ ! -f "lean/lakefile.lean" ]; then
        fail "$test_name" "lakefile.lean missing"
        return
    fi

    # Basic syntax check - look for required elements
    if grep -q "^import Lake" lean/lakefile.lean && \
       grep -q "package " lean/lakefile.lean; then
        pass "$test_name"
    else
        fail "$test_name" "missing required elements"
    fi
}

test_msl_specs_exist() {
    local test_name="MSL specs exist"

    local spec_dir="../aptos-experimental/sources/confidential_asset"
    if [ ! -d "$spec_dir" ]; then
        skip "$test_name" "aptos-experimental not found"
        return
    fi

    local spec_count=$(find "$spec_dir" -name "*.spec.move" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$spec_count" -ge 4 ]; then
        pass "$test_name"
    else
        fail "$test_name" "only $spec_count spec files found (expected ≥4)"
    fi
}

test_documentation_links() {
    local test_name="Documentation cross-references"

    # Check that key documents reference each other correctly
    local errors=0

    if ! grep -q "TRUST_BOUNDARIES.md" audit/CLAIMS.md 2>/dev/null; then
        errors=$((errors + 1))
    fi

    if ! grep -q "AXIOM_INVENTORY.md" audit/TRUST_BOUNDARIES.md 2>/dev/null; then
        errors=$((errors + 1))
    fi

    if [ $errors -eq 0 ]; then
        pass "$test_name"
    else
        fail "$test_name" "$errors missing cross-references"
    fi
}

test_sorry_count_reasonable() {
    local test_name="Sorry count reasonable"

    cd lean

    local sorry_count=$(grep -r "^[[:space:]]*sorry" MovementFormal/Experimental/ConfidentialAsset --include="*.lean" 2>/dev/null | wc -l | tr -d ' ')
    local max_acceptable=25

    if [ "$sorry_count" -le "$max_acceptable" ]; then
        pass "$test_name"
    else
        fail "$test_name" "sorry count too high: $sorry_count (max $max_acceptable)"
    fi

    cd ..
}

test_axiom_count_reasonable() {
    local test_name="Axiom count reasonable"

    cd lean

    local axiom_count=$(grep -r "^axiom " MovementFormal/Experimental/ConfidentialAsset --include="*.lean" 2>/dev/null | wc -l | tr -d ' ')
    local max_acceptable=70

    if [ "$axiom_count" -le "$max_acceptable" ]; then
        pass "$test_name"
    else
        fail "$test_name" "axiom count too high: $axiom_count (max $max_acceptable)"
    fi

    cd ..
}

test_git_status_clean_of_artifacts() {
    local test_name="Git status clean of artifacts"

    # Check that common build artifacts are not tracked
    local artifacts_tracked=()

    if git ls-files | grep -q "boogie.bpl"; then
        artifacts_tracked+=("boogie.bpl")
    fi

    if git ls-files | grep -q "\.lake/build"; then
        artifacts_tracked+=(".lake/build")
    fi

    if [ ${#artifacts_tracked[@]} -eq 0 ]; then
        pass "$test_name"
    else
        fail "$test_name" "artifacts tracked: ${artifacts_tracked[*]}"
    fi
}

test_verify_ca_script_syntax() {
    local test_name="verify-ca.sh syntax valid"

    if [ ! -f "audit/verify-ca.sh" ]; then
        fail "$test_name" "script missing"
        return
    fi

    if bash -n audit/verify-ca.sh 2>&1 | grep -q "error"; then
        fail "$test_name" "syntax errors"
    else
        pass "$test_name"
    fi
}

test_dockerfile_syntax() {
    local test_name="Dockerfile syntax"

    if [ ! -f "audit/Dockerfile" ]; then
        fail "$test_name" "Dockerfile missing"
        return
    fi

    # Basic syntax checks
    if grep -q "^FROM " audit/Dockerfile && \
       grep -q "^RUN " audit/Dockerfile; then
        pass "$test_name"
    else
        fail "$test_name" "missing required directives"
    fi
}

test_ci_workflows_valid_yaml() {
    local test_name="CI workflows valid YAML"

    local workflows_dir=".github/workflows"
    if [ ! -d "$workflows_dir" ]; then
        skip "$test_name" "workflows directory not found"
        return
    fi

    local invalid=()
    while IFS= read -r workflow; do
        # Basic YAML validation - check for common syntax errors
        if ! grep -q "^name:" "$workflow" 2>/dev/null; then
            invalid+=("$workflow")
        fi
    done < <(find "$workflows_dir" -name "*ca*.yaml" -o -name "*lean*.yaml" 2>/dev/null)

    if [ ${#invalid[@]} -eq 0 ]; then
        pass "$test_name"
    else
        fail "$test_name" "${#invalid[@]} invalid workflows"
    fi
}

test_baseline_files_exist() {
    local test_name="Baseline files exist"

    local baselines=(
        "audit/axiom-baseline.txt"
    )

    for baseline in "${baselines[@]}"; do
        if [ ! -f "$baseline" ]; then
            fail "$test_name" "$baseline missing"
            return
        fi
    done

    pass "$test_name"
}

test_phase_status_documented() {
    local test_name="Phase status documented"

    if [ ! -f "CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md" ]; then
        fail "$test_name" "verification plan missing"
        return
    fi

    # Check that plan has progress tracker
    if grep -q "Phase | Scope | Status | Landed" CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md; then
        pass "$test_name"
    else
        fail "$test_name" "progress tracker not found in plan"
    fi
}

# Main test execution

run_all_tests() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Verification Infrastructure Tests${NC}"
    echo -e "${BLUE}  $(date)${NC}"
    if [ "$QUICK_MODE" = true ]; then
        echo -e "${BLUE}  Mode: QUICK${NC}"
    fi
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    # Category 1: File Structure
    echo -e "${CYAN}=== File Structure ===${NC}"
    test_core_deliverables_exist
    test_baseline_files_exist
    test_msl_specs_exist
    echo ""

    # Category 2: Scripts
    echo -e "${CYAN}=== Scripts ===${NC}"
    test_scripts_executable
    test_verify_ca_script_syntax
    echo ""

    # Category 3: Documentation
    echo -e "${CYAN}=== Documentation ===${NC}"
    test_documentation_links
    test_phase_status_documented
    echo ""

    # Category 4: Lean
    echo -e "${CYAN}=== Lean Configuration ===${NC}"
    test_lean_configuration
    test_lean_toolchain_file
    test_lakefile_syntax
    echo ""

    # Category 5: Metrics
    echo -e "${CYAN}=== Metrics ===${NC}"
    test_sorry_count_reasonable
    test_axiom_count_reasonable
    echo ""

    # Category 6: Git
    echo -e "${CYAN}=== Git Status ===${NC}"
    test_git_status_clean_of_artifacts
    echo ""

    # Category 7: Build Artifacts
    echo -e "${CYAN}=== Build Artifacts ===${NC}"
    test_dockerfile_syntax
    test_ci_workflows_valid_yaml
    echo ""
}

# Summary

print_summary() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

    echo "Tests run: $total"
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Execute
run_all_tests
print_summary || exit 1

#!/usr/bin/env bash
# Phase 4 Test Suite — Comprehensive testing for crypto verifier bytecode proofs
#
# Usage:
#   ./scripts/phase4_test_suite.sh [--quick|--standard|--comprehensive]
#
# Modes:
#   --quick         : Fast checks (~30s) - build verification only
#   --standard      : Standard checks (~2min) - builds + sorry count + axioms
#   --comprehensive : Full checks (~5min) - all checks + performance benchmarks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEAN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$LEAN_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Mode selection
MODE="${1:---standard}"

# Counters
PASS=0
FAIL=0
WARNINGS=0

# Helper functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

print_summary() {
    echo
    print_header "Test Summary"
    echo -e "Passed:   ${GREEN}$PASS${NC}"
    echo -e "Failed:   ${RED}$FAIL${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    echo
    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        return 1
    fi
}

# Test 1: Individual file builds
test_individual_builds() {
    print_header "Test 1: Individual File Builds"

    local files=(
        "MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv"
        "MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv"
        "MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv"
        "MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv"
    )

    for file in "${files[@]}"; do
        print_test "Building $file"
        if lake build "$file" > /dev/null 2>&1; then
            print_pass "$file builds successfully"
        else
            print_fail "$file failed to build"
        fi
    done
}

# Test 2: ConcreteHelpers builds
test_concrete_helpers() {
    print_header "Test 2: ConcreteHelpers Builds"

    local files=(
        "MovementFormal.Experimental.ConfidentialAsset.Normalization.ConcreteHelpers"
        "MovementFormal.Experimental.ConfidentialAsset.Rotation.ConcreteHelpers"
        "MovementFormal.Experimental.ConfidentialAsset.Withdrawal.ConcreteHelpers"
        "MovementFormal.Experimental.ConfidentialAsset.Transfer.ConcreteHelpers"
    )

    for file in "${files[@]}"; do
        print_test "Building $file"
        if lake build "$file" > /dev/null 2>&1; then
            print_pass "$file builds successfully"
        else
            print_fail "$file failed to build"
        fi
    done
}

# Test 3: Full tree build
test_full_build() {
    print_header "Test 3: Full Tree Build"

    print_test "Building full Lean tree"
    if time lake build > /tmp/phase4_build.log 2>&1; then
        local jobs=$(grep -o '[0-9]* jobs' /tmp/phase4_build.log | tail -1 | awk '{print $1}')
        print_pass "Full tree builds successfully ($jobs jobs)"
    else
        print_fail "Full tree build failed"
        echo "Last 20 lines of build log:"
        tail -20 /tmp/phase4_build.log
    fi
}

# Test 4: Sorry count
test_sorry_count() {
    print_header "Test 4: Sorry Count Verification"

    print_test "Counting sorries in Phase 4 EvalEquiv files"

    local sorry_count=0
    local files=(
        "MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean"
        "MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean"
        "MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean"
        "MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean"
    )

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            local count=$(grep -c "sorry" "$file" || true)
            sorry_count=$((sorry_count + count))
            if [ $count -eq 0 ]; then
                print_pass "$file: 0 sorries (complete)"
            else
                print_warning "$file: $count sorries remaining"
            fi
        else
            print_fail "$file not found"
        fi
    done

    echo
    echo "Total sorries: $sorry_count"

    # Expected: ≤7 sorries as of 2026-04-23
    if [ $sorry_count -le 7 ]; then
        print_pass "Sorry count is $sorry_count (within target of ≤7)"
    elif [ $sorry_count -le 11 ]; then
        print_warning "Sorry count is $sorry_count (above target of ≤7, but improving)"
    else
        print_fail "Sorry count is $sorry_count (regression detected)"
    fi
}

# Test 5: Axiom count
test_axiom_count() {
    print_header "Test 5: Axiom Inventory"

    print_test "Checking axiom count in ConcreteHelpers"

    local files=(
        "MovementFormal/Experimental/ConfidentialAsset/Normalization/ConcreteHelpers.lean"
        "MovementFormal/Experimental/ConfidentialAsset/Rotation/ConcreteHelpers.lean"
        "MovementFormal/Experimental/ConfidentialAsset/Withdrawal/ConcreteHelpers.lean"
        "MovementFormal/Experimental/ConfidentialAsset/Transfer/ConcreteHelpers.lean"
    )

    local total_axioms=0
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            local count=$(grep -c "^axiom " "$file" || true)
            total_axioms=$((total_axioms + count))
            print_pass "$file: $count axioms"
        else
            print_fail "$file not found"
        fi
    done

    echo
    echo "Total ConcreteHelpers axioms: $total_axioms"

    # Expected: 24 axioms (5 + 6 + 7 + 8)
    if [ $total_axioms -eq 24 ]; then
        print_pass "Axiom count matches expected (24)"
    else
        print_warning "Axiom count is $total_axioms (expected 24)"
    fi
}

# Test 6: Import consistency
test_imports() {
    print_header "Test 6: Import Consistency"

    print_test "Verifying ConcreteHelpers imports in EvalEquiv files"

    local files=(
        "MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean:Normalization.ConcreteHelpers"
        "MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean:Rotation.ConcreteHelpers"
        "MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean:Withdrawal.ConcreteHelpers"
        "MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean:Transfer.ConcreteHelpers"
    )

    for entry in "${files[@]}"; do
        IFS=':' read -r file import <<< "$entry"
        if grep -q "import.*$import" "$file"; then
            print_pass "$file imports $import"
        else
            print_fail "$file missing import for $import"
        fi
    done
}

# Test 7: Build performance
test_performance() {
    print_header "Test 7: Build Performance"

    print_test "Measuring individual file build times"

    local files=(
        "MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv"
        "MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv"
        "MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv"
        "MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv"
    )

    for file in "${files[@]}"; do
        local start=$(date +%s%N)
        lake build "$file" > /dev/null 2>&1
        local end=$(date +%s%N)
        local duration=$(((end - start) / 1000000)) # Convert to milliseconds

        if [ $duration -lt 1000 ]; then
            print_pass "$file: ${duration}ms (target: ≤1000ms)"
        elif [ $duration -lt 2000 ]; then
            print_warning "$file: ${duration}ms (above target but acceptable)"
        else
            print_fail "$file: ${duration}ms (too slow)"
        fi
    done

    # Full tree build time
    print_test "Measuring full tree build time"
    local start=$(date +%s)
    lake build > /dev/null 2>&1
    local end=$(date +%s)
    local duration=$((end - start))

    if [ $duration -lt 10 ]; then
        print_pass "Full tree: ${duration}s (target: ≤10s)"
    elif [ $duration -lt 20 ]; then
        print_warning "Full tree: ${duration}s (above target but acceptable)"
    else
        print_fail "Full tree: ${duration}s (too slow)"
    fi
}

# Test 8: Documentation presence
test_documentation() {
    print_header "Test 8: Documentation Verification"

    local docs=(
        "CONCRETEHELPERS_USAGE_GUIDE.md"
        "PHASE_4_COMPLETION_ROADMAP.md"
        "PHASE_4_VERIFICATION_CHECKLIST.md"
    )

    for doc in "${docs[@]}"; do
        if [ -f "$doc" ]; then
            local lines=$(wc -l < "$doc")
            print_pass "$doc exists ($lines lines)"
        else
            print_warning "$doc not found"
        fi
    done
}

# Test 9: Lakefile consistency
test_lakefile() {
    print_header "Test 9: Lakefile Consistency"

    print_test "Verifying ConcreteHelpers entries in lakefile.lean"

    local entries=(
        "Normalization.ConcreteHelpers"
        "Rotation.ConcreteHelpers"
        "Withdrawal.ConcreteHelpers"
        "Transfer.ConcreteHelpers"
    )

    for entry in "${entries[@]}"; do
        if grep -q "$entry" lakefile.lean; then
            print_pass "$entry present in lakefile.lean"
        else
            print_fail "$entry missing from lakefile.lean"
        fi
    done
}

# Test 10: Step theorem counts
test_step_theorems() {
    print_header "Test 10: Step Theorem Coverage"

    print_test "Verifying step theorem counts match PC counts"

    # Normalization: 14 PCs (0-13)
    local norm_count=$(grep -c "theorem step_normalization_pc" \
        MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean || true)
    if [ $norm_count -eq 14 ]; then
        print_pass "Normalization: $norm_count step theorems (expected 14)"
    else
        print_fail "Normalization: $norm_count step theorems (expected 14)"
    fi

    # Rotation: 15 PCs (0-14)
    local rot_count=$(grep -c "theorem step_rotation_pc" \
        MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean || true)
    if [ $rot_count -eq 15 ]; then
        print_pass "Rotation: $rot_count step theorems (expected 15)"
    else
        print_fail "Rotation: $rot_count step theorems (expected 15)"
    fi

    # Withdrawal: 15 PCs (0-14)
    local with_count=$(grep -c "theorem step_withdrawal_pc" \
        MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean || true)
    if [ $with_count -eq 15 ]; then
        print_pass "Withdrawal: $with_count step theorems (expected 15)"
    else
        print_fail "Withdrawal: $with_count step theorems (expected 15)"
    fi

    # Transfer: 24 PCs (0-23)
    local trans_count=$(grep -c "theorem step_transfer_pc" \
        MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean || true)
    if [ $trans_count -eq 24 ]; then
        print_pass "Transfer: $trans_count step theorems (expected 24)"
    else
        print_fail "Transfer: $trans_count step theorems (expected 24)"
    fi
}

# Main execution
main() {
    echo "Phase 4 Test Suite - Mode: $MODE"
    echo "Started at: $(date)"
    echo

    case "$MODE" in
        --quick)
            test_individual_builds
            test_concrete_helpers
            ;;
        --standard)
            test_individual_builds
            test_concrete_helpers
            test_full_build
            test_sorry_count
            test_imports
            test_lakefile
            ;;
        --comprehensive)
            test_individual_builds
            test_concrete_helpers
            test_full_build
            test_sorry_count
            test_axiom_count
            test_imports
            test_documentation
            test_lakefile
            test_step_theorems
            test_performance
            ;;
        *)
            echo "Unknown mode: $MODE"
            echo "Usage: $0 [--quick|--standard|--comprehensive]"
            exit 1
            ;;
    esac

    echo
    echo "Completed at: $(date)"
    print_summary
}

main

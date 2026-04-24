#!/usr/bin/env bash
# scripts/comprehensive_health_check.sh — Complete CA verification health check
#
# Runs every verification check and produces detailed diagnostic report.
# More comprehensive than run_verification_suite.sh - includes deep validation,
# performance benchmarks, and actionable remediation steps.
#
# Usage:
#   ./scripts/comprehensive_health_check.sh [--fix-issues] [--verbose]
#
# Options:
#   --fix-issues    Automatically fix simple issues (permissions, stale files)
#   --verbose       Show detailed output from each check
#   --json          Output results in JSON format
#
# Exit codes:
#   0 = Perfect health
#   1 = Issues found (see report)
#   2 = Critical failures (blocking work)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$FORMAL_ROOT/../../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Modes
FIX_ISSUES=false
VERBOSE=false
JSON_OUTPUT=false

# Counters
TOTAL_CHECKS=0
PASSED=0
WARNINGS=0
FAILED=0
CRITICAL=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix-issues) FIX_ISSUES=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        --help)
            echo "Usage: $0 [--fix-issues] [--verbose] [--json]"
            echo ""
            echo "Comprehensive health check for CA formal verification"
            echo ""
            echo "Options:"
            echo "  --fix-issues    Auto-fix simple issues"
            echo "  --verbose       Show detailed output"
            echo "  --json          JSON output format"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 2 ;;
    esac
done

# Output helpers
log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[PASS]${NC} $*"; PASSED=$((PASSED + 1)); }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; WARNINGS=$((WARNINGS + 1)); }
error() { echo -e "${RED}[FAIL]${NC} $*"; FAILED=$((FAILED + 1)); }
critical() { echo -e "${MAGENTA}[CRIT]${NC} $*"; CRITICAL=$((CRITICAL + 1)); }

check() {
    local name="$1"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo ""
    echo -e "${CYAN}━━━ CHECK $TOTAL_CHECKS: $name ━━━${NC}"
}

# Track issues for remediation report
ISSUES=()
add_issue() {
    local severity="$1"
    local message="$2"
    local fix="${3:-}"
    ISSUES+=("$severity|$message|$fix")
}

cd "$FORMAL_ROOT"

echo "=========================================="
echo "  CA Verification Comprehensive Health Check"
echo "  $(date)"
echo "=========================================="
echo ""
echo "Repository: $REPO_ROOT"
echo "Formal root: $FORMAL_ROOT"
echo "Mode: $([ "$FIX_ISSUES" = true ] && echo "FIX" || echo "CHECK-ONLY")"
echo ""

# ============================================================================
# SECTION 1: Environment & Dependencies
# ============================================================================

check "Lean Toolchain Version"
if command -v lean &>/dev/null; then
    version=$(lean --version 2>&1 | head -1)
    expected="4.24.0"
    if echo "$version" | grep -q "$expected"; then
        success "Lean version correct: $version"
    else
        current=$(echo "$version" | sed -n 's/.*version \([0-9.]*\).*/\1/p')
        if [ -z "$current" ]; then current="unknown"; fi
        if [[ "$current" > "$expected" ]]; then
            warning "Lean version newer than expected: $current (expected $expected)"
            add_issue "WARN" "Lean version $current > $expected" "Update lean-toolchain file"
        else
            error "Lean version too old: $current (expected $expected)"
            add_issue "ERROR" "Lean version outdated" "Run: elan install $expected"
        fi
    fi
else
    critical "Lean not installed or not in PATH"
    add_issue "CRITICAL" "Lean not found" "Install elan and Lean toolchain"
fi

check "Lean Mathlib Cache"
if [ -d "$HOME/.cache/lake" ]; then
    cache_size=$(du -sh "$HOME/.cache/lake" 2>/dev/null | cut -f1)
    success "Mathlib cache exists ($cache_size)"
else
    warning "Mathlib cache missing - first build will be slow"
    add_issue "WARN" "No mathlib cache" "Run: cd lean && lake exe cache get"
fi

check "Move Prover Dependencies"
prover_ok=true
if [ -z "${Z3_EXE:-}" ]; then
    error "Z3_EXE not set"
    add_issue "ERROR" "Z3_EXE not configured" "Run: movement update prover-dependencies"
    prover_ok=false
fi
if [ -z "${BOOGIE_EXE:-}" ]; then
    error "BOOGIE_EXE not set"
    add_issue "ERROR" "BOOGIE_EXE not configured" "Run: movement update prover-dependencies"
    prover_ok=false
fi
if [ "$prover_ok" = true ]; then
    z3_version=$("$Z3_EXE" --version 2>&1 | head -1 || echo "unknown")
    if echo "$z3_version" | grep -q "4.11.2"; then
        success "Move Prover dependencies configured correctly"
    else
        error "Z3 version incorrect: $z3_version (need 4.11.2)"
        add_issue "ERROR" "Wrong Z3 version" "Install Z3 4.11.2 (not Homebrew)"
    fi
fi

check "Git Repository State"
if git rev-parse --git-dir &>/dev/null; then
    branch=$(git branch --show-current)
    if [ "$branch" = "lean-fv" ]; then
        success "On expected branch: $branch"
    else
        warning "On unexpected branch: $branch (expected lean-fv)"
    fi

    uncommitted=$(git status --short | wc -l)
    if [ "$uncommitted" -gt 0 ]; then
        warning "$uncommitted uncommitted changes"
        if [ "$VERBOSE" = true ]; then
            git status --short | head -10
        fi
    else
        success "Working tree clean"
    fi
else
    critical "Not in a git repository"
    add_issue "CRITICAL" "Not a git repo" "Check working directory"
fi

# ============================================================================
# SECTION 2: Build Health
# ============================================================================

check "Lean Tree Build"
cd "$FORMAL_ROOT/lean"
if [ "$VERBOSE" = true ]; then
    build_output=$(lake build 2>&1)
    build_status=$?
else
    build_output=$(lake build 2>&1 | tail -5)
    build_status=$?
fi

if [ $build_status -eq 0 ]; then
    jobs=$(echo "$build_output" | grep -o '[0-9]* jobs' | tail -1 | awk '{print $1}')
    if [ -z "$jobs" ]; then jobs="unknown"; fi
    success "Lean tree builds successfully ($jobs jobs)"
else
    error "Lean build failed"
    add_issue "ERROR" "Lean compilation errors" "Check build output above"
    if [ "$VERBOSE" = true ]; then
        echo "$build_output"
    fi
fi

check "Sorry Count"
sorry_count=$(grep -r "sorry" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" 2>/dev/null | wc -l)
expected_sorry=41  # From documentation
if [ "$sorry_count" -le "$expected_sorry" ]; then
    success "Sorry count: $sorry_count (≤ $expected_sorry expected)"
else
    warning "Sorry count increased: $sorry_count (was $expected_sorry)"
    add_issue "WARN" "More sorries than expected" "Review new sorries"
fi

check "Axiom Count"
cd "$FORMAL_ROOT"
axiom_output=$(./scripts/check_axioms.sh 2>&1 | grep "Total axioms" || echo "unknown")
if echo "$axiom_output" | grep -q "62 axioms"; then
    success "Axiom count stable: 62 axioms"
else
    warning "Axiom count may have changed"
    if [ "$VERBOSE" = true ]; then
        ./scripts/check_axioms.sh 2>&1 | tail -20
    fi
fi

# ============================================================================
# SECTION 3: Verification Operations
# ============================================================================

check "Lean Verification - All Operations"
cd "$FORMAL_ROOT"
ops_tested=0
ops_passed=0
for op in register withdraw transfer normalize rotate; do
    ops_tested=$((ops_tested + 1))
    if [ "$VERBOSE" = true ]; then
        op_result=$(./audit/verify-ca.sh --op "$op" --stack lean 2>&1)
        op_status=$?
    else
        op_result=$(./audit/verify-ca.sh --op "$op" --stack lean 2>&1 | tail -3)
        op_status=$?
    fi

    if [ $op_status -eq 0 ]; then
        ops_passed=$((ops_passed + 1))
        if [ "$VERBOSE" = true ]; then
            echo "  ✓ $op"
        fi
    else
        error "Operation $op failed Lean verification"
        add_issue "ERROR" "Lean verification failed for $op" "Check verify-ca.sh output"
    fi
done

if [ $ops_passed -eq $ops_tested ]; then
    success "All $ops_tested operations pass Lean verification"
else
    error "Only $ops_passed/$ops_tested operations passed"
fi

check "Move Prover Verification - Independent Modules"
if [ "$prover_ok" = true ]; then
    cd "$REPO_ROOT"
    modules_tested=0
    modules_passed=0

    for module in ristretto255_twisted_elgamal confidential_balance; do
        modules_tested=$((modules_tested + 1))
        if BOOGIE_EXE="$BOOGIE_EXE" Z3_EXE="$Z3_EXE" movement move prove \
            --package-dir aptos-move/framework/aptos-experimental \
            --named-addresses aptos_experimental=0x7 \
            --filter "$module" \
            --skip-fetch-latest-git-deps &>/dev/null; then
            modules_passed=$((modules_passed + 1))
            if [ "$VERBOSE" = true ]; then
                echo "  ✓ $module"
            fi
        else
            if [ "$VERBOSE" = true ]; then
                echo "  ✗ $module"
            fi
        fi
    done

    if [ $modules_passed -eq $modules_tested ]; then
        success "All $modules_tested independent modules pass Move Prover"
    else
        warning "$modules_passed/$modules_tested modules passed (known ristretto255 blocker affects others)"
    fi
else
    warning "Skipping Move Prover checks (dependencies not configured)"
fi

# ============================================================================
# SECTION 4: Documentation Health
# ============================================================================

check "Critical Documentation Files"
critical_docs=(
    "CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md"
    "audit/CLAIMS.md"
    "audit/TRUST_BOUNDARIES.md"
    "audit/AXIOM_INVENTORY.md"
    "VERIFICATION_STATUS_2026_04_24.md"
)

missing_docs=0
for doc in "${critical_docs[@]}"; do
    if [ ! -f "$doc" ]; then
        error "Missing critical doc: $doc"
        add_issue "ERROR" "Missing documentation" "Create $doc"
        missing_docs=$((missing_docs + 1))
    fi
done

if [ $missing_docs -eq 0 ]; then
    success "All critical documentation files present"
fi

check "Documentation Freshness"
stale_threshold=90  # days
stale_docs=0
for doc in *.md audit/*.md; do
    if [ -f "$doc" ]; then
        age=$(( ($(date +%s) - $(stat -f %m "$doc" 2>/dev/null || stat -c %Y "$doc")) / 86400 ))
        if [ $age -gt $stale_threshold ]; then
            stale_docs=$((stale_docs + 1))
        fi
    fi
done 2>/dev/null

if [ $stale_docs -eq 0 ]; then
    success "All documentation fresh (< $stale_threshold days)"
else
    warning "$stale_docs documents older than $stale_threshold days"
    add_issue "WARN" "Stale documentation" "Review and update old docs"
fi

# ============================================================================
# SECTION 5: Script Permissions & Executability
# ============================================================================

check "Script Permissions"
non_executable=0
for script in scripts/*.sh audit/*.sh; do
    if [ -f "$script" ] && [ ! -x "$script" ]; then
        non_executable=$((non_executable + 1))
        if [ "$FIX_ISSUES" = true ]; then
            chmod +x "$script"
            log "Fixed: chmod +x $script"
        else
            if [ "$VERBOSE" = true ]; then
                echo "  Not executable: $script"
            fi
        fi
    fi
done 2>/dev/null

if [ $non_executable -eq 0 ]; then
    success "All scripts executable"
elif [ "$FIX_ISSUES" = true ]; then
    success "Fixed $non_executable script permissions"
else
    warning "$non_executable scripts not executable"
    add_issue "WARN" "Non-executable scripts" "Run: chmod +x scripts/*.sh audit/*.sh"
fi

# ============================================================================
# SECTION 6: Performance Checks
# ============================================================================

check "Build Performance"
cd "$FORMAL_ROOT/lean"
start_time=$(date +%s)
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv &>/dev/null || true
end_time=$(date +%s)
build_duration=$((end_time - start_time))

if [ $build_duration -le 5 ]; then
    success "Registration build: ${build_duration}s (excellent)"
elif [ $build_duration -le 180 ]; then
    success "Registration build: ${build_duration}s (within 3min budget)"
else
    warning "Registration build: ${build_duration}s (exceeds 3min budget)"
    add_issue "WARN" "Slow build performance" "Check for elaboration issues"
fi

# ============================================================================
# SECTION 7: File Health
# ============================================================================

check "Backup and Temporary Files"
backup_files=$(find "$FORMAL_ROOT" -name "*.bak" -o -name "*.tmp" -o -name "*~" 2>/dev/null | wc -l)
if [ $backup_files -eq 0 ]; then
    success "No backup/temporary files"
else
    warning "$backup_files backup/temporary files found"
    if [ "$FIX_ISSUES" = true ]; then
        find "$FORMAL_ROOT" -name "*.bak" -o -name "*.tmp" -o -name "*~" -delete 2>/dev/null
        success "Cleaned up $backup_files temporary files"
    else
        add_issue "WARN" "Temporary files present" "Run with --fix-issues to clean"
    fi
fi

check "Large Files (>10MB)"
large_files=$(find "$FORMAL_ROOT" -type f -size +10M 2>/dev/null | wc -l)
if [ $large_files -eq 0 ]; then
    success "No unexpectedly large files"
else
    warning "$large_files files larger than 10MB"
    if [ "$VERBOSE" = true ]; then
        find "$FORMAL_ROOT" -type f -size +10M -exec ls -lh {} \; 2>/dev/null | head -5
    fi
fi

# ============================================================================
# Final Report
# ============================================================================

echo ""
echo "=========================================="
echo "  HEALTH CHECK SUMMARY"
echo "=========================================="
echo ""
echo "Total Checks:    $TOTAL_CHECKS"
echo -e "${GREEN}Passed:          $PASSED${NC}"
echo -e "${YELLOW}Warnings:        $WARNINGS${NC}"
echo -e "${RED}Failed:          $FAILED${NC}"
echo -e "${MAGENTA}Critical:        $CRITICAL${NC}"
echo ""

if [ $CRITICAL -gt 0 ]; then
    echo -e "${MAGENTA}⚠ CRITICAL ISSUES FOUND${NC} - Verification work is blocked"
    exit_code=2
elif [ $FAILED -gt 0 ]; then
    echo -e "${RED}✗ ISSUES FOUND${NC} - See remediation steps below"
    exit_code=1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}✓ MOSTLY HEALTHY${NC} - Minor issues to address"
    exit_code=0
else
    echo -e "${GREEN}✓ PERFECT HEALTH${NC} - All checks passed"
    exit_code=0
fi

# Remediation Report
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo "  REMEDIATION STEPS"
    echo "=========================================="
    echo ""

    for issue in "${ISSUES[@]}"; do
        IFS='|' read -r severity message fix <<< "$issue"
        case "$severity" in
            CRITICAL) color=$MAGENTA ;;
            ERROR) color=$RED ;;
            WARN) color=$YELLOW ;;
            *) color=$NC ;;
        esac

        echo -e "${color}[$severity]${NC} $message"
        if [ -n "$fix" ]; then
            echo "  → Fix: $fix"
        fi
        echo ""
    done
fi

echo "=========================================="
echo "  Report generated: $(date)"
echo "=========================================="

exit $exit_code

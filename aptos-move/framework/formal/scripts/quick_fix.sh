#!/usr/bin/env bash
# scripts/quick_fix.sh — Quick fixes for common verification issues
#
# Automatically diagnoses and fixes common verification problems.
# Runs a series of checks and applies fixes where possible.
#
# Usage:
#   ./scripts/quick_fix.sh [--dry-run] [--verbose]
#   ./scripts/quick_fix.sh --help
#
# Exit codes:
#   0 = All issues fixed or no issues found
#   1 = Some issues could not be auto-fixed
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
DRY_RUN=false
VERBOSE=false
FIXES_APPLIED=0
FIXES_FAILED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            cat <<EOF
Usage: $0 [--dry-run] [--verbose]

Options:
  --dry-run  : Show what would be fixed without applying changes
  --verbose  : Show detailed output
  --help     : Show this help

Quick fixes for common issues:
  1. Missing mathlib cache
  2. Corrupted build artifacts
  3. Stale git artifacts
  4. Missing executable permissions
  5. Outdated baselines

Examples:
  # Dry-run to see what would be fixed
  $0 --dry-run

  # Apply fixes
  $0

  # Verbose output
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

# Helper functions
log() {
    if [ "$VERBOSE" = true ]; then
        echo "$@"
    fi
}

fix_start() {
    local name="$1"
    echo -ne "${BLUE}[FIX]${NC} $name... "
}

fix_success() {
    FIXES_APPLIED=$((FIXES_APPLIED + 1))
    echo -e "${GREEN}✓ Fixed${NC}"
}

fix_skip() {
    local reason="$1"
    echo -e "${YELLOW}⊘ Skipped${NC} - $reason"
}

fix_fail() {
    local reason="$1"
    FIXES_FAILED=$((FIXES_FAILED + 1))
    echo -e "${RED}✗ Failed${NC} - $reason"
}

# Fix 1: Missing mathlib cache
fix_mathlib_cache() {
    fix_start "Checking mathlib cache"

    if [ ! -d "lean/.lake/build/lib" ] || [ -z "$(ls -A lean/.lake/build/lib 2>/dev/null)" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN]${NC} Would fetch mathlib cache"
            fix_success
        else
            log "Fetching mathlib cache..."
            cd lean
            if lake exe cache get > /tmp/quick_fix_cache.log 2>&1; then
                cd ..
                fix_success
            else
                cd ..
                fix_fail "Cache fetch failed (see /tmp/quick_fix_cache.log)"
            fi
        fi
    else
        fix_skip "Cache already present"
    fi
}

# Fix 2: Corrupted build artifacts
fix_corrupted_artifacts() {
    fix_start "Checking for corrupted artifacts"

    # Simple heuristic: if .lake/build exists but no .olean files, likely corrupted
    if [ -d "lean/.lake/build" ]; then
        local olean_count=$(find lean/.lake/build -name "*.olean" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$olean_count" -lt 10 ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "${CYAN}[DRY-RUN]${NC} Would clean and rebuild"
                fix_success
            else
                log "Cleaning build artifacts..."
                cd lean
                lake clean > /dev/null 2>&1
                cd ..
                fix_success
            fi
        else
            fix_skip "Artifacts look healthy"
        fi
    else
        fix_skip "No build artifacts found"
    fi
}

# Fix 3: Stale git artifacts
fix_stale_git_artifacts() {
    fix_start "Checking for stale git artifacts"

    local stale_files=()

    # Check for boogie.bpl
    if [ -f "boogie.bpl" ]; then
        stale_files+=("boogie.bpl")
    fi

    # Check for .log files
    while IFS= read -r -d '' file; do
        stale_files+=("$file")
    done < <(find . -maxdepth 2 -name "*.log" -type f -print0 2>/dev/null)

    if [ ${#stale_files[@]} -gt 0 ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY-RUN]${NC} Would remove: ${stale_files[*]}"
            fix_success
        else
            log "Removing stale files: ${stale_files[*]}"
            rm -f "${stale_files[@]}"
            fix_success
        fi
    else
        fix_skip "No stale artifacts found"
    fi
}

# Fix 4: Missing executable permissions
fix_script_permissions() {
    fix_start "Checking script permissions"

    local fixed=0
    for script in scripts/*.sh audit/*.sh; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            if [ "$DRY_RUN" = true ]; then
                log "Would chmod +x $script"
                fixed=$((fixed + 1))
            else
                chmod +x "$script"
                log "Fixed: $script"
                fixed=$((fixed + 1))
            fi
        fi
    done

    if [ $fixed -gt 0 ]; then
        fix_success
    else
        fix_skip "All scripts executable"
    fi
}

# Fix 5: Outdated baselines (informational only)
check_baselines() {
    fix_start "Checking baseline freshness"

    local needs_update=false

    # Check axiom baseline
    if [ -f "audit/axiom-baseline.txt" ]; then
        local current_axioms=$(./scripts/check_axioms.sh --baseline 2>/dev/null | grep -c "^axiom" || echo 0)
        local baseline_axioms=$(grep -c "^axiom" audit/axiom-baseline.txt || echo 0)

        if [ "$current_axioms" -ne "$baseline_axioms" ]; then
            needs_update=true
        fi
    fi

    if [ "$needs_update" = true ]; then
        echo -e "${YELLOW}⚠ INFO${NC} - Baselines may need update"
        echo "  Run: ./scripts/check_axioms.sh > audit/axiom-baseline.txt"
    else
        fix_skip "Baselines current"
    fi
}

# Main
main() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  CA Verification Quick Fix${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}  Mode: DRY-RUN${NC}"
    fi
    echo -e "${BLUE}  $(date)${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    fix_mathlib_cache
    fix_corrupted_artifacts
    fix_stale_git_artifacts
    fix_script_permissions
    check_baselines

    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Summary${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "  Fixes applied: ${GREEN}$FIXES_APPLIED${NC}"
    echo -e "  Fixes failed:  ${RED}$FIXES_FAILED${NC}"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}Dry-run complete. Re-run without --dry-run to apply fixes.${NC}"
    elif [ "$FIXES_APPLIED" -gt 0 ]; then
        echo -e "${GREEN}✅ Quick fixes applied successfully${NC}"
        echo ""
        echo "Recommended next step:"
        echo "  ./scripts/run_verification_suite.sh --quick"
    elif [ "$FIXES_FAILED" -gt 0 ]; then
        echo -e "${RED}❌ Some fixes could not be applied${NC}"
        echo ""
        echo "Review failures above and address manually."
        exit 1
    else
        echo -e "${GREEN}✅ No issues found${NC}"
    fi
}

main "$@"

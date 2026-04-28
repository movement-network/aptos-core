#!/usr/bin/env bash
# scripts/cleanup_verification_artifacts.sh — Clean up verification artifacts
#
# Removes build artifacts, temporary files, and stale verification outputs.
# Helps recover disk space and fix corrupted build states.
#
# Usage:
#   ./scripts/cleanup_verification_artifacts.sh [--aggressive] [--dry-run]
#   ./scripts/cleanup_verification_artifacts.sh --help
#
# Exit codes:
#   0 = Cleanup completed successfully
#   1 = Cleanup failed
#   2 = Usage error

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FORMAL_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
AGGRESSIVE=false
DRY_RUN=false
TOTAL_SIZE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --aggressive)
            AGGRESSIVE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            cat <<EOF
Usage: $0 [--aggressive] [--dry-run]

Options:
  --aggressive : Also remove Lean build cache (will require rebuild)
  --dry-run    : Show what would be removed without removing
  --help       : Show this help

Cleans up verification artifacts:
  - Standard: Temporary files, logs, stale artifacts
  - Aggressive: Also removes Lean build cache

Examples:
  # Standard cleanup
  $0

  # See what would be removed
  $0 --dry-run

  # Aggressive cleanup (removes build cache)
  $0 --aggressive
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            exit 2
            ;;
    esac
done

# Helper: calculate size and optionally remove
cleanup() {
    local path="$1"
    local description="$2"

    if [ -e "$path" ]; then
        local size=$(du -sh "$path" 2>/dev/null | cut -f1)

        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}Would remove:${NC} $description ($size)"
        else
            echo -e "${BLUE}Removing:${NC} $description ($size)"
            rm -rf "$path"
        fi

        # Approximate size tracking (convert to bytes roughly)
        local size_mb=$(du -sm "$path" 2>/dev/null | cut -f1 || echo 0)
        TOTAL_SIZE=$((TOTAL_SIZE + size_mb))
    fi
}

# Main cleanup
main() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Verification Artifacts Cleanup${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}  Mode: DRY-RUN${NC}"
    fi
    if [ "$AGGRESSIVE" = true ]; then
        echo -e "${BLUE}  Mode: AGGRESSIVE${NC}"
    fi
    echo -e "${BLUE}  $(date)${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    # Standard cleanup
    echo -e "${CYAN}=== Standard Cleanup ===${NC}"

    # Temporary files
    cleanup "/tmp/lean_*.log" "Lean temporary logs"
    cleanup "/tmp/move_*.log" "Move Prover temporary logs"
    cleanup "/tmp/verification_*.log" "Verification suite logs"
    cleanup "/tmp/integration_*.log" "Integration test logs"
    cleanup "/tmp/*_test.log" "Test logs"
    cleanup "/tmp/monitor_*.log" "Monitoring logs"
    cleanup "/tmp/quick_fix_*.log" "Quick fix logs"

    # Stale artifacts in formal root
    cleanup "boogie.bpl" "Boogie intermediate file"
    cleanup "*.log" "Log files in formal root"
    cleanup ".DS_Store" "macOS metadata"

    # Lean build intermediates (not the full cache)
    cleanup "lean/.lake/packages/*/build/**/*.trace" "Lean trace files"

    # Reports that are old (>90 days)
    if [ -d "reports" ]; then
        find reports -type f -mtime +90 2>/dev/null | while read -r old_report; do
            cleanup "$old_report" "Old report: $(basename "$old_report")"
        done
    fi

    # Aggressive cleanup
    if [ "$AGGRESSIVE" = true ]; then
        echo ""
        echo -e "${CYAN}=== Aggressive Cleanup ===${NC}"
        echo -e "${YELLOW}Warning: This will remove Lean build cache${NC}"
        echo -e "${YELLOW}You will need to run: cd lean && lake exe cache get && lake build${NC}"
        echo ""

        cleanup "lean/.lake/build" "Lean build cache"
        cleanup "lean/.lake/packages" "Lean packages cache"
    fi

    # Summary
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Cleanup Summary${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo "  Approximate space recovered: ${TOTAL_SIZE}MB"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}Dry-run complete. Re-run without --dry-run to actually remove.${NC}"
    elif [ "$AGGRESSIVE" = true ]; then
        echo -e "${GREEN}✅ Aggressive cleanup complete${NC}"
        echo ""
        echo "Next steps:"
        echo "  cd lean"
        echo "  lake exe cache get"
        echo "  lake build"
    else
        echo -e "${GREEN}✅ Standard cleanup complete${NC}"
        echo ""
        echo "For more aggressive cleanup (removes build cache):"
        echo "  $0 --aggressive"
    fi
}

main "$@"

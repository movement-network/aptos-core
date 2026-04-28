#!/usr/bin/env bash
# scripts/watch_verification.sh — Watch mode for continuous verification
#
# Monitors file changes and automatically re-runs verification when files change.
# Useful for development workflow - edit code, save, see results immediately.
#
# Usage:
#   ./scripts/watch_verification.sh [--operation OP] [--stack STACK]
#   ./scripts/watch_verification.sh --help
#
# Requires: inotify-tools (Linux) or fswatch (macOS)
#
# Exit codes:
#   0 = Watch terminated normally (Ctrl+C)
#   2 = Usage error or prerequisites missing

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
OPERATION=""
STACK=""
WATCH_PATHS=("lean/" "../aptos-experimental/sources/confidential_asset/")

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --operation)
            OPERATION="$2"
            shift 2
            ;;
        --stack)
            STACK="$2"
            shift 2
            ;;
        --help)
            cat <<EOF
Usage: $0 [--operation OP] [--stack STACK]

Options:
  --operation OP : Watch specific operation (register|withdraw|transfer|normalize|rotate)
  --stack STACK  : Watch specific stack (lean|move-prover|difftest)
  --help         : Show this help

Watch mode monitors file changes and automatically re-runs verification.
Press Ctrl+C to stop.

Examples:
  # Watch all operations, all stacks
  $0

  # Watch only register operation
  $0 --operation register

  # Watch only Lean stack
  $0 --stack lean

  # Watch register on Lean stack only
  $0 --operation register --stack lean

Requirements:
  - macOS: brew install fswatch
  - Linux: apt-get install inotify-tools
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            exit 2
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v fswatch &> /dev/null; then
            echo -e "${RED}Error:${NC} fswatch not found"
            echo "Install with: brew install fswatch"
            exit 2
        fi
    else
        if ! command -v inotifywait &> /dev/null; then
            echo -e "${RED}Error:${NC} inotify-tools not found"
            echo "Install with: apt-get install inotify-tools"
            exit 2
        fi
    fi
}

# Run verification
run_verification() {
    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  CA Verification Watch Mode${NC}"
    echo -e "${BLUE}  $(date)${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    local cmd="./audit/verify-ca.sh"

    if [ -n "$OPERATION" ]; then
        cmd="$cmd --op $OPERATION"
    fi

    if [ -n "$STACK" ]; then
        cmd="$cmd --stack $STACK"
    fi

    echo -e "${CYAN}Running: $cmd${NC}"
    echo ""

    local start=$(date +%s)
    if $cmd; then
        local end=$(date +%s)
        local duration=$((end - start))
        echo ""
        echo -e "${GREEN}✅ Verification passed${NC} (${duration}s)"
    else
        local end=$(date +%s)
        local duration=$((end - start))
        echo ""
        echo -e "${RED}❌ Verification failed${NC} (${duration}s)"
    fi

    echo ""
    echo -e "${YELLOW}Watching for changes... (Ctrl+C to stop)${NC}"
}

# Watch for changes
watch_changes() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use fswatch
        fswatch -o "${WATCH_PATHS[@]}" | while read -r; do
            run_verification
        done
    else
        # Linux: use inotifywait
        while inotifywait -r -e modify,create,delete "${WATCH_PATHS[@]}"; do
            run_verification
        done
    fi
}

# Main
main() {
    check_prerequisites

    echo -e "${CYAN}Starting watch mode...${NC}"
    echo ""
    echo "Configuration:"
    echo "  Operation: ${OPERATION:-all}"
    echo "  Stack: ${STACK:-all}"
    echo "  Watching: ${WATCH_PATHS[*]}"
    echo ""
    echo "Press Ctrl+C to stop"
    echo ""

    # Initial run
    run_verification

    # Watch for changes
    watch_changes
}

# Trap Ctrl+C
trap 'echo ""; echo "Watch mode stopped"; exit 0' SIGINT SIGTERM

main "$@"

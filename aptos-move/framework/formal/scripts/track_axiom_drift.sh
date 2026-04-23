#!/usr/bin/env bash
# scripts/track_axiom_drift.sh — Track axiom count changes over time
#
# Purpose: Monitor axiom drift across git commits to catch accidental axiom additions.
# Logs axiom counts to timestamped files for trend analysis.
#
# Usage:
#   ./scripts/track_axiom_drift.sh                    # Log current axiom count
#   ./scripts/track_axiom_drift.sh --compare HEAD~5   # Compare against 5 commits ago
#   ./scripts/track_axiom_drift.sh --history 30       # Show 30-day trend
#   ./scripts/track_axiom_drift.sh --alert 28         # Alert if count exceeds threshold
#
# Output: Logs to audit/axiom-tracking/<date>.txt, alerts if drift detected

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$FORMAL_ROOT/../../.." && pwd)"
cd "$FORMAL_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
TRACKING_DIR="$FORMAL_ROOT/audit/axiom-tracking"
COMPARE_REF=""
SHOW_HISTORY_DAYS=0
ALERT_THRESHOLD=0
ACTION="log"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Track axiom count changes over time to detect drift.

Options:
  --compare <ref>        Compare current count against git ref (e.g., HEAD~5, main)
  --history <days>       Show axiom trend for last N days
  --alert <count>        Alert (exit 1) if total axiom count exceeds threshold
  --baseline             Update baseline file (audit/axiom-baseline.txt)
  -h, --help             Show this help

Examples:
  # Log current axiom count (run daily via cron)
  $0

  # Compare against 5 commits ago
  $0 --compare HEAD~5

  # Show 30-day trend
  $0 --history 30

  # Alert if count exceeds 28 (target: ≤22 permanent + ≤6 temporary)
  $0 --alert 28

  # Update baseline after approved axiom addition
  $0 --baseline

Tracking directory: $TRACKING_DIR
Baseline file: audit/axiom-baseline.txt
EOF
}

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --compare)
            COMPARE_REF="$2"
            ACTION="compare"
            shift 2
            ;;
        --history)
            SHOW_HISTORY_DAYS="$2"
            ACTION="history"
            shift 2
            ;;
        --alert)
            ALERT_THRESHOLD="$2"
            ACTION="alert"
            shift 2
            ;;
        --baseline)
            ACTION="baseline"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option '$1'${NC}" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Ensure tracking directory exists
mkdir -p "$TRACKING_DIR"

# ============================================================================
# Helper: Get axiom count from current state
# ============================================================================

get_current_axiom_count() {
    local total=0
    local temporary=0
    local crypto=0
    local kernel=0
    local native=0

    # Run check_axioms.sh and parse output
    if [ -f "$FORMAL_ROOT/scripts/check_axioms.sh" ]; then
        local output
        output=$("$FORMAL_ROOT/scripts/check_axioms.sh" 2>/dev/null || echo "error")

        total=$(echo "$output" | grep -oP 'Total:\s+\K\d+' || echo "0")
        temporary=$(echo "$output" | grep -c 'TEMPORARY' || echo "0")
        crypto=$(echo "$output" | grep -c 'CRYPTO' || echo "0")
        kernel=$(echo "$output" | grep -c 'KERNEL' || echo "0")
        native=$(echo "$output" | grep -c 'NATIVE' || echo "0")
    fi

    echo "$total $temporary $crypto $kernel $native"
}

# ============================================================================
# Helper: Get axiom count from git ref
# ============================================================================

get_axiom_count_at_ref() {
    local ref="$1"
    local temp_dir
    temp_dir=$(mktemp -d)

    # Checkout ref to temp location
    git archive "$ref" | tar -x -C "$temp_dir" 2>/dev/null || {
        echo "0 0 0 0 0"
        rm -rf "$temp_dir"
        return 1
    }

    # Run check_axioms.sh from that ref
    local total=0
    if [ -f "$temp_dir/aptos-move/framework/formal/scripts/check_axioms.sh" ]; then
        cd "$temp_dir/aptos-move/framework/formal"
        total=$(bash scripts/check_axioms.sh 2>/dev/null | grep -oP 'Total:\s+\K\d+' || echo "0")
        cd "$FORMAL_ROOT"
    fi

    rm -rf "$temp_dir"
    echo "$total 0 0 0 0"  # Only return total for historical comparison
}

# ============================================================================
# Action: Log current count
# ============================================================================

if [ "$ACTION" = "log" ]; then
    read -r total temp crypto kernel native <<< "$(get_current_axiom_count)"

    timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    log_file="$TRACKING_DIR/${timestamp}.txt"

    cat > "$log_file" <<EOF
# Axiom Count — $timestamp
# Git commit: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
# Git branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

total=$total
temporary=$temp
crypto=$crypto
kernel=$kernel
native=$native
EOF

    echo -e "${GREEN}✅ Logged axiom count to $log_file${NC}"
    echo "Total: $total (TEMPORARY: $temp, CRYPTO: $crypto, KERNEL: $kernel, NATIVE: $native)"

    # Alert if count exceeds target (22 permanent + reasonable temporary)
    if [ "$total" -gt 28 ]; then
        echo -e "${YELLOW}⚠️  WARNING: Total axiom count ($total) exceeds expected range (≤28)${NC}"
        echo "   Target: ≤22 permanent + ≤6 temporary"
        echo "   Current: $((total - temp)) permanent + $temp temporary"
    fi

# ============================================================================
# Action: Compare against git ref
# ============================================================================

elif [ "$ACTION" = "compare" ]; then
    echo -e "${BLUE}Comparing axiom counts...${NC}"
    echo ""

    # Current count
    read -r current_total current_temp _ _ _ <<< "$(get_current_axiom_count)"

    # Historical count
    read -r past_total _ _ _ _ <<< "$(get_axiom_count_at_ref "$COMPARE_REF")"

    if [ "$past_total" -eq 0 ]; then
        echo -e "${RED}ERROR: Could not retrieve axiom count from $COMPARE_REF${NC}"
        exit 1
    fi

    diff=$((current_total - past_total))

    echo "Axiom count comparison:"
    echo "  $COMPARE_REF: $past_total"
    echo "  HEAD:         $current_total (TEMPORARY: $current_temp)"
    echo ""

    if [ "$diff" -gt 0 ]; then
        echo -e "${RED}❌ DRIFT DETECTED: +$diff axioms added${NC}"
        echo ""
        echo "Action required:"
        echo "  1. Review axiom additions via: git diff $COMPARE_REF..HEAD"
        echo "  2. Ensure additions are documented in AXIOM_INVENTORY.md"
        echo "  3. If approved, update baseline: $0 --baseline"
        exit 1
    elif [ "$diff" -lt 0 ]; then
        echo -e "${GREEN}✅ IMPROVEMENT: $((diff * -1)) axioms eliminated${NC}"
        echo ""
        echo "Consider updating baseline: $0 --baseline"
    else
        echo -e "${GREEN}✅ NO DRIFT: Axiom count unchanged${NC}"
    fi

# ============================================================================
# Action: Show history trend
# ============================================================================

elif [ "$ACTION" = "history" ]; then
    echo -e "${BLUE}Axiom Count Trend (Last $SHOW_HISTORY_DAYS Days)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Find log files from last N days
    cutoff_date=$(date -v -${SHOW_HISTORY_DAYS}d +%Y-%m-%d 2>/dev/null || date -d "${SHOW_HISTORY_DAYS} days ago" +%Y-%m-%d)

    found_logs=false
    for log in "$TRACKING_DIR"/*.txt; do
        [ -f "$log" ] || continue

        log_date=$(basename "$log" | cut -d_ -f1)
        if [[ "$log_date" > "$cutoff_date" ]] || [[ "$log_date" == "$cutoff_date" ]]; then
            total=$(grep '^total=' "$log" | cut -d= -f2)
            temp=$(grep '^temporary=' "$log" | cut -d= -f2)

            printf "%-20s Total: %-3s (TEMPORARY: %-2s)\n" "$log_date" "$total" "$temp"
            found_logs=true
        fi
    done

    if [ "$found_logs" = false ]; then
        echo "No tracking logs found in last $SHOW_HISTORY_DAYS days"
        echo ""
        echo "Start logging with: $0"
        echo "Set up daily cron: 0 0 * * * cd $FORMAL_ROOT && ./scripts/track_axiom_drift.sh"
    fi

# ============================================================================
# Action: Alert if threshold exceeded
# ============================================================================

elif [ "$ACTION" = "alert" ]; then
    read -r total temp _ _ _ <<< "$(get_current_axiom_count)"

    if [ "$total" -gt "$ALERT_THRESHOLD" ]; then
        echo -e "${RED}❌ ALERT: Axiom count ($total) exceeds threshold ($ALERT_THRESHOLD)${NC}"
        echo ""
        echo "Current breakdown:"
        echo "  Total:     $total"
        echo "  TEMPORARY: $temp"
        echo "  Permanent: $((total - temp))"
        echo ""
        echo "Target: ≤22 permanent axioms + minimal TEMPORARY"
        echo ""
        echo "Review with: ./scripts/check_axioms.sh"
        exit 1
    else
        echo -e "${GREEN}✅ Axiom count ($total) within threshold ($ALERT_THRESHOLD)${NC}"
        echo "  TEMPORARY: $temp"
        echo "  Permanent: $((total - temp))"
    fi

# ============================================================================
# Action: Update baseline
# ============================================================================

elif [ "$ACTION" = "baseline" ]; then
    echo -e "${BLUE}Updating axiom baseline...${NC}"

    baseline_file="$FORMAL_ROOT/audit/axiom-baseline.txt"

    if [ -f "$FORMAL_ROOT/scripts/check_axioms.sh" ]; then
        "$FORMAL_ROOT/scripts/check_axioms.sh" > "$baseline_file"
        echo -e "${GREEN}✅ Baseline updated: $baseline_file${NC}"
        echo ""
        echo "Commit this change with:"
        echo "  git add $baseline_file"
        echo "  git commit -m 'Update axiom baseline (approved addition documented in AXIOM_INVENTORY.md)'"
    else
        echo -e "${RED}ERROR: check_axioms.sh not found${NC}"
        exit 1
    fi

fi

exit 0

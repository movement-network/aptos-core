#!/usr/bin/env bash
# scripts/performance_dashboard.sh — Performance metrics dashboard for CA verification
#
# Tracks and displays build times, proof times, verification suite performance,
# and trends over time. Useful for detecting regressions and optimizing workflows.
#
# Usage:
#   ./scripts/performance_dashboard.sh [--format text|json|html]
#   ./scripts/performance_dashboard.sh --benchmark [--save baseline.json]
#   ./scripts/performance_dashboard.sh --compare baseline.json current.json
#   ./scripts/performance_dashboard.sh --trend [--days 30]
#
# Modes:
#   (default)      : Display current performance dashboard
#   --benchmark    : Run full benchmark suite and optionally save
#   --compare A B  : Compare two benchmark results
#   --trend        : Show performance trends over time
#
# Exit codes:
#   0 = Success
#   1 = Performance regression detected (in compare mode)
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
FORMAT="text"
MODE="dashboard"
BENCHMARK_SAVE=""
COMPARE_A=""
COMPARE_B=""
TREND_DAYS=30

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --benchmark)
            MODE="benchmark"
            shift
            ;;
        --save)
            BENCHMARK_SAVE="$2"
            shift 2
            ;;
        --compare)
            MODE="compare"
            COMPARE_A="$2"
            COMPARE_B="$3"
            shift 3
            ;;
        --trend)
            MODE="trend"
            shift
            ;;
        --days)
            TREND_DAYS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--format text|json|html] [--benchmark [--save file]] [--compare A B] [--trend]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

# Helper: run and time a command
time_command() {
    local name="$1"
    shift
    local start=$(date +%s.%N)
    "$@" > /dev/null 2>&1 || true
    local end=$(date +%s.%N)
    echo "$end - $start" | bc
}

# Helper: format duration
format_duration() {
    local seconds=$1
    if (( $(echo "$seconds < 1" | bc -l) )); then
        echo "${seconds}s"
    elif (( $(echo "$seconds < 60" | bc -l) )); then
        printf "%.2fs" "$seconds"
    else
        local mins=$(echo "$seconds / 60" | bc)
        local secs=$(echo "$seconds % 60" | bc)
        echo "${mins}m${secs}s"
    fi
}

# Dashboard mode: display current performance metrics
show_dashboard() {
    if [ "$FORMAT" = "text" ]; then
        echo -e "${BLUE}=========================================${NC}"
        echo -e "${BLUE}  CA Verification Performance Dashboard${NC}"
        echo -e "${BLUE}  $(date)${NC}"
        echo -e "${BLUE}=========================================${NC}"
        echo ""
    fi

    # Lean build performance
    if [ "$FORMAT" = "text" ]; then
        echo -e "${CYAN}=== Lean Build Performance ===${NC}"
    fi

    local lean_full_time=$(time_command "Lean full build" \
        bash -c 'cd lean && lake build')

    local registration_time=$(time_command "Registration EvalEquivRebuild" \
        bash -c 'cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild')

    local withdrawal_time=$(time_command "Withdrawal EvalEquiv" \
        bash -c 'cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv')

    local transfer_time=$(time_command "Transfer EvalEquiv" \
        bash -c 'cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv')

    if [ "$FORMAT" = "text" ]; then
        echo "  Full Lean tree:           $(format_duration $lean_full_time)"
        echo "  Registration (rebuild):   $(format_duration $registration_time)"
        echo "  Withdrawal (Phase 4):     $(format_duration $withdrawal_time)"
        echo "  Transfer (Phase 4):       $(format_duration $transfer_time)"
        echo ""

        # Budget comparison
        local registration_budget=3.0
        if (( $(echo "$registration_time < $registration_budget" | bc -l) )); then
            echo -e "  ${GREEN}✓ Registration within 3min budget${NC}"
        else
            echo -e "  ${RED}✗ Registration exceeds 3min budget${NC}"
        fi
        echo ""
    fi

    # Verification suite performance
    if [ "$FORMAT" = "text" ]; then
        echo -e "${CYAN}=== Verification Suite Performance ===${NC}"
    fi

    local quick_time=$(time_command "Quick suite" \
        ./scripts/run_verification_suite.sh --quick)

    local standard_time=$(time_command "Standard suite" \
        ./scripts/run_verification_suite.sh)

    if [ "$FORMAT" = "text" ]; then
        echo "  Quick mode (2min target):      $(format_duration $quick_time)"
        echo "  Standard mode (5min target):   $(format_duration $standard_time)"
        echo ""
    fi

    # Per-operation verification times
    if [ "$FORMAT" = "text" ]; then
        echo -e "${CYAN}=== Per-Operation Verification ===${NC}"
    fi

    for op in register withdraw transfer normalize rotate; do
        local op_time=$(time_command "$op verification" \
            ./audit/verify-ca.sh --op "$op" --stack lean)

        if [ "$FORMAT" = "text" ]; then
            echo "  $op: $(format_duration $op_time)"
        fi
    done

    if [ "$FORMAT" = "text" ]; then
        echo ""
    fi

    # Coverage metrics
    if [ "$FORMAT" = "text" ]; then
        echo -e "${CYAN}=== Coverage Metrics ===${NC}"
    fi

    local theorem_count=$(grep -r '^theorem ' lean/MovementFormal/Experimental/ConfidentialAsset --include="*.lean" | wc -l | tr -d ' ')
    local sorry_count=$(grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" | grep -v "SORRY" | grep -v "comment" | wc -l | tr -d ' ')
    local axiom_count=$(./scripts/check_axioms.sh --baseline 2>/dev/null | grep -c "^axiom" || echo "0")

    if [ "$FORMAT" = "text" ]; then
        echo "  Total theorems:     $theorem_count"
        echo "  Sorry placeholders: $sorry_count"
        echo "  Total axioms:       $axiom_count"
        echo ""
    fi

    # JSON output
    if [ "$FORMAT" = "json" ]; then
        jq -n \
            --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            --argjson lean_full "$lean_full_time" \
            --argjson registration "$registration_time" \
            --argjson withdrawal "$withdrawal_time" \
            --argjson transfer "$transfer_time" \
            --argjson quick "$quick_time" \
            --argjson standard "$standard_time" \
            --argjson theorems "$theorem_count" \
            --argjson sorries "$sorry_count" \
            --argjson axioms "$axiom_count" \
            '{
                timestamp: $timestamp,
                lean_build: {
                    full_tree_seconds: $lean_full,
                    registration_seconds: $registration,
                    withdrawal_seconds: $withdrawal,
                    transfer_seconds: $transfer
                },
                verification_suite: {
                    quick_mode_seconds: $quick,
                    standard_mode_seconds: $standard
                },
                coverage: {
                    total_theorems: $theorems,
                    sorry_count: $sorries,
                    axiom_count: $axioms
                }
            }'
    fi
}

# Benchmark mode: run comprehensive benchmarks
run_benchmark() {
    echo -e "${BLUE}Running comprehensive benchmark suite...${NC}"
    echo ""

    # Run benchmark script
    local benchmark_output=$(mktemp)
    ./scripts/benchmark_verification.sh --output json > "$benchmark_output"

    if [ -n "$BENCHMARK_SAVE" ]; then
        echo -e "${GREEN}Saving benchmark to $BENCHMARK_SAVE${NC}"
        cp "$benchmark_output" "$BENCHMARK_SAVE"
    fi

    if [ "$FORMAT" = "json" ]; then
        cat "$benchmark_output"
    else
        echo -e "${GREEN}✓ Benchmark complete${NC}"
        echo ""
        echo "Results:"
        jq -r '
            "  Lean full build: " + (.lean_build.full_tree_seconds | tostring) + "s",
            "  Registration: " + (.lean_build.registration_seconds | tostring) + "s",
            "  Quick suite: " + (.verification_suite.quick_mode_seconds | tostring) + "s"
        ' "$benchmark_output"
    fi

    rm -f "$benchmark_output"
}

# Compare mode: compare two benchmark results
compare_benchmarks() {
    if [ ! -f "$COMPARE_A" ] || [ ! -f "$COMPARE_B" ]; then
        echo -e "${RED}Error: Benchmark files not found${NC}"
        exit 2
    fi

    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Benchmark Comparison${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    echo "  Baseline: $COMPARE_A"
    echo "  Current:  $COMPARE_B"
    echo ""

    # Extract and compare metrics
    local baseline_lean=$(jq -r '.lean_build.full_tree_seconds' "$COMPARE_A")
    local current_lean=$(jq -r '.lean_build.full_tree_seconds' "$COMPARE_B")
    local diff_lean=$(echo "$current_lean - $baseline_lean" | bc)
    local pct_lean=$(echo "scale=2; ($diff_lean / $baseline_lean) * 100" | bc)

    echo -e "${CYAN}Lean Full Build:${NC}"
    echo "  Baseline: ${baseline_lean}s"
    echo "  Current:  ${current_lean}s"
    echo "  Diff:     ${diff_lean}s (${pct_lean}%)"

    if (( $(echo "$pct_lean > 10" | bc -l) )); then
        echo -e "  ${RED}⚠️  Regression detected (>10% slower)${NC}"
        exit 1
    elif (( $(echo "$pct_lean < -10" | bc -l) )); then
        echo -e "  ${GREEN}✓ Performance improved (>10% faster)${NC}"
    else
        echo -e "  ${GREEN}✓ Performance stable (within 10%)${NC}"
    fi

    echo ""
}

# Trend mode: show performance trends
show_trends() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Performance Trends (last $TREND_DAYS days)${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    # Look for benchmark files in reports directory
    if [ ! -d "reports" ]; then
        echo -e "${YELLOW}No reports directory found${NC}"
        echo "Run benchmarks with --save to track trends"
        return
    fi

    local benchmark_files=$(find reports -name "benchmark-*.json" -mtime -$TREND_DAYS | sort)

    if [ -z "$benchmark_files" ]; then
        echo -e "${YELLOW}No benchmark files found in last $TREND_DAYS days${NC}"
        return
    fi

    echo "Date           Lean Build  Registration  Quick Suite"
    echo "----           ----------  ------------  -----------"

    for file in $benchmark_files; do
        local date=$(basename "$file" .json | sed 's/benchmark-//')
        local lean=$(jq -r '.lean_build.full_tree_seconds' "$file" 2>/dev/null || echo "N/A")
        local reg=$(jq -r '.lean_build.registration_seconds' "$file" 2>/dev/null || echo "N/A")
        local quick=$(jq -r '.verification_suite.quick_mode_seconds' "$file" 2>/dev/null || echo "N/A")

        printf "%-14s %-11s %-13s %-11s\n" "$date" "${lean}s" "${reg}s" "${quick}s"
    done

    echo ""
}

# Main dispatch
case "$MODE" in
    dashboard)
        show_dashboard
        ;;
    benchmark)
        run_benchmark
        ;;
    compare)
        compare_benchmarks
        ;;
    trend)
        show_trends
        ;;
    *)
        echo "Unknown mode: $MODE"
        exit 2
        ;;
esac

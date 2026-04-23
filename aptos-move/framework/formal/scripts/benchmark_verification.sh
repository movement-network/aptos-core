#!/usr/bin/env bash
# scripts/benchmark_verification.sh — Performance benchmarking for CA verification
#
# Measures verification timing across all operations and stacks, produces
# detailed report suitable for tracking performance trends over time.
#
# Usage:
#   ./scripts/benchmark_verification.sh [--json|--csv|--markdown]
#   ./scripts/benchmark_verification.sh --baseline > benchmarks/baseline-$(date +%Y%m%d).txt
#
# Output formats:
#   (default)   Human-readable table
#   --json      JSON format for programmatic consumption
#   --csv       CSV format for spreadsheet import
#   --markdown  Markdown table for docs
#   --baseline  Baseline format for regression checking

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FORMAL_ROOT"

# Parse args
FORMAT="human"
if [ "${1:-}" = "--json" ]; then
    FORMAT="json"
elif [ "${1:-}" = "--csv" ]; then
    FORMAT="csv"
elif [ "${1:-}" = "--markdown" ]; then
    FORMAT="markdown"
elif [ "${1:-}" = "--baseline" ]; then
    FORMAT="baseline"
elif [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [--json|--csv|--markdown|--baseline]"
    echo ""
    echo "Benchmarks CA verification performance across all operations and stacks."
    echo ""
    echo "Output formats:"
    echo "  (default)   Human-readable table"
    echo "  --json      JSON format"
    echo "  --csv       CSV format"
    echo "  --markdown  Markdown table"
    echo "  --baseline  Baseline for regression checking"
    exit 0
fi

# Operations to benchmark
OPS=("register" "withdraw" "transfer" "normalize" "rotate")

# Stacks to benchmark
STACKS=("lean" "move-prover")
# Note: difftest excluded until harness integration complete

# Results storage
declare -A TIMES

# Benchmark function
benchmark_op() {
    local op="$1"
    local stack="$2"
    local start end elapsed

    start=$(date +%s.%N)
    ./audit/verify-ca.sh --op "$op" --stack "$stack" > /dev/null 2>&1 || echo "Failed: $op/$stack" >&2
    end=$(date +%s.%N)

    elapsed=$(echo "$end - $start" | bc)
    TIMES["${op}_${stack}"]="$elapsed"
}

# Run benchmarks
echo "Running benchmarks..." >&2
for op in "${OPS[@]}"; do
    for stack in "${STACKS[@]}"; do
        echo "  Benchmarking $op/$stack..." >&2
        benchmark_op "$op" "$stack"
    done
done

# Calculate totals
TOTAL_LEAN=0
TOTAL_MOVE_PROVER=0
for op in "${OPS[@]}"; do
    TOTAL_LEAN=$(echo "$TOTAL_LEAN + ${TIMES[${op}_lean]}" | bc)
    TOTAL_MOVE_PROVER=$(echo "$TOTAL_MOVE_PROVER + ${TIMES[${op}_move-prover]}" | bc)
done
TOTAL_ALL=$(echo "$TOTAL_LEAN + $TOTAL_MOVE_PROVER" | bc)

# Output results
case "$FORMAT" in
    human)
        echo ""
        echo "=========================================="
        echo "  CA Verification Benchmark Results"
        echo "  $(date)"
        echo "=========================================="
        echo ""
        printf "%-12s  %12s  %12s  %12s\n" "Operation" "Lean" "Move Prover" "Total"
        printf "%-12s  %12s  %12s  %12s\n" "------------" "------------" "------------" "------------"
        for op in "${OPS[@]}"; do
            lean_time="${TIMES[${op}_lean]}"
            mp_time="${TIMES[${op}_move-prover]}"
            total=$(echo "$lean_time + $mp_time" | bc)
            printf "%-12s  %12.2fs  %12.2fs  %12.2fs\n" "$op" "$lean_time" "$mp_time" "$total"
        done
        printf "%-12s  %12s  %12s  %12s\n" "------------" "------------" "------------" "------------"
        printf "%-12s  %12.2fs  %12.2fs  %12.2fs\n" "TOTAL" "$TOTAL_LEAN" "$TOTAL_MOVE_PROVER" "$TOTAL_ALL"
        echo ""
        echo "Budget compliance:"
        echo "  Per-operation budget: 180s (3 min)"
        for op in "${OPS[@]}"; do
            lean_time="${TIMES[${op}_lean]}"
            mp_time="${TIMES[${op}_move-prover]}"
            total=$(echo "$lean_time + $mp_time" | bc)
            if (( $(echo "$total > 180" | bc -l) )); then
                echo "    ❌ $op: ${total}s (OVER BUDGET)"
            else
                echo "    ✅ $op: ${total}s"
            fi
        done
        echo ""
        echo "  Full-run budget: 2700s (45 min)"
        if (( $(echo "$TOTAL_ALL > 2700" | bc -l) )); then
            echo "    ❌ Total: ${TOTAL_ALL}s (OVER BUDGET)"
        else
            echo "    ✅ Total: ${TOTAL_ALL}s"
        fi
        ;;

    json)
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"operations\": {"
        for i in "${!OPS[@]}"; do
            op="${OPS[$i]}"
            lean_time="${TIMES[${op}_lean]}"
            mp_time="${TIMES[${op}_move-prover]}"
            total=$(echo "$lean_time + $mp_time" | bc)
            echo -n "    \"$op\": {\"lean\": $lean_time, \"move_prover\": $mp_time, \"total\": $total}"
            if [ $i -lt $((${#OPS[@]} - 1)) ]; then
                echo ","
            else
                echo ""
            fi
        done
        echo "  },"
        echo "  \"totals\": {"
        echo "    \"lean\": $TOTAL_LEAN,"
        echo "    \"move_prover\": $TOTAL_MOVE_PROVER,"
        echo "    \"total\": $TOTAL_ALL"
        echo "  },"
        echo "  \"budgets\": {"
        echo "    \"per_operation\": 180,"
        echo "    \"full_run\": 2700"
        echo "  }"
        echo "}"
        ;;

    csv)
        echo "operation,lean,move_prover,total"
        for op in "${OPS[@]}"; do
            lean_time="${TIMES[${op}_lean]}"
            mp_time="${TIMES[${op}_move-prover]}"
            total=$(echo "$lean_time + $mp_time" | bc)
            echo "$op,$lean_time,$mp_time,$total"
        done
        echo "TOTAL,$TOTAL_LEAN,$TOTAL_MOVE_PROVER,$TOTAL_ALL"
        ;;

    markdown)
        echo "| Operation | Lean | Move Prover | Total |"
        echo "|-----------|------|-------------|-------|"
        for op in "${OPS[@]}"; do
            lean_time="${TIMES[${op}_lean]}"
            mp_time="${TIMES[${op}_move-prover]}"
            total=$(echo "$lean_time + $mp_time" | bc)
            printf "| %-9s | %.2fs | %.2fs | %.2fs |\n" "$op" "$lean_time" "$mp_time" "$total"
        done
        echo "| **TOTAL** | **${TOTAL_LEAN}s** | **${TOTAL_MOVE_PROVER}s** | **${TOTAL_ALL}s** |"
        ;;

    baseline)
        echo "# CA Verification Baseline"
        echo "# Generated: $(date -Iseconds)"
        echo "# Commit: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
        echo ""
        for op in "${OPS[@]}"; do
            for stack in "${STACKS[@]}"; do
                time="${TIMES[${op}_${stack}]}"
                echo "${op}_${stack}=$time"
            done
        done
        echo "total_lean=$TOTAL_LEAN"
        echo "total_move_prover=$TOTAL_MOVE_PROVER"
        echo "total_all=$TOTAL_ALL"
        ;;
esac

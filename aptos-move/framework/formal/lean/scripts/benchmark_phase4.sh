#!/usr/bin/env bash
# Phase 4 Performance Benchmark Script
#
# Measures build performance for Phase 4 crypto verifier proofs
# Outputs: CSV format, JSON format, human-readable summary
#
# Usage:
#   ./scripts/benchmark_phase4.sh [--format csv|json|summary] [--output FILE]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEAN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$LEAN_ROOT"

# Default options
FORMAT="summary"
OUTPUT=""
ITERATIONS=3

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--format csv|json|summary] [--output FILE] [--iterations N]"
            exit 1
            ;;
    esac
done

# Benchmark functions
benchmark_file() {
    local file=$1
    local total_time=0
    local min_time=999999
    local max_time=0

    for ((i=1; i<=ITERATIONS; i++)); do
        # Clean build
        lake clean "$file" > /dev/null 2>&1 || true

        # Measure build time
        local start=$(date +%s%N)
        lake build "$file" > /dev/null 2>&1
        local end=$(date +%s%N)
        local duration=$(((end - start) / 1000000)) # milliseconds

        total_time=$((total_time + duration))
        if [ $duration -lt $min_time ]; then
            min_time=$duration
        fi
        if [ $duration -gt $max_time ]; then
            max_time=$duration
        fi
    done

    local avg_time=$((total_time / ITERATIONS))
    echo "$avg_time:$min_time:$max_time"
}

# Files to benchmark
declare -A FILES
FILES["Normalization"]="MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv"
FILES["Rotation"]="MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv"
FILES["Withdrawal"]="MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv"
FILES["Transfer"]="MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv"
FILES["Normalization.ConcreteHelpers"]="MovementFormal.Experimental.ConfidentialAsset.Normalization.ConcreteHelpers"
FILES["Rotation.ConcreteHelpers"]="MovementFormal.Experimental.ConfidentialAsset.Rotation.ConcreteHelpers"
FILES["Withdrawal.ConcreteHelpers"]="MovementFormal.Experimental.ConfidentialAsset.Withdrawal.ConcreteHelpers"
FILES["Transfer.ConcreteHelpers"]="MovementFormal.Experimental.ConfidentialAsset.Transfer.ConcreteHelpers"

# Collect results
declare -A RESULTS

echo "Benchmarking Phase 4 files ($ITERATIONS iterations each)..." >&2

for name in "${!FILES[@]}"; do
    echo "  Benchmarking $name..." >&2
    result=$(benchmark_file "${FILES[$name]}")
    RESULTS[$name]=$result
done

# Full tree benchmark
echo "  Benchmarking full tree..." >&2
lake clean > /dev/null 2>&1 || true
total_tree_time=0
min_tree_time=999999
max_tree_time=0

for ((i=1; i<=ITERATIONS; i++)); do
    lake clean > /dev/null 2>&1
    start=$(date +%s)
    lake build > /dev/null 2>&1
    end=$(date +%s)
    duration=$((end - start))

    total_tree_time=$((total_tree_time + duration))
    if [ $duration -lt $min_tree_time ]; then
        min_tree_time=$duration
    fi
    if [ $duration -gt $max_tree_time ]; then
        max_tree_time=$duration
    fi
done

avg_tree_time=$((total_tree_time / ITERATIONS))

# Output results
output_csv() {
    echo "File,Avg_ms,Min_ms,Max_ms"
    for name in "${!RESULTS[@]}"; do
        IFS=':' read -r avg min max <<< "${RESULTS[$name]}"
        echo "$name,$avg,$min,$max"
    done
    echo "FullTree,$((avg_tree_time * 1000)),$((min_tree_time * 1000)),$((max_tree_time * 1000))"
}

output_json() {
    echo "{"
    echo '  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",'
    echo '  "iterations": '$ITERATIONS','
    echo '  "files": {'

    first=true
    for name in "${!RESULTS[@]}"; do
        IFS=':' read -r avg min max <<< "${RESULTS[$name]}"
        if [ "$first" = false ]; then
            echo "    ,"
        fi
        first=false
        echo -n '    "'$name'": {"avg_ms": '$avg', "min_ms": '$min', "max_ms": '$max'}'
    done

    echo
    echo "  },"
    echo '  "full_tree_seconds": {"avg": '$avg_tree_time', "min": '$min_tree_time', "max": '$max_tree_time'}'
    echo "}"
}

output_summary() {
    echo "Phase 4 Performance Benchmark Results"
    echo "======================================"
    echo "Iterations: $ITERATIONS"
    echo "Date: $(date)"
    echo
    echo "Individual Files (milliseconds):"
    echo "--------------------------------"

    printf "%-30s %10s %10s %10s\n" "File" "Avg" "Min" "Max"
    printf "%-30s %10s %10s %10s\n" "----" "---" "---" "---"

    for name in Normalization Rotation Withdrawal Transfer \
                Normalization.ConcreteHelpers Rotation.ConcreteHelpers \
                Withdrawal.ConcreteHelpers Transfer.ConcreteHelpers; do
        if [ -n "${RESULTS[$name]:-}" ]; then
            IFS=':' read -r avg min max <<< "${RESULTS[$name]}"
            printf "%-30s %10d %10d %10d\n" "$name" "$avg" "$min" "$max"
        fi
    done

    echo
    echo "Full Tree Build (seconds):"
    echo "--------------------------"
    printf "%-30s %10d %10d %10d\n" "Full Tree" "$avg_tree_time" "$min_tree_time" "$max_tree_time"

    echo
    echo "Performance Assessment:"
    echo "----------------------"

    # Check against targets
    local pass=0
    local warn=0
    local fail=0

    for name in Normalization Rotation Withdrawal Transfer; do
        if [ -n "${RESULTS[$name]:-}" ]; then
            IFS=':' read -r avg min max <<< "${RESULTS[$name]}"
            if [ $avg -lt 1000 ]; then
                echo "✅ $name: ${avg}ms (target: ≤1000ms)"
                ((pass++))
            elif [ $avg -lt 2000 ]; then
                echo "⚠️  $name: ${avg}ms (acceptable but above target)"
                ((warn++))
            else
                echo "❌ $name: ${avg}ms (too slow)"
                ((fail++))
            fi
        fi
    done

    if [ $avg_tree_time -lt 10 ]; then
        echo "✅ Full tree: ${avg_tree_time}s (target: ≤10s)"
    elif [ $avg_tree_time -lt 20 ]; then
        echo "⚠️  Full tree: ${avg_tree_time}s (acceptable but above target)"
    else
        echo "❌ Full tree: ${avg_tree_time}s (too slow)"
    fi

    echo
    echo "Summary: $pass passed, $warn warnings, $fail failed"
}

# Output to file or stdout
case "$FORMAT" in
    csv)
        if [ -n "$OUTPUT" ]; then
            output_csv > "$OUTPUT"
            echo "Results written to $OUTPUT" >&2
        else
            output_csv
        fi
        ;;
    json)
        if [ -n "$OUTPUT" ]; then
            output_json > "$OUTPUT"
            echo "Results written to $OUTPUT" >&2
        else
            output_json
        fi
        ;;
    summary)
        if [ -n "$OUTPUT" ]; then
            output_summary > "$OUTPUT"
            echo "Results written to $OUTPUT" >&2
        else
            output_summary
        fi
        ;;
    *)
        echo "Unknown format: $FORMAT"
        exit 1
        ;;
esac

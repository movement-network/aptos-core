#!/usr/bin/env bash
# scripts/detect_performance_regression.sh — Performance regression detection
#
# Compares current verification timing against baseline to catch performance regressions.
# Fails CI if any operation exceeds threshold (e.g., >20% slower than baseline).
#
# Usage:
#   ./scripts/detect_performance_regression.sh [--baseline <file>] [--threshold <percent>]
#
# Options:
#   --baseline <file>      Baseline file (default: benchmarks/baseline-latest.txt)
#   --threshold <percent>  Regression threshold (default: 20)
#   --strict               Fail on any regression (ignores threshold)
#   --update-baseline      Update baseline if within threshold
#
# Exit codes:
#   0   No regressions detected
#   1   Regressions detected (exceeds threshold)
#   2   Baseline file missing

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FORMAL_ROOT"

# Default args
BASELINE_FILE="benchmarks/baseline-latest.txt"
THRESHOLD=20  # 20% slower = regression
STRICT_MODE=false
UPDATE_BASELINE=false

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --baseline)
            BASELINE_FILE="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --strict)
            STRICT_MODE=true
            shift
            ;;
        --update-baseline)
            UPDATE_BASELINE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--baseline <file>] [--threshold <percent>] [--strict] [--update-baseline]"
            echo ""
            echo "Detects performance regressions by comparing current timing against baseline."
            echo ""
            echo "Options:"
            echo "  --baseline <file>      Baseline file (default: benchmarks/baseline-latest.txt)"
            echo "  --threshold <percent>  Regression threshold % (default: 20)"
            echo "  --strict               Fail on any regression (ignores threshold)"
            echo "  --update-baseline      Update baseline if within threshold"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Performance Regression Detection${NC}"
echo "Baseline: $BASELINE_FILE"
echo "Threshold: ${THRESHOLD}%"
echo ""

# Check baseline exists
if [ ! -f "$BASELINE_FILE" ]; then
    echo -e "${RED}ERROR: Baseline file not found: $BASELINE_FILE${NC}"
    echo ""
    echo "Create baseline with:"
    echo "  ./scripts/benchmark_verification.sh --baseline > benchmarks/baseline-$(date +%Y%m%d).txt"
    echo "  ln -sf baseline-$(date +%Y%m%d).txt benchmarks/baseline-latest.txt"
    exit 2
fi

# Run current benchmark
echo "Running current benchmark..."
CURRENT_FILE="/tmp/current-benchmark-$$.txt"
if ! ./scripts/benchmark_verification.sh --baseline > "$CURRENT_FILE" 2>&1; then
    echo -e "${RED}ERROR: Benchmark failed${NC}"
    cat "$CURRENT_FILE"
    rm -f "$CURRENT_FILE"
    exit 1
fi

echo "Comparing against baseline..."
echo ""

# Parse baseline and current
declare -A BASELINE_TIMES
declare -A CURRENT_TIMES

# Load baseline (format: "register_lean=1.23")
while IFS='=' read -r key value; do
    if [[ "$key" =~ ^(register|withdraw|transfer|normalize|rotate)_(lean|move-prover)$ ]]; then
        BASELINE_TIMES["$key"]="$value"
    elif [[ "$key" =~ ^total_(lean|move_prover|all)$ ]]; then
        BASELINE_TIMES["$key"]="$value"
    fi
done < "$BASELINE_FILE"

# Load current
while IFS='=' read -r key value; do
    if [[ "$key" =~ ^(register|withdraw|transfer|normalize|rotate)_(lean|move-prover)$ ]]; then
        CURRENT_TIMES["$key"]="$value"
    elif [[ "$key" =~ ^total_(lean|move_prover|all)$ ]]; then
        CURRENT_TIMES["$key"]="$value"
    fi
done < "$CURRENT_FILE"

# Compare and report
REGRESSIONS=0
IMPROVEMENTS=0
STABLE=0

printf "%-25s %12s %12s %12s %s\n" "Operation" "Baseline" "Current" "Change" "Status"
printf "%-25s %12s %12s %12s %s\n" "-------------------------" "------------" "------------" "------------" "------"

# Operations to check
OPS=(
    "register_lean"
    "register_move-prover"
    "withdraw_lean"
    "withdraw_move-prover"
    "transfer_lean"
    "transfer_move-prover"
    "normalize_lean"
    "normalize_move-prover"
    "rotate_lean"
    "rotate_move-prover"
    "total_lean"
    "total_move_prover"
    "total_all"
)

for op in "${OPS[@]}"; do
    baseline="${BASELINE_TIMES[$op]:-0}"
    current="${CURRENT_TIMES[$op]:-0}"

    if [ "$baseline" = "0" ] || [ "$current" = "0" ]; then
        printf "%-25s %12s %12s %12s ${YELLOW}SKIP${NC}\n" "$op" "$baseline" "$current" "N/A"
        continue
    fi

    # Calculate percent change: ((current - baseline) / baseline) * 100
    percent_change=$(echo "scale=2; (($current - $baseline) / $baseline) * 100" | bc)
    abs_change=$(echo "scale=2; $percent_change" | bc | tr -d '-')

    # Determine status
    if (( $(echo "$percent_change > $THRESHOLD" | bc -l) )) || [ "$STRICT_MODE" = true ] && (( $(echo "$percent_change > 0" | bc -l) )); then
        # Regression
        printf "%-25s %12.2fs %12.2fs %11.1f%% ${RED}REGRESS${NC}\n" "$op" "$baseline" "$current" "$percent_change"
        REGRESSIONS=$((REGRESSIONS + 1))
    elif (( $(echo "$percent_change < -5" | bc -l) )); then
        # Improvement (>5% faster)
        printf "%-25s %12.2fs %12.2fs %11.1f%% ${GREEN}IMPROVE${NC}\n" "$op" "$baseline" "$current" "$percent_change"
        IMPROVEMENTS=$((IMPROVEMENTS + 1))
    else
        # Stable (within threshold)
        printf "%-25s %12.2fs %12.2fs %11.1f%% ${GREEN}OK${NC}\n" "$op" "$baseline" "$current" "$percent_change"
        STABLE=$((STABLE + 1))
    fi
done

# Summary
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  Regressions: $REGRESSIONS"
echo "  Improvements: $IMPROVEMENTS"
echo "  Stable: $STABLE"
echo ""

# Update baseline if requested and no regressions
if [ "$UPDATE_BASELINE" = true ] && [ "$REGRESSIONS" -eq 0 ]; then
    echo -e "${GREEN}No regressions detected. Updating baseline...${NC}"
    cp "$CURRENT_FILE" "$BASELINE_FILE"
    echo "Baseline updated: $BASELINE_FILE"
    echo ""
fi

# Cleanup
rm -f "$CURRENT_FILE"

# Exit code
if [ "$REGRESSIONS" -gt 0 ]; then
    echo -e "${RED}❌ Performance regression detected!${NC}"
    echo ""
    echo "Regressions found in $REGRESSIONS operation(s)."
    echo ""
    echo "Investigate with:"
    echo "  ./scripts/benchmark_verification.sh"
    echo "  lake env lean --run -Dprofiler=true <Module>.lean"
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ No performance regressions detected.${NC}"
    exit 0
fi

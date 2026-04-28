#!/usr/bin/env bash
# scripts/diff_verification_baseline.sh — Compare verification state against baseline
#
# Compares current verification metrics (sorry count, axiom count, theorem count,
# performance) against saved baseline to detect regressions or improvements.
#
# Usage:
#   ./scripts/diff_verification_baseline.sh [--baseline FILE] [--save]
#   ./scripts/diff_verification_baseline.sh --generate-baseline
#   ./scripts/diff_verification_baseline.sh --help
#
# Exit codes:
#   0 = No regressions detected
#   1 = Regressions detected
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
BASELINE_FILE="reports/verification-baseline.json"
GENERATE_BASELINE=false
SAVE_CURRENT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --baseline)
            BASELINE_FILE="$2"
            shift 2
            ;;
        --generate-baseline)
            GENERATE_BASELINE=true
            shift
            ;;
        --save)
            SAVE_CURRENT=true
            shift
            ;;
        --help)
            cat <<EOF
Usage: $0 [--baseline FILE] [--save] [--generate-baseline]

Options:
  --baseline FILE      : Use specific baseline file (default: reports/verification-baseline.json)
  --generate-baseline  : Generate new baseline from current state
  --save               : Save current metrics to baseline file
  --help               : Show this help

Examples:
  # Generate initial baseline
  $0 --generate-baseline

  # Compare current state against baseline
  $0

  # Use custom baseline file
  $0 --baseline custom-baseline.json

  # Save current state as new baseline
  $0 --save
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            exit 2
            ;;
    esac
done

# Ensure reports directory exists
mkdir -p reports

# Collect current metrics
collect_metrics() {
    echo -e "${BLUE}Collecting current metrics...${NC}"

    # Sorry count
    local sorry_count=$(grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" 2>/dev/null | grep -v "SORRY" | grep -v "comment" | wc -l | tr -d ' ')

    # Axiom count
    local axiom_count=0
    if [ -x "scripts/check_axioms.sh" ]; then
        axiom_count=$(./scripts/check_axioms.sh --baseline 2>/dev/null | grep -c "^axiom" || echo 0)
    fi

    # Theorem count
    local theorem_count=$(grep -r '^theorem ' lean/MovementFormal/Experimental/ConfidentialAsset --include="*.lean" 2>/dev/null | wc -l | tr -d ' ')

    # MSL spec count
    local msl_spec_count=0
    if [ -d "../aptos-experimental/sources/confidential_asset" ]; then
        msl_spec_count=$(grep -c '^    spec ' ../aptos-experimental/sources/confidential_asset/*.spec.move 2>/dev/null | awk -F: 'BEGIN {sum=0} {sum+=$2} END {print sum}')
    fi

    # Build performance (Lean full tree)
    local build_time=0
    if [ -d "lean" ]; then
        local start=$(date +%s)
        cd lean && lake build > /dev/null 2>&1
        local end=$(date +%s)
        build_time=$((end - start))
        cd ..
    fi

    # Registration build time
    local registration_time=0
    if [ -d "lean" ]; then
        local start=$(date +%s)
        cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild > /dev/null 2>&1
        local end=$(date +%s)
        registration_time=$((end - start))
        cd ..
    fi

    # Generate JSON
    jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --argjson sorry "$sorry_count" \
        --argjson axioms "$axiom_count" \
        --argjson theorems "$theorem_count" \
        --argjson msl_specs "$msl_spec_count" \
        --argjson build_time "$build_time" \
        --argjson registration_time "$registration_time" \
        '{
            timestamp: $timestamp,
            metrics: {
                sorry_count: $sorry,
                axiom_count: $axioms,
                theorem_count: $theorems,
                msl_spec_count: $msl_specs,
                build_time_seconds: $build_time,
                registration_time_seconds: $registration_time
            }
        }'
}

# Generate baseline
if [ "$GENERATE_BASELINE" = true ]; then
    echo -e "${CYAN}=== Generating Baseline ===${NC}"
    echo ""

    collect_metrics > "$BASELINE_FILE"

    echo -e "${GREEN}✓ Baseline generated: $BASELINE_FILE${NC}"
    echo ""
    echo "Baseline metrics:"
    jq -r '
        "  Sorry count:         " + (.metrics.sorry_count | tostring),
        "  Axiom count:         " + (.metrics.axiom_count | tostring),
        "  Theorem count:       " + (.metrics.theorem_count | tostring),
        "  MSL spec count:      " + (.metrics.msl_spec_count | tostring),
        "  Build time:          " + (.metrics.build_time_seconds | tostring) + "s",
        "  Registration time:   " + (.metrics.registration_time_seconds | tostring) + "s"
    ' "$BASELINE_FILE"
    exit 0
fi

# Save current as baseline
if [ "$SAVE_CURRENT" = true ]; then
    echo -e "${CYAN}=== Saving Current State as Baseline ===${NC}"
    echo ""

    collect_metrics > "$BASELINE_FILE"

    echo -e "${GREEN}✓ Current state saved to: $BASELINE_FILE${NC}"
    exit 0
fi

# Compare against baseline
echo -e "${CYAN}=== Comparing Against Baseline ===${NC}"
echo ""

# Check baseline exists
if [ ! -f "$BASELINE_FILE" ]; then
    echo -e "${RED}Error:${NC} Baseline file not found: $BASELINE_FILE"
    echo ""
    echo "Generate baseline first:"
    echo "  $0 --generate-baseline"
    exit 2
fi

# Collect current metrics
CURRENT_FILE=$(mktemp)
trap "rm -f $CURRENT_FILE" EXIT
collect_metrics > "$CURRENT_FILE"

# Extract metrics
BASELINE_SORRY=$(jq -r '.metrics.sorry_count' "$BASELINE_FILE")
CURRENT_SORRY=$(jq -r '.metrics.sorry_count' "$CURRENT_FILE")

BASELINE_AXIOMS=$(jq -r '.metrics.axiom_count' "$BASELINE_FILE")
CURRENT_AXIOMS=$(jq -r '.metrics.axiom_count' "$CURRENT_FILE")

BASELINE_THEOREMS=$(jq -r '.metrics.theorem_count' "$BASELINE_FILE")
CURRENT_THEOREMS=$(jq -r '.metrics.theorem_count' "$CURRENT_FILE")

BASELINE_MSL=$(jq -r '.metrics.msl_spec_count' "$BASELINE_FILE")
CURRENT_MSL=$(jq -r '.metrics.msl_spec_count' "$CURRENT_FILE")

BASELINE_BUILD=$(jq -r '.metrics.build_time_seconds' "$BASELINE_FILE")
CURRENT_BUILD=$(jq -r '.metrics.build_time_seconds' "$CURRENT_FILE")

BASELINE_REG=$(jq -r '.metrics.registration_time_seconds' "$BASELINE_FILE")
CURRENT_REG=$(jq -r '.metrics.registration_time_seconds' "$CURRENT_FILE")

# Compare and report
REGRESSIONS=0
IMPROVEMENTS=0

echo "Metric              Baseline    Current     Change      Status"
echo "------              --------    -------     ------      ------"

# Sorry count (lower is better)
SORRY_DIFF=$((CURRENT_SORRY - BASELINE_SORRY))
SORRY_STATUS="${GREEN}✓ OK${NC}"
if [ "$CURRENT_SORRY" -gt "$BASELINE_SORRY" ]; then
    SORRY_STATUS="${RED}✗ REGRESSION${NC}"
    REGRESSIONS=$((REGRESSIONS + 1))
elif [ "$CURRENT_SORRY" -lt "$BASELINE_SORRY" ]; then
    SORRY_STATUS="${GREEN}✓ IMPROVED${NC}"
    IMPROVEMENTS=$((IMPROVEMENTS + 1))
fi
printf "Sorry count         %-11s %-11s %-11s %b\n" "$BASELINE_SORRY" "$CURRENT_SORRY" "$SORRY_DIFF" "$SORRY_STATUS"

# Axiom count (lower is better, within tolerance)
AXIOM_DIFF=$((CURRENT_AXIOMS - BASELINE_AXIOMS))
AXIOM_STATUS="${GREEN}✓ OK${NC}"
if [ "$CURRENT_AXIOMS" -gt "$((BASELINE_AXIOMS + 5))" ]; then
    AXIOM_STATUS="${RED}✗ REGRESSION${NC}"
    REGRESSIONS=$((REGRESSIONS + 1))
elif [ "$CURRENT_AXIOMS" -lt "$BASELINE_AXIOMS" ]; then
    AXIOM_STATUS="${GREEN}✓ IMPROVED${NC}"
    IMPROVEMENTS=$((IMPROVEMENTS + 1))
fi
printf "Axiom count         %-11s %-11s %-11s %b\n" "$BASELINE_AXIOMS" "$CURRENT_AXIOMS" "$AXIOM_DIFF" "$AXIOM_STATUS"

# Theorem count (higher is better)
THEOREM_DIFF=$((CURRENT_THEOREMS - BASELINE_THEOREMS))
THEOREM_STATUS="${GREEN}✓ OK${NC}"
if [ "$CURRENT_THEOREMS" -lt "$BASELINE_THEOREMS" ]; then
    THEOREM_STATUS="${YELLOW}⚠ DECREASED${NC}"
elif [ "$CURRENT_THEOREMS" -gt "$BASELINE_THEOREMS" ]; then
    THEOREM_STATUS="${GREEN}✓ IMPROVED${NC}"
    IMPROVEMENTS=$((IMPROVEMENTS + 1))
fi
printf "Theorem count       %-11s %-11s %-11s %b\n" "$BASELINE_THEOREMS" "$CURRENT_THEOREMS" "$THEOREM_DIFF" "$THEOREM_STATUS"

# MSL spec count (higher is better)
MSL_DIFF=$((CURRENT_MSL - BASELINE_MSL))
MSL_STATUS="${GREEN}✓ OK${NC}"
if [ "$CURRENT_MSL" -lt "$BASELINE_MSL" ]; then
    MSL_STATUS="${YELLOW}⚠ DECREASED${NC}"
elif [ "$CURRENT_MSL" -gt "$BASELINE_MSL" ]; then
    MSL_STATUS="${GREEN}✓ IMPROVED${NC}"
    IMPROVEMENTS=$((IMPROVEMENTS + 1))
fi
printf "MSL spec count      %-11s %-11s %-11s %b\n" "$BASELINE_MSL" "$CURRENT_MSL" "$MSL_DIFF" "$MSL_STATUS"

# Build time (lower is better, within 20% tolerance)
BUILD_DIFF=$((CURRENT_BUILD - BASELINE_BUILD))
BUILD_PCT=0
if [ "$BASELINE_BUILD" -gt 0 ]; then
    BUILD_PCT=$(echo "scale=2; ($BUILD_DIFF * 100.0) / $BASELINE_BUILD" | bc)
fi
BUILD_STATUS="${GREEN}✓ OK${NC}"
if (( $(echo "$BUILD_PCT > 20" | bc -l) )); then
    BUILD_STATUS="${RED}✗ REGRESSION${NC}"
    REGRESSIONS=$((REGRESSIONS + 1))
elif (( $(echo "$BUILD_PCT < -20" | bc -l) )); then
    BUILD_STATUS="${GREEN}✓ IMPROVED${NC}"
    IMPROVEMENTS=$((IMPROVEMENTS + 1))
fi
printf "Build time (s)      %-11s %-11s %-11s %b\n" "$BASELINE_BUILD" "$CURRENT_BUILD" "$BUILD_DIFF ($BUILD_PCT%)" "$BUILD_STATUS"

# Registration time (lower is better, within 20% tolerance)
REG_DIFF=$((CURRENT_REG - BASELINE_REG))
REG_PCT=0
if [ "$BASELINE_REG" -gt 0 ]; then
    REG_PCT=$(echo "scale=2; ($REG_DIFF * 100.0) / $BASELINE_REG" | bc)
fi
REG_STATUS="${GREEN}✓ OK${NC}"
if (( $(echo "$REG_PCT > 20" | bc -l) )); then
    REG_STATUS="${RED}✗ REGRESSION${NC}"
    REGRESSIONS=$((REGRESSIONS + 1))
elif (( $(echo "$REG_PCT < -20" | bc -l) )); then
    REG_STATUS="${GREEN}✓ IMPROVED${NC}"
    IMPROVEMENTS=$((IMPROVEMENTS + 1))
fi
printf "Registration (s)    %-11s %-11s %-11s %b\n" "$BASELINE_REG" "$CURRENT_REG" "$REG_DIFF ($REG_PCT%)" "$REG_STATUS"

echo ""
echo "=========================================="
echo "  Summary"
echo "=========================================="
echo -e "  Regressions:  ${RED}$REGRESSIONS${NC}"
echo -e "  Improvements: ${GREEN}$IMPROVEMENTS${NC}"
echo ""

if [ "$REGRESSIONS" -eq 0 ]; then
    echo -e "${GREEN}✅ NO REGRESSIONS DETECTED${NC}"
    echo ""
    if [ "$IMPROVEMENTS" -gt 0 ]; then
        echo "Consider updating baseline to capture improvements:"
        echo "  $0 --save"
    fi
    exit 0
else
    echo -e "${RED}❌ $REGRESSIONS REGRESSION(S) DETECTED${NC}"
    echo ""
    echo "Review regressions above and address before committing."
    echo ""
    echo "If regressions are expected, update baseline:"
    echo "  $0 --save"
    exit 1
fi

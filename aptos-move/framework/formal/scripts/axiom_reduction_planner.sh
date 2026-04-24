#!/usr/bin/env bash
# scripts/axiom_reduction_planner.sh — Strategic planning for TEMPORARY axiom elimination
#
# Analyzes TEMPORARY axioms and generates elimination plan with effort estimates,
# dependencies, and priority ordering for Phase 8 completion.
#
# Usage:
#   ./scripts/axiom_reduction_planner.sh [--format <text|json|markdown>] [--strategy <priority|deps|effort>]
#
# Options:
#   --format <type>      Output format (default: markdown)
#   --strategy <type>    Elimination strategy:
#                          priority: Critical path first
#                          deps: Dependency-order elimination
#                          effort: Quick wins first
#   --estimate           Include effort estimates for each axiom
#   --roadmap            Generate detailed Phase 8 roadmap
#
# Produces:
#   - TEMPORARY axiom inventory with locations
#   - Dependency graph showing which proofs depend on each axiom
#   - Effort estimates (lines of proof, complexity rating)
#   - Suggested elimination order
#   - Blocker analysis (what prerequisites each axiom needs)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LEAN_ROOT="$FORMAL_ROOT/lean"

# Default options
FORMAT="markdown"
STRATEGY="priority"
SHOW_ESTIMATES=false
GENERATE_ROADMAP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --format) FORMAT="$2"; shift 2 ;;
        --strategy) STRATEGY="$2"; shift 2 ;;
        --estimate) SHOW_ESTIMATES=true; shift ;;
        --roadmap) GENERATE_ROADMAP=true; shift ;;
        --help)
            sed -n '2,20p' "$0" | sed 's/^# //'
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

cd "$LEAN_ROOT"

# ANSI colors for text format
if [ "$FORMAT" = "text" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
fi

echo "# TEMPORARY Axiom Reduction Plan"
echo "Generated: $(date)"
echo

# Find all TEMPORARY axioms
echo "## TEMPORARY Axiom Inventory"
echo

temp_axiom_files=$(grep -r "TEMPORARY axiom\|axiom.*TEMPORARY" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" -l 2>/dev/null || true)

if [ -z "$temp_axiom_files" ]; then
    echo "✅ **No TEMPORARY axioms found!** Phase 8 complete."
    exit 0
fi

axiom_count=0
declare -A axiom_locations
declare -A axiom_reasons
declare -A axiom_estimates

while IFS= read -r file; do
    [ -z "$file" ] && continue

    # Extract axioms from this file
    while IFS= read -r line; do
        [ -z "$line" ] && continue

        # Extract axiom name
        axiom_name=$(echo "$line" | sed -n 's/^axiom \([a-zA-Z_0-9]*\).*/\1/p')

        if [ -n "$axiom_name" ]; then
            axiom_count=$((axiom_count + 1))
            relative_file=$(echo "$file" | sed "s|^MovementFormal/||")
            axiom_locations["$axiom_name"]="$relative_file"

            # Try to find comment explaining why it's TEMPORARY
            line_num=$(grep -n "^axiom $axiom_name" "$file" | cut -d: -f1)
            if [ -n "$line_num" ]; then
                # Look for comment in preceding 5 lines
                reason=$(sed -n "$((line_num - 5)),$((line_num - 1))p" "$file" | grep -o "TODO.*\|TEMPORARY.*\|FIXME.*" | head -1 || echo "No reason documented")
                axiom_reasons["$axiom_name"]="$reason"
            fi
        fi
    done < <(grep "^axiom.*TEMPORARY\|TEMPORARY.*^axiom" "$file" 2>/dev/null || true)

done <<< "$temp_axiom_files"

echo "**Total TEMPORARY axioms:** $axiom_count"
echo

if [ "$axiom_count" -eq 0 ]; then
    echo "✅ **All TEMPORARY axioms eliminated!** Phase 8 complete."
    exit 0
fi

# List each axiom
echo "### Axiom Details"
echo

for axiom in "${!axiom_locations[@]}"; do
    location="${axiom_locations[$axiom]}"
    reason="${axiom_reasons[$axiom]:-Unknown}"

    echo "#### \`$axiom\`"
    echo
    echo "- **Location:** \`$location\`"
    echo "- **Reason:** $reason"

    # Try to estimate complexity
    if [ "$SHOW_ESTIMATES" = true ]; then
        # Count how many theorems depend on this axiom
        dependent_count=$(grep -r "$axiom" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" | grep -v "^axiom" | wc -l | tr -d ' ')
        echo "- **Dependent theorems:** ~$dependent_count"

        # Estimate lines needed (very rough heuristic based on file analysis)
        case "$axiom" in
            *registration*) estimate="2000-3000" ;;
            *PC*|*pc*) estimate="200-500" ;;
            *helper*) estimate="50-150" ;;
            *) estimate="100-300" ;;
        esac
        echo "- **Estimated proof lines:** $estimate"
    fi

    echo
done

# Dependency analysis
echo "## Dependency Analysis"
echo

echo "### Axiom Usage Matrix"
echo

# For each axiom, find which files use it
for axiom in "${!axiom_locations[@]}"; do
    users=$(grep -r "$axiom" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" -l 2>/dev/null | grep -v "${axiom_locations[$axiom]}" || echo "")

    if [ -n "$users" ]; then
        user_count=$(echo "$users" | wc -l | tr -d ' ')
        echo "- **\`$axiom\`:** Used by $user_count file(s)"

        if [ "$FORMAT" = "markdown" ]; then
            while IFS= read -r user_file; do
                [ -z "$user_file" ] && continue
                relative=$(echo "$user_file" | sed "s|^MovementFormal/||")
                echo "  - \`$relative\`"
            done <<< "$users"
        fi
    else
        echo "- **\`$axiom\`:** No external dependencies ✅ (safe to eliminate independently)"
    fi
    echo
done

# Elimination strategy
echo "## Elimination Strategy ($STRATEGY mode)"
echo

case "$STRATEGY" in
    priority)
        echo "### Critical Path First"
        echo
        echo "Eliminate axioms blocking main verification claims first:"
        echo
        echo "1. **registration_eval_equiv_functional_sim** (if present)"
        echo "   - Blocks: Phase 6 registration composition"
        echo "   - Effort: HIGH (2000-3000 lines - singleton branch)"
        echo "   - Priority: **P0 - Critical**"
        echo
        echo "2. **Withdrawal PC-chaining helpers** (if present)"
        echo "   - Blocks: Full Phase 4 completion"
        echo "   - Effort: MEDIUM (4 axioms × ~70 lines each = 280 lines)"
        echo "   - Priority: **P1 - Important**"
        echo
        echo "3. **Other helper axioms**"
        echo "   - Effort: LOW (varies)"
        echo "   - Priority: **P2 - Optional**"
        ;;

    deps)
        echo "### Dependency-Ordered Elimination"
        echo
        echo "Eliminate leaf axioms (no dependents) first, then work up the dependency tree."
        echo
        # Find leaf axioms (not used by other files)
        echo "**Leaf axioms (eliminate first):**"
        for axiom in "${!axiom_locations[@]}"; do
            users=$(grep -r "$axiom" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" -l 2>/dev/null | grep -v "${axiom_locations[$axiom]}" || echo "")
            if [ -z "$users" ]; then
                echo "- \`$axiom\` (${axiom_locations[$axiom]})"
            fi
        done
        echo
        ;;

    effort)
        echo "### Quick Wins First"
        echo
        echo "Tackle easiest axioms first to build momentum:"
        echo
        echo "1. **Helper axioms** (~50-150 lines each)"
        echo "2. **PC-chaining axioms** (~200-500 lines total)"
        echo "3. **Main equivalence axioms** (~2000-3000 lines for singleton branch)"
        ;;
esac

echo

# Generate detailed roadmap if requested
if [ "$GENERATE_ROADMAP" = true ]; then
    echo "## Phase 8 Detailed Roadmap"
    echo
    echo "### Week-by-Week Elimination Plan"
    echo

    echo "#### Week 1-2: Infrastructure & Quick Wins"
    echo "- **Goal:** Eliminate all leaf axioms and helper axioms"
    echo "- **Tasks:**"
    echo "  - [ ] Set up axiom tracking CI (baseline + diff)"
    echo "  - [ ] Eliminate helper axioms (estimate: 2-3 days)"
    echo "  - [ ] Update AXIOM_INVENTORY.md"
    echo "- **Deliverable:** 20-30% axiom reduction"
    echo

    echo "#### Week 3-4: PC-Chaining Axioms"
    echo "- **Goal:** Complete Phase 4 helper proofs"
    echo "- **Tasks:**"
    echo "  - [ ] Withdrawal PC-chaining (4 axioms, ~70 lines each)"
    echo "  - [ ] Test full Phase 4 completion"
    echo "  - [ ] Update verification status docs"
    echo "- **Deliverable:** Phase 4 100% complete (0 sorries, 0 TEMPORARY axioms)"
    echo

    echo "#### Week 5-8: Singleton Branch (if present)"
    echo "- **Goal:** Eliminate registration_eval_equiv_functional_sim"
    echo "- **Tasks:**"
    echo "  - [ ] Design elaborator-friendly structure (Week 5)"
    echo "  - [ ] Implement buildSigmaLocals + bytecode lemmas (Week 6)"
    echo "  - [ ] Complete 20 PC helper sorries (Week 7)"
    echo "  - [ ] Integration & testing (Week 8)"
    echo "- **Deliverable:** Phase 1 100% complete, registration axiom eliminated"
    echo

    echo "#### Continuous: Maintenance"
    echo "- **Goal:** Prevent axiom drift"
    echo "- **Tasks:**"
    echo "  - [ ] Run \`check_axioms.sh --diff\` in CI"
    echo "  - [ ] Block PRs that introduce new TEMPORARY axioms"
    echo "  - [ ] Monthly axiom inventory review"
    echo
fi

# Effort summary
echo "## Effort Summary"
echo

total_estimate_min=0
total_estimate_max=0

for axiom in "${!axiom_locations[@]}"; do
    case "$axiom" in
        *registration*)
            total_estimate_min=$((total_estimate_min + 2000))
            total_estimate_max=$((total_estimate_max + 3000))
            ;;
        *PC*|*pc*)
            total_estimate_min=$((total_estimate_min + 200))
            total_estimate_max=$((total_estimate_max + 500))
            ;;
        *helper*)
            total_estimate_min=$((total_estimate_min + 50))
            total_estimate_max=$((total_estimate_max + 150))
            ;;
        *)
            total_estimate_min=$((total_estimate_min + 100))
            total_estimate_max=$((total_estimate_max + 300))
            ;;
    esac
done

echo "**Total estimated effort:** $total_estimate_min-$total_estimate_max lines of proof"
echo
echo "**Time estimate (assuming 200-300 lines/day):**"
echo "- Minimum: $((total_estimate_min / 300)) days (~$((total_estimate_min / 300 / 5)) weeks)"
echo "- Maximum: $((total_estimate_max / 200)) days (~$((total_estimate_max / 200 / 5)) weeks)"
echo

# Recommendations
echo "## Recommendations"
echo

echo "1. **Start with quick wins** to build momentum and validate elimination process"
echo "2. **Allocate dedicated time** for singleton branch (don't attempt in small increments)"
echo "3. **Track progress weekly** with \`check_axioms.sh --diff\`"
echo "4. **Update documentation** as each axiom is eliminated"
echo "5. **Consider pairing** on complex axioms (singleton branch)"
echo

# Next actions
echo "## Next Actions"
echo

echo "### Immediate (this week)"
echo "- [ ] Review this elimination plan"
echo "- [ ] Identify first axiom to tackle (recommend: easiest helper)"
echo "- [ ] Set up CI axiom tracking if not already done"
echo "- [ ] Block 2-hour session for first elimination attempt"
echo

echo "### Short term (next 2 weeks)"
echo "- [ ] Eliminate all leaf axioms"
echo "- [ ] Eliminate all helper axioms"
echo "- [ ] Update Phase 8 progress to 80%+"
echo

echo "### Medium term (next month)"
echo "- [ ] Complete PC-chaining axioms"
echo "- [ ] Plan singleton branch sprint (5-7 consecutive days)"
echo "- [ ] Target Phase 8 completion"
echo

echo "---"
echo "*Generated by \`axiom_reduction_planner.sh\`*"
echo "*For updates, re-run with \`--strategy <mode>\` and \`--estimate\` flags*"

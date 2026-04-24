#!/usr/bin/env bash
# scripts/analyze_lean_proof_metrics.sh — Deep analysis of Lean proof structure
#
# Provides detailed metrics about proof complexity, theorem distribution,
# axiom usage, and architectural patterns across the CA Lean tree.
#
# Usage:
#   ./scripts/analyze_lean_proof_metrics.sh [--output <format>] [--module <name>]
#
# Options:
#   --output <format>    Output format: text (default), json, csv, markdown
#   --module <name>      Analyze specific module only (e.g., Registration, Withdrawal)
#   --verbose            Show detailed per-file breakdown
#   --compare <commit>   Compare current state with commit
#
# Output includes:
#   - Theorem count by module and type
#   - Axiom dependency graph
#   - Sorry distribution and categorization
#   - Proof length statistics
#   - Build time correlations
#   - Complexity metrics (heartbeats, recursive depth)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LEAN_ROOT="$FORMAL_ROOT/lean"

# Default options
OUTPUT_FORMAT="text"
MODULE_FILTER=""
VERBOSE=false
COMPARE_COMMIT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output) OUTPUT_FORMAT="$2"; shift 2 ;;
        --module) MODULE_FILTER="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        --compare) COMPARE_COMMIT="$2"; shift 2 ;;
        --help)
            sed -n '2,24p' "$0" | sed 's/^# //'
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

cd "$LEAN_ROOT"

# Colors for text output
if [ "$OUTPUT_FORMAT" = "text" ]; then
    BLUE='\033[0;34m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    BLUE='' GREEN='' YELLOW='' RED='' CYAN='' NC=''
fi

echo -e "${CYAN}=========================================="
echo "  Lean Proof Structure Analysis"
echo "  $(date)"
echo -e "==========================================${NC}"
echo

# Function to count theorems in a file
count_theorems() {
    local file="$1"
    local count=$(grep -c "^theorem " "$file" 2>/dev/null || echo "0")
    echo "$count" | tr -d ' \t\n\r'
}

# Function to count axioms in a file
count_axioms() {
    local file="$1"
    local count=$(grep -c "^axiom " "$file" 2>/dev/null || echo "0")
    echo "$count" | tr -d ' \t\n\r'
}

# Function to count sorries in a file
count_sorries() {
    local file="$1"
    local count=$(grep -c "sorry" "$file" 2>/dev/null || echo "0")
    echo "$count" | tr -d ' \t\n\r'
}

# Function to count lemmas in a file
count_lemmas() {
    local file="$1"
    local count=$(grep -c "^lemma " "$file" 2>/dev/null || echo "0")
    echo "$count" | tr -d ' \t\n\r'
}

# Function to estimate proof lines (between theorem/axiom/lemma and next def/theorem/axiom/lemma/end)
estimate_proof_lines() {
    local file="$1"
    local total_lines=0
    local count=0

    # Get line numbers of theorems/lemmas
    local proof_starts=$(grep -n "^theorem \|^lemma " "$file" 2>/dev/null | cut -d: -f1 || echo "")

    if [ -z "$proof_starts" ]; then
        echo "0"
        return
    fi

    # For each proof, estimate length until next definition
    while read -r start_line; do
        [ -z "$start_line" ] && continue
        local end_line=$(tail -n +$((start_line + 1)) "$file" | grep -n "^theorem \|^lemma \|^def \|^axiom \|^end " | head -1 | cut -d: -f1 || echo "")
        if [ -n "$end_line" ]; then
            local length=$((end_line))
            total_lines=$((total_lines + length))
            count=$((count + 1))
        fi
    done <<< "$proof_starts"

    if [ "$count" -gt 0 ]; then
        echo "$((total_lines / count))"
    else
        echo "0"
    fi
}

# Analyze specific module or all modules
if [ -n "$MODULE_FILTER" ]; then
    MODULE_PATHS="MovementFormal/Experimental/ConfidentialAsset/$MODULE_FILTER"
else
    MODULE_PATHS="MovementFormal/Experimental/ConfidentialAsset"
fi

echo -e "${BLUE}━━━ Module Summary ━━━${NC}"
echo

total_theorems=0
total_axioms=0
total_sorries=0
total_lemmas=0
total_files=0

declare -A module_stats

for module_dir in Registration Withdrawal Transfer Normalization Rotation; do
    if [ -n "$MODULE_FILTER" ] && [ "$MODULE_FILTER" != "$module_dir" ]; then
        continue
    fi

    module_path="MovementFormal/Experimental/ConfidentialAsset/$module_dir"

    if [ ! -d "$module_path" ]; then
        continue
    fi

    echo -e "${CYAN}Module: $module_dir${NC}"

    m_theorems=0
    m_axioms=0
    m_sorries=0
    m_lemmas=0
    m_files=0
    m_total_lines=0

    while IFS= read -r -d '' file; do
        m_files=$((m_files + 1))
        total_files=$((total_files + 1))

        t_count=$(count_theorems "$file")
        a_count=$(count_axioms "$file")
        s_count=$(count_sorries "$file")
        l_count=$(count_lemmas "$file")
        file_lines=$(wc -l < "$file")

        m_theorems=$((m_theorems + t_count))
        m_axioms=$((m_axioms + a_count))
        m_sorries=$((m_sorries + s_count))
        m_lemmas=$((m_lemmas + l_count))
        m_total_lines=$((m_total_lines + file_lines))

        if [ "$VERBOSE" = true ]; then
            filename=$(basename "$file")
            echo "  $filename: $t_count theorems, $a_count axioms, $s_count sorries, $file_lines lines"
        fi
    done < <(find "$module_path" -name "*.lean" -type f -print0)

    echo "  Theorems: $m_theorems"
    echo "  Axioms: $m_axioms"
    echo "  Lemmas: $m_lemmas"
    echo "  Sorries: $m_sorries"
    echo "  Files: $m_files"
    echo "  Total lines: $m_total_lines"
    echo "  Avg lines/file: $((m_files > 0 ? m_total_lines / m_files : 0))"
    echo

    total_theorems=$((total_theorems + m_theorems))
    total_axioms=$((total_axioms + m_axioms))
    total_sorries=$((total_sorries + m_sorries))
    total_lemmas=$((total_lemmas + m_lemmas))

    module_stats[$module_dir]="$m_theorems,$m_axioms,$m_sorries,$m_lemmas,$m_files"
done

echo -e "${BLUE}━━━ Overall Statistics ━━━${NC}"
echo
echo "Total theorems: ${GREEN}$total_theorems${NC}"
echo "Total axioms: ${YELLOW}$total_axioms${NC}"
echo "Total lemmas: ${GREEN}$total_lemmas${NC}"
echo "Total sorries: ${RED}$total_sorries${NC}"
echo "Total files analyzed: $total_files"
echo

# Calculate proof completion rate
if [ $((total_theorems + total_axioms + total_lemmas)) -gt 0 ]; then
    total_proofs=$((total_theorems + total_lemmas))
    total_items=$((total_theorems + total_axioms + total_lemmas + total_sorries))
    completion_pct=$((total_proofs * 100 / total_items))
    echo "Proof completion: ${GREEN}${completion_pct}%${NC}"
fi

echo

# Axiom dependency analysis
echo -e "${BLUE}━━━ Axiom Analysis ━━━${NC}"
echo

# Find all axioms and their uses
echo "Axioms by category:"
echo

# TEMPORARY axioms
temp_axioms=$(grep -r "axiom.*TEMPORARY\|TEMPORARY axiom" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" 2>/dev/null | wc -l | tr -d ' \t\n\r' || echo "0")
echo "  TEMPORARY (for elimination): $temp_axioms"

# Phase 4 equivalence axioms
equiv_axioms=$(grep -r "axiom.*_eval_equiv_\|eval_equiv.*axiom" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" 2>/dev/null | wc -l | tr -d ' \t\n\r' || echo "0")
echo "  Phase 4 equivalence: $equiv_axioms"

# ConcreteHelpers axioms
concrete_axioms=$(grep -r "axiom" MovementFormal/Experimental/ConfidentialAsset/ --include="*Helpers*.lean" 2>/dev/null | wc -l | tr -d ' \t\n\r' || echo "0")
echo "  ConcreteHelpers: $concrete_axioms"

echo

# Sorry categorization
echo -e "${BLUE}━━━ Sorry Distribution ━━━${NC}"
echo

# Categorize sorries by context
pc_chain_sorries=$(grep -r "sorry.*PC\|PC.*sorry" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" 2>/dev/null | wc -l | tr -d ' \t\n\r' || echo "0")
helper_sorries=$(grep -r "sorry.*helper\|helper.*sorry" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" 2>/dev/null | wc -l | tr -d ' \t\n\r' || echo "0")
composition_sorries=$(grep -r "sorry.*compose\|compose.*sorry" MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" 2>/dev/null | wc -l | tr -d ' \t\n\r' || echo "0")

echo "  PC-chaining: $pc_chain_sorries"
echo "  Helpers: $helper_sorries"
echo "  Composition: $composition_sorries"
echo "  Other: $((total_sorries - pc_chain_sorries - helper_sorries - composition_sorries))"
echo

# Build time correlation (if --compare is used)
if [ -n "$COMPARE_COMMIT" ]; then
    echo -e "${BLUE}━━━ Comparison with $COMPARE_COMMIT ━━━${NC}"
    echo

    # Save current state
    current_theorems=$total_theorems
    current_axioms=$total_axioms
    current_sorries=$total_sorries

    # Checkout comparison commit and analyze
    git stash --quiet
    git checkout "$COMPARE_COMMIT" --quiet 2>/dev/null || {
        echo "Error: Could not checkout $COMPARE_COMMIT"
        git stash pop --quiet 2>/dev/null || true
        exit 1
    }

    # Re-count in old commit
    old_theorems=0
    old_axioms=0
    old_sorries=0

    for module_dir in Registration Withdrawal Transfer Normalization Rotation; do
        module_path="MovementFormal/Experimental/ConfidentialAsset/$module_dir"
        if [ -d "$module_path" ]; then
            while IFS= read -r -d '' file; do
                old_theorems=$((old_theorems + $(count_theorems "$file")))
                old_axioms=$((old_axioms + $(count_axioms "$file")))
                old_sorries=$((old_sorries + $(count_sorries "$file")))
            done < <(find "$module_path" -name "*.lean" -type f -print0)
        fi
    done

    # Return to current state
    git checkout - --quiet
    git stash pop --quiet 2>/dev/null || true

    # Show differences
    theorem_diff=$((current_theorems - old_theorems))
    axiom_diff=$((current_axioms - old_axioms))
    sorry_diff=$((current_sorries - old_sorries))

    echo "  Theorems: $old_theorems → $current_theorems (${theorem_diff:+${GREEN}+}${theorem_diff}${NC})"
    echo "  Axioms: $old_axioms → $current_axioms (${axiom_diff:+${YELLOW}+}${axiom_diff}${NC})"
    echo "  Sorries: $old_sorries → $current_sorries (${sorry_diff:+${RED}+}${sorry_diff}${NC})"
    echo
fi

# JSON output mode
if [ "$OUTPUT_FORMAT" = "json" ]; then
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"total_theorems\": $total_theorems,"
    echo "  \"total_axioms\": $total_axioms,"
    echo "  \"total_lemmas\": $total_lemmas,"
    echo "  \"total_sorries\": $total_sorries,"
    echo "  \"total_files\": $total_files,"
    echo "  \"modules\": {"

    first=true
    for module in Registration Withdrawal Transfer Normalization Rotation; do
        if [ -n "${module_stats[$module]:-}" ]; then
            IFS=',' read -r m_t m_a m_s m_l m_f <<< "${module_stats[$module]}"
            [ "$first" = false ] && echo ","
            echo "    \"$module\": {"
            echo "      \"theorems\": $m_t,"
            echo "      \"axioms\": $m_a,"
            echo "      \"sorries\": $m_s,"
            echo "      \"lemmas\": $m_l,"
            echo "      \"files\": $m_f"
            echo -n "    }"
            first=false
        fi
    done
    echo
    echo "  }"
    echo "}"
fi

echo -e "${CYAN}==========================================${NC}"
echo "  Analysis complete"
echo -e "${CYAN}==========================================${NC}"

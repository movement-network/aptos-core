#!/usr/bin/env bash
# scripts/quarterly_maintenance.sh — Quarterly CA formal verification health check
#
# Purpose: Comprehensive maintenance automation for long-term verification health
# Frequency: Run quarterly (every 3 months) or before major releases
#
# Usage:
#   ./scripts/quarterly_maintenance.sh                    # Full maintenance check
#   ./scripts/quarterly_maintenance.sh --report-only      # Generate report without fixes
#   ./scripts/quarterly_maintenance.sh --auto-fix         # Apply automated fixes
#   ./scripts/quarterly_maintenance.sh --section axioms   # Run specific section only

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$FORMAL_ROOT/../../.." && pwd)"
cd "$FORMAL_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
MODE="check"
SECTION="all"
REPORT_FILE="audit/quarterly-maintenance-$(date +%Y-%m-%d).md"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Quarterly maintenance automation for CA formal verification.

Options:
  --report-only       Generate report without applying fixes
  --auto-fix          Automatically apply fixes where possible
  --section <name>    Run specific section only (axioms, dependencies, performance, documentation, coverage, git)
  --output <file>     Report output file (default: audit/quarterly-maintenance-YYYY-MM-DD.md)
  --help              Show this help

Sections:
  axioms         - Axiom inventory reconciliation and drift analysis
  dependencies   - Tool version checks and update recommendations
  performance    - Build time regression detection
  documentation  - Documentation consistency and staleness checks
  coverage       - Verification coverage gaps analysis
  git            - Repository hygiene (large files, untracked artifacts)
  all (default)  - Run all sections

Examples:
  $0                           # Full quarterly check
  $0 --report-only             # Generate report only
  $0 --auto-fix                # Apply automated fixes
  $0 --section axioms          # Check axioms only
  $0 --output /tmp/report.md   # Custom output file
EOF
}

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --report-only)
            MODE="report"
            shift
            ;;
        --auto-fix)
            MODE="fix"
            shift
            ;;
        --section)
            SECTION="$2"
            shift 2
            ;;
        --output)
            REPORT_FILE="$2"
            shift 2
            ;;
        --help|-h)
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

# ============================================================================
# Report generation
# ============================================================================

REPORT_CONTENT=""

append_report() {
    REPORT_CONTENT+="$1"$'\n'
}

start_section() {
    local section_name="$1"
    echo ""
    echo -e "${BOLD}${BLUE}═══ $section_name ═══${NC}"
    append_report ""
    append_report "## $section_name"
    append_report ""
}

end_section() {
    append_report ""
}

# ============================================================================
# Section 1: Axiom Inventory and Drift
# ============================================================================

section_axioms() {
    start_section "Section 1: Axiom Inventory and Drift"

    # Check 1: Current axiom count
    echo -e "${BLUE}[1.1] Counting current axioms...${NC}"
    local current_count
    current_count=$(./scripts/check_axioms.sh --count 2>/dev/null || echo "0")
    echo "  Current axiom count: $current_count"
    append_report "**Current Axiom Count:** $current_count"

    # Check 2: Drift since last baseline
    echo ""
    echo -e "${BLUE}[1.2] Checking drift vs baseline...${NC}"
    if ./scripts/check_axioms.sh --diff > /tmp/axiom-drift.txt 2>&1; then
        echo -e "  ${GREEN}✅ No drift detected${NC}"
        append_report "**Drift Status:** ✅ No drift"
    else
        echo -e "  ${YELLOW}⚠️  Drift detected${NC}"
        cat /tmp/axiom-drift.txt | head -20
        append_report "**Drift Status:** ⚠️ Drift detected"
        append_report ""
        append_report '```'
        append_report "$(cat /tmp/axiom-drift.txt | head -50)"
        append_report '```'

        if [ "$MODE" = "fix" ]; then
            echo ""
            echo -e "${BLUE}Updating axiom baseline...${NC}"
            ./scripts/track_axiom_drift.sh --baseline
            echo -e "${GREEN}✅ Baseline updated${NC}"
            append_report ""
            append_report "*Action taken: Baseline updated*"
        fi
    fi
    rm -f /tmp/axiom-drift.txt

    # Check 3: Axiom breakdown by category
    echo ""
    echo -e "${BLUE}[1.3] Axiom breakdown by category...${NC}"
    if [ -f audit/AXIOM_INVENTORY.md ]; then
        local temp_cat
        temp_cat=$(grep -E "(TEMPORARY|CRYPTO|KERNEL|NATIVE):" audit/AXIOM_INVENTORY.md | wc -l || echo "0")
        echo "  Categorized axioms: $temp_cat"
        append_report "**Categorized Axioms:** $temp_cat"

        # Count by category
        for cat in TEMPORARY CRYPTO KERNEL NATIVE; do
            local cat_count
            cat_count=$(grep -c "^### $cat" audit/AXIOM_INVENTORY.md || echo "0")
            if [ "$cat_count" -gt 0 ]; then
                echo "    $cat: $cat_count"
                append_report "- **$cat:** $cat_count"
            fi
        done
    fi

    # Check 4: TEMPORARY axiom alert
    echo ""
    echo -e "${BLUE}[1.4] Checking for TEMPORARY axioms...${NC}"
    local temp_axioms
    temp_axioms=$(grep -c "TEMPORARY" audit/AXIOM_INVENTORY.md 2>/dev/null || echo "0")

    if [ "$temp_axioms" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠️  WARNING: $temp_axioms TEMPORARY axioms found${NC}"
        echo "  TEMPORARY axioms should be eliminated as work completes."
        append_report ""
        append_report "**⚠️ TEMPORARY Axioms:** $temp_axioms (target: 0)"
    else
        echo -e "  ${GREEN}✅ No TEMPORARY axioms${NC}"
        append_report "**TEMPORARY Axioms:** 0 ✅"
    fi

    # Check 5: Axiom target threshold
    echo ""
    echo -e "${BLUE}[1.5] Checking against target threshold...${NC}"
    local target=28
    if [ "$current_count" -le "$target" ]; then
        echo -e "  ${GREEN}✅ Within target (≤$target)${NC}"
        append_report "**Target Threshold:** ✅ $current_count ≤ $target"
    else
        echo -e "  ${RED}❌ Exceeds target: $current_count > $target${NC}"
        echo "  Review axiom-reduction roadmap in AXIOM_INVENTORY.md"
        append_report "**Target Threshold:** ❌ $current_count > $target"
    fi

    end_section
}

# ============================================================================
# Section 2: Tool Dependencies and Versions
# ============================================================================

section_dependencies() {
    start_section "Section 2: Tool Dependencies and Versions"

    # Check 1: Lean toolchain
    echo -e "${BLUE}[2.1] Checking Lean toolchain...${NC}"
    local lean_version
    lean_version=$(lean --version 2>&1 | head -1 || echo "not found")
    echo "  Lean: $lean_version"
    append_report "**Lean Version:** $lean_version"

    local expected_lean="4.24.0"
    if echo "$lean_version" | grep -q "$expected_lean"; then
        echo -e "  ${GREEN}✅ Correct version${NC}"
        append_report "  Status: ✅ Correct"
    else
        echo -e "  ${YELLOW}⚠️  Expected: $expected_lean${NC}"
        append_report "  Status: ⚠️ Expected $expected_lean"
    fi

    # Check 2: Move Prover dependencies
    echo ""
    echo -e "${BLUE}[2.2] Checking Move Prover dependencies...${NC}"

    if [ -n "${Z3_EXE:-}" ] && [ -x "$Z3_EXE" ]; then
        local z3_version
        z3_version=$("$Z3_EXE" --version 2>&1 | head -1 || echo "error")
        echo "  Z3: $z3_version"
        append_report "**Z3 Version:** $z3_version"

        if echo "$z3_version" | grep -q "4.11.2"; then
            echo -e "  ${GREEN}✅ Correct version${NC}"
            append_report "  Status: ✅ Correct"
        else
            echo -e "  ${YELLOW}⚠️  Expected: 4.11.2${NC}"
            append_report "  Status: ⚠️ Expected 4.11.2"
        fi
    else
        echo -e "  ${YELLOW}⚠️  Z3 not found (check \$Z3_EXE)${NC}"
        append_report "**Z3:** ⚠️ Not found"
    fi

    if [ -n "${BOOGIE_EXE:-}" ] && [ -x "$BOOGIE_EXE" ]; then
        local boogie_version
        boogie_version=$("$BOOGIE_EXE" -version 2>&1 | head -1 || echo "error")
        echo "  Boogie: $boogie_version"
        append_report "**Boogie Version:** $boogie_version"
    else
        echo -e "  ${YELLOW}⚠️  Boogie not found (check \$BOOGIE_EXE)${NC}"
        append_report "**Boogie:** ⚠️ Not found"
    fi

    # Check 3: Movement CLI
    echo ""
    echo -e "${BLUE}[2.3] Checking Movement CLI...${NC}"
    if command -v movement &> /dev/null; then
        local movement_version
        movement_version=$(movement --version 2>&1 | head -1 || echo "error")
        echo "  Movement: $movement_version"
        append_report "**Movement CLI:** $movement_version"
    else
        echo -e "  ${YELLOW}⚠️  Movement CLI not found${NC}"
        append_report "**Movement CLI:** ⚠️ Not found"
    fi

    # Check 4: Rust toolchain
    echo ""
    echo -e "${BLUE}[2.4] Checking Rust toolchain...${NC}"
    if command -v cargo &> /dev/null; then
        local rust_version
        rust_version=$(cargo --version 2>&1 || echo "error")
        echo "  Cargo: $rust_version"
        append_report "**Cargo Version:** $rust_version"
    else
        echo -e "  ${YELLOW}⚠️  Cargo not found${NC}"
        append_report "**Cargo:** ⚠️ Not found"
    fi

    # Check 5: Mathlib cache status
    echo ""
    echo -e "${BLUE}[2.5] Checking Mathlib cache...${NC}"
    if [ -d lean/.lake/build/lib ]; then
        local cache_size
        cache_size=$(du -sh lean/.lake/build/lib 2>/dev/null | cut -f1 || echo "unknown")
        echo "  Mathlib cache: $cache_size"
        append_report "**Mathlib Cache:** $cache_size"

        # Check age
        local cache_age_days
        cache_age_days=$(find lean/.lake/build/lib -type f -name "*.olean" -mtime +90 | wc -l || echo "0")
        if [ "$cache_age_days" -gt 100 ]; then
            echo -e "  ${YELLOW}⚠️  Cache may be stale (>90 days old)${NC}"
            echo "  Recommend: cd lean && lake exe cache get!"
            append_report "  Status: ⚠️ Stale (recommend refresh)"
        else
            echo -e "  ${GREEN}✅ Cache is fresh${NC}"
            append_report "  Status: ✅ Fresh"
        fi
    else
        echo -e "  ${YELLOW}⚠️  No Mathlib cache found${NC}"
        append_report "**Mathlib Cache:** ⚠️ Not found"
    fi

    end_section
}

# ============================================================================
# Section 3: Performance Regression Detection
# ============================================================================

section_performance() {
    start_section "Section 3: Performance Regression Detection"

    # Check 1: Lean build time
    echo -e "${BLUE}[3.1] Measuring Lean build time...${NC}"
    echo "  Running: cd lean && lake build (cold build simulation)"

    cd lean
    rm -rf .lake/build/MovementFormal 2>/dev/null || true  # Clear only our modules
    local start_time
    start_time=$(date +%s)

    if lake build > /tmp/lean-build.log 2>&1; then
        local end_time
        end_time=$(date +%s)
        local elapsed=$((end_time - start_time))

        echo "  Build time: ${elapsed}s"
        append_report "**Lean Build Time:** ${elapsed}s"

        local target=600  # 10 min
        if [ "$elapsed" -le "$target" ]; then
            echo -e "  ${GREEN}✅ Within budget (<${target}s)${NC}"
            append_report "  Status: ✅ Within budget (<${target}s)"
        else
            echo -e "  ${RED}❌ Exceeds budget: ${elapsed}s > ${target}s${NC}"
            append_report "  Status: ❌ Exceeds budget"
        fi
    else
        echo -e "  ${RED}❌ Build failed${NC}"
        cat /tmp/lean-build.log | tail -20
        append_report "**Lean Build:** ❌ Failed"
    fi

    cd "$FORMAL_ROOT"
    rm -f /tmp/lean-build.log

    # Check 2: Per-operation build times
    echo ""
    echo -e "${BLUE}[3.2] Per-operation build times...${NC}"
    for op in Registration Normalization Withdrawal Transfer Rotation; do
        echo -n "  $op: "
        cd lean
        local op_start
        op_start=$(date +%s)
        if lake build "MovementFormal.Experimental.ConfidentialAsset.$op.EvalEquiv" > /dev/null 2>&1 || \
           lake build "MovementFormal.Experimental.ConfidentialAsset.$op.EvalEquivRebuild" > /dev/null 2>&1; then
            local op_end
            op_end=$(date +%s)
            local op_elapsed=$((op_end - op_start))
            echo "${op_elapsed}s"
            append_report "- **$op:** ${op_elapsed}s"

            if [ "$op_elapsed" -gt 180 ]; then  # 3 min
                echo -e "    ${YELLOW}⚠️  Exceeds per-file budget (180s)${NC}"
            fi
        else
            echo "error"
            append_report "- **$op:** ❌ Build failed"
        fi
        cd "$FORMAL_ROOT"
    done

    # Check 3: verify-ca.sh timing
    echo ""
    echo -e "${BLUE}[3.3] verify-ca.sh performance...${NC}"
    if [ -x audit/verify-ca.sh ]; then
        for op in register withdraw transfer normalize rotate; do
            echo -n "  $op (Lean): "
            local verify_start
            verify_start=$(date +%s)
            if ./audit/verify-ca.sh --op "$op" --stack lean > /dev/null 2>&1; then
                local verify_end
                verify_end=$(date +%s)
                local verify_elapsed=$((verify_end - verify_start))
                echo "${verify_elapsed}s"
                append_report "- **verify-ca.sh $op (Lean):** ${verify_elapsed}s"

                if [ "$verify_elapsed" -gt 180 ]; then
                    echo -e "    ${YELLOW}⚠️  Exceeds target (180s)${NC}"
                fi
            else
                echo "error"
            fi
        done
    fi

    end_section
}

# ============================================================================
# Section 4: Documentation Consistency
# ============================================================================

section_documentation() {
    start_section "Section 4: Documentation Consistency"

    # Check 1: README age
    echo -e "${BLUE}[4.1] Checking README freshness...${NC}"
    if [ -f README.md ]; then
        local readme_age
        readme_age=$(find README.md -mtime +180 -print 2>/dev/null || echo "")
        if [ -n "$readme_age" ]; then
            echo -e "  ${YELLOW}⚠️  README.md not updated in 6+ months${NC}"
            append_report "**README.md:** ⚠️ Stale (>6 months)"
        else
            echo -e "  ${GREEN}✅ README.md is fresh${NC}"
            append_report "**README.md:** ✅ Fresh"
        fi
    fi

    # Check 2: Verification plan status sync
    echo ""
    echo -e "${BLUE}[4.2] Checking plan status accuracy...${NC}"
    local plan_file="CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md"

    if [ -f "$plan_file" ]; then
        # Count status marks
        local complete_count
        local in_progress_count
        local pending_count

        complete_count=$(grep -c "✅ COMPLETE" "$plan_file" || echo "0")
        in_progress_count=$(grep -c "🟡 in progress" "$plan_file" || echo "0")
        pending_count=$(grep -c "☐ pending" "$plan_file" || echo "0")

        echo "  Phase status marks:"
        echo "    Complete:    $complete_count"
        echo "    In progress: $in_progress_count"
        echo "    Pending:     $pending_count"

        append_report "**Verification Plan Status:**"
        append_report "- Complete: $complete_count"
        append_report "- In progress: $in_progress_count"
        append_report "- Pending: $pending_count"
    fi

    # Check 3: Broken internal links
    echo ""
    echo -e "${BLUE}[4.3] Checking for broken internal links...${NC}"
    local broken_links=0

    while IFS= read -r md_file; do
        # Extract markdown links
        while IFS= read -r link; do
            if [[ "$link" =~ \[.*\]\((.*\.md)\) ]]; then
                local link_target="${BASH_REMATCH[1]}"
                # Check if file exists
                if [ ! -f "$link_target" ] && [ ! -f "$(dirname "$md_file")/$link_target" ]; then
                    echo -e "  ${YELLOW}⚠️  Broken link in $md_file: $link_target${NC}"
                    broken_links=$((broken_links + 1))
                fi
            fi
        done < <(grep -o '\[.*\](.*\.md)' "$md_file" 2>/dev/null || true)
    done < <(find . -maxdepth 1 -name "*.md" -not -name "WORK_SESSION*" 2>/dev/null || true)

    if [ "$broken_links" -eq 0 ]; then
        echo -e "  ${GREEN}✅ No broken links found${NC}"
        append_report "**Broken Links:** 0 ✅"
    else
        echo -e "  ${YELLOW}⚠️  Found $broken_links broken links${NC}"
        append_report "**Broken Links:** $broken_links ⚠️"
    fi

    # Check 4: Session summary accumulation
    echo ""
    echo -e "${BLUE}[4.4] Checking session documentation...${NC}"
    local session_docs
    session_docs=$(find . -maxdepth 1 -name "WORK_SESSION_*.md" | wc -l || echo "0")

    echo "  Work session files: $session_docs"
    append_report "**Work Session Files:** $session_docs"

    if [ "$session_docs" -gt 20 ]; then
        echo -e "  ${YELLOW}⚠️  Consider archiving old session docs to audit/sessions/${NC}"
        append_report "  Note: Consider archiving"

        if [ "$MODE" = "fix" ]; then
            mkdir -p audit/sessions
            find . -maxdepth 1 -name "WORK_SESSION_*.md" -mtime +90 -exec mv {} audit/sessions/ \; 2>/dev/null || true
            echo -e "  ${GREEN}✅ Archived sessions >90 days old${NC}"
            append_report "  *Action taken: Archived old sessions*"
        fi
    fi

    end_section
}

# ============================================================================
# Section 5: Verification Coverage Gaps
# ============================================================================

section_coverage() {
    start_section "Section 5: Verification Coverage Gaps"

    # Check 1: Difftest corpus size
    echo -e "${BLUE}[5.1] Difftest corpus coverage...${NC}"
    if [ -x scripts/manage_difftest_corpus.sh ]; then
        echo "  Running: ./scripts/manage_difftest_corpus.sh stats"
        ./scripts/manage_difftest_corpus.sh stats > /tmp/corpus-stats.txt 2>&1 || true

        local total_rows
        total_rows=$(grep "Total corpus rows" /tmp/corpus-stats.txt | awk '{print $NF}' || echo "unknown")
        echo "  Total corpus rows: $total_rows"
        append_report "**Difftest Corpus Size:** $total_rows rows"

        # Extract coverage percentages
        grep -E "(Passing|Pending|Blocked)" /tmp/corpus-stats.txt | while read -r line; do
            append_report "- $line"
        done

        rm -f /tmp/corpus-stats.txt
    fi

    # Check 2: MSL spec coverage
    echo ""
    echo -e "${BLUE}[5.2] Move Prover spec coverage...${NC}"
    local spec_files
    spec_files=$(find ../aptos-experimental/sources/confidential_asset -name "*.spec.move" | wc -l || echo "0")
    echo "  Spec files: $spec_files"
    append_report "**MSL Spec Files:** $spec_files"

    # Count spec blocks
    local spec_blocks
    spec_blocks=$(grep -r "^spec " ../aptos-experimental/sources/confidential_asset/*.spec.move 2>/dev/null | wc -l || echo "0")
    echo "  Spec blocks: $spec_blocks"
    append_report "**Spec Blocks:** $spec_blocks"

    # Check 3: Lean proof coverage (Phase 4)
    echo ""
    echo -e "${BLUE}[5.3] Lean EvalEquiv coverage (Phase 4)...${NC}"
    for op in Registration Normalization Withdrawal Transfer Rotation; do
        local op_file="lean/MovementFormal/Experimental/ConfidentialAsset/$op/EvalEquiv.lean"
        if [ ! -f "$op_file" ]; then
            op_file="lean/MovementFormal/Experimental/ConfidentialAsset/$op/EvalEquivRebuild.lean"
        fi

        if [ -f "$op_file" ]; then
            local sorry_count
            sorry_count=$(grep -c "^sorry" "$op_file" 2>/dev/null || echo "0")
            if [ "$sorry_count" -eq 0 ]; then
                echo -e "  $op: ${GREEN}✅ Complete (0 sorry)${NC}"
                append_report "- **$op:** ✅ Complete"
            else
                echo -e "  $op: ${YELLOW}⚠️  $sorry_count sorry placeholders${NC}"
                append_report "- **$op:** ⚠️ $sorry_count sorry"
            fi
        else
            echo -e "  $op: ${RED}❌ File not found${NC}"
            append_report "- **$op:** ❌ Not found"
        fi
    done

    # Check 4: Phase 6 composition status
    echo ""
    echo -e "${BLUE}[5.4] Phase 6 composition coverage...${NC}"
    for op in Registration Normalization Withdrawal Transfer Rotation; do
        local comp_file="lean/MovementFormal/Experimental/ConfidentialAsset/$op/Phase6Composition.lean"

        if [ -f "$comp_file" ]; then
            local comp_sorry
            comp_sorry=$(grep -c "^sorry" "$comp_file" 2>/dev/null || echo "0")
            if [ "$comp_sorry" -eq 0 ]; then
                echo -e "  $op: ${GREEN}✅ Composition complete${NC}"
                append_report "- **$op composition:** ✅ Complete"
            else
                echo -e "  $op: ${YELLOW}⚠️  $comp_sorry sorry in composition${NC}"
                append_report "- **$op composition:** ⚠️ $comp_sorry sorry"
            fi
        else
            echo -e "  $op: ${YELLOW}⚠️  No composition file${NC}"
            append_report "- **$op composition:** ⚠️ Not found"
        fi
    done

    end_section
}

# ============================================================================
# Section 6: Repository Hygiene
# ============================================================================

section_git() {
    start_section "Section 6: Repository Hygiene"

    # Check 1: Large files
    echo -e "${BLUE}[6.1] Checking for large files (>1MB)...${NC}"
    local large_files
    large_files=$(find . -type f -size +1M ! -path "./.lake/*" ! -path "./.git/*" ! -path "*/node_modules/*" 2>/dev/null || true)

    if [ -n "$large_files" ]; then
        echo -e "  ${YELLOW}⚠️  Large files found:${NC}"
        echo "$large_files" | while read -r file; do
            local size
            size=$(du -h "$file" | cut -f1)
            echo "    $size  $file"
            append_report "- $size $file"
        done
    else
        echo -e "  ${GREEN}✅ No large files${NC}"
        append_report "**Large Files:** None ✅"
    fi

    # Check 2: Untracked artifacts
    echo ""
    echo -e "${BLUE}[6.2] Checking for untracked build artifacts...${NC}"
    local untracked_artifacts
    untracked_artifacts=$(git status --porcelain | grep "^??" | grep -E "\.(olean|ilean|trace|bpl)$" || true)

    if [ -n "$untracked_artifacts" ]; then
        echo -e "  ${YELLOW}⚠️  Untracked artifacts (should be in .gitignore):${NC}"
        echo "$untracked_artifacts" | head -10
        append_report "**Untracked Artifacts:** ⚠️ Found"

        if [ "$MODE" = "fix" ]; then
            echo "  Recommend adding to .gitignore"
        fi
    else
        echo -e "  ${GREEN}✅ No untracked artifacts${NC}"
        append_report "**Untracked Artifacts:** None ✅"
    fi

    # Check 3: Stale branches (local)
    echo ""
    echo -e "${BLUE}[6.3] Checking for stale local branches...${NC}"
    local stale_branches
    stale_branches=$(git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short) %(committerdate:relative)' | \
        awk '$2 ~ /month|year/ {print}' | wc -l || echo "0")

    if [ "$stale_branches" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠️  $stale_branches branches not updated in >1 month${NC}"
        git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short) %(committerdate:relative)' | \
            awk '$2 ~ /month|year/ {print "    " $0}' | head -5
        append_report "**Stale Branches:** $stale_branches ⚠️"
    else
        echo -e "  ${GREEN}✅ No stale branches${NC}"
        append_report "**Stale Branches:** None ✅"
    fi

    # Check 4: Uncommitted changes
    echo ""
    echo -e "${BLUE}[6.4] Checking working tree status...${NC}"
    if [ -n "$(git status --porcelain formal/)" ]; then
        echo -e "  ${YELLOW}⚠️  Uncommitted changes in formal/${NC}"
        append_report "**Working Tree:** ⚠️ Uncommitted changes"
    else
        echo -e "  ${GREEN}✅ Clean working tree${NC}"
        append_report "**Working Tree:** ✅ Clean"
    fi

    end_section
}

# ============================================================================
# Main execution
# ============================================================================

echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║  CA Formal Verification Quarterly Maintenance             ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Date: $(date +%Y-%m-%d)"
echo "Mode: $MODE"
echo "Section: $SECTION"
echo "Report output: $REPORT_FILE"
echo ""

# Initialize report
append_report "# CA Formal Verification Quarterly Maintenance Report"
append_report ""
append_report "**Date:** $(date +%Y-%m-%d)"
append_report "**Mode:** $MODE"
append_report "**Generated by:** scripts/quarterly_maintenance.sh"
append_report ""
append_report "---"

# Run sections
if [ "$SECTION" = "all" ] || [ "$SECTION" = "axioms" ]; then
    section_axioms
fi

if [ "$SECTION" = "all" ] || [ "$SECTION" = "dependencies" ]; then
    section_dependencies
fi

if [ "$SECTION" = "all" ] || [ "$SECTION" = "performance" ]; then
    section_performance
fi

if [ "$SECTION" = "all" ] || [ "$SECTION" = "documentation" ]; then
    section_documentation
fi

if [ "$SECTION" = "all" ] || [ "$SECTION" = "coverage" ]; then
    section_coverage
fi

if [ "$SECTION" = "all" ] || [ "$SECTION" = "git" ]; then
    section_git
fi

# Write report
echo ""
echo -e "${BLUE}Writing report to $REPORT_FILE...${NC}"
echo "$REPORT_CONTENT" > "$REPORT_FILE"
echo -e "${GREEN}✅ Report written${NC}"

# Summary
echo ""
echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║  Maintenance Complete                                      ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Report saved to: $REPORT_FILE"
echo ""

if [ "$MODE" = "report" ]; then
    echo "Mode: Report-only (no fixes applied)"
    echo "To apply automated fixes, run with --auto-fix"
elif [ "$MODE" = "fix" ]; then
    echo "Mode: Auto-fix (fixes applied where possible)"
    echo "Review changes and commit if appropriate"
else
    echo "Mode: Check (issues identified, no fixes applied)"
    echo "To fix issues, run with --auto-fix"
fi

echo ""
echo "Next quarterly maintenance due: $(date -d '+3 months' +%Y-%m-%d 2>/dev/null || date -v +3m +%Y-%m-%d)"

exit 0

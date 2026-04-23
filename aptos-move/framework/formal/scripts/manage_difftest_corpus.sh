#!/usr/bin/env bash
# scripts/manage_difftest_corpus.sh — Difftest corpus management automation
#
# Purpose: Add, validate, and manage difftest corpus rows for CA verification
# Operations: add, validate, list, stats, prune, export
#
# Usage:
#   ./scripts/manage_difftest_corpus.sh add --operation transfer --case happy_path
#   ./scripts/manage_difftest_corpus.sh validate
#   ./scripts/manage_difftest_corpus.sh stats
#   ./scripts/manage_difftest_corpus.sh list --operation withdraw
#   ./scripts/manage_difftest_corpus.sh prune --stale
#   ./scripts/manage_difftest_corpus.sh export --format markdown

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$FORMAL_ROOT/../../.." && pwd)"
DIFFTEST_DIR="$FORMAL_ROOT/difftest"
INVENTORY_DIR="$DIFFTEST_DIR/inventory"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $0 <command> [OPTIONS]

Manage difftest corpus rows for CA formal verification.

Commands:
  add         Add new corpus row for an operation
  validate    Validate corpus integrity and coverage
  list        List corpus rows (optionally filtered by operation)
  stats       Show corpus statistics and coverage metrics
  prune       Remove stale or redundant corpus rows
  export      Export corpus inventory in various formats
  sync        Sync corpus with RunnerFuncMappingAux.lean

Options (add):
  --operation <op>    Operation name (register, withdraw, transfer, normalize, rotate)
  --case <name>       Test case name (e.g., happy_path, frozen_account, invalid_proof)
  --description <txt> Human-readable description
  --skip-lean         Mark as VM-only (skip Lean evaluation)
  --interactive       Interactive mode with prompts

Options (list):
  --operation <op>    Filter by operation
  --stack <stack>     Filter by stack (lean, vm-only, both)
  --status <status>   Filter by status (passing, blocked, pending)

Options (prune):
  --stale             Remove rows with no corresponding Lean mapping
  --redundant         Remove duplicate coverage
  --dry-run           Show what would be pruned without removing

Options (export):
  --format <fmt>      Output format (markdown, json, csv, html)
  --output <file>     Output file (default: stdout)

Examples:
  # Add new test case interactively
  $0 add --interactive

  # Add specific test case
  $0 add --operation transfer --case sender_frozen --description "Transfer from frozen sender account"

  # Validate full corpus
  $0 validate

  # Show statistics
  $0 stats

  # List all withdraw test cases
  $0 list --operation withdraw

  # Export coverage report as HTML
  $0 export --format html --output corpus-coverage.html

  # Sync corpus with Lean mappings
  $0 sync
EOF
}

# ============================================================================
# Corpus inventory parsing
# ============================================================================

get_inventory_file() {
    echo "$INVENTORY_DIR/confidential_assets.md"
}

parse_inventory_stats() {
    local inventory_file
    inventory_file=$(get_inventory_file)

    if [ ! -f "$inventory_file" ]; then
        echo "ERROR: Inventory file not found: $inventory_file" >&2
        return 1
    fi

    # Count rows by status
    local total_rows
    local lean_rows
    local vm_only_rows
    local blocked_rows

    total_rows=$(grep -c "^|" "$inventory_file" | tail -1 || echo "0")
    lean_rows=$(grep -c "| Lean |" "$inventory_file" || echo "0")
    vm_only_rows=$(grep -c "| VM only |" "$inventory_file" || echo "0")
    blocked_rows=$(grep -c "| Blocked |" "$inventory_file" || echo "0")

    echo "total:$total_rows lean:$lean_rows vm_only:$vm_only_rows blocked:$blocked_rows"
}

# ============================================================================
# Command: add
# ============================================================================

cmd_add() {
    local operation=""
    local case_name=""
    local description=""
    local skip_lean=false
    local interactive=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --operation)
                operation="$2"
                shift 2
                ;;
            --case)
                case_name="$2"
                shift 2
                ;;
            --description)
                description="$2"
                shift 2
                ;;
            --skip-lean)
                skip_lean=true
                shift
                ;;
            --interactive)
                interactive=true
                shift
                ;;
            *)
                echo -e "${RED}ERROR: Unknown option '$1'${NC}" >&2
                usage >&2
                exit 1
                ;;
        esac
    done

    if [ "$interactive" = true ]; then
        echo -e "${BLUE}Adding new difftest corpus row (interactive mode)${NC}"
        echo ""

        read -p "Operation (register/withdraw/transfer/normalize/rotate): " operation
        read -p "Test case name (snake_case): " case_name
        read -p "Description: " description
        read -p "Skip Lean evaluation? (y/N): " skip_choice

        if [[ "$skip_choice" =~ ^[Yy]$ ]]; then
            skip_lean=true
        fi
    fi

    # Validate required fields
    if [ -z "$operation" ] || [ -z "$case_name" ]; then
        echo -e "${RED}ERROR: --operation and --case are required${NC}" >&2
        usage >&2
        exit 1
    fi

    # Validate operation
    case "$operation" in
        register|withdraw|transfer|normalize|rotate)
            ;;
        *)
            echo -e "${RED}ERROR: Invalid operation '$operation'${NC}" >&2
            echo "Valid operations: register, withdraw, transfer, normalize, rotate" >&2
            exit 1
            ;;
    esac

    echo ""
    echo -e "${BLUE}Adding corpus row:${NC}"
    echo "  Operation:   $operation"
    echo "  Case:        $case_name"
    echo "  Description: $description"
    echo "  Skip Lean:   $skip_lean"
    echo ""

    # Generate corpus entry template
    local corpus_id="${operation}_${case_name}"
    local stack_column
    if [ "$skip_lean" = true ]; then
        stack_column="VM only"
    else
        stack_column="Lean"
    fi

    # Add to inventory file
    local inventory_file
    inventory_file=$(get_inventory_file)

    # Create backup
    cp "$inventory_file" "${inventory_file}.bak"

    # Find the right section and append
    local temp_file
    temp_file=$(mktemp)

    awk -v op="$operation" -v id="$corpus_id" -v desc="$description" -v stack="$stack_column" '
    BEGIN { found_section = 0; added = 0 }
    /^### / {
        if (found_section && !added) {
            # Reached next section, add before it
            printf "| %s | %s | %s | Pending |\n", id, desc, stack
            added = 1
        }
        found_section = 0
    }
    tolower($0) ~ tolower(op) && /^### / {
        found_section = 1
    }
    { print }
    END {
        if (found_section && !added) {
            printf "| %s | %s | %s | Pending |\n", id, desc, stack
        }
    }
    ' "$inventory_file" > "$temp_file"

    mv "$temp_file" "$inventory_file"

    echo -e "${GREEN}✅ Added corpus row to inventory${NC}"
    echo ""

    # Generate TODO for Lean mapping
    if [ "$skip_lean" = false ]; then
        echo -e "${YELLOW}TODO: Add Lean mapping${NC}"
        echo ""
        echo "Add to lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean:"
        echo ""
        echo "  | \"$corpus_id\" =>"
        echo "    some { funcIdx := ${operation}FuncIdx"
        echo "           env := { ... }  -- configure module environment"
        echo "           cs := { ... }   -- configure call stack"
        echo "           stack := [...]  -- initial stack"
        echo "           ms := { ... }   -- machine state"
        echo "         }"
        echo ""
    fi

    # Generate TODO for Rust oracle
    echo -e "${YELLOW}TODO: Add Rust oracle generation${NC}"
    echo ""
    echo "Add to move-lean-difftest/src/suites/confidential_asset.rs:"
    echo ""
    echo "  TestCase {"
    echo "      id: \"$corpus_id\".into(),"
    echo "      oracle_fn: Box::new(|h| {"
    echo "          // Generate oracle for $case_name"
    echo "          // Return OracleResult"
    echo "      }),"
    echo "      skip_lean: $skip_lean,"
    echo "  },"
    echo ""

    echo -e "${GREEN}Corpus row added successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Implement Rust oracle generation"
    if [ "$skip_lean" = false ]; then
        echo "  2. Add Lean mapping to RunnerFuncMappingAux.lean"
        echo "  3. Run: ./difftest.sh --suite confidential_asset"
    else
        echo "  2. Run: cargo run -p move-lean-difftest -- --suite confidential_asset"
    fi
    echo "  4. Update row status to 'Passing' when green"
}

# ============================================================================
# Command: validate
# ============================================================================

cmd_validate() {
    echo -e "${BLUE}Validating difftest corpus integrity...${NC}"
    echo ""

    local errors=0

    # Check 1: Inventory file exists
    echo -e "${BLUE}[1/6] Checking inventory file...${NC}"
    local inventory_file
    inventory_file=$(get_inventory_file)

    if [ ! -f "$inventory_file" ]; then
        echo -e "${RED}❌ FAIL: Inventory file not found${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✅ PASS${NC}"
    fi

    # Check 2: No duplicate IDs
    echo ""
    echo -e "${BLUE}[2/6] Checking for duplicate corpus IDs...${NC}"
    local duplicates
    duplicates=$(grep "^|" "$inventory_file" | awk -F'|' '{print $2}' | sort | uniq -d | xargs)

    if [ -n "$duplicates" ]; then
        echo -e "${RED}❌ FAIL: Duplicate IDs found: $duplicates${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✅ PASS${NC}"
    fi

    # Check 3: Rust oracle coverage
    echo ""
    echo -e "${BLUE}[3/6] Checking Rust oracle coverage...${NC}"
    local rust_suite="$REPO_ROOT/move-lean-difftest/src/suites/confidential_asset.rs"

    if [ ! -f "$rust_suite" ]; then
        echo -e "${YELLOW}⚠️  WARNING: Rust suite not found at $rust_suite${NC}"
    else
        # Count test cases in Rust
        local rust_count
        rust_count=$(grep -c 'TestCase {' "$rust_suite" || echo "0")
        echo "  Rust test cases: $rust_count"
        echo -e "${GREEN}✅ PASS${NC}"
    fi

    # Check 4: Lean mapping coverage
    echo ""
    echo -e "${BLUE}[4/6] Checking Lean mapping coverage...${NC}"
    local lean_mapping="$FORMAL_ROOT/lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean"

    if [ ! -f "$lean_mapping" ]; then
        echo -e "${YELLOW}⚠️  WARNING: Lean mapping not found${NC}"
    else
        # Count Lean rows (non-VM-only)
        local lean_required
        lean_required=$(grep -c "| Lean |" "$inventory_file" || echo "0")

        local lean_mapped
        lean_mapped=$(grep -c "| \".*\" =>" "$lean_mapping" || echo "0")

        echo "  Lean rows in inventory: $lean_required"
        echo "  Lean mappings found:    $lean_mapped"

        if [ "$lean_mapped" -lt "$lean_required" ]; then
            echo -e "${YELLOW}⚠️  WARNING: Some Lean rows may be unmapped${NC}"
        else
            echo -e "${GREEN}✅ PASS${NC}"
        fi
    fi

    # Check 5: Operation coverage
    echo ""
    echo -e "${BLUE}[5/6] Checking operation coverage...${NC}"
    for op in register withdraw transfer normalize rotate; do
        local op_count
        op_count=$(grep -ci "^| ${op}_" "$inventory_file" || echo "0")
        printf "  %-12s %3d rows\n" "$op:" "$op_count"
    done
    echo -e "${GREEN}✅ PASS${NC}"

    # Check 6: Status distribution
    echo ""
    echo -e "${BLUE}[6/6] Checking status distribution...${NC}"
    for status in Passing Pending Blocked; do
        local status_count
        status_count=$(grep -c "| $status |" "$inventory_file" || echo "0")
        printf "  %-12s %3d rows\n" "$status:" "$status_count"
    done
    echo -e "${GREEN}✅ PASS${NC}"

    # Summary
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════${NC}"
    if [ "$errors" -eq 0 ]; then
        echo -e "${GREEN}✅ All validation checks passed!${NC}"
    else
        echo -e "${RED}❌ Validation failed with $errors error(s)${NC}"
        return 1
    fi
}

# ============================================================================
# Command: stats
# ============================================================================

cmd_stats() {
    echo -e "${BOLD}${BLUE}Difftest Corpus Statistics${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local inventory_file
    inventory_file=$(get_inventory_file)

    if [ ! -f "$inventory_file" ]; then
        echo -e "${RED}ERROR: Inventory file not found${NC}" >&2
        exit 1
    fi

    # Overall stats
    local total_rows
    total_rows=$(grep -c "^|" "$inventory_file" | tail -1 || echo "0")
    total_rows=$((total_rows - 5))  # Subtract header rows

    echo -e "${BOLD}Overall Coverage${NC}"
    echo "  Total corpus rows:    $total_rows"

    # Stack breakdown
    local lean_rows
    local vm_only_rows
    local blocked_rows

    lean_rows=$(grep -c "| Lean |" "$inventory_file" || echo "0")
    vm_only_rows=$(grep -c "| VM only |" "$inventory_file" || echo "0")
    blocked_rows=$(grep -c "| Blocked |" "$inventory_file" || echo "0")

    echo ""
    echo -e "${BOLD}Stack Distribution${NC}"
    printf "  Lean evaluation:      %3d (%.1f%%)\n" \
        "$lean_rows" "$(awk "BEGIN {print ($lean_rows * 100.0) / $total_rows}")"
    printf "  VM-only:              %3d (%.1f%%)\n" \
        "$vm_only_rows" "$(awk "BEGIN {print ($vm_only_rows * 100.0) / $total_rows}")"
    printf "  Blocked:              %3d (%.1f%%)\n" \
        "$blocked_rows" "$(awk "BEGIN {print ($blocked_rows * 100.0) / $total_rows}")"

    # Status breakdown
    local passing_rows
    local pending_rows

    passing_rows=$(grep -c "| Passing |" "$inventory_file" || echo "0")
    pending_rows=$(grep -c "| Pending |" "$inventory_file" || echo "0")

    echo ""
    echo -e "${BOLD}Status Distribution${NC}"
    printf "  Passing:              %3d (%.1f%%)\n" \
        "$passing_rows" "$(awk "BEGIN {print ($passing_rows * 100.0) / $total_rows}")"
    printf "  Pending:              %3d (%.1f%%)\n" \
        "$pending_rows" "$(awk "BEGIN {print ($pending_rows * 100.0) / $total_rows}")"
    printf "  Blocked:              %3d (%.1f%%)\n" \
        "$blocked_rows" "$(awk "BEGIN {print ($blocked_rows * 100.0) / $total_rows}")"

    # Per-operation breakdown
    echo ""
    echo -e "${BOLD}Per-Operation Coverage${NC}"
    echo ""
    printf "  %-12s %6s %6s %6s %6s\n" "Operation" "Total" "Lean" "VM-only" "Status"
    echo "  ─────────────────────────────────────────────────────"

    for op in register withdraw transfer normalize rotate; do
        local op_total
        local op_lean
        local op_vm
        local op_passing

        op_total=$(grep -ci "^| ${op}_" "$inventory_file" || echo "0")
        op_lean=$(grep "^| ${op}_" "$inventory_file" | grep -c "| Lean |" || echo "0")
        op_vm=$(grep "^| ${op}_" "$inventory_file" | grep -c "| VM only |" || echo "0")
        op_passing=$(grep "^| ${op}_" "$inventory_file" | grep -c "| Passing |" || echo "0")

        if [ "$op_total" -gt 0 ]; then
            local pass_pct
            pass_pct=$(awk "BEGIN {print ($op_passing * 100.0) / $op_total}")
            printf "  %-12s %6d %6d %6d %5.1f%%\n" \
                "$op" "$op_total" "$op_lean" "$op_vm" "$pass_pct"
        fi
    done

    echo ""

    # Coverage gaps
    echo -e "${BOLD}Coverage Gaps${NC}"
    echo ""

    local has_gaps=false

    # Check for operations with < 5 test cases
    for op in register withdraw transfer normalize rotate; do
        local op_count
        op_count=$(grep -ci "^| ${op}_" "$inventory_file" || echo "0")

        if [ "$op_count" -lt 5 ]; then
            echo -e "  ${YELLOW}⚠️  $op: only $op_count test cases (recommend ≥5)${NC}"
            has_gaps=true
        fi
    done

    # Check for missing error paths
    if ! grep -q "invalid_proof" "$inventory_file"; then
        echo -e "  ${YELLOW}⚠️  Missing 'invalid_proof' error path coverage${NC}"
        has_gaps=true
    fi

    if ! grep -q "frozen" "$inventory_file"; then
        echo -e "  ${YELLOW}⚠️  Missing 'frozen account' error path coverage${NC}"
        has_gaps=true
    fi

    if [ "$has_gaps" = false ]; then
        echo -e "  ${GREEN}No significant gaps detected${NC}"
    fi

    echo ""
}

# ============================================================================
# Command: list
# ============================================================================

cmd_list() {
    local filter_op=""
    local filter_stack=""
    local filter_status=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --operation)
                filter_op="$2"
                shift 2
                ;;
            --stack)
                filter_stack="$2"
                shift 2
                ;;
            --status)
                filter_status="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}ERROR: Unknown option '$1'${NC}" >&2
                usage >&2
                exit 1
                ;;
        esac
    done

    local inventory_file
    inventory_file=$(get_inventory_file)

    if [ ! -f "$inventory_file" ]; then
        echo -e "${RED}ERROR: Inventory file not found${NC}" >&2
        exit 1
    fi

    echo -e "${BOLD}${BLUE}Difftest Corpus Rows${NC}"
    if [ -n "$filter_op" ]; then
        echo "  Filtered by operation: $filter_op"
    fi
    if [ -n "$filter_stack" ]; then
        echo "  Filtered by stack: $filter_stack"
    fi
    if [ -n "$filter_status" ]; then
        echo "  Filtered by status: $filter_status"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Apply filters and display
    local filter_cmd="cat"

    if [ -n "$filter_op" ]; then
        filter_cmd="$filter_cmd | grep -i '^| ${filter_op}_'"
    fi

    if [ -n "$filter_stack" ]; then
        filter_cmd="$filter_cmd | grep '| $filter_stack |'"
    fi

    if [ -n "$filter_status" ]; then
        filter_cmd="$filter_cmd | grep '| $filter_status |'"
    fi

    eval "$filter_cmd" < "$inventory_file" | grep "^|" | head -1
    eval "$filter_cmd" < "$inventory_file" | grep "^|" | tail -n +2

    echo ""
}

# ============================================================================
# Command: sync
# ============================================================================

cmd_sync() {
    echo -e "${BLUE}Syncing corpus inventory with Lean mappings...${NC}"
    echo ""

    local inventory_file
    inventory_file=$(get_inventory_file)

    local lean_mapping="$FORMAL_ROOT/lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean"

    if [ ! -f "$lean_mapping" ]; then
        echo -e "${RED}ERROR: Lean mapping file not found${NC}" >&2
        exit 1
    fi

    # Extract mapped IDs from Lean
    local mapped_ids
    mapped_ids=$(grep "| \".*\" =>" "$lean_mapping" | sed 's/.*| "\(.*\)" =>.*/\1/' | sort)

    # Extract Lean-stack IDs from inventory
    local inventory_lean_ids
    inventory_lean_ids=$(grep "| Lean |" "$inventory_file" | awk -F'|' '{print $2}' | tr -d ' ' | sort)

    # Find unmapped
    local unmapped
    unmapped=$(comm -23 <(echo "$inventory_lean_ids") <(echo "$mapped_ids"))

    if [ -n "$unmapped" ]; then
        echo -e "${YELLOW}⚠️  Unmapped Lean corpus rows:${NC}"
        echo "$unmapped" | while read -r id; do
            echo "  - $id"
        done
        echo ""
        echo "Add mappings to: $lean_mapping"
    else
        echo -e "${GREEN}✅ All Lean corpus rows are mapped${NC}"
    fi

    # Find orphaned mappings
    local orphaned
    orphaned=$(comm -13 <(echo "$inventory_lean_ids") <(echo "$mapped_ids"))

    if [ -n "$orphaned" ]; then
        echo ""
        echo -e "${YELLOW}⚠️  Orphaned Lean mappings (no inventory entry):${NC}"
        echo "$orphaned" | while read -r id; do
            echo "  - $id"
        done
        echo ""
        echo "Consider removing from Lean mappings or adding to inventory."
    fi

    echo ""
    echo -e "${GREEN}Sync check complete${NC}"
}

# ============================================================================
# Command: export
# ============================================================================

cmd_export() {
    local format="markdown"
    local output_file=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --format)
                format="$2"
                shift 2
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}ERROR: Unknown option '$1'${NC}" >&2
                usage >&2
                exit 1
                ;;
        esac
    done

    local inventory_file
    inventory_file=$(get_inventory_file)

    case "$format" in
        markdown)
            if [ -n "$output_file" ]; then
                cp "$inventory_file" "$output_file"
                echo -e "${GREEN}Exported to $output_file${NC}"
            else
                cat "$inventory_file"
            fi
            ;;
        json)
            # Convert markdown table to JSON
            echo "{ \"corpus\": [" > "$output_file"
            grep "^|" "$inventory_file" | tail -n +2 | while IFS='|' read -r _ id desc stack status _; do
                id=$(echo "$id" | xargs)
                desc=$(echo "$desc" | xargs)
                stack=$(echo "$stack" | xargs)
                status=$(echo "$status" | xargs)
                echo "  { \"id\": \"$id\", \"description\": \"$desc\", \"stack\": \"$stack\", \"status\": \"$status\" },"
            done | sed '$ s/,$//' >> "$output_file"
            echo "] }" >> "$output_file"
            echo -e "${GREEN}Exported JSON to $output_file${NC}"
            ;;
        *)
            echo -e "${RED}ERROR: Unsupported format '$format'${NC}" >&2
            exit 1
            ;;
    esac
}

# ============================================================================
# Main
# ============================================================================

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

case "$1" in
    add)
        shift
        cmd_add "$@"
        ;;
    validate)
        shift
        cmd_validate "$@"
        ;;
    stats)
        shift
        cmd_stats "$@"
        ;;
    list)
        shift
        cmd_list "$@"
        ;;
    sync)
        shift
        cmd_sync "$@"
        ;;
    export)
        shift
        cmd_export "$@"
        ;;
    --help|-h)
        usage
        ;;
    *)
        echo -e "${RED}ERROR: Unknown command '$1'${NC}" >&2
        echo ""
        usage >&2
        exit 1
        ;;
esac

exit 0

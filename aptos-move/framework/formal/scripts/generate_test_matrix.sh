#!/usr/bin/env bash
# scripts/generate_test_matrix.sh — Test matrix generation for systematic CA coverage
#
# Purpose: Generate comprehensive test matrices ensuring systematic coverage of:
#   - All operations × error conditions
#   - Edge cases and boundary conditions
#   - Composable test scenarios
#
# Usage:
#   ./scripts/generate_test_matrix.sh                    # Generate full matrix
#   ./scripts/generate_test_matrix.sh --operation transfer  # Single operation
#   ./scripts/generate_test_matrix.sh --format markdown  # Output format
#   ./scripts/generate_test_matrix.sh --gaps-only        # Show coverage gaps only

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
OPERATION="all"
FORMAT="markdown"
GAPS_ONLY=false
OUTPUT_FILE=""

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Generate comprehensive test matrix for CA formal verification.

Options:
  --operation <op>    Generate matrix for specific operation (register, withdraw, transfer, normalize, rotate, all)
  --format <fmt>      Output format (markdown, csv, json, html)
  --gaps-only         Show only coverage gaps (missing test cases)
  --output <file>     Write to file instead of stdout
  --help              Show this help

Output Formats:
  markdown (default)  - Markdown table with coverage indicators
  csv                 - CSV for import to spreadsheet
  json                - JSON for programmatic analysis
  html                - HTML table with color coding

Examples:
  $0                                  # Full matrix, markdown
  $0 --operation transfer             # Transfer matrix only
  $0 --gaps-only                      # Show gaps across all operations
  $0 --format html --output matrix.html  # HTML output to file
  $0 --operation register --format csv   # Register CSV matrix
EOF
}

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --operation)
            OPERATION="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --gaps-only)
            GAPS_ONLY=true
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
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
# Test Matrix Definitions
# ============================================================================

# Error codes for CA operations
declare -A ERROR_CODES=(
    [INVALID_PROOF]=65537
    [FROZEN_ACCOUNT]=196617
    [ALLOW_LIST_VIOLATION]=196618
    [INSUFFICIENT_BALANCE]=196619
    [INVALID_CIPHERTEXT]=196620
    [INVALID_PUBLIC_KEY]=196621
    [DUPLICATE_REGISTRATION]=196622
)

# Test dimensions per operation
declare -A REGISTER_DIMENSIONS=(
    [happy_path]="New account, valid proof, valid public key"
    [duplicate_registration]="Account already registered"
    [invalid_proof]="Sigma protocol verification fails"
    [invalid_public_key]="Malformed Ristretto point"
    [zero_balance]="Register with zero initial balance"
    [max_balance]="Register with maximum balance"
)

declare -A WITHDRAW_DIMENSIONS=(
    [happy_path]="Valid withdrawal, sufficient balance, valid proof"
    [frozen_sender]="Sender account frozen"
    [insufficient_balance]="Withdrawal amount > current balance"
    [invalid_proof]="Sigma protocol verification fails"
    [negative_amount]="Range proof verification fails"
    [zero_withdrawal]="Withdraw zero amount"
    [full_balance]="Withdraw entire balance"
    [allow_list_violation]="Recipient not on allow list (if enabled)"
)

declare -A TRANSFER_DIMENSIONS=(
    [happy_path]="Valid transfer, sufficient balance, valid proofs"
    [frozen_sender]="Sender account frozen"
    [frozen_recipient]="Recipient account frozen"
    [insufficient_balance]="Transfer amount > sender balance"
    [invalid_sigma_proof]="Transfer sigma proof fails"
    [invalid_new_balance_proof]="New balance range proof fails"
    [invalid_transfer_amount_proof]="Transfer amount range proof fails"
    [zero_transfer]="Transfer zero amount"
    [self_transfer]="Sender == recipient"
    [multiple_auditors]="Transfer with multiple auditor ciphertexts"
    [no_auditors]="Transfer with empty auditor list"
    [allow_list_sender]="Sender not on allow list (if enabled)"
    [allow_list_recipient]="Recipient not on allow list (if enabled)"
)

declare -A NORMALIZE_DIMENSIONS=(
    [happy_path]="Valid normalization, valid proof"
    [frozen_account]="Account frozen"
    [invalid_proof]="Normalization proof verification fails"
    [empty_pending]="No pending balance to normalize"
    [max_pending]="Normalize maximum pending balance"
)

declare -A ROTATE_DIMENSIONS=(
    [happy_path]="Valid key rotation, valid proof"
    [frozen_account]="Account frozen"
    [invalid_proof]="Rotation proof verification fails"
    [same_key]="New key == old key"
    [invalid_new_key]="Malformed new public key"
)

# ============================================================================
# Coverage checking
# ============================================================================

check_coverage() {
    local operation="$1"
    local dimension="$2"
    local corpus_id="${operation}_${dimension}"

    # Check if test case exists in inventory
    if [ -f difftest/inventory/confidential_assets.md ]; then
        if grep -q "^| $corpus_id " difftest/inventory/confidential_assets.md; then
            echo "✅"
            return 0
        fi
    fi

    # Check if test case exists in Lean mapping
    if [ -f lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean ]; then
        if grep -q "\"$corpus_id\"" lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean; then
            echo "⚠️"  # Mapped but not in inventory
            return 1
        fi
    fi

    # Check if test case exists in Rust suite
    if [ -f "$REPO_ROOT/move-lean-difftest/src/suites/confidential_asset.rs" ]; then
        if grep -q "\"$corpus_id\"" "$REPO_ROOT/move-lean-difftest/src/suites/confidential_asset.rs"; then
            echo "⚠️"  # In Rust but not mapped
            return 1
        fi
    fi

    echo "❌"
    return 2
}

get_coverage_count() {
    local operation="$1"
    local total=0
    local covered=0

    local dimension_var="${operation^^}_DIMENSIONS[@]"
    if [ -z "${!dimension_var+x}" ]; then
        echo "0/0"
        return
    fi

    for dimension in "${!dimension_var}"; do
        total=$((total + 1))
        if check_coverage "$operation" "$dimension" | grep -q "✅"; then
            covered=$((covered + 1))
        fi
    done

    echo "$covered/$total"
}

# ============================================================================
# Matrix generation: Markdown
# ============================================================================

generate_markdown() {
    local operation="$1"

    echo "# Test Matrix: $operation"
    echo ""
    echo "**Generated:** $(date +%Y-%m-%d)"
    echo ""
    echo "| Test Case | Description | Coverage | Error Code | Priority |"
    echo "|-----------|-------------|----------|------------|----------|"

    local dimension_var="${operation^^}_DIMENSIONS[@]"
    if [ -z "${!dimension_var+x}" ]; then
        echo "| (no dimensions defined) | | | | |"
        return
    fi

    # Iterate through dimensions
    local -n dimensions="${operation^^}_DIMENSIONS"
    for dimension in "${!dimensions[@]}"; do
        local description="${dimensions[$dimension]}"
        local coverage
        coverage=$(check_coverage "$operation" "$dimension")
        local corpus_id="${operation}_${dimension}"

        # Determine error code
        local error_code="-"
        if [[ "$dimension" == *"invalid_proof"* ]] || [[ "$dimension" == *"sigma"* ]]; then
            error_code="${ERROR_CODES[INVALID_PROOF]}"
        elif [[ "$dimension" == *"frozen"* ]]; then
            error_code="${ERROR_CODES[FROZEN_ACCOUNT]}"
        elif [[ "$dimension" == *"allow_list"* ]]; then
            error_code="${ERROR_CODES[ALLOW_LIST_VIOLATION]}"
        elif [[ "$dimension" == *"insufficient"* ]]; then
            error_code="${ERROR_CODES[INSUFFICIENT_BALANCE]}"
        fi

        # Determine priority
        local priority="Medium"
        if [[ "$dimension" == "happy_path" ]]; then
            priority="Critical"
        elif [[ "$dimension" == *"invalid_proof"* ]]; then
            priority="High"
        elif [[ "$dimension" == *"frozen"* ]]; then
            priority="High"
        elif [[ "$dimension" == *"zero"* ]] || [[ "$dimension" == *"max"* ]]; then
            priority="Medium"
        else
            priority="Low"
        fi

        # Skip if gaps-only and covered
        if [ "$GAPS_ONLY" = true ] && [ "$coverage" = "✅" ]; then
            continue
        fi

        echo "| $corpus_id | $description | $coverage | $error_code | $priority |"
    done

    echo ""
    echo "**Legend:**"
    echo "- ✅ Covered (exists in corpus)"
    echo "- ⚠️  Partially covered (exists in Rust/Lean but not inventory)"
    echo "- ❌ Not covered (missing test case)"
    echo ""

    local coverage_stats
    coverage_stats=$(get_coverage_count "$operation")
    echo "**Coverage:** $coverage_stats"
    echo ""
}

# ============================================================================
# Matrix generation: CSV
# ============================================================================

generate_csv() {
    local operation="$1"

    echo "Test Case,Description,Coverage,Error Code,Priority"

    local dimension_var="${operation^^}_DIMENSIONS[@]"
    if [ -z "${!dimension_var+x}" ]; then
        return
    fi

    local -n dimensions="${operation^^}_DIMENSIONS"
    for dimension in "${!dimensions[@]}"; do
        local description="${dimensions[$dimension]}"
        local coverage
        coverage=$(check_coverage "$operation" "$dimension")
        local corpus_id="${operation}_${dimension}"

        # Determine error code
        local error_code=""
        if [[ "$dimension" == *"invalid_proof"* ]]; then
            error_code="${ERROR_CODES[INVALID_PROOF]}"
        elif [[ "$dimension" == *"frozen"* ]]; then
            error_code="${ERROR_CODES[FROZEN_ACCOUNT]}"
        fi

        # Determine priority
        local priority="Medium"
        if [[ "$dimension" == "happy_path" ]]; then
            priority="Critical"
        elif [[ "$dimension" == *"invalid_proof"* ]] || [[ "$dimension" == *"frozen"* ]]; then
            priority="High"
        fi

        # Skip if gaps-only and covered
        if [ "$GAPS_ONLY" = true ] && [ "$coverage" = "✅" ]; then
            continue
        fi

        echo "\"$corpus_id\",\"$description\",\"$coverage\",\"$error_code\",\"$priority\""
    done
}

# ============================================================================
# Matrix generation: JSON
# ============================================================================

generate_json() {
    local operation="$1"

    echo "{"
    echo "  \"operation\": \"$operation\","
    echo "  \"generated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"test_cases\": ["

    local dimension_var="${operation^^}_DIMENSIONS[@]"
    if [ -z "${!dimension_var+x}" ]; then
        echo "  ]"
        echo "}"
        return
    fi

    local -n dimensions="${operation^^}_DIMENSIONS"
    local first=true
    for dimension in "${!dimensions[@]}"; do
        local description="${dimensions[$dimension]}"
        local coverage
        coverage=$(check_coverage "$operation" "$dimension")
        local corpus_id="${operation}_${dimension}"

        # Skip if gaps-only and covered
        if [ "$GAPS_ONLY" = true ] && [ "$coverage" = "✅" ]; then
            continue
        fi

        if [ "$first" = false ]; then
            echo ","
        fi
        first=false

        local status="missing"
        if [ "$coverage" = "✅" ]; then
            status="covered"
        elif [ "$coverage" = "⚠️" ]; then
            status="partial"
        fi

        echo "    {"
        echo "      \"id\": \"$corpus_id\","
        echo "      \"description\": \"$description\","
        echo "      \"status\": \"$status\","
        echo "      \"priority\": \"high\""
        echo -n "    }"
    done

    echo ""
    echo "  ]"
    echo "}"
}

# ============================================================================
# Matrix generation: HTML
# ============================================================================

generate_html() {
    local operation="$1"

    cat <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Test Matrix: $operation</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .covered { background-color: #d4edda; }
        .partial { background-color: #fff3cd; }
        .missing { background-color: #f8d7da; }
        .priority-critical { font-weight: bold; color: #d9534f; }
        .priority-high { color: #f0ad4e; }
        .priority-medium { color: #5bc0de; }
        .priority-low { color: #999; }
    </style>
</head>
<body>
    <h1>Test Matrix: $operation</h1>
    <p><strong>Generated:</strong> $(date +%Y-%m-%d)</p>
    <table>
        <thead>
            <tr>
                <th>Test Case</th>
                <th>Description</th>
                <th>Coverage</th>
                <th>Error Code</th>
                <th>Priority</th>
            </tr>
        </thead>
        <tbody>
EOF

    local dimension_var="${operation^^}_DIMENSIONS[@]"
    if [ -z "${!dimension_var+x}" ]; then
        echo "            <tr><td colspan=\"5\">(no dimensions defined)</td></tr>"
    else
        local -n dimensions="${operation^^}_DIMENSIONS"
        for dimension in "${!dimensions[@]}"; do
            local description="${dimensions[$dimension]}"
            local coverage
            coverage=$(check_coverage "$operation" "$dimension")
            local corpus_id="${operation}_${dimension}"

            # Skip if gaps-only and covered
            if [ "$GAPS_ONLY" = true ] && [ "$coverage" = "✅" ]; then
                continue
            fi

            local row_class="missing"
            if [ "$coverage" = "✅" ]; then
                row_class="covered"
            elif [ "$coverage" = "⚠️" ]; then
                row_class="partial"
            fi

            local error_code="-"
            if [[ "$dimension" == *"invalid_proof"* ]]; then
                error_code="${ERROR_CODES[INVALID_PROOF]}"
            elif [[ "$dimension" == *"frozen"* ]]; then
                error_code="${ERROR_CODES[FROZEN_ACCOUNT]}"
            fi

            local priority="medium"
            local priority_class="priority-medium"
            if [[ "$dimension" == "happy_path" ]]; then
                priority="Critical"
                priority_class="priority-critical"
            elif [[ "$dimension" == *"invalid_proof"* ]] || [[ "$dimension" == *"frozen"* ]]; then
                priority="High"
                priority_class="priority-high"
            fi

            echo "            <tr class=\"$row_class\">"
            echo "                <td>$corpus_id</td>"
            echo "                <td>$description</td>"
            echo "                <td>$coverage</td>"
            echo "                <td>$error_code</td>"
            echo "                <td class=\"$priority_class\">$priority</td>"
            echo "            </tr>"
        done
    fi

    cat <<EOF
        </tbody>
    </table>
    <h2>Legend</h2>
    <ul>
        <li class="covered">✅ Covered (exists in corpus)</li>
        <li class="partial">⚠️ Partially covered (exists in Rust/Lean but not inventory)</li>
        <li class="missing">❌ Not covered (missing test case)</li>
    </ul>
    <p><strong>Coverage:</strong> $(get_coverage_count "$operation")</p>
</body>
</html>
EOF
}

# ============================================================================
# Summary matrix (all operations)
# ============================================================================

generate_summary_markdown() {
    echo "# CA Formal Verification: Test Coverage Summary"
    echo ""
    echo "**Generated:** $(date +%Y-%m-%d)"
    echo ""
    echo "| Operation | Total Cases | Covered | Coverage % | Gaps |"
    echo "|-----------|-------------|---------|------------|------|"

    for op in register withdraw transfer normalize rotate; do
        local coverage_stats
        coverage_stats=$(get_coverage_count "$op")

        local covered
        local total
        covered=$(echo "$coverage_stats" | cut -d'/' -f1)
        total=$(echo "$coverage_stats" | cut -d'/' -f2)

        local percentage=0
        if [ "$total" -gt 0 ]; then
            percentage=$((covered * 100 / total))
        fi

        local gaps=$((total - covered))

        echo "| $op | $total | $covered | ${percentage}% | $gaps |"
    done

    echo ""
    echo "## Coverage Gaps by Priority"
    echo ""

    for op in register withdraw transfer normalize rotate; do
        echo "### $op"
        echo ""
        generate_markdown "$op" | grep "❌" | grep -E "(Critical|High)" || echo "  (No high-priority gaps)"
        echo ""
    done
}

# ============================================================================
# Main execution
# ============================================================================

OUTPUT=""

if [ "$OPERATION" = "all" ]; then
    if [ "$FORMAT" = "markdown" ]; then
        OUTPUT=$(generate_summary_markdown)
    else
        echo -e "${YELLOW}Multi-operation summary only supports markdown format${NC}" >&2
        exit 1
    fi
else
    case "$FORMAT" in
        markdown)
            OUTPUT=$(generate_markdown "$OPERATION")
            ;;
        csv)
            OUTPUT=$(generate_csv "$OPERATION")
            ;;
        json)
            OUTPUT=$(generate_json "$OPERATION")
            ;;
        html)
            OUTPUT=$(generate_html "$OPERATION")
            ;;
        *)
            echo -e "${RED}ERROR: Unknown format '$FORMAT'${NC}" >&2
            usage >&2
            exit 1
            ;;
    esac
fi

# Output
if [ -n "$OUTPUT_FILE" ]; then
    echo "$OUTPUT" > "$OUTPUT_FILE"
    echo -e "${GREEN}✅ Matrix written to $OUTPUT_FILE${NC}"
else
    echo "$OUTPUT"
fi

exit 0

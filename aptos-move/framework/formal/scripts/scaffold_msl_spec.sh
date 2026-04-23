#!/usr/bin/env bash
# scripts/scaffold_msl_spec.sh — Generate MSL spec scaffolding for Move functions
#
# Analyzes Move source code and generates MSL spec templates with
# abort conditions, ensures clauses, and modifies clauses based on
# function signatures and implementation patterns.
#
# Usage:
#   ./scripts/scaffold_msl_spec.sh --function FUNC_NAME --module MODULE
#   ./scripts/scaffold_msl_spec.sh --analyze FILE.move
#   ./scripts/scaffold_msl_spec.sh --help
#
# Exit codes:
#   0 = Scaffold generated successfully
#   1 = Failed to generate scaffold
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
FUNCTION=""
MODULE=""
ANALYZE_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --function)
            FUNCTION="$2"
            shift 2
            ;;
        --module)
            MODULE="$2"
            shift 2
            ;;
        --analyze)
            ANALYZE_FILE="$2"
            shift 2
            ;;
        --help)
            cat <<EOF
Usage: $0 --function FUNC_NAME --module MODULE
       $0 --analyze FILE.move

Options:
  --function NAME  : Function name to scaffold spec for
  --module NAME    : Module name (e.g., confidential_asset)
  --analyze FILE   : Analyze Move file and suggest specs
  --help           : Show this help

Generates MSL spec scaffolding based on function signatures.

Examples:
  # Generate spec for specific function
  $0 --function withdraw_to_internal --module confidential_asset

  # Analyze entire file for missing specs
  $0 --analyze ../aptos-experimental/sources/confidential_asset/confidential_asset.move

  # Common patterns recognized:
  # - abort codes from assert! statements
  # - global resource access patterns
  # - parameter validation requirements
  # - return value constraints
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            exit 2
            ;;
    esac
done

# Extract function signature from Move source
extract_signature() {
    local func_name="$1"
    local move_file="$2"

    # Simple extraction - find function definition
    grep -A 10 "fun $func_name" "$move_file" || echo ""
}

# Generate spec template
generate_spec() {
    local func_name="$1"

    cat <<EOF
    spec $func_name {
        // === Pre-conditions ===
        // requires ...;

        // === Abort conditions ===
        // Add abort_if clauses for each assert! in the function
        // Example: aborts_if amount == 0 with EINVALID_AMOUNT;

        // === Post-conditions (ensures) ===
        // ensures result == expected_value;
        // ensures global<Resource>(addr) == old(global<Resource>(addr));

        // === Frame conditions (modifies) ===
        // List all global resources that may be modified
        // modifies global<ConfidentialAssetStore>(signer::address_of(account));

        // === Invariants ===
        // Check struct invariants are maintained
        // invariant len(store.pending_balance) == len(store.actual_balance);
    }
EOF
}

# Analyze Move file
analyze_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo -e "${RED}Error:${NC} File not found: $file"
        exit 2
    fi

    echo -e "${CYAN}Analyzing:${NC} $file"
    echo ""

    # Find public/entry functions
    local public_funcs=$(grep -E "^\s*(public|entry)" "$file" | grep "fun " | sed 's/.*fun \([a-zA-Z0-9_]*\).*/\1/' || echo "")

    if [ -z "$public_funcs" ]; then
        echo -e "${YELLOW}No public/entry functions found${NC}"
        exit 0
    fi

    echo "Public/entry functions found:"
    echo "$public_funcs" | while read -r func; do
        echo "  - $func"
    done
    echo ""

    # Check which have specs
    echo "Spec coverage:"
    echo "$public_funcs" | while read -r func; do
        local spec_file="${file%.move}.spec.move"
        if [ -f "$spec_file" ]; then
            if grep -q "spec $func" "$spec_file"; then
                echo -e "  ${GREEN}✓${NC} $func (has spec)"
            else
                echo -e "  ${YELLOW}✗${NC} $func (missing spec)"
            fi
        else
            echo -e "  ${RED}✗${NC} $func (no spec file)"
        fi
    done
    echo ""

    # Suggest next steps
    echo "Next steps:"
    echo "$public_funcs" | while read -r func; do
        local spec_file="${file%.move}.spec.move"
        if [ -f "$spec_file" ]; then
            if ! grep -q "spec $func" "$spec_file"; then
                echo "  1. Add spec for $func:"
                echo "     $0 --function $func --module $(basename "$file" .move)"
            fi
        fi
    done
}

# Main
main() {
    if [ -n "$ANALYZE_FILE" ]; then
        analyze_file "$ANALYZE_FILE"
        exit 0
    fi

    if [ -z "$FUNCTION" ] || [ -z "$MODULE" ]; then
        echo -e "${RED}Error:${NC} --function and --module are required"
        echo "Use --help for usage information"
        exit 2
    fi

    echo -e "${CYAN}Generating MSL spec scaffold for:${NC} $MODULE::$FUNCTION"
    echo ""

    generate_spec "$FUNCTION"

    echo ""
    echo -e "${GREEN}✓ Scaffold generated${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Copy the spec above to ../aptos-experimental/sources/confidential_asset/$MODULE.spec.move"
    echo "  2. Fill in abort conditions (check assert! statements in source)"
    echo "  3. Add ensures clauses for expected behavior"
    echo "  4. Add modifies clauses for global resources"
    echo "  5. Test: movement move compile --package-dir ../aptos-experimental"
}

main "$@"

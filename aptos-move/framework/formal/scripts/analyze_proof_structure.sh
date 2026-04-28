#!/usr/bin/env bash
set -euo pipefail

#
# analyze_proof_structure.sh
#
# Purpose: Analyze the structure and complexity of Lean proofs in the CA verification codebase.
# Provides metrics on proof size, tactic usage, theorem dependencies, and identifies optimization opportunities.
#
# Usage:
#   ./analyze_proof_structure.sh [OPTIONS]
#
# Options:
#   --file <path>        Analyze a specific Lean file
#   --operation <name>   Analyze all files for a specific operation (normalization, withdrawal, etc.)
#   --all                Analyze all CA Lean files
#   --format <type>      Output format: text (default), json, markdown
#   --verbose            Show detailed analysis per theorem
#
# Examples:
#   ./analyze_proof_structure.sh --file lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean
#   ./analyze_proof_structure.sh --operation transfer --format json
#   ./analyze_proof_structure.sh --all --format markdown > proof_analysis_report.md
#

# Configuration
LEAN_ROOT="lean/MovementFormal/Experimental/ConfidentialAsset"
FORMAT="text"
VERBOSE=false
TARGET=""
MODE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      MODE="file"
      TARGET="$2"
      shift 2
      ;;
    --operation)
      MODE="operation"
      TARGET="$2"
      shift 2
      ;;
    --all)
      MODE="all"
      shift
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      head -n 20 "$0" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage"
      exit 1
      ;;
  esac
done

# Validate arguments
if [[ -z "$MODE" ]]; then
  echo "Error: Must specify --file, --operation, or --all"
  echo "Run with --help for usage"
  exit 1
fi

# Helper: Analyze a single Lean file
analyze_file() {
  local file=$1

  if [[ ! -f "$file" ]]; then
    echo "Error: File not found: $file" >&2
    return 1
  fi

  # Count theorems
  local num_theorems=$(grep -c "^theorem " "$file" || true)

  # Count axioms
  local num_axioms=$(grep -c "^axiom " "$file" || true)

  # Count sorry
  local num_sorry=$(grep -c "sorry" "$file" || true)

  # Count lines of code (excluding comments and blank lines)
  local loc=$(grep -v "^--" "$file" | grep -v "^/-" | grep -v "^$" | wc -l | tr -d ' ')

  # Count tactic usage
  local num_rw=$(grep -o "\brw\b" "$file" | wc -l | tr -d ' ')
  local num_simp=$(grep -o "\bsimp\b" "$file" | wc -l | tr -d ' ')
  local num_simp_only=$(grep -o "simp only" "$file" | wc -l | tr -d ' ')
  local num_cases=$(grep -o "\bcases\b" "$file" | wc -l | tr -d ' ')
  local num_rfl=$(grep -o "\brfl\b" "$file" | wc -l | tr -d ' ')
  local num_exact=$(grep -o "\bexact\b" "$file" | wc -l | tr -d ' ')
  local num_unfold=$(grep -o "\bunfold\b" "$file" | wc -l | tr -d ' ')
  local num_have=$(grep -o "\bhave\b" "$file" | wc -l | tr -d ' ')

  # Count irreducible definitions
  local num_irreducible=$(grep -c "@\[irreducible\]" "$file" || true)

  # Count simp lemmas
  local num_simp_lemmas=$(grep -c "@\[simp\]" "$file" || true)

  # Estimate proof complexity (average lines per theorem)
  local avg_lines_per_theorem=0
  if [[ $num_theorems -gt 0 ]]; then
    avg_lines_per_theorem=$((loc / num_theorems))
  fi

  # Check for bare simp (performance anti-pattern)
  local num_bare_simp=$(grep -E "\bsimp\b\s*$" "$file" | wc -l | tr -d ' ')

  # Output results
  case $FORMAT in
    json)
      cat <<EOF
{
  "file": "$file",
  "metrics": {
    "theorems": $num_theorems,
    "axioms": $num_axioms,
    "sorry": $num_sorry,
    "lines_of_code": $loc,
    "avg_lines_per_theorem": $avg_lines_per_theorem,
    "irreducible_defs": $num_irreducible,
    "simp_lemmas": $num_simp_lemmas
  },
  "tactics": {
    "rw": $num_rw,
    "simp": $num_simp,
    "simp_only": $num_simp_only,
    "cases": $num_cases,
    "rfl": $num_rfl,
    "exact": $num_exact,
    "unfold": $num_unfold,
    "have": $num_have
  },
  "performance": {
    "bare_simp_count": $num_bare_simp,
    "warnings": $(if [[ $num_bare_simp -gt 0 ]]; then echo "true"; else echo "false"; fi)
  }
}
EOF
      ;;

    markdown)
      cat <<EOF
## $(basename "$file")

**Path:** \`$file\`

### Metrics
- **Theorems:** $num_theorems
- **Axioms:** $num_axioms
- **Sorry:** $num_sorry
- **Lines of code:** $loc
- **Avg lines per theorem:** $avg_lines_per_theorem
- **Irreducible definitions:** $num_irreducible
- **Simp lemmas:** $num_simp_lemmas

### Tactic Usage
- \`rw\`: $num_rw
- \`simp\`: $num_simp (bare: $num_bare_simp ⚠️)
- \`simp only\`: $num_simp_only
- \`cases\`: $num_cases
- \`rfl\`: $num_rfl
- \`exact\`: $num_exact
- \`unfold\`: $num_unfold
- \`have\`: $num_have

$(if [[ $num_bare_simp -gt 0 ]]; then
  echo "### ⚠️ Performance Warnings"
  echo "- Found $num_bare_simp bare \`simp\` calls (should use \`simp only\`)"
fi)

EOF
      ;;

    text|*)
      echo "=== Proof Structure Analysis: $(basename "$file") ==="
      echo ""
      echo "Metrics:"
      echo "  Theorems:                  $num_theorems"
      echo "  Axioms:                    $num_axioms"
      echo "  Sorry:                     $num_sorry"
      echo "  Lines of code:             $loc"
      echo "  Avg lines per theorem:     $avg_lines_per_theorem"
      echo "  Irreducible definitions:   $num_irreducible"
      echo "  Simp lemmas:               $num_simp_lemmas"
      echo ""
      echo "Tactic usage:"
      echo "  rw:                        $num_rw"
      echo "  simp (total):              $num_simp"
      echo "  simp only:                 $num_simp_only"
      echo "  simp (bare):               $num_bare_simp"
      echo "  cases:                     $num_cases"
      echo "  rfl:                       $num_rfl"
      echo "  exact:                     $num_exact"
      echo "  unfold:                    $num_unfold"
      echo "  have:                      $num_have"
      echo ""

      if [[ $num_bare_simp -gt 0 ]]; then
        echo "⚠️  Performance warnings:"
        echo "  - Found $num_bare_simp bare 'simp' calls (should use 'simp only')"
        echo ""
      fi

      if [[ $num_sorry -gt 0 ]]; then
        echo "⚠️  Incomplete proofs:"
        echo "  - Found $num_sorry 'sorry' placeholders"
        echo ""
      fi

      if [[ $num_axioms -gt 0 ]]; then
        echo "ℹ️  Axioms declared:"
        echo "  - $num_axioms axioms (review AXIOM_INVENTORY.md)"
        echo ""
      fi
      ;;
  esac

  # Verbose mode: list individual theorems
  if [[ "$VERBOSE" == "true" ]]; then
    echo "Theorems in this file:"
    grep "^theorem " "$file" | sed 's/theorem /  - /' | sed 's/ :.*$//'
    echo ""
  fi
}

# Main logic
case $MODE in
  file)
    analyze_file "$TARGET"
    ;;

  operation)
    # Find all Lean files for the operation
    operation_dir="$LEAN_ROOT/$(echo "$TARGET" | sed 's/^./\U&/')"  # Capitalize first letter

    if [[ ! -d "$operation_dir" ]]; then
      echo "Error: Operation directory not found: $operation_dir" >&2
      exit 1
    fi

    if [[ "$FORMAT" == "markdown" ]]; then
      echo "# Proof Structure Analysis: $TARGET"
      echo ""
      echo "**Generated:** $(date)"
      echo ""
    fi

    find "$operation_dir" -name "*.lean" -type f | sort | while read -r file; do
      analyze_file "$file"
    done
    ;;

  all)
    if [[ "$FORMAT" == "markdown" ]]; then
      echo "# Confidential Assets Proof Structure Analysis"
      echo ""
      echo "**Generated:** $(date)"
      echo ""
    fi

    for operation in Registration Normalization Withdrawal Transfer Rotation; do
      operation_dir="$LEAN_ROOT/$operation"

      if [[ -d "$operation_dir" ]]; then
        if [[ "$FORMAT" == "markdown" ]]; then
          echo "---"
          echo ""
          echo "# $operation"
          echo ""
        else
          echo ""
          echo "========================================="
          echo "Operation: $operation"
          echo "========================================="
          echo ""
        fi

        find "$operation_dir" -name "*.lean" -type f | sort | while read -r file; do
          analyze_file "$file"
        done
      fi
    done

    # Summary
    if [[ "$FORMAT" == "markdown" ]]; then
      echo "---"
      echo ""
      echo "## Summary"
      echo ""
      echo "Run \`./analyze_proof_structure.sh --all --format text\` for a detailed summary."
    fi
    ;;
esac

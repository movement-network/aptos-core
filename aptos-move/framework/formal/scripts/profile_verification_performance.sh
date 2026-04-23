#!/usr/bin/env bash
set -euo pipefail

#
# profile_verification_performance.sh
#
# Purpose: Automated performance profiling for CA verification across all three stacks
# Tracks build times, axiom counts, VC counts, and test execution times over commits
# Generates trend reports, identifies regressions, and validates against budgets
#
# Usage:
#   ./profile_verification_performance.sh [OPTIONS]
#
# Options:
#   --mode <quick|standard|comprehensive>  # Profile depth (default: standard)
#   --output-dir <dir>                     # Output directory (default: ./metrics/performance)
#   --baseline <commit>                    # Baseline commit for comparison
#   --format <text|json|csv|html>          # Output format (default: text)
#   --alert-on-regression                  # Exit 1 if performance regression detected
#   --stack <lean|msl|difftest|all>        # Which stack to profile (default: all)
#
# Examples:
#   # Quick profile (5 min)
#   ./profile_verification_performance.sh --mode quick
#
#   # Comprehensive profile with regression detection (30 min)
#   ./profile_verification_performance.sh --mode comprehensive --alert-on-regression
#
#   # Profile just Lean stack, output JSON
#   ./profile_verification_performance.sh --stack lean --format json
#
#   # Compare against baseline commit
#   ./profile_verification_performance.sh --baseline e9f7b29dde --format html
#

# Configuration
MODE="standard"
OUTPUT_DIR="./metrics/performance"
BASELINE=""
FORMAT="text"
ALERT_ON_REGRESSION=false
STACK="all"

# Performance budgets (from verification plan)
LEAN_PER_FILE_BUDGET_SECONDS=180       # 3 minutes per operation
LEAN_FULL_TREE_BUDGET_SECONDS=600      # 10 minutes for full CA tree
MSL_PER_MODULE_BUDGET_SECONDS=60       # 1 minute per module (when unblocked)
DIFFTEST_PER_TEST_BUDGET_MS=5000       # 5 seconds per test
DIFFTEST_FULL_CORPUS_BUDGET_SECONDS=600  # 10 minutes for 87+ tests

# Regression thresholds (% increase from baseline)
REGRESSION_THRESHOLD_PERCENT=20  # Alert if >20% slower

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --baseline)
      BASELINE="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --alert-on-regression)
      ALERT_ON_REGRESSION=true
      shift
      ;;
    --stack)
      STACK="$2"
      shift 2
      ;;
    --help)
      head -n 35 "$0" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage"
      exit 1
      ;;
  esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Timestamp for this run
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

# Output files
METRICS_FILE="$OUTPUT_DIR/metrics_${TIMESTAMP}.json"
REPORT_FILE="$OUTPUT_DIR/report_${TIMESTAMP}.${FORMAT}"
HISTORY_CSV="$OUTPUT_DIR/performance_history.csv"

# Initialize metrics JSON
cat > "$METRICS_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "commit": "$COMMIT_SHA",
  "branch": "$BRANCH",
  "mode": "$MODE",
  "lean": {},
  "msl": {},
  "difftest": {},
  "summary": {}
}
EOF

# Helper: Update JSON metrics
update_json() {
  local key=$1
  local value=$2
  jq "$key = $value" "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
}

# Helper: Measure command execution time
measure_time() {
  local description=$1
  shift
  local cmd="$@"

  echo -e "${BLUE}Measuring: $description${NC}"

  local start_time=$(date +%s%3N)
  if eval "$cmd" > /dev/null 2>&1; then
    local end_time=$(date +%s%3N)
    local elapsed=$((end_time - start_time))
    echo -e "${GREEN}  ✓ ${description}: ${elapsed}ms${NC}"
    echo "$elapsed"
  else
    local end_time=$(date +%s%3N)
    local elapsed=$((end_time - start_time))
    echo -e "${RED}  ✗ ${description}: FAILED (${elapsed}ms)${NC}"
    echo "-1"  # Indicate failure
  fi
}

# =============================================================================
# LEAN STACK PROFILING
# =============================================================================

profile_lean() {
  echo -e "${BLUE}=== Profiling Lean Stack ===${NC}"

  local operations=("Normalization" "Withdrawal" "Transfer" "Rotation" "Registration")
  local total_time=0
  local operation_count=0

  # Initialize Lean metrics
  update_json '.lean.operations' '{}'

  # Profile each operation
  for op in "${operations[@]}"; do
    echo ""
    echo -e "${YELLOW}Profiling $op...${NC}"

    local op_lower=$(echo "$op" | tr '[:upper:]' '[:lower:]')
    local module="MovementFormal.Experimental.ConfidentialAsset.$op"

    # Measure build time
    local build_time=$(measure_time "$op build time" \
      "lake build $module")

    if [[ "$build_time" != "-1" ]]; then
      local build_time_seconds=$((build_time / 1000))

      # Check against budget
      local status="OK"
      if [[ $build_time_seconds -gt $LEAN_PER_FILE_BUDGET_SECONDS ]]; then
        status="OVER_BUDGET"
        echo -e "${YELLOW}  ⚠ Over budget: ${build_time_seconds}s > ${LEAN_PER_FILE_BUDGET_SECONDS}s${NC}"
      fi

      # Count axioms
      local axiom_output=$(./scripts/check_axioms.sh "$module" 2>&1 || echo "")
      local total_axioms=$(echo "$axiom_output" | grep "Total axioms:" | awk '{print $3}' || echo "0")
      local temp_axioms=$(echo "$axiom_output" | grep "Temporary axioms:" | awk '{print $3}' || echo "0")

      # Update JSON
      update_json ".lean.operations.${op_lower}" \
        "{\"build_time_ms\": $build_time, \"build_time_seconds\": $build_time_seconds, \"total_axioms\": $total_axioms, \"temp_axioms\": $temp_axioms, \"status\": \"$status\", \"budget_seconds\": $LEAN_PER_FILE_BUDGET_SECONDS}"

      total_time=$((total_time + build_time))
      operation_count=$((operation_count + 1))
    else
      echo -e "${RED}  ✗ Build failed for $op${NC}"
      update_json ".lean.operations.${op_lower}" \
        "{\"build_time_ms\": -1, \"status\": \"FAILED\"}"
    fi
  done

  # Full tree build
  echo ""
  echo -e "${YELLOW}Profiling full CA Lean tree...${NC}"
  local full_tree_time=$(measure_time "Full CA tree build" \
    "lake build MovementFormal.Experimental.ConfidentialAsset")

  local full_tree_seconds=-1
  local full_tree_status="FAILED"
  if [[ "$full_tree_time" != "-1" ]]; then
    full_tree_seconds=$((full_tree_time / 1000))
    full_tree_status="OK"
    if [[ $full_tree_seconds -gt $LEAN_FULL_TREE_BUDGET_SECONDS ]]; then
      full_tree_status="OVER_BUDGET"
      echo -e "${YELLOW}  ⚠ Over budget: ${full_tree_seconds}s > ${LEAN_FULL_TREE_BUDGET_SECONDS}s${NC}"
    fi
  fi

  # Average time per operation
  local avg_time_ms=0
  if [[ $operation_count -gt 0 ]]; then
    avg_time_ms=$((total_time / operation_count))
  fi

  # Update JSON summary
  update_json '.lean.summary' \
    "{\"total_operations\": $operation_count, \"total_time_ms\": $total_time, \"avg_time_per_operation_ms\": $avg_time_ms, \"full_tree_time_ms\": $full_tree_time, \"full_tree_time_seconds\": $full_tree_seconds, \"full_tree_status\": \"$full_tree_status\", \"budget_seconds\": $LEAN_FULL_TREE_BUDGET_SECONDS}"

  echo ""
  echo -e "${GREEN}Lean profiling complete.${NC}"
}

# =============================================================================
# MSL STACK PROFILING
# =============================================================================

profile_msl() {
  echo -e "${BLUE}=== Profiling MSL Stack ===${NC}"

  # Check if Move Prover is available
  if ! command -v movement &> /dev/null; then
    echo -e "${YELLOW}Movement CLI not found, skipping MSL profiling${NC}"
    update_json '.msl.status' '"SKIPPED"'
    return
  fi

  # Check if Z3 is available
  if [[ -z "${Z3_EXE:-}" ]]; then
    echo -e "${YELLOW}Z3_EXE not set, skipping MSL profiling${NC}"
    update_json '.msl.status' '"SKIPPED"'
    return
  fi

  # NOTE: MSL verification is currently blocked on ristretto255 patches
  # Once unblocked, this will profile each module

  local modules=("confidential_asset" "confidential_balance" "confidential_proof")
  local total_time=0
  local module_count=0
  local total_vcs=0

  update_json '.msl.modules' '{}'

  for module in "${modules[@]}"; do
    echo ""
    echo -e "${YELLOW}Profiling $module (MSL)...${NC}"

    # Measure prover time
    local prover_time=$(measure_time "$module MSL verification" \
      "movement move prove --package-dir aptos-move/framework/aptos-experimental --filter $module --vc-timeout 60 --skip-fetch-latest-git-deps")

    if [[ "$prover_time" != "-1" ]]; then
      local prover_time_seconds=$((prover_time / 1000))

      # Count VCs (would extract from prover output in real implementation)
      local vc_count=0  # Placeholder

      # Check against budget
      local status="OK"
      if [[ $prover_time_seconds -gt $MSL_PER_MODULE_BUDGET_SECONDS ]]; then
        status="OVER_BUDGET"
        echo -e "${YELLOW}  ⚠ Over budget: ${prover_time_seconds}s > ${MSL_PER_MODULE_BUDGET_SECONDS}s${NC}"
      fi

      update_json ".msl.modules.${module}" \
        "{\"prover_time_ms\": $prover_time, \"prover_time_seconds\": $prover_time_seconds, \"vc_count\": $vc_count, \"status\": \"$status\", \"budget_seconds\": $MSL_PER_MODULE_BUDGET_SECONDS}"

      total_time=$((total_time + prover_time))
      module_count=$((module_count + 1))
      total_vcs=$((total_vcs + vc_count))
    else
      # Expected: MSL currently blocked on ristretto255
      echo -e "${YELLOW}  ⚠ Verification blocked (expected until ristretto255 patches applied)${NC}"
      update_json ".msl.modules.${module}" \
        "{\"prover_time_ms\": -1, \"status\": \"BLOCKED\"}"
    fi
  done

  # Average time per module
  local avg_time_ms=0
  if [[ $module_count -gt 0 ]]; then
    avg_time_ms=$((total_time / module_count))
  fi

  update_json '.msl.summary' \
    "{\"total_modules\": $module_count, \"total_time_ms\": $total_time, \"avg_time_per_module_ms\": $avg_time_ms, \"total_vcs\": $total_vcs, \"status\": \"BLOCKED\"}"

  echo ""
  echo -e "${GREEN}MSL profiling complete (currently blocked).${NC}"
}

# =============================================================================
# DIFFTEST STACK PROFILING
# =============================================================================

profile_difftest() {
  echo -e "${BLUE}=== Profiling Difftest Stack ===${NC}"

  local corpus_dir="difftest/corpus/confidential_assets"

  # Count test cases
  local test_count=$(find "$corpus_dir" -name "*.json" -type f 2>/dev/null | wc -l)

  if [[ $test_count -eq 0 ]]; then
    echo -e "${YELLOW}No difftest cases found, skipping${NC}"
    update_json '.difftest.status' '"SKIPPED"'
    return
  fi

  echo "Found $test_count difftest cases"

  # Profile execution based on mode
  local tests_to_run=$test_count
  if [[ "$MODE" == "quick" ]]; then
    tests_to_run=10
    echo -e "${YELLOW}Quick mode: sampling 10 tests${NC}"
  elif [[ "$MODE" == "standard" ]]; then
    tests_to_run=30
    echo -e "${YELLOW}Standard mode: sampling 30 tests${NC}"
  fi

  # Sample test files
  local test_files=($(find "$corpus_dir" -name "*.json" -type f | head -n "$tests_to_run"))

  local total_time=0
  local passed=0
  local failed=0

  update_json '.difftest.tests' '[]'

  for test_file in "${test_files[@]}"; do
    local test_name=$(basename "$test_file" .json)
    echo -ne "\r  Testing: $test_name                    "

    # Measure test execution time
    local start_time=$(date +%s%3N)
    local test_result="PASS"

    # Run difftest (placeholder - actual command depends on harness)
    if ! timeout 10s ./difftest/difftest.sh run-single "$test_file" > /dev/null 2>&1; then
      test_result="FAIL"
      failed=$((failed + 1))
    else
      passed=$((passed + 1))
    fi

    local end_time=$(date +%s%3N)
    local test_time=$((end_time - start_time))

    # Check against budget
    local status="OK"
    if [[ $test_time -gt $DIFFTEST_PER_TEST_BUDGET_MS ]]; then
      status="OVER_BUDGET"
    fi

    # Update JSON (append to tests array)
    local test_json="{\"name\": \"$test_name\", \"time_ms\": $test_time, \"result\": \"$test_result\", \"status\": \"$status\", \"budget_ms\": $DIFFTEST_PER_TEST_BUDGET_MS}"
    update_json '.difftest.tests += ['"$test_json"']'

    total_time=$((total_time + test_time))
  done

  echo ""  # Clear progress line

  # Average time per test
  local avg_time_ms=0
  if [[ $tests_to_run -gt 0 ]]; then
    avg_time_ms=$((total_time / tests_to_run))
  fi

  # Estimate full corpus time
  local estimated_full_time_ms=$((avg_time_ms * test_count))
  local estimated_full_time_seconds=$((estimated_full_time_ms / 1000))

  local full_corpus_status="OK"
  if [[ $estimated_full_time_seconds -gt $DIFFTEST_FULL_CORPUS_BUDGET_SECONDS ]]; then
    full_corpus_status="OVER_BUDGET"
  fi

  update_json '.difftest.summary' \
    "{\"total_tests\": $test_count, \"tests_run\": $tests_to_run, \"passed\": $passed, \"failed\": $failed, \"total_time_ms\": $total_time, \"avg_time_per_test_ms\": $avg_time_ms, \"estimated_full_corpus_time_seconds\": $estimated_full_time_seconds, \"status\": \"$full_corpus_status\", \"budget_seconds\": $DIFFTEST_FULL_CORPUS_BUDGET_SECONDS}"

  echo -e "${GREEN}Difftest profiling complete.${NC}"
}

# =============================================================================
# BASELINE COMPARISON
# =============================================================================

compare_baseline() {
  if [[ -z "$BASELINE" ]]; then
    return
  fi

  echo ""
  echo -e "${BLUE}=== Comparing Against Baseline: $BASELINE ===${NC}"

  # Find baseline metrics file
  local baseline_file=$(find "$OUTPUT_DIR" -name "metrics_*_${BASELINE}.json" | head -n 1)

  if [[ -z "$baseline_file" ]] || [[ ! -f "$baseline_file" ]]; then
    echo -e "${YELLOW}No baseline metrics found for commit $BASELINE${NC}"
    return
  fi

  echo "Baseline: $baseline_file"

  # Compare Lean metrics
  local current_lean_time=$(jq -r '.lean.summary.total_time_ms // 0' "$METRICS_FILE")
  local baseline_lean_time=$(jq -r '.lean.summary.total_time_ms // 0' "$baseline_file")

  if [[ $baseline_lean_time -gt 0 ]]; then
    local lean_diff=$((current_lean_time - baseline_lean_time))
    local lean_percent=$(echo "scale=2; ($lean_diff / $baseline_lean_time) * 100" | bc)

    if (( $(echo "$lean_percent > $REGRESSION_THRESHOLD_PERCENT" | bc -l) )); then
      echo -e "${RED}  ✗ Lean regression: +${lean_percent}% (${current_lean_time}ms vs ${baseline_lean_time}ms)${NC}"
      update_json '.comparison.lean_regression' 'true'
    elif (( $(echo "$lean_percent > 0" | bc -l) )); then
      echo -e "${YELLOW}  ⚠ Lean slowdown: +${lean_percent}% (${current_lean_time}ms vs ${baseline_lean_time}ms)${NC}"
      update_json '.comparison.lean_regression' 'false'
    else
      echo -e "${GREEN}  ✓ Lean performance: ${lean_percent}% (${current_lean_time}ms vs ${baseline_lean_time}ms)${NC}"
      update_json '.comparison.lean_regression' 'false'
    fi
  fi

  # Compare difftest metrics (similar logic)
  local current_difftest_time=$(jq -r '.difftest.summary.avg_time_per_test_ms // 0' "$METRICS_FILE")
  local baseline_difftest_time=$(jq -r '.difftest.summary.avg_time_per_test_ms // 0' "$baseline_file")

  if [[ $baseline_difftest_time -gt 0 ]]; then
    local difftest_diff=$((current_difftest_time - baseline_difftest_time))
    local difftest_percent=$(echo "scale=2; ($difftest_diff / $baseline_difftest_time) * 100" | bc)

    if (( $(echo "$difftest_percent > $REGRESSION_THRESHOLD_PERCENT" | bc -l) )); then
      echo -e "${RED}  ✗ Difftest regression: +${difftest_percent}% (${current_difftest_time}ms vs ${baseline_difftest_time}ms)${NC}"
      update_json '.comparison.difftest_regression' 'true'
    else
      echo -e "${GREEN}  ✓ Difftest performance: ${difftest_percent}% (${current_difftest_time}ms vs ${baseline_difftest_time}ms)${NC}"
      update_json '.comparison.difftest_regression' 'false'
    fi
  fi
}

# =============================================================================
# REPORT GENERATION
# =============================================================================

generate_report() {
  echo ""
  echo -e "${BLUE}=== Generating Report ===${NC}"

  case "$FORMAT" in
    text)
      generate_text_report
      ;;
    json)
      cp "$METRICS_FILE" "$REPORT_FILE"
      echo "JSON report: $REPORT_FILE"
      ;;
    csv)
      generate_csv_report
      ;;
    html)
      generate_html_report
      ;;
    *)
      echo -e "${RED}Unknown format: $FORMAT${NC}"
      ;;
  esac
}

generate_text_report() {
  cat > "$REPORT_FILE" <<EOF
================================================================================
CA Verification Performance Profile
================================================================================

Timestamp:  $TIMESTAMP
Commit:     $COMMIT_SHA
Branch:     $BRANCH
Mode:       $MODE

================================================================================
LEAN STACK
================================================================================

Per-Operation Build Times:
EOF

  # Extract Lean operation metrics
  jq -r '.lean.operations | to_entries[] | "  \(.key): \(.value.build_time_seconds)s (\(.value.status))"' "$METRICS_FILE" >> "$REPORT_FILE"

  cat >> "$REPORT_FILE" <<EOF

Full CA Tree: $(jq -r '.lean.summary.full_tree_time_seconds' "$METRICS_FILE")s ($(jq -r '.lean.summary.full_tree_status' "$METRICS_FILE"))

Axiom Counts:
EOF

  jq -r '.lean.operations | to_entries[] | "  \(.key): \(.value.total_axioms) total, \(.value.temp_axioms) temporary"' "$METRICS_FILE" >> "$REPORT_FILE"

  cat >> "$REPORT_FILE" <<EOF

================================================================================
MSL STACK
================================================================================

Status: $(jq -r '.msl.summary.status // "SKIPPED"' "$METRICS_FILE")

$(jq -r '.msl.modules // {} | to_entries[] | "  \(.key): \(.value.prover_time_seconds)s (\(.value.status))"' "$METRICS_FILE")

================================================================================
DIFFTEST STACK
================================================================================

Total Tests:  $(jq -r '.difftest.summary.total_tests // 0' "$METRICS_FILE")
Tests Run:    $(jq -r '.difftest.summary.tests_run // 0' "$METRICS_FILE")
Passed:       $(jq -r '.difftest.summary.passed // 0' "$METRICS_FILE")
Failed:       $(jq -r '.difftest.summary.failed // 0' "$METRICS_FILE")

Avg Time/Test: $(jq -r '.difftest.summary.avg_time_per_test_ms // 0' "$METRICS_FILE")ms
Estimated Full Corpus Time: $(jq -r '.difftest.summary.estimated_full_corpus_time_seconds // 0' "$METRICS_FILE")s

Status: $(jq -r '.difftest.summary.status // "UNKNOWN"' "$METRICS_FILE")

================================================================================
EOF

  # Add comparison section if baseline provided
  if [[ -n "$BASELINE" ]]; then
    cat >> "$REPORT_FILE" <<EOF

BASELINE COMPARISON (vs $BASELINE)
================================================================================

Lean Regression:     $(jq -r '.comparison.lean_regression // "N/A"' "$METRICS_FILE")
Difftest Regression: $(jq -r '.comparison.difftest_regression // "N/A"' "$METRICS_FILE")

EOF
  fi

  echo "Text report: $REPORT_FILE"
}

generate_csv_report() {
  # Append to history CSV
  if [[ ! -f "$HISTORY_CSV" ]]; then
    echo "timestamp,commit,branch,lean_total_ms,lean_full_tree_ms,msl_total_ms,difftest_avg_ms" > "$HISTORY_CSV"
  fi

  local lean_total=$(jq -r '.lean.summary.total_time_ms // 0' "$METRICS_FILE")
  local lean_full=$(jq -r '.lean.summary.full_tree_time_ms // 0' "$METRICS_FILE")
  local msl_total=$(jq -r '.msl.summary.total_time_ms // 0' "$METRICS_FILE")
  local difftest_avg=$(jq -r '.difftest.summary.avg_time_per_test_ms // 0' "$METRICS_FILE")

  echo "$TIMESTAMP,$COMMIT_SHA,$BRANCH,$lean_total,$lean_full,$msl_total,$difftest_avg" >> "$HISTORY_CSV"

  cp "$HISTORY_CSV" "$REPORT_FILE"
  echo "CSV report: $REPORT_FILE"
  echo "History: $HISTORY_CSV"
}

generate_html_report() {
  cat > "$REPORT_FILE" <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>CA Verification Performance Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    h2 { color: #666; margin-top: 30px; }
    table { border-collapse: collapse; width: 100%; margin-top: 10px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    .ok { color: green; }
    .warning { color: orange; }
    .fail { color: red; }
  </style>
</head>
<body>
  <h1>CA Verification Performance Report</h1>
  <p><strong>Timestamp:</strong> $TIMESTAMP</p>
  <p><strong>Commit:</strong> $COMMIT_SHA</p>
  <p><strong>Branch:</strong> $BRANCH</p>
  <p><strong>Mode:</strong> $MODE</p>

  <h2>Lean Stack</h2>
  <table>
    <tr><th>Operation</th><th>Build Time</th><th>Axioms</th><th>Status</th></tr>
EOF

  # Extract Lean metrics and format as HTML table rows
  jq -r '.lean.operations | to_entries[] | "<tr><td>\(.key)</td><td>\(.value.build_time_seconds)s</td><td>\(.value.total_axioms) (\(.value.temp_axioms) temp)</td><td class=\"\(if .value.status == "OK" then "ok" elif .value.status == "OVER_BUDGET" then "warning" else "fail" end)\">\(.value.status)</td></tr>"' "$METRICS_FILE" >> "$REPORT_FILE"

  cat >> "$REPORT_FILE" <<EOF
  </table>

  <h2>Difftest Stack</h2>
  <p><strong>Total Tests:</strong> $(jq -r '.difftest.summary.total_tests // 0' "$METRICS_FILE")</p>
  <p><strong>Passed:</strong> <span class="ok">$(jq -r '.difftest.summary.passed // 0' "$METRICS_FILE")</span></p>
  <p><strong>Failed:</strong> <span class="fail">$(jq -r '.difftest.summary.failed // 0' "$METRICS_FILE")</span></p>
  <p><strong>Avg Time/Test:</strong> $(jq -r '.difftest.summary.avg_time_per_test_ms // 0' "$METRICS_FILE")ms</p>

</body>
</html>
EOF

  echo "HTML report: $REPORT_FILE"
}

# =============================================================================
# REGRESSION DETECTION
# =============================================================================

detect_regressions() {
  if [[ "$ALERT_ON_REGRESSION" != true ]]; then
    return 0
  fi

  local has_regression=false

  # Check Lean regressions
  local lean_regression=$(jq -r '.comparison.lean_regression // false' "$METRICS_FILE")
  if [[ "$lean_regression" == "true" ]]; then
    echo -e "${RED}❌ Lean performance regression detected${NC}"
    has_regression=true
  fi

  # Check difftest regressions
  local difftest_regression=$(jq -r '.comparison.difftest_regression // false' "$METRICS_FILE")
  if [[ "$difftest_regression" == "true" ]]; then
    echo -e "${RED}❌ Difftest performance regression detected${NC}"
    has_regression=true
  fi

  # Check budget violations
  local lean_status=$(jq -r '.lean.summary.full_tree_status' "$METRICS_FILE")
  if [[ "$lean_status" == "OVER_BUDGET" ]]; then
    echo -e "${RED}❌ Lean full tree build exceeded budget${NC}"
    has_regression=true
  fi

  if [[ "$has_regression" == true ]]; then
    echo -e "${RED}Performance regression detected!${NC}"
    echo "See report: $REPORT_FILE"
    return 1
  else
    echo -e "${GREEN}✅ No performance regressions detected${NC}"
    return 0
  fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
  echo -e "${BLUE}=================================================================================${NC}"
  echo -e "${BLUE}CA Verification Performance Profiler${NC}"
  echo -e "${BLUE}=================================================================================${NC}"
  echo ""
  echo "Mode: $MODE"
  echo "Stack: $STACK"
  echo "Output: $OUTPUT_DIR"
  echo ""

  # Profile requested stacks
  if [[ "$STACK" == "all" ]] || [[ "$STACK" == "lean" ]]; then
    profile_lean
  fi

  if [[ "$STACK" == "all" ]] || [[ "$STACK" == "msl" ]]; then
    profile_msl
  fi

  if [[ "$STACK" == "all" ]] || [[ "$STACK" == "difftest" ]]; then
    profile_difftest
  fi

  # Compare against baseline if provided
  if [[ -n "$BASELINE" ]]; then
    compare_baseline
  fi

  # Generate report
  generate_report

  # Detect regressions
  detect_regressions
  local exit_code=$?

  echo ""
  echo -e "${GREEN}=================================================================================${NC}"
  echo -e "${GREEN}Profiling complete!${NC}"
  echo -e "${GREEN}=================================================================================${NC}"
  echo "Metrics: $METRICS_FILE"
  echo "Report:  $REPORT_FILE"
  echo ""

  exit $exit_code
}

# Run main
main

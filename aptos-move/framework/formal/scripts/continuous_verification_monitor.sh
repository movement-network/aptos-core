#!/usr/bin/env bash
set -euo pipefail

#
# continuous_verification_monitor.sh
#
# Purpose: Continuous monitoring of verification infrastructure health.
# Runs in background, alerts on failures, tracks metrics over time.
#
# Usage:
#   ./continuous_verification_monitor.sh [OPTIONS]
#
# Options:
#   --interval <seconds>  Check interval (default: 300 = 5 minutes)
#   --alert <method>      Alert method: slack, email, log (default: log)
#   --metrics-dir <dir>   Metrics storage directory (default: ./metrics)
#   --operations <csv>    Operations to monitor (default: all)
#   --thresholds <file>   Custom thresholds file (default: ./thresholds.json)
#   --daemon              Run as background daemon
#   --stop                Stop running daemon
#
# Examples:
#   ./continuous_verification_monitor.sh --interval 600 --alert slack
#   ./continuous_verification_monitor.sh --daemon
#   ./continuous_verification_monitor.sh --stop
#

# Configuration
INTERVAL=300  # 5 minutes
ALERT_METHOD="log"
METRICS_DIR="./metrics"
OPERATIONS="normalization,withdrawal,transfer,rotation,registration"
THRESHOLDS_FILE="./thresholds.json"
DAEMON_MODE=false
STOP_DAEMON=false
PID_FILE="/tmp/ca_verification_monitor.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --alert)
      ALERT_METHOD="$2"
      shift 2
      ;;
    --metrics-dir)
      METRICS_DIR="$2"
      shift 2
      ;;
    --operations)
      OPERATIONS="$2"
      shift 2
      ;;
    --thresholds)
      THRESHOLDS_FILE="$2"
      shift 2
      ;;
    --daemon)
      DAEMON_MODE=true
      shift
      ;;
    --stop)
      STOP_DAEMON=true
      shift
      ;;
    --help)
      head -n 30 "$0" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage"
      exit 1
      ;;
  esac
done

# Stop daemon if requested
if [[ "$STOP_DAEMON" == true ]]; then
  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
      echo "Stopping verification monitor (PID: $PID)..."
      kill "$PID"
      rm "$PID_FILE"
      echo "Monitor stopped."
    else
      echo "No running monitor found (stale PID file)."
      rm "$PID_FILE"
    fi
  else
    echo "No monitor PID file found."
  fi
  exit 0
fi

# Create metrics directory
mkdir -p "$METRICS_DIR"

# Load thresholds or use defaults
if [[ -f "$THRESHOLDS_FILE" ]]; then
  # Load from JSON
  BUILD_TIME_THRESHOLD=$(jq -r '.build_time_seconds // 10' "$THRESHOLDS_FILE")
  AXIOM_COUNT_THRESHOLD=$(jq -r '.axiom_count // 23' "$THRESHOLDS_FILE")
  TEMP_AXIOM_THRESHOLD=$(jq -r '.temp_axiom_count // 0' "$THRESHOLDS_FILE")
else
  # Defaults
  BUILD_TIME_THRESHOLD=10
  AXIOM_COUNT_THRESHOLD=23
  TEMP_AXIOM_THRESHOLD=0
fi

# Alert function
send_alert() {
  local severity=$1
  local message=$2
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  case "$ALERT_METHOD" in
    slack)
      if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        curl -X POST "$SLACK_WEBHOOK_URL" \
          -H 'Content-Type: application/json' \
          -d "{\"text\": \"[$severity] CA Verification Monitor\\n$message\\n$timestamp\"}" \
          > /dev/null 2>&1
      else
        echo -e "${YELLOW}Warning: SLACK_WEBHOOK_URL not set, falling back to log${NC}"
        echo "[$timestamp] [$severity] $message" >> "$METRICS_DIR/alerts.log"
      fi
      ;;
    email)
      if [[ -n "${ALERT_EMAIL:-}" ]]; then
        echo "[$severity] $message" | mail -s "CA Verification Alert" "$ALERT_EMAIL"
      else
        echo -e "${YELLOW}Warning: ALERT_EMAIL not set, falling back to log${NC}"
        echo "[$timestamp] [$severity] $message" >> "$METRICS_DIR/alerts.log"
      fi
      ;;
    log)
      echo "[$timestamp] [$severity] $message" >> "$METRICS_DIR/alerts.log"
      echo -e "${RED}[$severity]${NC} $message"
      ;;
  esac
}

# Check operation health
check_operation() {
  local op=$1
  local op_cap="$(echo "${op:0:1}" | tr '[:lower:]' '[:upper:]')${op:1}"

  echo -e "${BLUE}Checking $op...${NC}"

  # Build and time
  local start_time=$(date +%s)
  local build_output=$(lake build MovementFormal.Experimental.ConfidentialAsset.$op_cap 2>&1 || echo "BUILD_FAILED")
  local end_time=$(date +%s)
  local build_time=$((end_time - start_time))

  # Check for build failure
  if echo "$build_output" | grep -q "BUILD_FAILED\|error:"; then
    send_alert "CRITICAL" "Build failed for $op"
    return 1
  fi

  # Check build time
  if [[ $build_time -gt $BUILD_TIME_THRESHOLD ]]; then
    send_alert "WARNING" "Build time for $op exceeded threshold: ${build_time}s > ${BUILD_TIME_THRESHOLD}s"
  fi

  # Check axioms
  local axiom_output=$(./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.$op_cap 2>&1 || echo "")
  local total_axioms=$(echo "$axiom_output" | grep "Total axioms:" | awk '{print $3}' || echo "0")
  local temp_axioms=$(echo "$axiom_output" | grep "Temporary axioms:" | awk '{print $3}' || echo "0")

  # Check axiom counts
  if [[ $temp_axioms -gt $TEMP_AXIOM_THRESHOLD ]]; then
    send_alert "CRITICAL" "Temporary axioms detected in $op: $temp_axioms (expected $TEMP_AXIOM_THRESHOLD)"
  fi

  # Record metrics
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$timestamp,$op,$build_time,$total_axioms,$temp_axioms" >> "$METRICS_DIR/metrics.csv"

  echo -e "${GREEN}✓${NC} $op: ${build_time}s, $total_axioms axioms ($temp_axioms temp)"
  return 0
}

# Check difftest corpus
check_difftest() {
  echo -e "${BLUE}Checking difftest corpus...${NC}"

  local difftest_output=$(./scripts/manage_difftest_corpus.sh test all 2>&1 || echo "DIFFTEST_FAILED")

  if echo "$difftest_output" | grep -q "DIFFTEST_FAILED\|FAIL"; then
    local failed_count=$(echo "$difftest_output" | grep -c "FAIL" || echo "0")
    send_alert "CRITICAL" "Difftest failures detected: $failed_count tests failed"
    return 1
  fi

  local passed_count=$(echo "$difftest_output" | grep -c "PASS" || echo "0")
  echo -e "${GREEN}✓${NC} Difftest: $passed_count tests passed"
  return 0
}

# Check CI/CD status
check_ci_cd() {
  echo -e "${BLUE}Checking CI/CD status...${NC}"

  # Check if gh CLI is available
  if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}gh CLI not installed, skipping CI/CD check${NC}"
    return 0
  fi

  # Get latest workflow run
  local latest_run=$(gh run list --workflow=ca-verification-suite.yaml --limit 1 --json conclusion --jq '.[0].conclusion' 2>&1 || echo "")

  if [[ "$latest_run" == "failure" ]]; then
    send_alert "WARNING" "Latest CI/CD run failed"
    return 1
  elif [[ "$latest_run" == "success" ]]; then
    echo -e "${GREEN}✓${NC} CI/CD: Latest run succeeded"
  else
    echo -e "${YELLOW}?${NC} CI/CD: Unknown status ($latest_run)"
  fi

  return 0
}

# Main monitoring loop
monitor_loop() {
  echo -e "${BLUE}=== CA Verification Monitor ===${NC}"
  echo "Interval: ${INTERVAL}s"
  echo "Alert method: $ALERT_METHOD"
  echo "Metrics dir: $METRICS_DIR"
  echo ""

  # Initialize metrics CSV if not exists
  if [[ ! -f "$METRICS_DIR/metrics.csv" ]]; then
    echo "timestamp,operation,build_time_s,total_axioms,temp_axioms" > "$METRICS_DIR/metrics.csv"
  fi

  local iteration=0

  while true; do
    iteration=$((iteration + 1))
    echo -e "${YELLOW}=== Iteration $iteration ($(date '+%Y-%m-%d %H:%M:%S')) ===${NC}"

    # Parse operations
    IFS=',' read -ra OPS_ARRAY <<< "$OPERATIONS"

    # Check each operation
    local all_passed=true
    for op in "${OPS_ARRAY[@]}"; do
      if ! check_operation "$op"; then
        all_passed=false
      fi
    done

    # Check difftest
    if ! check_difftest; then
      all_passed=false
    fi

    # Check CI/CD (optional, may not be available)
    check_ci_cd || true

    # Summary
    if [[ "$all_passed" == true ]]; then
      echo -e "${GREEN}✅ All checks passed${NC}"
    else
      echo -e "${RED}❌ Some checks failed (see alerts)${NC}"
    fi

    # Generate metrics summary
    echo ""
    echo -e "${BLUE}Recent metrics (last 10 entries):${NC}"
    tail -n 10 "$METRICS_DIR/metrics.csv" | column -t -s ','

    # Wait for next iteration
    echo ""
    echo -e "${YELLOW}Sleeping for ${INTERVAL}s...${NC}"
    sleep "$INTERVAL"
  done
}

# Run as daemon if requested
if [[ "$DAEMON_MODE" == true ]]; then
  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
      echo "Monitor already running (PID: $PID)"
      exit 1
    else
      rm "$PID_FILE"
    fi
  fi

  echo "Starting verification monitor as daemon..."
  nohup "$0" --interval "$INTERVAL" --alert "$ALERT_METHOD" --metrics-dir "$METRICS_DIR" --operations "$OPERATIONS" > "$METRICS_DIR/monitor.log" 2>&1 &
  DAEMON_PID=$!
  echo "$DAEMON_PID" > "$PID_FILE"
  echo "Monitor started (PID: $DAEMON_PID)"
  echo "Logs: $METRICS_DIR/monitor.log"
  echo "Stop with: $0 --stop"
  exit 0
fi

# Run monitoring loop (foreground)
monitor_loop

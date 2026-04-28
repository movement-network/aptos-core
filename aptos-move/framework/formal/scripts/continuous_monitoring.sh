#!/usr/bin/env bash
# scripts/continuous_monitoring.sh — Continuous verification health monitoring
#
# Monitors the health of the CA formal verification infrastructure in real-time.
# Tracks build status, axiom count, sorry count, performance metrics, and alerts
# on regressions or issues.
#
# Usage:
#   ./scripts/continuous_monitoring.sh [--interval SECONDS] [--webhook URL]
#   ./scripts/continuous_monitoring.sh --once
#   ./scripts/continuous_monitoring.sh --help
#
# Modes:
#   (default)    : Continuous monitoring (runs until interrupted)
#   --once       : Single monitoring pass
#   --interval N : Check every N seconds (default: 300 = 5 minutes)
#   --webhook URL: Send alerts to webhook URL
#
# Exit codes:
#   0 = Success (or interrupted in continuous mode)
#   1 = Health check failure detected
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
INTERVAL=300
WEBHOOK_URL=""
ONCE_MODE=false
MONITORING_LOG="logs/monitoring.log"
ALERT_COOLDOWN=3600  # 1 hour between duplicate alerts

# State tracking
LAST_SORRY_COUNT=""
LAST_AXIOM_COUNT=""
LAST_ALERT_TIME=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --webhook)
            WEBHOOK_URL="$2"
            shift 2
            ;;
        --once)
            ONCE_MODE=true
            shift
            ;;
        --help)
            cat <<EOF
Usage: $0 [--interval SECONDS] [--webhook URL] [--once]

Options:
  --interval N   : Check every N seconds (default: 300)
  --webhook URL  : Send alerts to webhook URL
  --once         : Single monitoring pass
  --help         : Show this help

Examples:
  # Continuous monitoring with 5-minute interval
  $0

  # Monitor every minute with webhook alerts
  $0 --interval 60 --webhook https://hooks.slack.com/...

  # Single health check
  $0 --once
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            exit 2
            ;;
    esac
done

# Setup
mkdir -p logs
mkdir -p reports/monitoring

# Helper: log message
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] $message" >> "$MONITORING_LOG"

    case "$level" in
        ERROR)
            echo -e "${RED}✗${NC} $message"
            ;;
        WARNING)
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        INFO)
            echo -e "${GREEN}✓${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Helper: send alert
send_alert() {
    local title="$1"
    local message="$2"
    local severity="${3:-warning}"

    # Check cooldown
    local now=$(date +%s)
    if [ $((now - LAST_ALERT_TIME)) -lt $ALERT_COOLDOWN ]; then
        log_message "INFO" "Alert suppressed (cooldown active): $title"
        return
    fi

    LAST_ALERT_TIME=$now

    if [ -n "$WEBHOOK_URL" ]; then
        local payload=$(jq -n \
            --arg title "$title" \
            --arg message "$message" \
            --arg severity "$severity" \
            --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            '{
                text: $title,
                attachments: [{
                    color: ($severity | if . == "error" then "danger" elif . == "warning" then "warning" else "good" end),
                    title: $title,
                    text: $message,
                    footer: "CA Formal Verification Monitor",
                    ts: ($timestamp | fromdateiso8601)
                }]
            }')

        curl -X POST -H 'Content-type: application/json' \
            --data "$payload" \
            "$WEBHOOK_URL" > /dev/null 2>&1 || \
            log_message "WARNING" "Failed to send webhook alert"
    fi

    log_message "ALERT" "$title: $message"
}

# Check: Lean build health
check_lean_build() {
    log_message "INFO" "Checking Lean build health..."

    cd lean
    if lake build > /tmp/monitor_lean_build.log 2>&1; then
        log_message "INFO" "Lean build: OK"
        return 0
    else
        local error_count=$(grep -c "error:" /tmp/monitor_lean_build.log || echo 0)
        send_alert "Lean Build Failure" \
            "Lean tree failed to build with $error_count errors. See logs/monitoring.log for details." \
            "error"
        cd ..
        return 1
    fi
    cd ..
}

# Check: Sorry count regression
check_sorry_count() {
    local current=$(grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" | grep -v "SORRY" | grep -v "comment" | wc -l | tr -d ' ')
    local baseline=21

    if [ "$current" -gt "$baseline" ]; then
        if [ "$current" != "$LAST_SORRY_COUNT" ]; then
            send_alert "Sorry Count Regression" \
                "Sorry count increased from baseline $baseline to $current (regression of $((current - baseline)))" \
                "warning"
        fi
    elif [ "$current" -lt "$baseline" ]; then
        if [ "$current" != "$LAST_SORRY_COUNT" ]; then
            log_message "INFO" "Sorry count improved: $current < $baseline (progress!)"
        fi
    fi

    LAST_SORRY_COUNT=$current
    log_message "INFO" "Sorry count: $current (baseline: $baseline)"
}

# Check: Axiom drift
check_axiom_drift() {
    local current=$(./scripts/check_axioms.sh --baseline 2>/dev/null | grep -c "^axiom" || echo 0)
    local expected=149

    if [ "$current" -gt "$((expected + 10))" ]; then
        if [ "$current" != "$LAST_AXIOM_COUNT" ]; then
            send_alert "Axiom Count Drift" \
                "Axiom count drifted from expected $expected to $current (+$((current - expected)))" \
                "warning"
        fi
    fi

    LAST_AXIOM_COUNT=$current
    log_message "INFO" "Axiom count: $current (expected: $expected)"
}

# Check: Build performance
check_build_performance() {
    log_message "INFO" "Checking build performance..."

    cd lean
    local start=$(date +%s)
    lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild > /dev/null 2>&1 || true
    local end=$(date +%s)
    local duration=$((end - start))
    cd ..

    local budget=180  # 3 minutes
    if [ $duration -gt $budget ]; then
        send_alert "Performance Regression" \
            "Registration build took ${duration}s (budget: ${budget}s, overage: $((duration - budget))s)" \
            "warning"
    else
        log_message "INFO" "Build performance: ${duration}s (within ${budget}s budget)"
    fi
}

# Check: Git status
check_git_status() {
    if ! git diff --quiet || ! git diff --cached --quiet; then
        log_message "WARNING" "Uncommitted changes detected in working directory"
    else
        log_message "INFO" "Git working directory clean"
    fi
}

# Check: Disk space
check_disk_space() {
    local usage=$(df -h . | awk 'NR==2 {print $5}' | tr -d '%')
    local threshold=90

    if [ "$usage" -gt "$threshold" ]; then
        send_alert "Disk Space Warning" \
            "Disk usage at ${usage}% (threshold: ${threshold}%)" \
            "warning"
    else
        log_message "INFO" "Disk space: ${usage}% used"
    fi
}

# Generate health report
generate_health_report() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local report_file="reports/monitoring/health-$(date +%Y-%m-%d-%H%M%S).json"

    jq -n \
        --arg timestamp "$timestamp" \
        --argjson sorry "$LAST_SORRY_COUNT" \
        --argjson axioms "$LAST_AXIOM_COUNT" \
        '{
            timestamp: $timestamp,
            metrics: {
                sorry_count: $sorry,
                axiom_count: $axioms
            },
            status: "healthy"
        }' > "$report_file"

    log_message "INFO" "Health report saved: $report_file"
}

# Single monitoring pass
run_monitoring_pass() {
    local pass_start=$(date +%s)

    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  CA Verification Health Check${NC}"
    echo -e "${BLUE}  $(date)${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    local failed=0

    check_lean_build || failed=$((failed + 1))
    check_sorry_count
    check_axiom_drift
    check_build_performance
    check_git_status
    check_disk_space
    generate_health_report

    local pass_end=$(date +%s)
    local pass_duration=$((pass_end - pass_start))

    echo ""
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✓ All health checks passed${NC} (${pass_duration}s)"
    else
        echo -e "${RED}✗ $failed health check(s) failed${NC} (${pass_duration}s)"
    fi
    echo ""

    return $failed
}

# Main
main() {
    echo -e "${BLUE}Starting CA Formal Verification Health Monitor${NC}"
    echo "  Interval: ${INTERVAL}s"
    if [ -n "$WEBHOOK_URL" ]; then
        echo "  Webhook: configured"
    fi
    if [ "$ONCE_MODE" = true ]; then
        echo "  Mode: single pass"
    else
        echo "  Mode: continuous"
        echo "  (Press Ctrl+C to stop)"
    fi
    echo ""

    # Initial pass
    run_monitoring_pass

    if [ "$ONCE_MODE" = true ]; then
        exit 0
    fi

    # Continuous monitoring
    while true; do
        sleep "$INTERVAL"
        run_monitoring_pass
    done
}

# Trap interrupts
trap 'echo ""; echo "Monitoring stopped"; exit 0' SIGINT SIGTERM

main "$@"

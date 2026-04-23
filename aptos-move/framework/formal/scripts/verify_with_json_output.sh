#!/usr/bin/env bash
# scripts/verify_with_json_output.sh — JSON output wrapper for verify-ca.sh
#
# Phase 7 stretch goal: structured status output for dashboard integration.
# Wraps verify-ca.sh execution and produces machine-readable JSON results.
#
# Usage:
#   ./scripts/verify_with_json_output.sh [verify-ca.sh args...] > results.json
#   ./scripts/verify_with_json_output.sh --op register --stack lean
#   ./scripts/verify_with_json_output.sh --help
#
# Output format:
#   {
#     "timestamp": "2026-04-23T12:34:56Z",
#     "command": ["verify-ca.sh", "--op", "register"],
#     "exit_code": 0,
#     "duration_seconds": 1.234,
#     "results": {
#       "operation": "register",
#       "stack": "all",
#       "status": "pass",
#       "checks": [...]
#     }
#   }
#
# Exit codes: mirrors verify-ca.sh exit code

set -euo pipefail

FORMAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY_CA_SCRIPT="$FORMAL_ROOT/audit/verify-ca.sh"

# Check prerequisites
if [ ! -x "$VERIFY_CA_SCRIPT" ]; then
    echo "{\"error\": \"verify-ca.sh not found or not executable at $VERIFY_CA_SCRIPT\"}" >&2
    exit 2
fi

if ! command -v jq &> /dev/null; then
    echo "{\"error\": \"jq not installed (required for JSON output)\"}" >&2
    exit 2
fi

# Parse arguments to extract operation and stack
OPERATION="all"
STACK="all"
CLAIM=""
LIST_MODE=false
COVERAGE_MODE=false

ARGS=("$@")
for ((i=0; i<${#ARGS[@]}; i++)); do
    case "${ARGS[i]}" in
        --op)
            ((i++))
            OPERATION="${ARGS[i]}"
            ;;
        --stack)
            ((i++))
            STACK="${ARGS[i]}"
            ;;
        --claim)
            ((i++))
            CLAIM="${ARGS[i]}"
            ;;
        --list)
            LIST_MODE=true
            ;;
        --coverage)
            COVERAGE_MODE=true
            ;;
    esac
done

# Create temporary files for capturing output
STDOUT_FILE=$(mktemp)
STDERR_FILE=$(mktemp)
trap "rm -f $STDOUT_FILE $STDERR_FILE" EXIT

# Execute verify-ca.sh and capture output
START_TIME=$(date +%s)
START_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

EXIT_CODE=0
"$VERIFY_CA_SCRIPT" "$@" > "$STDOUT_FILE" 2> "$STDERR_FILE" || EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Parse output to extract structured information
STDOUT_CONTENT=$(cat "$STDOUT_FILE")
STDERR_CONTENT=$(cat "$STDERR_FILE")

# Extract check results from stdout
# Look for patterns like "✅ PASS" or "❌ FAIL"
CHECKS_JSON="[]"
if [ "$LIST_MODE" = false ] && [ "$COVERAGE_MODE" = false ]; then
    # Extract check results (simplified - could be enhanced with more sophisticated parsing)
    CHECKS_JSON=$(echo "$STDOUT_CONTENT" | grep -E '(✅|❌|⚠️)' | \
        awk '{
            status = "unknown"
            if ($0 ~ /✅/) status = "pass"
            else if ($0 ~ /❌/) status = "fail"
            else if ($0 ~ /⚠️/) status = "warning"

            # Extract check name (everything before the status emoji)
            check_name = $0
            gsub(/.*\[/, "", check_name)
            gsub(/\].*/, "", check_name)

            print "{\"name\": \"" check_name "\", \"status\": \"" status "\"}"
        }' | jq -s '.' || echo "[]")
fi

# Determine overall status
STATUS="pass"
if [ "$EXIT_CODE" -ne 0 ]; then
    STATUS="fail"
elif echo "$STDOUT_CONTENT" | grep -q '❌'; then
    STATUS="fail"
elif echo "$STDOUT_CONTENT" | grep -q '⚠️'; then
    STATUS="warning"
fi

# Special handling for list mode
if [ "$LIST_MODE" = true ]; then
    # Extract claims list
    CLAIMS_JSON=$(echo "$STDOUT_CONTENT" | grep '^  •' | \
        awk '{sub(/^  • /, ""); print "{\"claim\": \"" $0 "\"}"}' | \
        jq -s '.' || echo "[]")

    jq -n \
        --arg timestamp "$START_ISO" \
        --argjson exit_code "$EXIT_CODE" \
        --argjson duration "$DURATION" \
        --argjson claims "$CLAIMS_JSON" \
        '{
            timestamp: $timestamp,
            command: ["verify-ca.sh", "--list"],
            exit_code: $exit_code,
            duration_seconds: $duration,
            mode: "list",
            claims: $claims
        }'
    exit "$EXIT_CODE"
fi

# Special handling for coverage mode
if [ "$COVERAGE_MODE" = true ]; then
    # Extract coverage statistics from stdout
    LEAN_THEOREMS=$(echo "$STDOUT_CONTENT" | grep -A1 "Lean EvalEquivRebuild theorems" | tail -1 | tr -d ' ' || echo "0")
    MSL_SPECS=$(echo "$STDOUT_CONTENT" | grep "TOTAL:" | awk '{print $2}' || echo "0")
    AXIOM_COUNT=$(echo "$STDOUT_CONTENT" | grep "^Total axioms:" | awk '{print $3}' || echo "0")

    jq -n \
        --arg timestamp "$START_ISO" \
        --argjson exit_code "$EXIT_CODE" \
        --argjson duration "$DURATION" \
        --argjson lean_theorems "$LEAN_THEOREMS" \
        --argjson msl_specs "$MSL_SPECS" \
        --argjson axiom_count "$AXIOM_COUNT" \
        '{
            timestamp: $timestamp,
            command: ["verify-ca.sh", "--coverage"],
            exit_code: $exit_code,
            duration_seconds: $duration,
            mode: "coverage",
            coverage: {
                lean_theorems: $lean_theorems,
                msl_specs: $msl_specs,
                axiom_count: $axiom_count
            }
        }'
    exit "$EXIT_CODE"
fi

# Build JSON output
jq -n \
    --arg timestamp "$START_ISO" \
    --arg operation "$OPERATION" \
    --arg stack "$STACK" \
    --arg claim "$CLAIM" \
    --arg status "$STATUS" \
    --argjson exit_code "$EXIT_CODE" \
    --argjson duration "$DURATION" \
    --argjson checks "$CHECKS_JSON" \
    --arg stdout "$STDOUT_CONTENT" \
    --arg stderr "$STDERR_CONTENT" \
    '{
        timestamp: $timestamp,
        command: (["verify-ca.sh"] + ($operation | if . != "all" then ["--op", .] else [] end) + ($stack | if . != "all" then ["--stack", .] else [] end) + ($claim | if . != "" then ["--claim", .] else [] end)),
        exit_code: $exit_code,
        duration_seconds: $duration,
        results: {
            operation: $operation,
            stack: $stack,
            claim: $claim,
            status: $status,
            checks: $checks
        },
        output: {
            stdout: $stdout,
            stderr: $stderr
        }
    }'

exit "$EXIT_CODE"

#!/bin/bash
set -euo pipefail

# PFN Backup Orchestrator
# Manages PFN (Public Full Node) lifecycle for automated hourly backups
# Runs as PID 1 in backup PFN container

# ============================================================================
# Global Variables
# ============================================================================

PFN_PID=""
LAST_BACKUP_HOUR=""
DATA_DIR="/opt/data/aptos"
PFN_CONFIG="/etc/validator/validator.yaml"
PFN_API_PORT="${PFN_API_PORT:-8080}"
REMOTE_API_URL="${REMOTE_API_URL:-}"
SYNC_THRESHOLD="${SYNC_THRESHOLD:-3}"
VERBOSE_BACKUPS=false  # Default: quiet during backup loop

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose-backups|--log-backups)
      VERBOSE_BACKUPS=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $*"
}

# ============================================================================
# PFN Process Management
# ============================================================================

start_pfn() {
    log_info "Starting PFN process..."

    # Start aptos-node in background, redirect output to log file
    # Use absolute path since we changed shared-bin mount location
    /usr/local/bin/aptos-node --config "$PFN_CONFIG" > /var/log/pfn.log 2>&1 &
    PFN_PID=$!

    # Verify the process is actually running
    sleep 2
    if ! kill -0 "$PFN_PID" 2>/dev/null; then
        log_error "PFN process failed to start or exited immediately"
        log_error "Check /var/log/pfn.log for errors"
        cat /var/log/pfn.log >&2
        exit 1
    fi

    log_info "PFN process started with PID: $PFN_PID"
}

stop_pfn() {
    if [ -n "$PFN_PID" ] && kill -0 "$PFN_PID" 2>/dev/null; then
        log_info "Stopping PFN process (PID: $PFN_PID)..."

        # Send SIGTERM for graceful shutdown
        kill -TERM "$PFN_PID"

        # Wait for process to exit
        wait "$PFN_PID" 2>/dev/null || true

        PFN_PID=""
        log_info "PFN process stopped"
    else
        log_warn "PFN process not running or already stopped"
    fi
}

# ============================================================================
# Sync Status Validation
# ============================================================================

is_synced() {
    local phase="${1:-sync}"  # Default to "sync" phase if not specified

    # Get local block height from PFN API
    local local_height
    local_height=$(curl -s "http://localhost:${PFN_API_PORT}/v1" | jq -r '.block_height // 0' 2>/dev/null || echo "0")

    if [ "$local_height" = "0" ]; then
        # Only log warnings during sync phase or if verbose mode enabled
        if [ "$phase" = "sync" ] || [ "$VERBOSE_BACKUPS" = "true" ]; then
            log_warn "Failed to get local block height from PFN API"
        fi
        return 1
    fi

    # If no remote API URL configured, assume synced
    if [ -z "$REMOTE_API_URL" ]; then
        # Only log during sync phase or if verbose mode enabled
        if [ "$phase" = "sync" ] || [ "$VERBOSE_BACKUPS" = "true" ]; then
            log_info "No remote API URL configured, assuming synced (local height: $local_height)"
        fi
        return 0
    fi

    # Get remote block height from reference node
    local remote_height
    remote_height=$(curl -s "$REMOTE_API_URL" | jq -r '.block_height // 0' 2>/dev/null || echo "0")

    if [ "$remote_height" = "0" ]; then
        # Only log warnings during sync phase or if verbose mode enabled
        if [ "$phase" = "sync" ] || [ "$VERBOSE_BACKUPS" = "true" ]; then
            log_warn "Failed to get remote block height from reference API"
        fi
        return 1
    fi

    # Calculate absolute difference
    local diff=$((remote_height - local_height))
    if [ "$diff" -lt 0 ]; then
        diff=$((-diff))
    fi

    # Check if difference is within threshold
    if [ "$diff" -le "$SYNC_THRESHOLD" ]; then
        # Only log during sync phase or if verbose mode enabled
        if [ "$phase" = "sync" ] || [ "$VERBOSE_BACKUPS" = "true" ]; then
            log_info "PFN is synced (local: $local_height, remote: $remote_height, diff: $diff)"
        fi
        return 0
    else
        # Only log during sync phase or if verbose mode enabled
        if [ "$phase" = "sync" ] || [ "$VERBOSE_BACKUPS" = "true" ]; then
            log_info "PFN is not synced yet (local: $local_height, remote: $remote_height, diff: $diff)"
        fi
        return 1
    fi
}

# ============================================================================
# Backup Operations
# ============================================================================

run_backup() {
    log_info "Starting backup process..."

    # Initialize restic repository if it doesn't exist
    if ! restic snapshots &>/dev/null; then
        log_info "Initializing restic repository..."
        if restic init; then
            log_info "Restic repository initialized successfully"
        else
            log_error "Failed to initialize restic repository"
            return 1
        fi
    fi

    # Run restic backup
    log_info "Creating backup snapshot of $DATA_DIR..."
    if restic backup "$DATA_DIR" \
        --host "$RESTIC_HOST" \
        --tag hourly \
        --exclude-caches \
        --exclude '*.tmp' \
        --exclude '*.lock'; then
        log_info "Backup snapshot created successfully"
    else
        log_error "Failed to create backup snapshot"
        return 1
    fi

    # Prune old snapshots - keep 336 hourly backups (14 days)
    log_info "Pruning old snapshots (keeping 336 hourly backups)..."
    if restic forget --keep-hourly 336 --prune --host "$RESTIC_HOST"; then
        log_info "Old snapshots pruned successfully"
    else
        log_warn "Failed to prune old snapshots (non-fatal)"
    fi

    log_info "Backup process completed successfully"
    return 0
}

perform_backup_cycle() {
    log_info "=== Starting backup cycle ==="

    # Stop PFN gracefully
    stop_pfn

    # Wait 5 seconds for any pending writes to flush
    log_info "Waiting 5 seconds for write flush..."
    sleep 5

    # Run backup
    if run_backup; then
        log_info "Backup cycle completed successfully"
    else
        log_error "Backup cycle failed"
    fi

    # Restart PFN regardless of backup status
    start_pfn

    log_info "=== Backup cycle finished ==="
}

# ============================================================================
# Main Orchestration Loop
# ============================================================================

main() {
    log_info "=== PFN Backup Orchestrator Starting ==="

    # Install required dependencies (curl, jq)
    log_info "Installing dependencies (curl, jq)..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq curl jq &>/dev/null
        log_info "Dependencies installed successfully"
    else
        log_error "apt-get not found - cannot install dependencies"
        exit 1
    fi

    log_info "Configuration:"
    log_info "  - Data directory: $DATA_DIR"
    log_info "  - PFN config: $PFN_CONFIG"
    log_info "  - PFN API port: $PFN_API_PORT"
    log_info "  - Local API URL: http://localhost:${PFN_API_PORT}/v1"
    log_info "  - Remote API URL: ${REMOTE_API_URL:-not configured}"
    log_info "  - Sync threshold: $SYNC_THRESHOLD blocks"
    log_info "  - S3 bucket: ${S3_BUCKET:-not set}"
    log_info "  - AWS region: ${AWS_REGION:-not set}"
    log_info "  - Restic host: ${RESTIC_HOST:-not set}"

    # Configure restic repository URL
    if [ -n "${S3_BUCKET:-}" ] && [ -n "${AWS_REGION:-}" ] && [ -n "${RESTIC_HOST:-}" ]; then
        export RESTIC_REPOSITORY="s3:https://s3.${AWS_REGION}.amazonaws.com/${S3_BUCKET}/${RESTIC_HOST}"
        log_info "  - Restic repository: $RESTIC_REPOSITORY"
    else
        log_error "Required environment variables not set (S3_BUCKET, AWS_REGION, RESTIC_HOST)"
        exit 1
    fi

    # Verify restic password is set
    if [ -z "${RESTIC_PASSWORD:-}" ]; then
        log_error "RESTIC_PASSWORD environment variable not set"
        exit 1
    fi

    # Start PFN process
    start_pfn

    # Wait for PFN API to become ready (aptos-node takes time to start REST API)
    log_info "Waiting for PFN API to become ready..."
    sleep 30

    # Wait for API to respond (check HTTP status, not block height)
    log_info "Checking if PFN API is responding..."
    local api_ready=false
    for i in {1..10}; do
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PFN_API_PORT}/v1" 2>/dev/null || echo "000")
        if [ "$http_code" = "200" ]; then
            log_info "PFN API is ready (HTTP $http_code)"
            api_ready=true
            break
        fi
        log_info "PFN API not ready yet (HTTP $http_code), waiting... (attempt $i/10)"
        sleep 10
    done

    if [ "$api_ready" = false ]; then
        log_error "PFN API did not become ready after 130 seconds"
        log_error "Check PFN logs for errors:"
        tail -50 /var/log/pfn.log >&2
        exit 1
    fi

    # Wait for initial sync with detailed progress logging
    log_info "Waiting for initial sync..."
    log_info "Starting PFN log monitoring in background..."

    # Tail PFN logs in background with clear prefix
    tail -f /var/log/pfn.log 2>/dev/null | while IFS= read -r line; do
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [PFN-NODE] $line"
    done &

    local last_height=0
    local sync_start_time=$(date +%s)
    local check_count=0

    while ! is_synced "sync"; do
        check_count=$((check_count + 1))

        # Get current sync status
        local local_height
        local_height=$(curl -s "http://localhost:${PFN_API_PORT}/v1" | jq -r '.ledger_version // "0"' 2>/dev/null || echo "0")

        local remote_height=""
        if [ -n "$REMOTE_API_URL" ]; then
            remote_height=$(curl -s "$REMOTE_API_URL" | jq -r '.ledger_version // "0"' 2>/dev/null || echo "0")
        fi

        # Calculate sync progress
        if [ "$local_height" != "0" ] && [ "$remote_height" != "0" ] && [ "$remote_height" != "null" ]; then
            local progress_pct=$((local_height * 100 / remote_height))
            local remaining=$((remote_height - local_height))

            # Calculate sync rate (blocks per minute)
            if [ "$last_height" != "0" ] && [ "$local_height" -gt "$last_height" ]; then
                local blocks_synced=$((local_height - last_height))
                local elapsed_time=$(($(date +%s) - sync_start_time))
                local elapsed_minutes=$((elapsed_time / 60))

                if [ "$elapsed_minutes" -gt 0 ]; then
                    local sync_rate=$((blocks_synced / elapsed_minutes))
                    local eta_minutes=$((remaining / sync_rate))
                    local eta_hours=$((eta_minutes / 60))

                    log_info "SYNC PROGRESS: ${progress_pct}% | Local: ${local_height} | Remote: ${remote_height} | Remaining: ${remaining} blocks | Rate: ${sync_rate} blocks/min | ETA: ${eta_hours}h ${eta_minutes}m"
                else
                    log_info "SYNC PROGRESS: ${progress_pct}% | Local: ${local_height} | Remote: ${remote_height} | Remaining: ${remaining} blocks | Calculating sync rate..."
                fi
            else
                log_info "SYNC PROGRESS: ${progress_pct}% | Local: ${local_height} | Remote: ${remote_height} | Remaining: ${remaining} blocks | Warming up..."
            fi

            last_height=$local_height
        else
            if [ "$local_height" = "0" ]; then
                log_info "WAITING: Node initializing (ledger_version: 0) - waiting for sync to start... (check ${check_count})"
            else
                log_info "SYNCING: Local ledger_version: ${local_height} (remote API unavailable)"
            fi
        fi

        sleep 60
    done

    # Stop tailing PFN logs
    log_info "Initial sync completed - stopping PFN log monitoring"
    # Kill all tail processes monitoring pfn.log
    # Using pkill with pattern matching is more reliable than tracking PIDs through pipes
    if pkill -f "tail -f /var/log/pfn.log" 2>/dev/null; then
        log_info "Stopped PFN log monitoring processes"
        sleep 1
    else
        log_warn "No tail processes found to stop (may have already exited)"
    fi

    # Main orchestration loop
    log_info "Entering main orchestration loop..."
    while true; do
        CURRENT_HOUR=$(date +%Y-%m-%d-%H)
        CURRENT_MIN=$(date +%M)

        # Check if it's backup time (minute :00) and we haven't backed up this hour
        if [ "$CURRENT_MIN" = "00" ] && [ "$LAST_BACKUP_HOUR" != "$CURRENT_HOUR" ]; then
            log_info "Backup time detected (hour: $CURRENT_HOUR)"

            # Verify PFN is synced before backup
            if is_synced "backup"; then
                perform_backup_cycle
                LAST_BACKUP_HOUR="$CURRENT_HOUR"
            else
                log_warn "Skipping backup - PFN not synced"
            fi
        fi

        # Health check: restart PFN if process died unexpectedly
        if [ -n "$PFN_PID" ] && ! kill -0 "$PFN_PID" 2>/dev/null; then
            log_error "PFN process died unexpectedly, restarting..."
            start_pfn

            # Wait for sync after restart
            log_info "Waiting for sync after PFN restart..."
            while ! is_synced "backup"; do
                sleep 60
            done
            log_info "PFN synced after restart"
        fi

        # Sleep for 1 minute before next check
        sleep 60
    done
}

# ============================================================================
# Signal Handling
# ============================================================================

# Trap termination signals for graceful shutdown
cleanup() {
    log_info "Received termination signal, shutting down..."
    stop_pfn
    exit 0
}

trap cleanup SIGTERM SIGINT

# ============================================================================
# Entry Point
# ============================================================================

# Run main orchestration function
main

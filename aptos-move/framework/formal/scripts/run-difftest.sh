#!/usr/bin/env bash
# run-difftest.sh — Wrapper for difftest harness
#
# Usage:
#   ./scripts/run-difftest.sh <operation> [--verbose]
#
# Operations: normalization, withdrawal, transfer, rotation, registration
#
# Examples:
#   ./scripts/run-difftest.sh normalization
#   ./scripts/run-difftest.sh withdrawal --verbose

set -euo pipefail

OPERATION="${1:-}"
VERBOSE=false

# Parse arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <operation> [--verbose]" >&2
    echo "Operations: normalization, withdrawal, transfer, rotation, registration" >&2
    exit 1
fi

if [[ $# -ge 2 ]] && [[ "$2" == "--verbose" ]]; then
    VERBOSE=true
fi

# Map operation to corpus file
CORPUS_DIR="difftest/corpora/confidential_assets"

case "$OPERATION" in
    normalization)
        CORPUS_FILE="$CORPUS_DIR/normalization_corpus.json"
        ;;
    withdrawal)
        CORPUS_FILE="$CORPUS_DIR/withdrawal_corpus.json"
        ;;
    transfer)
        CORPUS_FILE="$CORPUS_DIR/transfer_corpus.json"
        ;;
    rotation)
        CORPUS_FILE="$CORPUS_DIR/rotation_corpus.json"
        ;;
    registration)
        CORPUS_FILE="$CORPUS_DIR/registration_corpus.json"
        ;;
    *)
        echo "Error: Unknown operation '$OPERATION'" >&2
        echo "Supported: normalization, withdrawal, transfer, rotation, registration" >&2
        exit 1
        ;;
esac

if [[ ! -f "$CORPUS_FILE" ]]; then
    echo "Error: Corpus file not found: $CORPUS_FILE" >&2
    echo "Current directory: $(pwd)" >&2
    echo "Expected path: $CORPUS_FILE" >&2
    exit 1
fi

# Build difftest if needed
DIFFTEST_BIN="difftest/target/release/difftest"

if [[ ! -f "$DIFFTEST_BIN" ]]; then
    echo "Building difftest harness (first run only)..."
    if [[ ! -f "difftest/Cargo.toml" ]]; then
        echo "Error: difftest/Cargo.toml not found" >&2
        echo "Run this script from aptos-move/framework/formal/" >&2
        exit 1
    fi

    (cd difftest && cargo build --release)

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to build difftest harness" >&2
        exit 1
    fi
fi

# Run difftest
echo "Running difftest for $OPERATION..."
echo "Corpus: $CORPUS_FILE"

DIFFTEST_CMD=("$DIFFTEST_BIN" "--corpus" "$CORPUS_FILE")

if [[ "$VERBOSE" == "true" ]]; then
    DIFFTEST_CMD+=("--verbose")
fi

# Execute difftest
"${DIFFTEST_CMD[@]}"

DIFFTEST_EXIT_CODE=$?

# Report results
if [[ $DIFFTEST_EXIT_CODE -eq 0 ]]; then
    echo "✅ Difftest passed for $OPERATION"
    exit 0
else
    echo "❌ Difftest failed for $OPERATION (exit code: $DIFFTEST_EXIT_CODE)"
    exit 1
fi

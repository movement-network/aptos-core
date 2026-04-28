#!/usr/bin/env bash
# profile_lean_build.sh
# Profiles Lean build times with detailed breakdown
# Usage: ./profile_lean_build.sh [--file MODULE] [--verbose]

set -euo pipefail

FILE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --file) FILE="$2"; shift 2 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

LEAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lean" && pwd)"
cd "$LEAN_DIR"

profile_file() {
    local module="$1"
    echo "Profiling: $module"
    
    # Clean build
    rm -f ".lake/build/lib/${module}.olean"
    rm -f ".lake/build/lib/${module}.trace"
    
    # Build with timing
    local start=$(date +%s.%N)
    /usr/bin/time -l lake build "$module" 2>&1 | tee /tmp/build.log
    local end=$(date +%s.%N)
    
    local elapsed=$(echo "$end - $start" | bc)
    echo "Build time: ${elapsed}s"
    
    if [[ "$VERBOSE" == true ]]; then
        echo "Memory usage:"
        grep "maximum resident set size" /tmp/build.log || true
        echo "File size:"
        ls -lh ".lake/build/lib/${module}.olean" 2>/dev/null || true
    fi
}

if [[ -n "$FILE" ]]; then
    profile_file "$FILE"
else
    echo "Profiling all CA files..."
    for f in MovementFormal/Experimental/ConfidentialAsset/**/EvalEquiv*.lean; do
        module=$(echo "$f" | sed 's|/|.|g' | sed 's|\.lean$||')
        profile_file "$module"
    done
fi

#!/usr/bin/env bash
# scripts/check_axioms.sh — enumerate every axiom / pragma-opaque / pragma-escape in
# the CA formal-verification surface.
#
# Modes:
#   (no flag) — human-readable output with section headers
#   --baseline — sorted normalized output suitable for diffing against audit/axiom-baseline.txt
#   --diff — compare current state against audit/axiom-baseline.txt, fail on net-new axioms
#
# Used by:
#   - .github/workflows/move-prover-ca.yaml (inventory step)
#   - .github/workflows/axiom-diff-ca.yaml (CI guard per plan §10.5)
#   - audit/TRUST_BOUNDARIES.md regeneration
#
# Exit 0 on clean; non-zero only in --diff mode if the baseline doesn't match current state.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../.." && pwd)"

CA_SRC="$REPO_ROOT/aptos-move/framework/aptos-experimental/sources/confidential_asset"
RISTRETTO_SRC="$REPO_ROOT/aptos-move/framework/aptos-stdlib/sources/cryptography"
LEAN_ROOT="$REPO_ROOT/aptos-move/framework/formal/lean/MovementFormal/Experimental/ConfidentialAsset"
AXIOM_BASELINE="$REPO_ROOT/aptos-move/framework/formal/audit/axiom-baseline.txt"

# Extract just the axiom names (stripping file paths, line numbers, formal args).
# Produces sorted "axiom <name>" lines suitable for diffing.
emit_baseline() {
    # Find real `axiom <name>` declarations. Real axioms have one of:
    #   - same-line `(` or `:` (args or type annotation)
    #   - end-of-line (args/type continue on next line)
    # Comments in doc blocks that happen to start with "axiom " are followed by English prose,
    # which we filter by requiring the end-of-line or bracket/colon pattern.
    grep -rh --include='*.lean' -E "^axiom [A-Za-z_][A-Za-z_0-9']*([[:space:]]*[(:]|[[:space:]]*$)" \
        "$REPO_ROOT/aptos-move/framework/formal/lean/MovementFormal" 2>/dev/null \
        | sed -E "s/^(axiom [A-Za-z_][A-Za-z_0-9']*).*/\1/" \
        | sort -u
}

# --- Dispatch ---
if [ "${1:-}" = "--baseline" ]; then
    emit_baseline
    exit 0
fi

if [ "${1:-}" = "--diff" ]; then
    if [ ! -f "$AXIOM_BASELINE" ]; then
        echo "ERROR: baseline file not found at $AXIOM_BASELINE" >&2
        exit 2
    fi
    CURRENT="$(emit_baseline)"
    # Extract axiom lines from baseline file (strip comments + TEMPORARY section markers).
    BASELINE="$(grep -E '^axiom [A-Za-z_]' "$AXIOM_BASELINE" | sort -u)"
    if ! diff <(echo "$BASELINE") <(echo "$CURRENT") > /dev/null; then
        echo "=========================================="
        echo "  AXIOM DIFF FAILED"
        echo "=========================================="
        echo "Current axioms differ from baseline at audit/axiom-baseline.txt:"
        diff -u <(echo "$BASELINE") <(echo "$CURRENT") || true
        echo
        echo "If the diff is intentional (new axiom with a documented trust rationale):"
        echo "  1. Add a row to audit/AXIOM_INVENTORY.md explaining the new axiom"
        echo "  2. Regenerate the baseline:"
        echo "     ./aptos-move/framework/formal/scripts/check_axioms.sh --baseline > audit/axiom-baseline-new.txt"
        echo "     (then merge into audit/axiom-baseline.txt manually, preserving the comments)"
        exit 1
    fi
    echo "OK: axiom baseline matches current state ($(echo "$CURRENT" | wc -l | tr -d ' ') axioms)"
    exit 0
fi

# Default mode: human-readable inventory.
echo "=========================================="
echo "  MSL pragma-escape inventory (CA)"
echo "=========================================="
grep -RHn --include='*.spec.move' --include='*.move' \
    -E 'pragma opaque|pragma deactivated_proof|pragma verify = false|pragma aborts_if_is_partial' \
    "$CA_SRC" "$RISTRETTO_SRC" \
    || echo "(no escapes found)"

echo
echo "=========================================="
echo "  Lean axiom declarations (CA)"
echo "=========================================="
grep -RHn --include='*.lean' \
    -E '^axiom |^TEMPORARY AXIOM' \
    "$LEAN_ROOT" \
    || echo "(no axioms found)"

echo
echo "=========================================="
echo "  Lean @[opaque] declarations (CA oracle boundary)"
echo "=========================================="
grep -RHn --include='*.lean' \
    -E '@\[opaque\]' \
    "$LEAN_ROOT" \
    "$REPO_ROOT/aptos-move/framework/formal/lean/MovementFormal/MoveModel/Native" \
    || echo "(no @[opaque] found)"

echo
echo "=========================================="
echo "  TEMPORARY AXIOM markers (work-in-progress)"
echo "=========================================="
grep -RHn --include='*.lean' \
    'TEMPORARY AXIOM' \
    "$REPO_ROOT/aptos-move/framework/formal/lean/MovementFormal" \
    || echo "(no TEMPORARY AXIOM markers — rebuild complete or nothing to reprove)"

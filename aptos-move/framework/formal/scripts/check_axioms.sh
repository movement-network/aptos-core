#!/usr/bin/env bash
# scripts/check_axioms.sh — enumerate every axiom / pragma-opaque / pragma-escape in
# the CA formal-verification surface.
#
# Used by:
#   - .github/workflows/move-prover-ca.yaml (inventory step)
#   - audit/TRUST_BOUNDARIES.md regeneration
#
# Exit 0 on clean enumeration; non-zero only if grep / find itself fails.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../.." && pwd)"

CA_SRC="$REPO_ROOT/aptos-move/framework/aptos-experimental/sources/confidential_asset"
RISTRETTO_SRC="$REPO_ROOT/aptos-move/framework/aptos-stdlib/sources/cryptography"
LEAN_ROOT="$REPO_ROOT/aptos-move/framework/formal/lean/MovementFormal/Experimental/ConfidentialAsset"

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

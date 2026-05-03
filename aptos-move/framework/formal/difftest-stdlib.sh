#!/usr/bin/env bash
# Move ↔ Lean differential tests — **move-stdlib-related suites only** (no confidential / FA / e2e).
#
# Skips `verify-corpora` and `check_confidential_lean_hygiene.sh`. Oracle JSON contains only:
#   vector, acl, bcs, bit_vector, error, hash, signer, string, cmp,
#   fixed_point32, option, global_resource_smoke
#
# Usage (repo root):
#   chmod +x aptos-move/framework/formal/difftest-stdlib.sh   # once
#   ./aptos-move/framework/formal/difftest-stdlib.sh
#
# Optional: custom oracle path (absolute or relative to this script’s `difftest/` dir)
#   ./aptos-move/framework/formal/difftest-stdlib.sh my_stdlib_oracle.json
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LEAN_DIR="$SCRIPT_DIR/lean"
DIFTEST_CRATE="$SCRIPT_DIR/difftest"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '1,22p' "$0"
  exit 0
fi

if [[ -n "${1:-}" ]]; then
  if [[ "$1" == /* ]]; then
    JSON="$1"
  else
    JSON="$DIFTEST_CRATE/$1"
  fi
else
  JSON="$DIFTEST_CRATE/difftest_oracle_stdlib.json"
fi

STDLIB_SUITES=(
  vector acl bcs bit_vector error hash signer string cmp
  fixed_point32 option global_resource_smoke
)

SUITE_ARGS=()
for s in "${STDLIB_SUITES[@]}"; do
  SUITE_ARGS+=(--suite "$s")
done

echo "=== Move ↔ Lean differential tests (stdlib suites only) ==="
echo "Oracle: $JSON"
echo ""

echo "[1/2] Oracle: cargo run -p move-lean-difftest → $JSON"
(cd "$REPO_ROOT" && cargo run -p move-lean-difftest -- --quiet "${SUITE_ARGS[@]}" -o "$JSON")

echo ""
echo "[2/2] Lean: lake build difftest && lake exe difftest"
(cd "$LEAN_DIR" && lake build difftest && lake exe difftest "$JSON")

echo ""
echo "Done."

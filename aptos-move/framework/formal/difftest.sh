#!/usr/bin/env bash
# Move ↔ Lean differential tests: VM oracle JSON → Lean `difftest`.
# Covers vector, BCS, hash (and future suites). Not tied to vector.move only.
#
# Usage:
#   ./aptos-move/framework/formal/difftest.sh
#   ./aptos-move/framework/formal/difftest.sh --suite bcs
#   ./aptos-move/framework/formal/difftest.sh --suite bcs --output my.json
#
# Oracle path matches the Rust harness defaults (see `cargo run -p move-lean-difftest -- --help`).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LEAN_DIR="$SCRIPT_DIR/lean"
DIFTEST_CRATE="$SCRIPT_DIR/difftest"

USER_OUTPUT=""
SUITES=()
ARGS_ALL=("$@")
i=0
while [[ $i -lt ${#ARGS_ALL[@]} ]]; do
  a="${ARGS_ALL[$i]}"
  case "$a" in
    --output|-o)
      USER_OUTPUT="${ARGS_ALL[$((i + 1))]}"
      i=$((i + 2))
      ;;
    --suite)
      SUITES+=("${ARGS_ALL[$((i + 1))]}")
      i=$((i + 2))
      ;;
    *)
      i=$((i + 1))
      ;;
  esac
done

if [[ -n "$USER_OUTPUT" ]]; then
  if [[ "$USER_OUTPUT" == /* ]]; then
    JSON="$USER_OUTPUT"
  else
    JSON="$DIFTEST_CRATE/$USER_OUTPUT"
  fi
elif [[ ${#SUITES[@]} -eq 0 ]]; then
  JSON="$DIFTEST_CRATE/difftest_oracle.json"
else
  SUF=$(printf '%s\n' "${SUITES[@]}" | sort -u | tr '\n' '_' | sed 's/_$//')
  JSON="$DIFTEST_CRATE/difftest_oracle_${SUF}.json"
fi

echo "=== Move ↔ Lean differential tests ==="
echo ""

echo "[1/2] Oracle: real Move VM → $JSON"
(cd "$REPO_ROOT" && cargo run -p move-lean-difftest -- --quiet "$@")

echo ""
echo "[2/2] Model: Lean evaluator vs JSON"
(cd "$LEAN_DIR" && lake build difftest && lake exe difftest "$JSON")

echo ""
echo "Done. Inspect the oracle file anytime:"
echo "  $JSON"
echo ""

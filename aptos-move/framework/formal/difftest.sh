#!/usr/bin/env bash
# Move ↔ Lean differential tests: VM oracle JSON → Lean `difftest`.
# Covers vector, BCS, hash, confidential balance/proof/layer smoke (`--suite confidential`, …).
#
# Usage:
#   ./aptos-move/framework/formal/difftest.sh
#   ./aptos-move/framework/formal/difftest.sh --suite bcs
#   ./aptos-move/framework/formal/difftest.sh --suite bcs --output my.json
#   ./aptos-move/framework/formal/difftest.sh --list-suites
#
# Oracle path matches the Rust harness defaults (see `cargo run -p move-lean-difftest -- --help`).
# `--list-suites` prints registered suite ids and exits (no Lean step).
# Optional: `DIFTEST_MERGE_CA_E2E=1` exports the CA e2e `OracleFragment`, merges it into the harness
# oracle, and runs Lean on `difftest_ci_merged.json` (same idea as `.github/workflows/formal-difftest.yaml`).
# Step [0]: `cargo run -p move-lean-difftest -- verify-corpora` (Rust hex corpus checks).
set -euo pipefail

for arg in "$@"; do
  if [[ "$arg" == "--list-suites" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
    (cd "$REPO_ROOT" && cargo run -p move-lean-difftest -- --list-suites)
    exit 0
  fi
done

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

echo "[0] Corpus: registration FS + tagged SHA3-512 + Bulletproofs DST + serializer hex (Rust verify-corpora)"
(cd "$REPO_ROOT" && cargo run -p move-lean-difftest -- verify-corpora)

echo ""
echo "[0a] ConfidentialAsset Lean hygiene (no line-start sorry; single allowlisted axiom)"
bash "$SCRIPT_DIR/scripts/check_confidential_lean_hygiene.sh"

echo ""
echo "[1/2] Oracle: real Move VM → $JSON"
(cd "$REPO_ROOT" && cargo run -p move-lean-difftest -- --quiet "$@")

if [[ "${DIFTEST_MERGE_CA_E2E:-}" == "1" ]]; then
  FRAG="$DIFTEST_CRATE/difftest_ca_e2e_fragment.json"
  MERGED="$DIFTEST_CRATE/difftest_ci_merged.json"
  echo ""
  echo "[1b] CA e2e → OracleFragment → $FRAG"
  (cd "$REPO_ROOT" && \
    CONFIDENTIAL_ASSET_E2E_ORACLE_OUT="$FRAG" \
    RUST_MIN_STACK=8388608 \
    cargo test -p e2e-move-tests export_confidential_asset_e2e_oracle_fragment -- --test-threads=1)
  echo ""
  echo "[1c] merge → $MERGED"
  (cd "$REPO_ROOT" && cargo run -p move-lean-difftest -- merge -o "$MERGED" "$JSON" "$FRAG")
  JSON="$MERGED"
fi

echo ""
echo "[2/2] Model: Lean evaluator vs JSON"
(cd "$LEAN_DIR" && lake build difftest && lake exe difftest "$JSON")

echo ""
echo "Done. Inspect the oracle file anytime:"
echo "  $JSON"
echo ""

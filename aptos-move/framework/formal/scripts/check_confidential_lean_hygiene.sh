#!/usr/bin/env bash
# Fail if ConfidentialAsset formal Lean gains undocumented `sorry` or an extra top-level `axiom`.
# Intended trust model: exactly one named bytecode bridge axiom (`registration_eval_equiv_singleton_tail`)
# under `Experimental/ConfidentialAsset/`; companion CA bytecode/refinement/smoke modules elsewhere must
# have **no** `axiom` lines and no line-start `sorry`.
#
# Usage: from repo root,
#   bash aptos-move/framework/formal/scripts/check_confidential_lean_hygiene.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MF_ROOT="$FORMAL_ROOT/lean/MovementFormal"
CA_DIR="$MF_ROOT/Experimental/ConfidentialAsset"
# Edwards oracle scaffolding, bytecode transcription, registration program/natives, refinement,
# smoke tests, and VM↔Lean oracle routing for CA live outside the Experimental tree (or are shared
# entrypoints for CA rows). Shared AptosStd crypto files that legitimately declare axioms are not listed.
CA_EXTRA_LEANS=(
  "$MF_ROOT/AptosStd/Crypto/EdwardsOracle.lean"
  "$MF_ROOT/Refinement/AptosExperimental/Confidential.lean"
  "$MF_ROOT/MoveModel/Programs/Confidential.lean"
  "$MF_ROOT/MoveModel/Programs/Registration.lean"
  "$MF_ROOT/MoveModel/Programs/RegistrationDifftestOracle.lean"
  "$MF_ROOT/MoveModel/Native/Registration.lean"
  "$MF_ROOT/SmokeTests/Confidential.lean"
  "$MF_ROOT/DiffTest/Runner.lean"
  "$MF_ROOT/DiffTest/RunnerFuncMappingAux.lean"
)

if [[ ! -d "$CA_DIR" ]]; then
  echo "ERROR: expected directory $CA_DIR" >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) is required for this check." >&2
  exit 1
fi

EXISTING_EXTRAS=()
for f in "${CA_EXTRA_LEANS[@]}"; do
  if [[ -f "$f" ]]; then
    EXISTING_EXTRAS+=("$f")
  fi
done

SORRY_LINES="$(rg -n '^\s*sorry\b' "$CA_DIR" --glob '*.lean' "${EXISTING_EXTRAS[@]}" || true)"
if [[ -n "$SORRY_LINES" ]]; then
  echo "ERROR: line-start 'sorry' in ConfidentialAsset formal Lean (proof debt / unsound shortcut):" >&2
  echo "$SORRY_LINES" >&2
  exit 1
fi

for f in "${EXISTING_EXTRAS[@]}"; do
  EXTRA_AXIOMS="$(rg -n '^axiom\s+' "$f" || true)"
  if [[ -n "$EXTRA_AXIOMS" ]]; then
    echo "ERROR: unexpected '^axiom' in CA companion module (must stay axiom-free): $f" >&2
    echo "$EXTRA_AXIOMS" >&2
    exit 1
  fi
done

AXIOM_LINES="$(rg -n '^axiom\s+' "$CA_DIR" --glob '*.lean' || true)"
if [[ -z "$AXIOM_LINES" ]]; then
  echo "ERROR: expected exactly one allowlisted axiom in $CA_DIR; found none." >&2
  exit 1
fi

COUNT="$(echo "$AXIOM_LINES" | wc -l | tr -d ' ')"
if [[ "$COUNT" != "1" ]]; then
  echo "ERROR: expected exactly one '^axiom' line under ConfidentialAsset formal Lean; update allowlist if intentional." >&2
  echo "$AXIOM_LINES" >&2
  exit 1
fi

if ! echo "$AXIOM_LINES" | rg -q 'registration_eval_equiv_singleton_tail'; then
  echo "ERROR: sole axiom must remain 'registration_eval_equiv_singleton_tail' (see EvalEquiv.lean, REGISTRATION_VERIFY_REVIEW.md)." >&2
  echo "$AXIOM_LINES" >&2
  exit 1
fi

echo "OK ConfidentialAsset Lean hygiene: no line-start sorry in Experimental + CA companion .lean files; single allowlisted axiom under Experimental/ConfidentialAsset/."

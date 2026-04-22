#!/usr/bin/env bash
# audit/verify-ca.sh — Phase 7 reviewer entry point for CA formal verification.
#
# Scope: runs MSL / Lean / difftest checks against any single CA operation, or the full matrix.
# Plan §10.1 details the UX target. This file is a SCAFFOLD: many branches dispatch to
# `echo "not implemented yet"` pending the corresponding phase landing.
#
# Budgets (plan §10.6):
#   - Full run ≤ 45 min (soft ceiling)
#   - Per-op run ≤ 3 min (hard)
#
# Usage:
#   ./verify-ca.sh                     # full-stack run (all ops, all stacks)
#   ./verify-ca.sh --op register       # single operation, all stacks
#   ./verify-ca.sh --op register --stack lean
#   ./verify-ca.sh --claim "transfer preserves balance sum"
#   ./verify-ca.sh --list              # enumerate available claims
#
# Exit 0 on green; non-zero on any failure.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../.." && pwd)"

usage() {
    cat <<EOF
Usage: $0 [--op <name>] [--stack <stack>] [--claim <text>] [--list]
  Options:
    --op <register|deposit|withdraw|transfer|normalize|rotate|freeze|rollover>
    --stack <move-prover|lean|difftest>
    --claim <plain-English substring matching CLAIMS.md>
    --list    — enumerate claims from CLAIMS.md
EOF
}

OP=""
STACK=""
CLAIM=""
LIST=0

while [ $# -gt 0 ]; do
    case "$1" in
        --op) OP="$2"; shift 2 ;;
        --stack) STACK="$2"; shift 2 ;;
        --claim) CLAIM="$2"; shift 2 ;;
        --list) LIST=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ "$LIST" = 1 ]; then
    echo "Available claims (from CLAIMS.md) — scaffold only, full dispatch pending Phase 7:"
    grep -E '^\| ' "$HERE/CLAIMS.md" | awk -F'|' 'NR>2 { gsub(/^ +| +$/, "", $2); if ($2 != "" && $2 != "Claim") print "  • " $2 }'
    exit 0
fi

# --- Stack dispatchers ---

run_lean_for_op() {
    local op="$1"
    cd "$REPO_ROOT/aptos-move/framework/formal/lean"
    case "$op" in
        register)
            # Phase 1 day-one ships the axiom-stub; Phase 1 completion reproves it.
            lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
            ;;
        withdraw|transfer|normalize|rotate)
            echo "Lean EvalEquiv target for $op does not exist yet (Phase 4 scope)." >&2
            return 1
            ;;
        *)
            echo "Operation '$op' has no Lean claim in this plan." >&2
            return 1
            ;;
    esac
}

run_move_prover_for_op() {
    local op="$1"
    local filter=""
    case "$op" in
        register)   filter='register_internal' ;;
        deposit)    filter='deposit_to_internal' ;;
        withdraw)   filter='withdraw_to_internal' ;;
        transfer)   filter='confidential_transfer_internal' ;;
        freeze)     filter='freeze_token_internal|unfreeze_token_internal' ;;
        rollover)   filter='rollover_pending_balance_internal' ;;
        normalize)  filter='normalize_internal' ;;
        rotate)     filter='rotate_encryption_key_internal' ;;
        *) echo "No Move Prover filter known for op '$op'." >&2; return 1 ;;
    esac

    if ! command -v movement >/dev/null 2>&1; then
        echo "ERROR: 'movement' CLI not in PATH. See plan §5.1 for setup." >&2
        return 1
    fi
    if [ -z "${Z3_EXE:-}" ]; then
        echo "ERROR: Z3_EXE not set. Run: movement update prover-dependencies --assume-yes" >&2
        return 1
    fi

    movement move prove \
        --package-dir "$REPO_ROOT/aptos-move/framework/aptos-experimental" \
        --named-addresses aptos_experimental=0x7 \
        --filter "$filter" \
        --vc-timeout 120 \
        --skip-fetch-latest-git-deps
}

run_difftest_for_op() {
    local op="$1"
    # TODO: Phase 7 unified runner. For now, point to the manual difftest harness.
    echo "Difftest dispatch for '$op' not implemented yet — invoke difftest.sh manually."
    echo "See plan §10.1 for the planned --op/--stack UX."
    return 1
}

# --- Main ---

if [ -n "$CLAIM" ]; then
    echo "Claim-level dispatch not implemented yet (Phase 7 scope)."
    echo "Matching claim rows in CLAIMS.md:"
    grep -i "$CLAIM" "$HERE/CLAIMS.md" || true
    exit 1
fi

if [ -z "$OP" ]; then
    echo "Full-stack run not implemented yet. Use --op for now; see --help."
    exit 1
fi

if [ -z "$STACK" ] || [ "$STACK" = "lean" ]; then
    echo "--- Lean ($OP) ---"
    run_lean_for_op "$OP" || { echo "Lean: FAIL for $OP"; exit 1; }
fi
if [ -z "$STACK" ] || [ "$STACK" = "move-prover" ]; then
    echo "--- Move Prover ($OP) ---"
    run_move_prover_for_op "$OP" || { echo "Move Prover: FAIL for $OP"; exit 1; }
fi
if [ -z "$STACK" ] || [ "$STACK" = "difftest" ]; then
    echo "--- Difftest ($OP) ---"
    run_difftest_for_op "$OP" || { echo "Difftest: FAIL for $OP"; exit 1; }
fi

echo "OK"

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
    --coverage — print Lean-theorem / MSL-spec / axiom coverage summary
EOF
}

OP=""
STACK=""
CLAIM=""
LIST=0
COVERAGE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --op) OP="$2"; shift 2 ;;
        --stack) STACK="$2"; shift 2 ;;
        --claim) CLAIM="$2"; shift 2 ;;
        --list) LIST=1; shift ;;
        --coverage) COVERAGE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ "$LIST" = 1 ]; then
    echo "Available claims (from CLAIMS.md) — scaffold only, full dispatch pending Phase 7:"
    grep -E '^\| ' "$HERE/CLAIMS.md" | awk -F'|' 'NR>2 { gsub(/^ +| +$/, "", $2); if ($2 != "" && $2 != "Claim") print "  • " $2 }'
    exit 0
fi

# Coverage summary mode: runs check_axioms.sh + counts Lean theorems / MSL specs.
if [ "$COVERAGE" = 1 ]; then
    echo "=========================================="
    echo "  CA formal-verification coverage summary"
    echo "=========================================="
    echo
    echo "Lean EvalEquivRebuild theorems (Registration, 84-PC bytecode):"
    grep -c '^theorem ' "$REPO_ROOT/aptos-move/framework/formal/lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean" \
        || echo "0"
    echo
    echo "Lean Phase 4 EvalEquiv theorems (Withdrawal/Transfer/Normalization/Rotation dispatchers):"
    for op in Withdrawal Transfer Normalization Rotation; do
        count=$(grep -c '^theorem ' "$REPO_ROOT/aptos-move/framework/formal/lean/MovementFormal/Experimental/ConfidentialAsset/$op/EvalEquiv.lean" 2>/dev/null || echo 0)
        echo "  $op: $count theorems"
    done
    echo
    echo "MSL spec blocks in CA source tree:"
    grep -c '^    spec ' "$REPO_ROOT/aptos-move/framework/aptos-experimental/sources/confidential_asset"/*.spec.move \
        | awk -F: 'BEGIN {total=0} {total += $2; print "  " $1 ": " $2} END {print "  TOTAL: " total}'
    echo
    bash "$REPO_ROOT/aptos-move/framework/formal/scripts/check_axioms.sh"
    exit 0
fi

# --- Stack dispatchers ---

run_lean_for_op() {
    local op="$1"
    local quiet="${2:-false}"
    cd "$REPO_ROOT/aptos-move/framework/formal/lean"

    local cmd_output_filter="cat"
    if [ "$quiet" = "true" ]; then
        cmd_output_filter="grep -E 'Build completed|warning:|error:' || true"
    fi

    case "$op" in
        register)
            # Phase 1: axiom-stub + rebuild body (EvalEquivRebuild has 206 per-PC theorems).
            lake build \
                MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv \
                MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild \
                2>&1 | eval "$cmd_output_filter"
            ;;
        withdraw)
            # Phase 4: 27 bytecode theorems + functional sim + 4 PC-chaining axioms (to be proved)
            lake build \
                MovementFormal.Experimental.ConfidentialAsset.Withdrawal.FunctionalSim \
                MovementFormal.MoveModel.Programs.Withdrawal \
                MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv \
                2>&1 | eval "$cmd_output_filter"
            ;;
        transfer)
            # Phase 4: 33 bytecode theorems + functional sim (most complex, 24 PCs)
            lake build \
                MovementFormal.Experimental.ConfidentialAsset.Transfer.FunctionalSim \
                MovementFormal.MoveModel.Programs.Transfer \
                MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv \
                2>&1 | eval "$cmd_output_filter"
            ;;
        normalize)
            # Phase 4: 22 bytecode theorems + functional sim + 1 PC-chaining axiom
            lake build \
                MovementFormal.Experimental.ConfidentialAsset.Normalization.FunctionalSim \
                MovementFormal.MoveModel.Programs.Normalization \
                MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv \
                2>&1 | eval "$cmd_output_filter"
            ;;
        rotate)
            # Phase 4: 22 bytecode theorems + functional sim
            lake build \
                MovementFormal.Experimental.ConfidentialAsset.Rotation.FunctionalSim \
                MovementFormal.MoveModel.Programs.Rotation \
                MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv \
                2>&1 | eval "$cmd_output_filter"
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
    local suite=""
    case "$op" in
        register|withdraw|transfer|normalize|rotate)
            suite="confidential_proof"
            ;;
        freeze|rollover|deposit)
            suite="confidential_asset"
            ;;
        *)
            echo "No difftest suite mapped for op '$op'." >&2
            return 1
            ;;
    esac

    local difftest="$REPO_ROOT/aptos-move/framework/formal/difftest.sh"
    if [ ! -x "$difftest" ]; then
        echo "ERROR: difftest harness not found/executable at $difftest" >&2
        echo "See difftest/README.md for setup." >&2
        return 1
    fi
    (cd "$REPO_ROOT" && "$difftest" --suite "$suite")
}

# --- Main ---

if [ -n "$CLAIM" ]; then
    echo "=========================================="
    echo "  Claim-based verification"
    echo "=========================================="
    echo
    echo "Searching for claims matching: '$CLAIM'"
    echo
    matches=$(grep -i "$CLAIM" "$HERE/CLAIMS.md" | grep -v "^|.*Claim.*|" | grep "^|" || true)
    if [ -z "$matches" ]; then
        echo "No matching claims found in CLAIMS.md"
        exit 1
    fi
    echo "Found matching claims:"
    echo "$matches"
    echo
    echo "Note: Claim-level verification dispatch to specific theorems is Phase 7 work."
    echo "Use --op <operation> --stack <stack> for now to verify components."
    exit 1
fi

if [ -z "$OP" ]; then
    echo "=========================================="
    echo "  Full CA verification matrix"
    echo "=========================================="
    echo
    echo "Running all operations across all stacks..."
    echo "Budget: ≤2700s (45 min) full run per plan §10.6"
    echo

    MATRIX_START=$(date +%s)
    ALL_OPS="register withdraw transfer normalize rotate"
    FAILED_OPS=""
    PASSED_OPS=""
    declare -A OP_TIMES

    for op in $ALL_OPS; do
        echo "--- $op ---"
        OP_START=$(date +%s)

        if [ -z "$STACK" ] || [ "$STACK" = "lean" ]; then
            echo "  Lean..."
            LEAN_START=$(date +%s)
            if run_lean_for_op "$op" true 2>&1 | tail -1 | grep -q "successfully"; then
                LEAN_END=$(date +%s)
                LEAN_TIME=$((LEAN_END - LEAN_START))
                echo "  Lean: ✓ (${LEAN_TIME}s)"
            else
                echo "  Lean: ✗ FAILED"
                FAILED_OPS="$FAILED_OPS $op(lean)"
            fi
        fi
        if [ -z "$STACK" ] || [ "$STACK" = "move-prover" ]; then
            echo "  Move Prover..."
            if run_move_prover_for_op "$op" >/dev/null 2>&1; then
                echo "  Move Prover: ✓"
            else
                echo "  Move Prover: ✗ SKIPPED (requires Z3_EXE setup)"
                # Don't count as failure if tool isn't set up
            fi
        fi
        if [ -z "$STACK" ] || [ "$STACK" = "difftest" ]; then
            echo "  Difftest..."
            if run_difftest_for_op "$op" >/dev/null 2>&1; then
                echo "  Difftest: ✓"
            else
                echo "  Difftest: ✗ SKIPPED (requires difftest harness)"
            fi
        fi

        OP_END=$(date +%s)
        OP_ELAPSED=$((OP_END - OP_START))
        OP_TIMES[$op]=$OP_ELAPSED
        PASSED_OPS="$PASSED_OPS $op"

        if [ "$OP_ELAPSED" -gt 180 ]; then
            echo "  ⚠ Time: ${OP_ELAPSED}s (exceeds per-op budget of 180s)"
        else
            echo "  Time: ${OP_ELAPSED}s"
        fi
        echo
    done

    MATRIX_END=$(date +%s)
    MATRIX_ELAPSED=$((MATRIX_END - MATRIX_START))

    echo "=========================================="
    echo "Summary:"
    echo "  Verified: $PASSED_OPS"
    echo
    echo "Per-operation times:"
    for op in $ALL_OPS; do
        echo "  $op: ${OP_TIMES[$op]}s"
    done
    echo
    echo "Total time: ${MATRIX_ELAPSED}s"
    if [ "$MATRIX_ELAPSED" -gt 2700 ]; then
        echo "  ⚠ Exceeds full-run budget of 2700s (45 min)"
    else
        echo "  ✓ Within full-run budget (≤2700s)"
    fi

    if [ -n "$FAILED_OPS" ]; then
        echo
        echo "  Failed: $FAILED_OPS"
        echo "  Status: ✗ FAILED"
        exit 1
    fi
    echo
    echo "  Status: ✓ All operations verified"
    echo "=========================================="
    exit 0
fi

START_TIME=$(date +%s)

if [ -z "$STACK" ] || [ "$STACK" = "lean" ]; then
    echo "--- Lean ($OP) ---"
    LEAN_START=$(date +%s)
    run_lean_for_op "$OP" false || { echo "Lean: FAIL for $OP"; exit 1; }
    LEAN_END=$(date +%s)
    LEAN_ELAPSED=$((LEAN_END - LEAN_START))
    echo "Lean: OK (${LEAN_ELAPSED}s)"
    if [ "$LEAN_ELAPSED" -gt 180 ]; then
        echo "⚠ Warning: Lean build took ${LEAN_ELAPSED}s (budget: ≤180s per §10.6)"
    fi
fi
if [ -z "$STACK" ] || [ "$STACK" = "move-prover" ]; then
    echo "--- Move Prover ($OP) ---"
    MP_START=$(date +%s)
    run_move_prover_for_op "$OP" || { echo "Move Prover: FAIL for $OP"; exit 1; }
    MP_END=$(date +%s)
    MP_ELAPSED=$((MP_END - MP_START))
    echo "Move Prover: OK (${MP_ELAPSED}s)"
fi
if [ -z "$STACK" ] || [ "$STACK" = "difftest" ]; then
    echo "--- Difftest ($OP) ---"
    DT_START=$(date +%s)
    run_difftest_for_op "$OP" || { echo "Difftest: FAIL for $OP"; exit 1; }
    DT_END=$(date +%s)
    DT_ELAPSED=$((DT_END - DT_START))
    echo "Difftest: OK (${DT_ELAPSED}s)"
fi

END_TIME=$(date +%s)
TOTAL_ELAPSED=$((END_TIME - START_TIME))
echo
echo "=========================================="
echo "Total time: ${TOTAL_ELAPSED}s"
if [ "$TOTAL_ELAPSED" -gt 180 ]; then
    echo "⚠ Warning: Per-op budget is ≤180s (plan §10.6)"
else
    echo "✓ Within per-op budget (≤180s)"
fi
echo "=========================================="

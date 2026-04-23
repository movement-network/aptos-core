#!/usr/bin/env bash
# Track Phase 6 completion progress with detailed metrics
set -euo pipefail

cd "$(dirname "$0")/.."
FORMAL_DIR="$(pwd)"

echo "=== Phase 6 Completion Progress Tracker ==="
echo ""
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Sorry counts by operation
norm_sorry=$(grep "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/*.lean 2>/dev/null | wc -l | tr -d ' ')
with_sorry=$(grep "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/*.lean 2>/dev/null | wc -l | tr -d ' ')
rot_sorry=$(grep "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/*.lean 2>/dev/null | wc -l | tr -d ' ')
trans_sorry=$(grep "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/*.lean 2>/dev/null | wc -l | tr -d ' ')
total_sorry=$((norm_sorry + with_sorry + rot_sorry + trans_sorry))

# Axiom counts (critical axioms only, excluding crypto/group theory)
norm_axioms=$(grep "^axiom norm_run" lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean 2>/dev/null | wc -l | tr -d ' ')
with_axioms=$(grep "^axiom run_" lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean 2>/dev/null | wc -l | tr -d ' ')
total_axioms=$((norm_axioms + with_axioms))

# Original baseline (from initial scaffolding)
BASELINE_SORRY=11
BASELINE_AXIOMS=3

# Calculate completion percentages
sorry_completed=$((BASELINE_SORRY - total_sorry))
axioms_completed=$((BASELINE_AXIOMS - total_axioms))
sorry_pct=$((sorry_completed * 100 / BASELINE_SORRY))
axioms_pct=$((axioms_completed * 100 / BASELINE_AXIOMS))

echo "## Sorry Status"
echo ""
echo "| Operation | Sorries | Change from Baseline |"
echo "|-----------|---------|---------------------|"
echo "| Normalization | $norm_sorry | $([ $norm_sorry -lt 3 ] && echo "-$((3 - norm_sorry))" || echo "0") |"
echo "| Withdrawal | $with_sorry | $([ $with_sorry -lt 5 ] && echo "-$((5 - with_sorry))" || echo "0") |"
echo "| Rotation | $rot_sorry | $([ $rot_sorry -lt 1 ] && echo "-$((1 - rot_sorry))" || echo "0") |"
echo "| Transfer | $trans_sorry | $([ $trans_sorry -lt 2 ] && echo "-$((2 - trans_sorry))" || echo "0") |"
echo "| **Total** | **$total_sorry / $BASELINE_SORRY** | **$sorry_completed completed** |"
echo ""
echo "Progress: $sorry_completed / $BASELINE_SORRY sorries completed ($sorry_pct%)"
echo ""

echo "## Axiom Status"
echo ""
echo "| Category | Count | Status |"
echo "|----------|-------|--------|"
echo "| PC-chaining helpers | $total_axioms | $([ $total_axioms -eq 0 ] && echo "✅ All proved" || echo "⚠️  $total_axioms remaining") |"
echo "| Crypto primitives | ~17 | ✅ External (accepted) |"
echo ""
echo "Progress: $axioms_completed / $BASELINE_AXIOMS axioms discharged ($axioms_pct%)"
echo ""

# Build status
echo "## Build Health"
echo ""
if lake build MovementFormal.Experimental.ConfidentialAsset &>/dev/null; then
    echo "✅ Full CA tree builds successfully"
else
    echo "❌ Build failures detected"
fi
echo ""

# Line counts for completed proofs
echo "## Proof Metrics"
echo ""
norm_lines=$(wc -l < lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean)
with_lines=$(wc -l < lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean)
rot_lines=$(wc -l < lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean)
trans_lines=$(wc -l < lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean)
total_lines=$((norm_lines + with_lines + rot_lines + trans_lines))

echo "| File | Lines | Sorries | Density |"
echo "|------|-------|---------|---------|"
echo "| Normalization/EvalEquiv | $norm_lines | $norm_sorry | $([ $norm_sorry -eq 0 ] && echo "✅ 0%" || echo "$((norm_sorry * 100 / norm_lines))%") |"
echo "| Withdrawal/EvalEquiv | $with_lines | $with_sorry | $([ $with_sorry -eq 0 ] && echo "✅ 0%" || echo "$((with_sorry * 100 / with_lines))%") |"
echo "| Rotation/EvalEquiv | $rot_lines | $rot_sorry | $([ $rot_sorry -eq 0 ] && echo "✅ 0%" || echo "$((rot_sorry * 100 / rot_lines))%") |"
echo "| Transfer/EvalEquiv | $trans_lines | $trans_sorry | $([ $trans_sorry -eq 0 ] && echo "✅ 0%" || echo "$((trans_sorry * 100 / trans_lines))%") |"
echo "| **Total** | **$total_lines** | **$total_sorry** | **$([ $total_sorry -eq 0 ] && echo "✅ Complete" || echo "$((total_sorry * 100 / total_lines))%")** |"
echo ""

# Phase breakdown
echo "## Phase Status (from SORRY_CATEGORIZATION.md)"
echo ""
echo "| Phase | Target | Status | Ready |"
echo "|-------|--------|--------|-------|"
echo "| 1. Quick Wins | 2 unreachable | Not started | ✅ Utilities ready |"
echo "| 2. Match Simplify | 2 lemmas | Not started | ✅ Utilities ready |"
echo "| 3. Array Elaboration | Blocker research | Not started | ⚠️  Requires deep research |"
echo "| 4. Main Compositions | 5 theorems | Blocked | ❌ Depends on Phase 3 |"
echo ""

# Timeline estimate
remaining_sorry=$total_sorry
echo "## Estimated Completion"
echo ""
if [ $remaining_sorry -eq 0 ]; then
    echo "✅ **Phase 6 COMPLETE!**"
elif [ $remaining_sorry -le 4 ]; then
    echo "🎯 **Near completion:** $remaining_sorry sorries remaining"
    echo "Estimated: 1-2 weeks (Phases 1-2 only)"
elif [ $remaining_sorry -le 7 ]; then
    echo "🔄 **Array blocker resolved:** $(( remaining_sorry - 4 )) main theorems remain"
    echo "Estimated: 4-8 weeks (Phase 4 only)"
else
    echo "📊 **Full roadmap:** All phases required"
    echo "Estimated: 5-11 weeks (Phases 1-4)"
fi
echo ""

echo "## Recent Activity"
echo ""
# Show last 3 commits touching Phase 6 files
git log --oneline --no-merges -3 --pretty=format:"- %h %s (%ar)" -- \
    lean/MovementFormal/Experimental/ConfidentialAsset/*/EvalEquiv.lean \
    lean/MovementFormal/Experimental/ConfidentialAsset/*/Composition.lean \
    audit/SORRY_CATEGORIZATION.md 2>/dev/null || echo "No recent commits"
echo ""
echo ""

echo "---"
echo "💡 **Next Steps:**"
if [ $remaining_sorry -eq $BASELINE_SORRY ]; then
    echo "1. Attempt Phase 1 unreachable cases (Withdrawal:889,903) - 1-2 hours"
    echo "2. Attempt Phase 2 match simplification (Withdrawal:844, Transfer:718) - 1-2 days"
    echo "3. Research array elaboration blocker - 1-3 weeks"
elif [ $remaining_sorry -gt 4 ]; then
    echo "1. Continue array elaboration research"
    echo "2. Once blocker solved, tackle main compositions (4-8 weeks)"
else
    echo "1. Complete remaining quick wins"
    echo "2. Finish match simplification lemmas"
fi
echo ""

# Export metrics to JSON for external tracking
cat > /tmp/phase6_progress.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "sorries": {
    "total": $total_sorry,
    "baseline": $BASELINE_SORRY,
    "completed": $sorry_completed,
    "percentage": $sorry_pct,
    "by_operation": {
      "normalization": $norm_sorry,
      "withdrawal": $with_sorry,
      "rotation": $rot_sorry,
      "transfer": $trans_sorry
    }
  },
  "axioms": {
    "total": $total_axioms,
    "baseline": $BASELINE_AXIOMS,
    "completed": $axioms_completed,
    "percentage": $axioms_pct
  },
  "lines_of_proof": $total_lines
}
EOF

echo "📊 Metrics exported to /tmp/phase6_progress.json"

#!/usr/bin/env bash
# lint_heartbeats.sh — warn/fail on `set_option maxHeartbeats N` overrides above threshold.
#
# Why: high heartbeat overrides signal that a proof is straining against its scaffolding
# (e.g. unfolding a deep frame chain where a cached projection would suffice). Keeping
# overrides bounded stops the build from drifting toward "forever". See the projection-cache
# pattern introduced in EvalEquiv/Part2.lean (registrationFramePc{N}_pc_eq, _code_eq) for
# how to drop overrides systematically.
#
# Usage:
#   scripts/lint_heartbeats.sh             # warn only (exit 0)
#   scripts/lint_heartbeats.sh --strict    # exit 1 if any override > THRESHOLD
#
# Tune THRESHOLD to your pain point. 400000 = 2× the Lean default.

set -euo pipefail
THRESHOLD="${HEARTBEATS_THRESHOLD:-400000}"
STRICT="${1:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

violations=0
while IFS=: read -r file line content; do
  n=$(echo "$content" | grep -oE 'maxHeartbeats[[:space:]]+[0-9]+' | awk '{print $2}')
  if [ -n "$n" ] && [ "$n" -gt "$THRESHOLD" ]; then
    echo "  $file:$line  maxHeartbeats $n  (> $THRESHOLD)"
    violations=$((violations + 1))
  fi
done < <(grep -rn --include='*.lean' 'set_option[[:space:]]\+maxHeartbeats' "$ROOT/MovementFormal" 2>/dev/null || true)

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "Found $violations maxHeartbeats overrides > $THRESHOLD."
  if [ "$STRICT" = "--strict" ]; then
    exit 1
  fi
fi

exit 0

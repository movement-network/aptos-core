#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "=== Testing Nix Builds on $(uname -m)/$(uname -s) ==="
FAILURES=0
BINARIES=(aptos-node movement l1-migration aptos-faucet-service aptos-transaction-emitter)

for binary in "${BINARIES[@]}"; do
  echo "--- Building $binary ---"
  if nix build ".#$binary" -L; then
    BIN="result/bin/$binary"
    if [ -f "$BIN" ]; then
      VERSION=$("$BIN" --version 2>&1 || true)
      echo "  $binary: $VERSION"
      [ -n "$VERSION" ] || { echo "  WARN: empty version"; FAILURES=$((FAILURES + 1)); }
    else
      echo "  ERROR: $BIN not found"; FAILURES=$((FAILURES + 1))
    fi
  else
    echo "  ERROR: build failed"; FAILURES=$((FAILURES + 1))
  fi
done

echo "--- Building all-binaries ---"
if nix build .#all-binaries -L; then
  for binary in "${BINARIES[@]}"; do
    [ -f "result/bin/$binary" ] || { echo "MISSING: $binary"; FAILURES=$((FAILURES + 1)); }
  done
else
  echo "ERROR: all-binaries build failed"; FAILURES=$((FAILURES + 1))
fi

echo ""
[ "$FAILURES" -eq 0 ] && echo "All tests PASSED" || { echo "$FAILURES test(s) FAILED"; exit 1; }

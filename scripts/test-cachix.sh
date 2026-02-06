#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

CACHE="movement-m1"
BINARIES=(aptos-node movement l1-migration aptos-faucet-service aptos-transaction-emitter)

echo "=== Testing Cachix Push for $CACHE ==="
command -v cachix &>/dev/null || { echo "ERROR: cachix not installed. Run: just setup-cachix"; exit 1; }

for binary in "${BINARIES[@]}"; do
  echo "--- $binary ---"
  nix build ".#$binary" -L
  STORE_PATH=$(readlink -f result)
  HASH=$(basename "$STORE_PATH" | cut -d- -f1)
  cachix push "$CACHE" result
  if curl -sf "https://${CACHE}.cachix.org/${HASH}.narinfo" >/dev/null 2>&1; then
    echo "  Verified in cache"
  else
    echo "  WARN: narinfo not yet visible (may propagate)"
  fi
done
echo "=== Done ==="

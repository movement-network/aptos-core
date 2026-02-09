#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
TAG="${1:-$(git rev-parse --short HEAD)}"
echo "=== E2E Test: Build -> Push -> Validate on K8s ==="
echo "1. Building Docker image..."
just container-buildx aptos-node "$TAG"
echo "2. Pushing to GHCR..."
docker push "ghcr.io/movementlabsxyz/aptos-node:$TAG"
echo "3. Setting up K8s namespace..."
just k8s-setup
echo "4. Submitting K8s validation job..."
just k8s-test-docker "$TAG"
echo ""
echo "Monitor: just k8s-test-logs"
echo "Status:  just k8s-test-status"

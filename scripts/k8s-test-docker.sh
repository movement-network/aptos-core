#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
K8S_CONTEXT="${K8S_CONTEXT:-devNet}"
K8S_NAMESPACE="${K8S_NAMESPACE:-nix-build-test}"
TAG="${1:-$(git rev-parse --short HEAD)}"
echo "Testing ghcr.io/movementlabsxyz/aptos-node:$TAG on K8s amd64..."
kubectl --context "$K8S_CONTEXT" -n "$K8S_NAMESPACE" delete job test-docker-image --ignore-not-found=true
sed "s/IMAGE_TAG/$TAG/g" k8s/test-docker-image-job.yaml | \
    kubectl --context "$K8S_CONTEXT" -n "$K8S_NAMESPACE" apply -f -
echo "Job submitted. Run: just k8s-test-logs"

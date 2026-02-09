#!/usr/bin/env bash
set -euo pipefail
K8S_CONTEXT="${K8S_CONTEXT:-devNet}"
K8S_NAMESPACE="${K8S_NAMESPACE:-nix-build-test}"
echo "K8s Test Jobs (namespace: $K8S_NAMESPACE)"
echo "============================================="
kubectl --context "$K8S_CONTEXT" -n "$K8S_NAMESPACE" get jobs,pods -o wide 2>/dev/null || echo "No resources found."

#!/usr/bin/env bash
set -euo pipefail
K8S_CONTEXT="${K8S_CONTEXT:-devNet}"
K8S_NAMESPACE="${K8S_NAMESPACE:-nix-build-test}"
kubectl --context "$K8S_CONTEXT" -n "$K8S_NAMESPACE" delete jobs --all

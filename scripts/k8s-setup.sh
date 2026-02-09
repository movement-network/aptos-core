#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
K8S_CONTEXT="${K8S_CONTEXT:-devNet}"
kubectl --context "$K8S_CONTEXT" apply -f k8s/namespace.yaml

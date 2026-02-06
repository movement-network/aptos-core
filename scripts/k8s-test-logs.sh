#!/usr/bin/env bash
set -euo pipefail
K8S_CONTEXT="${K8S_CONTEXT:-devNet}"
K8S_NAMESPACE="${K8S_NAMESPACE:-nix-build-test}"
JOB="${1:-test-docker-image}"
kubectl --context "$K8S_CONTEXT" -n "$K8S_NAMESPACE" logs -f "job/$JOB" 2>/dev/null || \
    { echo "Job not ready. Waiting..." && sleep 5 && \
      kubectl --context "$K8S_CONTEXT" -n "$K8S_NAMESPACE" logs -f "job/$JOB"; }

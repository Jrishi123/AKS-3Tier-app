#!/usr/bin/env bash
set -euo pipefail

helm dependency build
helm lint .
helm template myapp . --namespace app >/tmp/aks-3tier-rendered.yaml

echo "Valid render: /tmp/aks-3tier-rendered.yaml"

if helm template myapp . --set api.enabled=yes >/tmp/invalid.yaml 2>/tmp/invalid.err; then
  echo "ERROR: schema test unexpectedly passed"
  exit 1
fi

echo "Schema type test passed: invalid boolean rejected."

#!/usr/bin/env bash
set -euo pipefail

: "${ACR_NAME:?Set ACR_NAME}"

LOGIN_SERVER="$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)"

az acr login --name "$ACR_NAME"

docker build -t "${LOGIN_SERVER}/aks-3tier-api:1.0.0" app/api
docker push "${LOGIN_SERVER}/aks-3tier-api:1.0.0"

docker build -t "${LOGIN_SERVER}/aks-3tier-frontend:1.0.0" app/frontend
docker push "${LOGIN_SERVER}/aks-3tier-frontend:1.0.0"

echo "LOGIN_SERVER=$LOGIN_SERVER"

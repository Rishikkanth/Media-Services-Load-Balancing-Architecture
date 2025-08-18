#!/usr/bin/env bash
set -euo pipefail

NODE_ID="${HOSTNAME:-$(uuidgen)}"
PATH_ASSIGNMENT="${PATH_ASSIGNMENT:-/media/1}" # injected by allocator, env or sidecar
REGISTRY_TABLE="${REGISTRY_TABLE}"

# 1) Write registry state
aws dynamodb put-item --table-name "$REGISTRY_TABLE" --item \
  "{\"node_id\":{\"S\":\"$NODE_ID\"},\"path\":{\"S\":\"$PATH_ASSIGNMENT\"},\"status\":{\"S\":\"ACTIVE\"},\"active_connections\":{\"N\":\"0\"}}"

# 2) (Optional) call a lightweight webhook to adjust ALB weights if needed
if [[ -n "${REGISTRY_WEBHOOK:-}" ]]; then
  curl -fsS -X POST "$REGISTRY_WEBHOOK/register" -d "{\"node_id\":\"$NODE_ID\",\"path\":\"$PATH_ASSIGNMENT\"}"
fi

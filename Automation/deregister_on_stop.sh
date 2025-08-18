#!/usr/bin/env bash
set -euo pipefail
aws dynamodb update-item \
  --table-name "$REGISTRY_TABLE" \
  --key "{\"node_id\":{\"S\":\"$HOSTNAME\"}}" \
  --update-expression "SET #s = :d" \
  --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":d":{"S":"DRAINING"}}'
# Actual drain is handled by Lambda drain controller.


#!/usr/bin/env bash
# Wait for the vLLM health endpoint to come up, with a timeout.
# Ensures the systemd unit doesn't report "active" while the model is
# still loading (first start downloads ~16 GB of weights).
set -euo pipefail

URL="${1:-http://127.0.0.1:8000/health}"
TIMEOUT="${2:-900}"
INTERVAL="${3:-5}"

elapsed=0
while (( elapsed < TIMEOUT )); do
  if curl -fsS --max-time 5 "${URL}" >/dev/null 2>&1; then
    echo "vLLM healthy: ${URL}"
    exit 0
  fi
  sleep "${INTERVAL}"
  elapsed=$(( elapsed + INTERVAL ))
done

echo "ERROR: vLLM did not become healthy at ${URL} within ${TIMEOUT}s" >&2
exit 1

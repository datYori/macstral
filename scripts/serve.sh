#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

port="${1:-$MACSTRAL_PORT_DEFAULT}"

# If already serving, nothing to do.
if curl -fsS --max-time 5 "http://localhost:${port}/api/version" >/dev/null 2>&1; then
  log "ollama already serving on :${port}"
  exit 0
fi

log "starting ollama on :${port} (keep_alive=${MACSTRAL_KEEP_ALIVE})"
# Note: to change the port, set OLLAMA_HOST=localhost:<port> before running ollama serve.
exec env OLLAMA_KEEP_ALIVE="$MACSTRAL_KEEP_ALIVE" ollama serve

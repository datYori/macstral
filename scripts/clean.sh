#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

bash scripts/down.sh || true
rm -rf .macstral

if [ "${1:-}" = "--models" ]; then
  if ollama list | awk '{print $1}' | grep -qx "${MACSTRAL_OLLAMA_MODEL}"; then
    log "removing ollama model '${MACSTRAL_OLLAMA_MODEL}'"
    ollama rm "$MACSTRAL_OLLAMA_MODEL"
  else
    log "ollama model '${MACSTRAL_OLLAMA_MODEL}' not found; skipping."
  fi
fi
log "clean done."

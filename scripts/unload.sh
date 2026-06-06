#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

port="${1:-$MACSTRAL_PORT_DEFAULT}"

# Free the model from memory now (frees the VRAM the keep_alive timer was holding).
# Keeps the model on disk and leaves the Ollama daemon running; next use reloads it.
if ollama stop "$MACSTRAL_OLLAMA_MODEL" 2>/dev/null; then
  log "unloaded ${MACSTRAL_OLLAMA_MODEL} from memory"
else
  # Fallback if 'ollama stop' is unavailable: ask the daemon to evict via keep_alive=0.
  if curl -fsS --max-time 30 "http://localhost:${port}/api/chat" \
       -H 'Content-Type: application/json' \
       -d "{\"model\":\"${MACSTRAL_OLLAMA_MODEL}\",\"keep_alive\":0}" >/dev/null 2>&1; then
    log "unloaded ${MACSTRAL_OLLAMA_MODEL} (keep_alive=0)"
  else
    err "could not unload; is the Ollama daemon up on :${port}?"
    exit 1
  fi
fi

ollama ps

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

port="${1:-$MACSTRAL_PORT_DEFAULT}"
mkdir -p .macstral

# Write vibe config.
bash scripts/write-vibe-config.sh ollama "$port"

# Ensure daemon is up.
daemon_started=0
if ! curl -fsS --max-time 5 "http://localhost:${port}/api/version" >/dev/null 2>&1; then
  log "ollama daemon not running; starting it..."
  nohup ollama serve > .macstral/server.log 2>&1 &
  echo $! > .macstral/server.pid
  daemon_started=1
  log "waiting for ollama on :${port}..."
  for _ in $(seq 1 60); do
    if curl -fsS --max-time 2 "http://localhost:${port}/api/version" >/dev/null 2>&1; then break; fi
    sleep 1
  done
  if ! curl -fsS --max-time 5 "http://localhost:${port}/api/version" >/dev/null 2>&1; then
    err "ollama did not come up; see .macstral/server.log"
    exit 1
  fi
fi

if [ "$daemon_started" -eq 0 ]; then
  log "ollama already up on :${port} (app daemon; 'just down' will not stop it)"
fi

# Warm the model with a tiny request (non-fatal if it fails).
log "warming model ${MACSTRAL_OLLAMA_MODEL}..."
curl -fsS --max-time 60 "http://localhost:${port}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"${MACSTRAL_OLLAMA_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" \
  >/dev/null 2>&1 || log "  (warm-up request failed; model will load on first use)"

log "launching vibe..."
exec vibe

#!/usr/bin/env bash
set -euo pipefail
# Capture the caller's directory BEFORE we cd into the repo. This is the project
# Vibe will open in (and prewarm for), so the prefill and the session always match.
invocation_dir="$(pwd)"
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

dir="${1:-$invocation_dir}"
port="${2:-$MACSTRAL_PORT_DEFAULT}"
[ -d "$dir" ] || { err "workdir not found: $dir"; exit 1; }
mkdir -p .macstral

# Write vibe config.
bash scripts/write-vibe-config.sh ollama "$port"

# Ensure the Ollama daemon is up.
daemon_started=0
if ! curl -fsS --max-time 5 "http://localhost:${port}/api/version" >/dev/null 2>&1; then
  log "ollama daemon not running; starting it..."
  nohup env OLLAMA_KEEP_ALIVE="$MACSTRAL_KEEP_ALIVE" ollama serve > .macstral/server.log 2>&1 &
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

# Prewarm: load the model AND prefill Vibe's full system prompt FOR THIS workdir,
# so the interactive first turn reuses Ollama's cached prefix (seconds, not ~90s).
# Because we prefill and launch in the same dir, the cached prefix always matches.
log "prewarming Devstral and caching Vibe's prompt for: ${dir}"
log "(one-time ~60-90s prefill on a cold model; Vibe opens ready when it finishes)"
( vibe -p "Reply with the single word READY." \
    --workdir "$dir" --trust --max-turns 1 --output text >/dev/null 2>&1 ) &
pf=$!
secs=0
while kill -0 "$pf" 2>/dev/null; do
  printf '\r  prewarming... %3ds' "$secs"
  secs=$((secs + 1))
  sleep 1
done
if wait "$pf"; then
  printf '\r  prewarm complete in %ds; first turn will be fast.   \n' "$secs"
else
  printf '\r  prewarm did not finish cleanly; Vibe will prefill on first turn.\n'
fi

log "launching vibe in ${dir}..."
exec vibe --workdir "$dir"

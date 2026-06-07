#!/usr/bin/env bash
set -euo pipefail
# Capture the caller's directory BEFORE we cd into the repo. This is the project
# Vibe will open in (and prewarm for), so the prefill and the session always match.
invocation_dir="$(pwd)"
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

dir="${1:-$invocation_dir}"
port="${2:-$MACSTRAL_PORT_DEFAULT}"   # Ollama daemon port
proxy_port="$MACSTRAL_PROXY_PORT"     # port Vibe talks to (normalize-proxy)
[ -d "$dir" ] || { err "workdir not found: $dir"; exit 1; }
command -v uv >/dev/null 2>&1 || { err "uv not found (needed for the normalize-proxy); install from https://docs.astral.sh/uv/"; exit 1; }
mkdir -p .macstral

# Ensure the Ollama daemon is up (on $port).
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

# Start the normalize-proxy: vibe -> :proxy_port -> ollama :port. It repairs
# message-role alternation so Devstral's template stops 500ing on consecutive
# user messages (mistral-vibe#255; see scripts/normalize.py). Left running until
# 'just down'.
if curl -fsS --max-time 2 "http://localhost:${proxy_port}/api/version" >/dev/null 2>&1; then
  log "normalize-proxy already up on :${proxy_port}"
else
  log "starting normalize-proxy on :${proxy_port} -> :${port}..."
  LISTEN_PORT="$proxy_port" OLLAMA_PORT="$port" \
    nohup uv run scripts/normalize-proxy.py > .macstral/proxy.log 2>&1 &
  echo $! > .macstral/proxy.pid
  for _ in $(seq 1 30); do
    if curl -fsS --max-time 2 "http://localhost:${proxy_port}/api/version" >/dev/null 2>&1; then break; fi
    sleep 1
  done
  if ! curl -fsS --max-time 2 "http://localhost:${proxy_port}/api/version" >/dev/null 2>&1; then
    err "normalize-proxy did not come up; see .macstral/proxy.log"
    exit 1
  fi
fi

# Write vibe config pointing at the proxy (not Ollama directly).
bash scripts/write-vibe-config.sh ollama "$proxy_port"

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

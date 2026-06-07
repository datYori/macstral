#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

# Stop the normalize-proxy first (started by 'just up').
proxy_pidfile=".macstral/proxy.pid"
if [ -f "$proxy_pidfile" ]; then
  ppid="$(cat "$proxy_pidfile")"
  if kill "$ppid" 2>/dev/null; then log "stopped normalize-proxy (PID ${ppid})."; fi
  rm -f "$proxy_pidfile"
fi
# Sweep any stray listener (uv spawns a child python that can outlive its parent).
if pkill -f 'scripts/normalize-proxy.py' 2>/dev/null; then
  log "swept stray normalize-proxy process(es)."
fi

pidfile=".macstral/server.pid"
if [ ! -f "$pidfile" ]; then
  log "no server pid file; the Ollama app daemon (if running) is left untouched."
  exit 0
fi
pid="$(cat "$pidfile")"
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"; log "stopped ollama daemon (PID ${pid})."
else
  log "daemon (PID ${pid}) not running."
fi
rm -f "$pidfile"

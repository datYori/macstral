#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

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

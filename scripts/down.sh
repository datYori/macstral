#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

pidfile=".macstral/server.pid"
[ -f "$pidfile" ] || { log "no server pid file; nothing to stop."; exit 0; }
pid="$(cat "$pidfile")"
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"; log "stopped server (PID ${pid})."
else
  log "server (PID ${pid}) not running."
fi
rm -f "$pidfile"

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

backend="${1:-mlx}"
port="${2:-$MACSTRAL_PORT_DEFAULT}"
mkdir -p .macstral

case "$backend" in
  mlx)      serve_script="scripts/serve.sh" ;;
  llamacpp) serve_script="scripts/serve-llamacpp.sh" ;;
  *) err "unknown backend '$backend' (mlx|llamacpp)"; exit 64 ;;
esac

log "writing vibe config (backend=${backend})"
bash scripts/write-vibe-config.sh "$backend" "$port"

log "starting ${backend} server in background on :${port}"
nohup bash "$serve_script" "$port" > .macstral/server.log 2>&1 &
echo $! > .macstral/server.pid

log "waiting for :${port} to accept connections..."
for _ in $(seq 1 60); do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then break; fi
  sleep 2
done
if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
  err "server did not come up; see .macstral/server.log"; exit 1
fi

log "server up. launching vibe (server keeps running; 'just down' to stop it)."
vibe

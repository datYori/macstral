#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

port="${1:-$MACSTRAL_PORT_DEFAULT}"

if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
  err "port ${port} already in use (PID $(lsof -tnP -iTCP:"$port" -sTCP:LISTEN | head -1))"
  exit 1
fi

log "serving ${MACSTRAL_MODEL_ID} via MLX on :${port}"
exec uv run mlx_lm.server --model "$MACSTRAL_MODEL_ID" --port "$port"

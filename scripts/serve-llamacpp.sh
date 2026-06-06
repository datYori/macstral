#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

port="${1:-$MACSTRAL_PORT_DEFAULT}"
ctx="${2:-16000}"

# VERIFIED in Step 1 — replace with the exact repo/file you confirmed:
GGUF_REPO="unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF"
GGUF_FILE="Devstral-Small-2-24B-Instruct-2512-Q4_K_M.gguf"

command -v llama-server >/dev/null 2>&1 || { log "installing llama.cpp via brew"; brew install llama.cpp; }

log "fetching GGUF ${GGUF_FILE} from ${GGUF_REPO}"
model_path="$(hf download "$GGUF_REPO" "$GGUF_FILE")" || {
  err "failed to fetch ${GGUF_FILE} from ${GGUF_REPO}; verify repo/file names"; exit 1; }

if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
  err "port ${port} already in use"; exit 1
fi

log "serving Devstral GGUF via llama.cpp on :${port} (ctx=${ctx}, tool calls via --jinja)"
exec llama-server -m "$model_path" --jinja -c "$ctx" --port "$port" -ngl 99 --alias devstral-local

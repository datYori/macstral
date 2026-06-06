#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

# Gate first (hard-fails on blockers; no prompt).
bash scripts/doctor.sh --check "$@"

# Require ollama on PATH.
if ! command -v ollama >/dev/null 2>&1; then
  err "ollama not found. Install the native macOS app from https://ollama.com/download (do not use brew)."
  exit 1
fi

# Ensure daemon is responding; start it if not.
if ! curl -fsS --max-time 5 "http://localhost:${MACSTRAL_PORT_DEFAULT}/api/version" >/dev/null 2>&1; then
  log "ollama daemon not responding; starting it..."
  nohup ollama serve >/dev/null 2>&1 &
  for _ in $(seq 1 20); do
    if curl -fsS --max-time 2 "http://localhost:${MACSTRAL_PORT_DEFAULT}/api/version" >/dev/null 2>&1; then break; fi
    sleep 1
  done
  if ! curl -fsS --max-time 5 "http://localhost:${MACSTRAL_PORT_DEFAULT}/api/version" >/dev/null 2>&1; then
    err "ollama daemon did not start; check 'ollama serve' manually."
    exit 1
  fi
fi
log "ollama daemon up at :${MACSTRAL_PORT_DEFAULT}"

# Download GGUF (~11.5 GB, cached after first run).
log "fetching GGUF: ${MACSTRAL_GGUF_REPO} / ${MACSTRAL_GGUF_FILE}"
gguf="$(hf download "$MACSTRAL_GGUF_REPO" "$MACSTRAL_GGUF_FILE")"
log "GGUF path: ${gguf}"

# Create Ollama model (skip if already present).
if ollama list | awk '{print $1}' | grep -qx "${MACSTRAL_OLLAMA_MODEL}"; then
  log "ollama model '${MACSTRAL_OLLAMA_MODEL}' already exists; skipping create."
else
  tmpfile="$(mktemp /tmp/Modelfile.XXXXXX)"
  printf 'FROM %s\nPARAMETER num_ctx %s\nPARAMETER temperature 0.2\n' \
    "$gguf" "$MACSTRAL_NUM_CTX" > "$tmpfile"
  log "creating ollama model '${MACSTRAL_OLLAMA_MODEL}'..."
  ollama create "$MACSTRAL_OLLAMA_MODEL" -f "$tmpfile"
  rm -f "$tmpfile"
fi

# Install Vibe if missing.
if command -v vibe >/dev/null 2>&1; then
  log "vibe already installed: $(command -v vibe)"
else
  log "installing Mistral Vibe..."
  curl -LsSf https://mistral.ai/vibe/install.sh | bash
fi

log "setup complete."
log "next: 'just up'"

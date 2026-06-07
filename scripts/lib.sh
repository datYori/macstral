#!/usr/bin/env bash
# Shared helpers for macstral. Source this file; do not execute it.

# shellcheck disable=SC2034
MACSTRAL_OLLAMA_MODEL="devstral-q3"
# shellcheck disable=SC2034
MACSTRAL_GGUF_REPO="unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF"
# shellcheck disable=SC2034
MACSTRAL_GGUF_FILE="Devstral-Small-2-24B-Instruct-2512-Q3_K_M.gguf"
# shellcheck disable=SC2034
MACSTRAL_NUM_CTX=16384
# shellcheck disable=SC2034
MACSTRAL_PORT_DEFAULT=11434
# Port for the normalize-proxy that Vibe talks to; it forwards to Ollama on
# MACSTRAL_PORT_DEFAULT and repairs message-role alternation (see
# scripts/normalize.py). Vibe's config points here, not at Ollama directly.
# shellcheck disable=SC2034
MACSTRAL_PROXY_PORT=11436
# How long Ollama keeps the model resident after a request (avoids cold reloads
# between Vibe turns). "30m", "1h", or "-1" to pin forever.
# shellcheck disable=SC2034
MACSTRAL_KEEP_ALIVE="30m"

log() { printf '%s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }

# Total unified memory in whole GB.
mac_ram_gb() {
  local bytes
  bytes=$(sysctl -n hw.memsize)
  printf '%s\n' "$(( bytes / 1024 / 1024 / 1024 ))"
}

# recommend_ctx <ram_gb> -> prints a tier word
# tiers: comfortable (>=24) | tight (>=16) | refused (<16)
recommend_ctx() {
  local ram="$1"
  if   [ "$ram" -ge 24 ]; then printf 'comfortable\n'
  elif [ "$ram" -ge 16 ]; then printf 'tight\n'
  else                         printf 'refused\n'
  fi
}

# require_tools <t1> <t2> ... -> non-zero if any missing (prints which).
require_tools() {
  local missing=0 t
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || { err "missing required tool: $t"; missing=1; }
  done
  return "$missing"
}

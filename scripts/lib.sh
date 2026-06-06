#!/usr/bin/env bash
# Shared helpers for macstral. Source this file; do not execute it.

# shellcheck disable=SC2034
MACSTRAL_MODEL_ID="mlx-community/Devstral-Small-2-24B-Instruct-2512-4bit"
# shellcheck disable=SC2034
MACSTRAL_PORT_DEFAULT=8080

log() { printf '%s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }

# Total unified memory in whole GB.
mac_ram_gb() {
  local bytes
  bytes=$(sysctl -n hw.memsize)
  printf '%s\n' "$(( bytes / 1024 / 1024 / 1024 ))"
}

# recommend_ctx <ram_gb> -> prints "<ctx> <tier>"
# tiers: comfortable (>=32) | ok-tight (>=24) | tight (>=16) | refused (<16)
recommend_ctx() {
  local ram="$1"
  if   [ "$ram" -ge 32 ]; then printf '32000 comfortable\n'
  elif [ "$ram" -ge 24 ]; then printf '16000 ok-tight\n'
  elif [ "$ram" -ge 16 ]; then printf '8000 tight\n'
  else                         printf '0 refused\n'
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

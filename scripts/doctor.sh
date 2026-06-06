#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

MIN_DISK_GB=20
mode="interactive"   # interactive | check
for arg in "$@"; do
  case "$arg" in
    --check) mode="check" ;;
    *) err "unknown arg: $arg"; exit 64 ;;
  esac
done

# --- hard blockers ---
[ "$(uname -s)" = "Darwin" ] || { err "macOS only (found $(uname -s))"; exit 1; }
[ "$(uname -m)" = "arm64" ]  || { err "Apple Silicon arm64 required (found $(uname -m))"; exit 1; }
require_tools just hf ollama || exit 1

avail_gb=$(df -g / | awk 'NR==2 {print $4}')
[ "$avail_gb" -ge "$MIN_DISK_GB" ] || { err "need >= ${MIN_DISK_GB} GB free on / (found ${avail_gb})"; exit 1; }

# --- tier ---
ram=$(mac_ram_gb)
tier=$(recommend_ctx "$ram")

log "macstral doctor"
log "  arch:   $(uname -m), macOS $(sw_vers -productVersion)"
log "  RAM:    ${ram} GB   disk free: ${avail_gb} GB"
log "  model:  Devstral Small 2 24B Q3_K_M via Ollama (~11.5 GB)"
log "  ctx:    ${MACSTRAL_NUM_CTX}"
log "  tier:   ${tier}"

case "$tier" in
  refused)
    err "RAM < 16 GB: Q3_K_M (~11.5 GB) cannot run reliably (adaptive model = roadmap)."
    exit 2 ;;
  tight)
    log "  note:   16-23 GB is tight but Q3 (~11.5 GB) fits at 16 GB borderline; proceed with care." ;;
  comfortable)
    log "  note:   raising GPU wired limit (docs/gpu-memory.md) helps on 24 GB but is optional for Q3." ;;
esac

if [ "$mode" = "interactive" ]; then
  printf 'Proceed with these settings? [y/N] '
  read -r reply
  case "$reply" in
    [yY]|[yY][eE][sS]) log "confirmed." ;;
    *) err "aborted by user."; exit 10 ;;
  esac
fi

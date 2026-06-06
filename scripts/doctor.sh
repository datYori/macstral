#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

MIN_DISK_GB=20
mode="interactive"   # interactive | check
force=0
for arg in "$@"; do
  case "$arg" in
    --check) mode="check" ;;
    --force) force=1 ;;
    *) err "unknown arg: $arg"; exit 64 ;;
  esac
done

# --- hard blockers ---
[ "$(uname -s)" = "Darwin" ] || { err "macOS only (found $(uname -s))"; exit 1; }
[ "$(uname -m)" = "arm64" ]  || { err "Apple Silicon arm64 required (found $(uname -m))"; exit 1; }
require_tools uv just hf || exit 1

avail_gb=$(df -g / | awk 'NR==2 {print $4}')
[ "$avail_gb" -ge "$MIN_DISK_GB" ] || { err "need >= ${MIN_DISK_GB} GB free on / (found ${avail_gb})"; exit 1; }

# --- tier ---
ram=$(mac_ram_gb)
read -r ctx tier <<EOF
$(recommend_ctx "$ram")
EOF

log "macstral doctor"
log "  arch:   $(uname -m), macOS $(sw_vers -productVersion)"
log "  RAM:    ${ram} GB   disk free: ${avail_gb} GB"
log "  model:  ${MACSTRAL_MODEL_ID} (~15 GB)"
log "  tier:   ${tier}"

case "$tier" in
  refused)
    err "RAM < 16 GB unsupported in v1 (adaptive model = roadmap)."
    exit 2 ;;
  tight)
    log "  note:   16-23 GB is unsupported for Q4 at usable context."
    if [ "$force" -ne 1 ]; then
      err "re-run with --force to proceed at reduced ctx=${ctx}."
      exit 3
    fi
    log "  --force: proceeding at ctx=${ctx}." ;;
  ok-tight)
    log "  note:   raise GPU wired limit for headroom -> docs/gpu-memory.md" ;;
esac

log "  ctx:    ${ctx}"

if [ "$mode" = "interactive" ]; then
  printf 'Proceed with these settings? [y/N] '
  read -r reply
  case "$reply" in
    [yY]|[yY][eE][sS]) log "confirmed." ;;
    *) err "aborted by user."; exit 10 ;;
  esac
fi

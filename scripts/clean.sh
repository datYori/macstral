#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

bash scripts/down.sh || true
if [ -d .venv ]; then rm -rf .venv; log "removed .venv"; fi
rm -rf .macstral

if [ "${1:-}" = "--models" ]; then
  log "removing model from HF cache: ${MACSTRAL_MODEL_ID}"
  hf cache delete "$MACSTRAL_MODEL_ID" 2>/dev/null || \
    log "could not auto-delete; run 'hf cache scan' / 'hf cache delete' manually."
fi
log "clean done."

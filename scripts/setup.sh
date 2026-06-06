#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

# Gate first (honors --force; hard-fails on blockers; no prompt).
bash scripts/doctor.sh --check "$@"

log "creating uv venv (python 3.12) -> .venv"
uv venv --python 3.12 .venv

log "installing mlx-lm into .venv"
uv pip install mlx-lm

log "installing Mistral Vibe"
if command -v vibe >/dev/null 2>&1; then
  log "vibe already installed: $(command -v vibe)"
else
  curl -LsSf https://mistral.ai/vibe/install.sh | bash
fi

log "downloading model: ${MACSTRAL_MODEL_ID} (~15 GB, one-time)"
hf download "$MACSTRAL_MODEL_ID"

log "setup complete."
log "next: 'just up' (serve + config + vibe), or 'just serve' then 'just config mlx' then 'just vibe'."

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

backend="${1:-ollama}"
port="${2:-$MACSTRAL_PORT_DEFAULT}"
tmpl="config/vibe.${backend}.toml.tmpl"
dest="${HOME}/.vibe/config.toml"

[ -f "$tmpl" ] || { err "no template for backend '$backend' ($tmpl)"; exit 1; }

mkdir -p "${HOME}/.vibe"

# Render to a temp file first so we can compare before touching the real config.
rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT
sed -e "s|__PORT__|${port}|g" -e "s|__MODEL_NAME__|${MACSTRAL_OLLAMA_MODEL}|g" "$tmpl" > "$rendered"

# Skip entirely if the existing config already matches (no backup churn on repeat runs).
if [ -f "$dest" ] && cmp -s "$rendered" "$dest"; then
  log "config unchanged: ${dest} (backend=${backend}, port=${port})"
  exit 0
fi

# Back up an existing, differing config before overwriting it.
if [ -f "$dest" ]; then
  n=1; while [ -f "${dest}.bak.${n}" ]; do n=$((n + 1)); done
  cp "$dest" "${dest}.bak.${n}"
  log "backed up existing config -> ${dest}.bak.${n}"
fi

cp "$rendered" "$dest"
log "wrote ${dest} (backend=${backend}, port=${port})"

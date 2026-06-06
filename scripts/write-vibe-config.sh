#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

backend="${1:-mlx}"
port="${2:-$MACSTRAL_PORT_DEFAULT}"
tmpl="config/vibe.${backend}.toml.tmpl"
dest="${HOME}/.vibe/config.toml"

[ -f "$tmpl" ] || { err "no template for backend '$backend' ($tmpl)"; exit 1; }

mkdir -p "${HOME}/.vibe"
if [ -f "$dest" ]; then
  n=1; while [ -f "${dest}.bak.${n}" ]; do n=$((n + 1)); done
  cp "$dest" "${dest}.bak.${n}"
  log "backed up existing config -> ${dest}.bak.${n}"
fi

sed -e "s|__PORT__|${port}|g" -e "s|__MODEL_ID__|${MACSTRAL_MODEL_ID}|g" "$tmpl" > "$dest"
log "wrote ${dest} (backend=${backend}, port=${port})"

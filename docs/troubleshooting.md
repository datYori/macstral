# Troubleshooting

## `just doctor` exits non-zero

- `macOS only` / `arm64 required`: macstral is Apple-Silicon-only.
- `missing required tool`: install it. `brew install just`, `brew install huggingface-cli` (provides `hf`), and install [Ollama](https://ollama.com/download) as the native macOS app (not brew).
- `need >= 20 GB free`: free disk space; the GGUF is ~11.5 GB.
- `RAM < 16 GB`: Q3_K_M requires at least 16 GB unified memory.

## Ollama daemon not responding

Run `ollama serve` manually in a terminal, or open the Ollama macOS app. Then re-run `just up`.

## Slow generation

Dense 24B at Q3 on M-series memory bandwidth is roughly 10-18 tok/s. Close memory-heavy apps. Raising the GPU cap (docs/gpu-memory.md) is optional but can help.

## First turn takes ~1 minute before any output

Expected. Vibe prefills its full system prompt (instructions, skills, working-directory context) before the first token; for the dense 24B at Q3 on an M4 Pro that prefill is about 50-60s. It then streams, and later turns reuse Ollama's prompt cache. Run Vibe in the specific project directory (not a large parent), trim unused skills, and keep the model warm (see the Performance section of the README; `just up` pins `keep_alive`). If `ollama ps` shows the model unloaded between turns, raise `MACSTRAL_KEEP_ALIVE` in `scripts/lib.sh` or `launchctl setenv OLLAMA_KEEP_ALIVE -1` for the Ollama app daemon.

## Out of memory / system stalls

Q3_K_M (~11.5 GB) is chosen to fit 24 GB. If you observe paging: close other apps, and consider raising the GPU wired limit (docs/gpu-memory.md). On 16 GB the model is borderline; 24 GB is the recommended minimum.

## Vibe ignores my config / uses the wrong model

The `~/.vibe/config.toml` path is what Vibe reads. If `active_model` or provider settings are silently ignored, check that the top-level scalars (`active_model`, `enable_telemetry`, `enable_auto_update`) appear BEFORE any `[[providers]]` or `[[models]]` array-of-tables. TOML nests later scalars into the last array entry rather than top-level, which causes Vibe to ignore them. `just config ollama` rewrites the file correctly from the template.

## Vibe still phones home

Confirm `enable_telemetry = false` and `enable_auto_update = false` in `~/.vibe/config.toml`. MCP servers and connectors reach external systems independently; disable them separately.

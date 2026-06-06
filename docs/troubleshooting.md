# Troubleshooting

## `just doctor` exits non-zero
- `macOS only` / `arm64 required`: macstral is Apple-Silicon-only.
- `missing required tool`: install it -- `brew install just`, `brew install huggingface-cli` (provides `hf`) or see the hf docs, and install `uv` from astral.sh.
- `need >= 20 GB free`: free disk space; the model is ~15 GB.
- `re-run with --force`: you have 16-23 GB; Q4 is tight. `just doctor --force` to proceed at reduced context.

## Vibe tool calls are unreliable / it won't edit files
MLX tool-calling is less robust than llama.cpp's grammar-constrained decoding. Switch to the fallback:
```bash
just down
just serve-llamacpp 8080 16000   # terminal A
just config llamacpp             # rewrites ~/.vibe/config.toml
just vibe                        # terminal B
```

## Slow generation
Dense 24B on M-series memory bandwidth is ~10-18 tok/s. Close memory-heavy apps, raise the GPU cap (docs/gpu-memory.md), keep context modest.

## Out of memory / system stalls
Lower context, ensure the GPU wired limit is <= 80 % of RAM, close other apps. On 24 GB keep context near 16k.

## Vibe still phones home
Confirm `enable_telemetry = false` and `enable_auto_update = false` in `~/.vibe/config.toml`. MCP servers / connectors reach external systems independently -- disable them separately.

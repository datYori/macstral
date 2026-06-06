# macstral

Run [Mistral Vibe](https://github.com/mistralai/mistral-vibe) fully locally on Apple Silicon, against **Devstral Small 2 24B (Q4)** served by **MLX-LM**. No code leaves your machine.

> Target: Apple Silicon Mac, 24 GB+ unified memory (32 GB+ comfortable). macOS only.

## Quickstart

```bash
just doctor     # check your Mac + confirm settings
just setup      # venv + mlx-lm + vibe + download model (~15 GB)
just up         # serve (MLX) + write config + launch vibe
```

## Prerequisites

- Apple Silicon Mac, macOS, 24 GB+ unified memory (32 GB+ comfortable)
- Xcode Command Line Tools (`xcode-select --install`)
- [`just`](https://just.systems): `brew install just`
- [`uv`](https://astral.sh/uv): install from astral.sh (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- [`hf`](https://github.com/huggingface/huggingface_hub) (Hugging Face CLI): `brew install huggingface-cli` or `pip install huggingface_hub[cli]`

`vibe` (Mistral Vibe) is installed automatically by `just setup` via `curl -LsSf https://mistral.ai/vibe/install.sh | bash`.

## How it works

`vibe` sends requests over an OpenAI-compatible HTTP API to `mlx_lm.server`, which runs Devstral-Small-2-24B-Instruct-2512-4bit (MLX) on-device. No inference leaves the machine.

## 24 GB Macs

The default Metal GPU wired cap leaves thin headroom for KV cache. See [docs/gpu-memory.md](docs/gpu-memory.md) for how to raise the limit to 18 GB via a LaunchDaemon (requires `sudo`, run manually).

## Switch to llama.cpp fallback

If Vibe tool calls are unreliable on MLX, switch to the llama.cpp backend:

```bash
just down
just serve-llamacpp   # terminal A
just config llamacpp  # rewrites ~/.vibe/config.toml
just vibe             # terminal B
```

See [docs/troubleshooting.md](docs/troubleshooting.md) for more.

## Verify it works

1. Run `just up` and wait for the server to start and Vibe to open.
2. In Vibe, point it at a scratch directory and ask it to create or edit a small file.
3. Confirm requests are handled locally: `tail -f .macstral/server.log` shows inference activity on the local server.

## License

Apache-2.0.

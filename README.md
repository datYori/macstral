# macstral

Run [Mistral Vibe](https://github.com/mistralai/mistral-vibe) fully locally on Apple Silicon, against **Devstral Small 2 24B Q3_K_M** served by **Ollama**. No code leaves your machine.

> Target: Apple Silicon Mac, 24 GB+ unified memory (16 GB tight but borderline). macOS only.

## Quickstart

```bash
just doctor    # check your Mac + confirm settings
just setup     # fetch GGUF (~11.5 GB), create devstral-q3 model, install Vibe
just up        # write config + ensure daemon up + launch vibe
```

## Prerequisites

- Apple Silicon Mac, macOS, 24 GB+ unified memory (16 GB borderline)
- Xcode Command Line Tools: `xcode-select --install`
- [`just`](https://just.systems): `brew install just`
- [`hf`](https://github.com/huggingface/huggingface_hub) (Hugging Face CLI): `brew install huggingface-cli` or `pip install 'huggingface_hub[cli]'`
- [Ollama](https://ollama.com/download): install the native macOS app (do **not** use brew)

`vibe` (Mistral Vibe) is installed automatically by `just setup`.

## How it works

```
vibe  --OpenAI-compatible HTTP-->  Ollama :11434  -->  devstral-q3 (Devstral Small 2 24B Q3_K_M, num_ctx 16384)
```

No inference leaves the machine. Vibe points at `http://localhost:11434/v1`. The model runs fully on-device via Ollama.

## 24 GB Macs

Q3_K_M (~11.5 GB) fits comfortably in 24 GB. Raising the Metal GPU wired cap is optional but can help with headroom. See [docs/gpu-memory.md](docs/gpu-memory.md).

## Performance

First turn is slow: Vibe prefills its whole system prompt (instructions, skills, and working-directory context, roughly 8-9k tokens) before the first token. On an M4 Pro that prefill is about 50-60s for the dense 24B at Q3; after that it streams (~10-18 tok/s), and follow-up turns reuse Ollama's prompt cache. To keep it snappy:

- Run Vibe inside the specific project directory, not a large parent like `~/perso`, so less working-directory context is loaded.
- Trim Vibe skills you do not need; fewer skills means a smaller prefill.
- Keep the model warm. `just serve` and `just up` start Ollama with `OLLAMA_KEEP_ALIVE` and pin the model so it does not cold-reload between turns. If you instead use the Ollama **app** daemon, set it yourself: `launchctl setenv OLLAMA_KEEP_ALIVE -1`, then restart Ollama. Tune the value via `MACSTRAL_KEEP_ALIVE` in `scripts/lib.sh`.
- Free the memory on demand. `just unload` releases the warm model from RAM/VRAM immediately (keeps it on disk, leaves the daemon running); the next use reloads it.

## Roadmap

MLX and llama.cpp backends are on the roadmap but not implemented in v1. The Ollama+Q3 path was chosen after MLX+Q4 OOM'd on 24 GB under Vibe's agentic context load and no prebuilt 3-bit MLX weights were available.

## Verify it works

1. Run `just up` and wait for Vibe to open.
2. Point Vibe at a scratch directory and ask it to create or edit a small file.
3. Confirm local inference: `ollama ps` shows `devstral-q3` loaded.

## Docs

- [docs/gpu-memory.md](docs/gpu-memory.md): raise the Metal wired limit on 24 GB Macs
- [docs/troubleshooting.md](docs/troubleshooting.md): common failures and fixes
- [docs/DESIGN.md](docs/DESIGN.md): architecture and design rationale

## License

Apache-2.0.

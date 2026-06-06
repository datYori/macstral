# macstral

Run [Mistral Vibe](https://github.com/mistralai/mistral-vibe) fully locally on Apple Silicon, against **Devstral Small 2 24B (Q4)** served by **MLX-LM**. No code leaves your machine.

> Target: Apple Silicon Mac, 24 GB+ unified memory (32 GB+ comfortable). macOS only.

## Quickstart

```bash
just doctor     # check your Mac + confirm settings
just setup      # venv + mlx-lm + vibe + download model (~15 GB)
just up         # serve (MLX) + write config + launch vibe
```

See [docs/gpu-memory.md](docs/gpu-memory.md) (24 GB Macs), [docs/troubleshooting.md](docs/troubleshooting.md), and [docs/DESIGN.md](docs/DESIGN.md).

## License

Apache-2.0.

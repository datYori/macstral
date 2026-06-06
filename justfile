# macstral: local Mistral Vibe + Devstral Q4 on Apple Silicon
set shell := ["bash", "-cu"]

# List recipes
default:
    @just --list

# Verify host + recommend settings (interactive confirm). Pass --force to override tight RAM.
doctor *ARGS:
    bash scripts/doctor.sh {{ARGS}}

# Install env, mlx-lm, Vibe, and download the model (~15 GB)
setup *ARGS:
    bash scripts/setup.sh {{ARGS}}

# Serve via MLX (primary). e.g. just serve 8080
serve PORT="8080":
    bash scripts/serve.sh {{PORT}}

# Serve via llama.cpp (fallback). e.g. just serve-llamacpp 8080 16000
serve-llamacpp PORT="8080" CTX="16000":
    bash scripts/serve-llamacpp.sh {{PORT}} {{CTX}}

# Write ~/.vibe/config.toml. just config mlx | just config llamacpp
config BACKEND="mlx" PORT="8080":
    bash scripts/write-vibe-config.sh {{BACKEND}} {{PORT}}

# Launch Vibe (a server must already be running)
vibe:
    vibe

# One shot: write config + start server in background + launch vibe
up BACKEND="mlx" PORT="8080":
    bash scripts/up.sh {{BACKEND}} {{PORT}}

# Stop a background server started by 'up'
down:
    bash scripts/down.sh

# Lint scripts + run unit tests
test:
    shellcheck scripts/*.sh tests/*.sh
    bash tests/recommend_ctx.test.sh

# Remove .venv (add --models to also drop the HF model cache)
clean *ARGS:
    bash scripts/clean.sh {{ARGS}}

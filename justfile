# macstral: local Mistral Vibe + Devstral Q3 on Apple Silicon via Ollama
set shell := ["bash", "-cu"]

# List recipes
default:
    @just --list

# Verify host + recommend settings (interactive confirm)
doctor *ARGS:
    bash scripts/doctor.sh {{ARGS}}

# Install Ollama model, Vibe, and fetch GGUF (~11.5 GB)
setup *ARGS:
    bash scripts/setup.sh {{ARGS}}

# Ensure Ollama daemon is serving on PORT (starts it if not). e.g. just serve 11434
serve PORT="11434":
    bash scripts/serve.sh {{PORT}}

# Write ~/.vibe/config.toml from template
config BACKEND="ollama" PORT="11434":
    bash scripts/write-vibe-config.sh {{BACKEND}} {{PORT}}

# Launch Vibe (daemon must already be running)
vibe:
    vibe

# One shot: prewarm (prefill Vibe's prompt for DIR) then launch vibe. DIR defaults to where you ran just.
up DIR=invocation_directory() PORT="11434":
    bash scripts/up.sh "{{DIR}}" {{PORT}}

# Stop a background daemon started by 'up' (leaves the Ollama app daemon alone)
down:
    bash scripts/down.sh

# Free the model from memory now (releases keep_alive; keeps model on disk, daemon up)
unload PORT="11434":
    bash scripts/unload.sh {{PORT}}

# Lint scripts + run unit tests
test:
    shellcheck scripts/*.sh tests/*.sh
    bash tests/recommend_ctx.test.sh

# Remove .macstral runtime dir (add --models to also remove the devstral-q3 model)
clean *ARGS:
    bash scripts/clean.sh {{ARGS}}

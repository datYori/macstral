# macstral — local Mistral Vibe + Devstral Q4 on Apple Silicon
set shell := ["bash", "-cu"]

# List recipes
default:
    @just --list

# Verify host + recommend settings (interactive confirm). Pass --force to override tight RAM.
doctor *ARGS:
    bash scripts/doctor.sh {{ARGS}}

# Lint scripts + run unit tests
test:
    shellcheck scripts/*.sh tests/*.sh
    bash tests/recommend_ctx.test.sh

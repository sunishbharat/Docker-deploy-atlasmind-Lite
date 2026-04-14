#!/usr/bin/env zsh
# -- atlasmind-Lite startup (macOS) --------------------------------------------
# Creates the shared cross-stack network if missing, then starts the stack.
# Usage:
#   ./start-macos.zsh                        # Groq backend
#   ./start-macos.zsh --profile ollama       # local Ollama backend (waits for model pull)
# -----------------------------------------------------------------------------

docker network inspect atlasmind-shared >/dev/null 2>&1 \
  || docker network create atlasmind-shared

docker volume inspect atlasmind_pgdata >/dev/null 2>&1 \
  || docker volume create atlasmind_pgdata

docker volume inspect atlasmind_ollama_models >/dev/null 2>&1 \
  || docker volume create atlasmind_ollama_models

# Separate --profile <name> from the remaining args so it is passed to
# `docker compose` (top-level flag) rather than to `up` (subcommand).
local -a compose_flags=()
local -a up_flags=()
local ollama_profile=0

while (( $# > 0 )); do
  case "$1" in
    --profile)
      compose_flags+=(--profile "$2")
      [[ "$2" == "ollama" ]] && ollama_profile=1
      shift 2
      ;;
    *)
      up_flags+=("$1")
      shift
      ;;
  esac
done

# Start detached and wait for all services to become healthy.
# --wait blocks until every healthcheck passes — for ollama this means
# the model pull is fully complete before this script returns.
echo "Starting atlasmind-Lite stack..."
docker compose -p atlasmind-lite ${compose_flags[@]+"${compose_flags[@]}"} up -d ${up_flags[@]+"${up_flags[@]}"}

if (( ollama_profile )); then
  echo "Waiting for Ollama model pull to complete (this may take a few minutes on first run)..."
fi

docker compose -p atlasmind-lite ${compose_flags[@]+"${compose_flags[@]}"} up --wait --no-recreate ${up_flags[@]+"${up_flags[@]}"}

echo ""
echo "Stack is ready."
(( ollama_profile )) && echo "  Ollama:     http://localhost:11434"
echo "  atlasmind:  http://localhost:8000"

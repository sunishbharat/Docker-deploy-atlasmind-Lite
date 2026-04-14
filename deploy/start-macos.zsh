#!/usr/bin/env zsh
# -- atlasmind-Lite startup (macOS) --------------------------------------------
# Creates the shared cross-stack network if missing, then starts the stack.
# Usage:
#   ./start-macos.zsh                        # Groq backend
#   ./start-macos.zsh --profile ollama       # local Ollama backend
#   ./start-macos.zsh --profile ollama -d    # detached (background)
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

while (( $# > 0 )); do
  case "$1" in
    --profile)
      compose_flags+=(--profile "$2")
      shift 2
      ;;
    *)
      up_flags+=("$1")
      shift
      ;;
  esac
done

docker compose -p atlasmind-lite ${compose_flags[@]+"${compose_flags[@]}"} up ${up_flags[@]+"${up_flags[@]}"}

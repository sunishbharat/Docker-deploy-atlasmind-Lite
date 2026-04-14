#!/bin/sh
# -- atlasmind-Lite startup -----------------------------------------------------
# Creates the shared cross-stack network if missing, then starts the stack.
# Usage:
#   ./start.sh                        # Groq backend
#   ./start.sh --profile ollama       # local Ollama backend
#   ./start.sh --profile ollama -d    # detached (background)
# -----------------------------------------------------------------------------

docker network inspect atlasmind-shared >/dev/null 2>&1 \
  || docker network create atlasmind-shared

docker volume inspect atlasmind_pgdata >/dev/null 2>&1 \
  || docker volume create atlasmind_pgdata

docker volume inspect atlasmind_ollama_models >/dev/null 2>&1 \
  || docker volume create atlasmind_ollama_models

# Separate --profile <name> from the remaining args so it is passed to
# `docker compose` (top-level flag) rather than to `up` (subcommand).
COMPOSE_FLAGS=""
UP_FLAGS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      COMPOSE_FLAGS="$COMPOSE_FLAGS --profile $2"
      shift 2
      ;;
    *)
      UP_FLAGS="$UP_FLAGS $1"
      shift
      ;;
  esac
done

# shellcheck disable=SC2086
docker compose -p atlasmind-lite $COMPOSE_FLAGS up $UP_FLAGS

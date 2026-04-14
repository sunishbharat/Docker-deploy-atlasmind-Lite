#!/usr/bin/env zsh
# -- atlasmind-Lite startup (macOS) --------------------------------------------
# Creates the shared cross-stack network if missing, then starts the stack.
# Usage:
#   ./start-macos.zsh                        # Groq backend
#   ./start-macos.zsh --profile ollama       # local Ollama backend (waits for model pull)
# -----------------------------------------------------------------------------

set -e  # exit immediately on any error

# -- Preflight checks ----------------------------------------------------------

# 1. Docker must be running
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

# 2. If --profile ollama is requested, free up port 11434 from native Ollama
if [[ " $* " == *" ollama "* ]]; then
  if lsof -i :11434 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Native Ollama is running on port 11434 — stopping it gracefully..."
    # Try quitting the macOS app first (graceful), then fall back to SIGTERM
    osascript -e 'quit app "Ollama"' 2>/dev/null || killall -TERM ollama 2>/dev/null || true
    # Wait up to 10 seconds for the port to be released
    local i=0
    while lsof -i :11434 -sTCP:LISTEN -t >/dev/null 2>&1; do
      (( i++ ))
      if (( i > 10 )); then
        echo "ERROR: Port 11434 is still in use after 10 seconds. Please stop Ollama manually and retry."
        exit 1
      fi
      sleep 1
    done
    echo "Port 11434 is now free."
  fi
fi

# -- Networks & volumes --------------------------------------------------------

docker network inspect atlasmind-shared >/dev/null 2>&1 \
  || docker network create atlasmind-shared

docker volume inspect atlasmind_pgdata >/dev/null 2>&1 \
  || docker volume create atlasmind_pgdata

docker volume inspect atlasmind_ollama_models >/dev/null 2>&1 \
  || docker volume create atlasmind_ollama_models

# -- Arg parsing ---------------------------------------------------------------
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

# -- Start stack ---------------------------------------------------------------
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

#!/usr/bin/env zsh
# -- atlasmind-Lite startup (macOS) --------------------------------------------
# Creates the shared cross-stack network if missing, then starts the stack.
# Usage:
#   ./start-macos.zsh                        # Groq backend
#   ./start-macos.zsh --profile ollama       # local Ollama backend (waits for model pull)
# -----------------------------------------------------------------------------

set -eo pipefail

# Always run from the directory containing this script so docker compose finds
# docker-compose.yml and .env regardless of where the user invoked us from.
cd "$(dirname "$0")"

# -- Preflight checks ----------------------------------------------------------

# 1. Docker must be running
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

# 2. .env must exist and POSTGRES_PASSWORD must be set
if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill in POSTGRES_PASSWORD at minimum."
  exit 1
fi
if ! grep -q '^POSTGRES_PASSWORD=.\+' .env 2>/dev/null; then
  echo "ERROR: POSTGRES_PASSWORD is not set in .env. Open .env and set it before retrying."
  exit 1
fi

# -- Arg parsing ---------------------------------------------------------------
# Separate --profile <name> from the remaining args so it is passed to
# `docker compose` (top-level flag) rather than to `up` (subcommand).
compose_flags=()
up_flags=()
ollama_profile=0

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

# -- Preflight: free port 11434 for containerised Ollama -----------------------
if (( ollama_profile )); then
  if lsof -i :11434 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Native Ollama is running on port 11434 — stopping it gracefully..."
    # Try quitting the macOS app first (graceful), then fall back to SIGTERM
    osascript -e 'quit app "Ollama"' 2>/dev/null || killall -TERM ollama 2>/dev/null || true
    # Wait up to 10 seconds for the port to be released
    i=0
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

# -- Start stack ---------------------------------------------------------------
# -d --wait: start detached and block until every healthcheck passes.
# For ollama this means the model pull is fully complete before this script returns.
echo "Starting atlasmind-Lite stack..."
(( ollama_profile )) && echo "Waiting for Ollama model pull to complete (this may take a few minutes on first run)..."

docker compose -p atlasmind-lite \
  ${compose_flags[@]+"${compose_flags[@]}"} \
  up -d --wait \
  ${up_flags[@]+"${up_flags[@]}"}

echo ""
echo "Stack is ready."
(( ollama_profile )) && echo "  Ollama:     http://localhost:11434"
echo "  atlasmind:  http://localhost:8000"

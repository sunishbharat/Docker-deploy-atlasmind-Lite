#!/bin/sh
set -e

MODEL="${JQL_LOCAL_MODEL:-qwen2.5:3b-instruct-q4_K_M}"

echo "[ollama] Starting server..."
ollama serve &
OLLAMA_PID=$!

echo "[ollama] Waiting for API..."
i=0
until ollama list > /dev/null 2>&1; do
  i=$((i+1))
  if [ $i -gt 120 ]; then
    echo "[ollama] ERROR: Ollama failed to start after 120 seconds"
    exit 1
  fi
  sleep 1
done
echo "[ollama] Server ready"

if ollama list 2>/dev/null | grep -q "$MODEL"; then
  echo "[ollama] Model '$MODEL' already available, skipping pull"
else
  echo "[ollama] Pulling model '$MODEL' (first-run only)..."
  ollama pull "$MODEL"
  echo "[ollama] Model pull complete"
fi

echo "[ollama] All ready — keeping server alive"
tail -f /dev/null &
wait $OLLAMA_PID

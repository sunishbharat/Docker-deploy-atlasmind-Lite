#!/bin/sh
set -e

MODEL="${JQL_LOCAL_MODEL:-qwen2.5:3b-instruct-q4_K_M}"

# Register corporate CA certificate if present (needed behind TLS-inspecting proxies)
if [ -f /usr/local/share/ca-certificates/ollama-cert.crt ]; then
  echo "[ollama] Registering corporate CA certificate..."
  update-ca-certificates 2>/dev/null || true
  cat /usr/local/share/ca-certificates/ollama-cert.crt >> /etc/ssl/certs/ca-certificates.crt
fi

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

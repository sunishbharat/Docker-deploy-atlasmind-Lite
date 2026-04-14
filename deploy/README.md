# atlasmind-Lite

Natural language → JQL generator. Runs as a 3-container Docker stack.

## Prerequisites

- Docker Desktop (Windows / macOS) or Docker Engine (Linux)
- The `atlasmind-lite-cpu:latest` image loaded locally (provided separately)

### Load the image

```bash
docker load -i atlasmind-lite-cpu.tar
```

---

## Setup

**Step 1 — Configure:**

```bash
cp .env.example .env
```

Open `.env` and set at minimum:
```
POSTGRES_PASSWORD=<choose a password>
```

For Groq backend, also set:
```
LLM_BACKEND=groq
GROQ_API_KEY=<your-groq-api-key>
```

**Step 2 — Make the startup script executable (Linux / macOS):**

```bash
chmod +x start.sh
```

**Step 3 — Start the stack:**

```bash
# Local Ollama backend (downloads model on first run)
./start.sh --profile ollama -d

# Groq backend (no local model needed)
./start.sh -d
```

**Verify:**

```bash
curl http://localhost:8000/health
# → {"status":"ok"}
```

---

## LLM backends

### Ollama (local, default)

Runs a local LLM inside Docker. On first start, the model is pulled automatically (~2 GB). Subsequent starts reuse the cached model.

Default model: `qwen2.5:3b-instruct-q4_K_M`

To use a different model, set in `.env`:
```
JQL_LOCAL_MODEL=qwen2.5-coder:7b-instruct
```

### Groq (cloud)

Faster — no local model download needed. Requires a free Groq API key from [console.groq.com](https://console.groq.com).

Set in `.env`:
```
LLM_BACKEND=groq
GROQ_API_KEY=your-key
```

Start **without** `--profile ollama`:
```bash
./start.sh -d
```

---

## Jira integration (optional)

Add to `.env`:
```
JIRA_URL=https://yourorg.atlassian.net
JIRA_USER=you@example.com
JIRA_TOKEN=your-api-token
```

---

## API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Liveness check |
| `GET` | `/query?q=<text>` | Natural language → JQL |
| `POST` | `/query` | Natural language → JQL (JSON body) |

```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query": "list open bugs assigned to me"}'
```

---

## Stopping the stack

```bash
docker compose down
```

To also remove stored data (database + Ollama model cache):
```bash
docker compose down -v
```

---

## Files

```
deploy/
├-- docker-compose.yml      # Stack definition
├-- ollama-entrypoint.sh    # Ollama startup (required at runtime)
├-- start.sh                # Startup script
├-- .env.example            # Config template — copy to .env
└-- README.md               # This file
```

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

For a cloud backend (no local model download needed), also set the relevant vars — see [LLM backends](#llm-backends) below.

**Step 2 — Make the startup script executable (Linux / macOS):**

```bash
chmod +x start.sh
```

**Step 3 — Start the stack:**

```bash
# Local Ollama backend (downloads model on first run)
./start.sh --profile ollama -d

# Any cloud backend (Groq / Claude / Bedrock / vLLM — no local model needed)
./start.sh -d
```

**Windows (Command Prompt) — start with inline env vars:**

```cmd
set POSTGRES_PASSWORD=postgres && set JQL_OLLAMA_TIMEOUT=240 && set MAX_JIRA_RESULTS=1000 && docker compose --profile ollama up
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

### vLLM (GPU inference server)

Offloads inference to an external GPU server (e.g. a Windows machine running vLLM in WSL2, reachable over Tailscale). No local model download needed.

Set in `.env`:
```
LLM_BACKEND=vllm
VLLM_URL=http://100.x.x.x:8002
```

Start **without** `--profile ollama`:
```bash
./start.sh -d
```

The model name is auto-detected from the vLLM server's `/v1/models` endpoint.

### Claude (Anthropic direct)

No local model needed. Requires an Anthropic API key from [console.anthropic.com](https://console.anthropic.com).

Set in `.env`:
```
LLM_BACKEND=claude
CLAUDE_API_KEY=your-anthropic-key
```

Optionally override the model or inference settings:
```
CLAUDE_MODEL=claude-sonnet-4-6
CLAUDE_TEMPERATURE=0.1
CLAUDE_TIMEOUT=30
CLAUDE_MAX_TOKENS=500
```

Start **without** `--profile ollama`:
```bash
./start.sh -d
```

### Bedrock (AWS Bedrock-compatible endpoint)

Uses a Bedrock-compatible endpoint authenticated with a bearer token. Both `CUSTOM_ENDPOINT` and `AWS_BEARER_TOKEN_BEDROCK` are required.

Set in `.env`:
```
LLM_BACKEND=bedrock
CUSTOM_ENDPOINT=https://your-bedrock-compatible-endpoint
AWS_BEARER_TOKEN_BEDROCK=your-bearer-token
```

Optionally override the model, region, or inference settings:
```
BEDROCK_MODEL=claude-sonnet-4.6
BEDROCK_REGION=custom
BEDROCK_TEMPERATURE=0.1
BEDROCK_TIMEOUT=30
BEDROCK_MAX_TOKENS=500
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

### Custom Jira fields (`STANDARD_FIELD_IDS`)

To control which Jira fields are used for context, set `STANDARD_FIELD_IDS` as a comma-separated list in `.env`:

```
STANDARD_FIELD_IDS=key,summary,assignee,priority,issuetype,created,resolutiondate
```

Then recreate the container to pick up the new value:
```bash
docker compose -p atlasmind-lite up -d --force-recreate atlasmind
```

> **Note:** `docker compose restart` does **not** re-read `.env` — it reuses the existing container's environment. Always use `--force-recreate` when changing env vars.

Verify the value was applied:
```bash
docker exec atlasmind-lite-cpu printenv STANDARD_FIELD_IDS
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

## Troubleshooting

### `external volume "atlasmind_pgdata" not found`

The startup scripts (`start.sh` / `start-macos.zsh`) create the required Docker volumes and network automatically. If you run `docker compose up` directly, you must create them first:

```bash
docker volume create atlasmind_pgdata
docker volume create atlasmind_ollama_models
docker network create atlasmind-shared
```

Then retry your `docker compose up` command.

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

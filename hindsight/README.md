# Hindsight

Hindsight is the agent-memory server on `cicero`. It runs bare-metal from a
Python virtual environment as systemd user services, stores memories in the
host PostgreSQL, and takes its models from the vLLM stack (`vllm/`) and from
OpenRouter.

## Components

| Component | Endpoint | Runs as | Choice |
| --- | --- | --- | --- |
| Hindsight API | `http://cicero.local:8888` | `hindsight.service` | `hindsight-api` 0.10.1 from PyPI |
| Control Plane (web UI) | `http://cicero.local:9999` | `hindsight-ui.service` | `@vectorize-io/hindsight-control-plane`, same version as the API |
| Database | local socket, `127.0.0.1:5432` | host PostgreSQL 18 | database `hindsight` with `vector` and `pg_trgm`, role `gaperton`, peer authentication |
| Retain / Consolidation LLM | `http://127.0.0.1:8080/v1` | `cicero-vllm.service` | Qwen3.8-27B FP8 on vLLM, model id `qwen3.8-27b` |
| Reflect LLM | `https://openrouter.ai/api/v1` | OpenRouter | `deepseek/deepseek-v4.1-flash`, reasoning effort `max` |
| Reranker | `http://127.0.0.1:8081/v1` | llama.cpp sidecar in `cicero-vllm.service` | Qwen3-Reranker 0.6B Q8_0 on ROCm1, model id `qwen3-reranker` |
| Embeddings | in-process | `hindsight.service` | `BAAI/bge-m3` on CPU, 1024 dimensions |

## How the components connect

```text
 LAN clients (agents, MCP)          browser
          |                            |
          v                            v
   Hindsight API :8888  <-------  Control Plane :9999
          |
          +--> PostgreSQL (local socket)             memories, vectors, llm_requests
          +--> bge-m3 on CPU (in-process)            embeddings
          +--> vLLM :8080  qwen3.8-27b               Retain, Consolidation
          +--> OpenRouter  deepseek-v4.1-flash       Reflect, mental-model refresh
          +--> llama.cpp :8081  qwen3-reranker       Recall reranking
```

- **Retain** extracts facts with the local Qwen, with thinking disabled.
- **Consolidation** merges facts into observations with the local Qwen, with
  thinking disabled, one fact per batch.
- **Recall** embeds the query on CPU, gathers up to 100 candidates from
  PostgreSQL, and reranks them in one `/v1/rerank` request to the sidecar.
  Documents are truncated to 3072 tokens so each query+document pair fits the
  reranker's 4096-token batch; one oversized pair fails the whole request.
- **Reflect** runs its agent loop on DeepSeek V4.1 Flash through OpenRouter,
  with reasoning effort `max`. Mental-model refresh runs the Reflect pipeline
  with the same model and effort. The prompts sent there include retrieved
  memories, so this data leaves the host.

The vLLM stack is shared with Open WebUI and other clients. Hindsight is limited
to 4 concurrent LLM calls overall and 3 per operation; each call must acquire
both limits, including remote Reflect calls.

## Configuration

`hindsight.service` loads `~/.config/hindsight/hindsight.env`, a symlink to
the active profile `hindsight-qwen3.8-27b.env`. The profile is not tracked in
this repository because it holds the OpenRouter API key; keep it mode `600`.
Restart the API after editing it.

| Setting | Value |
| --- | --- |
| `LLM_PROVIDER` / `LLM_BASE_URL` / `LLM_MODEL` | `openai`, `http://127.0.0.1:8080/v1`, `qwen3.8-27b` |
| `REFLECT_LLM_PROVIDER` / `REFLECT_LLM_BASE_URL` / `REFLECT_LLM_MODEL` | `openai`, `https://openrouter.ai/api/v1`, `deepseek/deepseek-v4.1-flash` |
| `REFLECT_LLM_API_KEY` | OpenRouter key |
| `REFLECT_LLM_REASONING_EFFORT` / `MENTAL_MODEL_REFRESH_LLM_REASONING_EFFORT` | `max` each |
| `LLM_MAX_CONCURRENT` | `4` |
| `RETAIN_` / `REFLECT_` / `CONSOLIDATION_LLM_MAX_CONCURRENT` | `3` each |
| `MENTAL_MODEL_REFRESH_CONCURRENCY` | `3` |
| `LLM_TIMEOUT` | `300` s per request, Reflect included |
| `REFLECT_WALL_TIMEOUT` | `600` s per Reflect |
| `LLM_STRICT_SCHEMA` | `true` |
| `RETAIN_` / `CONSOLIDATION_LLM_EXTRA_BODY` | `{"chat_template_kwargs":{"enable_thinking":false}}` |
| `CONSOLIDATION_LLM_BATCH_SIZE` | `1` |
| `EMBEDDINGS_PROVIDER` / `EMBEDDINGS_LOCAL_MODEL` | `local`, `BAAI/bge-m3`, CPU forced |
| `RERANKER_PROVIDER` / `RERANKER_LITELLM_API_BASE` / `RERANKER_LITELLM_MODEL` | `litellm`, `http://127.0.0.1:8081/v1`, `qwen3-reranker` |
| `RERANKER_MAX_CANDIDATES` / `RERANKER_LITELLM_MAX_TOKENS_PER_DOC` | `100`, `3072` |

All names carry the `HINDSIGHT_API_` prefix. The reranker's own settings (one
slot, 4096-token context and batch) live in `vllm/sidecar.ini`.

Changing the embedding model after memories exist requires re-embedding the
stored data and rebuilding its vector indexes.

## Files

| Path | Purpose |
| --- | --- |
| `hindsight/update.sh` | Back up PostgreSQL, upgrade the API and the matching Control Plane, and verify both |
| `hindsight/ui/` | Control Plane installer and its systemd user unit |
| `hindsight/benchmark/` | Workload generators and benchmarks |
| `hindsight/templates/` | Reference copies of Hindsight's Retain and Consolidate prompts, used by the benchmarks |
| `~/.local/share/hindsight/venv` | API Python environment |
| `~/.local/share/hindsight/cache/huggingface` | Embedding-model cache |
| `~/.local/share/hindsight-control-plane` | Control Plane npm install |
| `~/.config/hindsight/hindsight.env` | Active API profile (symlink) |
| `~/.config/hindsight/control-plane.env` | Control Plane access key |
| `~/.config/systemd/user/hindsight.service` | API unit |
| `~/.config/systemd/user/hindsight-ui.service` | Control Plane unit |

## Operation

```bash
systemctl --user status hindsight.service hindsight-ui.service
journalctl --user -u hindsight.service -f
systemctl --user restart hindsight.service      # after changing the profile
./hindsight/ui/install.sh                       # install or refresh the Control Plane
./hindsight/update.sh                           # upgrade to the latest release
./hindsight/update.sh 0.10.1                    # upgrade to a specific release
```

When the version changes, `update.sh` writes a PostgreSQL dump to
`~/backups/hindsight/` before it upgrades the API package. The API applies
database migrations on startup.

Health checks:

```bash
curl -fsS http://cicero.local:8888/health       # API and database pool
curl -fsS http://127.0.0.1:8080/health          # vLLM
curl -fsS http://127.0.0.1:8081/health          # reranker sidecar
```

The default API namespace is `http://cicero.local:8888/v1/default`; the schema
is at `/openapi.json`. Read the Control Plane access key with:

```bash
sed -n 's/^HINDSIGHT_CP_ACCESS_KEY=//p' ~/.config/hindsight/control-plane.env
```

## Database and backups

```bash
psql --dbname hindsight
pg_dump --dbname=hindsight --format=custom \
  --file="$HOME/backups/hindsight/hindsight-$(date +%Y%m%d-%H%M%S).dump"
pg_restore --list ~/backups/hindsight/hindsight-TIMESTAMP.dump
```

Stop Hindsight before restoring its database. The `llm_requests` table records
every LLM call with its operation, token counts and duration.

## Security

- The API has no authentication or TLS. Keep port 8888 on the trusted LAN.
- The Control Plane requires its access key, but keep port 9999 on the LAN too.
- PostgreSQL stays bound to localhost.
- Reflect and mental-model-refresh prompts, including retrieved memories, go
  to OpenRouter and the provider that serves the model.
- Do not commit the profile, credentials or memory data to this repository.

# Hindsight

Current Hindsight deployment on `cicero`, last checked 2026-08-23. Historical
benchmarks, incidents, rejected configurations, and tuning rationale are kept in
[`experiments/`](experiments/README.md), not in this operational README.

Paths and commands below are relative to the repository root unless an absolute
path is shown.

## Services

| Component | Endpoint | Service / backend |
| --- | --- | --- |
| Hindsight API | `http://cicero.local:8888` | `hindsight.service`, bound to `0.0.0.0:8888` |
| Control Plane | `http://cicero.local:9999` | `hindsight-ui.service`, bound to `0.0.0.0:9999` |
| LLM and reranker | `http://127.0.0.1:8080/v1` | Shared llama.cpp router in `cicero-home-ai.service` |
| PostgreSQL | local socket and `127.0.0.1:5432` | Database `hindsight`, role `gaperton` via peer authentication |

The API and Control Plane are available on the trusted LAN. PostgreSQL remains
local. The Control Plane connects to the API over `127.0.0.1:8888` and reads its
access key from `/home/gaperton/.config/hindsight/control-plane.env`.

## Installed versions

- Hindsight API: `0.9.1`
- Hindsight Control Plane: `0.9.1`
- PyTorch: `2.13.0+cpu`
- SentenceTransformers: `6.0.0`
- asyncpg: `0.31.0`
- Embedding columns: `vector(1024)`

The installed `hindsight-api` package is unmodified. Repository patches under
`patches/` apply only to llama.cpp.

## Active configuration

The systemd API unit loads
`/home/gaperton/.config/hindsight/hindsight.env`, currently a symlink to
`hindsight-gpt-oss.env`. The active database URL is:

```dotenv
HINDSIGHT_API_DATABASE_URL=postgresql://gaperton@/hindsight?host=/var/run/postgresql
```

### LLM

| Setting | Current value |
| --- | --- |
| Provider | `openai` |
| API base | `http://127.0.0.1:8080/v1` |
| Router model id | `llm` |
| Model | GPT-OSS 20B `UD-Q8_K_XL` |
| Hindsight concurrency | `HINDSIGHT_API_LLM_MAX_CONCURRENT=2` |
| llama.cpp slots | `parallel = 2` |
| Context | `262144` total, `131072` per slot |
| Request timeout | 300 seconds |
| Reflect wall timeout | 600 seconds |
| Strict schemas | enabled |
| Output limit | `n-predict = 4096` |

The `[llm]` preset is tensor-split 38/62 across ROCm0 and ROCm1. It uses the
custom `hindsight/templates/gpt-oss-20b-harmony.jinja` template, F16 KV cache,
`batch-size = 4096`, and `ubatch-size = 2048`.

The environment sets `reasoning_effort=low` globally through
`HINDSIGHT_API_LLM_EXTRA_BODY` and explicitly for Reflect through
`HINDSIGHT_API_REFLECT_LLM_REASONING_EFFORT`. Hindsight 0.9.1 sends the latter
as a top-level request parameter, which takes precedence in llama.cpp.

### Embeddings

| Setting | Current value |
| --- | --- |
| Provider | `local` |
| Model | `BAAI/bge-m3` |
| Device | CPU |
| Dimensions | 1024 |

Changing the embedding model after memories exist may require re-embedding the
stored data and rebuilding its vector indexes.

### Reranker and Recall concurrency

| Setting | Current value |
| --- | --- |
| Provider | `litellm` |
| API base | `http://127.0.0.1:8080/v1` |
| Router model id | `reranker` |
| Model | Qwen3-Reranker 0.6B Q8_0 on ROCm0 |
| Candidates per Recall | `HINDSIGHT_API_RERANKER_MAX_CANDIDATES=100` |
| Maximum tokens per document | `3072` |
| llama.cpp slots | `parallel = 1` |
| Context / batch / ubatch | `4096 / 4096 / 4096` |

A normal Recall packs its candidate documents into one `/v1/rerank` request.
The active LiteLLM provider has no separate reranker semaphore. Concurrent
Recall operations are limited by `HINDSIGHT_API_RECALL_MAX_CONCURRENT`; it is
unset here, so Hindsight 0.9.1 uses its default of 32 per worker. The llama.cpp
reranker has one processing slot, so simultaneous rerank requests queue there.

## Repository layout

| Path | Purpose |
| --- | --- |
| `hindsight/update.sh` | Back up PostgreSQL, upgrade the API and matching Control Plane, and verify both endpoints. |
| `hindsight/ui/` | Control Plane installer and systemd user unit. |
| `hindsight/benchmark/` | Hindsight workload generators and benchmark programs. |
| `hindsight/templates/` | Retain, Consolidate, and GPT-OSS chat templates. |
| `hindsight/experiments/` | Dated investigations, measurements, incidents, and rejected configurations. |

Runtime files are outside the repository:

| Path | Purpose |
| --- | --- |
| `/home/gaperton/.local/share/hindsight/venv` | Hindsight Python environment |
| `/home/gaperton/.local/share/hindsight/cache/huggingface` | Embedding-model cache |
| `/home/gaperton/.config/hindsight/hindsight.env` | Active API environment symlink |
| `/home/gaperton/.config/hindsight/control-plane.env` | Control Plane access key |
| `/home/gaperton/.config/systemd/user/hindsight.service` | Installed API user unit |
| `/home/gaperton/.config/systemd/user/hindsight-ui.service` | Installed Control Plane user unit |

## Service management

Status and logs:

```bash
systemctl --user status hindsight.service hindsight-ui.service
journalctl --user -u hindsight.service -f
journalctl --user -u hindsight-ui.service -f
```

Restart after changing the API environment:

```bash
systemctl --user restart hindsight.service
```

Install or refresh the persistent Control Plane:

```bash
./hindsight/ui/install.sh
```

Upgrade the API and version-matched Control Plane together:

```bash
./hindsight/update.sh           # latest stable release
./hindsight/update.sh 0.9.1     # explicit version
```

The updater creates a custom-format PostgreSQL dump under
`/home/gaperton/backups/hindsight/` before changing the API package.

## Health and API discovery

```bash
curl -fsS http://cicero.local:8888/health
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/v1/models
curl -fsS http://cicero.local:8888/openapi.json
```

The Hindsight health endpoint covers the API and its database pool; check the
router separately as shown above. The default API namespace is
`http://cicero.local:8888/v1/default`.

Read the Control Plane access key locally with:

```bash
sed -n 's/^HINDSIGHT_CP_ACCESS_KEY=//p' ~/.config/hindsight/control-plane.env
```

## PostgreSQL and backups

Connect through peer authentication:

```bash
psql --dbname hindsight
```

Create a manual logical backup:

```bash
install -d -m 700 /home/gaperton/backups/hindsight
pg_dump --dbname=hindsight --format=custom \
  --file="/home/gaperton/backups/hindsight/hindsight-$(date +%Y%m%d-%H%M%S).dump"
```

List a dump before restoring it:

```bash
pg_restore --list /home/gaperton/backups/hindsight/hindsight-TIMESTAMP.dump
```

Stop Hindsight before replacing or restoring its database. PostgreSQL is the
authoritative data store; the inactive `.pg0` directory is not a current backup.

## Security

- The Hindsight API has no application authentication or TLS. Keep port 8888 on
  the trusted LAN and do not forward it to the internet.
- The Control Plane uses an access key, but port 9999 should also remain limited
  to the trusted LAN.
- PostgreSQL must remain bound to localhost; do not expose port 5432.
- Do not commit credentials or memory data to this repository.

## Historical evidence

See [`experiments/README.md`](experiments/README.md) for the dated installation
log, model investigations, tuning results, and benchmark methodology. Those
documents explain why the current values were selected; they do not define the
active configuration.

# Hindsight server

This machine runs a local-only Hindsight memory server backed by the Ubuntu PostgreSQL service and the secondary llama.cpp router.

## Architecture

- Hindsight API: `http://127.0.0.1:8888`
- PostgreSQL: `127.0.0.1:5432` and the local Unix socket
- LLM: secondary llama.cpp router at `http://127.0.0.1:8081/v1`
- LLM model: `qwen3.6-35b-a3b`
- LLM router config: `models-1.ini`, MoE-only, two inference slots
- Embeddings: `BAAI/bge-m3`, local CPU inference
- Reranker: `BAAI/bge-reranker-v2-m3`, local CPU inference
- Database: `hindsight`
- PostgreSQL role: `gaperton`, authenticated through Unix-socket peer authentication

All service endpoints are bound to localhost. Hindsight does not contain or require a PostgreSQL password.

## Installed versions

Verified on 2026-08-02:

- Hindsight API: 0.8.6
- PostgreSQL: 18.4
- pgvector: 0.8.1
- `pg_trgm`: 1.6
- PyTorch: 2.13.0+cpu
- SentenceTransformers: 5.6.1
- asyncpg: 0.31.0
- Embedding columns: `vector(1024)`

The 2026-08-02 installation audit also verified that the Hindsight and PostgreSQL services are enabled and active, the OpenAPI document exposes 57 paths, and no warning-or-higher journal entries occurred after the current Hindsight activation.

## Files and data

- Hindsight virtual environment: `/home/gaperton/.local/share/hindsight/venv`
- Hindsight environment: `/home/gaperton/.config/hindsight/hindsight.env`
- systemd user unit: `/home/gaperton/.config/systemd/user/hindsight.service`
- Hugging Face cache: `/home/gaperton/.local/share/hindsight/cache/huggingface`
- PostgreSQL setup script: `/home/gaperton/.local/share/hindsight/configure-postgresql.sh`
- Inactive embedded pg0 data: `/home/gaperton/.local/share/hindsight/.pg0`

The embedded pg0 directory is retained only as rollback data. It occupies approximately 139 MiB, has no active pg0 process, and is not used by the service. The active service uses Ubuntu PostgreSQL.

## Multilingual retrieval

The deployment is optimized for memories and queries that mix Russian and English.

### Embeddings

`BAAI/bge-m3` produces 1024-dimensional multilingual embeddings and does not require different `query:` and `passage:` prefixes. That makes it directly compatible with Hindsight's local SentenceTransformers provider.

`intfloat/multilingual-e5-large` was considered but not selected. E5 requires asymmetric query and passage prefixes, while Hindsight 0.8.6's local SentenceTransformers provider sends both through the same plain `encode()` path. E5 would require the ONNX provider, TEI, or another wrapper that applies the prefixes correctly.

### Reranker

`BAAI/bge-reranker-v2-m3` replaces the small English-focused MS MARCO MiniLM default. It is multilingual and reranks candidates after semantic, keyword, graph, and temporal retrieval.

The reranker is configured with:

- CPU inference
- Maximum concurrency: 2
- Length-based bucket batching enabled

The lower concurrency avoids CPU thrashing on the Ryzen 7 5700X.

### Embedding-dimension warning

Changing embedding models after memories exist may require re-embedding all stored memories. Hindsight only changes the PostgreSQL vector dimension automatically when the affected tables contain no embeddings.

During initial setup, Hindsight safely migrated these empty columns from `vector(384)` to `vector(1024)` and rebuilt their HNSW indexes:

- `memory_units.embedding`
- `mental_models.embedding`

Do not change the embedding model casually after storing real data.

## LLM configuration

Hindsight uses the secondary llama.cpp router so it does not contend with the primary endpoint:

- Endpoint: `http://127.0.0.1:8081/v1`
- Model: `qwen3.6-35b-a3b`
- Quantization: `UD-Q5_K_XL`
- Hindsight LLM concurrency: 2
- Router slots: 2, with 131072 tokens per slot when this model is loaded
- Continuous batching: enabled
- Timeout: 300 seconds
- Strict structured schemas: enabled
- Qwen thinking: disabled with `chat_template_kwargs.enable_thinking=false`
- Qwen speculative decoding: `draft-mtp`, depth 4 in the current router config

Thinking is disabled because reasoning tokens can exhaust Hindsight's bounded structured-output calls before Qwen emits the required result.

The secondary router also offers `gemma4-26b-a4b` at `UD-Q6_K_XL`. Gemma MTP is disabled because every locally tested draft depth reduced generation throughput. Hindsight currently selects Qwen, not Gemma.

The saved Qwen Q5_K_XL benchmark validates MTP depth 2 for generation throughput: 109.51 to 134.10 tokens/s, while prompt throughput fell from 368.73 to 312.94 tokens/s. The active depth-4 setting has passed Hindsight correctness checks but does **not** yet have a matching controlled no-regression benchmark. Do not treat depth 4 as performance-approved until it is compared with depth 2 and no MTP using a representative prompt-heavy Hindsight workload.

Hindsight's strongest official local recommendation is `gpt-oss-20b`, which is not currently installed as a llama.cpp preset.

## Service management

Check status:

```bash
systemctl --user status hindsight.service
systemctl status postgresql.service
curl -fsS http://127.0.0.1:8888/health
```

Restart Hindsight:

```bash
systemctl --user restart hindsight.service
```

Stop and start Hindsight:

```bash
systemctl --user stop hindsight.service
systemctl --user start hindsight.service
```

Follow logs:

```bash
journalctl --user-unit hindsight.service -f
```

Recent errors only:

```bash
journalctl --user-unit hindsight.service --since today -p err
```

Both PostgreSQL and Hindsight are enabled at boot. The Hindsight unit uses `Restart=on-failure`. Its unit orders startup after `cicero-home-ai.service`, but the Hindsight process can still start and report database health when the llama.cpp router is unavailable because LLM connections are opened lazily.

## Health and API discovery

Health check:

```bash
curl -fsS http://127.0.0.1:8888/health
```

This endpoint verifies Hindsight and database-pool health; it does **not** verify the configured LLM. Check the router separately:

```bash
curl -fsS http://127.0.0.1:8081/health
curl -fsS http://127.0.0.1:8081/v1/models
```

Hindsight 0.8.6 also exposes `POST /v1/default/banks/{bank_id}/health/llm`, but this installation leaves it disabled. It returns HTTP 404 unless `HINDSIGHT_API_ENABLE_BANK_LLM_HEALTH=true` is configured. Retain, Recall, consolidation, and Reflect do not require that optional endpoint to be enabled.

OpenAPI schema:

```bash
curl -fsS http://127.0.0.1:8888/openapi.json
```

The default API namespace is exposed under `/v1/default`.

## PostgreSQL access

The local `gaperton` Unix account maps to the restricted PostgreSQL `gaperton` role through peer authentication:

```bash
psql --dbname hindsight
```

Useful checks:

```sql
SELECT current_user, current_database();
SELECT extname, extversion
FROM pg_extension
WHERE extname IN ('vector', 'pg_trgm')
ORDER BY extname;
```

The role is not a superuser and cannot create roles or databases. Public connection access to the `hindsight` database has been revoked. PostgreSQL listens only on localhost. The 2026-08-02 audit verified both 1024-dimensional embedding columns, both HNSW embedding indexes, and zero banks, memory units, or mental models after test cleanup.

## Backups

No scheduled backup job is configured yet. Create a logical backup with:

```bash
install -d -m 700 /home/gaperton/backups/hindsight
pg_dump --dbname=hindsight --format=custom \
  --file="/home/gaperton/backups/hindsight/hindsight-$(date +%Y%m%d-%H%M%S).dump"
```

List a dump before restoring:

```bash
pg_restore --list /home/gaperton/backups/hindsight/hindsight-TIMESTAMP.dump
```

Restore into an empty database only after stopping Hindsight. A typical restore must be run by a PostgreSQL administrator because replacing the database is destructive. Keep the dump, Hindsight version, embedding model, and vector dimension together in operational records.

## Verified behavior

### Active Qwen MoE installation audit

With the configured `qwen3.6-35b-a3b` Q5_K_XL model, strict schemas, thinking disabled, and two router slots, a temporary-bank test passed:

| Operation | Result | Latency |
| --- | --- | ---: |
| Retain | strict-schema extraction passed | 11.563 s |
| Recall | Russian query retrieved the English access-code memory | 0.956 s |
| Reflect | returned the exact access code | 8.691 s |

The test bank was deleted afterward, and PostgreSQL returned to zero banks and zero memory units. This is focused ad-hoc verification, not a benchmark suite. During the audit the secondary router was started temporarily and stopped afterward; the normal `cicero-home-ai.service` remains responsible for port 8081 during regular operation.

### Earlier multilingual retrieval matrix

An earlier six-document smoke corpus, run before the active Qwen MoE switch, included Russian and English facts plus similar distractors. The following retrieval directions all returned the correct top result:

| Direction | Query target | Recall latency |
| --- | --- | ---: |
| Russian to Russian | Anna's veterinarian location and weekday | 1.255 s |
| English to English | Quarterly architecture meeting room | 0.834 s |
| English to Russian | Marina's Aurora backup location | 0.805 s |
| Russian to English | Daniel's telescope access code | 1.016 s |

Observed BGE reranker time for two to four candidates was 0.536-1.079 seconds on CPU. Retain took 26.280 seconds, consolidation completed in about 24 seconds, and Reflect returned the exact English access code from a Russian question in 17.577 seconds.

A service restart preserved the memories and cross-language recall. Consolidation translated one Russian fact into an equivalent English observation; the meaning remained correct. The smoke-test bank was deleted after verification, leaving zero banks and zero memory units.

## Resource footprint

After the multilingual models were loaded and exercised:

- Hindsight RSS: approximately 4.0 GiB
- Hugging Face cache: approximately 6.6 GiB, including current and previously used models
- Hindsight virtual environment: approximately 2.1 GiB
- Inactive embedded pg0 rollback directory: approximately 139 MiB
- BGE model cold start: approximately 1 minute 50 seconds during the first download and load
- Warm restarts still load both models from disk and are slower than the former small-model setup

The models are forced onto CPU so both Radeon GPUs remain dedicated to llama.cpp.

## Security notes

- Do not bind Hindsight or PostgreSQL to a LAN interface without adding authentication, firewall rules, and TLS as appropriate.
- Keep `/home/gaperton/.config/hindsight/hindsight.env` mode `0600`.
- Do not place credentials in this repository.
- Hindsight's model cache contains downloaded public model weights, not application memories.
- PostgreSQL is the authoritative active data store; do not treat the old pg0 directory as a current backup.

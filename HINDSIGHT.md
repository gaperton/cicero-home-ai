# Hindsight server

This machine runs a LAN-accessible Hindsight memory server backed by the localhost-only Ubuntu PostgreSQL service and the secondary llama.cpp router.

## Architecture

- Hindsight API: `http://cicero.local:8888` on the trusted LAN; `http://127.0.0.1:8888` locally
- PostgreSQL: `127.0.0.1:5432` and the local Unix socket
- LLM: secondary llama.cpp router at `http://127.0.0.1:8081/v1`
- LLM model: `gemma4-26b-a4b`
- LLM router config: `models-1.ini`, MoE-only, two inference slots
- Embeddings: `BAAI/bge-m3`, local CPU inference
- Reranker: `BAAI/bge-reranker-v2-m3`, local CPU inference
- Database: `hindsight`
- PostgreSQL role: `gaperton`, authenticated through Unix-socket peer authentication

Hindsight and the llama.cpp routers are LAN-accessible at `cicero.local`. PostgreSQL remains bound to localhost. The secondary router is excluded from Open WebUI and reserved for Hindsight and direct API clients. Hindsight does not contain or require a PostgreSQL password.

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

### Local Reflect safety patch

Hindsight 0.8.6 leaves intermediate Reflect `call_with_tools` requests without an output-token limit. It also discards the OpenAI-compatible `reasoning_content` returned with a Gemma tool call instead of replaying it in the next assistant tool-call message, even though Gemma 4's chat template requires that history. The missing history can make follow-up turns malformed; independently, the missing token ceiling allowed one malformed call to generate more than 60,000 tokens, exceed Hindsight's 300-second wall timeout, and continue occupying a llama.cpp slot after the HTTP request had failed.

The installed package is patched to cap Reflect tool-call completions at 4,096 tokens while preserving smaller caller-provided limits, and to preserve/replay `reasoning_content` across OpenAI-compatible tool turns. The reproducible patch is stored at `patches/hindsight-0.8.6-reflect-tool-cap.patch`; its regression test is `/home/gaperton/.local/share/hindsight/tests/test_reflect_tool_cap.py`. A Hindsight package upgrade may overwrite the installed patch. Re-check upstream behavior and either remove the local patch when fixed upstream or reapply it from the `site-packages` directory before restarting the service.

The `reasoning_content` change was verified against the live llama.cpp response and with five repeated two-iteration Reflect workflows. All five returned the correct database and role in 55.676–68.890 seconds (median 55.931 seconds), but one workflow still needed a bounded retry after a `peg-gemma4` HTTP 500. Preserving the history is therefore a protocol-correctness fix, not a complete cure for Gemma's parser/generation failures; retain the token cap.

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
- Model: `gemma4-26b-a4b`
- Quantization: `UD-Q6_K_XL`
- Hindsight LLM concurrency: 2
- Router slots: 2, with 131072 tokens per slot when this model is loaded
- Continuous batching: enabled
- Timeout: 300 seconds
- Strict structured schemas: enabled
- Gemma speculative decoding: disabled because every locally tested draft depth reduced generation throughput

The secondary router also offers `qwen3.6-35b-a3b` at `UD-Q5_K_XL` with `draft-mtp` depth 2. When Qwen is selected, thinking is disabled with `chat_template_kwargs.enable_thinking=false` because reasoning tokens can exhaust Hindsight's bounded structured-output calls before Qwen emits the required result.

The saved Qwen Q5_K_XL benchmark validates MTP depth 2 for generation throughput: 109.51 to 134.10 tokens/s, while prompt throughput fell from 368.73 to 312.94 tokens/s. The Hindsight comparison below shows that higher raw decode throughput does not guarantee reliable or lower-latency Reflect behavior.

Hindsight's strongest official local recommendation is `gpt-oss-20b`, which is not currently installed as a llama.cpp preset.

## Service management

Check status:

```bash
systemctl --user status hindsight.service
systemctl status postgresql.service
curl -fsS http://cicero.local:8888/health
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
curl -fsS http://cicero.local:8888/health
```

This endpoint verifies Hindsight and database-pool health; it does **not** verify the configured LLM. Check the router separately:

```bash
curl -fsS http://127.0.0.1:8081/health
curl -fsS http://127.0.0.1:8081/v1/models
```

Hindsight 0.8.6 also exposes `POST /v1/default/banks/{bank_id}/health/llm`, but this installation leaves it disabled. It returns HTTP 404 unless `HINDSIGHT_API_ENABLE_BANK_LLM_HEALTH=true` is configured. Retain, Recall, consolidation, and Reflect do not require that optional endpoint to be enabled.

OpenAPI schema:

```bash
curl -fsS http://cicero.local:8888/openapi.json
```

The default API namespace is exposed at `http://cicero.local:8888/v1/default`.

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

### Gemma versus Qwen Hindsight comparison (2026-08-02)

A controlled operation-level comparison used the same Hindsight configuration, three-item bilingual memory workload, exact access-code checks, strict schemas, CPU embedding and reranking models, two router slots, and the deployed GGUF presets. Each workflow performed Retain, Russian-to-English Recall, Reflect, and consolidation, then deleted its temporary bank. Reflect was placed before explicit consolidation so the operations could be timed independently; Hindsight's automatic consolidation can still overlap them.

Gemma 4 26B-A4B Q6_K_XL completed one warm-up and all three measured workflows correctly:

| Operation | Measured runs | Median |
| --- | --- | ---: |
| Retain | 7.583 / 7.450 / 7.519 s | 7.519 s |
| Recall | 0.720 / 0.855 / 0.772 s | 0.772 s |
| Reflect | 6.428 / 7.051 / 8.077 s | 7.051 s |
| Consolidation | 5.022 / 5.020 / 4.017 s | 5.020 s |
| LLM-heavy workflow | 19.033 / 19.521 / 19.613 s | 19.521 s |
| Complete workflow | 19.760 / 20.382 / 20.392 s | 20.382 s |

All three recalls retrieved the exact English access code from the Russian query, all Reflect calls returned the exact code, and all consolidations completed. Across the three measured workflows, llama.cpp handled 27 internal LLM calls, 19,085 evaluated prompt tokens, and 3,418 generated tokens. Weighted throughput was 979.1 prompt tokens/s and 79.8 generated tokens/s; median per-call generation throughput was 72.5 tokens/s. These rates include real two-slot overlap and schema-constrained Hindsight requests rather than an isolated decode benchmark.

Qwen3.6 35B-A3B Q5_K_XL with MTP depth 2 produced one valid warm-up workflow:

| Operation | Valid Qwen reference |
| --- | ---: |
| Retain | 8.417 s |
| Recall | 1.026 s |
| Reflect | 18.385 s |
| Consolidation | 1.009 s |
| LLM-heavy workflow | 27.810 s |
| Complete workflow | 28.844 s |

Qwen then failed the validity gate twice on the same data: one Reflect after consolidation and one Reflect before consolidation both ran for 300 seconds and returned HTTP 504. The first runaway generated more than 20,000 tokens without terminating. Completed pre-failure calls decoded at about 149.8 tokens/s, but that higher raw rate did not produce a usable result. Only one of three attempted Qwen workflows was valid, so there is no defensible three-run Qwen median.

Gemma's median complete workflow was 29.3% faster than the one valid Qwen reference, while Retain was 10.7% faster and Reflect was 61.6% faster. Do not compare the explicit consolidation values directly: automatic consolidation overlapped the workflow, and Qwen's long Reflect gave it more time to finish in the background before the explicit consolidation poll.

Assessment: Gemma's speed is operationally good for Hindsight on this host. Recall stayed below 1 second, Retain below 8 seconds, Reflect below 9 seconds, and the full workflow was stable around 20 seconds. Gemma is the preferred Hindsight model from this test because it was both faster end to end and reliable. Hindsight now persistently selects `gemma4-26b-a4b`.

The earlier one-memory Qwen smoke test passed Retain in 11.563 seconds, Recall in 0.956 seconds, and Reflect in 8.691 seconds, but it did not expose the richer workflow's runaway Reflect behavior. These are focused ad-hoc integration measurements, not a canonical benchmark suite.

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

- Hindsight listens on all interfaces for trusted-LAN access and has no application-level authentication or TLS in this deployment. Block port 8888 from untrusted networks and never forward it directly to the internet.
- PostgreSQL remains localhost-only; do not expose port 5432 to the LAN.
- Keep `/home/gaperton/.config/hindsight/hindsight.env` mode `0600`.
- Do not place credentials in this repository.
- Hindsight's model cache contains downloaded public model weights, not application memories.
- PostgreSQL is the authoritative active data store; do not treat the old pg0 directory as a current backup.

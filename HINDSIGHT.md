# Hindsight server

This machine runs a LAN-accessible Hindsight memory server backed by the localhost-only Ubuntu PostgreSQL service and the secondary llama.cpp router.

## Architecture

- Hindsight API: `http://cicero.local:8888` on the trusted LAN; `http://127.0.0.1:8888` locally
- PostgreSQL: `127.0.0.1:5432` and the local Unix socket
- LLM: secondary llama.cpp router at `http://127.0.0.1:8081/v1`
- LLM model: `gpt-oss-20b`
- LLM router config: `models-1.ini`; the secondary router allows two resident models so the LLM and the reranker can coexist
- Embeddings: `BAAI/bge-m3`, local CPU inference
- Reranker: `qwen3-reranker-0.6b`, Q8_0 GGUF on Vulkan1 through llama.cpp's `/v1/rerank` endpoint
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

### No local patches — stock 0.8.6

**This installation runs unmodified Hindsight 0.8.6**, verified end to end on 2026-08-03 with no patches applied; see the operation benchmark below for current figures. Keep it that way: a `pip install -U` silently reverts any local edit to `site-packages`, and there is no CI here to catch the drift.

Two local patches existed and were both removed on 2026-08-03:

- **Reflect tool-call token cap.** Capped intermediate `call_with_tools` requests (4,096, later 1,024 tokens). Written for Gemma, whose `peg-gemma4` tool-call path could generate 60,000+ tokens, exceed the 300-second wall timeout, and keep occupying a llama.cpp slot after the HTTP request had failed. Removed because it truncates a tool call into a malformed one rather than raising, and because the cap counts gpt-oss's reasoning tokens too.
- **`reasoning_content` replay.** Preserved the model's own analysis across assistant tool-call turns. Not required: llama.cpp maps `reasoning_content` onto the gpt-oss template's `thinking` field (`common_chat_params_init_gpt_oss` in `common/chat.cpp`), and the harmony template renders it only under `{%- elif message.thinking and not future_final_message.found %}`. When the field is absent that branch simply does not fire — the prompt stays valid and nothing raises. The patch bought protocol fidelity (harmony is designed around the model seeing its own intra-turn analysis), never correctness, and the benefit was never measured against gpt-oss.

Note that one hazard is real but handled upstream: the harmony template raises if an assistant message with tool calls carries *both* `content` and `thinking`. llama.cpp erases `content` in that case, so it cannot be tripped from Hindsight.

If a future model genuinely needs either behavior, re-derive the patch rather than restoring these — both were written against Gemma-era failure modes that no longer describe this deployment.

### Corrupt GGUF incident, 2026-08-03

The `gpt-oss-20b-UD-Q8_K_XL.gguf` download was silently corrupt: **the file size matched HuggingFace's to the byte** (13,195,442,368) while its sha256 did not (`91d8d123…fc981` on disk vs `b97fa9f3…ec239` published). Nothing detected it, because `hf download` skips any file whose recorded metadata matches and never re-hashes the bytes.

Symptoms, all downstream of the bad weights and all misleading:

- Reflect generated 29,370+ tokens and never terminated, exactly mimicking the Gemma runaway the removed token cap was written for
- `/v1/chat/completions` returned HTTP 500 `The model produced output that does not match the expected peg-native format` — even for "What is 2+2?"
- Hindsight's 512-token startup connection check failed with `finish_reason=length`, empty content

The diagnostic that cut through it was raw `/completion`, which bypasses the chat template and the PEG parser: the model answered `" Paris."` correctly and then collapsed into `tradem tradem tradem…`. That localises the fault to generation itself, ruling out Hindsight, the tool protocol, and the parser in one step. Quantized KV cache, `batch-size`/`ubatch-size`, and sampling parameters were each independently excluded — including gpt-oss's official `temp 1.0 / top_p 1.0 / top_k 0`, which degenerated identically.

After re-downloading, the same captured `reflect_tool_call` payload that had run to 29,370 tokens returned a correct tool call in **52 tokens / 2.7 s**.

**Verify the hash after any model download.** Size and a successful load prove nothing:

```bash
sha256sum models/GPT-OSS-20B/gpt-oss-20b-UD-Q8_K_XL.gguf
curl -fsS "https://huggingface.co/api/models/unsloth/gpt-oss-20b-GGUF/tree/main?recursive=1" \
  | python3 -c "import json,sys; [print(f['path'], f.get('size'), (f.get('lfs') or {}).get('oid')) for f in json.load(sys.stdin) if f['path'].endswith('.gguf')]"
```

To force a re-download, delete both the file and `.cache/huggingface/download/<file>.metadata` — deleting the file alone is not always enough.

One llama.cpp behavior seen here is real and independent of the corruption: **a non-streaming client disconnecting does not stop generation.** The abandoned Reflect kept decoding to 30k tokens holding a slot. Streaming clients do abort. This is the standing argument for bounding pathological generations somewhere, if one ever recurs on healthy weights.

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

Hindsight uses the multilingual `Qwen3-Reranker-0.6B` Q8_0 GGUF preset in `models-1.ini`. Hindsight 0.8.6 is directly compatible with llama.cpp reranking: its `litellm` reranker provider posts to `{API_BASE}/rerank`, so an API base ending in `/v1` reaches llama.cpp's `/v1/rerank`. No protocol adapter or Hindsight code patch is required.

Persistent Hindsight settings in `/home/gaperton/.config/hindsight/hindsight.env`:

```dotenv
HINDSIGHT_API_RERANKER_PROVIDER=litellm
HINDSIGHT_API_RERANKER_LITELLM_API_BASE=http://127.0.0.1:8081/v1
HINDSIGHT_API_RERANKER_LITELLM_MODEL=reranker
HINDSIGHT_API_RERANKER_LITELLM_MAX_TOKENS_PER_DOC=3072
HINDSIGHT_API_RERANKER_MAX_CANDIDATES=100
```

The corresponding `models-1.ini` preset enables `reranking = true`, offloads all layers to Vulkan1, uses eight parallel slots, sets `ctx-size` to 32768, and sets `batch-size` and `ubatch-size` to 8192. The large physical batch is required for real Hindsight candidates: llama.cpp's default 512-token physical batch returned HTTP 500 when a query-document pair exceeded it, and reranking is non-causal so a pair must fit in a single physical batch. `run.sh` overrides the secondary router to `--models-max 2`, allowing `gpt-oss-20b` and `qwen3-reranker-0.6b` to remain loaded together instead of evicting each other on every Recall/LLM transition.

`HINDSIGHT_API_RERANKER_LITELLM_MAX_TOKENS_PER_DOC=3072` is a second, client-side guard on the same limit. Hindsight sends every candidate in one request and calls `raise_for_status()`, so a single overlong document would fail the whole Recall's reranking; this truncates it instead. Keep it below the per-slot context to leave room for the query and chat template.

The previous CPU fallback was `BAAI/bge-reranker-v2-m3`, configured with the `local` provider, forced CPU execution, FP16 disabled, length-bucket batching, and maximum concurrency 2. To roll back, replace the three active LiteLLM variables above with the following values, restart `hindsight.service`, and confirm the effective process environment and a live Recall:

```dotenv
HINDSIGHT_API_RERANKER_PROVIDER=local
HINDSIGHT_API_RERANKER_LOCAL_MODEL=BAAI/bge-reranker-v2-m3
HINDSIGHT_API_RERANKER_LOCAL_FORCE_CPU=true
HINDSIGHT_API_RERANKER_LOCAL_FP16=false
HINDSIGHT_API_RERANKER_LOCAL_BUCKET_BATCHING=true
HINDSIGHT_API_RERANKER_LOCAL_MAX_CONCURRENT=2
```

The low CPU concurrency avoids thrashing on the Ryzen 7 5700X. Changing the reranker does not require re-embedding stored memories.

### Embedding-dimension warning

Changing embedding models after memories exist may require re-embedding all stored memories. Hindsight only changes the PostgreSQL vector dimension automatically when the affected tables contain no embeddings.

During initial setup, Hindsight safely migrated these empty columns from `vector(384)` to `vector(1024)` and rebuilt their HNSW indexes:

- `memory_units.embedding`
- `mental_models.embedding`

Do not change the embedding model casually after storing real data.

## LLM configuration

Hindsight uses the secondary llama.cpp router so it does not contend with the primary endpoint:

- Endpoint: `http://127.0.0.1:8081/v1`
- Model: `gpt-oss-20b` — Hindsight's own strongest official local recommendation, and the faster of the two working profiles (Reflect 22-30 s vs Gemma's 68-83 s). `gemma4-26b-a4b-qat` also works as of 2026-08-08 once its two mitigations are in place; see "Gemma 4: rejection, root cause, and fix" below and `notes/hindsight-gemma.md`.
- Quantization: `UD-Q8_K_XL`
- Hindsight LLM concurrency: 3 (`HINDSIGHT_API_LLM_MAX_CONCURRENT=3`) — matches the router's 3 slots exactly. The per-operation override vars (`HINDSIGHT_API_RETAIN_LLM_MAX_CONCURRENT`, `..._REFLECT_...`, `..._CONSOLIDATION_...`) exist in the Hindsight codebase but are unset here, so every LLM call (Retain, Reflect, Consolidation) shares the single global semaphore of 3 — there is no way for Hindsight to oversubscribe the slots.
- Router slots: 3; `ctx-size = 300000` (100,000 tokens/slot)
- Output bounding: `HINDSIGHT_API_LLM_EXTRA_BODY='{"chat_template_kwargs":{"reasoning_effort":"low"}}'`. This is gpt-oss's native mechanism and replaces the removed Reflect token cap. `enable_thinking` is a Gemma/Qwen flag and is a no-op for gpt-oss.
- Continuous batching: enabled
- Timeout: 300 seconds
- Strict structured schemas: enabled
- Speculative decoding: disabled because every locally tested draft depth reduced generation throughput

### Prefill dominates the LLM cost

Hindsight's llama.cpp traffic is almost entirely prompt evaluation. Measured on the live server (2026-08-03):

| Prompt tokens | Prompt eval | Generated |
| ---: | ---: | ---: |
| 24,317 | 9.71 s @ 2,505 tok/s | 251 tokens @ 132 tok/s |
| 23,547 | 9.18 s @ 2,565 tok/s | — |
| 14,398 | 5.28 s @ 2,725 tok/s | 110 tokens @ 132 tok/s |
| 2,146 | 0.66 s @ 3,245 tok/s | 53 tokens @ 148 tok/s |

Roughly 90% of a typical Retain or Consolidation call is prompt processing, so prefill throughput — not decode throughput — is the lever for Hindsight latency. The preset therefore sets `batch-size = 4096` and `ubatch-size = 2048` instead of llama.cpp's 2048/512 defaults.

llama.cpp's slot prefix cache does work where it can (`f_sim_best = 1.000` produces 1-token prompt evals on repeated prefixes), but Retain and Consolidation prompts carry distinct content each call and are fully reprocessed.

The secondary router previously also offered `gemma4-26b-a4b` and `qwen3.6-35b-a3b`; both were removed from `models-1.ini`. With `--models-max 2` any client requesting a third model on :8081 would evict `gpt-oss-20b` or the reranker mid-workload.

The saved Qwen Q5_K_XL benchmark validated MTP depth 2 for generation throughput: 109.51 to 134.10 tokens/s, while prompt throughput fell from 368.73 to 312.94 tokens/s. The Gemma/Qwen comparison below shows that higher raw decode throughput does not guarantee reliable or lower-latency Reflect behavior.

### Reranker (GPU, replaces the CPU cross-encoder)

Hindsight's reranker is `qwen3-reranker-0.6b` (Q8_0 GGUF, `ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF`), served from the same Vulkan1 router as the LLM via llama.cpp's `/v1/rerank` endpoint, wired in through Hindsight's `litellm` reranker provider:

```
HINDSIGHT_API_RERANKER_PROVIDER=litellm
HINDSIGHT_API_RERANKER_LITELLM_API_BASE=http://127.0.0.1:8081/v1
HINDSIGHT_API_RERANKER_LITELLM_MODEL=reranker
```

This replaced the local CPU `BAAI/bge-reranker-v2-m3` path, which was the dominant cost in every slow Recall (one call spent 34.7s of its 34.88s total in the `[4] Reranking [cross-encoder]` stage alone).

- Preset: `models-1.ini`, `[reranker]` (`qwen3-reranker-0.6b`) — `kv-unified = true`, `parallel = 8`, `ctx-size = 32768`, `batch-size = 4096`, `ubatch-size = 4096`
- Requires `--models-max 2` on the Vulkan1 `llama-server` instance (set explicitly in `run.sh`, overriding `.env`'s global `--models-max 1`) so the LLM and the reranker stay resident simultaneously instead of evicting each other on every call — this is a **startup-only** flag; changing it needs `systemctl --user restart cicero-home-ai.service`, not just a router preset reload
- `ctx-size` is a **total**, divided across `parallel` slots. Read it per slot: the per-slot figure is the hard ceiling on one query+document pair, and llama.cpp rejects the **entire** rerank request with HTTP 400 `exceed_context_size_error` if any single pair exceeds it — not just the offending document. An earlier `ctx-size = 8192` with `parallel = 8` therefore gave 1,024 tokens per pair; verified live on 2026-08-03 with a three-document batch where one 2,115-token document failed all three. The longest stored `memory_units.text` at that time was 2,490 characters (~700 tokens), plus the `context: ` prefix Hindsight prepends — under the old ceiling, but with almost no headroom.
- `batch-size`/`ubatch-size` must stay bounded (8192, not higher) and `ubatch-size` must remain **≥ the per-slot context**, since reranking is non-causal and a pair has to fit in a single physical batch. An earlier attempt at 8192 alongside `parallel=8` was fine, but pushing `parallel` to 32 with a proportionally larger `ctx-size` blew the combined footprint over the card and dumped ~30 GiB into GTT, silently degrading the LLM's own throughput (prompt processing dropped from ~200 tok/s to ~134 tok/s) alongside the reranker.

#### Reranker tuning (2026-08-03)

Benchmarked with 100 real `hermes` documents rather than synthetic text, since cost turns out to depend on document length.

| Change | Result |
| --- | --- |
| `kv-unified = true` | **31.3 -> 22.0 ms/doc (-29%)** |
| `parallel` 8 -> 32 | no change (22.0 vs 21.7 ms/doc) |
| `batch`/`ubatch` 8192 -> 4096 | no change; smaller buffers are free |
| Truncating documents to 256 tokens | 3% faster, rankings identical |

End-to-end `hermes` Recall: **4.37 s -> 3.14 s**.

Three findings worth keeping:

- **`parallel` is not a throughput lever.** Hindsight sends every candidate in one request and llama.cpp processes them serially — latency is exactly linear in document count from 1 to 300 documents. Eight slots exist only to serve concurrent Recalls, not to speed up one.
- **`kv-unified` also removes the per-slot cliff.** `n_ctx_slot` becomes the full `ctx-size` instead of `ctx-size / parallel`, so the earlier failure mode — `ctx-size 8192 / parallel 8` silently yielding 1024 tokens per pair — cannot recur. The ceiling on one query+document pair is now `ubatch-size`: verified live, ~3100 tokens passes and ~5175 fails with `input is too large to process. increase the physical batch size`. It still fails the whole request, so `MAX_TOKENS_PER_DOC=3072` must stay below `ubatch-size`.
- **`kv-unified` does not transfer to the LLM.** Tried on `gpt-oss-20b` and measured worse: 3-concurrent wall time 19.88 s median with it off versus 21.18 s with it on (4 repetitions each), sequential prefill and decode identical. The reranker benefits because it processes many short sequences through a shared buffer; gpt-oss runs a few long causal sequences that contend for one instead. Left off for the LLM.
- **Cost is driven by document length, not count** — 14 tokens costs 14 ms/doc, 560 tokens costs 442 ms/doc. Real memories average ~80 tokens (p95 140, max ~700), which is why truncation buys nothing here. If the corpus ever gains long documents, `MAX_TOKENS_PER_DOC` becomes a real latency lever rather than just a safety backstop.

**Measured impact**: per-candidate reranking cost dropped from ~788ms (CPU cross-encoder, 44 candidates in 34.7s) to ~48-50ms (GPU reranker) — roughly a 16-20x per-candidate speedup, verified both on a synthetic 150-document benchmark and against live Recall calls. Real end-to-end Recall latency did **not** drop by the same factor, because Hindsight caps reranking at `HINDSIGHT_API_RERANKER_MAX_CANDIDATES` (config default `DEFAULT_RERANKER_MAX_CANDIDATES = 300`, in `memory_engine.py`) — candidates beyond that are pre-filtered by RRF score before the cross-encoder ever sees them, so this ceiling does not grow with bank size. A full 300-candidate Recall against the live `hermes` bank (433 candidates merged, 133 pre-filtered) measured ~14.8-15.1s post-fix, down from 30-70s+ observed pre-fix. Lowering `HINDSIGHT_API_RERANKER_MAX_CANDIDATES` below 300 is the remaining lever if faster Recall is needed, at the cost of trusting RRF's cheaper ranking not to bury a relevant fact outside the reduced top-N.

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

### Vulkan GPU reranker deployment (2026-08-03)

The production `hermes` bank exposed a CPU reranking bottleneck that the earlier disposable-bank tests did not represent. With `BAAI/bge-reranker-v2-m3` on CPU, a Recall reranked 45 candidates in 27.483 seconds and took 27.694 seconds end to end; reranking consumed 99.2% of the request.

After switching Hindsight to `qwen3-reranker-0.6b` through llama.cpp, the same fixed question — “Which two GPU models are installed in the cicero host?” — produced these live measurements on the Hermes tool path:

| Run | Candidates | Reranking | Total Recall |
| --- | ---: | ---: | ---: |
| First successful GPU run | 59 | 4.639 s | 4.874 s |
| Warm GPU run | 59 | 3.686 s | 3.901 s |

The warm result is 7.46× faster in reranking and 7.10× faster end to end than the CPU baseline, an 85.9% reduction in total Recall latency. The correct hardware fact — two Radeon AI PRO R9700 GPUs — ranked first. Retrieval still returned many historical and superseded facts, so corpus cleanup, candidate limits, and final-output thresholds remain separate quality work; GPU acceleration does not solve corpus pollution.

A focused ad-hoc verifier subsequently exercised the configuration file, effective Hindsight process environment, both health endpoints, direct English/Russian reranking, model co-residency, and full HTTP Recall. It passed with Gemma and Qwen3-Reranker simultaneously loaded. That direct HTTP request reranked 256 candidates in 11.231 seconds and completed in 11.453 seconds (11.458 seconds at the verifier wall clock), so it is not directly comparable to the 59-candidate Hermes-tool measurements. The verifier was temporary and this repository has no canonical automated test suite.

Operational verification commands:

```bash
pid=$(systemctl --user show hindsight.service -p MainPID --value)
tr '\0' '\n' < "/proc/$pid/environ" | grep '^HINDSIGHT_API_RERANKER_'
curl -fsS http://127.0.0.1:8081/v1/models
curl -fsS http://127.0.0.1:8081/v1/rerank \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-reranker-0.6b","query":"GPU model","top_n":2,"documents":["AMD Radeon AI PRO R9700","PostgreSQL database"]}'
```

### gpt-oss-20b operation benchmark (2026-08-03)

Run on stock 0.8.6 with verified-good weights and the custom chat template, using the same methodology as the Gemma/Qwen comparison below: bilingual three-item workload with an exact access code, one warm-up plus three measured workflows, each on its own disposable bank, deleted afterwards. A workflow counts only if Recall retrieves the code from a Russian query and Reflect states it. All measured workflows were valid.

| Operation | Measured runs | Median |
| --- | --- | ---: |
| Retain | 3.631 / 4.324 / 4.283 s | 4.283 s |
| Recall (disposable bank) | 0.237 / 0.375 / 0.191 s | 0.237 s |
| Reflect | 5.175 / 4.715 / 4.763 s | 4.763 s |
| Complete workflow | 9.047 / 9.417 / 9.241 s | 9.241 s |

Production `hermes` bank, three runs, all correct. The benchmark issues only Recall and Reflect against it and stores nothing (verified: no benchmark content appears in `hermes`), but note that `hermes` is a live bank other clients write to concurrently -- it grew 477 -> 502 facts during this session -- so its figures carry more noise than the disposable-bank ones and are not exactly reproducible:

| Operation | Runs | Median |
| --- | --- | ---: |
| Recall | 2.980 / 3.249 / 2.931 s | 2.980 s |
| Reflect | 14.035 / 21.877 / 32.949 s | 21.877 s |

For comparison, the same benchmark on the **stock** template, before the fix described below: Reflect 12.553 s median on a disposable bank and 44.143 s on `hermes`, with runs spread 7.9-14.6 s and 24.0-53.8 s respectively. The custom template makes Reflect ~3.5x faster on small banks and ~21% faster on `hermes`, and collapses the variance.

A note on the harness: the validity gate originally compared the access code as a plain ASCII substring, and gpt-oss renders it with a non-breaking hyphen (`ORION-7741`, U+2011). That marked correct answers INVALID and silently reduced the sample to a single run. `benchmark/bench-hindsight.py` now NFKC-normalises and folds typographic dashes and spaces before comparing. Any future check against model output should do the same.

Two measurement caveats, both of which invalidate naive readings:

- **The explicit `POST /consolidate` call is not a measurement.** It returned in 0.004 s because automatic consolidation is queued during Retain and had already run. Real consolidation cost must be read from the journal (`CONSOLIDATION COMPLETE`): 8.158 / 6.413 / 6.015 s for these workflows, at ~1.8–2.4 s per memory. Do not compare the 0.004 s figure to the Gemma table's 5.020 s.
- **The disposable-bank Recall figure (0.214 s) is not representative.** Three memories never reach the reranker's 300-candidate budget. The `hermes` figure of 13.380 s is the real one, and it is dominated by reranking, exactly as recorded in the GPU reranker section.

**Reflect latency is dominated by parse-retry, not by decode.** See below.

### Residual issue: intermittent `peg-native` parse failures

During the benchmark above, 26 requests failed with HTTP 500 `The model produced output that does not match the expected peg-native format` on **verified-good weights**. Distribution by scope:

| Scope | Failed attempts |
| --- | ---: |
| `reflect_tool_call` | 14 (attempt 1/4 ×5, 2/4 ×5, 3/4 ×4) |
| `verification` (startup check) | 2 |

Hindsight retries these, and every retry eventually succeeded — no workflow produced a wrong answer. The cost is latency and variance: `hermes` Reflect ranged 24.027 s (clean) to 53.781 s (retried), and the disposable-bank Reflect spread 7.918–14.649 s on identical input. The median Reflect figures above therefore include a retry tax rather than measuring generation speed.

This is distinct from the corrupt-GGUF incident, where *every* request failed this way including `"What is 2+2?"`.

**Root cause (investigated 2026-08-03).** Only one turn shape fails, and it fails reproducibly:

| Reflect turn | `tool_choice` | Tools | Result |
| --- | --- | ---: | --- |
| 1–3 (initial tool selection) | `required` | 1 | 200, always — 20/20 on replay |
| 4+ (after tool results accumulate) | *omitted* → auto | 4 | 500, ~92% of the time |

The model emits a malformed harmony channel header, conflating the `final` channel with a `commentary to=functions.done` tool call and duplicating `<|constrain|>`. Captured raw from `/completion` (which bypasses the parser), four consecutive generations on the same failing prompt:

```
<|channel|>final <|constrain|>commentary to=functions.done<|constrain|><|constrain|>json<|message|>{...}
<|channel|>commentary to=functions.done <|constrain|>json<|message|>{...}      <- the one valid form
<|channel|>final <|constrain|>answer<|message|>...
<|channel|>final <|constrain|>commentary to=functions.done<|constrain|>json<|message|>{...}
```

Why only the later turns: `common/chat.cpp` sets

```cpp
data.grammar_lazy = !(has_response_format || (has_tools && inputs.tool_choice == COMMON_CHAT_TOOL_CHOICE_REQUIRED));
```

`tool_choice=required` produces an **eager** grammar that constrains generation from the first token, so a malformed header is impossible. `auto` produces a **lazy** grammar that engages only once a trigger matches — and the hybrid header matches no trigger, so generation runs unconstrained and the PEG parser then rejects it. llama.cpp already carries a `stray_commentary` workaround for a neighbouring gpt-oss header quirk; this is the same family of defect, not yet covered.

**It is not tunable from configuration.** Measured success rate on the failing turn (n=12 each) and end-to-end Reflect median on `hermes` (n=3):

| Setting | Turn success | Reflect median |
| --- | ---: | ---: |
| `reasoning_effort=low` (current) | 8.3% | **44.14 s** |
| `reasoning_effort=medium` | 33.3% | 59.19 s |
| `reasoning_effort=high` | 50.0% | 104.64 s |
| `temp=1.0 top_p=1.0 top_k=0` | 25.0% | not measured |
| `temp=0.0` | 0.0% | not measured |
| `tool_choice=required` | 100.0% | not reachable from config |

Raising `reasoning_effort` genuinely reduces the failure rate but is **net worse end to end**: the extra reasoning tokens cost more than the retries they avoid. `low` is optimal despite having the worst per-call success rate. Keep it.

Correctness is not affected — every configuration answered correctly 3/3, because Hindsight retries and, if all four attempts fail, falls back to a plain no-tool call. That fallback did fire in testing: one Reflect exhausted its retries and produced its answer outside the tool loop.

### Fix: custom chat template (2026-08-03)

Sampling and reasoning effort cannot fix this, but the **prompt** can. Appending an explicit channel instruction to the system header takes the failing turn from 8.3% to 100% (12/12) in isolation, so the fix is delivered as a chat-template override — a server-side config change, not a Hindsight patch.

`templates/gpt-oss-20b-harmony.jinja` is the model's own template, extracted from the GGUF, with one line added inside the existing `{%- if tools -%}` block so it is emitted **only when tools are present**:

```jinja
{{- "\nCalls to these tools must go to the commentary channel: 'functions'." }}
{{- "\nYou must always respond by calling a tool. To give your answer, call the 'done' tool. Never answer directly and never emit the 'final' channel while tools are available." }}
```

Wired in through `chat-template-file` in the `[llm]` preset (`gpt-oss-20b` in `models-1-oss.ini`). Measured effect:

| Metric | Stock template | Custom template |
| --- | ---: | ---: |
| Failing-turn success (n=20) | 8.3% | **95.0%** |
| Reflect median, `hermes` | 44.14 s | **35.09 s** |
| Reflect spread | 24.0–53.8 s | 34.5–39.3 s |
| `peg-native` 500s per 4 Reflects | ~12 | **0** |

Reflect is 20% faster and, more usefully, its variance nearly disappears — the spread was almost entirely retry noise. Answers stayed correct throughout.

**Maintenance:** the template is a copy of the model's own, so it must be re-extracted and re-patched after a model update, or it will silently drift from what the weights expect. Extract with:

```bash
cd llama.cpp && PYTHONPATH=gguf-py python3 -c "
from gguf import GGUFReader
r = GGUFReader('../models/GPT-OSS-20B/gpt-oss-20b-UD-Q8_K_XL.gguf')
f = next(x for x in r.fields.values() if 'chat_template' in x.name)
print(bytes(f.parts[f.data[0]]).decode())"
```

This is a workaround, not a cure. The upstream fixes remain: extend the gpt-oss PEG grammar to accept the hybrid header, or widen the lazy-grammar triggers to cover `<|channel|>final`. Sending `tool_choice=required` on later turns would also fix it but requires patching Hindsight, which this deployment deliberately does not do.

### Preset review against upstream guidance (2026-08-03)

Checked the `[llm]` preset (`gpt-oss-20b` in `models-1-oss.ini`) against Hindsight's own docs and llama.cpp's gpt-oss guide. Three things came out of it.

**1. Quantized KV cache is wrong for gpt-oss — fixed.** llama.cpp's gpt-oss guide advises against `--cache-type-k/v` quantization for this model, and it is measurably worse here:

| KV cache | Prefill (22k prompt) | Decode |
| --- | ---: | ---: |
| `q8_0` (previous `[*]` default) | 3073 tok/s | 132.5 tok/s |
| `f16` (current) | **3962 tok/s (+29%)** | 133.5 tok/s |

Decode is unaffected; prefill is what matters for this prompt-heavy workload. VRAM with both models resident is 19.05 GiB of 31.86 GiB, so it fits comfortably. Set in `[*]`, which also covers the reranker (verified working).

**2. `HINDSIGHT_API_LLM_REASONING_EFFORT` is a no-op for gpt-oss.** Hindsight's performance docs recommend `HINDSIGHT_API_LLM_REASONING_EFFORT=low`, but in 0.8.6 that value is only injected when `_supports_reasoning_model()` returns true, which matches `gpt-5`, `o1`, `o3` and some DeepSeek variants — **not** `gpt-oss`. Setting it here would do nothing. `HINDSIGHT_API_LLM_EXTRA_BODY` with `chat_template_kwargs.reasoning_effort` is the only route that reaches llama.cpp's harmony template, which is what this deployment uses. Do not "simplify" it to the documented variable.

**3. Preset items confirmed correct against upstream guidance:** `--jinja` required for tool calling (set in `[*]`); repetition penalties must be disabled (`repeat-penalty = 1.0`); flash attention recommended (`flash-attn = true`); `ubatch-size 2048` matches the guide's `-ub 2048`. Sampling params stay omitted because Hindsight sends per-operation temperatures.

#### Sampling and temperature

Effective sampling for `gpt-oss-20b`, established by capturing Hindsight's actual HTTP traffic through a logging proxy rather than reading the config:

| Operation | Configured | Actually sent |
| --- | --- | --- |
| Retain | `..._TEMPERATURE_RETAIN=0.1` | **0.1** |
| Reflect | `..._TEMPERATURE_REFLECT=0.2` | **nothing** |
| Consolidation | `..._TEMPERATURE_CONSOLIDATION=0.0` | **nothing** |

**Only Retain applies its configured temperature.** Reflect and Consolidation send no sampling parameters at all, so they run on llama.cpp's server defaults — temp 0.8, top-k 40, top-p 0.95, min-p 0.05. The two remaining `HINDSIGHT_API_LLM_TEMPERATURE_*` variables are inert for this deployment and should not be trusted to do anything. Hindsight also sends no `top_p`, `top_k` or `min_p` for any operation.

This diverges from gpt-oss's official recommendation (temp 1.0, top-p 1.0, top-k 0), but measurement says it does not matter: on the Reflect tool-call turn, with the custom chat template in place, **40/40 succeeded under all three of** llama.cpp defaults, `temp=0.2`, and `temp=1.0 / top_p=1.0 / top_k=100`. An earlier 16-sample run appeared to show differences (81–94%); that was noise, and the larger sample removed it.

`top_p`/`top_k`/`min_p` are therefore left at llama.cpp defaults. `temp = 0.2` **is** set in the preset, because it is the only working control for Reflect and Consolidation:

- Without it Consolidation runs at 0.8 although its configured intent is 0.0, so the same memories could consolidate differently run to run. The env var cannot fix this; the preset can. Retain still overrides with its own 0.1.
- 0.2 rather than 0.0 because greedy decoding is the classic repetition-loop trigger on this model.
- `repeat-penalty = 1.0` is correct and must stay. llama.cpp's gpt-oss guide is explicit that repetition penalties break this model, and clients enable them by default.

#### Applied: `HINDSIGHT_API_RERANKER_MAX_CANDIDATES=100`

Hindsight's docs recommend `100` for local deployments (default `300`). Measured on the live `hermes` bank across five varied English and Russian queries:

| Query | Recall @300 | Recall @100 | Facts returned | Top-10 overlap | Top-3 identical |
| --- | ---: | ---: | ---: | ---: | :---: |
| GPU models | 13.27 s | 4.37 s | 63 vs 63 | 10/10 | yes |
| Reranker history | 12.84 s | 4.63 s | 62 vs 58 | 7/10 | yes |
| Database (RU) | 12.51 s | 4.30 s | 63 vs 62 | 9/10 | yes |
| Gemma problems | 12.67 s | 4.56 s | 60 vs 59 | 10/10 | yes |
| Open WebUI config | 13.06 s | 5.05 s | 90 vs 80 | 10/10 | no |

Recall is ~3x faster and the head of the ranking is nearly unchanged — top-3 identical in four of five queries — but it is **not free**: up to 11% fewer facts are returned and one query's top-3 reordered. Facts that RRF ranks below 100 can no longer be rescued by the cross-encoder.

**Set to 100.** The tail it discards is largely the historical and superseded material this corpus is already known to carry, and Recall is the most frequently exercised operation. Reflect benefits too, because its tool calls invoke Recall internally: `hermes` Recall 13.207 s -> 4.367 s and Reflect 34.734 s -> 24.218 s. Raise it back to 300 if a lookup is ever found to miss a fact that RRF ranked below 100.

Also noted but not changed: Hindsight's docs suggest `HINDSIGHT_API_LLM_MAX_CONCURRENT=2` for local use and "leave at least one slot free per shared client". This deployment runs 3 against `parallel = 3`, so Hindsight can saturate the router. That is deliberate, but `:8081` does serve other clients, and a concurrent writer was observed during benchmarking — if the Hermes agent starts contending for slots, drop this to 2.

### Gemma 4: rejection, root cause, and fix (2026-08-06 → 08-08)

**Outcome first.** Gemma was rejected on 2026-08-06 because Reflect never
terminated on a real bank. The cause was found, fixed, and validated on
2026-08-08: **40/40 Reflects on `psychology` with zero hangs**, e2e 3/3 on every
probe, and zero calls anywhere near the `n-predict` backstop. It needs two
mitigations, both in place — the llama.cpp patch in `patches/` and
`reasoning-budget` in `models-1-gemma.ini`. gpt-oss remains production purely on
speed. Setup: `notes/hindsight-gemma.md`. The investigation below is kept because
several plausible-but-wrong diagnoses are recorded in it.

`gemma4-26b-a4b-qat` was re-tried as the Hindsight LLM and reverted the same day.
It is now an on-demand-only preset in `models-1.ini`. Do not promote it again
without reading this section.

**What prompted the retest.** The original rejection blamed llama.cpp #21375, and
the old Gemma preset never set `reasoning`, so it inherited llama.cpp's
`--reasoning auto` = ON. Turning thinking off looked like it might be the missing
piece: with `reasoning = off`, Retain and Consolidation stopped overgenerating
(output tokens fell from 1719–8242 to 130–400, Retain 31–37s to 4.6–11s).

**Where it fails.** Reflect on a real bank never terminates. Against the
1749-memory `psychology` bank it failed on every attempt, decoding past
28,000–47,000 tokens with no EOS until Hindsight's 300s timeout returned HTTP 504.
llama.cpp keeps generating after the client gives up, so each failure permanently
wedges a slot — one run left 2 of 3 slots occupied, degrading everything else on
the router until a restart.

Small banks hide this completely. A 3-item disposable bank passed
Retain/Recall/Reflect/Consolidate cleanly (Reflect 2.4s average, 55 output tokens
maximum). That is why the earlier `gemma-test-*` runs looked healthy. **Any future
model swap must be validated against `psychology` or another large bank, not just
the disposable-bank workflow** — `benchmark/e2e-psychology.py` does both.

**Not an agentic loop — this was checked directly.** The obvious innocent
explanation is that Reflect is agentic and Gemma simply takes many tool-call
turns. It is ruled out on two independent grounds. First, Hindsight caps Reflect
at `DEFAULT_REFLECT_MAX_ITERATIONS = 10`, so the loop is bounded by construction.
Second, and decisively, each agentic turn is a separate HTTP request and
therefore a separate llama.cpp task; the llama-server log shows a *single* task
id climbing monotonically — `task 54 | n_decoded = 307 … 33,525` across 130 log
lines, with `max_tokens: -1` and `n_predict: -1` in the slot params, i.e. nothing
capping generation but EOS. That is one request that never terminates, not ten
that each finish.

**The trigger is `tool_choice: "required"`.** Captured verbatim off the wire with
a logging proxy in front of the router (`HINDSIGHT_API_LLM_DEBUG_DUMP_4XX` is
useless here — it only fires on a 4xx, and this failure is a client-side wall
timeout with no HTTP error). Reconstructions had all terminated cleanly precisely
because they used `tool_choice: auto`. The captured hanging request is:

```
messages=4 (system 8934 ch, user 53, assistant tool_call, tool result 66959 ch)
tools=['recall']          <- a single tool; `done` is NOT offered on this turn
tool_choice="required"
```

Replayed byte-for-byte, with one variable changed:

| Replay | Result |
| --- | --- |
| verbatim, `tool_choice: "required"` | still generating at 150 s, 23,431 chars, tail `*_**_**_**_**…` |
| identical, `tool_choice: "auto"` | **6 s**, `finish_reason=stop`, clean 2,800-char answer |
| verbatim + `done` added to `tools` | still hangs — 14,032 chars, tail `______…` |

So it is not about which tools are offered, and not about context size. In
`common/chat.cpp` the Gemma 4 grammar for the required case is

```
start + zero_or_more(message) + scan_to_toolcall + tool_call
scan_to_toolcall = until("<|tool_call>")                      // unbounded
tool_call        = repeat(..., min = tool_choice==REQUIRED ? 1 : 0, ...)
grammar_lazy     = !(has_response_format || (has_tools && tool_choice==REQUIRED))
```

With `required`, `grammar_lazy` is false and `min = 1`, so a tool call is still
outstanding and EOS is never in the allowed set, while `scan_to_toolcall` lets the
model emit unlimited content on the way there. Gemma has already gathered its
evidence by this turn and wants to write the final answer as prose — it starts
doing exactly that, coherently, and then can never stop, degenerating into
single-token repetition. That is the collapse of google-deepmind/gemma#622
happening inside a state the grammar gives no exit from.

Hindsight reaches this state by design: `engine/reflect/agent.py` forces a
hierarchical retrieval sequence (`search_mental_models` → `search_observations` →
`recall`) for the first iterations, narrowing `tools` to the single forced tool
and sending `tool_choice` required. There is no env knob to disable the forcing
(`HINDSIGHT_API_REFLECT_LLM_STRATEGY` configures fallback models, not this), so
this is not tunable from configuration.

**Why gpt-oss is unaffected:** not luck, and not better instruction-following.
`common_chat_params_init_gpt_oss` already special-cases this exact situation and
drops its content-only alternative when the tool choice is required
(`return p.zero_or_more(start + any) + start + tool_call;` vs. the
`(tool_call | final_msg)` it uses otherwise). Its grammar makes the free-content
path unreachable, so the no-exit state cannot arise. `functionary_v3_2`
special-cases `REQUIRED` too. The gemma4 parser is the outlier that does not.

**A local patch fixes the grammar bug — but NOT all of the hangs.** Removing the
free-content branch from the gemma4 grammar when a tool call is required (mirroring
what gpt-oss already does) lives in
`patches/llamacpp-gemma4-required-toolcall.patch`, is re-applied automatically by
`build.sh`, and has an upstream writeup in
`llamacpp-gemma4-required-toolcall-PR.md`. It makes the captured request terminate
in 9.7 s with `finish_reason=tool_calls`, and takes `psychology` Reflect from 0/3
probes passing to 2/3.

**A second, unrelated failure remains that the patch does not touch.** Post-patch
e2e (2026-08-07, llama.cpp `4cf5cab65`) still lost one probe to a 300 s timeout.
That one is not the grammar: the session completed only two LLM calls (14.9 s
total) then hung on the third, which the wire capture shows is an **`auto`** turn —
`tool_choice: null`, 4 tools, ~132 KB prompt — where `grammar_lazy` is true and EOS
is freely available. The live slot showed `n_prompt = 95274` against the 100000
per-slot ceiling, with `n_decoded` past 45000. That is the high-context repetition
collapse of llama.cpp#21799 / google-deepmind/gemma#622 — a model defect that no
grammar change addresses.

It is **intermittent**: the same query then succeeded 5 times running (81-86 s).
Roughly 1 failure in 12 psychology Reflects post-patch (~8%), against 100% before.
Each failure still wedges a slot until the router restarts.

**Resolved by `reasoning-budget`** — see the section below. The residual ~8% was
the unbounded thought rule; bounding thinking at the sampler took it to zero
without removing the capability. gpt-oss stays production on speed alone
(Reflect 22-30 s vs 68-83 s), and its e2e on the same patched binary is 3/3 with
no errors, as expected since the patch only touches the gemma4 parser.

**Probable root cause is the model, not llama.cpp** (consistent with the above but
not locally confirmed). google-deepmind/gemma#622 documents
token-repetition collapse in both `gemma-4-31B` dense and `gemma-4-26B-A4B` MoE,
reproducing on Ollama, LMStudio, vLLM and Cloudflare Workers AI; `gemma3-27b` is
unaffected on the same stacks. It surfaces most reliably under grammar-constrained
decoding at 1000+ generated tokens: the grammar keeps EOS out of the allowed token
set, so the model's mild repetition bias becomes an inescapable loop
(vllm-project/vllm#40080). Hindsight's Reflect is exactly that shape — it calls
tools, and llama.cpp always applies a tool-call grammar. Upstream llama.cpp #21375
is closed "not planned"; #25072 and #21799 are open and unfixed.

**Mitigations tested, all failed.** Each was a single-variable change re-run
against `psychology`:

| Change | Result |
| --- | --- |
| `reasoning = off` | Fixes Retain/Consolidation overgeneration only; Reflect still runs away |
| `temp = 0.2` (from Gemma's official 1.0) | Runaway identical — 28,699 tokens |
| `HINDSIGHT_API_LLM_STRICT_SCHEMA=false` | No effect; tool calls are grammar-constrained regardless of `response_format` |
| DRY sampler, `0.8 / 1.75 / 2 / 8192` (2026-08-07) | No effect — 27,731 tokens at timeout, indistinguishable from runs without it |

Upstream also reports `repeat-penalty` 1.0–1.5 has no effect, so this repo's
`repeat-penalty = 1.0` convention is not the cost here. Note that
`dry-penalty-last-n` must be an explicit positive window: `llama-sampler.cpp`
applies `max(dry_penalty_last_n, 0)` and then treats `0` as disabled, so `-1`
silently turns DRY off instead of meaning "whole context".

**Neither a schema change nor a template change can fix this** — worth knowing
before anyone tries. In `common/chat.cpp`, the Gemma 4 tool grammar does not use
the caller's tool `parameters` schema at all; the line that would read it is
commented out behind a `TODO`, and arguments are matched by
`p.tool_args(p.ref("gemma4-dict"))` — a generic dict whose string values are
`until("<|\"|>")` and whose keys are `chars("[^:}]", 1, -1)`, both unbounded.
So `maxLength`/`minLength`, which `json-schema-to-grammar.cpp` genuinely does
support, never reach this path no matter what Hindsight puts in its tool schemas.
And the grammar is constructed in C++ from the `peg-gemma4` format, so the Jinja
chat template cannot alter it — unlike the gpt-oss harmony template fix, which
worked because it changed which *channel* tool calls were emitted on, a
prompt-side concern. Only a local llama.cpp patch could bound this grammar, at
the cost of the "track latest, no local patches" convention and a re-apply after
every `build.sh` pull.

**Restored configuration.** `gpt-oss-20b` back to `load-on-startup = true`,
`HINDSIGHT_API_LLM_MODEL=gpt-oss-20b`, `HINDSIGHT_API_LLM_STRICT_SCHEMA=true`, and
`HINDSIGHT_API_LLM_EXTRA_BODY` with `reasoning_effort=low` restored — that env var
and the gpt-oss preset are a pair; the variable is inert for Gemma and was unset
during the retest. Verified after revert: `psychology` Reflect returned a coherent
2474-character answer in 34.2s.

### The second Gemma defect, isolated and fixed (2026-08-07 → 08-08)

**Fixed by `reasoning-budget = 1024`.** The runaway lived in the thought rule,
`p.reasoning(p.until("<channel|>"))` — unbounded, with EOS locked out until the
mandatory tool call. Bounding thinking at the sampler forces the closing tag,
after which the grammar requires the call. Single-variable measurement on 120
replays of a captured production request: **5/120 hangs without it, 0/120 with
it**, thinking still used on 9/120 completions. End to end: 40/40 Reflects on
`psychology`, and **zero calls near the `n-predict` cap**, so the budget contains
the degeneration rather than the cap masking it.

Preferred over patching the thought out of the grammar, which was built and
measured (also 0/120) then discarded: it removes a real capability, and is
stricter than `common_chat_params_init_gpt_oss`, whose required-turn branch still
permits `analysis` blocks. Config beats a patch that must be rebased forever.

The investigation below is kept for the ruled-out table.

The hang that survived the llama.cpp grammar patch was tracked to root cause by
capturing the failing request off the wire and replaying it. Everything below is
measured, not inferred; several earlier guesses recorded here were wrong and are
listed at the end so they are not re-derived.

**Mechanism.** On a forced turn (`tool_choice: "required"`, `tools: ['recall']`)
the model already has its evidence and wants to call `done` with the final answer.
It cannot — `done` is not offered — so it drafts the answer *inside its thought
block* and never escapes: `thought` is `p.until("<channel|>")`, unbounded, and EOS
stays outside the allowed set until the mandatory tool call appears. Replaying one
captured request 120 times: **5 hangs (4.2%), all 5 with the runaway in
`reasoning_content`**, zero content, zero tool args. The client sees silence, not a
runaway, because nothing downstream watches `reasoning_content` — which is why this
was mistaken for a stall for so long.

**There are three unbounded rules in this grammar, not one.** All the same class:

| Rule | Bound | Confirmed by |
| --- | --- | --- |
| `scan_to_toolcall` / `content` | none | the original bug; fixed by our patch |
| `thought` = `until("<channel|>")` | none | 5/120 hangs in `reasoning_content` |
| `gemma4-array` / `gemma4-string-content` | none | 11/12 hangs in tool args (below) |

**Fix candidates, measured head to head** (same captured request, 12 trials each):

| Strategy | Hangs | Finished as |
| --- | --- | --- |
| A. `recall` only, `required` — production today | 0/12 | `recall` x12 |
| B. `recall`+`done`, `required` — "give it an exit" | **11/12** | `done` x1 |
| C. `recall`+`done`, `auto` — "stop forcing" | 0/12 | **`content` x12** |
| D. `recall` only, `auto` | 0/12 | **`content` x12** |

**B is a trap.** Offering `done` on a forced turn is ~20x worse than today: `done`
requires `memory_ids`, an array of ID strings, and the model collapses into
repeating one UUID forever inside the unbounded array rule.

**C/D break Reflect.** `auto` stops the hang but the model answers in plain prose
and calls no tool at all (24/24). `agent.py` raises `ReflectToolCallError` when a
turn produces no tool call and none was seen earlier, and deliberately no longer
salvages the free text ("it can be a raw done()-payload with sibling id fields
leaking into user-visible text"). Turn 0 under `auto` therefore fails outright, and
the hierarchical retrieval ladder — and with it the "ONLY use retrieved results"
anti-hallucination guarantee — is lost.

**The tractable Hindsight-side change** is to widen the existing
`stop_forcing_from_iteration` release (agent.py), which today fires only when fresh
mental models are found. The hang lands on the *second* forced turn, after
`search_observations` already returned 66 KB of evidence — exactly where forcing has
stopped earning anything. That keeps turn 0 forced, keeps `saw_tool_call` true, and
removes the turn where the model fights the constraint. It is a mitigation: any
forced turn can still reach an unbounded rule.

**The real fix belongs in llama.cpp.** Hindsight uses `tool_choice: required`
correctly; no API consumer should be able to hang a server with it.

**Deployed mitigation: `n-predict = 4096` on both profiles.** Not a fix — it bounds
blast radius. 5/120 hangs without it, **0/120 with it**, and degenerate runs abort
at ~21 s still returning a valid tool call instead of holding a slot to the 300 s
timeout. Real maxima sit far below the cap (retain 652 output tokens, consolidation
276, reflect 1424, e2e max 855), and a full gpt-oss e2e under the cap is unchanged
(3/3 every probe, `max_out` 1437). It is also cheap insurance for gpt-oss, which had
an unbounded runaway during the corrupt-GGUF incident above.

**Ruled out, with evidence** — do not revisit without new information:

| Hypothesis | Verdict |
| --- | --- |
| High context (~95k tokens) | Hang occurs at 32k; 84,428 tokens passes 3/3 |
| An `auto` turn | It is a `required` turn; wire capture is unambiguous |
| Slot prefix-cache reuse (`f_sim` / `f_keep`) | 1/16 hangs with `cache-ram = 0` vs 2/18 with cache on |
| Sampler settings | temp 1.0 vs 0.2, DRY, repeat-penalty all measured no different |
| Request content | Same bytes hang 4.2% and succeed 95.8% — it is stochastic |

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

After the multilingual models were loaded and exercised (the disk/cache figures below predate the GPU reranker switch):

- Hindsight RSS after the GPU reranker switch: approximately 2.4 GiB
- Hugging Face cache: approximately 6.6 GiB, including current and previously used models
- Hindsight virtual environment: approximately 2.1 GiB
- Inactive embedded pg0 rollback directory: approximately 139 MiB
- The old BGE CPU reranker remains in the Hugging Face cache as rollback data but is no longer loaded by Hindsight

Embeddings remain on CPU. Reranking now runs in llama.cpp on Vulkan1 alongside the Hindsight LLM.

## Security notes

- Hindsight listens on all interfaces for trusted-LAN access and has no application-level authentication or TLS in this deployment. Block port 8888 from untrusted networks and never forward it directly to the internet.
- PostgreSQL remains localhost-only; do not expose port 5432 to the LAN.
- Keep `/home/gaperton/.config/hindsight/hindsight.env` mode `0600`.
- Do not place credentials in this repository.
- Hindsight's model cache contains downloaded public model weights, not application memories.
- PostgreSQL is the authoritative active data store; do not treat the old pg0 directory as a current backup.

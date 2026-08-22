# gpu-0-1 combined router — measurements

Evidence behind the numbers in `gpu-0-1/combined.ini`. Re-measure if a model,
quant or `ctx-size` changes; the preset carries only the conclusions.

Card: 2x AMD R9700, gfx1201, 31.86 GiB usable VRAM each (68.42 GiB total... note
`rocm-smi` reports bytes — divide by 2^30, not 1e9; mixing the two is an easy way
to invent headroom that does not exist).

## Split mode: what each one actually buys

`benchmark/bench-split.sh`, one model at a time, nothing else resident.

qwen3.8-27B UD-Q5_K_M (dense), t/s:

| test | single | layer | tensor |
|---|---:|---:|---:|
| pp512 | 973.8 | 972.2 | 1094.3 |
| pp4096 | 936.8 | **1630.0** | 1067.3 |
| tg128 | 25.59 | 25.49 | **35.60** |
| pp4096 @ d16384 | 623.2 | **1084.4** | 828.1 |
| tg128 @ d16384 | 24.67 | 24.42 | **34.60** |

gpt-oss-20B UD-Q8_K_XL (MoE), t/s:

| test | single | layer | tensor |
|---|---:|---:|---:|
| pp4096 | 5009.1 | **8048.0** | 4914.6 |
| tg128 | **132.6** | 125.3 | 132.3 |
| pp4096 @ d16384 | 3668.9 | **6130.1** | 4126.8 |
| tg128 @ d16384 | 121.4 | 115.2 | 125.0 |

`tensor` is a decode play and only pays for a dense model — qwen +39% decode,
gpt-oss +0% (its ~3.6B active params are not bandwidth-starved). `layer` is a
large-batch prefill play: +61-74% at pp4096, nothing at pp512, -5.5% decode.

## Footprint

Each model alone, in its production config, components isolated by varying one
term at a time. GiB:

| model | total | weights+fixed | KV | compute (ubatch) |
|---|---:|---:|---:|---:|
| qwen | 32.84 | 19.66 | 12.83 @ 327680 q8_0 | 0.35 @ 512 |
| llm | 22.93 | 12.05 | 9.87 @ 262144 f16 | 1.01 @ 2048 |
| reranker | 3.73 | 1.06 | 0.44 @ 4096 f16 | 2.06 @ 4096 |

KV dominates the chat models (39% of qwen), so `ctx-size` is the only large
adjustable term. The reranker inverts that: 55% of it is the ubatch compute
buffer and its KV is negligible.

Marginal KV rate for qwen at q8_0: **~0.041 GiB per 1K tokens** of total context.

Parts sum to 59.5 GiB but live usage is ~61.4 — three child processes each carry
their own ROCm context and allocator slack.

Caveat when isolating: llama.cpp clamps `ubatch` to `n_ctx`, so a low-ctx probe
silently lowers ubatch too. Vary one at a time at fixed ctx.

## Reranker slot count

100 documents in one request, ~200 tok each, idle card:

| slots | 1 | 2 | 4 | 8 | 16 | 32 |
|---|---:|---:|---:|---:|---:|---:|
| throughput (rerank/s) | **0.15** | 0.10 | 0.08 | 0.08 | — | — |
| latency @ concurrency 1 | 6.8s | 9.8s | 12.2s | 12.4s | 13.9s | 17.0s |

Throughput is flat in concurrency: at 1 slot, 8 concurrent requests finish in the
same 53.7s wall as 8 sequential ones (mean latency 6.8s -> 30.2s, p95 47.0s). The
card is already saturated by the per-document fan-out inside a single request, so
extra slots buy only head-of-line fairness and cost aggregate throughput.

At ~800 tok/doc it is flat across slot counts — token count alone saturates.

## kv-unified

Load-bearing at `parallel = 8` (-29% on a 100-document rerank, and `n_ctx_slot`
becomes the full ctx-size instead of `ctx-size/parallel`). A **no-op at
`parallel = 1`** — measured identical `n_ctx_slot` 4096, 3.73 GiB, and 6.88s on a
100-document rerank with and without. Dropped from the preset; restore it if the
slot count ever goes back up.

## MTP and the "CPU sampler" warning

qwen's startup logs, under tensor split:

    set_sampler: backend sampling not supported with SPLIT_MODE_TENSOR; using CPU
    spec common_specu: backend offload failed for seq_id=0; using CPU sampler

Cause is `llama-context.cpp` `set_sampler()`, which refuses backend sampling
whenever `split_mode == LLAMA_SPLIT_MODE_TENSOR`. Not ROCm-specific, not a bug —
an explicitly unsupported combination.

**It costs nothing measurable.** At fixed layer split, where both are available,
6 requests each: GPU sampler mean 36.58 t/s (35.2-38.1), CPU sampler 36.33
(35.2-37.9). A 3-rep read suggested CPU was 11% faster; that was noise.

And tensor wins decode anyway, warning and all — qwen + MTP, same prompt:

| split | pp | tg |
|---|---:|---:|
| tensor (CPU sampler, forced) | 885-893 t/s | **49.8-53.2 t/s** |
| layer (GPU sampler) | **1138-1146 t/s** | 34.8-38.1 t/s |

MTP draft acceptance ~0.51-0.59, mean draft length ~2.0-2.2. Ignore the warning.

## Balance

The reranker cannot be split (tensor crashes it, layer costs ~2.4 GiB in
duplicated compute buffers), so it sits on ROCm1 and `llm`'s layer split is skewed
to compensate. Arithmetic says 58/42; it does not land there, because gpt-oss's 24
layers quantise the split. Measured, with qwen at 327680 (GiB used / free):

| tensor-split | GPU0 | GPU1 |
|---|---|---|
| 58,42 | 30.02 / 1.84 | 31.20 / 0.65 |
| **63,37** | 31.02 / 0.84 | 30.39 / 1.47 |
| 67,33 | 31.37 / 0.49 | 29.85 / 2.01 |

## Hindsight bounds

- One Recall issues exactly one rerank request (`engine/search/reranking.py`,
  single query, sequential `for await`, no `gather`).
- Documents per request capped at 100 (`HINDSIGHT_API_RERANKER_MAX_CANDIDATES`).
- Concurrent Recalls capped at 32 (`memory_engine.py`,
  `asyncio.Semaphore(recall_max_concurrent)`, default, not overridden here).
- The litellm reranker path has no semaphore of its own, unlike the TEI path.

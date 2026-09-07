# qwen4exp-indexer-no-v

Rationale for `llama-cpp.patch`, applied to `llama.cpp/` by `build.sh`.

Upstream: [ggml-org/llama.cpp#28330](https://github.com/ggml-org/llama.cpp/pull/28330),
"avoid allocating V cache for indexer (it's not used) in Qwen3.8-Flash-Next"
(fairydreaming, open). Applied verbatim, **+4/-0 in 1 file**.

## What it fixes

Qwen3.8-Flash-Next uses `llama_memory_hybrid_idx`, which holds an extra `llama_kv_cache`
for the QSA indexer keys. `llama_kv_cache` allocates a V cache unless the model is MLA,
but the indexer only ever stores K — so the V half was pure waste. The patch makes that
instance report as MLA so V is skipped.

## Why it matters here

Flash-Next only. Measured on this box at `--ctx-size 131072 -ctk q8_0 -ctv q8_0`:

```
before:  llama_kv_cache: size = 612.00 MiB   (K q8_0: 204.00, V q8_0: 408.00)
after:   llama_kv_cache: size = 204.00 MiB   (K q8_0: 204.00, V q8_0:   0.00)
```

At the 196608 context measured earlier in `benchmark/reports/bench-flashnext-*.md` the
indexer cache was 918 MiB (K 306 / V 612), so this frees **612 MiB** there. It scales
linearly with context, and on a box where Flash-Next fills both cards to within ~1 GiB,
that is expert residency bought back for four lines.

## Status

Open, not merged. The author notes the clean fix is a `llama_kv_cache` constructor
parameter rather than pretending to be MLA, so the final upstream form may differ —
expect this to need re-fetching rather than rebasing if it changes.

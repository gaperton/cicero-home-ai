# qwen3-reranker-logits

Rationale for `llama-cpp.patch`, applied to `llama.cpp/` by `build.sh`.

Upstream: [ggml-org/llama.cpp#27715](https://github.com/ggml-org/llama.cpp/pull/27715),
"Prevent Qwen3 reranker from allocating exponential memory as physical batch size
increases" (sredman, open). Applied verbatim, +7/-5 in 2 files.

## What it fixes

In reranking/embedding mode the graph still built the `lm_head` matmul and reserved a
logits buffer, neither of which a reranker ever reads. The cost scales with
`ubatch x n_vocab`, so it grows with `ubatch-size`. The patch skips both when
`cparams.embeddings` is set (`has_logits = !cparams.embeddings` in `llama-context.cpp`,
and the `lm_head` block in `src/models/qwen3.cpp`).

## Why it matters here

`[reranker]` in `gpu-0-1/combined.ini` is arch `qwen3` and runs `ubatch-size = 4096`
against a 151936-token vocabulary — the worst case for this bug. It is also pinned to
**ROCm0**, the tighter card: `[llm]` carries a `tensor-split = 38,62` specifically to
offset it. Every GiB freed here is a GiB back for the other two models.

Measured on this box, reranker started standalone with the preset's exact flags:

| | before | after |
|---|---|---|
| ROCm0 compute buffer | 2417.92 MiB | **240.09 MiB** |
| host output buffer | 0.58 MiB | 0.00 MiB |
| total ROCm0 VRAM | 3.73 GiB | **1.61 GiB** |

**-2.12 GiB, a 57% reduction.** The arithmetic confirms the mechanism: 4096 tokens x
151936 vocab x 4 B = 2373 MiB, essentially the whole saving. Rerank scores are unchanged
(same two-document probe: 0.1370 / 0.0000 before and after).

## Status

Open, not merged, `mergeable_state=unknown`, last touched 2026-08-29. Author reports
"all queries I tried are identical before and after"; that matches what was seen here.
If it stops applying, check whether it merged (delete this folder) — the deployed
reranker silently wastes ~2 GiB without it, which is a VRAM regression, not a crash, so
it will not announce itself.

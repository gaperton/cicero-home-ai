# rdna4-fattn-gfx1201

Rationale for `llama-cpp.patch`, applied to `llama.cpp/` by `build.sh`.

Upstream: [ggml-org/llama.cpp#28102](https://github.com/ggml-org/llama.cpp/pull/28102),
"CUDA/HIP: Flash Attention tuning (gfx1201)" by pwilkin. Applied **verbatim** — applies
cleanly to master, no rebase needed. Not authored here.

**Replaces the earlier `rdna4-fattn-hs256` entry (#26419).** Both fix the same root cause
and touch the same files, so they are mutually exclusive. #28102 won on measurement — see
the table below. #26419 was last touched 2026-08-29 and has been overtaken.

## What it fixes

Head dim 256 was not being selected for the AMD WMMA FlashAttention MMA kernel on gfx1201,
so prompt processing at depth fell back to a slow path. This is the regression tracked in
[#26220](https://github.com/ggml-org/llama.cpp/issues/26220), filed by another AI PRO
R9700 owner. The PR fixes an HS=256 bug in the general CUDA FA selection code that was
preventing the 256 kernels from being chosen at all, and tunes the gfx1201 path on top.
Touches `fattn.cu`, `fattn-mma-f16.cuh` and `fattn-common.cuh`.

Decode is untouched by design; this is a prefill-at-depth fix.

## Why it matters here

`[qwen3.8-27b]`, the deployed model in `gpu-0-1/combined.ini`, is arch `qwen35` with
`attention.key_length = attention.value_length = 256` — exactly the affected geometry.
`[llm]` (gpt-oss-20b, head dim 64) and `[reranker]` are unaffected. The deployed preset
runs 393216 over 2 slots = 196608 per slot, so depths up to ~150k are in normal range for
Hindsight's Reflect operation, which CLAUDE.md records at 14k p50 / 38k max but which
grows with bank size.

## Measured here

`Qwen3.8-27B-UD-Q5_K_M`, both cards, deployed `-sm tensor` topology, q8_0 KV,
`llama-bench -p 512 -n 0`, llama.cpp e71b80510. All three columns are the same command on
the same box; only the patch differs.

| test | unpatched | #26419 (old) | **#28102 (this)** | this vs unpatched |
|---|---|---|---|---|
| pp512 | 1086.50 | 1087.07 | 1091.23 | +0.4% (noise) |
| pp512 @ d16384 | 837.23 | 906.12 | **1000.19** | **+19.5%** |
| pp512 @ d65536 | 489.92 | 563.66 | **805.28** | **+64.4%** |
| pp512 @ d150000 | not measured | 351.63 | **607.25** | +72.7% vs #26419 |

`-r 3` except d150000 at `-r 2`. Zero gain at depth 0 and monotonically growing with depth
— the signature of the mechanism, not of build noise. Upstream reports +50% at d40000 and
+143% at d150000 on a single R9700; this box sees less at the deep end, plausibly because
`-sm tensor` already spreads attention across two cards.

At d65536 this patch is **43% faster than #26419**, and at d150000 **73% faster**. That
gap is why the swap happened.

## Correctness

`test-backend-ops test -o FLASH_ATTN_EXT`: 3/3 backends passed, 0 failures, across 282
`hsk=256` cases. Those compare against the CPU reference. All three production models
verified generating correctly end to end afterwards.

## Status

Open, not merged, `mergeable_state=blocked`, actively worked (updated 2026-09-07 by a
frequent llama.cpp contributor). Same author as #28447 (RDNA4 GDN optimizations), which is
a candidate to carry alongside if Flash-Next is pursued.

If it stops applying: check whether it merged upstream (delete this folder) or whether
#26419 landed instead — the two are alternatives for the same bug, and whichever lands
makes this entry unnecessary.

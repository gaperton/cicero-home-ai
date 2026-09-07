# rdna4-fattn-hs256

Rationale for `llama-cpp.patch`, applied to `llama.cpp/` by `build.sh`.

Upstream: [ggml-org/llama.cpp#26419](https://github.com/ggml-org/llama.cpp/pull/26419),
fixing [#26220](https://github.com/ggml-org/llama.cpp/issues/26220). **Rebased locally** —
see "Rebase" below. Not authored here; carried until it merges.

## What it fixes

Head dim 256 was excluded from the AMD WMMA FlashAttention MMA kernel, so gfx1201 fell
back to the tile kernel for those models. Issue #26220 — filed by another AI PRO R9700
owner — reports prompt processing at 127k running nearly 2x slower after the native MMA
FA kernel replaced rocWMMA. Decode is unaffected; this is purely a prefill-at-depth
regression, the one CLAUDE.md warns about when reading benchmarks with `-d`.

The patch does three things:

1. `fattn.cu` — widens the WMMA dispatch so head dim <= 256 also takes
   `BEST_FATTN_KERNEL_MMA_F16`, gated on `Q->ne[1] * gqa_ratio_eff > 64`. That gate is
   why decode is untouched: at gqa_ratio 6 it needs a batch of >= 11 tokens, so it fires
   during prefill and never for single-token generation.
2. `fattn-mma-f16.cuh` — for `DKQ > 128` on AMD WMMA, K and V are read straight from
   global memory via `load_ldmatrix`, bypassing LDS staging entirely (there is not enough
   shared memory to stage 256-wide tiles), plus `nbatch_V` 64 -> 128 in the (256,256,32)
   and (256,256,64) config cases, and the `DKQ > 128` bail-out widened to `DKQ > 256`.
3. Barrier correctness — with K/V out of LDS the tile barriers look redundant, but
   `tile_mask` still lives in shared memory, so the end-of-loop `__syncthreads()` must
   still fire when a mask is active or the next iteration's `load_mask` overwrites it
   while a slow warp is still reading it in softmax. The patch keeps the barrier under
   `DKQ <= 128 || ncols2 > 1 || mask_h`.

## Why it matters here

**This is a production fix, not a Flash-Next experiment.** `[qwen3.8-27b]`, the deployed
model in `gpu-0-1/combined.ini`, is arch `qwen35` with
`attention.key_length = attention.value_length = 256` and gqa_ratio 6 — exactly the case
this enables. `[llm]` (gpt-oss-20b) is head dim 64 and unaffected. `[reranker]` is
unaffected.

Measured on this box, `Qwen3.8-27B-UD-Q5_K_M`, both cards, the deployed
`-sm tensor` topology with q8_0 KV, `llama-bench -p 512 -n 0 -r 3`, llama.cpp e71b80510:

| test | before | after | change |
|---|---|---|---|
| pp512 | 1086.50 +- 41.37 | 1087.07 +- 42.05 | +0.1% (noise) |
| pp512 @ d16384 | 837.23 +- 13.97 | 906.12 +- 15.13 | **+8.2%** |
| pp512 @ d65536 | 489.92 +- 5.36 | 563.66 +- 6.83 | **+15.1%** |

The gain is zero at depth 0 and grows with depth, which is the signature of the mechanism
rather than of build noise. Upstream reports +19.1% at 65k and +21.8% at 126k on the same
GPU with Qwen3.6-35B-A3B Q4_K_M; this box sees less, plausibly because `-sm tensor` splits
the attention work across two cards.

## Correctness

`test-backend-ops test -o FLASH_ATTN_EXT`: **2959/2959 passed**, 0 failures, including 270
`hsk=256` cases and the kv=16384 long-context cases the patch itself adds. Those compare
against the CPU reference, which is the check that matters — a bad resolution here would
produce silently wrong attention, not a crash.

## Rebase

The upstream PR does not apply to current master. Since it was opened, upstream added LDS
swizzling (`ggml_cuda_fattn_smem_swizzle`, `swz_K`/`swz_V`), which rewrote the three
`load_ldmatrix` call sites the PR also touches. Resolved by keeping upstream's swizzled
accessor as the `else` branch and putting the PR's global-memory bypass in front of it:
the bypass never enters LDS, so swizzling is orthogonal to it. Note that for `DKQ > 128`
`tile_V_i` points into global memory, so the swizzle accessor's `tile_V`-relative offset
is meaningless on that path — another reason the bypass must not go through it.

If this stops applying: the fix landing upstream is the good outcome (delete this folder).
If it needs another rebase, the `tests/test-backend-ops.cpp` hunk is the fragile one —
that file churns upstream and the hunk is only the regression test, so dropping it is the
safe way to reduce rebase burden without losing the fix.

## Status

Open, approved by two reviewers on 2026-08-27. Blocked upstream because gfx1151
(RDNA3.5) regressed up to 14% at deep context and the change needs architecture-specific
gating. **That blocker does not apply to this box** — gfx1201 only, no RDNA3.5 card.

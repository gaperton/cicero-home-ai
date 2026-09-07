# moe-expert-cache

Rationale for `llama-cpp.patch`, applied to `llama.cpp/` by `build.sh`.

Upstream: [ggml-org/llama.cpp#27861](https://github.com/ggml-org/llama.cpp/pull/27861),
"GPU-resident LRU cache for host-offloaded MoE expert weights". Applied **verbatim** —
it still applies cleanly to master, no rebase needed. Not authored here.

## Read this first

**This patch is inert for everything currently deployed.** It only does work when a MoE
layer's experts live in host RAM, and all three models in `gpu-0-1/combined.ini` are fully
GPU-resident: `[qwen3.8-27b]` (18.4 GiB), `[llm]` (gpt-oss-20b), `[reranker]`. It is also
off by default (`--moe-expert-cache 0`). It is carried for Qwen3.8-Flash-Next evaluation,
which is the only model here that spills experts to host.

It is a **draft** PR touching `ggml.c`, `ggml-cpu.c`, `llama-graph.cpp` and
`llama-context.cpp` — a much larger and less settled surface than
[[../rdna4-fattn-hs256]]. Weigh that before keeping it long-term.

## What it does

A host-offloaded MoE layer streams the routed experts' weights over PCIe on every decoded
token, so decode is bound by host RAM bandwidth. Expert routing is near-uniform over long
horizons but strongly local across consecutive tokens, so a small VRAM cache absorbs most
of that traffic.

Per cached layer it allocates a companion tensor `[ne0, ne1, K+1]` in device memory (slot
K is permanently zero) plus an I32 `expert_id -> slot` table in two copies. The device
copy drives a second `mul_mat_id` chain over the cache tensors; the host copy tells the
CPU `mul_mat_id` to skip cached experts and zero those output rows. The two paths are then
summed, so each expert contributes exactly once. Uploads are throttled and asynchronous,
published only at decode boundaries after the copies land, so a graph never reads a torn
slot.

Decode-only (`n_tokens == 1`); prefill and batches take the normal path. That restriction
exists because duplicate slot IDs break CUDA's batched `mul_mat_id` kernels, which assume
distinct expert IDs per token.

New flags: `--moe-expert-cache N` (slots per host-resident expert layer, 0 = off) and
`--moe-expert-cache-inserts N` (max uploads per layer per decode step, default 2).

## Measured here

Qwen3.8-Flash-Next UD-IQ4_XS, both cards, `--fit on --fit-target 3072 --ctx-size 196608
-ctk q8_0 -ctv q8_0 --parallel 1`, 400-token greedy generation, llama.cpp e71b80510:

| | decode | VRAM (ROCm0 / ROCm1) |
|---|---|---|
| `--moe-expert-cache 0` (default) | 25.17 t/s | 28.68 / 28.94 GiB |
| `--moe-expert-cache 48` | **27.13 t/s (+7.8%)** | 28.68 / 29.76 GiB |

The cache took ~0.82 GiB, all on ROCm1 — only host-resident expert layers get one.
Upstream reports +31% on this model; this box sees less because `--fit-target 3072` leaves
only a few layers spilled to host, so there is less PCIe traffic to absorb. The gain
should grow as more experts spill (lower `--fit-target`, larger context, larger quant).

## Correctness

`test-backend-ops test -o MUL_MAT_ID` and `-o FLASH_ATTN_EXT`: 3/3 backends passed each.
Those cover the base ops, not the cache itself, which is a graph-level feature.

**Greedy output diverges with the cache on.** Same prompt, `temperature 0, top_k 1`, fixed
seed: the two generations share a 629-character prefix and then continue differently, both
coherent and both correct. The PR's "exact" means the cached and uncached contributions
sum to the mathematically correct value, not that the result is bit-identical — the
summation order differs, and after ~150 tokens a near-tie in the logits flips. Expect this;
it is not corruption. It does mean this patch breaks reproducibility of a fixed-seed
generation, which matters if a benchmark or test compares generated text exactly.

## build.sh interaction (why build.sh changed)

This is the first patch here that **creates** files (`src/llama-moecache.cpp`,
`src/llama-moecache.h`). `build.sh` discards previous patches with
`git checkout -- .`, which reverts tracked files only — the created files survive as
untracked leftovers, and the next `git apply` refuses with "already exists". The old
`apply_patches` read that as "no longer applies" and hard-failed the build with a
misleading rebase message; it also left the tree half-patched, since it aborts mid-loop.

`apply_patches` was therefore reworked to check "already applied" first, then delete the
files a patch creates (`git apply --summary`, `create mode` lines) before applying it.
Verified in both states: all three patches skip when applied, and all three re-apply from
a post-`checkout` tree with untracked leftovers present.

## Status

**Draft**, not merged, with open design questions the author lists: cache ownership
(per-process singleton vs model-attached), the ggml -> llama upcall for CPU observation,
multi-token batching, Vulkan topk-moe fusion, and expert-table mutation during
multi-ubatch prefill. Contributors estimate prefill participation would be worth ~75% on
prompt processing and small-batch support would take MTP+cache from 23-24 to 30-32 tok/s.

Because it is a draft, expect it to need rebasing or dropping on any given upstream pull.
If it stops applying and Flash-Next is not being evaluated, deleting this folder is the
cheap answer — nothing deployed depends on it.

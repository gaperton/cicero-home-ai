# patches/

Local fixes for `llama.cpp/`, applied by `build.sh` on every build (`./build.sh
--patch-only` to just re-apply). Each folder holds `llama-cpp.patch` plus a `README.md`
with the rationale, measurements, and upstream status — read that before touching an
entry. See `CLAUDE.md` for the mechanics (why patches instead of bare edits, what happens
when one stops applying).

None of these are authored here; each carries an upstream PR that has not merged yet.

| patch | PR | why |
|---|---|---|
| [gemma4-required-toolcall](gemma4-required-toolcall/) | (local) | `tool_choice: "required"` had no exit for gemma4 and hung the slot indefinitely |
| [rdna4-fattn-gfx1201](rdna4-fattn-gfx1201/) | [#28102](https://github.com/ggml-org/llama.cpp/pull/28102) | gfx1201 FlashAttention prefill-at-depth fix. Production: `[qwen3.8-27b]` is head-dim 256. Measured +19.5%/+64.4% pp at d16384/d65536 |
| [qwen3-reranker-logits](qwen3-reranker-logits/) | [#27715](https://github.com/ggml-org/llama.cpp/pull/27715) | reranker built an unused lm_head/logits buffer. Production: frees ~2.1 GiB on ROCm0, the tight card |
| [qwen4exp-sm-tensor](qwen4exp-sm-tensor/) | [#28569](https://github.com/ggml-org/llama.cpp/pull/28569) | re-enables `-sm tensor` for qwen4exp (Qwen3.8-Flash-Next), previously refused at load. Measured +8.0% pp / +5.6% tg over layer split |
| [qwen4exp-indexer-no-v](qwen4exp-indexer-no-v/) | [#28330](https://github.com/ggml-org/llama.cpp/pull/28330) | qwen4exp's indexer KV cache allocated an unused V half. Frees 612 MiB at 196608 ctx |
| [qwen4exp-mtp](qwen4exp-mtp/) | [#28243](https://github.com/ggml-org/llama.cpp/pull/28243) | NextN/MTP speculative decoding for qwen4exp, incl. Unsloth's shared draft-head gguf. Measured +56% decode |
| [moe-expert-cache](moe-expert-cache/) | [#27861](https://github.com/ggml-org/llama.cpp/pull/27861) | GPU-resident LRU cache for host-offloaded MoE experts. Draft, inert on all deployed models (none spill); Flash-Next evaluation only. Measured +7.8% decode |

`gemma4-required-toolcall` and `rdna4-fattn-gfx1201` fix the deployed stack
(`gpu-0-1/combined.ini`). The `qwen4exp-*` and `moe-expert-cache` entries exist for
evaluating Qwen3.8-Flash-Next, which is not deployed — see
`benchmark/reports/bench-flashnext-*.md` for the full measurements behind the numbers
above.

**Rejected:** [#28447](https://github.com/ggml-org/llama.cpp/pull/28447) (RDNA4 GDN
optimizations) — despite both hybrid Qwen models being GDN-heavy, it measured as a no-op
in both single-stream and MTP (multi-token) decode on this hardware. Not carried.
[#28136](https://github.com/ggml-org/llama.cpp/pull/28136) (PLE direct reads) was not
adopted — its gain was measured only on a DGX Spark's unified memory and conflicts with
`qwen4exp-mtp` at one hunk; revisit if Flash-Next prefill becomes a priority.

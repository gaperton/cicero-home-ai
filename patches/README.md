# patches/

Local fixes for `llama.cpp/`, applied by `build.sh` on every build (`./build.sh
--patch-only` to just re-apply). Each folder holds `llama-cpp.patch` plus a `README.md`
with the rationale, measurements, and upstream status — read that before touching an
entry. See `CLAUDE.md` for the mechanics (why patches instead of bare edits, what happens
when one stops applying).

None of these are authored here; each carries an upstream PR that has not merged yet.

| patch | PR | why |
|---|---|---|
| [qwen3-reranker-logits](qwen3-reranker-logits/) | [#27715](https://github.com/ggml-org/llama.cpp/pull/27715) | reranker built an unused lm_head/logits buffer. Production: frees ~2.1 GiB on ROCm0, the tight card |

`qwen3-reranker-logits` fixes the deployed stack; it's the only patch carried now.

**Removed 2026-09-23:** `qwen4exp-sm-tensor` (#28569), `qwen4exp-mtp` (#28243),
and `moe-expert-cache` (#27861) — all three existed only to evaluate
Qwen3.8-Flash-Next, which is not deployed. Without the first two, tensor split
on Flash-Next goes back to refusing at load and its MTP draft head is
unusable; `qwen3.8-flash.ini` needs re-validating before use. See
`benchmark/reports/bench-flashnext-*.md` for the measurements that were behind
them.

**Dropped during the 2026-09-20 update** (fixes landed upstream, folders removed):
`gemma4-required-toolcall` (upstream refactored the gemma4 parser into
`common/parsers/gemma4.cpp` and included the required-toolcall exit),
`rdna4-fattn-gfx1201` (#28102, merged 2026-09-11), and
`qwen4exp-indexer-no-v` (#28330, merged 2026-09-10).

**Rebased 2026-09-20:** all four carried patches were re-cut against current
master; `qwen4exp-mtp` now tracks the live #28243 head (12 commits, updated
2026-09-18) rather than the earlier 09-07 snapshot.

**Rejected:** [#28447](https://github.com/ggml-org/llama.cpp/pull/28447) (RDNA4 GDN
optimizations) — despite both hybrid Qwen models being GDN-heavy, it measured as a no-op
in both single-stream and MTP (multi-token) decode on this hardware. Not carried.
[#28136](https://github.com/ggml-org/llama.cpp/pull/28136) (PLE direct reads) was not
adopted — its gain was measured only on a DGX Spark's unified memory; revisit if
Flash-Next prefill becomes a priority.

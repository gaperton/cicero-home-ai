# qwen4exp-mtp

Rationale for `llama-cpp.patch`, applied to `llama.cpp/` by `build.sh`.

Upstream: [ggml-org/llama.cpp#28243](https://github.com/ggml-org/llama.cpp/pull/28243),
"models: Qwen3.8-Flash-Next MTP" by **danielhanchen** (Unsloth). Applied verbatim —
applies cleanly to master. **Draft**, +401/-73 in 19 files.

Self-contained: its diff already carries
[#27836](https://github.com/ggml-org/llama.cpp/pull/27836) (the qwen4exp NextN/MTP draft
head it says it builds on). [#28097](https://github.com/ggml-org/llama.cpp/pull/28097) is
**not** needed — see below.

## How to use it

```
-md models/Qwen3.8-Flash-Next/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf \
--spec-type draft-mtp --spec-draft-n-max 2
```

The head is a **separate gguf loaded as a draft model**, not something baked into the
main checkpoint (Flash-Next carries no `nextn` tensors; `[qwen3.8-27b]` does, which is
why that model needs no `-md`). `models/list.txt` carries the download.

Use the **shared** variant (2.60 GiB), not the self-contained one (3.85 GiB). Unsloth
calls it the fastest, and it works here: the sidecar is `arch=qwen4exp, block_count=49`
carrying `blk.48.nextn.{eh_proj,enorm,hnorm,hc_head_*}` but no `token_embd`/`output`.
#28243 detects an MTP-only file structurally — `mtp_only` is true when
`blk.0.hc_attn_norm.weight` is absent — marks the trunk `TENSOR_NOT_REQUIRED`, and
borrows `token_embd`/`output` from the target through `cparams.ctx_other`. The
`nextn_shared_target_tensors` key the file advertises is read nowhere; detection is
structural, so do not rely on that key meaning anything.

Loading the sidecar on its own fails deliberately, with
`"this draft head has no '%s' of its own; load it as a draft of its target model (-md),
not on its own"`.

## Measured here

Flash-Next UD-IQ4_XS, both cards, `--fit on --fit-target 6144 --ctx-size 65536
-ctk q8_0 -ctv q8_0 --parallel 1`, 400-token generation:

| | decode | VRAM ROCm0 / ROCm1 |
|---|---|---|
| no MTP | 26.04 t/s | 25.64 / 25.71 GiB |
| `--spec-type draft-mtp --spec-draft-n-max 2` | **40.63 t/s (+56%)** | 25.73 / 29.00 GiB |

Draft acceptance 0.765 (241/315), mean accepted length 2.53. Upstream claims 1.3-2x;
this is 1.56x.

**Budget VRAM manually.** `--fit on` cannot measure the draft model — it logs
`failed to measure the memory of the extra model, fitting without it` — so it fills the
cards as if the 2.6 GiB sidecar did not exist. At `--fit-target 3072 --ctx-size 131072`
that produced `cudaMalloc failed: out of memory` on ROCm1 and the server died on the
first real request. `--fit-target 6144` with `--ctx-size 65536` is what the numbers above
used. Raise the target or lower the context; do not trust autofit here.

## Status

**Draft**, not merged. Nineteen files, including `convert_hf_to_gguf.py`, `conversion/*.py`
and `gguf-py/` — conversion paths this repo never runs, since models are downloaded
pre-made. Those files churn upstream, so this is the entry most likely to break on a
pull. If it does and Flash-Next is not being evaluated, deleting this folder costs
nothing deployed.

It also conflicts with [#28136](https://github.com/ggml-org/llama.cpp/pull/28136)
(PLE direct reads) at `src/models/qwen4exp.cpp:188` — one hunk, resolvable, but #28136 was
deliberately not adopted so the conflict does not arise today.

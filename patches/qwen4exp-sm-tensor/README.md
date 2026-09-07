# qwen4exp-sm-tensor

Rationale for `llama-cpp.patch`, applied to `llama.cpp/` by `build.sh`.

Upstream: [ggml-org/llama.cpp#28569](https://github.com/ggml-org/llama.cpp/pull/28569),
"model : re-enable -sm tensor for qwen4exp" (kh0pper, open). Applied verbatim,
**+2/-1 in 2 files**.

## What it fixes

`llm_arch_supports_sm_tensor()` listed `LLM_ARCH_QWEN4EXP` among the architectures that
refuse tensor split, so Qwen3.8-Flash-Next died at load with
`LLAMA_SPLIT_MODE_TENSOR not implemented for architecture 'qwen4exp'`. #27941 had added
it to that list because `test-llama-archs -a qwen4exp` aborted on the Meta device once
the fixture carried a PLE layer. The PR argues that abort is a scheduler-placement
artefact of the test harness (the PLE embedding gather is a CPU node there, so `hc_init`
first materialises inside layer 0's PLE path) rather than a real QSA limitation.

## Why it matters here

Flash-Next only, but it settles a question this machine could not previously answer.
Measured, both cards, `-ngl 99 -fa on -lm mmap -r 2`:

| | layer split | tensor split |
|---|---|---|
| pp512 | 472.41 | **510.37** (+8.0%) |
| tg128 | 30.37 | **32.07** (+5.6%) |

Layer-split figures are from `benchmark/reports/bench-flashnext-20260907-151020.md`.

Note `fit` still cannot be combined with tensor split (see `gpu-0-1/combined.ini`), so a
tensor-split Flash-Next needs an explicit `-ncmoe`/`tensor-split` rather than `--fit on`.

## Status

Open, opened 2026-09-07, not merged. Two lines; if it stops applying it almost certainly
merged. Should upstream instead decide the abort was real, this folder must go — a
wrong `-sm tensor` here would be a correctness problem, not a slowdown.

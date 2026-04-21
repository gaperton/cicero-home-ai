# Dense Models Fitting a Single GPU

This report summarizes dense model baselines that fit fully on one 31 GiB GPU, then compares those single-GPU results against two-GPU layer-split runs where available.

Source reports:

- [Qwen3.5-27B single Q5](Qwen3.5-27B/single-fit-UD-Q5_K_XL-20260419-223027.md)
- [Qwen3.5-27B single Q4](Qwen3.5-27B/single-fit-UD-Q4_K_XL-20260419-223518.md)
- [Qwen3.5-27B all Q5](Qwen3.5-27B/all-fit-UD-Q5_K_XL-20260419-224046.md)
- [Gemma 4 31B IT single Q5](gemma-4-31B-it/single-fit-UD-Q5_K_XL-20260419-224613.md)
- [Gemma 4 31B IT single Q4](gemma-4-31B-it/single-fit-UD-Q4_K_XL-20260419-225217.md)
- [Gemma 4 31B IT all Q5](gemma-4-31B-it/all-fit-UD-Q5_K_XL-20260420-230216.md)

## What Are Dense Models

Dense models activate the full model for each token. Unlike MoE models, there is no sparse expert routing where only a subset of experts participates in each forward pass. That makes dense models simpler to place: if the quantized weights and runtime buffers fit in VRAM, the whole model can stay resident on one GPU.

In these tests, "fitting single GPU" means the model can run with `-sm none -mg 0` on one 31 GiB Radeon AI PRO R9700 without intentionally offloading model components to CPU RAM. The two-GPU results are included only as a scaling comparison, not because the models require two GPUs.

## Dense Models In Question

| Model                                |   Params |     Q5 size |     Q4 size | Notes                                             |
| ------------------------------------ | -------: | ----------: | ----------: | ------------------------------------------------- |
| [Qwen3.5-27B][qwen35-27b-gguf]       | `26.90B` | `18.78 GiB` | `16.40 GiB` | Smaller and faster of the two dense models tested |
| [Gemma 4 31B IT][gemma4-31b-it-gguf] | `30.70B` | `20.37 GiB` | `17.46 GiB` | Larger dense model with slightly lower throughput |

Both models fit comfortably on a single 31 GiB GPU in `UD-Q5_K_XL` and `UD-Q4_K_XL`.

## Hardware

| Component          | Value                          |
| ------------------ | ------------------------------ |
| GPUs               | 2x AMD Radeon AI PRO R9700     |
| VRAM               | 31 GiB per GPU                 |
| RAM                | 126 GiB                        |
| Kernel             | `6.17.0-20-generic`            |
| llama.cpp          | `23b8cc499` from 2026-04-18    |
| Backends           | ROCm and Vulkan                |
| Vulkan mode        | `RADV_DEBUG=nocompute`         |
| Common bench flags | `-ngl 999 -fa on -r 3 -b 2048` |

The benchmark uses `pp512` and `pp2048` for prompt-processing throughput, and `tg256` for token-generation throughput. `tg256` is the closest number here to interactive chat speed.

## Single GPU Results Summary

Single-GPU Vulkan is the best interactive baseline for both dense models. On `UD-Q5_K_XL`, Vulkan beats ROCm decode by about `17%` on both Qwen3.5-27B and Gemma 4 31B IT. On `UD-Q4_K_XL`, Vulkan beats ROCm decode by about `21%` on both models.

`UD-Q4_K_XL` is consistently faster than `UD-Q5_K_XL`, but the gain is moderate rather than dramatic. Q4 improves decode by about `7-11%` on Qwen3.5-27B and about `10-13%` on Gemma 4 31B IT, depending on backend.

Selected-ubatch snapshot:

| Model                                | Quant        | Backend | Ubatch |     `pp2048` |     `tg256` |
| ------------------------------------ | ------------ | ------- | -----: | -----------: | ----------: |
| [Qwen3.5-27B][qwen35-27b-gguf]       | `UD-Q5_K_XL` | ROCm    | `2048` | `816.90 t/s` | `23.87 t/s` |
| [Qwen3.5-27B][qwen35-27b-gguf]       | `UD-Q5_K_XL` | Vulkan  |  `512` | `880.33 t/s` | `27.87 t/s` |
| [Qwen3.5-27B][qwen35-27b-gguf]       | `UD-Q4_K_XL` | ROCm    | `2048` | `919.82 t/s` | `25.64 t/s` |
| [Qwen3.5-27B][qwen35-27b-gguf]       | `UD-Q4_K_XL` | Vulkan  |  `512` | `904.69 t/s` | `31.00 t/s` |
| [Gemma 4 31B IT][gemma4-31b-it-gguf] | `UD-Q5_K_XL` | ROCm    | `2048` | `565.01 t/s` | `21.50 t/s` |
| [Gemma 4 31B IT][gemma4-31b-it-gguf] | `UD-Q5_K_XL` | Vulkan  |  `512` | `693.36 t/s` | `25.14 t/s` |
| [Gemma 4 31B IT][gemma4-31b-it-gguf] | `UD-Q4_K_XL` | ROCm    | `2048` | `596.13 t/s` | `23.59 t/s` |
| [Gemma 4 31B IT][gemma4-31b-it-gguf] | `UD-Q4_K_XL` | Vulkan  |  `512` | `708.24 t/s` | `28.47 t/s` |

Main single-GPU observations:

- Qwen3.5-27B is faster than Gemma 4 31B IT in these dense runs, which matches the parameter-count difference.
- Vulkan is the clear single-GPU winner for interactive decode.
- Vulkan also gives more stable ubatch behavior on single GPU.
- ROCm benefits more from larger ubatch on long-prompt prompt processing, especially `pp2048`.
- Decode throughput is mostly insensitive to ubatch size; ubatch mainly tunes prompt-processing throughput.

## 2 GPU Results Summary

The two-GPU results are only available for `UD-Q5_K_XL`. The pattern is consistent across both dense models: two-GPU layer split does not improve interactive decode. ROCm is roughly flat to slightly slower, while Vulkan loses a large amount of decode speed.

| Model                                | Backend | 1 GPU `tg256` | 2 GPU `tg256` | Decode change | 1 GPU `pp2048` | 2 GPU `pp2048` | Prefill change |
| ------------------------------------ | ------- | ------------: | ------------: | ------------: | -------------: | -------------: | -------------: |
| [Qwen3.5-27B][qwen35-27b-gguf]       | ROCm    |       `23.87` |       `23.14` |         `-3%` |       `816.90` |       `820.65` |        `+0.5%` |
| [Qwen3.5-27B][qwen35-27b-gguf]       | Vulkan  |       `27.87` |       `19.96` |        `-28%` |       `880.33` |      `1341.27` |         `+52%` |
| [Gemma 4 31B IT][gemma4-31b-it-gguf] | ROCm    |       `21.50` |       `21.20` |         `-1%` |       `565.01` |       `572.36` |          `+1%` |
| [Gemma 4 31B IT][gemma4-31b-it-gguf] | Vulkan  |       `25.14` |       `19.50` |        `-22%` |       `693.36` |      `1047.75` |         `+51%` |

Main two-GPU observations:

- Two-GPU ROCm provides almost no prompt-processing gain and slightly reduces decode.
- Two-GPU Vulkan boosts long-prompt prefill by about `51-52%`.
- That Vulkan prefill gain comes with a `22-28%` decode penalty.
- On one GPU, Vulkan wins decode; on two GPUs, Vulkan can lose decode to ROCm.

Practical conclusion: for dense models that already fit on one GPU, use single-GPU Vulkan for chat and interactive inference. Use two-GPU Vulkan only when long-prompt prefill dominates the workload enough to justify the decode-speed loss.

[qwen35-27b-gguf]: https://huggingface.co/unsloth/Qwen3.5-27B-GGUF
[gemma4-31b-it-gguf]: https://huggingface.co/unsloth/gemma-4-31B-it-GGUF

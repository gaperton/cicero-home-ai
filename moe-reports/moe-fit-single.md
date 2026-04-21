# MoE Models Fitting a Single GPU

This report summarizes single-GPU MoE baselines for two models that fit fully on one 31 GiB GPU, then analyzes the performance cost of unloading MoE experts to CPU RAM with `--n-cpu-moe`.

Source reports:

- [Gemma 4 26B A4B IT single fit](gemma-4-26B-A4B-it/single-fit-UD-Q5_K_XL-20260419-170543.md)
- [Gemma 4 26B A4B IT expert offload sweep](gemma-4-26B-A4B-it/single-fit-moe-UD-Q5_K_XL-20260419-164051.md)
- [Qwen3.6-35B A3B single fit](Qwen3.6-35B-A3B/single-fit-UD-Q5_K_XL-20260419-180924.md)
- [Qwen3.6-35B A3B expert offload sweep](Qwen3.6-35B-A3B/single-fit-moe-UD-Q5_K_XL-20260419-181155.md)

## What Are MoE Models

MoE models contain multiple experts, but only a subset is active for each token. That lets them have high total parameter counts while keeping active compute lower than a dense model of the same size.

In these tests, both MoE models fit fully on one GPU at `UD-Q5_K_XL`. The `fit-moe` reports then force increasing numbers of experts into CPU RAM with `--n-cpu-moe 0,4,8,16,32,64` to measure the cost of expert unloading.

## MoE Models In Question

| Model | Params | Active profile | Q5 size | Notes |
|---|---:|---|---:|---|
| Gemma 4 26B A4B IT | `25.23B` | A4B | `19.75 GiB` | Smaller total model, 4B-active class |
| Qwen3.6-35B A3B | `34.66B` | A3B | `24.76 GiB` | Larger total model, 3B-active class |

Both models fit on a single 31 GiB GPU without expert unloading. That matters because the offload sweep shows that unloading experts is very expensive for decode speed.

## Hardware

| Component | Value |
|---|---|
| GPUs | 2x AMD Radeon AI PRO R9700 |
| VRAM | 31 GiB per GPU |
| RAM | 126 GiB |
| Kernel | `6.17.0-20-generic` |
| llama.cpp | `23b8cc499` from 2026-04-18 |
| Backends | ROCm and Vulkan |
| Vulkan mode | `RADV_DEBUG=nocompute` |
| Common bench flags | `-ngl 999 -fa on -r 3 -b 2048` |

The benchmark uses `pp512` and `pp2048` for prompt-processing throughput, and `tg256` for token-generation throughput. `tg256` is the closest number here to interactive chat speed.

## Single GPU Baseline

With all experts resident on GPU (`n_cpu_moe=0`), Vulkan is much faster than ROCm for Qwen3.6-35B A3B and Gemma 4 26B A4B IT. ROCm decode is almost identical across the two models, while Vulkan gives Qwen a clear lead.

Baseline snapshot at `n_cpu_moe=0`, ubatch `2048`:

| Model | Backend | `pp2048` | `tg256` |
|---|---|---:|---:|
| Gemma 4 26B A4B IT | ROCm | `1908.18 t/s` | `71.91 t/s` |
| Gemma 4 26B A4B IT | Vulkan | `3262.37 t/s` | `112.01 t/s` |
| Qwen3.6-35B A3B | ROCm | `2835.32 t/s` | `71.91 t/s` |
| Qwen3.6-35B A3B | Vulkan | `3471.48 t/s` | `129.34 t/s` |

Main baseline observations:

- On ROCm, both models decode at about `72 t/s`.
- On Vulkan, Qwen3.6-35B A3B reaches about `129 t/s`, around `15%` faster than Gemma 4 26B A4B IT at about `112 t/s`.
- Vulkan is about `56%` faster than ROCm for Gemma decode.
- Vulkan is about `80%` faster than ROCm for Qwen decode.
- Qwen has much higher ROCm prompt throughput than Gemma at `pp2048`, despite similar ROCm decode.

## Expert Unloading Results

The tables below use ubatch `2048` and compare every `n_cpu_moe` setting against `n_cpu_moe=0` for the same model and backend. Negative percentages are throughput loss.

### Gemma 4 26B A4B IT

| Backend | `n_cpu_moe` | `pp2048` | `pp2048` drop | `tg256` | `tg256` drop |
|---|---:|---:|---:|---:|---:|
| ROCm | `0` | `1908.18` | `0%` | `71.91` | `0%` |
| ROCm | `4` | `1670.86` | `-12%` | `56.46` | `-21%` |
| ROCm | `8` | `1465.12` | `-23%` | `43.47` | `-40%` |
| ROCm | `16` | `1134.73` | `-41%` | `30.05` | `-58%` |
| ROCm | `32` | `890.14` | `-53%` | `22.39` | `-69%` |
| ROCm | `64` | `883.28` | `-54%` | `22.53` | `-69%` |
| Vulkan | `0` | `3262.37` | `0%` | `112.01` | `0%` |
| Vulkan | `4` | `2132.35` | `-35%` | `70.68` | `-37%` |
| Vulkan | `8` | `1533.75` | `-53%` | `48.49` | `-57%` |
| Vulkan | `16` | `1107.67` | `-66%` | `34.40` | `-69%` |
| Vulkan | `32` | `714.73` | `-78%` | `23.10` | `-79%` |
| Vulkan | `64` | `706.77` | `-78%` | `23.16` | `-79%` |

Gemma's first offload step is already expensive. Moving only 4 experts to CPU costs about `21%` decode on ROCm and about `37%` decode on Vulkan. By `n_cpu_moe=32`, both backends fall to roughly dense-model decode speed.

### Qwen3.6-35B A3B

| Backend | `n_cpu_moe` | `pp2048` | `pp2048` drop | `tg256` | `tg256` drop |
|---|---:|---:|---:|---:|---:|
| ROCm | `0` | `2835.32` | `0%` | `71.91` | `0%` |
| ROCm | `4` | `2285.71` | `-19%` | `63.24` | `-12%` |
| ROCm | `8` | `1902.40` | `-33%` | `56.57` | `-21%` |
| ROCm | `16` | `1486.97` | `-48%` | `44.42` | `-38%` |
| ROCm | `32` | `1061.90` | `-63%` | `33.05` | `-54%` |
| ROCm | `64` | `934.93` | `-67%` | `29.07` | `-60%` |
| Vulkan | `0` | `3471.48` | `0%` | `129.34` | `0%` |
| Vulkan | `4` | `2259.38` | `-35%` | `91.59` | `-29%` |
| Vulkan | `8` | `1688.42` | `-51%` | `65.78` | `-49%` |
| Vulkan | `16` | `1225.91` | `-65%` | `49.69` | `-62%` |
| Vulkan | `32` | `804.91` | `-77%` | `34.36` | `-73%` |
| Vulkan | `64` | `705.15` | `-80%` | `29.84` | `-77%` |

Qwen handles small ROCm offloads better than Gemma on decode: `n_cpu_moe=4` costs about `12%` on ROCm. Vulkan still starts much faster, but its relative penalty is larger, with a `29%` decode drop at `n_cpu_moe=4` and a `77%` drop by `n_cpu_moe=64`.

## Cross-Model Findings

- If the model fits, keep all experts on GPU.
- Expert unloading hurts decode immediately, even at `n_cpu_moe=4`.
- Vulkan has the fastest no-offload decode, but it is also more sensitive to expert unloading.
- ROCm has lower no-offload decode, but it degrades more gently for Qwen at small offload counts.
- Large offloads collapse the MoE advantage: by `n_cpu_moe=32` or `64`, decode falls into the same range as much slower dense-model baselines.
- Prompt throughput and decode throughput do not degrade identically; always check `tg256` separately for interactive workloads.

## Practical Recommendation

For MoE models that already fit on one GPU, the best default is:

- single GPU
- Vulkan
- `n_cpu_moe=0`
- no expert unloading

Use expert unloading only as a last resort when the model cannot otherwise fit. It is not a benign memory-saving toggle; it is a direct throughput tradeoff. For interactive use, even unloading 4 experts is costly enough to change the user-visible speed.

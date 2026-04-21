# Gemma 4 31B IT Baseline Findings

Analyzed reports:

- `single-fit-UD-Q5_K_XL-20260419-224613.md`
- `all-fit-UD-Q5_K_XL-20260420-230216.md`
- `single-fit-UD-Q4_K_XL-20260419-225217.md`

## X-Ready Summary

More GPUs did not mean faster chat for Gemma 4 31B IT. In these llama.cpp runs on dual Radeon AI PRO R9700s, single-GPU Vulkan was the best interactive baseline. Two-GPU Vulkan produced much higher long-prompt prefill throughput, but decode speed dropped sharply.

### Headline Findings

- `UD-Q4_K_XL` is about `10%` faster than `UD-Q5_K_XL` for decode on ROCm (`23.59` vs `21.50 t/s`).
- `UD-Q4_K_XL` is about `13%` faster than `UD-Q5_K_XL` for decode on Vulkan (`28.47` vs `25.14 t/s`).
- On one GPU, Vulkan beats ROCm for `UD-Q5_K_XL` decode by about `17%` (`25.14` vs `21.50 t/s`).
- On two GPUs, Vulkan loses to ROCm for `UD-Q5_K_XL` decode by about `8%` (`19.50` vs `21.20 t/s`).
- Moving `UD-Q5_K_XL` from one GPU to two GPUs drops decode by about `1%` on ROCm and about `22%` on Vulkan.
- Two-GPU Vulkan improves `UD-Q5_K_XL` long-prompt prefill by about `51%` on `pp2048` (`693.36` to `1047.75 t/s`), but that comes at the cost of decode speed.
- Two-GPU ROCm gives almost no long-prompt gain at the selected ubatch: `pp2048` rises by only about `1%` (`565.01` to `572.36 t/s`).

### Practical Read

For interactive inference, use single-GPU Vulkan. For prompt-heavy prefill workloads, two-GPU Vulkan may be worth testing. For a speed-oriented quant, `UD-Q4_K_XL` gives a clean decode boost over `UD-Q5_K_XL`.

### Decode Snapshot

`UD-Q5_K_XL`, selected ubatch per backend:

| Config | Decode |
|---|---:|
| 1 GPU ROCm | `21.50 t/s` |
| 1 GPU Vulkan | `25.14 t/s` |
| 2 GPU ROCm | `21.20 t/s` |
| 2 GPU Vulkan | `19.50 t/s` |

### Caveat

These are hardware- and backend-specific results from llama.cpp on dual Radeon AI PRO R9700 GPUs. Treat the conclusion as a baseline for this setup, not a universal rule for all models, drivers, or multi-GPU systems.

## Scope

This report compares:

- `UD-Q5_K_XL` on a single GPU
- `UD-Q5_K_XL` across all GPUs
- `UD-Q4_K_XL` on a single GPU

The goal is to separate direct observations from higher-level conclusions.

## Fixed-Ubatch Comparison

To compare `single` and `all` more cleanly, this section chooses one ubatch per `quant + backend` and then reports the throughput range at that fixed ubatch. Here, "best ubatch" means the setting that gives the strongest overall balance for that `quant + backend`, with `tg256` weighted more heavily than small prompt-throughput differences because decode speed is the more user-visible metric in interactive inference. `512` and `default` are treated as the same setting.

### Selected Ubatch by Quant and Backend

- `UD-Q5_K_XL + ROCm`: `2048`
- `UD-Q5_K_XL + Vulkan`: `512`
- `UD-Q4_K_XL + ROCm`: `2048`
- `UD-Q4_K_XL + Vulkan`: `512`

### Ranges at the Selected Ubatch

#### `UD-Q5_K_XL`

- `ROCm`, ubatch `2048`: `pp512` `298.77-299.15 t/s`, `pp2048` `565.01-572.36 t/s`, `tg256` `21.20-21.50 t/s`
- `Vulkan`, ubatch `512`: `pp512` `690.18-727.12 t/s`, `pp2048` `693.36-1047.75 t/s`, `tg256` `19.50-25.14 t/s`

### Two-GPU Change by Backend, `UD-Q5_K_XL`

- `ROCm`, single to two GPUs: `pp512` drops by about `0.1%` (`299.15` to `298.77 t/s`), `pp2048` improves by about `1%` (`565.01` to `572.36 t/s`), and `tg256` drops by about `1%` (`21.50` to `21.20 t/s`).
- `Vulkan`, single to two GPUs: `pp512` drops by about `5%` (`727.12` to `690.18 t/s`), `pp2048` improves by about `51%` (`693.36` to `1047.75 t/s`), and `tg256` drops by about `22%` (`25.14` to `19.50 t/s`).

### Backend Comparison, `UD-Q5_K_XL`

- Single GPU: Vulkan is about `143%` faster on `pp512` (`727.12` vs `299.15 t/s`), about `23%` faster on `pp2048` (`693.36` vs `565.01 t/s`), and about `17%` faster on `tg256` (`25.14` vs `21.50 t/s`).
- Two GPUs: Vulkan is about `131%` faster on `pp512` (`690.18` vs `298.77 t/s`) and about `83%` faster on `pp2048` (`1047.75` vs `572.36 t/s`), but about `8%` slower on `tg256` (`19.50` vs `21.20 t/s`).

#### `UD-Q4_K_XL`

- `ROCm`, ubatch `2048`: `pp512` `302.82 t/s`, `pp2048` `596.13 t/s`, `tg256` `23.59 t/s`
- `Vulkan`, ubatch `512`: `pp512` `744.75 t/s`, `pp2048` `708.24 t/s`, `tg256` `28.47 t/s`

### Quant Comparison, Single GPU

- `ROCm`: `UD-Q4_K_XL` is about `10%` faster than `UD-Q5_K_XL` on `tg256` (`23.59` vs `21.50 t/s`), about `6%` faster on `pp2048` (`596.13` vs `565.01 t/s`), and about `1%` faster on `pp512` (`302.82` vs `299.15 t/s`).
- `Vulkan`: `UD-Q4_K_XL` is about `13%` faster than `UD-Q5_K_XL` on `tg256` (`28.47` vs `25.14 t/s`), about `2%` faster on `pp2048` (`708.24` vs `693.36 t/s`), and about `2%` faster on `pp512` (`744.75` vs `727.12 t/s`).

## Observations

### 1. Single-GPU `UD-Q5_K_XL`

- On ROCm, `tg256` is effectively flat across ubatch sizes: `21.50`, `21.52`, `21.50 t/s`.
- On ROCm, `pp2048` improves strongly as ubatch increases: `294.01`, `451.77`, `565.01 t/s`.
- On ROCm, `pp512` is roughly flat across ubatch sizes: `306.47`, `299.19`, `299.15 t/s`.
- On Vulkan, `tg256` is effectively flat across ubatch sizes: `25.14`, `25.14`, `25.12 t/s`.
- On Vulkan, `pp512` stays in a narrow band: `727.12`, `718.91`, `719.20 t/s`.
- On Vulkan, `pp2048` stays in a narrow band: `693.36`, `700.74`, `696.40 t/s`.
- At every tested ubatch size, single-GPU Vulkan is faster than single-GPU ROCm for `tg256`.
- At every tested ubatch size, single-GPU Vulkan is much faster than single-GPU ROCm for prompt processing.

### 2. All-GPU `UD-Q5_K_XL`

- On ROCm, all-GPU `tg256` is `21.01`, `21.22`, `21.20 t/s`, slightly below the single-GPU ROCm range.
- On ROCm, all-GPU `pp2048` is `283.36`, `457.91`, `572.36 t/s`, closely matching the single-GPU ROCm pattern.
- On ROCm, all-GPU `pp512` is `305.19`, `299.57`, `298.77 t/s`, also closely matching the single-GPU ROCm pattern.
- On Vulkan, all-GPU `tg256` is `19.50`, `19.52`, `19.05 t/s`, clearly below single-GPU Vulkan decoding.
- On Vulkan, all-GPU `pp2048` reaches `1047.75 t/s` at ubatch `512`, then drops to `878.10` at `1024` and `690.06` at `2048`.
- On Vulkan, all-GPU `pp512` ranges from `662.28` to `702.77 t/s`, below the single-GPU Vulkan `pp512` range.
- Among the all-GPU Vulkan results, the standout value is `pp2048` at ubatch `512`.

### 3. Single-GPU `UD-Q4_K_XL` versus Single-GPU `UD-Q5_K_XL`

- On ROCm, `UD-Q4_K_XL` is faster than `UD-Q5_K_XL` for decode at every tested ubatch size.
- On ROCm, single-GPU `UD-Q4_K_XL` `tg256` is `23.59-23.61 t/s` versus `21.50-21.52 t/s` for `UD-Q5_K_XL`.
- On ROCm, single-GPU `UD-Q4_K_XL` `pp2048` reaches `596.13 t/s` at ubatch `2048`, above the `565.01 t/s` peak for `UD-Q5_K_XL`.
- On Vulkan, `UD-Q4_K_XL` is faster than `UD-Q5_K_XL` for decode at every tested ubatch size.
- On Vulkan, single-GPU `UD-Q4_K_XL` `tg256` is `28.46-28.47 t/s` versus `25.12-25.14 t/s` for `UD-Q5_K_XL`.
- On Vulkan, single-GPU `UD-Q4_K_XL` prompt-processing throughput is slightly higher than `UD-Q5_K_XL`.
- For both quants, Vulkan remains faster than ROCm in the single-GPU runs.

### 4. Ubatch Behavior

- Decode throughput (`tg256`) is largely insensitive to ubatch size in all single-GPU runs.
- ROCm long-prompt throughput responds strongly to larger ubatch values.
- Single-GPU Vulkan is more stable across ubatch sizes than ROCm for prompt processing.
- All-GPU Vulkan is the least stable configuration in the compared runs because its `pp2048` result changes substantially across ubatch sizes.

## Conclusions

### 1. Best Balanced Configuration in These Results

Single-GPU Vulkan with `UD-Q5_K_XL` is the strongest balanced configuration in this set when both prompt speed and generation speed matter. It is consistently faster than single-GPU ROCm, and unlike all-GPU Vulkan, it does not trade away decode throughput to achieve higher prompt throughput.

### 2. Multi-GPU Splitting Does Not Help Decoding Here

For `UD-Q5_K_XL`, distributing the model across both GPUs does not improve generation speed in either backend. On ROCm it is roughly flat to slightly worse, and on Vulkan it is clearly worse for `tg256`. In this dataset, adding the second GPU helps little for balanced throughput and can actively hurt interactive decoding.

### 3. All-GPU Vulkan Looks Specialized Rather Than General-Purpose

The all-GPU Vulkan configuration appears useful mainly for long-prompt ingestion, especially at `pp2048` with ubatch `512`. However, because decode speed falls to about `19.5 t/s`, this mode looks better suited to prompt-heavy batch or prefill-oriented workloads than to interactive chat-style inference.

### 4. Ubatch Is Mainly a Prompt-Throughput Tuning Lever

The results suggest ubatch size matters far more for prompt processing than for token generation. If the workload is decode-heavy, ubatch choice is not likely to change the user experience much. If the workload is prompt-heavy on ROCm, larger ubatches can materially improve `pp2048`.

### 5. `UD-Q4_K_XL` Buys Measurable Speed Headroom

Moving from `UD-Q5_K_XL` to `UD-Q4_K_XL` improves decode throughput on the same single-GPU backend. The gain is about `10%` on ROCm and about `13%` on Vulkan, while prompt-processing gains are smaller.

### 6. Recommended Default Based on These Runs

If one default runtime configuration must be chosen from these results alone, the best candidate is:

- single GPU
- Vulkan
- `UD-Q5_K_XL`

That choice provides the best overall balance of throughput, stability across ubatch sizes, and interactive decode performance. If maximum speed is preferred over the higher quant, `UD-Q4_K_XL` on single-GPU Vulkan is the faster option.

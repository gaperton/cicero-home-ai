# Qwen3.5-27B Baseline Findings

Analyzed reports:

- `single-fit-UD-Q5_K_XL-20260419-223027.md`
- `all-fit-UD-Q5_K_XL-20260419-224046.md`
- `single-fit-UD-Q4_K_XL-20260419-223518.md`

## X-Ready Summary

More GPUs did not mean faster chat. In these Qwen3.5-27B llama.cpp runs on dual Radeon AI PRO R9700s, single-GPU Vulkan was the best interactive baseline. Two-GPU Vulkan produced much higher long-prompt prefill throughput, but decode speed fell sharply.

### Headline Findings

- `UD-Q4_K_XL` is `7-11%` faster than `UD-Q5_K_XL` for decode, depending on backend.
- On one GPU, Vulkan beats ROCm for `UD-Q5_K_XL` decode by about `17%` (`27.87` vs `23.87 t/s`).
- On two GPUs, Vulkan loses to ROCm for `UD-Q5_K_XL` decode by about `14%` (`19.96` vs `23.14 t/s`).
- Moving `UD-Q5_K_XL` from one GPU to two GPUs drops decode by about `3%` on ROCm and about `28%` on Vulkan.
- Two-GPU Vulkan improves `UD-Q5_K_XL` long-prompt prefill by about `52%` on `pp2048` (`880.33` to `1341.27 t/s`), but that comes at the cost of decode speed.
- Two-GPU ROCm gives almost no long-prompt gain at the selected ubatch: `pp2048` rises by only about `0.5%` (`816.90` to `820.65 t/s`).

### Practical Read

For interactive inference, use single-GPU Vulkan. For prompt-heavy prefill workloads, two-GPU Vulkan may be worth testing. For a speed-oriented quant, `UD-Q4_K_XL` gives a modest but consistent decode boost over `UD-Q5_K_XL`.

### Decode Snapshot

`UD-Q5_K_XL`, selected ubatch per backend:

| Config | Decode |
|---|---:|
| 1 GPU ROCm | `23.87 t/s` |
| 1 GPU Vulkan | `27.87 t/s` |
| 2 GPU ROCm | `23.14 t/s` |
| 2 GPU Vulkan | `19.96 t/s` |

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

- `ROCm`, ubatch `2048`: `pp512` `604.52-620.53 t/s`, `pp2048` `816.90-820.65 t/s`, `tg256` `23.14-23.87 t/s`
- `Vulkan`, ubatch `512`: `pp512` `884.16-894.11 t/s`, `pp2048` `880.33-1341.27 t/s`, `tg256` `19.96-27.87 t/s`

### Two-GPU Change by Backend, `UD-Q5_K_XL`

- `ROCm`, single to two GPUs: `pp512` improves by about `3%` (`604.52` to `620.53 t/s`), `pp2048` improves by about `0.5%` (`816.90` to `820.65 t/s`), and `tg256` drops by about `3%` (`23.87` to `23.14 t/s`).
- `Vulkan`, single to two GPUs: `pp512` drops by about `1%` (`894.11` to `884.16 t/s`), `pp2048` improves by about `52%` (`880.33` to `1341.27 t/s`), and `tg256` drops by about `28%` (`27.87` to `19.96 t/s`).

### Backend Comparison, `UD-Q5_K_XL`

- Single GPU: Vulkan is about `48%` faster on `pp512` (`894.11` vs `604.52 t/s`), about `8%` faster on `pp2048` (`880.33` vs `816.90 t/s`), and about `17%` faster on `tg256` (`27.87` vs `23.87 t/s`).
- Two GPUs: Vulkan is about `43%` faster on `pp512` (`884.16` vs `620.53 t/s`) and about `63%` faster on `pp2048` (`1341.27` vs `820.65 t/s`), but about `14%` slower on `tg256` (`19.96` vs `23.14 t/s`).

#### `UD-Q4_K_XL`

- `ROCm`, ubatch `2048`: `pp512` `644.45 t/s`, `pp2048` `919.82 t/s`, `tg256` `25.64 t/s`
- `Vulkan`, ubatch `512`: `pp512` `919.00 t/s`, `pp2048` `904.69 t/s`, `tg256` `31.00 t/s`

## Observations

### 1. Single-GPU `UD-Q5_K_XL`

- On ROCm, `tg256` is effectively flat across ubatch sizes: `23.90`, `23.86`, `23.87 t/s`.
- On ROCm, `pp2048` improves as ubatch increases: `652.28`, `759.98`, `816.90 t/s`.
- On ROCm, `pp512` is highest at ubatch `512` and lower at `1024` and `2048`: `671.35`, `609.42`, `604.52 t/s`.
- On Vulkan, performance is very stable across ubatch sizes.
- On Vulkan, `tg256` remains `27.86-27.87 t/s` across all tested ubatch values.
- On Vulkan, `pp512` remains `883-894 t/s` across all tested ubatch values.
- On Vulkan, `pp2048` remains `873-880 t/s` across all tested ubatch values.
- At every tested ubatch size, single-GPU Vulkan is faster than single-GPU ROCm for `tg256`.
- At every tested ubatch size, single-GPU Vulkan is also faster than single-GPU ROCm for both prompt-processing tests.

### 2. All-GPU `UD-Q5_K_XL`

- On ROCm, all-GPU `tg256` is `23.25`, `22.59`, `23.14 t/s`, which is slightly below the single-GPU ROCm `tg256` range.
- On ROCm, all-GPU `pp2048` is `650.81`, `745.09`, `820.65 t/s`, which is very close to the single-GPU ROCm pattern.
- On ROCm, all-GPU `pp512` is `667.39`, `623.79`, `620.53 t/s`, again close to the single-GPU ROCm pattern.
- On Vulkan, all-GPU `tg256` is `19.96`, `20.03`, `20.35 t/s`, clearly below single-GPU Vulkan decoding.
- On Vulkan, all-GPU `pp2048` reaches `1341.27 t/s` at ubatch `512`, then drops to `1114.15` at `1024` and `856.88` at `2048`.
- On Vulkan, all-GPU `pp512` is `884.16`, `849.42`, `847.53 t/s`, which is close to single-GPU Vulkan at ubatch `512` and lower at larger ubatches.
- Among the all-GPU Vulkan results, the standout value is `pp2048` at ubatch `512`.

### 3. Single-GPU `UD-Q4_K_XL` versus Single-GPU `UD-Q5_K_XL`

- On ROCm, `UD-Q4_K_XL` is faster than `UD-Q5_K_XL` for all three tests.
- On ROCm, single-GPU `UD-Q4_K_XL` `tg256` is `25.64-25.65 t/s` versus `23.86-23.90 t/s` for `UD-Q5_K_XL`.
- On ROCm, single-GPU `UD-Q4_K_XL` `pp2048` reaches `919.82 t/s` at ubatch `2048`, above the `816.90 t/s` peak for `UD-Q5_K_XL`.
- On Vulkan, `UD-Q4_K_XL` is faster than `UD-Q5_K_XL` for all three tests.
- On Vulkan, single-GPU `UD-Q4_K_XL` `tg256` is `30.99-31.00 t/s` versus `27.86-27.87 t/s` for `UD-Q5_K_XL`.
- On Vulkan, single-GPU `UD-Q4_K_XL` prompt-processing throughput is also slightly higher than `UD-Q5_K_XL`.
- For both quants, Vulkan remains faster than ROCm in the single-GPU runs.

### 4. Ubatch Behavior

- Decode throughput (`tg256`) is largely insensitive to ubatch size in all single-GPU runs.
- ROCm prompt throughput responds more strongly to ubatch changes than Vulkan prompt throughput.
- Single-GPU Vulkan is the most ubatch-stable configuration in the compared runs.
- All-GPU Vulkan is the least ubatch-stable configuration in the compared runs because its `pp2048` result changes substantially across ubatch sizes.

## Conclusions

### 1. Best Balanced Configuration in These Results

Single-GPU Vulkan with `UD-Q5_K_XL` is the strongest balanced configuration in this set when both prompt speed and generation speed matter. It is consistently faster than single-GPU ROCm, and unlike all-GPU Vulkan, it does not trade away decode throughput to achieve higher prompt throughput.

### 2. Multi-GPU Splitting Does Not Help Decoding Here

For `UD-Q5_K_XL`, distributing the model across both GPUs does not improve generation speed in either backend. On ROCm it is roughly a wash or slightly worse, and on Vulkan it is clearly worse for `tg256`. In this dataset, adding the second GPU helps little for balanced throughput and can actively hurt interactive decoding.

### 3. All-GPU Vulkan Looks Specialized Rather Than General-Purpose

The all-GPU Vulkan configuration appears useful mainly for long-prompt ingestion, especially at `pp2048` with ubatch `512`. However, because decode speed falls to about `20 t/s`, this mode looks better suited to prompt-heavy batch or prefill-oriented workloads than to interactive chat-style inference.

### 4. Ubatch Is Mainly a Prompt-Throughput Tuning Lever

The results suggest ubatch size matters far more for prompt processing than for token generation. If the workload is decode-heavy, ubatch choice is not likely to change the user experience much. If the workload is prompt-heavy on ROCm, larger ubatches can materially improve `pp2048`.

### 5. `UD-Q4_K_XL` Buys Measurable Speed Headroom

Moving from `UD-Q5_K_XL` to `UD-Q4_K_XL` improves both prompt and decode throughput on the same single-GPU backend. The gain is noticeable but not transformative: it improves speed while preserving the same overall backend ranking and tuning behavior.

### 6. Recommended Default Based on These Runs

If one default runtime configuration must be chosen from these results alone, the best candidate is:

- single GPU
- Vulkan
- `UD-Q5_K_XL`

That choice provides the best overall balance of throughput, stability across ubatch sizes, and interactive decode performance.

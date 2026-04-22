# Qwen3.5-122B-A10B Baseline Findings

This report summarizes Qwen3.5-122B-A10B on dual Radeon AI PRO R9700 GPUs. Unlike the smaller dense and MoE models, this model does not fit comfortably on one GPU. The useful baseline is therefore an all-GPU layer split, with Q3 fitting cleanly and Q4-class quants requiring CPU expert offload plus fit-target placement.

Source reports:

- [All-GPU Q3 fit baseline](all-fit-UD-Q3_K_XL-20260419-193127.md)
- [All-GPU Q3 expert offload sweep](all-fit-moe-UD-Q3_K_XL-20260419-193525.md)
- [Single-GPU Q3 no-fit vs fit-target](single-no-fit-moe-UD-Q3_K_XL-20260419-201753.md)
- [All-GPU IQ4 no-fit vs fit-target](all-no-fit-moe-UD-IQ4_XS-20260419-204231.md)
- [All-GPU Q4 XL no-fit vs fit-target](all-no-fit-moe-UD-Q4_K_XL-20260419-211546.md)
- [All-GPU Q4 S no-fit vs fit-target](all-no-fit-moe-Q4_K_S-20260419-221746.md)

## X-Ready Summary

Qwen3.5-122B-A10B is the first model in this set where placement strategy dominates everything. Q3 fits across both GPUs and reaches about `50 t/s` decode on Vulkan. Naive heavy CPU expert offload collapses Q4-class runs to about `12-14 t/s`. Fit-target placement recovers much of the lost speed, especially for `UD-IQ4_XS`, which reaches about `50 t/s` on Vulkan while staying in an IQ4-class quant.

### Headline Findings

- `UD-Q3_K_XL` is the clean all-GPU baseline: Vulkan reaches about `49.9 t/s`, while ROCm reaches about `36-37 t/s`.
- On the Q3 fit baseline, Vulkan is about `39%` faster than ROCm for decode at ubatch `2048` (`49.90` vs `35.96 t/s`).
- Expert offload is very expensive: Q3 Vulkan drops from about `50 t/s` to about `31 t/s` at `n_cpu_moe=4`, and to about `13 t/s` by `n_cpu_moe=64`.
- Naive `--n-cpu-moe 999` placement is slow for Q4-class quants: decode lands around `11.6-13.7 t/s`.
- Fit-target placement is a major recovery mechanism. For `UD-IQ4_XS`, Vulkan improves from `12.30` to `49.91 t/s` at ubatch `2048`, about a `306%` uplift.
- `UD-IQ4_XS + Vulkan + fit-target` is the standout Q4-class result: it roughly matches the Q3 Vulkan decode baseline while using the smaller `56.08 GiB` IQ4 quant.
- `UD-Q4_K_XL` and `Q4_K_S` ROCm fit-target runs crashed before completing the full ubatch `2048` row, so those results should be treated as incomplete.

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

`pp512` and `pp2048` measure prompt-processing throughput. `tg256` measures token-generation throughput and is the closest number here to interactive chat speed.

## Model And Quant Sizes

| Quant | Size | Placement mode tested | Notes |
|---|---:|---|---|
| `UD-Q3_K_XL` | `53.05 GiB` | All-GPU fit | Clean two-GPU baseline |
| `UD-IQ4_XS` | `56.08 GiB` | All-GPU no-fit plus fit-target | Best Q4-class result |
| `Q4_K_S` | `66.77 GiB` | All-GPU no-fit plus fit-target | Q4 small quant, partial ROCm fit-target result |
| `UD-Q4_K_XL` | `71.73 GiB` | All-GPU no-fit plus fit-target | Largest tested Q4-class quant, partial ROCm fit-target result |

The dual-GPU system has about `62 GiB` of total VRAM, so the `53.05 GiB` Q3 and `56.08 GiB` IQ4 quant are plausible all-GPU targets. The larger Q4 variants exceed aggregate VRAM and require substantial CPU involvement.

## Q3 All-GPU Fit Baseline

`UD-Q3_K_XL` is the stable baseline because it fits across both GPUs without intentional expert offload.

Selected results:

| Backend | Ubatch | `pp512` | `pp2048` | `tg256` |
|---|---:|---:|---:|---:|
| ROCm | `512` | `816.77` | `758.17` | `36.68` |
| ROCm | `1024` | `743.20` | `1104.50` | `36.92` |
| ROCm | `2048` | `740.72` | `1387.91` | `35.96` |
| Vulkan | `512` | `835.53` | `1333.41` | `49.87` |
| Vulkan | `1024` | `858.65` | `1410.83` | `49.91` |
| Vulkan | `2048` | `847.19` | `1268.40` | `49.90` |

Main observations:

- Vulkan decode is stable around `49.9 t/s` across ubatch values.
- ROCm decode is stable around `36-37 t/s`.
- ROCm benefits from larger ubatch on `pp2048`, rising from `758` to `1388 t/s`.
- Vulkan prompt throughput is strong at all ubatches, but `pp2048` peaks at ubatch `1024`.

## Q3 Expert Offload Drop

The Q3 expert-offload sweep shows the cost of moving experts out of GPU memory even when the model otherwise fits. The table below uses ubatch `2048` and compares each `n_cpu_moe` setting against `n_cpu_moe=0`.

| Backend | `n_cpu_moe` | `pp2048` | `pp2048` drop | `tg256` | `tg256` drop |
|---|---:|---:|---:|---:|---:|
| ROCm | `0` | `1386.86` | `0%` | `36.40` | `0%` |
| ROCm | `4` | `1157.54` | `-17%` | `31.56` | `-13%` |
| ROCm | `8` | `996.84` | `-28%` | `28.25` | `-22%` |
| ROCm | `16` | `779.57` | `-44%` | `23.70` | `-35%` |
| ROCm | `32` | `555.18` | `-60%` | `17.73` | `-51%` |
| ROCm | `64` | `451.91` | `-67%` | `14.59` | `-60%` |
| Vulkan | `0` | `1269.61` | `0%` | `49.97` | `0%` |
| Vulkan | `4` | `873.99` | `-31%` | `31.05` | `-38%` |
| Vulkan | `8` | `723.32` | `-43%` | `26.89` | `-46%` |
| Vulkan | `16` | `457.58` | `-64%` | `20.92` | `-58%` |
| Vulkan | `32` | `288.84` | `-77%` | `15.38` | `-69%` |
| Vulkan | `64` | `235.89` | `-81%` | `13.41` | `-73%` |

Expert unloading is not a small tax. On Vulkan, unloading just 4 experts cuts decode by about `38%`. On ROCm, the first step is gentler, but by `n_cpu_moe=64` both backends are near `14 t/s`.

## Single-GPU Q3 Fit-Target Result

Forcing the model onto one GPU with `--n-cpu-moe 999` is much slower than the all-GPU fit baseline. Fit-target helps, but it does not recover the all-GPU baseline.

At ubatch `2048`:

| Backend | Placement | `pp2048` | `tg256` |
|---|---|---:|---:|
| ROCm | No fit target | `464.49` | `14.44` |
| ROCm | Fit target `512 MiB` | `742.43` | `20.30` |
| Vulkan | No fit target | `259.32` | `14.57` |
| Vulkan | Fit target `512 MiB` | `497.24` | `20.51` |

Fit-target improves single-GPU Q3 decode by about `41%` on both ROCm and Vulkan, but the result is still far below the all-GPU Q3 baseline.

## Q4-Class No-Fit vs Fit-Target

The Q4-class reports use `--n-cpu-moe 999` and compare no fit target against `-fitt 512`. These are hard placement cases: the model is too large to place straightforwardly, so fit-target placement determines whether performance is usable.

### Best Completed Fit-Target Results

| Quant | Backend | Ubatch | No-fit `tg256` | Fit-target `tg256` | Decode uplift | Fit-target `pp2048` |
|---|---|---:|---:|---:|---:|---:|
| `UD-IQ4_XS` | ROCm | `2048` | `13.68` | `36.96` | `+170%` | `1386.68` |
| `UD-IQ4_XS` | Vulkan | `2048` | `12.30` | `49.91` | `+306%` | `1283.26` |
| `UD-Q4_K_XL` | Vulkan | `2048` | `11.60` | `26.94` | `+132%` | `623.67` |
| `Q4_K_S` | ROCm | `512` | `13.03` | `31.91` | `+145%` | `567.55` |

`UD-IQ4_XS` is the clear winner in the completed results. With Vulkan and fit-target, it reaches the same decode level as the Q3 all-GPU Vulkan baseline while keeping a Q4-class quant. ROCm also performs well on `UD-IQ4_XS`, reaching about `37 t/s`, close to the Q3 ROCm baseline.

### Incomplete Or Unstable Results

- `UD-Q4_K_XL + ROCm + fit-target` crashed before the ubatch `2048` row completed.
- `Q4_K_S + ROCm + fit-target` also crashed during the ubatch `2048` section.
- `UD-Q4_K_XL + ROCm + fit-target` has very noisy partial rows, including `19.51 ± 11.55 t/s` at ubatch `512`.
- `Q4_K_S + ROCm + fit-target` has a noisy ubatch `1024` decode result, `23.55 ± 14.41 t/s`.

These unstable rows should not be used as final recommendations. The reliable Q4-class recommendation from the completed data is `UD-IQ4_XS`, especially on Vulkan.

## Practical Recommendation

For this hardware and these runs:

- Use `UD-IQ4_XS + Vulkan + fit-target 512 MiB` when you want the best completed Q4-class result.
- Use `UD-Q3_K_XL + Vulkan` as the cleanest all-GPU fit baseline.
- Avoid naive `--n-cpu-moe 999` without fit-target; it collapses decode to about `12-14 t/s`.
- Avoid expert unloading when the model already fits; even small offloads cause large decode losses.
- Treat the `UD-Q4_K_XL` and `Q4_K_S` ROCm fit-target runs as incomplete until re-run successfully.

The main lesson is placement, not just quant size. A smaller or better-fitting quant with good placement can beat a larger quant that spills poorly into CPU expert offload.

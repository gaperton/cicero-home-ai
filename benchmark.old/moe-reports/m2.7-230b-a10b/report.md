# MiniMax-M2 230B.A10B — fitt Benchmark Report

## Test Description

**Model:** MiniMaxAI/MiniMax-M2.7 IQ4\_XS quantization (113.99 GiB, 228.69B total / 10B active params)  
**Date:** 2026-04-18  
**Hardware:** 2× AMD Radeon AI PRO R9700 (31 GiB VRAM each), 126 GiB RAM  
**llama.cpp:** 23b8cc499 (2026-04-18)

**Varied parameters:**
- Backend: ROCm, Vulkan
- `--fitt`: absent vs `--fitt 512`
- `n_ubatch`: 512, 1024, 2048

**Fixed parameters:**
- `sm=layer` (tensor-parallel split across both GPUs)
- `n_cpu_moe=999` (all MoE expert layers on CPU)
- `-ngl 99 -fa on -r 3`
- Tests: pp512, pp2048, tg256

---

## Raw Results

### ROCm — no --fitt

| ubatch | pp512 | pp2048 | tg256 |
|-------:|------:|-------:|------:|
| 512 | 52.47 ± 1.24 | 38.90 ± 14.03 | 8.74 ± 0.03 |
| 1024 | 56.04 ± 0.56 | 102.62 ± 0.48 | 8.37 ± 0.36 |
| 2048 | 56.66 ± 0.23 | 191.20 ± 0.76 | 8.67 ± 0.12 |

### ROCm — --fitt 512

| ubatch | pp512 | pp2048 | tg256 |
|-------:|------:|-------:|------:|
| 512 | 97.25 ± 3.70 | 98.06 ± 0.21 | 14.93 ± 0.05 |
| 1024 | 97.67 ± 0.52 | 145.64 ± 58.31 | 14.91 ± 0.04 |
| 2048 | 97.67 ± 0.86 | 306.42 ± 3.51 | 14.93 ± 0.01 |

### Vulkan — no --fitt

| ubatch | pp512 | pp2048 | tg256 |
|-------:|------:|-------:|------:|
| 512 | 37.01 ± 0.35 | 37.14 ± 0.29 | 7.78 ± 0.01 |
| 1024 | 37.18 ± 0.12 | 66.28 ± 0.03 | 7.69 ± 0.13 |
| 2048 | 37.22 ± 0.03 | 117.25 ± 0.51 | 7.77 ± 0.01 |

### Vulkan — --fitt 512

| ubatch | pp512 | pp2048 | tg256 |
|-------:|------:|-------:|------:|
| 512 | 69.84 ± 1.39 | 71.34 ± 0.43 | 14.21 ± 0.02 |
| 1024 | 71.50 ± 0.27 | 120.86 ± 0.23 | 14.11 ± 0.13 |
| 2048 | 71.68 ± 0.27 | 191.97 ± 0.12 | 14.20 ± 0.07 |

---

## Observations

1. **`--fitt 512` roughly doubles throughput across all metrics and both backends** — pp512 +72–93%, pp2048 +60–64%, tg256 +71–82%.

2. **ubatch has a massive effect on pp2048 but not pp512 or tg256.** Without fitt on ROCm: 38.9 t/s at ub512 → 191.2 t/s at ub2048 (5× gain). The effect persists with fitt: 98 → 306 t/s (3×). pp512 is nearly flat across ubatch values in all conditions. tg256 is completely unaffected by ubatch.

3. **ROCm outperforms Vulkan consistently** — ~36% on pp512 with fitt, ~60% on pp2048 with fitt, but only ~5% on tg256 with fitt (gap nearly disappears).

4. **Two anomalous high-variance measurements:**
   - ROCm no-fitt, ub512, pp2048: 38.90 ± 14.03 (±36% — highly unstable)
   - ROCm fitt, ub1024, pp2048: 145.64 ± 58.31 (±40% — highly unstable)

5. **tg256 with fitt is nearly identical across backends** — ROCm 14.93 vs Vulkan 14.20 t/s. Without fitt: ROCm 8.67 vs Vulkan 7.77 t/s.

---

## Interpretation and Conclusions

**`--fitt 512` is mandatory for this model.** The gain is too large to ignore — nearly 2× on every metric. It should be set by default in any serving configuration for MiniMax-M2.

**`n_ubatch=2048` is the optimal setting** for any workload involving prompts longer than ~512 tokens. For short prompts or pure chat (mostly tg-bound), the difference is negligible.

**ROCm is the preferred backend** for prompt-heavy workloads. For interactive chat (tg-bound), the backends are essentially equivalent with fitt enabled, making Vulkan a viable fallback if ROCm has stability issues.

**Best configuration:** `--fitt 512 -ub 2048` on ROCm delivers 306 t/s at pp2048 and 14.9 t/s at tg256 — competitive with much smaller models like Qwen3-35B (~277 pp2048, 12.4 tg256 on the same hardware), which confirms the layer-split + CPU-offloaded MoE architecture scales efficiently.

---

## Causal Theories

**Why `--fitt` doubles throughput:** `-fitt 512` triggers `llama_params_fit()` — llama-bench's automatic layer-fitting feature. When active, llama-bench frees the current model, resets `n_gpu_layers` to defaults, and calls `llama_params_fit` to compute the maximum number of layers that fit across all GPU devices given a 512 MiB per-device free-memory margin. The result replaces the `-ngl 99` override.

The key: MiniMax-M2 is 114 GiB but total VRAM is only ~62 GiB (2× 31 GiB). With `-ngl 99` and no fitting, llama.cpp attempts to assign all 99 layers to GPU but the model overflows — some layers fall back to CPU in an uncontrolled way. With `--fitt 512` and `n_cpu_moe=999` (MoE experts on CPU), the fitting algorithm correctly accounts for which weights actually need VRAM (non-MoE layers only), and finds the true optimal `n_gpu_layers` that maximizes GPU utilization. This likely loads substantially more non-MoE compute onto GPU compared to the naïve `-ngl 99` overflow, explaining the ~2× speedup.

**Why ubatch matters for pp2048 but not pp512:** Prompt processing is memory-bandwidth-bound and benefits from large matrix multiplications. With ub=512, a 2048-token prompt is processed in 4 sequential chunks — each too small to fully saturate the GPU's GEMM throughput. With ub=2048, the entire prompt is one large matrix operation. pp512 fits in a single ub=512 chunk already, so larger ubatch provides no benefit.

**Why tg256 is unaffected by ubatch:** Token generation is strictly sequential (one token at a time), so ubatch size is irrelevant — the working set is always a single token's activations.

**Why the tg256 backend gap vanishes with fitt:** Without fitt, the GPU backend (ROCm or Vulkan) is the bottleneck for the attention + non-MoE layers. With fitt, the CPU-side MoE computation dominates tg latency for both backends equally, masking GPU differences.

**Why ROCm is faster than Vulkan for pp:** ROCm has native HIP kernel optimizations for AMD GFX1201 (RDNA4), while Vulkan uses compute shaders via RADV with `nocompute` workaround. The GEMM operations in prompt processing expose this gap most clearly. The smaller relative gap with fitt (36% vs ~60% without) suggests fitt reduces the GPU-side work enough that the kernel efficiency gap matters less.

**High variance at ub512 pp2048 and fitt ub1024 pp2048:** The ub512 case for pp2048 involves 4 sequential chunks with CPU-GPU synchronization between each; any jitter in the CPU MoE scheduling compounds across chunks. The fitt ub1024 anomaly (145 ± 58, between the expected 98 and 306) suggests the fitt chunking boundary (512) interacts unpredictably with ubatch=1024 for 2048-token prompts — possibly alternating between fast and slow scheduling paths across the 3 runs.

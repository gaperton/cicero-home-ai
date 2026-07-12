# Qwen3.5 27B Benchmark Analysis

On PCIe-only dual-GPU consumer systems, multi-GPU in llama.cpp is not a universal accelerator but a conditional one, effective primarily for large-batch prompt processing.

For this exact platform (2× AMD Radeon AI PRO R9700 on bifurcated PCIe v4 x8 + x8) and dense model fitting single GPU (Qwen3.5 27B):

- Keep Q5_K_XL as the main daily-driver quant.
- Use Vulkan + split none for normal interactive inference.
- Use ROCm + layer split only for long-context or high-prefill workloads.
- Do not use ROCm + row.
- Treat Q6_K_XL as unjustified unless downstream evals prove otherwise

## 1. Environment

**Motherboard:** ASUS ROG Strix X570-F Gaming
- Chipset: AMD X570
- RAM: **128 GB DDR4-3600, 4 DIMMs** (4× 32 GB, dual-channel; FCLK 1800 MHz)

**GPUs:** 2× AMD Radeon AI PRO R9700 (gfx1201, RDNA 4)
- Each: 32624 MiB VRAM
- Total: 65248 MiB (≈64 GB)
- Native interface: PCIe 5.0 — X570-F only has PCIe 4.0 slots, cards negotiate down

**PCIe slot topology (critical for multi-GPU behavior):**

| Slot | Physical | Electrical | Source | Bandwidth |
|------|----------|------------|--------|----------:|
| GPU 0 (slot 1) | x16 | **x8** | CPU direct | ~16 GB/s |
| GPU 1 (slot 2) | x16 | **x8** | CPU direct | ~16 GB/s |

The CPU's 16 PCIe 4.0 lanes are bifurcated x8/x8 across both slots. Both GPUs connect directly to the CPU PCIe controller — the X570 chipset is not in the path. There is no direct GPU-to-GPU interconnect (no NVLink, no xGMI/Infinity Fabric — those are Instinct/MI series only). Inter-GPU traffic routes through the CPU: **GPU 0 → CPU PCIe controller → GPU 1**, with effective bandwidth capped at ~16 GB/s per direction.

---

## 2. Experiment

### Benchmark

Qwen3.5 27B, **UD** (Unsloth Dynamic) quantization variants: Q4_K_XL, Q5_K_XL, Q6_K_XL. UD uses imatrix-guided non-uniform bit allocation across layers, giving better quality than standard K-quants at the same nominal bit depth.

| Quant     | Size (GiB) | Fits single GPU? |
|-----------|----------:|:----------------:|
| Q4_K_XL   | 16.40     | Yes (32.6 GB)    |
| Q5_K_XL   | 18.78     | Yes              |
| Q6_K_XL   | 23.90     | Yes              |

All three quants fit entirely in a single R9700. No model requires both GPUs to hold weights.

`llama-bench -m models/Qwen3.5-27B-UD-Q{4,5,6}_K_XL.gguf -ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row`

All layers on GPU, flash attention enabled. Measures prompt processing at three context lengths (512 / 2048 / 4096 tokens) and token generation (256 tokens), across all three split modes, repeated twice. Both ROCm and Vulkan backends tested under `RADV_DEBUG=nocompute`. Build `5d14e5d19 (8797)`.

### Prompt processing (pp) — tokens/sec

**Q4_K_XL**

| Backend | Split | pp512   | pp2048  | pp4096  |
|---------|-------|--------:|--------:|--------:|
| ROCm    | none  | 1133    | 1094    | 1053    |
| ROCm    | layer | 1092    | 1677    | **1800**|
| ROCm    | row   | 645     | 685     | 671     |
| Vulkan  | none  | 937     | 927     | 901     |
| Vulkan  | layer | 900     | 1422    | 1376    |
| Vulkan  | row   | 915     | 1435    | 1407    |

**Q5_K_XL**

| Backend | Split | pp512   | pp2048  | pp4096  |
|---------|-------|--------:|--------:|--------:|
| ROCm    | none  | 978     | 949     | 910     |
| ROCm    | layer | 935     | 1459    | **1572**|
| ROCm    | row   | 618     | 659     | 646     |
| Vulkan  | none  | 909     | 899     | 878     |
| Vulkan  | layer | 884     | 1388    | 1367    |
| Vulkan  | row   | 895     | 1395    | 1369    |

**Q6_K_XL**

| Backend | Split | pp512   | pp2048  | pp4096  |
|---------|-------|--------:|--------:|--------:|
| ROCm    | none  | 812     | 790     | 759     |
| ROCm    | layer | 782     | 1193    | **1286**|
| ROCm    | row   | 422     | 446     | 440     |
| Vulkan  | none  | 894     | 883     | 862     |
| Vulkan  | layer | 850     | 1356    | 1340    |
| Vulkan  | row   | 873     | 1330    | 1335    |

### Token generation (tg256) — tokens/sec

| Backend | Split | Q4_K_XL     | Q5_K_XL     | Q6_K_XL   |
|---------|-------|------------:|------------:|----------:|
| ROCm    | none  | 25.83       | 24.01       | 20.36     |
| ROCm    | layer | 23.98       | 21.65       | 19.37     |
| ROCm    | row   | 26.59       | 25.62       | 23.10     |
| Vulkan  | none  | **30.99**   | **27.90**   | **22.66** |
| Vulkan  | layer | 21.20       | 20.62       | 18.38     |
| Vulkan  | row   | 21.30       | 21.23       | 18.41     |

---

## 3. Observations

**Vulkan row and layer splits are equivalent.**

For Vulkan, row and layer deliver virtually identical PP at all context lengths and all quants. The distinction is irrelevant on this backend.

**Token generation ranking (best → worst):**

Single GPU (no split): Vulkan leads ROCm by 11–20%. With two GPUs: ROCm row > ROCm layer >> Vulkan row ≈ Vulkan layer. Splits hurt Vulkan TG severely (−30%); ROCm tolerates them (row: +3%, layer: −7%).

**Prompt processing ranking at large context (best → worst):**

Single GPU: ROCm is modestly faster than Vulkan. With two GPUs: ROCm layer dominates (up to 1800 t/s at pp4096), then Vulkan row ≈ Vulkan layer (~1400 t/s), then ROCm row — catastrophically slow (~670 t/s), worse than single GPU.

**Layer split gain is context-dependent.**

At pp512 split overhead negates any gain. By pp4096 the batch amortizes the inter-GPU transfer cost, yielding 50–70% speedup. The crossover is around pp1024–pp2048.

**Q6 disproportionately hurts performance for a modest accuracy gain.**

Throughput decreases monotonically Q4 → Q5 → Q6, but the steps are not equal. Q4→Q5 is a modest trade: +2.4 GiB VRAM, −14% PP, −10% TG. Q5→Q6 is a worse deal: +5.1 GiB VRAM, −17% PP, −19% TG — more cost, more penalty, for one extra bit per weight. Q6 is not worth it.

---

## 4. Causal Explanations

### Consistent with published findings

**Vulkan single-GPU leads ROCm in token generation.**
Confirmed independently. Phoronix measured ~22% faster TG for Vulkan over ROCm on the R9700; RDNA3 benchmarks show 15–27%. The root cause is documented in [ggml-org/llama.cpp#21043](https://github.com/ggml-org/llama.cpp/discussions/21043): the ROCm compiler generates suboptimal matrix kernels for gfx1201, achieving ~3.1 TFLOPS against an expected ~4.95 TFLOPS. A separate HIP idling bug keeps the GPU at elevated utilization between inference calls. Neither issue affects Vulkan.

**ROCm row split collapses on multi-GPU.**
Documented in [ggml-org/llama.cpp#10682](https://github.com/ggml-org/llama.cpp/issues/10682) — identical behavior on other multi-GPU AMD setups, including garbled output in some cases. The mechanism: row split requires an allreduce across GPUs after every layer (62+ synchronizations per forward pass for this model). These traverse the CPU PCIe controller with no direct P2P path, and traffic bounces through CPU memory. Back-of-envelope: ~2.5 GB of reduce traffic per pp4096 forward pass over a ~16 GB/s link, before any compute. The allreduce overhead dominates entirely.

**Splits hurt Vulkan TG more than ROCm TG.**
Consistent with published reports: *"When using Vulkan with split mode Row or Layer, performance is significantly worse than split mode None… ROCm does not see a massive performance degradation from split mode None to Layer."* The mechanism is latency: in layer split, each token's activation crosses GPU boundaries once per forward pass (~40 MB). ROCm's HIP peer memcpy handles this with lower round-trip latency than Vulkan's inter-GPU transfer path. The fixed overhead is proportionally more damaging to Vulkan because its single-GPU TG baseline is already faster, leaving less compute time to hide the transfer.

---

### Not in published literature

**ROCm layer split outperforms Vulkan layer split for prompt processing (except Q6).**
No published multi-GPU comparison on RDNA4 exists to validate or contradict this. The likely cause is `RADV_DEBUG=nocompute`, which forces Vulkan compute operations through the graphics queue rather than the async compute queue, degrading compute-bound throughput. The effect weakens at Q6 as the bottleneck shifts to memory bandwidth. Unconfirmed — requires a Vulkan run without `nocompute`.

**Vulkan row and layer splits are equivalent.**
Not discussed in any published source. The Vulkan backend's row and layer implementations appear to converge to the same communication pattern on this driver — either row split is remapped internally, or the Vulkan multi-GPU allreduce avoids the per-layer synchronization cost that destroys ROCm row. The mechanism is unknown without reading the llama.cpp Vulkan multi-GPU source.

---

### Contradicted finding

One report ([ggml-org/llama.cpp#21043](https://github.com/ggml-org/llama.cpp/discussions/21043)) describes a ~10× ROCm PP slowdown on gfx1201 for Qwen models attributed to a Delta Net kernel dispatch issue. This does not appear in our data — ROCm PP is competitive throughout. The discrepancy is likely a ROCm version difference; our build predates or postdates the affected version, or `RADV_DEBUG=nocompute` sidesteps the issue.

---

## 5. Conclusions

1. The second GPU is useful mainly for prompt ingestion, not for steady-state generation.

Because all tested quants fit on a single 32 GB R9700, the second GPU is not needed for model residency. Its value is purely computational. In practice, that value appears only in prompt processing at medium and large batch/context sizes, where layer split can amortize inter-GPU communication. For single-user interactive chat dominated by token generation, one GPU is usually the better execution target.

2. For single-stream inference, the best default is Vulkan + no split.

Across all three quants, Vulkan / split=none gives the best token generation throughput, which is the metric users feel most directly during chat. Since generation latency dominates the perceived responsiveness of an interactive assistant, this should be treated as the default serving mode whenever the model fits on one card.

3. For long-context prompt ingestion, the best mode is ROCm + layer split.

At pp2048 and pp4096, ROCm / split=layer is clearly the best performer, and in some cases dramatically so. This makes it the right choice for workloads such as:

- very long system prompts,
- large-document ingestion,
- heavy RAG context packing,
- multi-thousand-token prefills before short answers.

4. ROCm row split should be treated as effectively broken on this platform.

Its prompt-processing behavior is not merely suboptimal; it is structurally wrong for this PCIe topology. Because the two GPUs communicate only through the CPU PCIe root complex, row split’s per-layer reduction traffic turns into a communication-bound regime that wipes out the theoretical benefit of parallelism. On this machine, ROCm row is not a tuning option; it is a failure mode.

5. Vulkan multi-GPU split modes are usable, but strategically uninteresting.

Vulkan row/layer split avoids the catastrophic collapse seen in ROCm row, but neither split mode preserves Vulkan’s single-GPU token-generation advantage. So Vulkan multi-GPU is not useless, but it does not produce a compelling “best of both worlds” result. It is a compromise mode, not an optimal one.

6. Q5_K_XL is the rational quality/performance point.

Q4 is the speed leader, but Q5 gives a moderate cost increase for a still-manageable throughput penalty. Q6, by contrast, consumes much more VRAM and loses too much speed for what is likely a marginal quality improvement relative to Q5. Unless a specific eval shows clear task-level gains, Q6 should be rejected as an inefficient point on the frontier. Therefore:

- best speed: Q4_K_XL
- best balanced choice: Q5_K_XL
- not recommended: Q6_K_XL

7. The machine’s real optimization target is workload routing, not one universal backend choice.

These data do not support the idea that one backend/split combination is globally best. Instead, the system wants mode switching by workload:

- Interactive chat / assistants / coding: Vulkan, no split, single GPU
- Large prefills / long-document ingestion / batched prompt processing: ROCm, layer split, dual GPU
- Avoid: ROCm row
- Use Vulkan split only if operational constraints force multi-GPU under Vulkan

8. The broader implication is architectural: when the model fits on one card, multi-GPU in llama.cpp is a prefill accelerator, not a general inference accelerator.

That is the real lesson of this benchmark. On consumer AMD cards connected by PCIe without direct GPU-GPU interconnect, multi-GPU only helps when the compute batch is large enough to hide communication. It does not automatically improve end-user chat speed, and in some modes it makes it worse. The second GPU should therefore be understood as a specialized accelerator for prefills and larger concurrent workloads, not as a universal multiplier of performance.


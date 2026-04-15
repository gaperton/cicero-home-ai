# Qwen3.5 27B Benchmark Analysis

## Hardware Configuration

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
| GPU 1 (slot 3) | x16 | **x8** | CPU direct | ~16 GB/s |

The CPU's 16 PCIe 4.0 lanes are bifurcated x8/x8 across both slots. Both GPUs connect directly to the CPU PCIe controller — the X570 chipset is not in the path. There is no direct GPU-to-GPU interconnect (no NVLink, no xGMI/Infinity Fabric — those are Instinct/MI series only). Inter-GPU traffic routes through the CPU: **GPU 0 → CPU PCIe controller → GPU 1**, with effective bandwidth capped at ~16 GB/s per direction.

---

**Benchmark:**
Test command: `llama-bench -ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row`
Environment: `RADV_DEBUG=nocompute` applied to both backends.
Build: `5d14e5d19 (8797)`

---

## 1. Facts

### Model sizes vs. VRAM

| Quant     | Size (GiB) | Fits single GPU? |
|-----------|----------:|:----------------:|
| Q4_K_XL   | 16.40     | Yes (32.6 GB)    |
| Q5_K_XL   | 18.78     | Yes              |
| Q6_K_XL   | 23.90     | Yes              |

All three quants fit entirely in a single R9700. No model requires both GPUs to hold weights.

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

## 2. Explanations

### Why layer split accelerates prompt processing

PP is compute-bound (many tokens processed in parallel). With `--split-mode layer`, the first half of the transformer layers runs on GPU 0 and the second half on GPU 1, effectively doubling compute resources. At pp512 there is no gain — the overhead of moving the activation tensor between GPUs costs as much as the saved compute. By pp4096 the batch is large enough to fully amortize that overhead, and both backends see ~50–70% speedup.

The crossover point is somewhere around pp1024–pp2048.

### Why ROCm layer PP is faster than Vulkan layer PP (except Q6)

ROCm uses the HIP compute path natively on gfx1201. The Vulkan tests are run with `RADV_DEBUG=nocompute`, which forces compute operations through the graphics queue rather than the dedicated async compute queue. This likely degrades multi-GPU throughput for compute-bound operations. The effect diminishes with larger quants (Q6) because the bottleneck shifts toward memory bandwidth even in PP. This is an implication, not confirmed — it would need a Vulkan run without `nocompute` to isolate.

### Why Vulkan none is faster than ROCm none for token generation

TG is memory-bandwidth bound: each generated token reads all weight matrices once. No data parallelism exists (batch size = 1). The RADV Vulkan driver appears to have lower per-kernel dispatch overhead for sequential memory-bound operations on this architecture than the ROCm HIP runtime, resulting in 11–20% higher throughput. The `nocompute` flag should not affect memory bandwidth, so this is likely a genuine driver-level difference.

### Why ROCm row split is terrible for PP (and TG)

Row split distributes each weight matrix across both GPUs column-wise. Every matrix multiply requires an allreduce (sum partial results) across GPUs at every layer. Qwen3.5 27B has 62 transformer layers, so every forward pass incurs 62+ inter-GPU synchronizations through the CPU PCIe controller. The result: ROCm row split PP is roughly **40% of ROCm none** — worse than single-GPU, not better.

Back-of-envelope: at pp4096, the reduce tensor is hidden_dim (5120) × batch (4096) × 2 bytes = ~40 MB per layer. With 62 layers, row split moves ~2.5 GB per forward pass over a ~16 GB/s PCIe 4.0 x8 link — about 0.15 seconds of transfer per forward pass, before compute. ROCm also has no zero-copy P2P between the two slots (traffic bounces through CPU memory), so effective throughput is likely lower than the raw PCIe ceiling. The allreduce overhead per layer dominates completely.

The same mechanism applies to TG but the effect is smaller because the per-token reduce tensor is tiny (5120 × 1 × 2 = 10 KB per layer), so allreduce round-trip latency rather than bandwidth becomes the bottleneck.

### Why Vulkan row split does NOT have this problem

This is unexpected. Vulkan row split PP matches Vulkan layer split at large contexts (within 2%). This suggests the Vulkan backend either: (a) implements row split differently — possibly deferring or batching communication; (b) uses a different synchronization primitive that maps better to PCIe transfers; or (c) the Vulkan split implementations for row and layer are effectively the same code path on this driver. The mechanism is **unknown** without inspecting the llama.cpp Vulkan backend source for multi-GPU allreduce.

### Why any split hurts TG more for Vulkan than ROCm

Vulkan TG drops 31% with layer split (31.0 → 21.2 t/s). ROCm TG drops only 7% (25.8 → 24.0 t/s). In layer split, each token's activation must cross from GPU 0 to GPU 1 **once per forward pass** through the PCIe 4.0 x8 link via the CPU. The transfer is small (~40 MB at the layer boundary), so bandwidth isn't the bottleneck — latency is. ROCm handles this via HIP peer memcpy with lower round-trip latency. Vulkan's inter-GPU transfer path appears higher-latency, so the fixed overhead is proportionally more expensive when per-token compute time is already short (~33–48 ms for a single token).

---

## 3. Practical Conclusions

### Best configuration by workload

**General serving (mixed prompt + generation):** ROCm + `--split-mode layer`
- PP throughput at long context is dominant (up to 1800 t/s for Q4 at pp4096)
- TG penalty is small (−7%), acceptable
- Q4_K_XL gives the best absolute throughput

**Generation-heavy, short prompts (chat, interactive):** Vulkan + `--split-mode none`
- Best raw generation speed (31 t/s Q4)
- No multi-GPU benefit since PP at short context doesn't justify split overhead
- Q4_K_XL again optimal

**Row split:** Avoid with ROCm. Vulkan row is harmless but offers no advantage over Vulkan layer.

### Quant selection

Q4_K_XL is the practical choice:
- Fits in one GPU with 16 GiB headroom for KV cache
- Highest PP and TG absolute throughput
- Q5 and Q6 offer diminishing returns: Q6 has 46% more weight data for a quality gain that is marginal on a 27B model already quantized to 6-bit

Q5 is a reasonable compromise if quality is the priority and the 2.4 GiB difference from Q4 is tolerable.

### What remains unknown

1. **Effect of `RADV_DEBUG=nocompute` on Vulkan PP**: Is this the primary reason ROCm layer beats Vulkan layer, or is ROCm genuinely better at multi-GPU compute on gfx1201? A Vulkan run without this flag would answer it.

2. **Why Vulkan row split avoids the allreduce penalty**: The ROCm row split PP is catastrophic; Vulkan row is fine. This asymmetry is not explained by the benchmark data alone.

3. **PCIe bandwidth saturation**: Whether the layer split improvement plateaus beyond pp4096, or whether even larger batches continue to scale.

4. **KV cache impact**: All benchmarks use `-p` tokens with presumably no KV cache retained. Real serving with long sessions and KV cache pressure will change the VRAM headroom picture, especially for Q6 at high concurrency.

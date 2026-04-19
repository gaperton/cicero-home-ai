# llama.cpp MoE Inference — System and Data Paths

## System

**CPU: AMD Ryzen 5700X (Zen 3)**
- 8 cores / 16 threads, AVX2 (no AVX-512)
- Single CCX, no NUMA
- 16 PCIe 4.0 lanes total

**RAM: 4× 32 GB DDR4-3600 = 128 GB, dual-channel**
- Peak: 57.6 GB/s; practical (4-DIMM, 2 DPC): ~48–52 GB/s
- Shared across all CPU cores and PCIe devices

**GPU: AMD Radeon AI PRO R9700**
- RDNA4 (GFX1201), 31 GiB GDDR6, ~600 GB/s VRAM bandwidth (256-bit bus)

**1-GPU config: x16** — single GPU gets all 16 lanes → 32 GB/s to CPU RAM

**2-GPU config: x8 + x8** — lanes split into two independent groups, one per GPU

```
config   lanes/GPU   GPU↔CPU bandwidth   total simultaneous
──────   ─────────   ─────────────────   ──────────────────
1× GPU     x16            32 GB/s              32 GB/s
2× GPU      x8            16 GB/s              32 GB/s
```

## Model inference, all on GPU

All weights in VRAM. For a dense model, each layer runs: layer norm → attention → FFN → residual. For MoE, FFN is replaced by a router + sparse expert dispatch:

```
token IDs
  │
  ▼ embedding lookup
  │
  for each layer:
    layer norm → attention → residual
    router → top-K indices + scores
    K expert matmuls           reads K of E expert tensors from VRAM
    weighted sum → residual
  │
  ▼ output norm → lm_head → logits
```

Only K expert tensors read per layer per token — E-K sit in VRAM unused. Bottleneck: VRAM bandwidth.

**Prefill (pp):** N tokens processed together as a matrix [N × hidden_dim]. Chunked into `ubatch`-sized GEMMs — larger ubatch = bigger matrix per launch = better GPU utilization.

**Generation (tg):** One token at a time — [1 × hidden_dim] vector per step. Memory bandwidth-bound; compute is idle.

**Flash attention (`-fa`):** Tiles attention, avoids materializing the full [N × N] score matrix. Saves VRAM at long context, ~20–30% faster on prefill.

## MoE model, GPU + CPU experts

Expert tensors too large for VRAM. `--n-cpu-moe N` pins expert tensors for layers 0..N to CPU RAM via `tensor_buft_override`. Attention and router weights stay in VRAM.

Where the expert matmul runs depends on batch size. The GPU backend offloads ops from CPU only when `batch_size >= 32` (default threshold, overridable via `GGML_OP_OFFLOAD_MIN_BATCH`). For `MUL_MAT_ID`, batch size is the token count.

**Generation (1 token, batch < 32) — matmul on CPU:**

```
hidden state
  │
  ▼ router                     GPU, weights in VRAM
  │
  ▼ top-K indices + activation  CPU RAM
                                K expert matmuls against weights in RAM
  ▼ result                      GPU
  │
  ▼ weighted sum → next layer
```

Activation crosses PCIe to CPU, expert matmuls run in RAM, result returns to GPU.
Bottleneck: CPU compute + RAM read bandwidth.

**Prefill (N tokens, batch ≥ 32) — matmul on GPU:**

```
hidden state
  │
  ▼ router                     GPU, weights in VRAM
  │
  ▼ top-K indices              scheduler reads ids tensor
  │
  │  CPU RAM → GPU VRAM        K expert tensors over PCIe
  │                            (only used experts, grouped consecutively)
  ▼ MUL_MAT_ID                 GPU, expert weights now in VRAM
  │
  ▼ weighted sum → next layer
```

Activations stay on GPU. What crosses PCIe is weight data — K expert tensors per MoE layer. The same weights serve the whole ubatch.
Bottleneck: PCIe bandwidth (weight copies) + RAM read bandwidth.

## --fitt: automatic placement

`--fitt N` (margin in MiB) calls `llama_params_fit()` which decides per-layer whether expert tensors go to VRAM or CPU RAM, maximizing VRAM use. It does not use `--n-cpu-moe` — it sets `tensor_buft_overrides` directly.

**Algorithm (MoE model):**

1. Move ALL expert tensors to CPU RAM. Check if dense-only weights fit across all GPUs.
2. **Back-to-front:** Fill each GPU with as many dense-only layers as fit (experts in CPU RAM), starting from the last GPU.
3. **Front-to-back:** Convert dense-only layers to full layers (experts back into VRAM), starting from the first GPU, until each GPU is full.

The result is a mixed placement — early layers tend to be full (experts in VRAM), later layers dense-only (experts in CPU RAM):

```
layers:    [ 0 .. F ]  [ F+1 .. L ]
experts:     VRAM         CPU RAM
```

where F is however many full layers fit given the available VRAM and the N MiB margin.

**With sm=none (1 GPU):** single GPU gets as many full layers as fit, rest dense-only.

**With sm=layer (2 GPUs):** back-to-front fill assigns dense-only layers to GPU1 first, then GPU0. Front-to-back conversion then promotes GPU0's layers to full first. Result: GPU0 tends to have experts in VRAM, GPU1 tends to pull experts from CPU RAM — unless enough VRAM exists for all layers on both GPUs.

This is why `--fitt` outperforms manual `--n-cpu-moe 999`: instead of keeping all experts in CPU RAM, it fits as many as possible into VRAM and only spills the remainder.

## Two GPUs, all VRAM

`sm=layer` splits transformer layers evenly across GPU0 and GPU1. All weights in VRAM. Works identically for dense and MoE — the split is at layer boundaries regardless of what runs inside each layer.

```
hidden state
  │
  ▼ [GPU0 — layers 0..L/2]
    per-layer compute (VRAM)
  │
  ▼ activation handoff
    ROCm:   hipMemcpyPeerAsync — direct P2P over PCIe
    Vulkan: GPU0 VRAM → CPU RAM → GPU1 VRAM
  │
  ▼ [GPU1 — layers L/2..L]
    per-layer compute (VRAM)
  │
  ▼ logits
```

GPU0 and GPU1 work sequentially — GPU1 waits on GPU0's completion event. The activation handoff is negligible in size.

Bottleneck: VRAM bandwidth on each GPU for its share of expert reads.

## MoE model, two GPUs + CPU experts

`sm=layer` + `--n-cpu-moe`: non-expert weights split across GPUs, all expert weights in CPU RAM. Expert weights are partitioned by layer — GPU0 copies only layers 0..L/2 experts into its own VRAM, GPU1 copies only layers L/2..L experts into its own VRAM. No expert weights are shared or duplicated between GPUs.

```
hidden state
  │
  ▼ [GPU0 — layers 0..L/2, non-expert weights in VRAM]
    for each layer:
      attention, router              GPU0
      CPU RAM → GPU0 VRAM            K expert tensors, PCIe x8 (GPU0 lane)
      MUL_MAT_ID, weighted sum       GPU0
  │
  ▼ activation handoff to GPU1
    ROCm: P2P direct; Vulkan: via CPU RAM
  │
  ▼ [GPU1 — layers L/2..L, non-expert weights in VRAM]
    for each layer:
      attention, router              GPU1
      CPU RAM → GPU1 VRAM            K expert tensors, PCIe x8 (GPU1 lane)
      MUL_MAT_ID, weighted sum       GPU1
  │
  ▼ logits
```

GPU0 and GPU1 work sequentially. Each uses its own x8 lane for expert copies, but never simultaneously — GPU1 is idle while GPU0 copies experts, and vice versa.

Bottleneck: PCIe bandwidth (expert weight copies, one GPU at a time) + RAM read bandwidth.

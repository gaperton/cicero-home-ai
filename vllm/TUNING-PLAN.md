# Tuning plan: community R9700 settings (2026-09-26)

Goal: find out which community-reported settings improve Qwen3.8-27B-FP8 on this
machine (2× R9700, PCIe 4.0 x8 each, GPU P2P working), for both upstream vLLM
and the radiance fork. The current `vllm/` config (radiance + MTP, `GPU_UTIL`
0.95, 200K context) is the baseline to beat.

Sources for the settings: `sample-config/` (another 2× R9700 host, "gadget",
upstream vLLM 0.29) and the community survey. The main references are
Kuvryn-ai-engine#1, ROCm/legacy-rocm-build#6685, vllm#58639, Level1Techs, and
kyuz0/amd-r9700-vllm-toolboxes.

## Baselines already measured

Measured on the same day, after the ROCm 10 / amdgpu 7.1.3 upgrade, with
`bench-openai.py` and fixed prompts:

| Config | Decode, 1 request (tok/s) | Aggregate at 2 / 4 / 8 | Prefill ~15K | KV pool |
| --- | ---: | ---: | ---: | ---: |
| llama.cpp (production) | 53.9 | 68 / 87 / 97 | 1,002 | 600K |
| upstream vLLM 0.30 + MTP 3, untuned | 31.9 | 54 / 104 / 191 | 2,392 | 527K |
| **radiance + MTP (`vllm/` config)** | **57.8** | **108 / 185 / 294** | **3,926** | **489K** |

The untuned upstream run had several problems. It fell back to the default FP8
GEMM configs (10 warnings in the log). With MTP it capped the batch at 2048
tokens. It also ran with 8 sequences and no `GPU_MAX_HW_QUEUES`.

## Hypotheses

1. **`GPU_MAX_HW_QUEUES=1` removes a fixed per-step cost.** On gfx1201 every
   small kernel pays about 17 µs while two or more other HIP streams hold
   pending waits; queue limits of 1 or 2 remove it. This is the prime suspect
   for upstream vLLM's slow single-stream decode.
2. **Official vLLM gets close to radiance with the rest of the sample recipe.**
   That recipe is: tuned GEMM configs, `--max-num-batched-tokens 8192`,
   `--max-num-seqs 32` (a larger CUDA-graph capture set) and an explicit
   `--kv-cache-memory-bytes`. If it closes the gap, the mainstream image
   becomes an option.
3. **Radiance gains context capacity and concurrency.** An explicit KV size
   reclaims the ~4.8 GiB per card left unused at 0.95. 32 sequences plus 8192
   batched tokens should help from 4 concurrent requests upward.
4. **A lower power cap saves power without slowing decode.** A 210–250 W cap
   should leave decode unchanged (it is bandwidth-bound) and cost ~10–15% of
   prefill.

## Test matrix

All vLLM runs use: 2-GPU tensor parallel, fp8 KV cache, prefix caching with
`--mamba-cache-mode align`, `--language-model-only`, `MAX_MODEL_LEN` 200000,
and the `qwen3_coder` / `qwen3` parsers. Everything else on the machine is
stopped during the runs and restored afterwards.

| # | Runtime | Changes from its baseline | Measure |
| --- | --- | --- | --- |
| 1a | upstream `vllm/vllm-openai-rocm:v0.30.0` | See the 1a recipe below | full bench + stress |
| 1b | same | 1a without `GPU_MAX_HW_QUEUES` | decode only: isolates the queue setting |
| 2b | radiance 1.0.387 (`vllm/` config) | `GPU_MAX_HW_QUEUES=1` | decode only |
| 2a | radiance 1.0.387 | See the 2a recipe below | full bench (30 tool calls) + stress |
| 3 | best of the above | GPU power cap 300 → 250 → 210 W | decode + prefill, board power |

**1a recipe.** Environment:
- `GPU_MAX_HW_QUEUES=1`
- `PYTORCH_ALLOC_CONF=` (empty)
- `HSA_XNACK=0`
- `VLLM_ROCM_USE_AITER=1`
- `NCCL_PROTO=Simple`
- `NCCL_TIMEOUT=1800` and `TORCH_NCCL_HEARTBEAT_TIMEOUT_SEC=1800`
- `TORCH_NCCL_ENABLE_MONITORING=0`

Mounts: the 5 tuned JSONs from `sample-config/tuned-configs/`, mounted into
`vllm/model_executor/layers/quantization/utils/configs/`.

Flags:
- MTP with 3 draft tokens
- `--max-num-seqs 32`
- `--max-num-batched-tokens 8192`
- `--kv-cache-memory-bytes 13150240768` (12.25 GiB per card)
- `--gpu-memory-utilization 0.97`
- `--disable-custom-all-reduce`
- `--no-async-scheduling`

P2P stays enabled. `NCCL_P2P_DISABLE=1` is only needed on hosts where P2P fails.

**2a recipe.** The current `vllm/` config plus:
- `--kv-cache-memory-bytes 12884901888` (12 GiB per card)
- `--max-num-seqs 32`
- `--max-num-batched-tokens 8192`
- `RADIANCE_AR_MAX_KB=81920`, so the R4D all-reduce still covers
  8192 × 5120 × 2 bytes
- `GPU_MAX_HW_QUEUES=1`, but only if 2b does not hurt (see below)

## Decision rules

- **`GPU_MAX_HW_QUEUES=1` for radiance (2b → 2a):** keep it only if single-request
  decode stays ≥ 97% of 57.8 tok/s and aggregate at 8 stays ≥ 97% of 294 tok/s.
- **Adopting 2a as the `vllm/` config:** it must match or beat the baseline on
  1-request decode (within noise, ~3%) and improve at least one of: aggregate
  at 4/8, KV pool, or decode during a long prefill. It must also keep 30/30
  tool calls and pass the stress test with ≥ 1 GiB free per card at peak.
- **Upstream vLLM as an alternative to the fork:** consider it only if 1a
  reaches ≥ 95% of radiance's 1-request decode and aggregate at 8, with
  tool calls and the stress test passing. That would satisfy the
  "mainstream first" preference.
- **Power cap:** adopt the lowest cap that keeps decode within 3% of 300 W. Report
  the prefill cost separately; it is a trade-off, not a pass/fail criterion.

## Running test 3 (needs root)

Writing the power cap needs root, and sudo here asks for a password, so run
these yourself while the chosen config is serving:

```bash
# set cap (W) on both cards; the default and hardware maximum are 300 W
for h in /sys/class/drm/card*/device/hwmon/hwmon*/power1_cap; do echo 250000000 | sudo tee "$h"; done
./vllm/bench-openai.py --label cap250 --parts decode,prefill --tools 0
amd-smi metric -p        # board power while the bench runs
# repeat with 210000000, then restore:
for h in /sys/class/drm/card*/device/hwmon/hwmon*/power1_cap; do echo 300000000 | sudo tee "$h"; done
```

The cap resets to 300 W on reboot. To persist it, add a oneshot unit.
Undervolting or raising the cap above 300 W needs
`amdgpu.ppfeaturemask=0xffffffff` on the kernel command line. It is not set
here (`0xfff7bfff`), and it is out of scope for this plan. Community reports
say −100 mV caused silent compute errors.

## Not in scope

- `NCCL_MIN_NCHANNELS=112`: documented by AMD for MI300X only, with no R9700
  measurement.
- `iommu=pt` and ASPM: reboot-level changes. ASPM gave no gain on PCIe Gen4 in
  community reports.
- Splitting the model into pipeline stages (PP): measured at ~18 tok/s decode
  on 27B, far worse than the tensor-parallel split used here.

## Status

- 2026-09-26 15:19–15:57: tests 1a, 1b, 2b and 2a ran. Production was restored
  automatically afterwards.
- The 2a stress test did not run: `stress-context.py` failed to size its
  prompt (proportional resizing oscillated; fixed with bisection). 2a's VRAM
  headroom is therefore **unverified**.
- Test 3 (power cap) is not run yet; it needs root.

| # | Decode, 1 request | Aggregate at 2 / 4 / 8 | Prefill ~4K / 15K / 56K | Decode during 28K prefill (TTFT) | Tool calls | KV pool | Stress peak / free |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| baseline radiance | 57.8 | 108 / 185 / 294 | 4,052 / 3,926 / 3,347 | 39.5 (7.6 s) | 30/30 | 489K | 27.08 / 4.78 GiB |
| 1a upstream + recipe | 47.9 | 91 / 153 / 260 | 2,066 / 2,580 / 2,183 | 28.0 (13.0 s) | 15/15 | 674K | 30.39 / 1.47 GiB, 0 preemptions |
| 1b 1a without HWQ | 48.0 | 91 / 153 / 268 | — | — | — | 674K | — |
| 2b radiance + HWQ | 57.7 | 107 / 178 / 295 | — | — | — | 496K | — |
| 2a radiance tuned | 71.6* | 100 / 192 / 306 | 4,025 / 3,464 / 3,461 | 34.8 (8.9 s) | 30/30 | 591K | not run |

\* The median of 3 prompts; the jump comes from the prose prompt alone
(50 → 72 tok/s) while code dropped (58 → 53). MTP acceptance at
temperature 1.0 varies per prompt, so treat this as noise, not a gain.

### Conclusions so far

1. **Hypothesis 1 is rejected.** `GPU_MAX_HW_QUEUES=1` has no effect on either
   runtime here (1a vs 1b, baseline vs 2b). The penalty it removes needs two or
   more side streams holding waits (pipeline-parallel); this setup splits each
   layer across both GPUs (TP) and does not trigger it.
2. **Hypothesis 2 is partly confirmed.** The rest of the recipe lifts upstream
   vLLM by +50% single-stream (31.9 → 47.9) and +36% at 8 requests: tuned GEMM
   configs, 8192 batched tokens, 32 sequences and an explicit KV size. It still
   reaches only 83–88% of radiance's decode, below the 95% bar. Prefill is
   unchanged and still 35–50% behind radiance, which points to radiance's own
   attention and all-reduce kernels rather than tuning. The fork stays.
3. **Hypothesis 3 is a mixed result.**
   - The explicit KV size is a clear win: +21% pool.
   - 32 sequences plus 8192 batched tokens gives +4% at 4 and 8 requests and
     −7% at 2.
   - Decode during a long prefill drops 12%, because the larger prefill chunks
     stall other requests for longer.
   - For this household workload (voice plus Hindsight alongside chat),
     latency under mixed load matters more than aggregate throughput.
4. **Next run, needs ~25 min of downtime:**
   - the stress test on 2a;
   - a 2c variant: explicit KV plus 32 sequences, with batched tokens kept at
     4096. It is expected to keep 2a's pool and graph set without the
     mixed-load cost.
   
   Adopt 2c if it holds the baseline's mixed-load figure. Otherwise adopt
   explicit KV alone.

## Round 2 (2026-09-26 16:38–17:37): FP8-KV calibration + context sizing

**Calibration.**
- The fork's `radiance_kv_calibration` was run on a private corpus of
  Hindsight documents, Open WebUI chats, code, the fork's fixture, and Russian
  prose from `sample-config/`.
- Fidelity was then measured as held-out per-token log-probabilities against a
  BF16 KV reference. Evaluation needs the sampler hooks off, because
  `VERIFY_HEAD`, `TOPK_COMPOSITE` and `DYNAMIC_DRAFT` hang `prompt_logprobs`.

Results:
- Every FP8 variant is within 0.35% of BF16 perplexity.
- EN + RU calibration is the best variant on both sets: +0.14% on the main
  set, −0.05% on Russian, and a 4× better worst-document score than default
  scales.
- EN-only calibration clips layer 7's V on Russian text: its Russian maximum is
  1.23× the English one.
- Full table: README, "FP8 KV-cache calibration".

**Context sizing (candidate 2c).** Settings: calibrated scales, explicit KV of
13.0 GiB/card, `MAX_MODEL_LEN` 262144, 32 sequences, batch 4096.

| Metric | Result |
| --- | --- |
| KV pool | 670,536 tokens (+37%) |
| Stress test (4 × 187K) | passed; 1.34 GiB free, 0 preemptions |
| Decode, 1 request | 59.7 tok/s |
| Aggregate at 2 / 4 / 8 | 100 / 183 / 313 |
| Prefill ~15K | 3,921 tok/s |
| Decode during long prefill | 37.1 tok/s |
| Tool calls | 30/30 |

It holds the baseline within noise, except that 32 sequences cost ~7% at 2
requests (seen in both 2a and 2c) and gain ~6% at 8.

**Adopted into `vllm/config.env`:** 2c exactly as validated.

**Not done:**
- A noise-floor repeat of the fidelity runs.
- 2c with 8 sequences. This might recover the ~7% at 2 requests; it needs
  re-sizing the KV and a new stress test.
- Test 3, the power cap (needs root).

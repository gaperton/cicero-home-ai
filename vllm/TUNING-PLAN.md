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

## Round 3 (2026-09-26 20:18–21:59): sequences, MTP ceiling, remaining community settings

All runs use calibrated EN+RU scales, 262K context, and 13.0 GiB KV unless
noted. Decode figures are the median of 5 repetitions.

| Run | Decode, 1 request | Aggregate 2 / 4 / 8 | Long-prefill decode | KV pool |
| --- | ---: | ---: | ---: | ---: |
| 32 seqs, MTP ≤8 (control, via the unit) | 57.5 | 100 / 177 / 312 | 38.8 | 671K |
| 16 seqs, MTP ≤8 | 58.4 | 107 / 196 / 298 | 36.6 | 671K |
| 8 seqs, MTP ≤8 | 62.2 | 106 / 180 / 302 | 37.0 | 671K |
| 16 seqs, MTP ≤2 | 65.7 | 115 / 216 / 371 | 38.0 | 746K |
| 16 seqs, MTP ≤3 | 64.7 | 119 / 208 / 368 | 43.7 | 734K |
| 16 seqs, MTP ≤4 | 66.0 | 126 / 214 / 354 | 39.4 | 718K |
| 16 seqs, MTP ≤4, batch 2048 | 68.2 | 114 / 214 / 358 | 42.3 | 718K |
| 16 seqs, MTP ≤4, `R4D_ATTN_FP8=3` | 69.1 | 126 / 210 / 352 | 40.6 (prefill 56K +11%) | 718K |
| DFlash2 (z-lab drafter) | did not start (see README) | | | |
| **Final: 16 seqs, MTP ≤3, 13.44 GiB KV (via the unit)** | **72.6** | **119 / 214 / 359** | **41.4** | **759K** |

**Final config validation.**
- Stress test: 4 × 185–190K tokens, 0 preemptions, 1.32 GiB free per card.
- Tool calls: 30/30.

**Adopted into `vllm/config.env`:**
- `MAX_NUM_SEQS=16`
- `MTP_TOKENS=3`
- `KV_CACHE_MEMORY_BYTES=14428405760`

**Not adopted:**
- batch 2048: the mixed-load benefit is already covered by the MTP ceiling of 3.
- `R4D_ATTN_FP8`: small gain, and it changes numerics.
- DFlash2: blocked; see README.

**Still open:**
- The power cap (needs root).
- DFlash2 with the fork's own drafter.
- A noise-floor repeat of the fidelity runs.


## Appendix: detailed measurements (moved from README, 2026-09-26)

Evidence behind the README's final configuration and exclusion list, kept verbatim.

### Memory and context

**The context is one shared pool, not per-slot reservations.**
- **Pool size:** vLLM turns everything left after weights, CUDA graphs and
  working buffers into one KV-cache pool. Each request takes blocks as it grows
  and returns them when it finishes.
- **`MAX_MODEL_LEN`** only caps a single request; it reserves nothing.
- **When the pool is full**, vLLM queues new requests or preempts and
  recomputes the newest one. Requests slow down, but they do not fail.
- **Contrast with llama.cpp:** there, `ctx-size` is divided among `parallel`
  slots up front.

Each running request also holds a fixed-size recurrent state for the model's 48
gated-delta-net layers. Only 16 of the 64 layers are full attention and use the
KV cache. With the fp8 KV cache, context costs about 17 KB per token per card.

**The KV pool is sized explicitly.** Current configuration, measured on
2026-09-26 with host ROCm 10.0 and amdgpu 7.1.3:

| Setting | Value |
| --- | --- |
| `KV_CACHE_MEMORY_BYTES` | 13.44 GiB per card |
| KV pool | 758,606 tokens: 2.89 full 262K contexts, or ~29 Hindsight Reflects at their 26K median |
| Idle VRAM | 30.54 of 31.86 GiB per card |

**Why explicit.** With `GPU_UTIL` alone, vLLM budgets the card from a
profiling pass. At 0.95 that budget was 30.27 GiB per card:

| Budget item | GiB per card |
| --- | ---: |
| Weights and runtime | 16.34 |
| Reserve for peak activations | 3.98 |
| CUDA graphs | 3.36 |
| KV cache | 9.95 (489K tokens) |

The activation reserve never materialises. At 0.95, peak VRAM under the stress
test equalled idle, 27.08 GiB, with 4.78 GiB per card unused. An explicit KV
size hands that slack to the pool: 759K tokens versus 489K, +55%.

**How 13.44 GiB was chosen.** Idle VRAM depends on the CUDA-graph set, so the
size was fitted to the final `MAX_NUM_SEQS=16` / `MTP_TOKENS=3`:
1. With 13.0 GiB of KV the idle footprint was 30.09 GiB, 1.77 GiB free.
2. Raise the KV size by the excess over a 1.3 GiB margin, to 13.44 GiB.
3. Restart and confirm: 30.54 GiB idle, 1.32 GiB free.

For comparison, with 13.0 GiB of KV the idle footprint was 30.52 GiB at 32
sequences and MTP ceiling 8, and 30.12 GiB at 8 sequences.

**Is it safe?** Yes. The final config was started through `cicero-vllm.service`
and run through [`stress-context.py`](stress-context.py): four prompts of
185–190K tokens (750K in total, next to the 759K pool) plus four decode
streams. Every request completed with 0 preemptions, and VRAM stayed at the idle
30.54 GiB per card throughout. The margin matches the other R9700 host in
`sample-config/`, which runs about 1 GiB free.

**When to re-size.** Changing the image, the driver, `SPEC`, `MTP_TOKENS`, `MAX_NUM_SEQS` or
`--max-num-batched-tokens` changes graph and runtime memory. After any of those:
1. Start with the same `KV_CACHE_MEMORY_BYTES`.
2. Read idle VRAM (`amd-smi monitor -v`) and adjust to ~1.3 GiB free.
3. Re-run `./vllm/stress-context.py --long 4 --ctx 190000`.

`GPU_UTIL` must still pass vLLM's startup check (free ≥ `GPU_UTIL` × 31.86 GiB;
about 31.3 GiB is free at boot).

Earlier measurements, before the explicit size:
- `GPU_UTIL=0.95`, `MAX_MODEL_LEN=200000`: 489,473 tokens (456,578 on amdgpu
  6.19.14).
- `SPEC=off` at 0.90 with the vision encoder loaded: 690K tokens.

MTP costs a large part of any pool: about 3.4 GiB of CUDA graphs plus draft
buffers.

**Long prompts starve decode while they prefill.** Prefill is chunked into
4096-token steps (`--max-num-batched-tokens`), and every running request
advances once per step. With three ~190K-token prompts prefilling back to back,
the concurrent decode streams averaged about 3.7 tok/s. With a single 30K-token
prompt they stayed at 34 tok/s. Lowering `--max-num-batched-tokens` makes that
trade the other way: better decode latency, slower prefill.

### FP8 KV-cache calibration

The FP8 checkpoint ships no KV scales. By default vLLM stores K and V with a
scale of 1.0 in every layer, so FP8's range is ±448. The actual per-layer
maxima are very uneven: K reaches 12–22, while V grows with depth, from ~10 in
early layers to 138 in layer 63. Calibrated scales fit FP8's range to each
layer, which improves precision for small values.

**What is used.** `FP8_KV_SCALES` points at
`calibration/qwen3.8-27b-fp8-kv-enru-20260926.safetensors`. It holds 64 scalar
q/k/v/prob scales covering the 16 full-attention layers. The fork's runtime
loads it only after checking its checksum and its binding to this exact
checkpoint (`RADIANCE_FP8_KV_SCALES_VERIFY=1`). The `.manifest.json` beside it
records the observed maxima, the software versions and the corpus hash; it
contains no corpus text.

**How it was made.** [`calibrate-kv.sh`](calibrate-kv.sh) runs the fork's
calibrator, `radiance_kv_calibration`. It makes an eager pass over a private
corpus, records each layer's Q/K/V absolute maximum across both GPUs, and sets
`scale = amax × 1.05 / 448`.
[`build-calibration-corpus.py`](build-calibration-corpus.py) assembles that
corpus. It is written to `calibration/corpus/`, which is gitignored:

- Hindsight documents
- Open WebUI chats
- llama.cpp code
- Russian technical prose from `sample-config/`
- the fork's 8-prompt fixture

There is no automatic alternative. The old one-shot `--calculate-kv-scales`
option is gone from vLLM ≥ 0.28, both upstream and in this image, and vLLM has
no dynamic per-token FP8 KV scaling.

**Language matters, a little.** A Russian-only calibration stayed within the
English maxima on 47 of 48 tensors, with a median ratio of 0.97. The exception
is layer 7's V: 13.1 on Russian text against 10.7 on English, a ratio of 1.23.
English-only scales would clip it whenever Russian is in the context. Hence the
mixed EN + RU corpus.

**Fidelity check.** Per-token log-probabilities were computed on a held-out
set that shares no text with the calibration corpus. BF16 KV is the reference.
Evaluations ran without speculative decoding and with the sampler hooks off;
see Caveats.

| KV cache | Main set: 19 docs, 115K tokens | Russian set: 4 docs, 17K tokens | Worst Russian document |
| --- | ---: | ---: | ---: |
| BF16 (reference) | ppl 10.2628 | ppl 3.5031 | — |
| FP8, default scales | +0.19% | +0.15% | +0.036 nats/token |
| FP8, EN-only calibration | +0.34% | +0.19% | +0.020 |
| **FP8, EN + RU calibration (deployed)** | **+0.14%** | **−0.05%** | **+0.008** |

**What the fidelity check shows.**
- FP8 KV costs very little quality with any scales: ≤ 0.35% perplexity.
- EN + RU calibration is the best variant everywhere, including the worst
  Russian document, where it is about 4× better than default scales.
- All FP8 variants differ from BF16 by the same mean per-token amount, about
  0.15. That suggests most of the deviation comes from the kernel path and
  nondeterminism rather than the scales. No repeat run was made to measure that
  noise floor, so treat calibration as a small, consistent improvement, not a
  proven large one.
- Throughput is unchanged; the scales cost nothing at runtime.

**When to recalibrate.** Recalibrate after any change of `MODEL_REPO`, since
scales are bound to the checkpoint. Also recalibrate if the traffic mix changes
a lot, for example to a new language. The sidecar's verification refuses a
mismatched checkpoint at startup.

### Performance

All numbers were measured on this machine on 2026-09-26 with
[`bench-openai.py`](bench-openai.py) at Qwen's recommended sampling. The
llama.cpp row is the production preset at the time: UD-Q6_K, tensor split,
MTP draft 2, 3 slots. All vLLM rows use the official FP8 weights and an fp8 KV
cache, at `GPU_UTIL=0.90` and `MAX_MODEL_LEN=131072`.

| | llama.cpp | vLLM 0.30 | vLLM 0.30 + MTP 3 | radiance | **radiance + MTP** |
| --- | ---: | ---: | ---: | ---: | ---: |
| Decode, 1 request (tok/s) | 50.6 | 17.0 | 31.8 | 34.8 | **52.9** |
| Aggregate decode, 2 / 4 / 8 requests | 66 / 85 / 90 | 36 / 76 / 142 | 54 / 109 / 185 | 66 / 129 / 216 | **94 / 162 / 284** |
| Time to first token at 8 requests | 17.5 s | 0.51 s | 0.45 s | 1.6 s | **0.31 s** |
| Prefill, ~14K / ~55–62K tokens (tok/s) | 964 / 910 | 2,491 / 2,137 | 2,410 / 2,040 | 2,869 / 3,072 | 2,615 / 3,056 |
| Decode during a ~30K prefill (tok/s) | 16.0 | 12.5 | 22.4 | 25.1 | **33.9** |
| That prefill's time to first token | 33.7 s | 18.8 s | 13.6 s | 9.0 s | 11.3 s |
| Tool calls well-formed | 15/15 | 15/15 | 15/15 | 15/15 | 30/30 |
| KV pool (tokens) | 600K | 618K | 442K | 690K | 371K |

Radiance + MTP, per content type at one request: prose 45, code 53, JSON 109
tok/s. The mean accepted draft length was about 5.

**The current config** is `config.env` as committed:
- radiance with calibrated EN + RU KV scales
- MTP, capped at 3 draft tokens by the per-request controller
- `MAX_NUM_SEQS=16`
- a 13.44 GiB/card explicit KV pool
- `MAX_MODEL_LEN=262144` and `--language-model-only`

It was measured through `cicero-vllm.service` with the fixed-prompt benchmark
at 5 repetitions. The earlier `vllm/` configs, all measured after the ROCm 10
upgrade, are shown for comparison:

| Measure | Auto KV, 200K, 8 seqs, MTP ≤8 | Explicit 13.0 GiB, 262K, 32 seqs, MTP ≤8 | **Current** |
| --- | ---: | ---: | ---: |
| Decode, 1 request | 57.8 tok/s | 57.5–59.7 | **72.6*** (prose 62, code 73, JSON 98) |
| Aggregate decode, 2 / 4 / 8 requests | 108 / 185 / 294 | 100 / 177 / 312 | **119 / 214 / 359** |
| Time to first token at 8 requests | 0.28 s | 0.28 s | 0.28 s |
| Prefill, ~4K / 15K / 56K tokens | 4,052 / 3,926 / 3,347 | 4,053 / 3,922 / 3,343 | 4,063 / 3,957 / 3,366 |
| Decode during a ~28K prefill (its TTFT) | 39.5 tok/s (7.6 s) | 37.1–38.8 (7.7 s) | **41.4 (7.6 s)** |
| Tool calls well-formed | 30/30 | 30/30 | 30/30 |
| KV pool | 489K (2.45 × 200K) | 671K (2.56 × 262K) | **759K (2.89 × 262K)** |

\* The same config measured 64.7 tok/s in the tuning sweep below. Per-prompt
variation at one request is large (prose ~60, JSON ~100), so treat the
single-request figure as roughly 65–72.

### Tuning results (2026-09-26)

Each change was measured one at a time with explicit 13.0 GiB of KV, 262K
context and calibrated scales. The chosen value then carried into the next
step.

**Concurrent sequences** (MTP ceiling 8):

| `MAX_NUM_SEQS` | 1 request | Aggregate 2 / 4 / 8 | Decode during long prefill | Idle VRAM |
| ---: | ---: | ---: | ---: | ---: |
| 32 | 57.5 | 100 / 177 / 312 | 38.8 | 30.52 GiB |
| **16** | 58.4 | **107 / 196** / 298 | 36.6 | 30.31 GiB |
| 8 | 62.2 | 106 / 180 / 302 | 37.0 | 30.12 GiB |

- 32 sequences was consistently ~7% slower at 2 requests, in three runs.
- 8 and 16 tie within noise. 16 is kept for burst headroom and its lead at
  4 requests.
- More sequences capture more CUDA graphs, at ~0.2 GiB per step of this table.

**MTP draft-depth ceiling** (16 sequences). The fork's controller picks each
request's draft depth per step, up to the ceiling. It keeps drafting while the
product of the draft probabilities stays above `RADIANCE_DRAFT_TAU` = 0.28. It
also lowers the ceiling as the batch grows (1 → 8, 2 → 7, 4 → 6, 8 → 5, 16 → 4),
and copies verbatim n-gram continuations for free.

| `MTP_TOKENS` | 1 request | Aggregate 2 / 4 / 8 | Decode during long prefill | Prefill ~15K | KV pool | Mean accepted |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | 65.7 | 115 / 216 / **371** | 38.0 | 3,473 | **746K** | 2.17 |
| **3** | 64.7 | 119 / 208 / 368 | **43.7** | **3,948** | 734K | 2.43 |
| 4 | **66.0** | **126** / 214 / 354 | 39.4 | 3,439 | 718K | 2.64 |
| 8 | 58.4 | 107 / 196 / 298 | 36.6 | 3,910 | 671K | 2.84 |

- A ceiling of 8 over-drafts. On prose and code most deep drafts are rejected,
  and verifying them costs every request in the batch compute each step.
- Ceilings 3 and 4 are 11–13% faster at 1–4 requests and ~20% at 8, and they
  free 7–9% of the KV pool (fewer draft slots per sequence).
- 3 is kept. It ties 4 on throughput and is best under mixed load and on
  prefill. The other R9700 host also settled on 3.

**Other community settings** (16 sequences, MTP ceiling 4):

| Setting | Effect | Verdict |
| --- | --- | --- |
| `--max-num-batched-tokens 2048` (vs 4096) | +7% decode during a long prefill, −3% prefill, the rest noise | not adopted: ceiling 3 at 4096 already gives 43.7 tok/s under mixed load |
| `R4D_ATTN_FP8=3` (FP8 QK/PV prefill legs) | +11% prefill at 56K tokens, neutral elsewhere | not adopted: it changes attention numerics and would need a fidelity re-check for ~1.5 s saved per 56K prompt |
| `GPU_MAX_HW_QUEUES=1` | none, on radiance or upstream | not adopted (see `TUNING-PLAN.md`) |
| DFlash2 speculative decoding (z-lab drafter, 7 draft tokens) | does not start in this image | not adopted; see below |

**DFlash2 did not start.** This is the block-diffusion drafter behind the
community's 140–186 tok/s single-stream claims. Two blockers:
1. **Calibrated KV scales.** The fork's scale sidecar check also runs against the
   drafter checkpoint and refuses it ("FP8-KV sidecar was calibrated for a
   different checkpoint"). DFlash therefore needs default scales.
2. **Drafter compile.** With default scales, the fork's DFlash2 model code
   (`qwen3_dflash2.py`, `prepare()`) hits a `torch.compile`
   `ConstraintViolationError` on `input_ids` vs `positions` sizes during
   vLLM's startup profiling run. This happens even with `"enforce_eager": true`
   in the speculative config.

The fork only qualified DFlash with its own drafters
(`tcclaviger/Qwen3.8-27B-DFlash2-FP8` and a heretic-ARA drafter) and its exact
profile (8K context, prefix caching off for benchmarks). It still marks
DFlash experimental. Getting DFlash running here means trying that drafter or
profile, or isolating which of this config's flags trips the constraint.

### Retest after the ROCm 10 upgrade

The host moved from ROCm 7.14 + amdgpu 6.19.14 + kernel 7.0.0-31 to ROCm
10.0.0 (pre4) + amdgpu 7.1.3 + kernel 7.0.0-34. Every configuration above was
re-run with the same flags. The containers bring their own ROCm userspace, so
for them only the driver and kernel changed.

| Tok/s, before → after | 1 request | Aggregate at 8 | Prefill ~15K (after only) | KV pool |
| --- | ---: | ---: | ---: | ---: |
| llama.cpp, ROCm 7.14 build | 50.6 → 53.9 | 90 → 97 | 1,002* | 600K |
| llama.cpp, rebuilt on ROCm 10 | — → 56.7 | — → 92 | 875* | 600K |
| vLLM 0.30 | 17.0 → 17.0 | 142 → 142 | 2,482 | 618K → 709K |
| vLLM 0.30 + MTP 3 | 31.8 → 31.9 | 185 → 191 | 2,392 | 442K → 527K |
| radiance | 34.8 → 34.8 | 216 → 216 | 2,650 | 690K → 690K |
| radiance + MTP | 52.9 → 52.8 | 284 → 289 | 2,620 | 371K → 371K |
| production (0.95, 200K) | 57.8 → 57.8 | 305 → 294 | 3,926 | 457K → 489K |

\* Same fixed ~15K prompt for both llama.cpp builds. With identical prompts, the
ROCm 10 build prefilled 723 / 875 / 833 tok/s at ~4K / 15K / 56K tokens,
against 804 / 1,002 / 836 for the ROCm 7.14 build.

**Conclusions:**
- **Decode:** no runtime got faster. Changes stay within run-to-run noise
  (a few percent).
- **KV pool:** the only real gain is on vLLM with `--language-model-only`,
  where the pool is 7–15% bigger. Runs through the fork's own compose file
  load the vision encoder, and their profile did not change.
- **Keep llama.cpp on its ROCm 7.14 build.** Built on ROCm 10 it prefills up to
  ~13% slower, with the same decode.
- **Prefill figures before and after are not comparable.** Before this retest,
  prompts were cut at random offsets; the "after" figures use the fixed slices.
  The production run also had a warm compile cache.

### Why the fork and not upstream vLLM

- **Upstream's custom all-reduce is gated to MI300/MI350.** Each generated token
  needs ~128 per-layer all-reduces between the two cards. Upstream enables its
  fast custom all-reduce only on those GPUs (`use_custom_allreduce()` in
  `vllm/platforms/rocm.py`), so on gfx1201 every all-reduce goes through RCCL.
- **RCCL's fast protocol deadlocks on gfx12.** Its LL protocol has that
  deadlock ([ROCm/rccl#2187](https://github.com/ROCm/rccl/pull/2187), still
  open), so `NCCL_PROTO=Simple` is mandatory. That protocol is slow, which is
  why upstream vLLM gets only 17 tok/s for a single request, however fast the
  kernels are.
- **Radiance replaces that path.** It installs a P2P one-shot all-reduce
  (`[radiance] custom all-reduce INSTALLED` in the log; P2P access is enabled
  between the cards on this host). That alone doubles single-request decode,
  and MTP adds the rest.
- **Upstream's own fix is still open:** an RDNA4 all-reduce backend,
  [vllm#55916](https://github.com/vllm-project/vllm/issues/55916). When it
  lands, re-test upstream with this same `bench-openai.py`.

The link between the cards is PCIe 4.0 x8 (Ryzen 9 5900XT). The fork's
published figures come from PCIe 5.0 hosts.

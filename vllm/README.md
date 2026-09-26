# vLLM: Qwen3.8-27B FP8 on both R9700s

An alternative to the llama.cpp stack for when this machine serves **only
Qwen3.8-27B**. vLLM runs the official `Qwen/Qwen3.8-27B-FP8` checkpoint with
tensor parallelism across both cards, through
[vllm-radiance](https://github.com/magiccodingman/vllm-radiance): vLLM 0.30 plus
hand-written gfx1201 kernels. It serves the same API port and model id as the
router did, so clients do not change.

Versus the llama.cpp stack (Q6_K, tensor split, MTP): single-user speed is
about even, but prefill is ~3x faster and parallel or long-prompt workloads run
2–3x faster. See [Performance](#performance).

## What runs

| Component | Endpoint | Notes |
| --- | --- | --- |
| vLLM (container `cicero-vllm`) | `http://cicero.local:8080/v1`, model `qwen3.8-27b` | Both cards, TP=2, up to 262,144 tokens per request (native) from a shared 670K-token pool |
| Open WebUI | `http://cicero.local:3000` | Same data dir as before (`~/.open-webui`) |

Both run under one user unit, **`cicero-vllm.service`** (`run.sh`), the
counterpart of `cicero-home-ai.service`. The unit declares
`Conflicts=cicero-home-ai.service cicero-tts-server.service`: vLLM claims
`GPU_UTIL` of *both* cards, so starting it stops the llama.cpp stack and the
Vulkan TTS server, and starting either of those stops it.

**Not available in this mode.** They were served by the llama.cpp router or
share the cards:

- `qwen3-asr`: voice transcription through `audio/` (the ASR proxy's upstream).
- `qwen3-reranker`: Hindsight's Recall reranker
  (`HINDSIGHT_API_RERANKER_LITELLM_MODEL` in `~/.config/hindsight/hindsight.env`).
  vLLM answers requests for it with 404. Point it elsewhere or disable reranking
  before relying on Recall.
- TTS (`cicero-tts-server.service`, which uses about 5.5 GB on GPU1).

Hindsight's LLM calls, Hermes, mem0 and Open WebUI use `qwen3.8-27b` on :8080
and work unchanged.

## Install, switch, update

```bash
./vllm/install.sh            # pull the image (~4 GB), download the model (~29 GB), install the unit
./vllm/start.sh              # switch to vLLM now (stops llama.cpp + TTS), wait until ready
./vllm/stop.sh               # stop it; ./start.sh brings the llama.cpp stack back
./vllm/install.sh --enable   # make cicero-vllm.service the boot default
./vllm/update.sh             # re-pull the pinned image, refresh the model, restart if running
./vllm/update.sh 1.0.400     # move the pin to another radiance tag
./vllm/calibrate-kv.sh       # recalibrate FP8 KV scales (GPUs must be free); after a model change
```

- The first start compiles kernels for about 5 minutes. Later starts reuse
  `vllm/cache/` and take about 2 minutes.
- `update.sh` clears that cache whenever the image changes, because a stale
  `torch.compile`/Triton cache from another build fails or hangs.
- `update.sh` also prints when a newer tag is published, but it never moves the
  pin by itself. The image pins its own torch, Triton and vLLM versions as a
  set, and the fork warns that unqualified bumps have caused TP hangs.

Logs go to `logs/vllm.log`.

## Configuration

Everything lives in [`config.env`](config.env):

| Setting | Value | Meaning |
| --- | --- | --- |
| `IMAGE` | `magiccodingman/vllm-radiance:1.0.387` | Pinned fork build (vLLM 0.30.0, ROCm 7.14 userspace) |
| `MODEL_REPO` / `MODEL_DIR` | `Qwen/Qwen3.8-27B-FP8` → `models/Qwen3.8-27B-FP8` | Official block-FP8 weights with the built-in MTP head, 28.8 GiB |
| `SERVED_MODEL_NAME` / `PORT` | `qwen3.8-27b` / `8080` | Drop-in for the router |
| `GPU_UTIL` | `0.95` | With an explicit KV size this is only vLLM's startup check (free VRAM must cover it) |
| `KV_CACHE_MEMORY_BYTES` | `13958643712` (13.0 GiB/card) | Explicit KV pool: 670,536 tokens, validated with the stress test (see below) |
| `MAX_MODEL_LEN` | `262144` | Per-request ceiling, prompt plus output: the model's native limit |
| `MAX_NUM_SEQS` | `32` | Ceiling on simultaneously running requests |
| `SPEC` | `mtp` | `mtp`: fork's fast-draft MTP (up to 8 draft tokens). `off`: no speculative decoding |
| `FP8_KV_SCALES` | `vllm/calibration/qwen3.8-27b-fp8-kv-enru-20260926.safetensors` | Calibrated FP8 KV scales; empty = default scales (see below) |

The fixed server flags are in [`docker-compose.yml`](docker-compose.yml), each
with its reason: FP8 KV cache, R4D attention, prefix caching with
`--mamba-cache-mode align`, `--language-model-only`, and the `qwen3_coder` /
`qwen3` tool and reasoning parsers. They follow the fork's qualified compose file.

## Memory and context

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
| `KV_CACHE_MEMORY_BYTES` | 13.0 GiB per card |
| KV pool | 670,536 tokens: 2.56 full 262K contexts, or ~26 Hindsight Reflects at their 26K median |
| Idle VRAM | 30.52 of 31.86 GiB per card |

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
size hands that slack to the pool: +37% versus the previous config.

**How 13.0 GiB was chosen.**
1. Start at 12.5 GiB and read idle VRAM: 30.00 GiB, 1.86 GiB free.
2. Raise the KV size by the excess over a 1.3 GiB margin, to 13.0 GiB.
3. Restart and confirm: 30.52 GiB idle, 1.34 GiB free.

**Is it safe?** Yes. [`stress-context.py`](stress-context.py) ran four prompts
of 187K tokens each (749K in total, more than the pool) plus four decode
streams. Every request completed (the overflow queued, 0 preemptions), and VRAM
stayed at the idle 30.52 GiB per card throughout. The margin matches the other
R9700 host in `sample-config/`, which runs about 1 GiB free.

**When to re-size.** Changing the image, the driver, `SPEC`, `MAX_NUM_SEQS` or
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

## FP8 KV-cache calibration

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

## Performance

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

**The current config** is `config.env` as committed: radiance + MTP,
calibrated EN + RU KV scales, a 13.0 GiB/card explicit KV pool,
`MAX_MODEL_LEN=262144`, `MAX_NUM_SEQS=32` and `--language-model-only`. It is
compared below with the previous config (auto KV at `GPU_UTIL=0.95`,
`MAX_MODEL_LEN=200000`, `MAX_NUM_SEQS=8`), both measured after the ROCm 10
upgrade with the fixed-prompt benchmark:

| Measure | Previous | **Current** |
| --- | ---: | ---: |
| Decode, 1 request | 57.8 tok/s | 59.7 (prose 52, code 60, JSON 108) |
| Aggregate decode, 2 / 4 / 8 requests | 108 / 185 / 294 | 100 / 183 / 313 |
| Time to first token at 8 requests | 0.28 s | 0.28 s |
| Prefill, ~4K / 15K / 56K tokens | 4,052 / 3,926 / 3,347 | 4,048 / 3,921 / 3,231 |
| Decode during a ~28K prefill (its TTFT) | 39.5 tok/s (7.6 s) | 37.1 (7.7 s) |
| Tool calls well-formed | 30/30 | 30/30 |
| KV pool | 489K (2.45 × 200K) | **671K (2.56 × 262K)** |

The capacity gain is the point. Speed is otherwise the same within noise, with
one pattern that repeated across two runs: 32 sequences cost ~7% aggregate at
2 requests and gain ~6% at 8, versus 8 sequences.

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

## Caveats

- **Radiance is an experimental fork.** It is maintained by one person on top
  of StillDeadcode's libr4d, and marked experimental.
  - **Tool calls with MTP:** its own qualification failed one of 30 tool calls
    in MTP mode (an unfinished JSON call). My runs passed 30/30 twice.
  - **If agents' tool calls misbehave, set `SPEC=off`.** That is the fork's
    tool-call-qualified mode: 34.8 tok/s for one request instead of 52.9, but a
    larger KV pool.
- **FP8 KV cache.** It uses calibrated scales, and held-out perplexity sits
  within 0.14% of BF16 KV (see "FP8 KV-cache calibration"). vLLM still logs its
  generic fp8-KV accuracy warning, and the fidelity check had no repeat runs.
- **Radiance's sampler hooks hang `prompt_logprobs` requests.** This covers
  `RADIANCE_VERIFY_HEAD`, `RADIANCE_TOPK_COMPOSITE` and `RADIANCE_DYNAMIC_DRAFT`,
  all on in the image. A request with `prompt_logprobs` stalls a GPU worker
  until vLLM's RPC timeout kills the engine. None of this machine's clients use
  it. For perplexity-style evaluation, set those three to `0`; generation
  output is unaffected.
- **The unit's docker group access.** The systemd user manager fixes its
  groups at login. It started before the user joined `docker`, so `run.sh`
  re-executes itself under `sg docker` when the group is missing. After a
  reboot the group is present and that branch is skipped.
- **An expired `hf` token breaks downloads.** The Hub answers 401, which `hf`
  reports as "Repository Not Found" even for public repos.
  `download-model.sh` retries anonymously. Refresh the token with
  `hf auth login`.

## Benchmarks and validation

```bash
./vllm/bench-openai.py --label my-change          # decode/prefill/mixed/tool calls against :8080
./vllm/stress-context.py --long 3 --ctx 190000    # overfill the KV pool, report peak VRAM and preemptions
```

`bench-openai.py` works against any OpenAI-compatible server (`--base`),
including the llama.cpp router, and appends JSON lines to
`vllm/bench-results.jsonl` (gitignored). Long prompts are cut from fixed offsets
per size, so every server sees the same text; token density across the sources
varies about 2x. A random nonce at the start still defeats prefix caching.
`--parts` runs a subset of `decode,prefill,mixed,tools`. On a cold server, the
first prefill size includes one-off kernel compilation; re-run it before
trusting that number.

## Layout

| Path | Purpose |
| --- | --- |
| `config.env` | All settings; the only file to edit |
| `docker-compose.yml` | The vLLM container: server flags, environment, mounts |
| `run.sh` | Open WebUI + `docker compose up` in the foreground; `ExecStart` of the unit |
| `cicero-vllm.service` | The systemd user unit (conflicts with the llama.cpp stack and TTS) |
| `install.sh` / `install-service.sh` | Pull, download and install the unit; `--enable` makes it the boot default |
| `update.sh` | Re-pull the pinned image (or move the pin), refresh the model, clear stale caches, restart |
| `download-model.sh` | `hf download` into `MODEL_DIR`, with the anonymous retry |
| `start.sh` / `stop.sh` | Switch to vLLM and wait for readiness / stop it |
| `bench-openai.py` | Runtime-agnostic streaming benchmark |
| `stress-context.py` | KV-pool overfill and peak-VRAM check |
| `calibrate-kv.sh` | Build the corpus, run the fork's FP8-KV calibrator, verify the sidecar |
| `build-calibration-corpus.py` | Assemble the private EN/RU/code calibration corpus into `calibration/corpus/` (gitignored) |
| `calibration/` | Calibrated FP8 KV scale sidecars plus manifests (no corpus text) |
| `TUNING-PLAN.md` | The 2026-09-26 community-settings experiments and their results |
| `cache/` | Persistent Triton/Inductor/vLLM compile caches (gitignored, root-owned) |

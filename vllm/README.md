# vLLM: Qwen3.8-27B FP8 on both R9700s

The production stack: **Qwen3.8-27B** on vLLM, plus a small llama.cpp sidecar
for the two models vLLM cannot serve (ASR and Hindsight's reranker). vLLM uses
the same API port and model id as the old router, so chat clients do not change. Measurements and experiment history are in
[`TUNING-PLAN.md`](TUNING-PLAN.md).

## Final configuration

| | |
| --- | --- |
| Runtime | [vllm-radiance](https://github.com/magiccodingman/vllm-radiance) `1.0.387`: vLLM 0.30 with hand-written gfx1201 kernels, including a P2P all-reduce between the cards |
| Model | Official `Qwen/Qwen3.8-27B-FP8` (block FP8, built-in MTP head), text only |
| GPUs | Both R9700s, tensor-parallel 2 |
| Speculative decoding | MTP, up to 3 draft tokens; the fork's controller sets the draft depth per request, per step |
| KV cache | FP8 with calibrated per-layer scales (EN + RU + code corpus) |
| Context | 262,144 tokens per request (the native limit), drawn from a shared pool of 606,299 tokens (10.75 GiB per card; 758,606 / 13.44 GiB without the sidecar) |
| Concurrency | 16 sequences; prefill in 4096-token chunks |
| VRAM | vLLM alone: 30.54 of 31.86 GiB per card, and the same peak under a 4 × 187K-token stress test (1.32 GiB free). With the sidecar: 30.35 / 30.66 GiB on ROCm0 / ROCm1, same peak under that stress test with ASR and rerank traffic running (1.51 / 1.20 GiB free, 0 preemptions) |
| Sidecar | llama.cpp router, [`sidecar.ini`](sidecar.ini): `qwen3-asr` text model on ROCm0; its audio encoder and `qwen3-reranker` on ROCm1 |
| API | `http://cicero.local:8080/v1`, model `qwen3.8-27b`; llama.cpp on `:8081`; audio proxy on `:8079`; Open WebUI on `:3000` |
| Service | `cicero-vllm.service` (Open WebUI + sidecar + vLLM), which conflicts with `cicero-home-ai.service` and `cicero-tts-server.service` |

Performance, measured 2026-09-26 on ROCm 10 with [`bench-openai.py`](bench-openai.py)
at Qwen's recommended sampling:

| | **This config** | llama.cpp (current production: Q6_K, tensor split, MTP 2) |
| --- | ---: | ---: |
| Decode, 1 request | ~65–72 tok/s | ~54 |
| Aggregate decode, 2 / 4 / 8 requests | 119 / 214 / 359 | 68 / 87 / 97 |
| Prefill, ~4K / 15K / 56K tokens | 4,063 / 3,957 / 3,366 tok/s | 804 / 1,002 / 836 |
| Decode while a ~28K-token prompt prefills | 41 tok/s | 17 |
| That prompt's time to first token | 7.6 s | 32.5 s |
| Tool calls well-formed | 30/30 | 15/15 |

**Ports:**
- `:8080` vLLM, `qwen3.8-27b`: Hindsight's LLM, Hermes, mem0 and Open WebUI,
  unchanged.
- `:8081` llama.cpp sidecar: `qwen3-reranker` for Hindsight Recall
  (`HINDSIGHT_API_RERANKER_LITELLM_API_BASE` in
  `~/.config/hindsight/hindsight-qwen3.8-27b.env`) and `qwen3-asr`.
- `:8079` audio proxy (`audio/`): audio only, with transcription going to
  `:8081` and TTS to `:8078`.

**Not available in this mode:** TTS. Its unit is stopped when vLLM starts,
because it would take VRAM from the KV pool.

## Install, switch, update

```bash
./vllm/install.sh            # pull the image (~4 GB), download the model (~29 GB), install the unit
./vllm/start.sh              # switch to vLLM now (stops llama.cpp + TTS), wait until ready
./vllm/stop.sh               # stop it; ./start.sh brings the llama.cpp stack back
./vllm/install.sh --enable   # make cicero-vllm.service the boot default
./vllm/update.sh             # re-pull the pinned image, refresh the model, restart if running
./vllm/update.sh 1.0.400     # move the pin to another radiance tag
./vllm/calibrate-kv.sh       # recalibrate FP8 KV scales (GPUs must be free)
```

- **Startup time:** the first start compiles kernels for ~5 min. Later starts
  reuse `vllm/cache/` and take ~2–3 min. `update.sh` clears the cache whenever
  the image changes.
- **Image pin:** the image stays pinned, and `update.sh` only reports newer
  tags. The fork's torch/Triton/vLLM versions form a set, and unqualified bumps
  have caused TP hangs.
- **Logs:** `logs/vllm.log`.

## Settings ([`config.env`](config.env))

| Setting | Value | Notes |
| --- | --- | --- |
| `IMAGE` | `magiccodingman/vllm-radiance:1.0.387` | pinned fork build |
| `MODEL_REPO` / `MODEL_DIR` | `Qwen/Qwen3.8-27B-FP8` → `models/Qwen3.8-27B-FP8` | also listed in `models/list.txt` |
| `SERVED_MODEL_NAME` / `PORT` | `qwen3.8-27b` / `8080` | drop-in for the router |
| `LLAMA_PRESET` / `LLAMA_PORT` | `vllm/sidecar.ini` / `8081` | llama.cpp sidecar, loaded before vLLM; empty preset = vLLM alone |
| `GPU_UTIL` | `0.85` | startup check only while the KV size is explicit; must fit into what the sidecar leaves free (`0.95` without it) |
| `KV_CACHE_MEMORY_BYTES` | `11542724608` | 10.75 GiB/card (`14428405760` without the sidecar); re-size after changing image, driver, `MTP_TOKENS`, `MAX_NUM_SEQS` or `sidecar.ini` |
| `MAX_MODEL_LEN` | `262144` | per-request ceiling, not a reservation |
| `MAX_NUM_SEQS` | `16` | concurrent requests |
| `SPEC` / `MTP_TOKENS` | `mtp` / `3` | `SPEC=off` disables speculative decoding |
| `FP8_KV_SCALES` | `vllm/calibration/qwen3.8-27b-fp8-kv-enru-20260926.safetensors` | empty = default scales |

The fixed server flags are in [`docker-compose.yml`](docker-compose.yml), each
with a one-line reason:
- FP8 KV cache and R4D attention
- prefix caching with `--mamba-cache-mode align`
- `--language-model-only`
- the `qwen3_coder` / `qwen3` tool and reasoning parsers

## Considered and excluded

Each option was measured on this machine unless marked otherwise. Numbers are
decode tok/s (1 request / aggregate at 8) unless stated.

| Option | Result | Why excluded |
| --- | --- | --- |
| **Runtimes** | | |
| llama.cpp (current production) | 54 / 97; prefill ~900 | 3–4× slower under concurrency and on prefill |
| Upstream vLLM 0.30, stock | 17 / 142 (32 / 191 with MTP 3) | on gfx1201 the all-reduce falls back to RCCL (custom all-reduce is MI300-only) |
| Upstream vLLM 0.30 with the community recipe (tuned GEMM configs, 8192 batch, 32 seqs, explicit KV) | 48 / 260; prefill ~2,100–2,600 | 83–88% of radiance's decode, 50–65% of its prefill. **Mainstream fallback** if the fork breaks |
| radiance without speculative decoding (`SPEC=off`) | 35 / 216 | slower; kept as the fallback if tool calls misbehave |
| **Speculative decoding** | | |
| MTP ceiling 8 (the fork's default) | 58 / 298 | over-drafts: deep drafts on prose/code get rejected but still cost every request compute |
| MTP ceiling 2 or 4 | 66 / 371, 66 / 354 | tied with 3 on throughput; 3 is best under mixed load and on prefill |
| DFlash2 (z-lab drafter, 7 draft tokens) | did not start | the scale sidecar check rejects the drafter checkpoint, and with default scales the drafter hits a `torch.compile` shape error, even with `enforce_eager` |
| **Concurrency** | | |
| `MAX_NUM_SEQS` 32 | 58 / 312 | ~7% slower at 2 requests (three runs); more graph memory |
| `MAX_NUM_SEQS` 8 | 62 / 302 | tied with 16; 16 keeps burst headroom |
| `--max-num-batched-tokens` 8192 | +4% at 4–8 requests | −12% decode while a long prompt prefills |
| `--max-num-batched-tokens` 2048 | +7% mixed-load decode, −3% prefill | MTP 3 at 4096 already gives better mixed-load decode |
| **Memory and context** | | |
| Automatic KV sizing (`GPU_UTIL` only) | 489K-token pool | vLLM reserves ~4 GiB/card for an activation peak that never occurs |
| `MAX_MODEL_LEN` 200000 | — | the pool is shared, so the native 262K costs nothing |
| **KV cache precision** | | |
| BF16 KV cache | reference quality | halves the pool; calibrated FP8 is within 0.14% perplexity |
| FP8 with default scales | +0.19% perplexity (EN), +0.15% (RU) | calibrated scales are better everywhere; 4× on the worst Russian document |
| FP8 with EN-only calibration | +0.34% perplexity (EN) | on Russian text layer 7's V reaches 1.23× the English maximum and gets clipped |
| **Kernels and environment** | | |
| `R4D_ATTN_FP8=3` (FP8 prefill attention) | +11% prefill at 56K | changes attention numerics; ~1.5 s saved per 56K prompt |
| `GPU_MAX_HW_QUEUES=1` | no change (radiance and upstream) | the dispatch penalty it fixes needs pipeline-parallel side streams |
| `NCCL_P2P_DISABLE=1` | — | only needed where P2P fails; it works here and radiance needs it |
| llama.cpp rebuilt on ROCm 10 | prefill up to 13% slower | llama.cpp stays on its ROCm 7.14 build |
| **Not tested** | | |
| GPU power cap 210–250 W | — | needs root (commands in `TUNING-PLAN.md`); community reports say decode is unchanged, prefill ~10–15% slower |
| TunableOp offline GEMM tuning | — | multi-step; the fork expects a "modest, could be zero" gain |
| `iommu=pt`, ASPM, `NCCL_MIN_NCHANNELS` | — | need a reboot, gave no gain on Gen4, or only affect RCCL, which radiance bypasses |

## Operations

**KV pool sizing.**
- The explicit `KV_CACHE_MEMORY_BYTES` replaces vLLM's conservative
  auto-sizing, and `MAX_MODEL_LEN` only caps a single request.
- When the pool is full, new requests queue; they do not fail.
- The sidecar is loaded first, and vLLM takes the same pool on both cards, so
  the fuller card sets the size. `sidecar.ini` keeps the cards level (ASR's
  audio encoder sits on ROCm1 via `mmproj-device`), at ~2.5 GiB each.
- ASR's encoder buffers are allocated on the first transcription. Send one
  request to each sidecar model before reading idle VRAM.
- 10.75 GiB leaves 1.51 / 1.20 GiB free on ROCm0 / ROCm1.
- After any change that affects graph memory (image, driver, `MTP_TOKENS`,
  `MAX_NUM_SEQS`, batch size) or `sidecar.ini`, re-size it:
  1. Start with the current size.
  2. Read idle VRAM (`amd-smi monitor -v`) and adjust to ~1.3 GiB free on the
     fuller card.
  3. Run `./vllm/stress-context.py --long 4 --ctx 190000`.

**FP8 KV calibration.** The scales are a checksummed sidecar bound to the
checkpoint; startup refuses a mismatch. Recalibrate with `./vllm/calibrate-kv.sh`
after changing `MODEL_REPO`, or if the traffic mix changes a lot (a new
language). The corpus is built from local data into `calibration/corpus/`,
which is gitignored.

**Long prompts.** While a very long prompt prefills (in 4096-token chunks),
other requests decode more slowly: ~41 tok/s next to a 28K-token prompt, a few
tok/s next to several 190K-token prompts.

## Caveats

- **Radiance is a one-maintainer, experimental fork.** Its own tests saw 1 bad
  tool call in 30 with MTP; runs here passed every time (30/30 tool calls in
  each MTP run). Fall back to `SPEC=off`, or to upstream vLLM with the
  community recipe.
- **Radiance's sampler hooks hang `prompt_logprobs` requests.** The hooks are
  `RADIANCE_VERIFY_HEAD`, `RADIANCE_TOPK_COMPOSITE` and
  `RADIANCE_DYNAMIC_DRAFT`, all on by default. No client here uses
  `prompt_logprobs`; set the three to `0` for perplexity evaluation.
- **The image's HSA profiler hook makes ROCr spin while idle.** Without
  `HSA_TOOLS_DISABLE_REGISTER=1` each worker keeps two threads at 100% CPU
  (`AsyncEventsLoop`, `InterruptSignal::WaitRelaxed`), which holds the CPU at
  ~78 °C instead of ~33 °C. With it, idle threads stay under 1% and decode is
  unchanged (84–85 tok/s, 1 request). Upstream: vllm-radiance issue #6.
- **FP8 KV fidelity** was measured without repeat runs (no noise floor).
- **Docker group:** the systemd user manager can predate the user joining
  `docker`. `run.sh` then re-executes itself under `sg docker`.
- **An expired `hf` token** makes the Hub report "Repository Not Found".
  `download-model.sh` retries anonymously; refresh the token with
  `hf auth login`.

## Benchmarks and validation

```bash
./vllm/bench-openai.py --label my-change          # decode / prefill / mixed load / tool calls against :8080
./vllm/stress-context.py --long 4 --ctx 190000    # overfill the KV pool; report peak VRAM and preemptions
```

`bench-openai.py` works against any OpenAI-compatible server (`--base`),
including the llama.cpp router. It cuts long prompts at fixed offsets so every
server sees the same text, and `--parts` selects a subset. The first prefill on
a cold server includes kernel compilation.

## Layout

| Path | Purpose |
| --- | --- |
| `config.env` | all settings; the only file to edit |
| `docker-compose.yml` | the vLLM container: server flags, environment, mounts |
| `run.sh` / `cicero-vllm.service` | Open WebUI, the sidecar (waits until loaded), then `docker compose up`, all in the foreground / the systemd user unit |
| `sidecar.ini` | llama.cpp preset for the sidecar: ASR + reranker |
| `install.sh`, `install-service.sh`, `update.sh`, `download-model.sh` | install, unit sync, update, model download |
| `start.sh` / `stop.sh` | switch to vLLM and wait for readiness / stop it |
| `bench-openai.py`, `stress-context.py` | benchmark and KV-pool stress test |
| `calibrate-kv.sh`, `build-calibration-corpus.py`, `calibration/` | FP8 KV calibration tooling and the scale sidecar (the corpus is gitignored) |
| `TUNING-PLAN.md` | experiment log and detailed measurements |
| `sample-config/` | reference setup from another 2× R9700 host |
| `cache/` | compile caches (gitignored, root-owned) |

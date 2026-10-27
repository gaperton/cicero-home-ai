# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Deployment scripts and config for a home LLM server: no build system, no tests. The machine has two AMD Radeon AI PRO R9700 cards (gfx1201, 32 GB each), 121 GB RAM, boots to TTY, and runs one model at a time, Qwen3.8-Flash-Next (stock or uncensored) or Qwen3.8-27B (`RADIANCE_PROFILE` in `rad/config.env` says which), on the **radiance** engine (`codeberg.org/StillDeadcode/radiance`, C++/HIP, `.rad` model containers, Docker image `stilldeadcode/radiance`). radiance is a separate engine from `vllm-radiance` (a patched vLLM image; the removed vLLM stack ran `magiccodingman/vllm-radiance`, a repackaging of `codeberg.org/StillDeadcode/vllm-radiance`). Both come from StillDeadcode and share the `libr4d` gfx1201 kernels; radiance drops vLLM/PyTorch.

The llama.cpp, vLLM, ASR/TTS and reranker stacks were removed on 2026-10-12. Do not reintroduce them, or reference their scripts as if they existed; history is in git and in `hindsight/experiments/`.

## Architecture

- `cicero-rad.service` (systemd user unit) → `rad/run.sh` → Open WebUI on `:3000` plus `docker compose up` of `rad/compose.yaml` (radiance on `:8080`, model id `qwen-local` whichever profile is loaded). `run.sh` exits when either child dies; systemd restarts the whole stack. Both log to `logs/rad.log`.
- The unit runs as the user. `run.sh` and `update.sh` re-exec under `sg docker` when the login session predates the user's `docker` group membership.
- **Model profiles:** `rad/profiles/<name>.env` (`flashnext`, `flashnext-uncensored`, `27b`) holds the model file, its HF repo + pinned revision and the model's own engine flags (`RADIANCE_ARGS`, e.g. Flash-Next's `expert_tiered`/`HOST_POOL_MIB`). `RADIANCE_PROFILE` in `rad/config.env` picks one; `./switch.sh <name>` downloads it if missing, sets it and restarts the stack. Both models fill both cards, so they never run together.
- `rad/config.env` holds the shared settings (image tag, active profile, served id `qwen-local`, dirs, host/port); `rad/compose.yaml` holds the engine flags every profile shares. Paths in `config.env` are relative to the repo root.
- The prefix cache lives in VRAM plus an 8 GiB pinned host-RAM tier (`--prefix-cache-mib`, idle TTL 3600 s); a restart loses it. Upstream removed the SSD tier in 1.5.0 (issue #70). `rad/state/` (gitignored) holds ad-hoc bench files.
- `models/rad/` holds the model files (gitignored; Flash-Next 114 GiB, 27B 28.67 GiB). `rad/fetch-model.sh` downloads only when the file is missing. Upstream replaces `.rad` files under the same name, so each profile pins `RADIANCE_MODEL_REVISION`; taking a new revision means updating it and deleting the file.
- `gpu-power/` — root system unit `cicero-gpu-power.service` caps both cards' PPT0 at 250 W (`GPU_POWER_CAP_W`, 210–300) on every boot; the cap does not survive a reboot otherwise. `sudo gpu-power/install.sh` installs a root-owned copy of `set-power-cap.sh`; re-run it after editing either file.
- `hindsight/` — the Hindsight memory server's docs, updater, Control Plane unit and end-to-end benchmark. Hindsight sends all LLM calls to `:8080`; its reranker runs on `seneca.local` because radiance leaves no VRAM. `hindsight/experiments/` is history.

**Script flow:**
- `install.sh` (sudo): apt (Docker, pipx) → `amd-smi` check → `gpu-power/install.sh` → `docker` group → `hf` CLI + Open WebUI (Python 3.11 via uv) → linger → `rad/install-service.sh`
- `update.sh [tag]`: optionally re-pin the tag in `config.env` → `docker pull` → active profile's model download if missing → `rad/install-service.sh` → restart
- `switch.sh [profile]`: no argument lists profiles; otherwise `rad/fetch-model.sh` → set `RADIANCE_PROFILE` → restart
- `rad/install-service.sh`: disables and deletes the legacy units (`cicero-home-ai`, `cicero-vllm`, `cicero-tts-server`, `cicero-asr-proxy`, `cicero-vulkan*`), installs `cicero-rad.service` with paths rewritten to the repo location, enables it.

## Engine facts (radiance 1.13.0)

Measured on the `flashnext` profile unless noted; `flashnext-uncensored` has the same size, placement and flags. The `27b` profile was started and quick-benchmarked on 1.2.3 only (15 GiB weights + 13.95 GiB KV per card, 3.2 full-length sessions; decode 85/234 tok/s at 1/4 streams, prefill 2.8K tok/s).

- **Host:** since 1.4.0 the image is built on ROCm 10.1, so the host's amdgpu driver must support it (31.50 or 31.60; 31.60 installed 2026-10-12, runs 1.13.0). Resizable BAR must be on (both cards expose 32 GiB). Both cards sit behind PCIe 16 GT/s x8 slots, which bounds expert streaming and prefill. Each startup ends with a `FINDINGS` report in `logs/rad.log`; a GPU memory fault exits the server (status 70) and systemd restarts it.
- **Memory:** both cards end up ~99% full: ~3.6 GiB static weights, ~17.7 GiB experts, ~8.2 GiB KV per card (4.0 full-length sessions); since 1.3.0 the token embedding sits in pinned RAM (`--embedding-placement ram`, the default). Experts that do not fit stream from a pinned host pool (`HOST_POOL_MIB`, 12 GiB per card); the 47.7 GiB n-gram table is placed in pinned RAM. ~85 GB RAM in use while serving. Raising the host pool frees VRAM for the KV cache. Nothing else GPU-bound can run alongside it.
- **Where things landed is in the log:** read the `placement:`, `VRAM budget` and `kv:` lines of the latest startup in `logs/rad.log` before claiming anything about placement, memory or KV capacity.
- **CLI syntax:** `--flag value` only; `--flag=value` fails as an unknown option. `--gpu-headroom-mib` must be ≥ ~226 (upstream's 96 warns).
- **Optional flags not set here:** `--control-vector off|on` (1.11.0) loads upstream's bundled Flash-Next refusal-direction vector, toggled per request with `"control_vector": true|false`; it is redundant on `flashnext-uncensored`. `--attn-prefill-fp8` (1.11.0) has kernels only for the 27B's attention and refuses to start on Flash-Next. `--draft-coupling on` (1.12.0) helps Flash-Next's MTP at high temperature and costs at low. `--weight-prefetch` (1.13.0) is on by default.
- **API fields:** since 1.12.0 `DELETE /sessions/<label>` forgets one stored conversation. Since 1.4.0 an unknown request field is ignored without an error or a log line (1.2.3 refused it with HTTP 400), and an OpenAI `reasoning` object is accepted. `reasoning_effort` accepts `none`, `minimal`, `low`, `medium`, `xhigh`; `high`/`max` are still refused with HTTP 400.
- **Model id:** chat and completion requests are served for any `model`; `GET /v1/models/<id>` 404s for anything but `qwen-local`. `/v1/models` reports `max_model_len` and `root`, the loaded `.rad` file, so a live client can tell the profiles apart. Every profile is served under that id, so `llm_requests` rows, Open WebUI chats and bench results do not say which model answered: attribute them by timestamp against the dated `rad: … profile <name>` start lines in `logs/rad.log`.
- **Endpoints:** `/v1/chat/completions`, `/v1/completions`, image and video input; since 1.3.0 also `/v1/responses`, Anthropic `/v1/messages`, llama-server's `/completion`, `/infill` and `/props`, and logprobs. `/v1/embeddings` serves embedding models only, so neither profile has it.
- **Baseline** (`rad/bench-openai.py`): full run on 1.2.3 (2026-10-07, driver 31.50): decode 121 tok/s single stream, 212/316/448 aggregate at 2/4/8; prefill 3.6–4.2K tok/s; 15/15 tool calls. Quick run on 1.4.0 (2026-10-12, driver 31.60, `--conc 1,4 --reps 4 --prefill 16384`): 143/308 aggregate at 1/4, prefill 4.6K tok/s, 15/15 tool calls; the same quick run on 1.2.3 with driver 31.60 gave 4-stream 291–295, so 1.4.0 is +5% there and +14% on prefill. Prefill prompts come from Python's stdlib source, so numbers taken before 2026-10-12 used different text. Full run on 1.13.0 (2026-10-27, `flashnext-uncensored`): 122/215/310/474 aggregate at 1/2/4/8, prefill 4.1–4.6K tok/s, mixed 25K prefill 6.6 s with the decode stream at 62 tok/s, 15/15 tool calls; the quick run gave 155/324 and 4.66K (1.10.0: 139/327, 4.42K). With `--reps 3` the `reason` prompt is never run, so the full run's 1-stream median is lower than the quick run's; compare like with like.

## Key conventions

- **Pin the image tag**; never `latest`. Releases land several times a day. Change it only through `./update.sh <tag>`, then re-run `rad/bench-openai.py` and compare with the baseline.
- **Stop other clients before benchmarking.** Open WebUI and Hindsight share `:8080`; check `hindsight.service` and in-flight requests in `logs/rad.log` first.
- Keep config comments to one or two lines of fact; rationale belongs in `README.md` or `hindsight/experiments/`.
- Deployment glue goes in `rad/`; do not keep files inside a cloned upstream tree.
- **Validate any Hindsight LLM change against a large bank, with enough repetitions.** Run `hindsight/benchmark/bench-hindsight.py` (disposable banks) and a read-only pass over the 1749-memory `psychology` bank. Small banks keep generations short and hide runaway-generation failures — `gemma4-26b-a4b-qat` passed every disposable-bank workflow and still hung Reflect on `psychology`. That failure hit ~8% of Reflects, so a 6-probe suite came back green about half the time. See `hindsight/experiments/gemma4.md`.
- **Hindsight's `llm_requests` table is the ground truth for workload shape** (`psql --dbname hindsight`: per-call `operation`, `input_tokens`, `cached_tokens`, `output_tokens`, `duration_ms`, full prompt). Query it before assuming request sizes. On the `psychology` bank: Retain ~2.4k prompt / ~600 generated, Consolidation ~5.5k / ~255 (77% of calls), Reflect 14k p50 / 38k max (7%); decode dominates. See `hindsight/benchmark/README.md`.

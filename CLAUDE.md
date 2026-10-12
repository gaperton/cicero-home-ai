# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Deployment scripts and config for a home LLM server: no build system, no tests. The machine has two AMD Radeon AI PRO R9700 cards (gfx1201, 32 GB each), 121 GB RAM, boots to TTY, and runs one model, Qwen3.8-Flash-Next, on the **radiance** engine (`codeberg.org/StillDeadcode/radiance`, C++/HIP, `.rad` model containers, Docker image `stilldeadcode/radiance`). radiance is unrelated to `vllm-radiance`, which the removed vLLM stack used.

The llama.cpp, vLLM, ASR/TTS and reranker stacks were removed on 2026-10-12. Do not reintroduce them, or reference their scripts as if they existed; history is in git and in `hindsight/experiments/`.

## Architecture

- `cicero-rad.service` (systemd user unit) → `rad/run.sh` → Open WebUI on `:3000` plus `docker compose up` of `rad/compose.yaml` (radiance on `:8080`, model id `qwen3.8-flash-next`). `run.sh` exits when either child dies; systemd restarts the whole stack. Both log to `logs/rad.log`.
- The unit runs as the user. `run.sh` and `update.sh` re-exec under `sg docker` when the login session predates the user's `docker` group membership.
- `rad/config.env` holds every setting (image tag, model file + HF repo, served id, port, `HOST_POOL_MIB`); `rad/compose.yaml` holds engine flags. Paths in `config.env` are relative to the repo root.
- `rad/state/kvcache/` is the prefix cache's disk tier (gitignored, unencrypted conversation KV). The engine does not create the directory; `run.sh` does, and without it the tier is silently off.
- `models/rad/` holds the 114 GiB model (gitignored). `update.sh` downloads it only when missing; the filename is versioned, so an existing file is never re-fetched.
- `gpu-power/` — root system unit `cicero-gpu-power.service` caps both cards' PPT0 at 250 W (`GPU_POWER_CAP_W`, 210–300) on every boot; the cap does not survive a reboot otherwise. `sudo gpu-power/install.sh` installs a root-owned copy of `set-power-cap.sh`; re-run it after editing either file.
- `hindsight/` — the Hindsight memory server's docs, updater, Control Plane unit and end-to-end benchmark. Hindsight sends all LLM calls to `:8080`; its reranker runs on `seneca.local` because radiance leaves no VRAM. `hindsight/experiments/` is history.

**Script flow:**
- `install.sh` (sudo): apt (Docker, pipx) → `amd-smi` check → `gpu-power/install.sh` → `docker` group → `hf` CLI + Open WebUI (Python 3.11 via uv) → linger → `rad/install-service.sh`
- `update.sh [tag]`: optionally re-pin the tag in `config.env` → `docker pull` → model download if missing → `rad/install-service.sh` → restart
- `rad/install-service.sh`: disables and deletes the legacy units (`cicero-home-ai`, `cicero-vllm`, `cicero-tts-server`, `cicero-asr-proxy`, `cicero-vulkan*`), installs `cicero-rad.service` with paths rewritten to the repo location, enables it.

## Engine facts (radiance 1.2.3)

- **Memory:** both cards end up ~99% full: ~4.2 GiB static weights, ~17.7 GiB experts, ~7.6 GiB KV per card. Experts that do not fit stream from a pinned host pool (`HOST_POOL_MIB`, 12 GiB per card); the 47.7 GiB n-gram table is placed in pinned RAM. ~85 GB RAM in use while serving. Raising the host pool frees VRAM for the KV cache. Nothing else GPU-bound can run alongside it.
- **Where things landed is in the log:** read the `placement:`, `VRAM budget` and `kv:` lines of the latest startup in `logs/rad.log` before claiming anything about placement, memory or KV capacity.
- **CLI syntax:** `--flag value` only; `--flag=value` fails as an unknown option. `--gpu-headroom-mib` must be ≥ ~226 (upstream's 96 warns).
- **Strict API:** an unimplemented request field returns HTTP 400 instead of being ignored. Clients sending an OpenAI `reasoning` object fail this way. `reasoning_effort` accepts `none`, `minimal`, `low`, `medium`, `xhigh`; `high`/`max` are refused.
- **Model id:** chat and completion requests are served for any `model`; `GET /v1/models/<id>` 404s for anything but `qwen3.8-flash-next`.
- **Endpoints:** `/v1/chat/completions`, `/v1/completions`, image and video input. No `/v1/responses`, `/v1/messages`, or `/v1/embeddings`.
- **Baseline** (`rad/bench-openai.py`, 1.2.3): decode 121 tok/s single stream, 212/316/448 aggregate at 2/4/8; prefill 3.6–4.2K tok/s; 15/15 tool calls. Prefill prompts come from Python's stdlib source, so numbers taken before 2026-10-12 used different text.

## Key conventions

- **Pin the image tag**; never `latest`. Releases land several times a day. Change it only through `./update.sh <tag>`, then re-run `rad/bench-openai.py` and compare with the baseline.
- **Stop other clients before benchmarking.** Open WebUI and Hindsight share `:8080`; check `hindsight.service` and in-flight requests in `logs/rad.log` first.
- Keep config comments to one or two lines of fact; rationale belongs in `README.md` or `hindsight/experiments/`.
- Deployment glue goes in `rad/`; do not keep files inside a cloned upstream tree.
- **Validate any Hindsight LLM change against a large bank, with enough repetitions.** Run `hindsight/benchmark/bench-hindsight.py` (disposable banks) and a read-only pass over the 1749-memory `psychology` bank. Small banks keep generations short and hide runaway-generation failures — `gemma4-26b-a4b-qat` passed every disposable-bank workflow and still hung Reflect on `psychology`. That failure hit ~8% of Reflects, so a 6-probe suite came back green about half the time. See `hindsight/experiments/gemma4.md`.
- **Hindsight's `llm_requests` table is the ground truth for workload shape** (`psql --dbname hindsight`: per-call `operation`, `input_tokens`, `cached_tokens`, `output_tokens`, `duration_ms`, full prompt). Query it before assuming request sizes. On the `psychology` bank: Retain ~2.4k prompt / ~600 generated, Consolidation ~5.5k / ~255 (77% of calls), Reflect 14k p50 / 38k max (7%); decode dominates. See `hindsight/benchmark/README.md`.

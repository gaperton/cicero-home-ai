# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A home AI server setup — not a software project with a build system or tests. It is a collection of shell scripts and config files that manage a local LLM server on a dedicated machine (two AMD R9700 GPUs, 32GB VRAM each, TTY mode, Vulkan).

## Architecture

Two `llama-server` instances, built from a single Vulkan `llama.cpp/` checkout at the repo root, each pinned to one GPU (`--device Vulkan0` / `Vulkan1`, no layer-split — per-GPU throughput beats `split-mode=layer` across both cards). Instance A listens on port 8080 (GPU0), instance B on port 8081 (GPU1). `run.sh` starts Open WebUI, then launches both `llama-server` processes directly.

**llama-server** runs in **router mode** — a built-in multi-model proxy, one router per GPU. Each instance loads only one model in VRAM at a time (`--models-max 1`, LRU eviction), so up to two different models can be resident simultaneously, one per GPU.

**Layout:**
- `.env` — Vulkan cmake flags and `SERVER_FLAGS`
- `models-0.ini` / `models-1.ini` — independent router presets for Vulkan0:8080 and Vulkan1:8081 (no split-mode)
- `llama.cpp/` — cloned separately (gitignored), built binaries live here alongside source; the same build/binaries are reused by `benchmark/` (no separate checkout)
- `benchmark/` — `bench.sh` / `bench-mtp.sh` run ad hoc comparisons against the shared `../llama.cpp/` build, not a standalone checkout

**Script flow:**
- `run-tmux.sh` → `run.sh` → Open WebUI + two `llama-server` instances, using `models-0.ini` on Vulkan0:8080 and `models-1.ini` on Vulkan1:8081; Open WebUI is configured only for the Vulkan0:8080 router, while Vulkan1:8081 is reserved for Hindsight and direct API clients
- `update.sh` → stop service → `build.sh` (git pull + rebuild) → download models → start service

## Key conventions

- `llama.cpp` is **not a git submodule** — it is cloned by `install.sh` into `llama.cpp/`, and updated by `build.sh` (`git pull`), always tracking latest.
- Sampling params live in each `models-*.ini` file's per-model sections; global server flags in its `[*]` section.
- Always set `repeat-penalty = 1.0` (or `--repeat-penalty 1.0`) in any model preset to explicitly disable it.
- Agent-facing model presets (used by Claude Code, Cursor, etc.) should **not** include sampling params — agents send their own and override server defaults anyway.
- Models are sized for TTY mode (no desktop). Max context fits in 32GB VRAM per GPU only without a running desktop session.
- Model presets in each `models-*.ini` file must fit a single 32GB card — no `split-mode=layer`, since each instance only sees one GPU.
- `models-1.ini` is the MoE-only secondary router and uses `parallel = 2`; MTP stays disabled there unless end-to-end benchmarks prove it is not slower for the prompt-heavy workload.

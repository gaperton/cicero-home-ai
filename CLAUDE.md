# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A home AI server setup — not a software project with a build system or tests. It is a collection of shell scripts and config files that manage a local LLM server on a dedicated machine (two AMD R9700 GPUs, 32GB VRAM each, TTY mode, Vulkan).

## Architecture

Two `llama-server` instances, built from a single Vulkan `llama.cpp/` checkout at the repo root, each pinned to one GPU (`--device Vulkan0` / `Vulkan1`, no layer-split — per-GPU throughput beats `split-mode=layer` across both cards). Instance A listens on port 8080 (GPU0), instance B on port 8081 (GPU1). `run.sh` starts Open WebUI, then launches both `llama-server` processes directly.

**llama-server** runs in **router mode** — a built-in multi-model proxy, one router per GPU. Each instance loads only one model in VRAM at a time (`--models-max 1`, LRU eviction), so up to two different models can be resident simultaneously, one per GPU.

**Layout:**
- `.env` — Vulkan cmake flags and `SERVER_FLAGS`
- `models.ini` — shared router preset for both instances (no split-mode; `--device` on the CLI pins each instance to its GPU)
- `llama.cpp/` — cloned separately (gitignored), built binaries live here alongside source; the same build/binaries are reused by `benchmark/` (no separate checkout)
- `benchmark/` — `bench.sh` / `bench-mtp.sh` run ad hoc comparisons against the shared `../llama.cpp/` build, not a standalone checkout

**Script flow:**
- `run-tmux.sh` → `run.sh` → Open WebUI + two `llama-server --models-preset models.ini` instances (one per `--device`/port)
- `update.sh` → stop service → `build.sh` (git pull + rebuild) → download models → start service

## Key conventions

- `llama.cpp` is **not a git submodule** — it is cloned by `install.sh` into `llama.cpp/`, and updated by `build.sh` (`git pull`), always tracking latest.
- Sampling params live in `models.ini` per-model sections; global server flags in the `[*]` section.
- Always set `repeat-penalty = 1.0` (or `--repeat-penalty 1.0`) in any model preset to explicitly disable it.
- Agent-facing model presets (used by Claude Code, Cursor, etc.) should **not** include sampling params — agents send their own and override server defaults anyway.
- Models are sized for TTY mode (no desktop). Max context fits in 32GB VRAM per GPU only without a running desktop session.
- Model presets in `models.ini` must fit a single 32GB card — no `split-mode=layer`, since each instance only sees one GPU.

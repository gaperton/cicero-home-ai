# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A home AI server setup — not a software project with a build system or tests. It is a collection of shell scripts and config files that manage a local LLM server on a dedicated machine (AMD R9700, 32GB VRAM, TTY mode).

## Architecture

**llama-server** runs in **router mode** — a built-in multi-model proxy on port 8080. Only one model is loaded in VRAM at a time (`--models-max 1`, LRU eviction).

**Config files:**
- `.env` — `CMAKE_GPU_FLAG` for the llama.cpp build (Vulkan/CUDA/ROCm)
- `models.ini` — router preset file: per-model settings and global server flags
- `llama.cpp/` — cloned separately (gitignored), built binaries live here alongside source

**Script flow:**
- `run-tmux.sh` → `run.sh` → `update.sh` (pull + rebuild llama.cpp, download models) → `llama-server --models-preset models.ini`

## Key conventions

- `llama.cpp` is **not a git submodule** — it is cloned by `install.sh` and updated by `update.sh` (`git pull`), always tracking latest.
- Sampling params live in `models.ini` per-model sections; global server flags in the `[*]` section.
- Always set `repeat-penalty = 1.0` (or `--repeat-penalty 1.0`) in any model preset to explicitly disable it.
- Agent-facing model presets (used by Claude Code, Cursor, etc.) should **not** include sampling params — agents send their own and override server defaults anyway.
- Models are sized for TTY mode (no desktop). Max context fits in 32GB VRAM only without a running desktop session.
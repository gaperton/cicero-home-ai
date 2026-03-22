# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A home AI server setup — not a software project with a build system or tests. It is a collection of shell scripts and config files that manage a local LLM server on a dedicated machine (AMD R9700, 32GB VRAM, TTY mode).

## Architecture

**llama-swap** proxies requests on port 8080 to `llama-server` (from llama.cpp). Only one model is loaded in VRAM at a time — llama-swap swaps instances on demand based on the model name in the request.

**Config files:**
- `.env` — `CMAKE_GPU_FLAG` for the llama.cpp build (Vulkan/CUDA/ROCm)
- `config.yaml` — llama-swap config: model presets, macros for server flags and sampling params
- `llama.cpp/` — cloned separately (gitignored), built binaries live here alongside source

**Script flow:**
- `run-tmux.sh` → `run.sh` → `update.sh` (pull + rebuild llama.cpp, download models) → `llama-swap --config config.yaml`

## Key conventions

- `llama.cpp` is **not a git submodule** — it is cloned by `install.sh` and updated by `update.sh` (`git pull`), always tracking latest.
- Sampling params live in `config.yaml` macros (`qwen-chat`, `glm-chat`), not in a separate presets file.
- Always set `repeat-penalty = 1.0` (or `--repeat-penalty 1.0`) in any model preset to explicitly disable it.
- Agent-facing model presets (used by Claude Code, Cursor, etc.) should **not** include sampling params — agents send their own and override server defaults anyway.
- Models are sized for TTY mode (no desktop). Max context fits in 32GB VRAM only without a running desktop session.
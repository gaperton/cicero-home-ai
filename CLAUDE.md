# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A home AI server setup — not a software project with a build system or tests. It is a collection of shell scripts and config files that manage a local LLM server on a dedicated machine (AMD R9700, 32GB VRAM, TTY mode).

## Architecture

Each GPU backend is fully self-contained in its own top-level folder — `rocm/` and `vulkan/`. Each owns its `llama.cpp/` checkout+build, its model preset(s), its own `run.sh` (launches `llama-server`) and `build.sh` (pulls + rebuilds), and its own `.env` (cmake flags + extra server flags). The top-level `run.sh` only handles what's shared across backends: MCP proxy and Open WebUI, then hands off to `rocm/run.sh` or `vulkan/run.sh`.

**llama-server** runs in **router mode** — a built-in multi-model proxy on port 8080 (plus 8081 for the Vulkan backend's second GPU instance). Only one model is loaded in VRAM at a time per instance (`--models-max 1`, LRU eviction).

**Layout:**
- `.env` — `SERVER_FLAGS_COMMON`, shared by every `llama-server` instance regardless of backend
- `rocm/.env`, `vulkan/.env` — backend-specific cmake flags and `SERVER_FLAGS_EXTRA`
- `rocm/models.ini` — router preset for ROCm (single instance, split-mode=layer across both GPUs, port 8080)
- `vulkan/models-0.ini`, `vulkan/models-1.ini` — router presets for Vulkan (one instance per GPU, ports 8080/8081)
- `mcp-config.json` — MCP server definitions (gitignored, contains API keys); used by `mcp-proxy`
- `webui-config.json` — pre-configures MCP server URLs in the llama.cpp web UI
- `rocm/llama.cpp/`, `vulkan/llama.cpp/` — cloned separately (gitignored), built binaries live here alongside source

**Script flow:**
- `run-tmux.sh` → `run.sh [rocm|vulkan]` → `mcp-proxy` (MCP servers on :8200) + Open WebUI + `<backend>/run.sh` → `llama-server --models-preset <backend's ini>`
- `update.sh [rocm|vulkan]` → stop service → `<backend>/build.sh` (git pull + rebuild) → download models → start service

## Key conventions

- `llama.cpp` is **not a git submodule** — it is cloned by `install.sh` into `rocm/llama.cpp` and `vulkan/llama.cpp`, and updated by `<backend>/build.sh` (`git pull`), always tracking latest.
- Sampling params live in each backend's `models*.ini` per-model sections; global server flags in the `[*]` section.
- Always set `repeat-penalty = 1.0` (or `--repeat-penalty 1.0`) in any model preset to explicitly disable it.
- Agent-facing model presets (used by Claude Code, Cursor, etc.) should **not** include sampling params — agents send their own and override server defaults anyway.
- Models are sized for TTY mode (no desktop). Max context fits in 32GB VRAM only without a running desktop session.
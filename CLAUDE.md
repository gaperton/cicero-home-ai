# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A home AI server setup — not a software project with a build system or tests. It is a collection of shell scripts and config files that manage a local LLM server on a dedicated machine (two AMD R9700 GPUs, gfx1201, 32GB VRAM each, TTY mode, ROCm/HIP).

## Architecture

One `llama-server` instance in **combined topology**: a single router owns both cards and serves port 8081, with all three models resident. `qwen3.8-27b` and `llm` are tensor-split across both cards; `reranker` stays on ROCm0. Open WebUI listens on port 3000 and points at that router.

There is one GPU folder and one user unit: `gpu-0-1/cicero-home-ai.service` runs `gpu-0-1/run.sh`, which supervises both the router and Open WebUI. Both processes log to `logs/gpu-0-1.log`; exiting either one causes systemd to restart the complete stack. `install.sh` disables and removes the superseded `cicero-vulkan{0,1}.service` units during migration.

**Device placement lives in the preset, never on the router's command line.** `gpu-0-1/run.sh` deliberately passes no `--device`: the router merges its own CLI args over every preset section and that merge *overwrites* (`tools/server/server-models.cpp`, `preset.merge(base_preset)`), so a `--device` there would drag all three children onto one card. Every section in `gpu-0-1/combined.ini` therefore carries its own `device =`; a section without one is handed both GPUs and silently layer-splits.

**Layout:**
- `.env` — ROCm/HIP cmake flags, the HIP toolchain env (`ROCM_PATH`/`HIP_PATH`/`HIPCXX`) and `SERVER_FLAGS`
- `gpu-0-1/` — the combined preset, its `active.ini` symlink, the single `run.sh`, and the single `cicero-home-ai.service` unit. `install-service.sh` synchronizes that unit and removes the legacy split units. `./switch gpu-0-1 combined` repoints `active.ini` and restarts the stack. Relative `model =` paths inside a preset resolve against the repo root because `run.sh` changes there first.
- `llama.cpp/` — cloned separately (gitignored), built binaries live here alongside source; the same build/binaries are reused by `benchmark/` (no separate checkout)
- `benchmark/` — `bench.sh` / `bench-mtp.sh` run ad hoc comparisons against the shared `../llama.cpp/` build, not a standalone checkout. `bench-mtp.sh` drives the Hindsight workload via `hindsight-load.py` with embedded per-model flags; read the `mix, per 100 calls` row, not `tg t/s`. Its profiles are derived from Hindsight's own `llm_requests` table (see below), not from HINDSIGHT.md's four hand-timed `hermes` calls. `bench-hindsight.py` measures the real Hindsight service instead.

**Script flow:**
- `gpu-0-1/run.sh` — starts Open WebUI on :3000 and the router on :8081, reading `gpu-0-1/active.ini` with `--models-max 3`. Open WebUI and Hindsight share the router, so the WebUI model list includes `llm` and `reranker`.
- `update.sh` → sync/migrate service unit → stop service → `build.sh` (git pull + rebuild) → download models → start service

## Key conventions

- `llama.cpp` is **not a git submodule** — it is cloned by `install.sh` into `llama.cpp/`, and updated by `build.sh` (`git pull`), always tracking latest.
- **Local llama.cpp fixes live in `patches/<topic>/llama-cpp.patch`, never as bare edits in `llama.cpp/`.** One folder per upstream change, each with a `README.md` carrying its rationale and evidence, so a patch and its justification cannot drift apart. `build.sh` discards local changes in that tree so the pull can fast-forward, then re-applies every patch; an edit that is not captured as a patch is silently lost on the next build. A patch that no longer applies is a **hard build failure** by design — either it landed upstream (delete it) or it needs rebasing, and building without it would quietly ship a binary missing the fix. `./build.sh --patch-only` re-applies patches without pulling or rebuilding. Capture new work with `mkdir patches/<topic> && git -C llama.cpp diff > patches/<topic>/llama-cpp.patch`, then write `patches/<topic>/README.md`.
- Sampling params live in each preset file's per-model sections; global server flags in its `[*]` section.
- Always set `repeat-penalty = 1.0` (or `--repeat-penalty 1.0`) in any model preset to explicitly disable it.
- Agent-facing model presets (used by Claude Code, Cursor, etc.) should **not** include sampling params — agents send their own and override server defaults anyway.
- Models are sized for TTY mode (no desktop). Max context fits in 32GB VRAM per GPU only without a running desktop session.
- The combined preset uses explicit tensor splits across both 32GB cards. `fit = off` is required because automatic fitting does not support tensor split.
- `[llm]` uses `chat-template-file = templates/gpt-oss-20b-harmony.jinja` (gpt-oss's own template plus one added tool-channel instruction). Without it gpt-oss emits a malformed channel header on Reflect's later turns and llama.cpp returns HTTP 500. Re-extract and re-apply it after any gpt-oss model update. See HINDSIGHT.md.
- `[llm]` runs 262144 total over 2 slots = 131072 per slot with a 38/62 tensor split. `[qwen3.8-27b]` runs 393216 total over 2 slots = 196608 per slot in tensor mode. `[reranker]` is deliberately unsplit on ROCm0 because tensor mode crashes on its first request.
- **The reranker's `parallel` is a latency lever, and more is worse.** llama.cpp posts one task per document and fans them across free slots (`tools/server/server-context.cpp`, the loop before `rd.post_tasks`), so slots do parallelise a single rerank — they just don't pay off. Measured on 100 documents, idle card: at ~200 tokens/doc, 1 slot takes 6.97s against 12.61s at 4, 13.06s at 8 and 17.00s at 32; at ~800 tokens/doc it is flat (~28.7s) because token count alone saturates the card. VRAM is unaffected (6.99 GB at 4 slots vs 6.93 at 8) since `kv-unified` shares one KV buffer rather than slicing it per slot. Hindsight caps concurrent Recalls at 32 (`memory_engine.py`, `asyncio.Semaphore(recall_max_concurrent)`, default not overridden) and its litellm reranker path has no semaphore of its own, so the queue is always deeper than the slot count.
- `ctx-size` in a preset is a **total** that llama.cpp divides across `parallel` slots. Always state the per-slot figure when changing either, especially for the reranker, where the per-slot value is the hard ceiling on one query+document pair and an overflow fails the whole rerank request. See HINDSIGHT.md.
- Keep `MAX=3` in `gpu-0-1/run.sh` so `[qwen3.8-27b]`, `[llm]`, and `[reranker]` can all carry `load-on-startup = true` and remain resident. MTP stays enabled only for Qwen; the Hindsight LLM has no MTP head.
- **Validate any Hindsight LLM swap against a large bank, with enough repetitions.** `benchmark/e2e-psychology.py` runs both: a disposable-bank workflow and a read-only pass over the 1749-memory `psychology` bank. Small banks keep generations short and hide runaway-generation failures entirely — `gemma4-26b-a4b-qat` passed every disposable-bank workflow and still hung Reflect indefinitely on `psychology`, wedging llama.cpp slots that stay occupied after the client times out. Repetitions matter as much as bank size: that failure was stochastic at ~8% per Reflect, so a 6-probe suite came back green about half the time regardless — `benchmark/gemma-fix-validation.py` runs 40. Both defects were eventually fixed (llama.cpp patch + `reasoning-budget`); see HINDSIGHT.md, "Gemma 4: rejection, root cause, and fix", and `notes/hindsight-gemma.md`.
- **Hindsight's `llm_requests` table is the ground truth for workload shape** — `psql --dbname hindsight` gives per-call `operation`, `input_tokens`, `cached_tokens`, `output_tokens`, `duration_ms` and the full prompt. Query it before assuming request sizes. It contradicts HINDSIGHT.md's "prefill dominates" section, which generalised from four hand-timed `hermes` calls: over 480 recorded `psychology`-bank calls, Retain is ~2.4k prompt / ~600 generated, Consolidation ~5.5k / ~255 (77% of all calls), and only Reflect is large (14k p50, 38k max, 7% of calls). Decode outweighs uncached prefill roughly 3:1 across the mix, and 44-64% of Retain/Consolidation input tokens are served from the slot prefix cache — that cached part is the system prompt.

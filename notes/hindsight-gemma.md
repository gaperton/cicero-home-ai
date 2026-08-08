# Running Hindsight against local Gemma 4

How to point Hindsight at `gemma4-26b-a4b-qat` on the Vulkan1 router, and what
has to be in place for it to work.

Status: validated 2026-08-08 on the 1749-memory `psychology` bank — 40/40
Reflects with zero hangs, e2e 3/3 on every probe, Retain and Consolidation clean.

**gpt-oss is still the default profile**, purely on speed (Reflect 22–30 s vs
68–83 s). Use Gemma when you want Gemma; nothing is broken about it now.

---

## TL;DR

```bash
./switch-hindsight-model.sh gemma      # flips preset + env, restarts both services
./switch-hindsight-model.sh status     # confirm
./switch-hindsight-model.sh oss        # back to the fast profile
```

That is the whole operation, *provided* the two mitigations below are present.
They already are. This document exists so that if Reflect ever starts hanging
again, you know which two things to check first.

---

## The two things that must be in place

Gemma's Reflect does not terminate without both. Each was measured
independently; neither is optional.

### 1. `patches/llamacpp-gemma4-required-toolcall.patch`

Applied to `llama.cpp/common/chat.cpp`, re-applied automatically by `build.sh`.

When `tool_choice` is `required`, the gemma4 grammar allowed unbounded free
content before the mandatory tool call, while EOS stayed outside the allowed
token set until that call appeared — an infinite legal derivation. The patch
removes the free-content path, mirroring what `common_chat_params_init_gpt_oss`
already does for the same case.

Check it is live:

```bash
./build.sh --patch-only          # "already applied, skipping" is the good answer
git -C llama.cpp diff --stat common/chat.cpp
```

If `build.sh` ever reports the patch no longer applies, that is a **hard build
failure by design** — either it landed upstream (delete it) or upstream moved and
it needs rebasing. Do not build without it.

### 2. `reasoning-budget = 1024` in `models-1-gemma.ini`

The patch left a second unbounded rule: the thought block,
`p.reasoning(p.until("<channel|>"))`. A model that opens a thought and never
closes it hangs identically, and because the output goes to `reasoning_content`
the client sees **silence**, not a runaway — which is what made this hard to find.

`reasoning-budget` caps thinking at the sampler and forces the closing tag, after
which the grammar requires the tool call. Measured on 120 replays of a captured
production request, single variable:

| | Hangs |
| --- | --- |
| no budget | 5/120 |
| `reasoning-budget = 1024` | **0/120** |

Thinking still happens — 9/120 completions used it, 1131–4993 characters. 1024 is
the measured value; genuine thinking on these turns runs ~600–1100 tokens, so it
fits. **Raising it leaves more room to degenerate before the cut** — re-run the
replay harness before increasing it.

### Backstop (not a fix): `n-predict = 4096`

On both profiles. Converts any future runaway into a bounded ~21 s response
instead of a slot held to the 300 s client timeout. In the 40-Reflect validation
**zero calls came near it**, which is the evidence that `reasoning-budget` is
containing the problem rather than the cap masking it. Keep it; if it ever starts
firing, something regressed.

---

## How the profile switch works

Two things must agree or the router thrashes on every call:

| | points at |
| --- | --- |
| `models-1.ini` | `models-1-oss.ini` or `models-1-gemma.ini` (symlink) |
| `~/.config/hindsight/hindsight.env` | `hindsight-gpt-oss.env` or `hindsight-gemma.env` (symlink) |

`switch-hindsight-model.sh` flips both, restarts `cicero-home-ai` then
`hindsight`, waits for the model to actually report `loaded`, and prints the
resulting state. Do not edit `models-1.ini` or `hindsight.env` directly — they
are symlinks.

Both presets expose their model under the router id **`llm`** (and the reranker
under `reranker`), so `HINDSIGHT_API_LLM_MODEL=llm` never changes between
profiles. Only which underlying model answers `llm` changes.

One consequence: `llm_requests.model` now records `llm` for both profiles, so
historical rows can only be attributed to a model **by timestamp**, not by name.

---

## Gemma-specific settings, and why

In `models-1-gemma.ini` under `[llm]`:

| Setting | Why |
| --- | --- |
| `reasoning = off` | The template defaults `enable_thinking` false, but llama.cpp's `--reasoning` defaults to `auto`, which turns it **on**. Without this, Gemma reasons on every Retain and Consolidation call. |
| `reasoning-budget = 1024` | See above. Bounds the thought block. |
| `temp = 0.2` | Reflect and Consolidation send no sampling params, so they inherit this. Gemma's official 1.0 is worse for structured output. Retain overrides with its own 0.1. |
| `n-predict = 4096` | Backstop. |
| MTP draft commented out | Loading it fails: `Gemma4Assistant requires ctx_other to be set`; llama.cpp then logs `[spec] failed to measure draft model memory` and runs without a draft anyway. |

In `hindsight-gemma.env`, the one difference from the gpt-oss profile:
`HINDSIGHT_API_LLM_EXTRA_BODY` is **omitted**. `reasoning_effort` is a gpt-oss
chat-template kwarg; Gemma's template ignores it, so it bounds nothing.

---

## Validating a change

```bash
cd benchmark && python3 -u gemma-fix-validation.py 40
```

Runs the e2e correctness gate, 40 production Reflects, a Retain/Consolidation
stress, and an `llm_requests` audit. Takes about 70 minutes.

**Do not validate with a short run.** The failure mode is stochastic at ~8% per
Reflect, so a 6-probe e2e comes back green roughly half the time even when badly
broken. That is how Gemma passed disposable-bank testing while hanging every
Reflect on a real bank. 40 Reflects with zero hangs puts the null probability at
3.6%.

In the audit output the number to watch is **calls at/near the 4096 cap**. It
should be zero.

---

## Expected performance

Measured on `psychology` (1749 memories), Gemma vs gpt-oss:

| Operation | Gemma | gpt-oss |
| --- | --- | --- |
| Reflect | 68–83 s | 22–30 s |
| Recall | 2.4–3.3 s | 2.4–3.3 s |
| Retain | ~6.5 s | ~4.0 s |
| Consolidation | ~2–7 s | ~2–3 s |

Recall is identical because it is the reranker's work, not the LLM's.

---

## If Reflect hangs again

In order:

1. `./build.sh --patch-only` — is the patch applied?
2. `grep reasoning-budget models-1-gemma.ini` — is it still set, and still 1024?
3. Check for slots held after a client timeout:
   ```bash
   curl -s http://127.0.0.1:8081/v1/models | python3 -c "import json,sys;[print(m['id'],m['status']['value']) for m in json.load(sys.stdin)['data']]"
   ```
   A wedged slot survives the client giving up; only a router restart clears it.
4. `psql --dbname hindsight` — look for `output_tokens` near 4096 (the backstop
   firing) or missing rows entirely (a call that never returned records nothing).

Capturing the exact failing request is the technique that cracked this: a logging
proxy in front of `:8081` that writes each request body **before** forwarding, so
a request that never returns is still on disk. `HINDSIGHT_API_LLM_DEBUG_DUMP_4XX`
is useless here — it only fires on a 4xx, and this failure is a client-side wall
timeout with no HTTP error at all.

---

## Ruled out — do not re-investigate without new information

| Hypothesis | Verdict |
| --- | --- |
| High context (~95k tokens) | Hang occurs at 32k prompt; 84,428 tokens passes 3/3 |
| An `auto` turn | It is a `required` turn; wire capture is unambiguous |
| Slot prefix-cache reuse | 1/16 hangs with `cache-ram = 0` vs 2/18 with cache on |
| Sampler settings | temp 1.0 vs 0.2, DRY, repeat-penalty — all measured no different |
| Request content | Same bytes hang 4.2% and succeed 95.8% — stochastic |
| `STRICT_SCHEMA=false` | No effect; tool calls are grammar-constrained regardless |
| Offering `done` on the forced turn | **11/12 hangs** — its `memory_ids` array is unbounded too |
| `tool_choice: auto` instead of forcing | Stops the hang, but the model then answers in prose and calls no tool (24/24), raising `ReflectToolCallError` |

Full detail: HINDSIGHT.md, "Gemma 4: rejection, root cause, and fix".

# Hindsight benchmarks

Ad hoc performance comparisons against the shared `../../llama.cpp/` build. Nothing
here is a standalone checkout — the binaries are the same ones `run.sh` serves
with, so a number measured here is a number the deployment can actually reach.

| file | what it measures |
| --- | --- |
| `bench-mtp.sh` | MTP (self-speculative decoding) A/B **on the Hindsight workload**, with per-model server flags embedded in the script |
| `bench-combined.sh` | the same workload against the live combined router and resident production models |
| `bench-streams.py` | isolated prefill, decode, and mixed-stream concurrency against the live router |
| `hindsight-load.py` | the load generator behind `bench-mtp.sh`: replays Hindsight's request shape against any `llama-server` |
| `bench-hindsight.py` | end-to-end against the real Hindsight service (banks, Recall, rerank), not the router |
| `gemma-retain-consolidate.py` | disposable-bank Gemma stress test for Retain and Consolidation only |

`bench-mtp.sh` and `hindsight-load.py` measure llama.cpp under Hindsight-shaped
load. `bench-combined.sh` and `bench-streams.py` measure the live shared router.
`bench-hindsight.py` measures Hindsight itself. Use the synthetic tools to choose
a model or server flag, then confirm the whole system end to end.

## The Hindsight workload

### Ground truth

Hindsight records every LLM call it makes in the `llm_requests` table, with
`operation`, `scope`, `input_tokens`, `cached_tokens`, `output_tokens`,
`duration_ms`, and the full prompt in `input`. **Query it before assuming
anything about request sizes:**

```bash
psql --dbname hindsight -c "
SELECT operation, count(*) n,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY input_tokens)  p50_in,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY output_tokens) p50_out,
       round(100.0*sum(coalesce(cached_tokens,0))/sum(input_tokens)) pct_cached,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY duration_ms)   p50_ms
FROM llm_requests WHERE bank_id='psychology' GROUP BY 1 ORDER BY n DESC;"
```

The figures below come from 480 `gpt-oss-20b` calls the `psychology` bank
recorded between 2026-08-05 16:30 and 2026-08-06 07:43 (87 traces).

### Shape

| operation | calls | % LLM time | input p50 | cached | uncached prefill | output p50 / avg | concurrency avg / max |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| consolidation | 369 (77%) | 53% | 5,493 | 44% | ~3,018 | 255 / 294 | 1.06 / 3 |
| retain | 77 (16%) | 34% | 2,365 | 64% | ~822 | 596 / 611 | 2.45 / 6 |
| reflect | 33 (7%) | 13% | 14,369 (p90 31.6k, max 38k) | not reported | ~16,207 | 82 / 446 | 1.33 / 4 |

Median durations: consolidation 2.61 s, retain 8.71 s, reflect 6.31 s. Total
LLM time across the 480 calls: 2,070 s, i.e. **431 s per 100 calls** — the
figure `bench-mtp.sh`'s `mix, per 100 calls` row is the synthetic analogue of.

**This is decode-dominated, and the old "Prefill dominates the LLM cost"
section is wrong for this bank.** Across the recorded mix, uncached prompt
tokens total ~1.71M against ~170k generated; at this machine's 4,139 tok/s
prefill and 134 tok/s decode that is ~430 s of prefill against ~1,270 s of
decode. The "~90% prompt processing" claim was generalised from four hand-timed
`hermes` calls with 23k prompts and 50-250 token outputs. Retain in particular
is the opposite shape: ~131 new prompt tokens against 679 generated.

### Sequence

Storing one memory produces one chain:

1. **`retain`** — one LLM call per chunk of `retain_chunk_size = 3000` chars.
   All chunks fire concurrently through `asyncio.gather`, bounded only by the
   global LLM semaphore (`HINDSIGHT_API_LLM_MAX_CONCURRENT=3`). Most retains
   here are a single chunk; the 2.45 average overlap comes from multi-chunk and
   multi-document retains.
2. Retain returns, and **consolidation is queued as an async task**, not run
   inline — the worker poller picks it up. This is why an explicit
   `POST /consolidate` returns in ~0.004 s: the work already happened.
3. **`consolidation` — one LLM call per fact**, because
   `HINDSIGHT_API_CONSOLIDATION_LLM_BATCH_SIZE=1`. Batches within a tag group
   run serially (memories with different tags may never share a call); only
   distinct tag groups overlap. Measured ratio: **4.79 consolidations per
   retain**.

A real chain from `llm_requests`:

```
06:18:35  retain         8764 ms   1810 in (1679 cached)   679 out
   +2.1s  consolidation  1446 ms   2512 in (2383 cached)   139 out
   +1.2s  consolidation  1368 ms   2687 in (2426 cached)   136 out
   +1.2s  consolidation  1410 ms   2858 in (2426 cached)   134 out
   +1.2s  consolidation  1531 ms   3049 in (2426 cached)   154 out
   +0.6s  consolidation  1605 ms   3229 in (2427 cached)   199 out
```

Input grows call to call as each fact's recall pools more existing
observations. The gaps are non-LLM work (recall, embeddings, DB).

Reflect is separate and rarer: a 3-4 turn tool loop whose prompt grows from
~2.3k to 14k-38k tokens, producing 800-2,400 output tokens per Reflect.

### Prompt structure and caching

Hindsight builds every prompt as a **stable bank-agnostic prefix plus a
variable user turn**. `build_consolidation_system_prompt()` carries only the
processing rules, input format, decision guide and output format; the bank's
MISSION is pushed into the user message by `build_consolidation_input()`.
Retain does the same through `_retain_mission_preamble()`. The docstrings give
the reason: baking the mission into the system prompt would make the prefix
bank-specific and force a separate cache per mission.

**Hindsight's own prefix-cache machinery is inert in this deployment.**
`get_or_create_cached_prefix()` is gated on `supports_prompt_caching()`, which
only the Gemini provider implements; this deployment runs
`HINDSIGHT_API_LLM_PROVIDER=openai`, so the call takes the uncached path. What
shows up in `cached_tokens` is **llama.cpp's slot prefix cache** —
`openai_compatible_llm.py` reads `usage.prompt_tokens_details.cached_tokens`,
which llama.cpp fills from `n_prompt_tokens_cache`
(`tools/server/server-task.cpp`). Hindsight's prompt split still pays off, just
through llama.cpp instead of its own provider cache.

The hit boundaries land exactly where the split predicts:

| operation | system prompt | cached per call | effect |
| --- | ---: | ---: | --- |
| retain | 7,166 chars | 1,679-1,681 | a 1,810-token prompt costs ~131 new tokens |
| consolidation | 9,740 chars | 2,383 first call, 2,426-2,427 after | the extra ~43 tokens are the MISSION block opening the user message — constant per bank, so the match runs past the system prompt into the user turn |
| reflect | 8,417 chars | not reported | — |

The two different prefixes alternate on the same router without permanently
evicting each other because `gpu-0-1/combined.ini`'s `[*]` sets `cache-ram = -1`: an
evicted slot prefix is restored from host RAM instead of reprocessed. Any
benchmark that sets `cache_prompt: false`, or that varies the system prompt
between requests, roughly doubles the prefill it measures and is not measuring
this deployment.

## How the bench models it

`hindsight-load.py` profiles, all derived from the table above:

| profile | prompt target | max output | concurrency | share of calls | grammar |
| --- | ---: | ---: | ---: | ---: | --- |
| `retain` | 2,365 | 600 | 2 | 16% | strict JSON schema |
| `consolidate` | 5,493 | 255 | 1 | 77% | strict JSON schema |
| `reflect` | 14,369 | 450 | 1 | 7% | none |
| `reflect-long` | 31,564 (p90) | 450 | 1 | — | none |

Faithful to the deployment: the real system prompts (read from `llm_requests`,
falling back to `../templates/*.md`), the shared cached prefix with a freshly
generated payload per request, strict schemas on Retain and Consolidation,
per-operation concurrency from the recorded overlap, no client-side sampling
except Retain's 0.1, and Hindsight's `LLM_EXTRA_BODY`
(`chat_template_kwargs.reasoning_effort=low`).

**Thinking policy.** gpt-oss reasons at `effort=low`: it cannot be switched
off, low is its native output bound, it is what Hindsight sends, and
`../experiments/2026-08-installation-and-tuning-log.md` records that raising it
is net worse end to end. Its recorded
`output_tokens` — the basis for the profiles' output caps — already include
those reasoning tokens. Every other model runs with `-rea off`
(`enable_thinking=false`), so its capped budget goes to the answer instead: Qwen
3.6's template defaults thinking **on** and would otherwise spend most of the
budget reasoning, while Gemma 4 already defaults it off and the flag only makes
that explicit. This is a bench-only choice — Hindsight sends no
`enable_thinking`, so a Qwen deployed as its LLM *would* think. Drop
`$NO_THINK` from a model's flags in `bench-mtp.sh` to measure that case.

Known approximations:

- **Profiles run in isolation, reality is a chain.** The bench measures each
  operation separately; production runs 1 retain then ~4.8 serial
  consolidations with ~1 s of non-LLM gap between them. The `mix, per 100
  calls` row reassembles the cost by call share, but never exercises the prefix
  alternation the real chain causes.
- **Reflect is replayed as a single turn** at the loop's dominant size, not as
  the 3-4 turn tool loop it really is.
- **The payloads are synthetic** — bilingual filler calibrated against the
  server's own `/tokenize` to hit the recorded token targets. Only the system
  prompts are real. Replaying the stored `input` prompts verbatim would be more
  faithful still, and the DB makes it possible.
- **The LLM runs alone on the card**, while production shares GPU1 with the
  resident reranker. Absolute numbers are optimistic; an A/B between two modes
  is not affected.
- **No queueing.** Recorded durations include time spent waiting on Hindsight's
  semaphore; the bench's do not. This is most of the gap between the bench's
  per-call figures and the DB's `duration_ms`.

## Running

```bash
./bench-mtp.sh                  # every model, every profile, baseline vs draft-mtp
./bench-mtp.sh gpt-oss          # filter by label substring
PROFILES="consolidate" REPEATS=5 ./bench-mtp.sh qwen3.8-27b
CONCURRENCY=3 ./bench-mtp.sh    # force the saturated case instead of measured overlap
```

Reports land in `reports/`. **Read the `mix, per 100 calls` row** — it weights
each profile's burst by that operation's share of recorded calls and is the
figure the MTP decision turns on. Per-profile `burst` is the per-operation
view; `pp t/s` and `tg t/s` are diagnostics that explain it. A model where
decode rises and the mix rises is losing.

### Measurement hygiene

**An unloaded card is not an idle test bed.** Stop `cicero-home-ai.service` and
`hindsight.service` before benchmarking — `bench-mtp.sh` warns if they are up
and prints GTT before each load, because a GTT spill (not VRAM exhaustion) is
what silently halved throughput in earlier contaminated runs.

# Hindsight benchmarks

| file | what it measures |
| --- | --- |
| `bench-hindsight.py` | end-to-end against the real Hindsight service (banks, Recall, rerank, Reflect) |
| `../../rad/bench-openai.py` | the LLM server alone: decode, prefill, mixed load and tool calls over the OpenAI API |

`bench-hindsight.py` runs disposable banks plus a read-only pass over a
production bank; see its docstring. Stop other clients of `:8080` first: the
radiance stack is shared with Open WebUI.

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
LLM time across the 480 calls: 2,070 s, i.e. **431 s per 100 calls**.

**This is decode-dominated, and the old "Prefill dominates the LLM cost"
section is wrong for this bank.** Across the recorded mix, uncached prompt
tokens total ~1.71M against ~170k generated; at the llama.cpp stack's 4,139
tok/s prefill and 134 tok/s decode that was ~430 s of prefill against ~1,270 s
of decode. The "~90% prompt processing" claim was generalised from four hand-timed
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

Hindsight builds every prompt as a stable bank-agnostic system prompt plus a
variable user turn (the bank's mission goes into the user message), so the
server's prefix cache serves the system prompt; `cached_tokens` in
`llm_requests` is what the server reports for it.

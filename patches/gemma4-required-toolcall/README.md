# gemma4-required-toolcall

Rationale for `llama-cpp.patch`, applied to `llama.cpp/` by `build.sh`.
Deployment notes: `../../hindsight/experiments/gemma4.md`.

Draft PR body below. Rewrite it in your own words before submitting — llama.cpp
prohibits AI-written PR descriptions (AGENTS.md), and the AI disclosure line is
required.

---

## Overview

With `tool_choice: "required"` the gemma4 grammar can never terminate: a tool call
is outstanding so EOS is never in the allowed set, but `scan_to_toolcall` and
`content` accept unbounded text before it. A model that answers the forced turn in
prose instead of calling the tool has no exit and generates until something else
stops it. A non-streaming client disconnecting doesn't stop it either, so the slot
stays busy until restart.

Reproduces every time on gemma-4-26B-A4B-it-qat with default sampling: ask "What is
2+2?" with one unrelated tool and `"tool_choice":"required"`. The request never
returns and `n_decoded` climbs past 7000. With this patch it answers in under 2s
with a well-formed tool call.

`common_chat_params_init_gpt_oss` already drops its content-only alternative when
required, and `functionary_v3_2` special-cases it too. This does the same for
gemma4.

## Additional information

The thought block and the tool arguments in the same function are unbounded too,
and left alone here — `--reasoning-budget` covers the former, and the commented-out
`params` schema above `p.tool_args` would cover the latter.

Probably fixes #21375. Tested on Vulkan only.

## Requirements

- I have read and agree with the [contributing guidelines](https://github.com/ggml-org/llama.cpp/blob/master/CONTRIBUTING.md)
- AI usage disclosure: <!-- YES / NO — describe how -->

---

## Notes (not for the PR)

Full reproducer:

```bash
llama-server -m gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf --jinja -c 8192 -ngl 99

curl -s localhost:8080/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "messages":[{"role":"user","content":"What is 2+2?"}],
  "tools":[{"type":"function","function":{"name":"get_weather",
    "parameters":{"type":"object","properties":{"city":{"type":"string"}}}}}],
  "tool_choice":"required"}'
```

Measurements:

- Minimal repro, identical flags, plain `llama-server`: unpatched 3/3 hang (>60s),
  patched 3/3 in 0–2s, 44–58 output tokens.
- Thought block: 5/120 hangs on a real workload, runaway in `reasoning_content` so
  the client sees silence; `--reasoning-budget 1024` → 0/120.
- Tool arguments: forcing a tool whose schema invites list output hangs 11/12.
- Not sampling: `temp` 1.0 → 0.2, DRY, `repeat-penalty` made no difference.
- Reproduced on `b10298` (`15586e2d7`), re-validated on `4cf5cab65`.

Not the same defect, listed to avoid mis-citing: #21799 / #21365 / #21516 are
high-context or plain-generation repetition — the repro above is a ~20-token
prompt. #20867 / #25895 are GBNF compile ceilings. #22786 / #21316 are parsing,
not termination.

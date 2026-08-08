# chat: fix non-terminating generation in the gemma4 parser when `tool_choice` is `required`

## Problem

With `peg-gemma4` and `tool_choice: "required"`, generation can never stop.

`common_chat_params_init_gemma4` builds:

```cpp
auto tool_call = p.trigger_rule("tool-call", p.repeat(..., /* min = */ REQUIRED ? 1 : 0, ...));
auto scan_to_toolcall = p.rule("scan-to-toolcall", p.until("<|tool_call>"));
return start + p.zero_or_more(message) + scan_to_toolcall + tool_call;
```

with `grammar_lazy = false` when required. So a tool call is mandatory — EOS is
never in the allowed set — *and* unbounded content is legal before it. A model
that responds to the forced turn by answering in prose instead of calling the
tool has no exit: it emits content forever, degenerating into single-token
repetition. Because llama.cpp keeps decoding after a non-streaming client
disconnects, each occurrence also holds a slot until the server restarts.

`common_chat_params_init_gpt_oss` already handles this case, dropping its
content-only alternative when required:

```cpp
if (inputs.tool_choice == COMMON_CHAT_TOOL_CHOICE_REQUIRED) {
    return p.zero_or_more(start + any) + start + tool_call;
}
return p.zero_or_more(start + any) + start + (tool_call | final_msg);
```

`functionary_v3_2` special-cases `REQUIRED` too. gemma4 is the only one that
doesn't.

## Fix

Same treatment — no free-content path when a tool call is required:

```diff
+            if (inputs.tool_choice == COMMON_CHAT_TOOL_CHOICE_REQUIRED) {
+                return start + p.optional(thought) + tool_call;
+            }
+
             return start + p.zero_or_more(message) + scan_to_toolcall + tool_call;
```

`auto` and `none` are untouched.

It doesn't look identical to the gpt-oss version because the formats carry
content differently. gpt-oss wraps content in delimited
`<|channel|>…<|message|>…<|end|>` blocks, so its answer path is a discrete
`final_msg` rule and deleting that rule suffices. gemma4 has no wrapper — its
answer path *is* the bare `content` / `scan_to_toolcall` runs of raw text — so the
equivalent is to exclude those. The shape used here mirrors gemma4's own
`has_response_format` branch a few lines up
(`start + p.optional(thought) + response_format`), which is the closer analogue:
both mean "constrained output is mandatory, no free answer". `p.optional` rather
than `p.zero_or_more` because `thought` already matches empty.

## Evidence

A real request captured off the wire (large tool result in context,
`tools: ["recall"]`, `tool_choice: "required"`) and replayed byte for byte.

Before the fix, with only `tool_choice` varied:

| `tool_choice` | Result |
| --- | --- |
| `"required"` | still generating at 150 s, 23k chars, tail `*_**_**_**…` |
| `"auto"` | 6 s, `finish_reason=stop`, clean answer |

Server side: a single task, `n_decoded` climbing 307 → 33,525 monotonically, with
`max_tokens: -1` — one request that never ends, not an agent loop.

After the fix, the same request returns in 9.7 s with
`finish_reason=tool_calls`, a well-formed call and zero free content. Across 120
replays, **no hang is attributable to the content path**; the residual failures
(below) all land in a different rule.

## Known remaining holes

This PR closes one of three unbounded rules in the same function. I would rather
enumerate them than imply the parser is now safe.

**The thought block** — `p.reasoning(p.until("<channel|>"))` — is equally
unbounded and still reachable on a required turn. Measured 5/120 hangs on the
replayed request above, every one with the runaway in `reasoning_content`, so the
client sees only silence rather than a runaway. I deliberately did not patch it:
`--reasoning-budget N` already bounds it at the sampler and forces the closing
tag, measured 0/120 on the same request while still letting the model think.
Removing the thought from the grammar also works (0/120) but costs a real
capability, and would put gemma4 further from gpt-oss, which still permits
`analysis` blocks on required turns.

**Tool arguments** — `gemma4-string-content` and `gemma4-array` are unbounded, so
forcing a tool whose schema invites long list output hangs 11/12. This is the case
the commented-out `params` schema would address (the `TODO @aldehir` above
`p.tool_args`), since `json-schema-to-grammar` already supports
`maxItems`/`maxLength`. Out of scope here, but it is the same defect class and
probably the right long-term fix.

For what it's worth in a real deployment: with this patch plus
`--reasoning-budget`, an agent that forces a retrieval tool on early iterations
(Hindsight's Reflect, 1749-memory bank) goes from hanging on essentially every
attempt to **40/40 completing**, with no generation approaching the `--n-predict`
backstop. That result is the patch *and* the budget together, not this patch
alone.

Not a sampling issue: `temp` 1.0 → 0.2, DRY, `repeat-penalty`, and offering
additional tools each made no difference, which is what pointed at the grammar.

## Caveats

Reproduced on `b10298` (`15586e2d7`) and re-validated on `4cf5cab65`, Vulkan
backend, `gemma-4-26B-A4B-it-qat`. Grammar construction is backend-independent, but
I only tested Vulkan, and only this model — the change affects every gemma4 model.

No test added. A grammar-level regression test asserting that a `required` turn
admits no non-terminating derivation would be worthwhile; happy to add one if you
suggest where it best fits.

## Related issues

Plausibly the same defect: #21375 (closed as not planned — "infinite repetition
loop with peg-gemma4 parser during tool calls") and #25072.

Related but **not** fixed by this, and worth separating: #21799, #21365, #21516
describe Gemma 4 repetition at high context or on plain generation. I could not
reproduce a context-size dependency for the failure above — it occurs at a 32k
prompt, while an 84k-token prompt passed cleanly — so I would not claim this patch
addresses those.

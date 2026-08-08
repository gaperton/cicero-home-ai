# chat: fix non-terminating generation in the gemma4 parser when `tool_choice` is `required`

## Problem

With `peg-gemma4` and `tool_choice: "required"`, generation can never stop.

`common_chat_params_init_gemma4` builds:

```cpp
auto tool_call = p.trigger_rule("tool-call", p.repeat(..., /* min = */ REQUIRED ? 1 : 0, ...));
auto scan_to_toolcall = p.rule("scan-to-toolcall", p.until("<|tool_call>"));
return start + p.zero_or_more(message) + scan_to_toolcall + tool_call;
```

with `grammar_lazy = false` when required. So a tool call is mandatory (EOS is never
in the allowed set) *and* unbounded content is legal before it. A model that answers
the forced turn in prose instead of calling the tool has no exit: it emits content
forever, degenerating into single-token repetition, and keeps decoding after the
client disconnects — wedging the slot until restart.

`common_chat_params_init_gpt_oss` already handles exactly this, dropping its
content-only alternative when required:

```cpp
if (inputs.tool_choice == COMMON_CHAT_TOOL_CHOICE_REQUIRED) {
    return p.zero_or_more(start + any) + start + tool_call;
}
return p.zero_or_more(start + any) + start + (tool_call | final_msg);
```

`functionary_v3_2` special-cases `REQUIRED` too. gemma4 is the only one that doesn't.

## Fix

Same treatment: no free-content path when a tool call is required. The optional
thought block stays, matching the `has_response_format` branch just above.

```diff
+            if (inputs.tool_choice == COMMON_CHAT_TOOL_CHOICE_REQUIRED) {
+                return start + p.optional(thought) + tool_call;
+            }
+
             return start + p.zero_or_more(message) + scan_to_toolcall + tool_call;
```

`auto` and `none` are untouched.

It doesn't look identical to the gpt-oss fix because the formats carry content
differently. gpt-oss wraps content in delimited `<|channel|>…<|message|>…<|end|>`
blocks, so its answer path is a discrete `final_msg` rule and deleting that rule is
enough. gemma4 has no wrapper — its answer path *is* the bare `content` /
`scan_to_toolcall` runs of raw text — so the equivalent is to exclude those. The
shape used here mirrors gemma4's own `has_response_format` branch a few lines up
(`start + p.optional(thought) + response_format`), which is the closer analogue:
both mean "constrained output is mandatory, no free answer". `p.optional` rather
than `p.zero_or_more` because `thought` already matches empty.

Note this is stricter than gpt-oss's version, which still allows unlimited
well-formed `analysis`/`preamble` blocks before the required call — the same latent
shape, but a much narrower hole since each iteration forces `<|end|>` plus a new
header. Happy to loosen gemma4 to match if you'd rather the two be symmetric.

## Evidence

One real request (large tool result already in context, `tools: ["recall"]`,
`tool_choice: "required"`), replayed byte for byte with a single variable changed:

| | Result |
| --- | --- |
| `"required"`, before fix | still generating at 150 s, 23k chars, tail `*_**_**_**…` |
| `"auto"`, before fix | 6 s, `finish_reason=stop` |
| `"required"`, **after fix** | 9.7 s, `finish_reason=tool_calls`, well-formed call, 0 free content |

Server side before the fix: one task, `n_decoded` 307 → 33,525 monotonic, with
`max_tokens: -1`.

End-to-end against an agent that forces a retrieval tool on early iterations: every
attempt used to hit the 300 s client timeout; after the fix the same query completes
in 82 s, and a 3-probe suite goes from 0/3 to 2/3.

The remaining probe failure is a separate issue and not addressed here — it occurs
on an `auto` turn at ~95k prompt tokens, where the grammar is lazy and EOS is
available, i.e. the high-context repetition collapse tracked in #21799. Mentioning
it so the fix is not oversold: this PR removes a grammar defect, it does not make
gemma4 hang-free.

Not a sampler issue — `temp` 1.0→0.2, DRY, `repeat-penalty` and offering extra tools
each made no difference, which is what pointed at the grammar.

## Caveats

Reproduced on `b10298` (`15586e2d7`), Vulkan, `gemma-4-26B-A4B-it-qat`. Grammar
construction is backend-independent but I only tested Vulkan. No test added — happy
to add one if you suggest where it fits.

Likely the same root cause as #21375 (closed as not planned), #25072, #21799, #21365,
#21516.

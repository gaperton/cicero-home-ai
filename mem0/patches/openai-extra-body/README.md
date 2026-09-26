# openai-extra-body

Lets the server's `openai` LLM send a fixed `extra_body` with every request, set
in `mem0/configure.json`:

```json
"extra_body": {"chat_template_kwargs": {"enable_thinking": false}}
```

**Why.** `[qwen3.8-27b]` thinks unless the request says otherwise, and Mem0 has no
setting that sends llama.cpp's `chat_template_kwargs`. No Mem0 LLM provider sends
`extra_body`, and the Qwen3.8 template has no `/no_think` text switch. The only
config-level switch is `is_reasoning_model: true` + `reasoning_effort: "none"`
(llama.cpp maps `"none"` to `enable_thinking=false`), but in that mode Mem0 sends
only `messages`, `response_format` and `reasoning_effort` (`mem0/llms/base.py`,
`_get_supported_params`). It drops `temperature`, `top_p` and `max_tokens`, so the
preset's thinking-mode sampling (temperature 1.0) applies and nothing caps the
output. Hindsight solves the same problem with
`HINDSIGHT_API_RETAIN_LLM_EXTRA_BODY`.

**What.** `server/cicero_llm.py` subclasses Mem0's `OpenAIConfig` (adds
`extra_body`) and `OpenAILLM` (passes it to `chat.completions.create`), and
re-registers them as the `openai` provider — `LlmConfig` rejects provider names
outside its hardcoded list, so a new name is not an option. `server/main.py`
imports the module before `initialize_state()` builds the `Memory`. Without
`extra_body` in the config the provider behaves exactly like upstream.

Drop this patch if Mem0's OpenAI config gains an `extra_body` (or equivalent)
option.

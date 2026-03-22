# llama-server

Local LLM server based on [llama.cpp](https://github.com/ggml-org/llama.cpp) with Vulkan backend.

## Models

| Preset | Model | Context | Mode |
|---|---|---|---|
| `qwen3.5-27b@q5-200k` | Qwen3.5 27B UD-Q5_K_XL | 200k | chat |
| `qwen3.5-27b@q5-200k-coding` | Qwen3.5 27B UD-Q5_K_XL | 200k | thinking |
| `qwen3.5-35b-a3b@q5-262k` | Qwen3.5 35B-A3B UD-Q5_K_XL | 262k | chat |
| `qwen3.5-35b-a3b@q5-262k-coding` | Qwen3.5 35B-A3B UD-Q5_K_XL | 262k | thinking |
| `glm4.7-flash@q5` | GLM-4.7 Flash UD-Q5_K_XL | — | chat |
| `glm4.7-flash@q5-coding` | GLM-4.7 Flash UD-Q5_K_XL | — | thinking |

Sampling params follow official model card recommendations. Thinking/coding presets enable the model's Jinja chat template for chain-of-thought reasoning.

## Usage

```bash
# First-time setup
sudo ./install.sh

# Start server (updates llama.cpp + models, then starts llama-server)
./run.sh

# Same, but in a tmux session with mc on the right
./run-tmux.sh

# Stop the tmux session
./run-tmux.sh kill
```

The server exposes an OpenAI-compatible API on `http://localhost:8080`.

## Scripts

| Script | Description |
|---|---|
| `install.sh` | Install dependencies, clone and build llama.cpp, install `hf` CLI |
| `update.sh` | Pull latest llama.cpp, rebuild, download updated models from HuggingFace |
| `run.sh` | Run `update.sh` then start `llama-server` |
| `run-tmux.sh` | Run `run.sh` in a tmux session with mc file manager |

## Layout

```
models/
  presets.ini               # model presets (sampling params, ctx size, etc.)
  *.gguf                    # model files (downloaded from unsloth HF repos)
llama.cpp/                  # cloned source + built binaries
```

## Requirements

- Ubuntu 24.04 (Noble)
- GPU with Vulkan support
- HuggingFace account (for higher download rate limits)

## HuggingFace authentication

```bash
hf auth login
```

Saves your token to `~/.cache/huggingface/token` — picked up automatically by `update.sh`.

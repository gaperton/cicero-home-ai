# llama-server

Local LLM server based on [llama.cpp](https://github.com/ggml-org/llama.cpp) with Vulkan backend, managed by [llama-swap](https://github.com/mostlygeek/llama-swap) for on-demand model switching.

## Models

| Preset | Model | Context |
|---|---|---|
| `qwen3.5-27b@q5-200k` | Qwen3.5 27B UD-Q5_K_XL | 200k |
| `qwen3.5-35b-a3b@q5-262k` | Qwen3.5 35B-A3B UD-Q5_K_XL | 262k |
| `glm4.7-flash@q5` | GLM-4.7 Flash UD-Q5_K_XL | — |

Sampling params follow official model card recommendations.

## Usage

```bash
# First-time setup
sudo ./install.sh

# Update llama.cpp + models, then start llama-swap
./run.sh

# Same, but in a tmux session with mc on the right
./run-tmux.sh

# Stop the tmux session
./run-tmux.sh kill

# Update without starting the server
./update.sh
```

`update.sh` pulls the latest llama.cpp source, rebuilds with the Vulkan backend, and downloads updated model files from HuggingFace (skipping unchanged files).

The server exposes an OpenAI-compatible API on `http://localhost:8080`.

## Scripts

| Script | Description |
|---|---|
| `install.sh` | Install dependencies, clone and build llama.cpp, install `hf` CLI |
| `update.sh` | Pull latest llama.cpp, rebuild, download updated models from HuggingFace |
| `run.sh` | Run `update.sh` then start `llama-swap` |
| `run-tmux.sh` | Run `run.sh` in a tmux session with mc file manager |

## Layout

```
config.yaml                 # llama-swap config (models, macros)
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

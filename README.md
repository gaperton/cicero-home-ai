# cicero-home-ai

Home AI server running local LLMs via [llama.cpp](https://github.com/ggml-org/llama.cpp) in router mode for on-demand model switching. Exposes an OpenAI-compatible API on port 8080 and a built-in web UI at the same port.

## How it works

`llama-server` runs in **router mode** — a built-in multi-model proxy. It listens on port 8080 and routes requests to the appropriate model based on the model name in the request. When a request comes in for a model that isn't loaded, the router starts a new child process for that model and proxies the request. With `--models-max 1`, only one model is in VRAM at a time (LRU eviction).

Model server flags and sampling parameters are defined in `models.ini` (INI preset file).

`mcp-proxy` runs alongside llama-server and wraps stdio MCP servers (Brave Search, web fetch) as streamable HTTP endpoints on port 8200. The llama.cpp web UI connects to these via its built-in CORS proxy.

| Script | What it does |
|---|---|
| `install.sh` | Installs system dependencies, clones llama.cpp, installs the `hf` CLI, `mcp-proxy`, and `uv`. Run once with `sudo`. |
| `update.sh` | Pulls latest llama.cpp source, rebuilds incrementally, downloads updated model files from HuggingFace (skips unchanged files). |
| `run.sh` | Runs `update.sh`, starts `mcp-proxy` (MCP servers on :8200), then starts `llama-server` in router mode. |
| `run-tmux.sh` | Runs `run.sh` in a tmux session with `mc` file manager in the right pane. The recommended way to run the server. |
| `bench.sh` | Runs `llama-bench` across all configured models and saves a Markdown report to `reports/`. |

## Installation

Configured for AMD, using Vulkan with the default drivers from Linux HWE kernels. No proprietary drivers needed.

1. Install Linux Mint Cinnamon (or Ubuntu; Mint/Ubuntu assumed below)
2. Clone this repo and `cd` into it
3. Run first-time setup:
   ```bash
   sudo ./install.sh
   ```
4. Reload your shell so `hf` is on PATH, then authenticate with HuggingFace:
   ```bash
   source ~/.bashrc
   hf auth login
   ```
5. Edit `.env` if needed (see [Configuration](#configuration) below)
6. Copy `mcp-config.json` and fill in your Brave Search API key (free tier at brave.com/search/api):
   ```bash
   cp mcp-config.json.example mcp-config.json   # or edit directly
   ```
7. Build llama.cpp and download all models (~70 GB):
   ```bash
   ./update.sh
   ```

## MCP tools

MCP servers are configured in `mcp-config.json` (gitignored — contains API keys). `mcp-proxy` wraps them as streamable HTTP endpoints used by the llama.cpp web UI.

| Server | Package | Description |
|---|---|---|
| `brave-search` | `@modelcontextprotocol/server-brave-search` | Web search via Brave Search API |
| `fetch` | `mcp-server-fetch` (via `uvx`) | Free web page fetching |

The web UI connects to these at `http://localhost:8200/servers/{name}/mcp` via the llama-server CORS proxy.

**mcp-config.json format:**
```json
{
  "mcpServers": {
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": { "BRAVE_API_KEY": "your-key-here" }
    },
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"]
    }
  }
}
```

## Booting into TTY and auto-starting the server

Running in TTY (no desktop environment) frees up ~2–4 GB of VRAM, which is needed for the full context sizes. To add a dedicated GRUB entry that boots straight into TTY and auto-starts the server:

**1. Add a custom GRUB entry**

Copy the `linux` and `initrd` lines from your existing Mint entry in `/boot/grub/grub.cfg`, append `systemd.unit=multi-user.target` to the `linux` line, and save the result to `/etc/grub.d/40_custom`:

```bash
menuentry "cicero-home-ai (TTY)" {
    search --no-floppy --fs-uuid --set=root <your-root-uuid>
    linux   /boot/vmlinuz-... root=UUID=<your-root-uuid> ro quiet splash systemd.unit=multi-user.target
    initrd  /boot/initrd.img-...
}
```

Get your root UUID with `lsblk -o NAME,UUID`, then regenerate GRUB:

```bash
sudo update-grub
```

**2. Enable autologin on TTY1**

```bash
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
```

**3. Auto-start the server on TTY1 login**

Add to `~/.bash_profile`:

```bash
if [ "$(tty)" = "/dev/tty1" ]; then
    exec ~/llama-server/run-tmux.sh
fi
```

On next boot, selecting the GRUB entry will log in automatically and launch the tmux session with the server running.

## Configuration

**`.env`** — GPU backend for the llama.cpp build:

| Variable | Default | Description |
|---|---|---|
| `CMAKE_GPU_FLAG` | `-DGGML_VULKAN=ON` | GPU backend. Use `-DGGML_CUDA=ON` for CUDA or `-DGGML_HIP=ON` for ROCm. |

**`models.ini`** — per-model sampling params and global server flags (`[*]` section).

**`mcp-config.json`** — MCP server definitions (gitignored, contains API keys).

**`webui-config.json`** — pre-configures MCP server URLs in the web UI.

## Models

Sized to use the full 32GB VRAM of the AMD R9700 in TTY mode. If running from a desktop session, reduce context to ~150,000 to account for the ~2–4 GB consumed by the UI.

| Preset | Model |
|---|---|
| `qwen3.5-27b@q5-200k` | Qwen3.5 27B UD-Q5_K_XL |
| `qwen3.5-35b-a3b@q5-262k` | Qwen3.5 35B-A3B UD-Q5_K_XL |
| `glm4.7-flash@q5` | GLM-4.7 Flash UD-Q5_K_XL |

Context size is auto-fit by llama.cpp to available VRAM (`fit-target = 256` in `models.ini`).

### Adding or changing models

**1. Add a download step in `update.sh`:**

```bash
hf download <hf-repo> <filename>.gguf --local-dir models/
```

**2. Add a preset section in `models.ini`:**

```ini
[my-model@q5]
model = models/<filename>.gguf
temp = 1.0
top-p = 0.95
repeat-penalty = 1.0
```

- The section name (`my-model@q5`) is the model name clients pass in API requests.
- Global settings from `[*]` (GPU layers, flash attention, etc.) are inherited automatically.
- Add sampling params per model, or omit them for agent-facing models (agents send their own).
- Always set `repeat-penalty = 1.0` to explicitly disable it.
- To remove a model, delete its section from `models.ini` and its `hf download` line from `update.sh`.

## Layout

```
.env                        # local config (CMAKE_GPU_FLAG)
models.ini                  # router preset (models, sampling params, server flags)
mcp-config.json             # MCP server definitions (gitignored — contains API keys)
webui-config.json           # web UI pre-configuration (MCP server URLs)
models/
  *.gguf                    # model files (downloaded from HuggingFace)
reports/
  bench-*.md                # llama-bench output (generated by bench.sh)
llama.cpp/                  # cloned source + built binaries
```

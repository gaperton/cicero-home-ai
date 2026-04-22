# cicero-home-ai

Home AI server running local LLMs via [llama.cpp](https://github.com/ggml-org/llama.cpp) in router mode. Exposes an OpenAI-compatible API and a chat UI ([Open WebUI](https://github.com/open-webui/open-webui) on port 3000).

## How it works

`llama-server` runs in **router mode** — a built-in multi-model proxy. It routes requests based on the model name in the request; when a model isn't loaded, the router starts a child process for it and proxies the request. With `--models-max 1`, only one model is in VRAM at a time (LRU eviction).

On **Vulkan (dual-GPU)**, two `llama-server` instances run in parallel:
- **GPU 0 → port 8080**, preset from `models-0.ini`
- **GPU 1 → port 8081**, preset from `models-1.ini`

On **ROCm (single-GPU)**, one instance runs on port 8080, preset from `models.ini`.

**Open WebUI** runs on port 3000 and is pre-configured to use both llama-server endpoints as OpenAI-compatible backends.

**mcp-proxy** wraps stdio MCP servers (Brave Search, web fetch) as streamable HTTP endpoints on port 8200, which the Open WebUI connects to via the llama-server CORS proxy.

| Script | What it does |
|---|---|
| `install.sh` | Install deps, clone llama.cpp checkouts, install Python tools, install and enable the systemd user service. Run once with `sudo`. |
| `update.sh` | Stop the service, pull latest llama.cpp, rebuild, download updated models, restart the service. |
| `start.sh` | Start the service via `systemctl --user`. |
| `stop.sh` | Stop the service via `systemctl --user`. |
| `run.sh` | Start the full stack (llama-server + mcp-proxy + Open WebUI) in the foreground. Called by the systemd service. |
| `run-tmux.sh` | Run `run.sh` in a tmux session with `mc` in the right pane, then attach. For interactive monitoring. |
| `bench.sh` | Run `llama-bench` across all models and save a Markdown report to `reports/`. |

## Usage

```bash
./start.sh          # start the service
./stop.sh           # stop the service
./update.sh         # stop, rebuild, download models, restart
./run-tmux.sh       # start and attach interactively (tmux session with mc)
./run-tmux.sh kill  # kill the interactive tmux session
```

## Installation

Configured for AMD, using Vulkan with the default drivers from Linux HWE kernels. No proprietary drivers needed.

1. Install Linux Mint Cinnamon (or Ubuntu; Mint/Ubuntu assumed below)
2. Clone this repo and `cd` into it
3. Run first-time setup (installs deps, clones llama.cpp, installs and enables the systemd user service):
   ```bash
   sudo ./install.sh
   ```
4. Reload your shell so `hf` is on PATH, then authenticate with HuggingFace:
   ```bash
   source ~/.bashrc
   hf auth login
   ```
5. Copy `mcp-config.example.json` and fill in your Brave Search API key (free tier at brave.com/search/api):
   ```bash
   cp mcp-config.example.json mcp-config.json
   ```
6. Build llama.cpp, download all models (~70 GB), and start the service:
   ```bash
   ./update.sh
   ```

To adjust the GPU backend or server flags before building, edit `.env` (see [Configuration](#configuration)).

## MCP tools

MCP servers are configured in `mcp-config.json` (gitignored — contains API keys). `mcp-proxy` wraps them as streamable HTTP endpoints used by Open WebUI.

| Server | Package | Description |
|---|---|---|
| `brave-search` | `@modelcontextprotocol/server-brave-search` | Web search via Brave Search API |
| `fetch` | `mcp-server-fetch` (via `uvx`) | Free web page fetching |

A free Brave Search API key (2000 queries/month): [brave.com/search/api](https://brave.com/search/api) — sign up, create an app, copy the key into `mcp-config.json`.

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

Running in TTY (no desktop) frees ~2–4 GB of VRAM needed for full context sizes. The systemd user service (installed by `install.sh`) starts the server automatically on boot with lingering enabled.

**1. Add a custom GRUB entry**

Copy the `linux` and `initrd` lines from your existing Mint entry in `/boot/grub/grub.cfg`, append `systemd.unit=multi-user.target` to the `linux` line, and save to `/etc/grub.d/40_custom`:

```bash
menuentry "cicero-home-ai (TTY)" {
    search --no-floppy --fs-uuid --set=root <your-root-uuid>
    linux   /boot/vmlinuz-... root=UUID=<your-root-uuid> ro quiet splash systemd.unit=multi-user.target
    initrd  /boot/initrd.img-...
}
```

Get your UUID with `lsblk -o NAME,UUID`, then regenerate GRUB:

```bash
sudo update-grub
```

**2. Enable autologin on TTY1 (optional)**

```bash
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
```

On next boot, selecting the GRUB entry boots into TTY and the systemd user service starts the server stack automatically.

Useful commands:

```bash
systemctl --user status cicero-home-ai.service
journalctl --user -u cicero-home-ai.service -f
tail -f logs/autostart.log
```

To switch the backend, edit `ExecStart=` in `~/.config/systemd/user/cicero-home-ai.service` (e.g. `run.sh rocm`), then `systemctl --user daemon-reload`.

## Configuration

**`.env`** — GPU backend build flags and server flags:

| Variable | Default | Description |
|---|---|---|
| `CMAKE_VULKAN_FLAGS` | `-DGGML_VULKAN=ON` | CMake flags for the Vulkan llama.cpp build. |
| `CMAKE_ROCM_FLAGS` | `-DGGML_HIP=ON ...` | CMake flags for the ROCm build. Adjust `AMDGPU_TARGETS` for your GPU. |
| `SERVER_FLAGS_COMMON` | `--host 0.0.0.0 --models-max 1 --webui-mcp-proxy` | Flags passed to every `llama-server` instance. |
| `SERVER_FLAGS_VULKAN` | _(empty)_ | Extra flags for the Vulkan backend. |
| `SERVER_FLAGS_ROCM` | _(empty)_ | Extra flags for the ROCm backend. |

**`models.ini`** (ROCm) / **`models-0.ini` + `models-1.ini`** (Vulkan) — per-model sampling params and global server flags (`[*]` section).

**`mcp-config.json`** — MCP server definitions (gitignored, contains API keys).

**`webui-config.json`** — pre-configures MCP server URLs in Open WebUI.

## Models

Sized to use the full 32 GB VRAM of the AMD R9700 in TTY mode. If running from a desktop session, reduce `fit-target` in `models.ini` to account for the ~2–4 GB consumed by the desktop.

| Preset | Model |
|---|---|
| `qwen3.6-27b@q5-200k` | Qwen3.6 27B UD-Q5_K_XL |
| `qwen3.6-35b-a3b@q5-262k` | Qwen3.6 35B-A3B UD-Q5_K_XL |
| `gemma4-31b@q5-128k` | Gemma 4 31B UD-Q5_K_XL |

Context is auto-fit to available VRAM (`fit-target = 256` in `models.ini`).

### Adding or changing models

**1.** Add a download step in `update.sh`:

```bash
hf download <hf-repo> <filename>.gguf --local-dir models/
```

**2.** Add a preset section in `models.ini`:

```ini
[my-model@q5]
model = models/<filename>.gguf
temp = 1.0
top-p = 0.95
repeat-penalty = 1.0
```

- The section name (`my-model@q5`) is the model identifier used in API requests.
- Global settings from `[*]` (GPU layers, flash attention, etc.) are inherited automatically.
- Add sampling params per model, or omit them for agent-facing models (agents send their own).
- Always set `repeat-penalty = 1.0` to explicitly disable it.
- To remove a model, delete its section from `models.ini` and its `hf download` line from `update.sh`.

## Layout

```
.env                        # GPU backend build flags and server flags
models.ini                  # router preset for ROCm (models, sampling params, server flags)
models-0.ini                # router preset for Vulkan GPU 0 (port 8080)
models-1.ini                # router preset for Vulkan GPU 1 (port 8081)
mcp-config.json             # MCP server definitions (gitignored — contains API keys)
webui-config.json           # Open WebUI pre-configuration (MCP server URLs)
models/
  *.gguf                    # model files (downloaded from HuggingFace)
reports/
  bench-*.md                # llama-bench output (generated by bench.sh)
systemd/
  cicero-home-ai.service    # user service template (installed to ~/.config/systemd/user/ by install.sh)
llama-vulkan/               # llama.cpp source + Vulkan build (cloned by install.sh)
llama-rocm/                 # llama.cpp source + ROCm build (cloned by install.sh)
```

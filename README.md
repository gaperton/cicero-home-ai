# cicero-home-ai

Home AI server running local LLMs via [llama.cpp](https://github.com/ggml-org/llama.cpp) in router mode. Exposes an OpenAI-compatible API and a chat UI ([Open WebUI](https://github.com/open-webui/open-webui) on port 3000).

## How it works

`llama-server` runs in **router mode** — a built-in multi-model proxy. It routes requests based on the model name in the request; when a model isn't loaded, the router starts a child process for it and proxies the request. With `--models-max 1`, only one model is in VRAM at a time per instance (LRU eviction).

Two instances run side by side, one per GPU (Vulkan backend, no layer-split): port 8080 on GPU0 loads `models-0.ini`, while port 8081 on GPU1 loads `models-1.ini`. Running each GPU independently outperforms splitting a single model across both cards, and lets two different models stay resident at once.

**Open WebUI** runs on port 3000 and uses only the primary Vulkan0 router on port 8080. The secondary Vulkan1 router on port 8081 is reserved for Hindsight and direct API clients. Both raw llama.cpp APIs remain reachable on the LAN as `http://cicero.local:8080/v1` and `http://cicero.local:8081/v1`.

| Script | What it does |
|---|---|
| `install.sh` | Install deps, clone the llama.cpp checkout, install Python tools, install and enable the systemd user service. Run once with `sudo`. |
| `update.sh` | Stop the service, rebuild, update models, and restart the service. |
| `start.sh` | Start the service via `systemctl --user`. |
| `stop.sh` | Stop the service via `systemctl --user`. |
| `run.sh` | Start the full stack (llama-server + Open WebUI) in the foreground. Called by the systemd service. |
| `benchmark/bench.sh` | Run `llama-bench` (single GPU, Vulkan) and save a Markdown report under `benchmark/reports/`. |
| `benchmark/bench-mtp.sh` | Boot `llama-server` per model/quant and measure MTP speculative-decoding speedup. |

## Usage

```bash
./start.sh    # start the service
./stop.sh     # stop the service
./update.sh   # rebuild, update models, restart
./run.sh      # foreground stack
```

## Installation

Configured for AMD GPUs using the Vulkan backend (via Mesa RADV) — no ROCm/HIP SDK required.

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
5. Build llama.cpp, download all models listed in `models/list.txt`, and start the service:
   ```bash
   ./update.sh
   ```

The systemd service runs `./run.sh`. Build and server flags live in `.env`; see [Configuration](#configuration).

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

## Configuration

**`.env`** — Vulkan build flags and server flags:

| Variable | Default | Description |
|---|---|---|
| `CMAKE_FLAGS` | `-DGGML_VULKAN=ON -DGGML_NATIVE=1 ...` | CMake flags for the llama.cpp build. |
| `SERVER_FLAGS` | `--host 0.0.0.0 --models-max 1` | Flags passed to each `llama-server` instance. |

**`models-0.ini` / `models-1.ini`** — per-model sampling params and global server flags (`[*]` section) for the Vulkan0:8080 and Vulkan1:8081 routers respectively. Each instance is pinned to one GPU on the CLI (see `run.sh`), so presets must fit a single 32GB card — no `split-mode=layer`.

## Models

Each preset must fit a single 32 GB card, since instances are pinned one-per-GPU (no `split-mode=layer`). Sized for TTY mode; if running from a desktop session, reduce `fit-target` in the corresponding `models-*.ini` file to account for the ~2–4 GB consumed by the desktop.

| Router | Preset | Model |
|---|---|---|
| Vulkan0:8080 | `qwen3.6-27b` | Qwen3.6 27B UD-Q6_K_XL with built-in MTP |
| Vulkan0:8080 | `gemma4-31b` | Gemma 4 31B Q6_K with an MTP draft model |
| Vulkan1:8081 | `qwen3.6-35b-a3b` | Qwen3.6 35B-A3B MoE UD-Q5_K_XL, two parallel slots, MTP depth 2 |
| Vulkan1:8081 | `gemma4-26b-a4b` | Gemma 4 26B-A4B MoE UD-Q6_K_XL, two parallel slots, MTP disabled |

The files are independent: instance 0 contains the dense presets, while instance 1 contains only MoE presets and allows two parallel calls. Open WebUI lists only the instance-0 presets; instance 1 remains available to Hindsight and direct OpenAI-compatible API clients. Context is auto-fit to available VRAM (`fit-target = 256` in each file).

### Adding or changing models

**1.** Add the model to `models/list.txt`, using tab-separated columns:

```text
<local-folder>    <huggingface-repo>    <filename-in-repo>    [local-rename]
```

The optional fourth column renames the downloaded file locally. Run `./models/update.sh` to download models without rebuilding, or use the top-level `./update.sh` workflow.

**2.** Add a preset section to `models-0.ini`, `models-1.ini`, or both:

```ini
[my-model@q5]
model = models/<local-folder>/<filename>.gguf
temp = 1.0
top-p = 0.95
repeat-penalty = 1.0
```

- The section name (`my-model@q5`) is the model identifier used in API requests.
- Global settings from `[*]` (GPU layers, flash attention, etc.) are inherited automatically.
- Add sampling params per model, or omit them for agent-facing models (agents send their own).
- Always set `repeat-penalty = 1.0` to explicitly disable it.
- To remove a model, delete its preset section and its row from `models/list.txt`.

## Layout

```
.env                        # Vulkan cmake flags + SERVER_FLAGS
build.sh                    # git pull + rebuild
install.sh                  # first-time setup (deps, clone, systemd service)
run.sh                      # launch Open WebUI + two llama-server instances (Vulkan0:8080, Vulkan1:8081)
update.sh                   # stop, rebuild, update models, start
start.sh / stop.sh          # systemd service control
models-0.ini                # Vulkan0:8080 router presets
models-1.ini                # Vulkan1:8081 router presets
llama.cpp/                  # llama.cpp source + build (cloned by install.sh, gitignored)
models/
  list.txt                  # tab-separated HuggingFace model manifest
  install.sh                 # install the HuggingFace CLI
  update.sh                  # download/update every manifest entry
  <model>/
    *.gguf                   # downloaded model files
benchmark/
  bench.sh                   # llama-bench runner (single GPU, Vulkan) using ../llama.cpp
  bench-mtp.sh                 # MTP speculative-decoding benchmark, drives llama-server directly
  reports/                    # generated benchmark reports
systemd/
  cicero-home-ai.service      # user service template (installed to ~/.config/systemd/user/ by install.sh)
```

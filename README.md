# cicero-home-ai

Home AI server running local LLMs via [llama.cpp](https://github.com/ggml-org/llama.cpp) in router mode. Exposes an OpenAI-compatible API and a chat UI ([Open WebUI](https://github.com/open-webui/open-webui) on port 3000).

## How it works

`llama-server` runs in **router mode** — a built-in multi-model proxy. It routes requests based on the model name in the request; when a model isn't loaded, the router starts a child process for it and proxies the request. With `--models-max 1`, only one model is in VRAM at a time (LRU eviction).

A single instance runs on port 8080, split across both GPUs (`split-mode=layer`), preset from `models.ini`.

**Open WebUI** runs on port 3000, pointed at the llama-server endpoint.

| Script | What it does |
|---|---|
| `install.sh` | Install deps, clone the llama.cpp checkout, install Python tools, install and enable the systemd user service. Run once with `sudo`. |
| `update.sh` | Stop the service, rebuild, update models, and restart the service. |
| `start.sh` | Start the service via `systemctl --user`. |
| `stop.sh` | Stop the service via `systemctl --user`. |
| `run.sh` | Start the full stack (llama-server + Open WebUI) in the foreground. Called by the systemd service. |
| `benchmark/bench.sh` | Run `llama-bench` and save a Markdown report under `benchmark/reports/`. |

## Usage

```bash
./start.sh    # start the service
./stop.sh     # stop the service
./update.sh   # rebuild, update models, restart
./run.sh      # foreground stack
```

## Installation

Configured for an AMD GPU with ROCm. Requires a working ROCm/HIP SDK with `hipconfig` on `PATH`.

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

**`.env`** — ROCm build flags and server flags:

| Variable | Default | Description |
|---|---|---|
| `CMAKE_FLAGS` | `-DGGML_HIP=ON ...` | CMake flags for the llama.cpp build. Adjust `GPU_TARGETS` for your GPU. |
| `SERVER_FLAGS` | `--host 0.0.0.0 --models-max 1` | Flags passed to the `llama-server` instance. |

**`models.ini`** — per-model sampling params and global server flags (`[*]` section).

## Models

Sized to use the full 32 GB VRAM of the AMD R9700 in TTY mode. If running from a desktop session, reduce `fit-target` in `models.ini` to account for the ~2–4 GB consumed by the desktop.

| Preset | Model |
|---|---|
| `qwen3.6-27b` | Qwen3.6 27B Q8_0 with built-in MTP |
| `gemma4-31b` | Gemma 4 31B Q8_0 with an MTP draft model |

Context is auto-fit to available VRAM (`fit-target = 256` in `models.ini`).

### Adding or changing models

**1.** Add the model to `models/list.txt`, using tab-separated columns:

```text
<local-folder>    <huggingface-repo>    <filename-in-repo>    [local-rename]
```

The optional fourth column renames the downloaded file locally. Run `./models/update.sh` to download models without rebuilding, or use the top-level `./update.sh` workflow.

**2.** Add a preset section in `models.ini`:

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
.env                        # ROCm cmake flags + SERVER_FLAGS
build.sh                    # git pull + rebuild
install.sh                  # first-time setup (deps, clone, systemd service)
run.sh                      # launch Open WebUI + llama-server (split-mode=layer, both GPUs, port 8080)
update.sh                   # stop, rebuild, update models, start
start.sh / stop.sh          # systemd service control
models.ini                  # router preset
llama.cpp/                  # llama.cpp source + build (cloned by install.sh, gitignored)
models/
  list.txt                  # tab-separated HuggingFace model manifest
  install.sh                 # install the HuggingFace CLI
  update.sh                  # download/update every manifest entry
  <model>/
    *.gguf                   # downloaded model files
benchmark/
  bench.sh                   # dense-model benchmark runner
  bench-moe.sh                # MoE benchmark runner
  analysis/                   # benchmark analyses
  reports/                    # generated benchmark reports
systemd/
  cicero-home-ai.service      # user service template (installed to ~/.config/systemd/user/ by install.sh)
```

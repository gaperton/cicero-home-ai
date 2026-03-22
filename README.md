# cicero-home-ai

Home AI server running local LLMs via [llama.cpp](https://github.com/ggml-org/llama.cpp), managed by [llama-swap](https://github.com/mostlygeek/llama-swap) for on-demand model switching. Exposes an OpenAI-compatible API for use with agents and chat clients.

## How it works

[llama-swap](https://github.com/mostlygeek/llama-swap) acts as a proxy in front of `llama-server`. It listens on port 8080 and routes requests to the appropriate model based on the model name in the request. When a request comes in for a model that isn't loaded, llama-swap stops the current `llama-server` instance, starts a new one with the requested model, and proxies the request — so only one model is in VRAM at a time.

Models and their server flags are defined in `config.yaml`.

## Models

Picked to run in TTY (no desktop environment), using the full 32GB VRAM of the AMD R9700. Context sizes are set to the maximum that fits. If running from a desktop session, reduce `--ctx-size` to ~150,000 to account for the ~2–4 GB of VRAM consumed by the UI — though note that inference quality degrades beyond 150–200K context anyway due to attention limitations of current models.

| Preset | Model | Context |
|---|---|---|
| `qwen3.5-27b@q5-200k` | Qwen3.5 27B UD-Q5_K_XL | 200k |
| `qwen3.5-35b-a3b@q5-262k` | Qwen3.5 35B-A3B UD-Q5_K_XL | 262k |
| `glm4.7-flash@q5` | GLM-4.7 Flash UD-Q5_K_XL | — |

Default sampling params follow official model card recommendations for the general use. llama.cpp flags are taken as suggested by Sudo Su (@SudoingX).

## Scripts

| Script | What it does |
|---|---|
| `install.sh` | Installs system dependencies, clones llama.cpp, builds it with the GPU backend from `.env`, installs the `hf` CLI. Run once with `sudo`. |
| `update.sh` | Pulls latest llama.cpp source, rebuilds incrementally, downloads updated model files from HuggingFace (skips unchanged files). |
| `run.sh` | Runs `update.sh`, then starts `llama-swap` with `config.yaml`. |
| `run-tmux.sh` | Runs `run.sh` in a tmux session with `mc` file manager in the right pane. The recommended way to run the server. |

## Installation

By default, it is configured for AMD, to be run with Vulkan using default drivers coming with Linux HWE kernels.

1. Install Linux Mint Cinnamon (or Ubuntu, or other Linux of your choice; we assume Mint/Ubuntu)
2. Clone this repo and `cd` into it
3. Run first-time setup:
   ```bash
   sudo ./install.sh
   ```
4. Authenticate with HuggingFace (needed to download models):
   ```bash
   hf auth login
   ```
5. Edit `.env` if needed (default is Vulkan; change `CMAKE_GPU_FLAG` for CUDA or ROCm)
6. Download models and build llama.cpp:
   ```bash
   ./update.sh
   ```
   Downloads all models (~70 GB) and builds llama.cpp.
7. Start the server:
   ```bash
   ./run.sh
   ```

## Booting into TTY and auto-starting the server

Running in TTY (without a desktop environment) frees up ~2–4 GB of VRAM. To add a dedicated GRUB entry that boots straight to TTY and auto-starts the server:

**1. Add a custom GRUB entry**

Append to `/etc/grub.d/40_custom`:

Copy the existing `linux` and `initrd` lines from your normal Mint entry in `/boot/grub/grub.cfg`, then append `systemd.unit=multi-user.target`:

```bash
menuentry "cicero-home-ai (TTY)" {
    search --no-floppy --fs-uuid --set=root <your-root-uuid>
    linux   /boot/vmlinuz-... root=UUID=<your-root-uuid> ro quiet splash systemd.unit=multi-user.target
    initrd  /boot/initrd.img-...
}
```

Then regenerate GRUB:

```bash
sudo update-grub
```

> Get your root UUID with `lsblk -o NAME,UUID`. Copy the exact `linux`/`initrd` lines from the working Mint entry in `/boot/grub/grub.cfg` — just add `systemd.unit=multi-user.target` at the end of the `linux` line.

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

On next boot, selecting the GRUB entry will drop into TTY1, log in automatically, and launch the tmux session with the server running.

## Layout

```
.env                        # local config (CMAKE_GPU_FLAG)
config.yaml                 # llama-swap config (models, macros)
models/
  presets.ini               # model presets (sampling params, ctx size, etc.)
  *.gguf                    # model files (downloaded from unsloth HF repos)
llama.cpp/                  # cloned source + built binaries
```
# cicero-home-ai

Home AI server running local LLMs via [llama.cpp](https://github.com/ggml-org/llama.cpp), managed by [llama-swap](https://github.com/mostlygeek/llama-swap) for on-demand model switching. Exposes an OpenAI-compatible API for use with agents and chat clients.

## How it works

[llama-swap](https://github.com/mostlygeek/llama-swap) acts as a proxy in front of `llama-server`. It listens on port 8080 and routes requests to the appropriate model based on the model name in the request. When a request comes in for a model that isn't loaded, llama-swap stops the current `llama-server` instance, starts a new one with the requested model, and proxies the request — so only one model is in VRAM at a time.

Model server flags and sampling parameters are defined as macros in `config.yaml`.

| Script | What it does |
|---|---|
| `install.sh` | Installs system dependencies, clones llama.cpp, builds it with the GPU backend from `.env`, installs the `hf` CLI. Run once with `sudo`. |
| `update.sh` | Pulls latest llama.cpp source, rebuilds incrementally, downloads updated model files from HuggingFace (skips unchanged files). |
| `run.sh` | Runs `update.sh`, then starts `llama-swap` with `config.yaml`. |
| `run-tmux.sh` | Runs `run.sh` in a tmux session with `mc` file manager in the right pane. The recommended way to run the server. |

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
6. Build llama.cpp and download all models (~70 GB):
   ```bash
   ./update.sh
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

All runtime settings live in `.env`:

| Variable | Default | Description |
|---|---|---|
| `CMAKE_GPU_FLAG` | `-DGGML_VULKAN=ON` | GPU backend for llama.cpp build. Use `-DGGML_CUDA=ON` for CUDA or `-DGGML_HIP=ON` for ROCm. |
| `CTX_QUANT` | `f16` | KV cache quantization. `f16` is the llama.cpp default; `q8_0` or `q4_0` reduce VRAM at some quality cost. |
| `VRAM_BUFFER` | `256` | VRAM safety margin in MiB passed to `-fitt`. llama.cpp auto-fits context size to leave this much free. |

## Models

Sized to use the full 32GB VRAM of the AMD R9700 in TTY mode. If running from a desktop session, reduce `--ctx-size` to ~150,000 to account for the ~2–4 GB consumed by the UI — though inference quality degrades beyond 150–200K context anyway due to attention limitations of current models.

| Preset | Model |
|---|---|
| `qwen3.5-27b@q5-200k` | Qwen3.5 27B UD-Q5_K_XL |
| `qwen3.5-35b-a3b@q5-262k` | Qwen3.5 35B-A3B UD-Q5_K_XL |
| `glm4.7-flash@q5` | GLM-4.7 Flash UD-Q5_K_XL |

Context size is auto-fit by llama.cpp to available VRAM (controlled by `VRAM_BUFFER` in `.env`).

Default sampling params follow official model card recommendations. llama.cpp flags are taken as suggested by Sudo Su (@SudoingX).

## Layout

```
.env                        # local config (CMAKE_GPU_FLAG, CTX_QUANT, VRAM_BUFFER)
config.yaml                 # llama-swap config (models, sampling params, server flags)
models/
  *.gguf                    # model files (downloaded from unsloth HF repos)
llama.cpp/                  # cloned source + built binaries
```
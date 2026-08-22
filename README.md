# cicero-home-ai

Home AI server running local LLMs via [llama.cpp](https://github.com/ggml-org/llama.cpp) in router mode. Exposes an OpenAI-compatible API and a chat UI ([Open WebUI](https://github.com/open-webui/open-webui) on port 3000).

## How it works

`llama-server` runs in **router mode** — a built-in multi-model proxy. It routes requests based on the model name in the request; when a model isn't loaded, the router starts a child process for it and proxies the request. `--models-max` is hardcoded in each `gpu-N/run.sh` (1 on gpu-0, 2 on gpu-1); it cannot be set inside a preset, because the router reads it before presets load.

The host runs the **combined topology**: one router (`cicero-vulkan1.service`, `gpu-0-1/run.sh`) owns both cards and serves port 8081 with all three models resident — `qwen3.8-27b` on ROCm0, `llm` and `reranker` on ROCm1. Open WebUI is a separate unit (`cicero-vulkan0.service`, `gpu-0-1/webui.sh`) on port 3000, pointed at that same router, so its model list now includes `llm` and `reranker` alongside the chat model. Hindsight is untouched by the change: `llm`/`reranker` keep their ids and their port. Each model is still pinned to a single card — no layer-split — but placement lives in the preset's `device =` keys rather than on the command line. The `cicero-vulkan{0,1}` unit names and `logs/vulkan{0,1}.log` are historical, predating both the ROCm move and this one, and are kept so installed units and `./switch` keep working.

**Open WebUI** runs on port 3000 against the combined router on port 8081, which Hindsight and direct API clients also use. The raw llama.cpp API is reachable on the LAN as `http://cicero.local:8081/v1`.

| Script | What it does |
|---|---|
| `install.sh` | Install deps, clone the llama.cpp checkout, install Python tools, install and enable the systemd user service. Run once with `sudo`. |
| `update.sh` | Stop the service, rebuild, update models, and restart the service. |
| `start.sh` | Start the service via `systemctl --user`. |
| `stop.sh` | Stop the service via `systemctl --user`. |
| `gpu-0-1/run.sh` | Start the combined router (both cards, port 8081) in the foreground. Called by `cicero-vulkan1.service`. |
| `gpu-0-1/webui.sh` | Start Open WebUI alone on port 3000, pointed at :8081. Called by `cicero-vulkan0.service`. |
| `gpu-N/run.sh` | Dormant single-card runners, kept for reverting to one-router-per-card. |
| `switch gpu-0-1 <preset>` | Point the router at a preset and restart it. No args = status. |
| `benchmark/bench.sh` | Run `llama-bench` (single GPU, ROCm) and save a Markdown report under `benchmark/reports/`. |
| `benchmark/bench-mtp.sh` | Boot `llama-server` per model/quant and measure MTP speculative-decoding speedup. |

## Usage

```bash
./start.sh    # start the service
./stop.sh     # stop the service
./update.sh   # rebuild, update models, restart
./gpu-0-1/run.sh   # foreground: combined router, both cards, :8081
./gpu-0-1/webui.sh # foreground: Open WebUI only, :3000
```

## Installation

Configured for AMD GPUs using the **ROCm/HIP backend** (`-DGGML_HIP=ON`, `GPU_TARGETS=gfx1201`).
The ROCm SDK must be installed first, from AMD's own apt repo — it is not in the Ubuntu archive,
and `install.sh` checks for `/opt/rocm` and stops if it is missing rather than failing later in the build.

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

The systemd services run `gpu-0/run.sh` and `gpu-1/run.sh`. Build and server flags live in `.env`; see [Configuration](#configuration).

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
systemctl --user status cicero-vulkan0.service cicero-vulkan1.service
journalctl --user -u cicero-vulkan1.service -f
tail -f logs/vulkan0.log logs/vulkan1.log
```

## Configuration

**`.env`** — ROCm build flags, HIP toolchain env and server flags:

| Variable | Default | Description |
|---|---|---|
| `CMAKE_FLAGS` | `-DGGML_HIP=ON -DGPU_TARGETS=gfx1201 -DGGML_NATIVE=1 ...` | CMake flags for the llama.cpp build. |
| `ROCM_PATH` / `HIP_PATH` / `HIPCXX` | `/opt/rocm`, `/opt/rocm`, `/opt/rocm/llvm/bin/clang++` | HIP toolchain, exported so cmake's `enable_language(HIP)` finds ROCm's clang. |
| `SERVER_FLAGS` | `--host 0.0.0.0 --models-max 1` | Flags passed to each `llama-server` instance. |

**`gpu-0/` / `gpu-1/`** — each GPU owns its presets, its `active.ini` symlink and its systemd unit. `model =` paths inside a preset stay relative to the repo root, because each `run.sh` cds there before launching. Each instance is pinned to one GPU on the CLI (see `gpu-N/run.sh`), so presets must fit a single 32GB card — no `split-mode=layer`.

## Models

Each preset must fit a single 32 GB card, since instances are pinned one-per-GPU (no `split-mode=layer`). Sized for TTY mode; if running from a desktop session, reduce `fit-target` in the corresponding preset to account for the ~2–4 GB consumed by the desktop.

| Router | Model id | Model |
|---|---|---|
| ROCm0 (:8081) | `qwen3.8-27b` | Qwen3.8 27B UD-Q6_K with built-in MTP, 2 slots, context autofit (117248/slot measured) |
| ROCm1 (:8081) | `llm` | GPT-OSS 20B UD-Q8_K_XL, 2 slots, 262144 total = 131072/slot |
| ROCm1 (:8081) | `reranker` | Qwen3-Reranker 0.6B Q8_0, 8 slots, kv-unified 32768, `/v1/rerank` for Hindsight |

Dormant single-card presets remain in `gpu-0/` (`default.ini`: `qwen3.8-27b`, `gemma4-31b`) and `gpu-1/` (`oss.ini`, `gemma.ini`, `qwen.ini`, `answers.ini`, `judge.ini`).

The files are independent: instance 0 contains the dense presets, while instance 1 contains the Hindsight-oriented MoE presets and GPU reranker. The instance-1 router allows two resident models; the normal pair is `gemma4-26b-a4b` plus `qwen3-reranker-0.6b`. Open WebUI lists only the instance-0 presets; instance 1 remains available to Hindsight and direct API clients. Context is auto-fit to available VRAM (`fit-target = 256` in each file).

Hindsight uses its `litellm` reranker provider with API base `http://127.0.0.1:8081/v1`, which maps directly to llama.cpp's `/v1/rerank`; no adapter is required. See [HINDSIGHT.md](HINDSIGHT.md) for the persistent environment settings, benchmark results, verification, and CPU rollback procedure.

### Adding or changing models

**1.** Add the model to `models/list.txt`, using tab-separated columns:

```text
<local-folder>    <huggingface-repo>    <filename-in-repo>    [local-rename]
```

The optional fourth column renames the downloaded file locally. Run `./models/update.sh` to download models without rebuilding, or use the top-level `./update.sh` workflow.

**2.** Add a preset section to a `gpu-0/` or `gpu-1/` preset:

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
.env                        # ROCm cmake flags + HIP toolchain env + SERVER_FLAGS
build.sh                    # git pull + rebuild
install.sh                  # first-time setup (deps, clone, systemd service)
switch                      # ./switch gpu-1 qwen — repoint a GPU and restart only its service
update.sh                   # stop, rebuild, update models, start
start.sh / stop.sh          # systemd service control
gpu-0-1/                    # ACTIVE — one router, both cards, :8081
  combined.ini              #   qwen3.8-27b on ROCm0, llm + reranker on ROCm1
  active.ini                #   symlink to the active preset
  run.sh                    #   llama-server, --models-max 3, no --device
  webui.sh                  #   Open WebUI only, :3000 -> :8081
gpu-0/                      # dormant single-card preset
  default.ini               #   chat models + batch-* judge/answer models
  active.ini                #   symlink to the active preset
  run.sh                    #   Open WebUI + llama-server ROCm0:8080
  cicero-vulkan0.service    #   user unit — now runs gpu-0-1/webui.sh
gpu-1/                      # dormant single-card presets
  {oss,gemma,qwen}.ini      #   Hindsight profiles
  active.ini                #   symlink to the active preset
  run.sh                    #   llama-server ROCm1:8081
  cicero-vulkan1.service    #   user unit — now runs gpu-0-1/run.sh
llama.cpp/                  # llama.cpp source + build (cloned by install.sh, gitignored)
models/
  list.txt                  # tab-separated HuggingFace model manifest
  install.sh                 # install the HuggingFace CLI
  update.sh                  # download/update every manifest entry
  <model>/
    *.gguf                   # downloaded model files
benchmark/
  bench.sh                   # llama-bench runner (single GPU, ROCm) using ../llama.cpp
  bench-mtp.sh                 # MTP speculative-decoding benchmark, drives llama-server directly
  reports/                    # generated benchmark reports
systemd/
```

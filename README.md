# cicero-home-ai

Home AI server running local LLMs via [llama.cpp](https://github.com/ggml-org/llama.cpp) in router mode. Exposes an OpenAI-compatible API, a chat UI ([Open WebUI](https://github.com/open-webui/open-webui) on port 3000), and the Hindsight Control Plane on port 9999.

## How it works

`llama-server` runs in **router mode** — a built-in multi-model proxy. It routes requests based on the requested model name, starting a model process when needed. `gpu-0-1/run.sh` sets `--models-max 3`; this startup-only option cannot live in the preset.

The host has one combined topology in `gpu-0-1/`. One systemd user unit, `cicero-home-ai.service`, supervises Open WebUI and the router together. The router owns both ROCm cards, serves all three resident models on port 8080, and uses per-model placement from `combined.ini`. Open WebUI listens on port 3000 and points at that router.

**Open WebUI** runs on port 3000 against the combined router on port 8080, which Hindsight and direct API clients also use. The raw llama.cpp API is reachable on the LAN as `http://cicero.local:8080/v1`.

| Script | What it does |
|---|---|
| `install.sh` | Install deps, clone the llama.cpp checkout, install Python tools, install and enable the systemd user service. Run once with `sudo`. |
| `update.sh` | Sync the user unit, stop the service, rebuild, update models, and restart. |
| `hindsight/update.sh` | Back up PostgreSQL, upgrade Hindsight and its matching Control Plane, then verify both services. |
| `start.sh` | Start the service via `systemctl --user`. |
| `stop.sh` | Stop the service via `systemctl --user`. |
| `gpu-0-1/run.sh` | Start Open WebUI and the combined router in the foreground. Called by `cicero-home-ai.service`. |
| `switch gpu-0-1 <preset>` | Point the router at a preset and restart it. No args = status. |
| `benchmark/bench.sh` | Run `llama-bench` (single GPU, ROCm) and save a Markdown report under `benchmark/reports/`. |
| `hindsight/benchmark/bench-mtp.sh` | Boot `llama-server` per model/quant and measure MTP speculative-decoding speedup on the Hindsight workload. |

## Usage

```bash
./start.sh    # start the service
./stop.sh     # stop the service
./update.sh   # rebuild, update models, restart
./gpu-0-1/run.sh   # foreground: Open WebUI :3000 + router :8080
```

## Hindsight

Hindsight is managed separately from the llama.cpp stack; the top-level
`install.sh` does not install its API or Control Plane. For an existing Hindsight
API installation, install the persistent Web UI and apply future upgrades with:

```bash
./hindsight/ui/install.sh
./hindsight/update.sh           # latest matching API + Control Plane
./hindsight/update.sh 0.9.1     # explicit version
```

See [`hindsight/README.md`](hindsight/README.md) for service configuration,
access, verification, rollback, and benchmark details.

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

The `cicero-home-ai.service` user unit runs `gpu-0-1/run.sh`. Build and server flags live in `.env`; see [Configuration](#configuration).

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
tail -f logs/gpu-0-1.log
```

## Configuration

**`.env`** — ROCm build flags, HIP toolchain env and server flags:

| Variable | Default | Description |
|---|---|---|
| `CMAKE_FLAGS` | `-DGGML_HIP=ON -DGPU_TARGETS=gfx1201 -DGGML_NATIVE=1 ...` | CMake flags for the llama.cpp build. |
| `ROCM_PATH` / `HIP_PATH` / `HIPCXX` | `/opt/rocm`, `/opt/rocm`, `/opt/rocm/llvm/bin/clang++` | HIP toolchain, exported so cmake's `enable_language(HIP)` finds ROCm's clang. |
| `SERVER_FLAGS` | `--host 0.0.0.0 --models-max 1` | Base flags passed to `llama-server`; `run.sh` overrides `--models-max` to 3. |

**`gpu-0-1/`** owns the preset, its `active.ini` symlink, the runner, and the service unit. `model =` paths inside the preset stay relative to the repo root because `run.sh` changes there before launching. Device and split settings belong in each model section; do not pass a global `--device`, which would override them.

## Models

The active preset is sized for two 32 GB cards in TTY mode. Running a desktop consumes roughly 2–4 GB of VRAM and may require smaller contexts.

| Router | Model id | Model |
|---|---|---|
| ROCm0+ROCm1 (:8080) | `qwen3.8-27b` | Qwen3.8 27B UD-Q5_K_M with built-in MTP, tensor split, 2 × 196608-token slots |
| ROCm0+ROCm1 (:8080) | `llm` | GPT-OSS 20B UD-Q8_K_XL, 38/62 tensor split, 2 × 131072-token slots |
| ROCm0 (:8080) | `reranker` | Qwen3-Reranker 0.6B Q8_0, one 4096-token slot, `/v1/rerank` for Hindsight |

Hindsight uses its `litellm` reranker provider with API base `http://127.0.0.1:8080/v1`, which maps directly to llama.cpp's `/v1/rerank`; no adapter is required. All repository-owned Hindsight service files, prompts, experiments, and workload benchmarks live under [`hindsight/`](hindsight/README.md).

### Adding or changing models

**1.** Add the model to `models/list.txt`, using tab-separated columns:

```text
<local-folder>    <huggingface-repo>    <filename-in-repo>    [local-rename]
```

The optional fourth column renames the downloaded file locally. Run `./models/update.sh` to download models without rebuilding, or use the top-level `./update.sh` workflow.

**2.** Add a preset section to `gpu-0-1/combined.ini`:

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
switch                      # select/reload the combined preset and show status
update.sh                   # stop, rebuild, update models, start
start.sh / stop.sh          # systemd service control
gpu-0-1/                    # the only GPU/service folder
  combined.ini              #   tensor-split chat + LLM, reranker on ROCm0
  active.ini                #   symlink to the active preset
  run.sh                    #   Open WebUI :3000 + llama-server :8080
  install-service.sh        #   install/update the unit; retire legacy units
  cicero-home-ai.service    #   the single systemd user unit
llama.cpp/                  # llama.cpp source + build (cloned by install.sh, gitignored)
models/
  list.txt                  # tab-separated HuggingFace model manifest
  install.sh                 # install the HuggingFace CLI
  update.sh                  # download/update every manifest entry
  <model>/
    *.gguf                   # downloaded model files
benchmark/
  bench.sh                   # llama-bench runner (single GPU, ROCm) using ../llama.cpp
  bench-split.sh             # compare one-card, layer-split, and tensor-split layouts
  reports/                   # generated generic benchmark reports
hindsight/
  README.md                  # current deployment and operational commands
  update.sh                  # backup + upgrade API and matching Control Plane
  ui/
    install.sh               # install the Control Plane and enable its user unit
    hindsight-ui.service     # persistent Hindsight Web UI on :9999
  benchmark/                 # Hindsight workload, concurrency, and end-to-end benchmarks
  templates/                 # Retain, Consolidate, and gpt-oss prompt templates
  experiments/               # dated investigations, measurements, and incidents
```

# cicero-home-ai

A home AI server on two AMD Radeon AI PRO R9700 cards (gfx1201, 32 GB each,
121 GB host RAM). It runs one model, **Qwen3.8-Flash-Next**, on the
[radiance](https://codeberg.org/StillDeadcode/radiance) inference engine.

| Service | Address | Unit |
|---|---|---|
| OpenAI-compatible API | `http://cicero.local:8080/v1`, model `qwen3.8-flash-next` | `cicero-rad.service` |
| Open WebUI (chat) | `http://cicero.local:3000` | `cicero-rad.service` |
| Hindsight memory API / Control Plane | `:8888` / `:9999` | `hindsight.service`, `hindsight-ui.service` — see [`hindsight/`](hindsight/README.md) |
| GPU power cap, 250 W per card | — | `cicero-gpu-power.service` (system) |

## How it works

`cicero-rad.service` (systemd user unit) runs `rad/run.sh`. That script starts
Open WebUI and the radiance container (`docker compose`, `rad/compose.yaml`) in
the foreground and exits as soon as either dies, so systemd restarts the
whole stack. Both write to `logs/rad.log`.

radiance serves the 114 GiB model container
`qwen3.8-next-flash-fp8-iq4r-moe.rad` (4-bit experts, int8 trunk, MTP head,
vision tower) tensor-parallel across both cards:

- **VRAM** — both cards are filled to ~99%: ~4 GiB of fixed weights, ~18 GiB
  of experts and ~7.6 GiB of KV cache per card. Nothing else GPU-bound can run
  next to it.
- **Host RAM** — experts that do not fit VRAM stream from a pinned 12 GiB pool
  per card, and the 47.7 GiB n-gram table sits in pinned RAM. Expect ~85 GB of
  RAM in use while serving.
- **Context and concurrency** — 262,144 tokens per request, 8 sequences at once,
  FP8 KV cache. The pool holds ~3.7 full-length sessions; beyond that the
  scheduler preempts.
- **Speculative decoding** — the model's MTP head drafts 3 tokens per step.
- **Prefix cache** — finished conversations' KV moves to host RAM (4 GiB) and
  then to disk (128 GiB in `rad/state/kvcache/`), so a returning conversation
  skips its prefill.

Measured on 1.2.3 with `rad/bench-openai.py`:

| | 1 stream | 2 | 4 | 8 |
|---|---:|---:|---:|---:|
| decode, aggregate tok/s | 117 | 212 | 316 | 448 |
| decode, per request tok/s | 121 | 109 | 91 | 64 |

Prefill runs at 3.6–4.2K tok/s (4K–56K-token prompts); 15 of 15 tool-call
probes returned well-formed calls.

## Using the API

Point any OpenAI-compatible client at `http://cicero.local:8080/v1`. No API key.

- **Endpoints:** `/v1/chat/completions` and `/v1/completions`, streaming or not,
  with tool calls and image or video input (images are resized to at most
  4.2 MP). There is no `/v1/responses`, no Anthropic `/v1/messages`, and no
  `/v1/embeddings`.
- **Model id:** chat and completion requests are served whatever `model` they
  name, but `GET /v1/models/<id>` returns 404 for anything other than
  `qwen3.8-flash-next`, so a client that checks the model first needs that id.
- **Unknown parameters are refused, not ignored.** A field the server does not
  implement returns HTTP 400. The common case is an OpenAI `reasoning` object;
  send `reasoning_effort` instead, one of `none`, `minimal`, `low`, `medium`,
  `xhigh` (`high` and `max` are refused).
- Thinking is on by default. Turn it off per request with
  `"chat_template_kwargs": {"enable_thinking": false}`.

## Installation

1. Install Ubuntu or Linux Mint with the amdgpu driver and `amd-smi` (from
   AMD's ROCm repo, https://repo.radeon.com). The engine's ROCm userspace ships
   inside the radiance image; the host needs no ROCm SDK.
2. Clone this repo and `cd` into it.
3. Run first-time setup. It installs Docker, adds you to the `docker` group,
   installs the `hf` CLI and Open WebUI with pipx, installs the GPU power cap,
   enables lingering, and installs and enables `cicero-rad.service`:
   ```bash
   sudo ./install.sh
   ```
4. Reload your shell, then pull the image, download the model (~114 GiB into
   `models/rad/`) and start the stack:
   ```bash
   source ~/.bashrc
   ./update.sh
   ```

Hindsight is installed separately; see [`hindsight/README.md`](hindsight/README.md).

## Operation

```bash
./start.sh                    # systemctl --user start cicero-rad.service
./stop.sh                     # systemctl --user stop cicero-rad.service
./update.sh                   # re-pull the pinned image, sync the unit, restart
./update.sh 1.2.4             # move the pin to another radiance release, then the same
tail -f logs/rad.log          # engine + Open WebUI log
systemctl --user status cicero-rad.service
curl -fsS http://127.0.0.1:8080/v1/models
./rad/bench-openai.py --label rad-1.2.3   # benchmark; results append to bench-results.jsonl
```

Startup takes a few minutes: the engine loads the model and copies the n-gram
table into pinned RAM before `server: listening` appears in the log. Read the
`placement:` and `VRAM budget` lines there to see where each part of the model
landed.

radiance releases land several times a day, so the image tag is pinned in
`rad/config.env` and changes only through `./update.sh <tag>`. Re-run
`rad/bench-openai.py` after a bump and compare it with the table above. Stop
other clients first: Open WebUI and Hindsight share `:8080`.

## Configuration

| File | Holds |
|---|---|
| `rad/config.env` | Image tag, model file and its Hugging Face repo, served model id, host/port, expert host pool per card |
| `rad/compose.yaml` | Engine flags: TP, sequences, context, placement, KV dtype, prefix-cache tiers, speculative tokens. The parser takes `--flag value`, not `--flag=value` |
| `rad/cicero-rad.service` | The user unit; `rad/install-service.sh` installs it (paths are rewritten to the repo's location) |
| `gpu-power/cicero-gpu-power.service` | `GPU_POWER_CAP_W` (210–300). Re-run `sudo gpu-power/install.sh` after editing |

`HOST_POOL_MIB` trades RAM for VRAM: experts the pool cannot hold take card
memory away from the KV cache.

`rad/state/kvcache/` holds conversation KV on disk, unencrypted.

## Booting into TTY

The model needs nearly all VRAM on both cards, so the machine boots without a
desktop. `install.sh` enables lingering, so `cicero-rad.service` starts at
boot without a login.

**1. Add a GRUB entry.** Copy the `linux` and `initrd` lines from your existing
entry in `/boot/grub/grub.cfg`, append `systemd.unit=multi-user.target` to the
`linux` line, and save to `/etc/grub.d/40_custom`:

```bash
menuentry "cicero-home-ai (TTY)" {
    search --no-floppy --fs-uuid --set=root <your-root-uuid>
    linux   /boot/vmlinuz-... root=UUID=<your-root-uuid> ro quiet splash systemd.unit=multi-user.target
    initrd  /boot/initrd.img-...
}
```

Get the UUID with `lsblk -o NAME,UUID`, then run `sudo update-grub`.

**2. Autologin on TTY1 (optional):**

```bash
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
```

## Layout

```
install.sh                  # first-time setup (sudo)
update.sh                   # pull image, fetch model if missing, sync unit, restart
start.sh / stop.sh          # systemd service control
rad/
  config.env                #   all settings: image pin, model, port, host pool
  compose.yaml              #   radiance engine flags
  run.sh                    #   Open WebUI :3000 + radiance :8080, foreground
  cicero-rad.service        #   the systemd user unit
  install-service.sh        #   install/enable the unit; retire legacy units
  bench-openai.py           #   decode / prefill / mixed / tool-call benchmark
  state/                    #   prefix-cache disk tier (gitignored)
gpu-power/                  # boot-time GPU power cap (system unit, root)
models/rad/                 # the .rad model container (gitignored)
hindsight/                  # Hindsight memory server: docs, updater, UI unit, benchmark, history
logs/                       # rad.log (gitignored)
```

Earlier llama.cpp and vLLM deployments were removed from the tree; their
measurements remain in [`hindsight/experiments/`](hindsight/experiments/README.md),
and their scripts are in git history.

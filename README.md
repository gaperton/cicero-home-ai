# cicero-home-ai

A home AI server on two AMD Radeon AI PRO R9700 cards (gfx1201, 32 GB each,
121 GB host RAM). It runs one model at a time on the
[radiance](https://codeberg.org/StillDeadcode/radiance) inference engine:
**Qwen3.8-Flash-Next** or **Qwen3.8-27B**. See
[Switching models](#switching-models).

| Service | Address | Unit |
|---|---|---|
| OpenAI-compatible API | `http://cicero.local:8080/v1`, model `qwen-local` | `cicero-rad.service` |
| Open WebUI (chat) | `http://cicero.local:3000` | `cicero-rad.service` |
| Hindsight memory API / Control Plane | `:8888` / `:9999` | `hindsight.service`, `hindsight-ui.service` — see [`hindsight/`](hindsight/README.md) |
| GPU power cap, 250 W per card | — | `cicero-gpu-power.service` (system) |

## How it works

`cicero-rad.service` (systemd user unit) runs `rad/run.sh`. That script starts
Open WebUI and the radiance container (`docker compose`, `rad/compose.yaml`) in
the foreground and exits as soon as either dies, so systemd restarts the
whole stack. Both write to `logs/rad.log`.

With the `flashnext` profile, radiance serves the 113.3 GiB model container
`qwen3.8-next-flash-iqr-v4.rad` (IQR-V4 4-bit experts, int8 trunk, MTP head,
vision tower) tensor-parallel across both cards:

- **VRAM** — both cards are filled to ~99%: ~3.2 GiB of fixed weights, ~17.3 GiB
  of experts and ~9.0 GiB of KV cache per card. Nothing else GPU-bound can run
  next to it.
- **Host RAM** — experts that do not fit VRAM stream from a pinned 12 GiB pool
  per card; the 47.7 GiB n-gram table and the token embedding sit in pinned RAM.
  With the prefix cache's host tier and snapshot store below, ~102 GiB is
  pinned and ~112 GB of RAM is in use while serving, leaving ~8 GB.
- **Context and concurrency** — 262,144 tokens per request, 8 sequences at once,
  int8 KV cache. The pool holds ~4.4 full-length sessions; beyond that the
  scheduler preempts.
- **Speculative decoding** — the model's MTP head drafts 3 tokens per step.
- **Refusals** — upstream's bundled refusal-projection control vector is loaded
  but off: `qwen-local` is the stock model, and a request that sends
  `"control_vector": true` gets refusals projected out. Open WebUI shows that as
  a second model, `qwen-local-uncensored`. It replaces the abliterated
  `flashnext-uncensored` container, which has no build radiance 2.0 can load.
- **Prefix cache** — finished conversations' KV moves from VRAM to a 16 GiB
  pinned host-RAM tier (~1.14M tokens), so a returning conversation skips its
  prefill. Flash-Next's linear layers also need a saved state snapshot to
  resume from; 120 snapshot slots (13.2 GiB of pinned RAM) are shared by all
  stored conversations. The 8 GiB / 80-slot defaults ran full under an agent
  with many subtask sessions. Nothing
  is written to disk; a restart loses the cache.

Full runs with `rad/bench-openai.py`, driver 31.60. 2.0.0 serves the IQR-V4
container (2026-11-15, right after the switch); 1.17.0 and 1.15.0 served the
FP8 `flashnext-uncensored` container (1.17.0 on 2026-11-15 after three days'
uptime, 1.15.0 on 2026-10-31):

| | 1 stream | 2 | 4 | 8 |
|---|---:|---:|---:|---:|
| decode, aggregate tok/s, 2.0.0 | 165 | 254 | 327 | 483 |
| decode, per request tok/s, 2.0.0 | 168 | 132 | 99 | 71 |
| decode, aggregate tok/s, 1.17.0 | 132 | 201 | 296 | 458 |
| decode, aggregate tok/s, 1.15.0 | 131 | 219 | 310 | 476 |

On 2.0.0 prefill runs at 5.1–5.3K tok/s on 4K–53K-token prompts (1.17.0:
4.72–4.77K). A 25K prefill fired during a decode stream finishes in 6.5–6.8 s
while that stream keeps 116–139 tok/s (1.17.0: 6.6 s at 63 tok/s). 15 of 15
tool-call probes returned well-formed calls. The quick run (`--conc 1,4 --reps 4
--prefill 16384`) gave 161/340 aggregate tok/s at 1/4 streams and 5.25K tok/s
prefill, against 148/301 and 4.85K on 1.17.0. Decode is sampled at temperature
1.0, so MTP acceptance and per-prompt speed vary from run to run; the full run's
three repetitions skip the fast `reason` prompt, so its single-stream median
reads lower than the quick run's. Earlier quick runs: 1.15.0 150/335 and 4.72K,
1.13.0 155/324 and 4.66K, 1.10.0 139/327 and 4.42K, 1.4.0 143/308 and 4.58K.

## Using the API

Point any OpenAI-compatible client at `http://cicero.local:8080/v1`. No API key.

- **Endpoints:** `/v1/chat/completions` and `/v1/completions`, streaming or not,
  with tool calls and image or video input (images are resized to at most
  4.2 MP). Since 1.3.0 the server also speaks OpenAI's `/v1/responses`,
  Anthropic's `/v1/messages` and llama-server's `/completion`, `/infill` and
  `/props`, with logprobs. `/v1/embeddings` is for embedding models only, so it
  is not available here.
- **Model id:** a request must name `qwen-local` or the profile's alias
  (`qwen3.8-flash-next` or `qwen3.8-27b`); any other name gets 404 (radiance 1.x
  served any name). A request without `model` goes to the loaded model. Every
  profile uses this id; `GET /v1/models` shows which is loaded in `root` (the
  `.rad` file) along with `max_model_len` and `state`. `root` is shown only to
  callers on this machine.
- **Unknown parameters are ignored silently** (since 1.4.0; earlier releases
  refused them with HTTP 400), so a misspelled field has no effect and no
  error. An OpenAI `reasoning` object is accepted. `reasoning_effort` takes
  `none`, `minimal`, `low`, `medium` or `xhigh`; `high` and `max` are refused.
- Thinking is on by default. Turn it off per request with
  `"chat_template_kwargs": {"enable_thinking": false}`.

## Installation

1. Install Ubuntu or Linux Mint with the amdgpu driver and `amd-smi` (from
   AMD's ROCm repo, https://repo.radeon.com). The engine's ROCm userspace ships
   inside the radiance image; the host needs no ROCm SDK, but its driver must
   support the image's ROCm (10.1 since radiance 1.4.0: driver 31.50 or newer).
   Turn on Resizable BAR (Above 4G Decoding) in the firmware setup; radiance
   refuses to start without it.
2. Clone this repo and `cd` into it.
3. Run first-time setup. It installs Docker, adds you to the `docker` group,
   installs the `hf` CLI and Open WebUI with pipx, installs the GPU power cap,
   enables lingering, and installs and enables `cicero-rad.service`:
   ```bash
   sudo ./install.sh
   ```
4. Reload your shell, then pull the image, download the model (~113 GiB into
   `models/radiance_v2/`) and start the stack:
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
./switch.sh                   # list model profiles; ./switch.sh <profile> to change
tail -f logs/rad.log          # engine + Open WebUI log
systemctl --user status cicero-rad.service
curl -fsS http://127.0.0.1:8080/v1/models
curl -fsS http://127.0.0.1:8080/health   # the process and each model's state
./rad/bench-openai.py --label flashnext-rad-2.0.0   # benchmark; results append to bench-results.jsonl
```

Flash-Next was ready 30 s after a restart with the file in the page cache: the
engine loads the model and copies the n-gram table into pinned RAM before
`model qwen-local: ready` appears in the log. Read the `placement:` and `VRAM
budget` lines there to see where each part of the model landed.

radiance releases land several times a day, so the image tag is pinned in
`rad/config.env` and changes only through `./update.sh <tag>`. Re-run
`rad/bench-openai.py` after a bump and compare it with the table above. Stop
other clients first: Open WebUI and Hindsight share `:8080`.

## Switching models

Each model fills both cards and uses the same port, so one runs at a time.
A profile in `rad/profiles/` describes each model. `RADIANCE_PROFILE` in
`rad/config.env` names the one that is served.

| Profile | Model | File |
|---|---|---|
| `flashnext` | Qwen3.8-Flash-Next IQR-V4, MoE; experts partly in pinned RAM; refusal control vector per request | `qwen3.8-next-flash-iqr-v4.rad`, 113.3 GiB |
| `27b` | Qwen3.8-27B IQ8R, dense, DFlash2 drafter, vision; fits VRAM (not yet started on 2.0) | `qwen3.8-27b-iq8r-dflash.rad`, 28.76 GiB |

radiance 2.0 refuses FP8 containers, so the 1.x files left in `models/rad/`
(`flashnext`, `flashnext-uncensored`, `27b` FP8) no longer load.

```bash
./switch.sh 27b               # download if missing, set RADIANCE_PROFILE, restart the stack
```

A switch restarts the whole stack, Open WebUI included, and the new model loads
in a few minutes. Flash-Next is larger than the page cache can keep, so
switching back to it reads the whole file from disk again. Prefix caching uses
VRAM and a 16384 MiB host-RAM tier, with a 3600-second idle TTL. The host tier is
allocated as pinned RAM at startup; finished conversations are copied there
before their VRAM is reclaimed. Radiance removed
the SSD prefix tier in 1.5.0 because of excessive writes (upstream issue #70);
no conversation cache is written to disk, and a restart loses the cache.
`DELETE /sessions/<label>` (since 1.12.0) forgets one stored conversation.

Both profiles are served as `qwen-local` (`SERVED_MODEL_NAME` in
`rad/config.env`), so clients need no change. The id therefore does not tell
which model answered: Hindsight's `llm_requests`, Open WebUI's history and
`bench-results.jsonl` all show `qwen-local`. Each start writes a dated
`rad: … profile <name> …` line to `logs/rad.log`; match timestamps against
those lines (`grep ' rad: ' logs/rad.log`), and label benchmarks with the
profile. Running Hindsight on the 27B is an LLM change: validate it as
[`hindsight/README.md`](hindsight/README.md) describes.

A profile pins its Hugging Face revision: upstream replaces `.rad` files under
the same name. An existing file is never re-fetched; to take a new revision,
update `RADIANCE_MODEL_REVISION` and delete the file.

## Configuration

| File | Holds |
|---|---|
| `rad/config.env` | Image tag, active profile, served model id, model directory, host/port |
| `rad/profiles/<name>.env` | Model file, its Hugging Face repo and pinned revision |
| `rad/profiles/<name>.yaml` | The model's own engine keys: aliases, TP, sequences, Flash-Next's expert placement and host pool, the control vector |
| `rad/radiance.yaml` | Engine keys every profile shares: VRAM headroom, load timeout, and under `defaults:` context, KV dtype and the prefix cache |
| `rad/compose.yaml` | The container: devices, groups, mounts. radiance 2.0 takes only `--config FILE`; `run.sh` writes `rad/state/radiance.yaml` from the three files above and compose mounts it |
| `rad/cicero-rad.service` | The user unit; `rad/install-service.sh` installs it (paths are rewritten to the repo's location) |
| `gpu-power/cicero-gpu-power.service` | `GPU_POWER_CAP_W` (210–300). Re-run `sudo gpu-power/install.sh` after editing |

`host-pool-mib` (Flash-Next) trades RAM for VRAM: experts the pool cannot hold
take card memory away from the KV cache. Since 2.0 it is the pool for both cards
together, so 24576 is 12 GiB per card (1.x read 12288 as per card). To validate
a config without restarting, run the image with the two mounts and `--config
/etc/radiance/radiance.yaml --check`.

`control-vector: off` loads Cudecnik's refusal projection (bundled with the
image, layers 4..44) and leaves requests off; a request opts in with
`"control_vector": true`. `POST /admin/control-vector {"enabled": true|false}`
from this machine changes the default until the next restart. Open WebUI's
`qwen-local-uncensored` is a workspace model on top of `qwen-local` whose
Advanced Params carry the custom parameter `control_vector` = `true`; Open
WebUI parses the value as JSON, so it arrives as a boolean. The expert-residency options of 1.14.0 (`expert-profile`,
`expert-pin-top`, `draft-expert-placement: host`) were measured on 1.15.0 and
gave nothing over the default heat engine, which already moves decode-hot
experts into VRAM; moving the MTP head's experts to RAM cost 22% of 4-stream
decode.

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
switch.sh                   # change the served model profile, restart
start.sh / stop.sh          # systemd service control
rad/
  config.env                #   shared settings: image pin, active profile, served id, port
  profiles/                 #   per model: .env (file, repo + revision), .yaml (engine keys)
  radiance.yaml             #   radiance engine keys common to all profiles
  compose.yaml              #   the radiance container; mounts the config run.sh writes
  fetch-model.sh            #   download a profile's model if missing
  run.sh                    #   Open WebUI :3000 + radiance :8080, foreground
  cicero-rad.service        #   the systemd user unit
  install-service.sh        #   install/enable the unit; retire legacy units
  bench-openai.py           #   decode / prefill / mixed / tool-call benchmark
  state/                    #   local benchmark results (gitignored)
gpu-power/                  # boot-time GPU power cap (system unit, root)
models/radiance_v2/         # the .rad containers radiance 2.0 serves (gitignored)
models/rad/                 # the 1.x FP8 containers 2.0 refuses (gitignored)
hindsight/                  # Hindsight memory server: docs, updater, UI unit, benchmark, history
logs/                       # rad.log (gitignored)
```

Earlier llama.cpp and vLLM deployments were removed from the tree; their
measurements remain in [`hindsight/experiments/`](hindsight/experiments/README.md),
and their scripts are in git history.

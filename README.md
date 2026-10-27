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

With the `flashnext` profile, radiance serves the 114 GiB model container
`qwen3.8-next-flash-fp8-iq4r-moe.rad` (4-bit experts, int8 trunk, MTP head,
vision tower) tensor-parallel across both cards. `flashnext-uncensored` (the
active profile) is the same model with refusals abliterated, at the same size
and with the same flags:

- **VRAM** — both cards are filled to ~99%: ~3.6 GiB of fixed weights, ~18 GiB
  of experts and ~8.2 GiB of KV cache per card. Nothing else GPU-bound can run
  next to it.
- **Host RAM** — experts that do not fit VRAM stream from a pinned 12 GiB pool
  per card; the 47.7 GiB n-gram table and the token embedding sit in pinned RAM.
  Expect ~85 GB of RAM in use while serving.
- **Context and concurrency** — 262,144 tokens per request, 8 sequences at once,
  FP8 KV cache. The pool holds ~4.0 full-length sessions; beyond that the
  scheduler preempts.
- **Speculative decoding** — the model's MTP head drafts 3 tokens per step.
- **Prefix cache** — finished conversations' KV moves from VRAM to an 8 GiB
  pinned host-RAM tier, so a returning conversation skips its prefill. Nothing
  is written to disk; a restart loses the cache.

Full run on 1.13.0 with `rad/bench-openai.py` (2026-10-27, `flashnext-uncensored`,
driver 31.60), against the full run on 1.2.3 (2026-10-07, `flashnext`, driver 31.50):

| | 1 stream | 2 | 4 | 8 |
|---|---:|---:|---:|---:|
| decode, aggregate tok/s, 1.13.0 | 122 | 215 | 310 | 474 |
| decode, per request tok/s, 1.13.0 | 125 | 128 | 88 | 69 |
| decode, aggregate tok/s, 1.2.3 | 117 | 212 | 316 | 448 |

Prefill runs at 4.1–4.6K tok/s (4K–53K-token prompts; 1.2.3: 3.6–4.2K). A 25K
prefill fired during a decode stream finishes in 6.6 s while that stream keeps
62 tok/s. 15 of 15 tool-call probes returned well-formed calls. Decode is
sampled at temperature 1.0, so MTP acceptance and per-prompt speed vary from run
to run; the full run's three repetitions skip the fast `reason` prompt, so its
single-stream median reads lower than the quick run's.

The quick run (`--conc 1,4 --reps 4 --prefill 16384`) on the uncensored profile
gave 155/324 aggregate tok/s at 1/4 streams and 4.66K tok/s prefill on 1.13.0,
against 139/327 and 4.42K on 1.10.0 (2026-10-21) and 143/308 and 4.58K on
1.4.0 (`flashnext`).

## Using the API

Point any OpenAI-compatible client at `http://cicero.local:8080/v1`. No API key.

- **Endpoints:** `/v1/chat/completions` and `/v1/completions`, streaming or not,
  with tool calls and image or video input (images are resized to at most
  4.2 MP). Since 1.3.0 the server also speaks OpenAI's `/v1/responses`,
  Anthropic's `/v1/messages` and llama-server's `/completion`, `/infill` and
  `/props`, with logprobs. `/v1/embeddings` is for embedding models only, so it
  is not available here.
- **Model id:** chat and completion requests are served whatever `model` they
  name, but `GET /v1/models/<id>` returns 404 for anything other than
  `qwen-local`, so a client that checks the model first needs that id. Both
  profiles use this id; `GET /v1/models` shows which is loaded in `root` (the
  `.rad` file) along with `max_model_len`.
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
./switch.sh                   # list model profiles; ./switch.sh <profile> to change
tail -f logs/rad.log          # engine + Open WebUI log
systemctl --user status cicero-rad.service
curl -fsS http://127.0.0.1:8080/v1/models
./rad/bench-openai.py --label flashnext-rad-1.13.0   # benchmark; results append to bench-results.jsonl
```

Startup takes a few minutes: the engine loads the model and copies the n-gram
table into pinned RAM before `server: listening` appears in the log. Read the
`placement:` and `VRAM budget` lines there to see where each part of the model
landed.

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
| `flashnext` | Qwen3.8-Flash-Next, MoE; experts partly in pinned RAM | `qwen3.8-next-flash-fp8-iq4r-moe.rad`, 114 GiB |
| `flashnext-uncensored` | The same, refusals abliterated | `qwen3.8-next-flash-uncensored-fp8-iq4r-moe.rad`, 114 GiB |
| `27b` | Qwen3.8-27B FP8, dense, DFlash2 drafter, vision; fits VRAM | `qwen3.8-27b-fp8.rad`, 28.67 GiB |

```bash
./switch.sh 27b               # download if missing, set RADIANCE_PROFILE, restart the stack
```

A switch restarts the whole stack, Open WebUI included, and the new model loads
in a few minutes. Flash-Next is larger than the page cache can keep, so
switching back to it reads the whole file from disk again. Prefix caching uses
VRAM and an 8192 MiB host-RAM tier, with a 3600-second idle TTL. The host tier is
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
| `rad/profiles/<name>.env` | Model file, its Hugging Face repo and pinned revision, the model's own engine flags (`RADIANCE_ARGS`; Flash-Next's expert host pool) |
| `rad/compose.yaml` | Engine flags every profile shares: TP, sequences, context, KV dtype, prefix-cache tiers. The parser takes `--flag value`, not `--flag=value` |
| `rad/cicero-rad.service` | The user unit; `rad/install-service.sh` installs it (paths are rewritten to the repo's location) |
| `gpu-power/cicero-gpu-power.service` | `GPU_POWER_CAP_W` (210–300). Re-run `sudo gpu-power/install.sh` after editing |

`HOST_POOL_MIB` (Flash-Next) trades RAM for VRAM: experts the pool cannot hold take card
memory away from the KV cache.

Engine flags this setup leaves off: `--control-vector off|on` loads upstream's
refusal-direction vector for Flash-Next (per request: `"control_vector": true`),
redundant on the uncensored profile; `--attn-prefill-fp8` speeds up very long
27B prompts (+20% at 221K tokens, lossy) and does not start on Flash-Next.

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
  profiles/                 #   one .env per model: file, repo + revision, model flags
  compose.yaml              #   radiance engine flags common to all profiles
  fetch-model.sh            #   download a profile's model if missing
  run.sh                    #   Open WebUI :3000 + radiance :8080, foreground
  cicero-rad.service        #   the systemd user unit
  install-service.sh        #   install/enable the unit; retire legacy units
  bench-openai.py           #   decode / prefill / mixed / tool-call benchmark
  state/                    #   local benchmark results (gitignored)
gpu-power/                  # boot-time GPU power cap (system unit, root)
models/rad/                 # the .rad model containers (gitignored)
hindsight/                  # Hindsight memory server: docs, updater, UI unit, benchmark, history
logs/                       # rad.log (gitignored)
```

Earlier llama.cpp and vLLM deployments were removed from the tree; their
measurements remain in [`hindsight/experiments/`](hindsight/experiments/README.md),
and their scripts are in git history.

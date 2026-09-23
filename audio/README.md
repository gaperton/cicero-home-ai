# Audio (ASR + TTS)

Adds speech-to-text and text-to-speech to the Open WebUI / Hindsight stack,
fronted by one proxy so clients only need one connection.

## Components

| Component | What | Port |
| --- | --- | --- |
| `asr_transcode_proxy.py` + `asr-transcode-proxy.sh` + `cicero-asr-proxy.service` | The proxy: routes chat/ASR to the router, everything else `/v1/audio/*` to `tts-server` | 8079 |
| `qwentts.cpp/` (cloned by `install.sh`, gitignored) + `tts-server.sh` + `cicero-tts-server.service` | TTS backend (Qwen3-TTS CustomVoice, Vulkan) | 8078 |
| `install.sh` | Clones/builds qwentts.cpp, downloads its models, installs both systemd units | — |

The router (`gpu-0-1/`, port 8080) serves chat and `qwen3-asr` transcription
directly; `tts-server` only speaks natively to `qwentts.cpp`'s own dialect,
which is why the proxy exists.

## Why the proxy exists

- **ASR transcoding**: browser mic input (Open WebUI's `MediaRecorder`) is
  WebM/Opus. llama.cpp's `mtmd-helper` only decodes WAV/MP3/FLAC (via
  miniaudio, no WebM/Opus decoder) and silently falls through to a video path
  that extracts no audio at all. The proxy transcodes to WAV with `ffmpeg`
  before forwarding.
- **ASR response_format**: llama.cpp's transcription endpoint only accepts
  `response_format: "json"`, but real Whisper-API clients expect
  `text`/`srt`/`vtt`/`verbose_json` too. The proxy always asks for `json` and
  reshapes the reply (srt/vtt/verbose_json are single-segment approximations —
  llama.cpp's response carries no per-segment timing).
- **TTS format/voice**: Open WebUI always sends `response_format: "mp3"` and
  `voice: "alloy"`, neither of which `tts-server` understands natively. The
  proxy always requests `wav` from the backend, substitutes
  `DEFAULT_TTS_VOICE` for anything not in the model's real speaker list
  (checked via `GET /v1/audio/voices` up front — see below), then
  ffmpeg-transcodes to whatever the client actually asked for. This buffers
  the whole response, so it doesn't support `tts-server`'s low-latency PCM
  streaming — a non-issue for Open WebUI, which downloads a full file anyway.
- `GET /v1/models` merges both backends' model lists so one Open WebUI
  connection shows chat, ASR and TTS models together.

## TTS model: CustomVoice, not base

`tts-server` runs Qwen3-TTS 1.7B **CustomVoice** (Q8_0), not the base model.
CustomVoice ships 9 built-in named speakers baked into the weights (`serena`,
`vivian`, `uncle_fu`, `ryan`, `aiden`, `ono_anna`, `sohee`, `eric`, `dylan` —
the last two carry Mandarin dialect overrides), selected per-request via the
`voice` field with no cloning or reference audio needed. Default is `aiden`
(`DEFAULT_TTS_VOICE` in `asr_transcode_proxy.py`).

This replaced an earlier base-mode setup that had zero built-in speakers and
needed a cloned reference voice registered over HTTP on every start to get a
consistent identity — CustomVoice refuses that registration endpoint outright
(`tools/tts-server.cpp`: "voice registration is only valid for base models").

**Gotcha this caused**: with zero speakers, an invalid voice name cleanly
400s with "unknown voice". With CustomVoice's 9 speakers, `tts-server` instead
passes *any* non-empty voice string straight to the synthesis pipeline, and an
unrecognized one (e.g. Open WebUI's hardcoded `"alloy"`) blows up deep inside
as a generic 500 with no matchable error string. The proxy works around this
by fetching the real speaker list from `GET /v1/audio/voices` once at startup
and substituting the default *before* the first request, rather than reacting
to an error after the fact.

## GPU placement

`tts-server` is Vulkan-based, not ROCm/HIP, so it doesn't show up in
`amd-smi process`'s per-process VRAM accounting even though it shares the same
physical cards. It's pinned to the ROCm1 card via `GGML_VK_VISIBLE_DEVICES=1`
in `tts-server.sh` (confirmed 1:1 index mapping between Vulkan and ROCm device
order via `vulkaninfo`'s `VkPhysicalDevicePCIBusInfoPropertiesEXT` vs.
`rocm-smi --showbus`). `gpu-0-1/qwen3-asr.ini` in turn keeps `qwen3-asr` and
`qwen3-reranker` on ROCm0, so the two ~3-7 GB fixed loads (ASR + TTS) land on
opposite cards instead of stacking onto one — see that file for the current
VRAM balance across both cards.

## Install / manage

```bash
./audio/install.sh      # clone+build qwentts.cpp, fetch TTS models, install units
systemctl --user start   cicero-tts-server.service cicero-asr-proxy.service
systemctl --user status  cicero-tts-server.service cicero-asr-proxy.service
journalctl --user -u cicero-tts-server.service -f
```

Both units run independently of `cicero-home-ai.service` on purpose: a crash
in either one shouldn't take down chat, and they only matter while an
audio-capable model is loaded.

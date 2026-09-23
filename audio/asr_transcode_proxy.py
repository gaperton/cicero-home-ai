#!/usr/bin/env python3
# audio/asr_transcode_proxy.py — one connection for chat, ASR and TTS: routes
# to the llama.cpp router (chat, qwen3-asr) or qwentts.cpp's tts-server
# (/v1/audio/speech, /v1/audio/voices), transcoding/reshaping where the two
# backends don't speak the client's dialect. See audio/README.md for why.
#
#   ASR_PROXY_UPSTREAM=http://127.0.0.1:8080 \
#   ASR_PROXY_TTS_UPSTREAM=http://127.0.0.1:8078 \
#   ASR_PROXY_PORT=8079 ./audio/asr-transcode-proxy.sh
import json
import os
import re
import subprocess

import httpx
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse

UPSTREAM = os.environ.get("ASR_PROXY_UPSTREAM", "http://127.0.0.1:8080")
TTS_UPSTREAM = os.environ.get("ASR_PROXY_TTS_UPSTREAM", "http://127.0.0.1:8078")
TRANSCODE_PATHS = {"/v1/audio/transcriptions", "/v1/audio/translations"}
SPEECH_PATH = "/v1/audio/speech"
DEFAULT_TTS_SEED = 42  # pinned so unseeded calls are reproducible, see speech()
DEFAULT_TTS_VOICE = "aiden"  # built-in CustomVoice speaker; see speech()
NATIVE_TTS_FORMATS = {"wav", "pcm"}
FFMPEG_TTS_FORMATS = {
    "mp3": (["-f", "mp3"], "audio/mpeg"),
    "opus": (["-c:a", "libopus", "-f", "ogg"], "audio/ogg"),
    "aac": (["-c:a", "aac", "-f", "adts"], "audio/aac"),
    "flac": (["-f", "flac"], "audio/flac"),
}
HOP_BY_HOP = {"host", "content-length", "transfer-encoding", "connection"}

# Qwen3-ASR tags each internal segment with its detected language, e.g.
# "language Russian<asr_text>...text...". Strip these markers so the client
# gets plain transcript text.
LANG_TAG_RE = re.compile(r"language \w+<asr_text>")

app = FastAPI()
client = httpx.AsyncClient(base_url=UPSTREAM, timeout=None)
tts_client = httpx.AsyncClient(base_url=TTS_UPSTREAM, timeout=None)

_valid_voices: set[str] | None = None


async def get_valid_voices() -> set[str]:
    # Cached for the proxy's lifetime — CustomVoice's speaker list is fixed
    # per model load. Used to catch a bad voice name before sending it; see
    # audio/README.md for why tts-server can't be trusted to reject one itself.
    global _valid_voices
    if _valid_voices is None:
        try:
            r = await tts_client.get("/v1/audio/voices")
            _valid_voices = {v["name"] for v in r.json().get("voices", [])}
        except Exception:
            return set()
    return _valid_voices


def pick_client(url_path: str) -> httpx.AsyncClient:
    # Any /v1/audio/* path except the ASR transcode ones belongs to tts-server
    # (speech synthesis, voice registry).
    if url_path.startswith("/v1/audio/") and url_path not in TRANSCODE_PATHS:
        return tts_client
    return client


def clean_transcript_json(body: bytes) -> bytes | None:
    try:
        payload = json.loads(body)
    except ValueError:
        return None
    text = payload.get("text")
    if not isinstance(text, str):
        return None
    payload["text"] = LANG_TAG_RE.sub("", text).strip()
    return json.dumps(payload).encode()


def reshape_transcript(json_body: bytes, fmt: str) -> tuple[bytes, str]:
    if fmt == "json":
        return json_body, "application/json"
    text = json.loads(json_body).get("text", "")
    if fmt == "text":
        return text.encode(), "text/plain"
    if fmt == "verbose_json":
        vjson = {"task": "transcribe", "language": None, "duration": None, "text": text, "segments": []}
        return json.dumps(vjson).encode(), "application/json"
    if fmt == "srt":
        return f"1\n00:00:00,000 --> 00:00:00,000\n{text}\n".encode(), "text/plain"
    if fmt == "vtt":
        return f"WEBVTT\n\n00:00:00.000 --> 00:00:00.000\n{text}\n".encode(), "text/vtt"
    raise KeyError(fmt)


def transcode_to_wav(data: bytes) -> bytes:
    # 16 kHz mono s16 WAV: a safe, small default. miniaudio resamples to the
    # model's own target rate on top of this regardless, so exact rate here
    # doesn't matter — only that ffmpeg can decode the *input* container.
    proc = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", "pipe:0",
         "-ac", "1", "-ar", "16000", "-f", "wav", "pipe:1"],
        input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        raise ValueError(proc.stderr.decode("utf-8", "replace"))
    return proc.stdout


def transcode_wav_to(data: bytes, fmt: str) -> bytes:
    args, _content_type = FFMPEG_TTS_FORMATS[fmt]
    proc = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "wav", "-i", "pipe:0", *args, "pipe:1"],
        input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        raise ValueError(proc.stderr.decode("utf-8", "replace"))
    return proc.stdout


@app.post(SPEECH_PATH)
async def speech(request: Request):
    try:
        payload = json.loads(await request.body())
    except ValueError:
        return Response(content="invalid JSON body", status_code=400)

    # tts-server defaults seed to -1 (fresh hardware-random per call, qwen.cpp
    # qt_resolve_seed); pin one so repeated/split calls are reproducible. An
    # explicit seed from the client still wins.
    payload.setdefault("seed", DEFAULT_TTS_SEED)

    payload.setdefault("voice", DEFAULT_TTS_VOICE)
    valid_voices = await get_valid_voices()
    if valid_voices and payload["voice"] not in valid_voices:
        payload["voice"] = DEFAULT_TTS_VOICE

    requested_format = payload.get("response_format") or "mp3"
    payload["response_format"] = requested_format if requested_format in NATIVE_TTS_FORMATS else "wav"

    resp = await tts_client.post(SPEECH_PATH, json=payload)
    if resp.status_code == 400 and b"unknown voice" in resp.content.lower():
        payload["voice"] = DEFAULT_TTS_VOICE
        resp = await tts_client.post(SPEECH_PATH, json=payload)

    if resp.status_code != 200:
        return Response(content=resp.content, status_code=resp.status_code,
                         media_type=resp.headers.get("content-type"))

    if requested_format in NATIVE_TTS_FORMATS:
        return Response(content=resp.content, status_code=200,
                         media_type=resp.headers.get("content-type", "audio/wav"))

    try:
        audio = transcode_wav_to(resp.content, requested_format)
    except KeyError:
        return Response(content=f"unsupported response_format '{requested_format}'", status_code=400)
    except ValueError as e:
        return Response(content=f"ffmpeg transcode failed: {e}", status_code=502)
    _, content_type = FFMPEG_TTS_FORMATS[requested_format]
    return Response(content=audio, status_code=200, media_type=content_type)


@app.get("/v1/models")
async def list_models():
    async def safe_list(c: httpx.AsyncClient):
        try:
            r = await c.get("/v1/models")
            return r.json().get("data", [])
        except Exception:
            return []

    chat_models, tts_models = await safe_list(client), await safe_list(tts_client)
    return {"object": "list", "data": chat_models + tts_models}


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"])
async def proxy(path: str, request: Request):
    url_path = "/" + path
    target = pick_client(url_path)
    headers = {k: v for k, v in request.headers.items() if k.lower() not in HOP_BY_HOP}

    requested_transcript_format = "json"
    if request.method == "POST" and url_path in TRANSCODE_PATHS:
        form = await request.form()
        upload = form.get("file")
        if upload is not None:
            requested_transcript_format = str(form.get("response_format") or "json")
            raw = await upload.read()
            try:
                wav = transcode_to_wav(raw)
            except ValueError as e:
                return Response(content=f"ffmpeg transcode failed: {e}", status_code=400)
            files = {"file": ("audio.wav", wav, "audio/wav")}
            data = {k: v for k, v in form.multi_items() if k != "file"}
            data["response_format"] = "json"  # the only value the router accepts; reshaped below
            upstream_req = target.build_request("POST", url_path, data=data, files=files)
        else:
            body = await request.body()
            upstream_req = target.build_request("POST", url_path, content=body, headers=headers)
    else:
        body = await request.body()
        upstream_req = target.build_request(
            request.method, url_path, content=body, headers=headers, params=request.query_params)

    if url_path in TRANSCODE_PATHS:
        # Transcription responses are small JSON, not streamed — buffer so we
        # can strip the language-tag markers and reshape response_format.
        upstream_resp = await target.send(upstream_req)
        resp_headers = {k: v for k, v in upstream_resp.headers.items() if k.lower() not in HOP_BY_HOP}
        if upstream_resp.status_code != 200 or "application/json" not in upstream_resp.headers.get("content-type", ""):
            return Response(content=upstream_resp.content, status_code=upstream_resp.status_code, headers=resp_headers)
        cleaned = clean_transcript_json(upstream_resp.content) or upstream_resp.content
        try:
            body, content_type = reshape_transcript(cleaned, requested_transcript_format)
        except KeyError:
            return Response(
                content=f"unsupported response_format '{requested_transcript_format}'".encode(),
                status_code=400)
        return Response(content=body, status_code=200, media_type=content_type)

    upstream_resp = await target.send(upstream_req, stream=True)
    resp_headers = {k: v for k, v in upstream_resp.headers.items() if k.lower() not in HOP_BY_HOP}
    return StreamingResponse(
        upstream_resp.aiter_raw(),
        status_code=upstream_resp.status_code,
        headers=resp_headers,
        background=upstream_resp.aclose,
    )

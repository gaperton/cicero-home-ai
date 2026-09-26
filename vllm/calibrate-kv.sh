#!/usr/bin/env bash
# vllm/calibrate-kv.sh — Produce calibrated FP8 KV scales for MODEL_DIR.
#
#   ./vllm/calibrate-kv.sh            # corpus -> calibrate -> verify
#
# Needs both GPUs free: stop cicero-vllm.service / the llama.cpp stack first.
# Uses the radiance image's own calibrator: an eager pass that records each
# full-attention layer's Q/K/V absolute maximum (TP-reduced) and writes
# scale = amax * 1.05 / 448 as an immutable, checksummed sidecar bound to the
# exact checkpoint. The source model is not modified. Afterwards point
# FP8_KV_SCALES in config.env at the new file and restart.
set -euo pipefail

VLLM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$VLLM_DIR")"
# shellcheck source=config.env
source "$VLLM_DIR/config.env"
OUT="$(basename "$MODEL_DIR" | tr 'A-Z' 'a-z')-kv-enru-$(date +%Y%m%d).safetensors"

python3 "$VLLM_DIR/build-calibration-corpus.py"

docker run --rm --ipc=host --security-opt seccomp=unconfined --device=/dev/kfd --device=/dev/dri \
  -e HIP_VISIBLE_DEVICES=0,1 -e NCCL_PROTO=Simple \
  -e VLLM_ROCM_USE_AITER=1 -e VLLM_ROCM_USE_AITER_UNIFIED_ATTENTION=1 \
  -e VLLM_ROCM_USE_AITER_LINEAR=0 -e VLLM_ROCM_USE_AITER_RMSNORM=0 \
  -e VLLM_ROCM_USE_AITER_MHA=0 -e VLLM_ROCM_USE_AITER_MOE=0 \
  -v "$REPO/$MODEL_DIR:/models/model:ro" -v "$VLLM_DIR/calibration:/calibration:rw" \
  --entrypoint sh "$IMAGE" -c "
    python -m radiance_kv_calibration calibrate --model /models/model --quantization fp8 \
      --corpus /calibration/corpus/calib.jsonl --output /calibration/$OUT \
      --tensor-parallel-size 2 --max-model-len 49152 --gpu-memory-utilization 0.90 \
      --batch-size 4 --seed 17 --language-model-only &&
    python -m radiance_kv_calibration verify /calibration/$OUT --model /models/model;
    rc=\$?; chown -R $(id -u):$(id -g) /calibration; exit \$rc"

echo "Wrote vllm/calibration/$OUT"
echo "Use it: set FP8_KV_SCALES=vllm/calibration/$OUT in vllm/config.env, then ./vllm/start.sh"

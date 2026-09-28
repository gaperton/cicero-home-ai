#!/usr/bin/env bash
# Set the PPT0 socket power cap on every AMD GPU. Run by cicero-gpu-power.service.
set -euo pipefail

CAP_W="${GPU_POWER_CAP_W:-250}"

# amdgpu may still be initialising at boot; wait for the GPUs to be listed.
for _ in $(seq 60); do
    gpus=$(amd-smi list 2>/dev/null | sed -n 's/^GPU: \([0-9]*\)$/\1/p')
    [[ -n "$gpus" ]] && break
    sleep 1
done
[[ -n "$gpus" ]] || { echo "set-power-cap: no GPUs listed by amd-smi" >&2; exit 1; }

for gpu in $gpus; do
    amd-smi set -g "$gpu" -o "$CAP_W" ppt0
    limit=$(amd-smi static --limit -g "$gpu" | sed -n 's/.*SOCKET_POWER_LIMIT: \([0-9]*\) W.*/\1/p' | head -1)
    [[ "$limit" == "$CAP_W" ]] || { echo "set-power-cap: GPU $gpu reports ${limit:-?} W, expected $CAP_W W" >&2; exit 1; }
    echo "set-power-cap: GPU $gpu capped at $CAP_W W"
done

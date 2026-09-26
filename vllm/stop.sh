#!/usr/bin/env bash
# vllm/stop.sh — Stop cicero-vllm.service (Open WebUI, the sidecar and vLLM).
set -euo pipefail

systemctl --user stop cicero-vllm.service
echo "Stopped. Back to llama.cpp: ./start.sh"

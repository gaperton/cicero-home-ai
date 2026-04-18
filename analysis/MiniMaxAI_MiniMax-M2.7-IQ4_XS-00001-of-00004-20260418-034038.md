# MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004 — Analysis Benchmark

**Date:** Sat Apr 18 03:40:38 AM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 --n-cpu-moe 999 -b 4096 -ub 4096 -fitt 512`  
**Env:** `RADV_DEBUG=nocompute`

## MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004 · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
main: error: failed to load model 'models/MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004.gguf'
| model                          |       size |     params | backend    | ngl | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -: | --------------: | -------------------: |
**ERROR: ROCm bench crashed (exit 1)**

## MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004 · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
radv/amdgpu: Not enough memory for command submission.
main: error: failed to create context with model 'models/MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004.gguf'
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
**ERROR: Vulkan bench crashed (exit 1)**


# Qwen3.5-122B-A10B — Analysis Benchmark

**Date:** Sat Apr 18 12:21:44 AM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row --n-cpu-moe 999 -b 4096 -ub 4096 -fitt 512`  
**Env:** `RADV_DEBUG=nocompute`

## Qwen3.5-122B-A10B-UD-Q4_K_XL-00001-of-00003 · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch |     sm | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -----: | -: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |           pp512 |        210.60 ± 8.41 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |          pp2048 |        554.82 ± 3.61 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |          pp4096 |      206.71 ± 135.03 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |           tg256 |         14.66 ± 0.01 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |           pp512 |       537.15 ± 10.97 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |          pp2048 |      1098.90 ± 23.93 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |          pp4096 |       1232.20 ± 2.95 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |           tg256 |         23.82 ± 0.39 |
main: error: failed to load model 'models/Qwen3.5-122B-A10B-UD-Q4_K_XL-00001-of-00003.gguf'
**ERROR: ROCm bench crashed (exit 1)**

## Qwen3.5-122B-A10B-UD-Q4_K_XL-00001-of-00003 · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch |     sm | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -----: | -: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |           pp512 |        131.67 ± 2.03 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |          pp2048 |       311.45 ± 14.38 |

# Qwen3.5-122B-A10B — Analysis Benchmark

**Date:** Fri Apr 17 11:25:40 PM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row --n-cpu-moe 999`  
**Env:** `RADV_DEBUG=nocompute`

## Qwen3.5-122B-A10B-UD-Q4_K_XL-00001-of-00003 · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |   none |  1 |           pp512 |        132.45 ± 2.30 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |   none |  1 |          pp2048 |        133.31 ± 0.22 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |   none |  1 |          pp4096 |        132.09 ± 2.64 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |   none |  1 |           tg256 |         11.87 ± 0.12 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |  layer |  1 |           pp512 |        127.73 ± 0.17 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |  layer |  1 |          pp2048 |        130.16 ± 2.52 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |  layer |  1 |          pp4096 |        124.66 ± 3.27 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |  layer |  1 |           tg256 |         11.52 ± 0.08 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    row |  1 |           pp512 |        118.86 ± 1.26 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    row |  1 |          pp2048 |        121.89 ± 0.17 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    row |  1 |          pp4096 |        121.33 ± 0.65 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    row |  1 |           tg256 |         11.70 ± 0.02 |

build: 5d14e5d19 (8797)

## Qwen3.5-122B-A10B-UD-Q4_K_XL-00001-of-00003 · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |   none |  1 |           pp512 |         72.84 ± 1.27 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |   none |  1 |          pp2048 |         72.66 ± 0.95 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |   none |  1 |          pp4096 |         72.45 ± 0.35 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |   none |  1 |           tg256 |         12.30 ± 0.05 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |  layer |  1 |           pp512 |         72.22 ± 0.64 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |  layer |  1 |          pp2048 |         72.30 ± 1.67 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |  layer |  1 |          pp4096 |         69.65 ± 0.73 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |  layer |  1 |           tg256 |         11.60 ± 0.01 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    row |  1 |           pp512 |         70.30 ± 0.71 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    row |  1 |          pp2048 |         69.87 ± 0.31 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    row |  1 |          pp4096 |         70.51 ± 0.74 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    row |  1 |           tg256 |         11.57 ± 0.04 |

build: 5d14e5d19 (8797)


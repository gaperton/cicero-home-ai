# Qwen3.5-122B-A10B — Analysis Benchmark

**Date:** Sat Apr 18 12:01:49 AM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row --n-cpu-moe 999 -b 4096 -ub 4096`  
**Env:** `RADV_DEBUG=nocompute`

## Qwen3.5-122B-A10B-UD-Q4_K_XL-00001-of-00003 · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |           pp512 |        129.35 ± 2.33 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |          pp2048 |        379.76 ± 2.13 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |          pp4096 |        597.85 ± 0.98 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |           tg256 |         11.52 ± 0.12 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |           pp512 |        127.62 ± 0.33 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |          pp2048 |        373.00 ± 3.44 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |          pp4096 |        576.82 ± 2.98 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |           tg256 |         11.84 ± 0.05 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |           pp512 |        119.40 ± 1.08 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |          pp2048 |        325.79 ± 0.16 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |          pp4096 |        482.27 ± 0.34 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |           tg256 |         11.75 ± 0.02 |

build: 5d14e5d19 (8797)

## Qwen3.5-122B-A10B-UD-Q4_K_XL-00001-of-00003 · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |           pp512 |         71.73 ± 1.67 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |          pp2048 |        197.43 ± 4.53 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |          pp4096 |        321.64 ± 3.95 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |           tg256 |         12.41 ± 0.02 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |           pp512 |         71.60 ± 0.42 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |          pp2048 |        184.72 ± 1.49 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |          pp4096 |        291.59 ± 3.95 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |           tg256 |         11.50 ± 0.00 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |           pp512 |         69.54 ± 0.89 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |          pp2048 |        182.30 ± 0.69 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |          pp4096 |        293.86 ± 1.34 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |           tg256 |         11.49 ± 0.03 |

build: 5d14e5d19 (8797)


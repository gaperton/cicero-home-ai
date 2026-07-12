# Qwen3.6-35B-A3B — Analysis Benchmark

**Date:** Fri Apr 17 11:56:34 PM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row --n-cpu-moe 999 -t 8 -b 4096 -ub 4096`  
**Env:** `RADV_DEBUG=nocompute`

## Qwen3.6-35B-A3B-UD-Q4_K_XL · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |           pp512 |        452.27 ± 5.17 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |          pp2048 |       1246.27 ± 0.28 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |          pp4096 |       1807.02 ± 1.98 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |           tg256 |         28.90 ± 0.01 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |           pp512 |        436.82 ± 6.68 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |          pp2048 |       1180.32 ± 3.69 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |          pp4096 |       1674.38 ± 9.69 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |           tg256 |         30.24 ± 0.01 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |           pp512 |        378.87 ± 8.36 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |          pp2048 |        932.60 ± 6.63 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |          pp4096 |       1236.39 ± 2.05 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |           tg256 |         26.26 ± 0.00 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q4_K_XL · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |           pp512 |        254.65 ± 2.61 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |          pp2048 |        807.27 ± 6.08 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |          pp4096 |       1213.23 ± 3.87 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |           tg256 |         32.45 ± 0.11 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |           pp512 |        250.55 ± 1.63 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |          pp2048 |       715.64 ± 14.66 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |          pp4096 |        945.43 ± 3.49 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |           tg256 |         28.61 ± 0.16 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |           pp512 |        245.56 ± 0.98 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |          pp2048 |        689.31 ± 9.94 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |          pp4096 |        948.71 ± 7.03 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |           tg256 |         28.66 ± 0.08 |

build: 5d14e5d19 (8797)


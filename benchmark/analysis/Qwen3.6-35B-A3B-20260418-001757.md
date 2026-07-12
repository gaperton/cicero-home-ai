# Qwen3.6-35B-A3B — Analysis Benchmark

**Date:** Sat Apr 18 12:17:57 AM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row --n-cpu-moe 999 -b 4096 -ub 4096 -fitt 512`  
**Env:** `RADV_DEBUG=nocompute`

## Qwen3.6-35B-A3B-UD-Q4_K_XL · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch |     sm | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -----: | -: | ---------: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |           pp512 |      3057.06 ± 36.03 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |          pp2048 |       4268.77 ± 2.85 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |          pp4096 |       4077.49 ± 4.47 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |           tg256 |         71.08 ± 0.18 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |           pp512 |      2730.90 ± 40.98 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |          pp2048 |       4176.52 ± 2.97 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |          pp4096 |      4029.79 ± 11.49 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |           tg256 |         57.01 ± 0.07 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |        512 |           pp512 |       1481.71 ± 6.65 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |        512 |          pp2048 |       2060.25 ± 3.88 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |        512 |          pp4096 |       2040.87 ± 6.50 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    4096 |     4096 |    row |  1 |        512 |           tg256 |         34.23 ± 0.05 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q4_K_XL · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch |     sm | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -----: | -: | ---------: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |           pp512 |      2964.40 ± 20.29 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |          pp2048 |       3761.65 ± 8.33 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |          pp4096 |       3221.13 ± 9.91 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |           tg256 |        135.12 ± 0.71 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |           pp512 |      2383.80 ± 12.70 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |          pp2048 |      3668.15 ± 25.62 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |          pp4096 |       3138.50 ± 6.47 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |  layer |  1 |        512 |           tg256 |        106.56 ± 0.02 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |        512 |           pp512 |      2390.22 ± 20.09 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |        512 |          pp2048 |       3645.57 ± 5.89 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |        512 |          pp4096 |      3159.91 ± 11.50 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    4096 |     4096 |    row |  1 |        512 |           tg256 |        106.06 ± 0.16 |

build: 5d14e5d19 (8797)


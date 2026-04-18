# Qwen3.6-35B-A3B — Analysis Benchmark

**Date:** Fri Apr 17 10:45:11 PM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row --n-cpu-moe 999`  
**Env:** `RADV_DEBUG=nocompute`

## Qwen3.6-35B-A3B-UD-Q4_K_XL · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |           pp512 |        454.93 ± 4.62 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |          pp2048 |        453.46 ± 3.39 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |          pp4096 |        445.45 ± 0.58 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |           tg256 |         29.82 ± 0.60 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |           pp512 |        441.16 ± 7.53 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |          pp2048 |        446.28 ± 7.39 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |          pp4096 |        429.85 ± 3.62 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |           tg256 |         30.85 ± 0.37 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |           pp512 |        381.75 ± 8.50 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |          pp2048 |        397.91 ± 1.57 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |          pp4096 |        396.58 ± 1.14 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |           tg256 |         26.66 ± 0.03 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q4_K_XL · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |           pp512 |        263.60 ± 3.68 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |          pp2048 |        259.28 ± 4.23 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |          pp4096 |        261.25 ± 3.02 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |           tg256 |         32.84 ± 0.74 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |           pp512 |        250.13 ± 1.31 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |          pp2048 |       257.79 ± 10.68 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |          pp4096 |        243.75 ± 0.08 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |           tg256 |         28.68 ± 0.11 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |           pp512 |        247.88 ± 0.60 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |          pp2048 |        243.15 ± 1.69 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |          pp4096 |        245.00 ± 0.29 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |           tg256 |         28.68 ± 0.14 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q5_K_XL · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |           pp512 |        383.71 ± 2.60 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |          pp2048 |        380.34 ± 2.45 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |          pp4096 |        373.56 ± 0.36 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |           tg256 |         26.59 ± 0.04 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |           pp512 |        368.23 ± 4.69 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |          pp2048 |        372.35 ± 6.21 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |          pp4096 |        359.98 ± 6.17 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |           tg256 |         27.93 ± 0.60 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |           pp512 |        325.49 ± 6.33 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |          pp2048 |        337.81 ± 2.07 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |          pp4096 |        339.75 ± 1.41 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |           tg256 |         24.17 ± 0.19 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q5_K_XL · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |           pp512 |        230.83 ± 0.42 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |          pp2048 |        230.12 ± 2.92 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |          pp4096 |        232.02 ± 2.98 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |           tg256 |         29.91 ± 0.14 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |           pp512 |        220.56 ± 2.18 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |          pp2048 |        229.20 ± 8.26 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |          pp4096 |        213.18 ± 0.14 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |           tg256 |         23.58 ± 0.02 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |           pp512 |        214.27 ± 1.14 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |          pp2048 |        218.00 ± 0.93 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |          pp4096 |        216.69 ± 1.55 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |           tg256 |         23.47 ± 0.08 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q6_K_XL · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |           pp512 |        319.45 ± 4.50 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |          pp2048 |        320.08 ± 1.85 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |          pp4096 |        314.98 ± 0.96 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |   none |  1 |           tg256 |         24.14 ± 0.04 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |           pp512 |        308.46 ± 3.84 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |          pp2048 |        314.42 ± 2.09 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |          pp4096 |        304.53 ± 2.84 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |  layer |  1 |           tg256 |         25.09 ± 0.48 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |           pp512 |        275.62 ± 4.39 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |          pp2048 |        288.56 ± 2.45 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |          pp4096 |        286.14 ± 2.23 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |        999 |    row |  1 |           tg256 |         22.00 ± 0.09 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q6_K_XL · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |           pp512 |        202.52 ± 1.20 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |          pp2048 |        201.41 ± 3.69 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |          pp4096 |        200.49 ± 0.08 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |   none |  1 |           tg256 |         26.26 ± 0.30 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |           pp512 |        190.26 ± 3.30 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |          pp2048 |        198.17 ± 6.66 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |          pp4096 |        185.75 ± 0.05 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |  layer |  1 |           tg256 |         23.58 ± 0.03 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |           pp512 |        186.18 ± 1.05 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |          pp2048 |        187.87 ± 1.86 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |          pp4096 |        189.14 ± 0.93 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |        999 |    row |  1 |           tg256 |         21.10 ± 0.08 |

build: 5d14e5d19 (8797)


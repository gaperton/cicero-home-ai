# Qwen3.6-35B-A3B — Analysis Benchmark

**Date:** Fri Apr 17 10:38:07 PM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row`  
**Env:** `RADV_DEBUG=nocompute`

## Qwen3.6-35B-A3B-UD-Q4_K_XL · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |   none |  1 |           pp512 |      3081.60 ± 41.09 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |   none |  1 |          pp2048 |      2939.00 ± 10.82 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |   none |  1 |          pp4096 |       2821.40 ± 4.64 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |   none |  1 |           tg256 |         71.23 ± 0.25 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |           pp512 |      2760.79 ± 92.25 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |          pp2048 |       4285.16 ± 1.29 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |          pp4096 |      4523.21 ± 27.33 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |           tg256 |         56.82 ± 1.54 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |    row |  1 |           pp512 |       1488.03 ± 5.77 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |    row |  1 |          pp2048 |       1724.99 ± 2.11 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |    row |  1 |          pp4096 |       1689.85 ± 0.43 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | ROCm       |  99 |    row |  1 |           tg256 |         34.48 ± 0.03 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q4_K_XL · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |           pp512 |      2968.56 ± 21.75 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |          pp2048 |      2887.19 ± 26.02 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |          pp4096 |      2833.55 ± 11.16 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |           tg256 |        136.42 ± 0.82 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |           pp512 |      2407.85 ± 21.45 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |          pp2048 |      4287.27 ± 61.87 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |          pp4096 |      4150.25 ± 25.52 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |           tg256 |        106.42 ± 0.34 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |           pp512 |      2392.13 ± 49.45 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |          pp2048 |       4270.04 ± 3.86 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |          pp4096 |      4216.62 ± 10.68 |
| qwen35moe 35B.A3B Q4_K - Medium |  20.81 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |           tg256 |        105.76 ± 0.26 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q5_K_XL · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |   none |  1 |           pp512 |      2673.21 ± 28.39 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |   none |  1 |          pp2048 |      2564.92 ± 12.98 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |   none |  1 |          pp4096 |       2457.84 ± 5.72 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |   none |  1 |           tg256 |         73.07 ± 0.40 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |           pp512 |      2427.61 ± 61.43 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |          pp2048 |      3740.36 ± 31.03 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |          pp4096 |      3927.31 ± 22.49 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |           tg256 |         62.16 ± 0.59 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |    row |  1 |           pp512 |      1405.63 ± 11.04 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |    row |  1 |          pp2048 |       1571.92 ± 0.48 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |    row |  1 |          pp4096 |       1538.09 ± 0.03 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       |  99 |    row |  1 |           tg256 |         48.04 ± 0.08 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q5_K_XL · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |           pp512 |      2812.12 ± 97.45 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |          pp2048 |      2798.09 ± 29.27 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |          pp4096 |       2736.72 ± 9.52 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |           tg256 |        130.85 ± 0.71 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |           pp512 |      2356.40 ± 16.65 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |          pp2048 |      4167.02 ± 66.60 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |          pp4096 |      4018.21 ± 14.23 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |           tg256 |        102.92 ± 0.25 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |           pp512 |      2355.46 ± 60.49 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |          pp2048 |       4148.54 ± 4.05 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |          pp4096 |      4074.69 ± 17.54 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |           tg256 |        102.11 ± 0.41 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q6_K_XL · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |   none |  1 |           pp512 |      2447.64 ± 24.39 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |   none |  1 |          pp2048 |      2349.82 ± 13.03 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |   none |  1 |          pp4096 |       2255.05 ± 0.27 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |   none |  1 |           tg256 |         74.50 ± 0.51 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |           pp512 |      2308.79 ± 27.32 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |          pp2048 |      3463.27 ± 24.13 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |          pp4096 |       3663.71 ± 2.85 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |  layer |  1 |           tg256 |         62.41 ± 0.73 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |    row |  1 |           pp512 |       1347.66 ± 4.38 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |    row |  1 |          pp2048 |       1515.76 ± 0.83 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |    row |  1 |          pp4096 |       1488.75 ± 6.15 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | ROCm       |  99 |    row |  1 |           tg256 |         34.77 ± 0.07 |

build: 5d14e5d19 (8797)

## Qwen3.6-35B-A3B-UD-Q6_K_XL · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |           pp512 |      2831.12 ± 29.93 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |          pp2048 |      2767.67 ± 23.66 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |          pp4096 |       2706.55 ± 6.10 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |   none |  1 |           tg256 |        125.61 ± 0.69 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |           pp512 |      2337.88 ± 19.05 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |          pp2048 |      3950.38 ± 54.08 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |          pp4096 |       3832.49 ± 7.38 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |  layer |  1 |           tg256 |        100.52 ± 0.30 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |           pp512 |      2338.62 ± 39.01 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |          pp2048 |      3939.94 ± 30.71 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |          pp4096 |      3889.34 ± 11.08 |
| qwen35moe 35B.A3B Q6_K         |  29.65 GiB |    34.66 B | Vulkan     |  99 |    row |  1 |           tg256 |         99.95 ± 0.22 |

build: 5d14e5d19 (8797)


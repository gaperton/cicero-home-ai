# Qwen3.5-122B-A10B — Analysis Benchmark

**Date:** Sat Apr 18 12:37:37 AM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm layer --n-cpu-moe 999 -b 4096 -ub 4096 -fitt 512`  
**Env:** `RADV_DEBUG=nocompute`

## Qwen3.5-122B-A10B-UD-Q4_K_XL-00001-of-00003 · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |           pp512 |        583.75 ± 2.06 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp2048 |       1115.99 ± 6.42 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp4096 |       1263.40 ± 4.80 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |           tg256 |         26.79 ± 0.58 |

build: 5d14e5d19 (8797)

## Qwen3.5-122B-A10B-UD-Q4_K_XL-00001-of-00003 · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |  1 |        512 |           pp512 |        336.88 ± 3.45 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp2048 |       665.87 ± 31.12 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp4096 |        771.66 ± 3.41 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     |  99 |        999 |    4096 |     4096 |  1 |        512 |           tg256 |         31.08 ± 0.14 |

build: 5d14e5d19 (8797)


# MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004 — Analysis Benchmark

**Date:** Sat Apr 18 03:30:34 AM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm layer --n-cpu-moe 999 -b 4096 -ub 4096 -fitt 512`  
**Env:** `RADV_DEBUG=nocompute`

## MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004 · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -: | ---------: | --------------: | -------------------: |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |           pp512 |        130.68 ± 0.47 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp2048 |        381.12 ± 0.73 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp4096 |       545.75 ± 12.28 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |           tg256 |         15.45 ± 0.08 |

build: fd1c0ec3f (8834)

## MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004 · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -: | ---------: | --------------: | -------------------: |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | Vulkan     |  99 |        999 |    4096 |     4096 |  1 |        512 |           pp512 |         71.21 ± 0.41 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | Vulkan     |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp2048 |        204.28 ± 0.97 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | Vulkan     |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp4096 |       305.63 ± 12.79 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | Vulkan     |  99 |        999 |    4096 |     4096 |  1 |        512 |           tg256 |         13.60 ± 0.04 |

build: fd1c0ec3f (8834)


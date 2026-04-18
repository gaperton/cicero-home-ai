# MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004 — Analysis Benchmark

**Date:** Sat Apr 18 03:46:12 AM EDT 2026  
**Flags:** `-ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 --n-cpu-moe 999 -b 4096 -ub 4096 -fitt 512`  
**Env:** `RADV_DEBUG=nocompute`

## MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004 · ROCm
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -: | ---------: | --------------: | -------------------: |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |           pp512 |        131.87 ± 0.46 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp2048 |        387.88 ± 1.84 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |          pp4096 |        562.94 ± 3.09 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | ROCm       |  99 |        999 |    4096 |     4096 |  1 |        512 |           tg256 |         15.40 ± 0.02 |

build: fd1c0ec3f (8834)

## MiniMaxAI_MiniMax-M2.7-IQ4_XS-00001-of-00004 · Vulkan
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_batch | n_ubatch |     sm | fa |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | ------: | -------: | -----: | -: | ---------: | --------------: | -------------------: |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |           pp512 |         49.32 ± 0.22 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |          pp2048 |        155.18 ± 0.18 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |          pp4096 |        254.71 ± 8.46 |
| minimax-m2 230B.A10B IQ4_XS - 4.25 bpw | 113.99 GiB |   228.69 B | Vulkan     |  99 |        999 |    4096 |     4096 |   none |  1 |        512 |           tg256 |         10.92 ± 0.01 |

build: fd1c0ec3f (8834)


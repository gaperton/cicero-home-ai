## Q4_K_XL

### ROCm

gaperton@WhiteSwan:~/data/cicero-home-ai$ RADV_DEBUG=nocompute ./llama.cpp-rocm/llama-bench -m models/Qwen3.5-27B-UD-Q4_K_XL.gguf -ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |   none |  1 |           pp512 |       1133.20 ± 0.11 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |   none |  1 |          pp2048 |       1093.98 ± 4.95 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |   none |  1 |          pp4096 |       1052.74 ± 3.81 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |   none |  1 |           tg256 |         25.83 ± 0.03 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |           pp512 |       1091.62 ± 0.83 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |          pp2048 |       1677.00 ± 0.17 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |          pp4096 |       1799.55 ± 4.79 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |           tg256 |         23.98 ± 1.52 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |    row |  1 |           pp512 |        645.47 ± 1.45 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |    row |  1 |          pp2048 |        684.96 ± 0.18 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |    row |  1 |          pp4096 |        670.90 ± 0.11 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | ROCm       |  99 |    row |  1 |           tg256 |         26.59 ± 0.02 |

build: 5d14e5d19 (8797)

### Vulkan

gaperton@WhiteSwan:~/data/cicero-home-ai$ RADV_DEBUG=nocompute ./llama.cpp/llama-bench -m models/Qwen3.5-27B-UD-Q4_K_XL.gguf -ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |           pp512 |        937.04 ± 0.74 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |          pp2048 |        927.28 ± 2.05 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |          pp4096 |        901.43 ± 2.88 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |           tg256 |         30.99 ± 0.01 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |           pp512 |       900.14 ± 11.26 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |          pp2048 |       1422.26 ± 0.84 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |          pp4096 |      1375.87 ± 42.58 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |           tg256 |         21.20 ± 0.71 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |           pp512 |        914.80 ± 0.32 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |          pp2048 |       1435.30 ± 4.79 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |          pp4096 |       1406.95 ± 3.93 |
| qwen35 27B Q4_K - Medium       |  16.40 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |           tg256 |         21.30 ± 0.14 |

build: 5d14e5d19 (8797)

## Q5_K_XL

### ROCm

gaperton@WhiteSwan:~/data/cicero-home-ai$ RADV_DEBUG=nocompute ./llama.cpp-rocm/llama-bench -m models/Qwen3.5-27B-UD-Q5_K_XL.gguf -ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |   none |  1 |           pp512 |        977.71 ± 0.03 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |   none |  1 |          pp2048 |        949.40 ± 1.65 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |   none |  1 |          pp4096 |        910.25 ± 3.35 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |   none |  1 |           tg256 |         24.01 ± 0.06 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |           pp512 |        935.10 ± 2.89 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |          pp2048 |       1459.47 ± 1.85 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |          pp4096 |       1572.04 ± 1.66 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |           tg256 |         21.65 ± 1.26 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |    row |  1 |           pp512 |        618.26 ± 1.43 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |    row |  1 |          pp2048 |        658.63 ± 0.55 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |    row |  1 |          pp4096 |        645.54 ± 0.10 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | ROCm       |  99 |    row |  1 |           tg256 |         25.62 ± 0.02 |

build: 5d14e5d19 (8797)

### Vulkan

gaperton@WhiteSwan:~/data/cicero-home-ai$ RADV_DEBUG=nocompute ./llama.cpp/llama-bench -m models/Qwen3.5-27B-UD-Q5_K_XL.gguf -ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |           pp512 |        909.22 ± 0.82 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |          pp2048 |        899.18 ± 2.18 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |          pp4096 |        877.55 ± 1.69 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |           tg256 |         27.90 ± 0.00 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |           pp512 |        884.37 ± 3.31 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |          pp2048 |       1387.55 ± 1.37 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |          pp4096 |       1366.96 ± 2.72 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |           tg256 |         20.62 ± 0.05 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |           pp512 |        894.60 ± 2.46 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |          pp2048 |       1394.51 ± 0.91 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |          pp4096 |       1369.00 ± 2.88 |
| qwen35 27B Q5_K - Medium       |  18.78 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |           tg256 |         21.23 ± 0.49 |

build: 5d14e5d19 (8797)

## Q6_K_XL

### ROCm

gaperton@WhiteSwan:~/data/cicero-home-ai$ RADV_DEBUG=nocompute ./llama.cpp-rocm/llama-bench -m models/Qwen3.5-27B-UD-Q6_K_XL.gguf -ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row
ggml_cuda_init: found 2 ROCm devices (Total VRAM: 65248 MiB):
  Device 0: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
  Device 1: AMD Radeon AI PRO R9700, gfx1201 (0x1201), VMM: no, Wave Size: 32, VRAM: 32624 MiB
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |   none |  1 |           pp512 |        812.15 ± 0.67 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |   none |  1 |          pp2048 |        790.42 ± 1.58 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |   none |  1 |          pp4096 |        759.47 ± 2.52 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |   none |  1 |           tg256 |         20.36 ± 0.00 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |           pp512 |        782.48 ± 3.52 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |          pp2048 |       1192.69 ± 0.57 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |          pp4096 |       1286.48 ± 0.14 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |  layer |  1 |           tg256 |         19.37 ± 1.18 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |    row |  1 |           pp512 |        421.74 ± 0.22 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |    row |  1 |          pp2048 |        445.79 ± 0.07 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |    row |  1 |          pp4096 |        439.97 ± 0.12 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | ROCm       |  99 |    row |  1 |           tg256 |         23.10 ± 0.04 |

build: 5d14e5d19 (8797)

### Vulkan

gaperton@WhiteSwan:~/data/cicero-home-ai$ RADV_DEBUG=nocompute ./llama.cpp/llama-bench -m models/Qwen3.5-27B-UD-Q6_K_XL.gguf -ngl 99 -fa 1 -p 512,2048,4096 -n 256 -r 2 -sm none,layer,row
WARNING: radv is not a conformant Vulkan implementation, testing use only.
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon AI PRO R9700 (RADV GFX1201) (radv) | uma: 0 | fp16: 1 | bf16: 0 | warp size: 64 | shared memory: 65536 | int dot: 0 | matrix cores: KHR_coopmat
| model                          |       size |     params | backend    | ngl |     sm | fa |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | -----: | -: | --------------: | -------------------: |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |           pp512 |        893.55 ± 0.92 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |          pp2048 |        882.68 ± 2.52 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |          pp4096 |        861.86 ± 2.46 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |   none |  1 |           tg256 |         22.66 ± 0.00 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |           pp512 |       849.69 ± 29.09 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |          pp2048 |       1355.69 ± 1.29 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |          pp4096 |       1339.64 ± 0.15 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |  layer |  1 |           tg256 |         18.38 ± 0.43 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |           pp512 |        872.57 ± 6.25 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |          pp2048 |      1330.14 ± 45.49 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |          pp4096 |       1335.03 ± 6.18 |
| qwen35 27B Q6_K                |  23.90 GiB |    26.90 B | Vulkan     |  99 |    row |  1 |           tg256 |         18.41 ± 0.26 |

build: 5d14e5d19 (8797)

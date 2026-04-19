# single fit-moe UD-Q5_K_XL gemma-4-26B-A4B-it 2026-04-19 16:40:51 EDT

| | |
|---|---|
| **Model** | gemma-4-26B-A4B-it |
| **Quant** | UD-Q5_K_XL |
| **Scope** | single |
| **Mode** | fit-moe |
| **Timestamp** | 2026-04-19 16:40:51 EDT |
| **Detail** | full VRAM with --n-cpu-moe sweep |
| **pp** | 512,2048 |
| **tg** | 256 |
| **ubatch** | 512,1024,2048 |

## Backend: rocm

| | |
|---|---|
| **GPU 0** | AMD Radeon AI PRO R9700 (31 GiB) |
| **GPU 1** | AMD Radeon AI PRO R9700 (31 GiB) |
| **RAM** | 126 GiB |
| **Kernel** | 6.17.0-20-generic |
| **llama.cpp** | 23b8cc499 (2026-04-18) |


### n_cpu_moe=0,4,8,16,32,64

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          0 |      512 |   none |           pp512 |        575.87 ± 3.80 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          0 |      512 |   none |          pp2048 |        599.08 ± 9.11 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          0 |      512 |   none |           tg256 |         72.04 ± 0.38 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          0 |     1024 |   none |           pp512 |       608.26 ± 20.53 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          0 |     1024 |   none |          pp2048 |      1115.29 ± 35.31 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          0 |     1024 |   none |           tg256 |         71.68 ± 0.88 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          0 |     2048 |   none |           pp512 |       608.38 ± 19.48 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          0 |     2048 |   none |          pp2048 |      1908.18 ± 45.33 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          0 |     2048 |   none |           tg256 |         71.91 ± 0.32 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          4 |      512 |   none |           pp512 |        513.48 ± 8.15 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          4 |      512 |   none |          pp2048 |       483.03 ± 12.26 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          4 |      512 |   none |           tg256 |         56.14 ± 0.10 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          4 |     1024 |   none |           pp512 |       511.38 ± 10.95 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          4 |     1024 |   none |          pp2048 |       945.36 ± 15.44 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          4 |     1024 |   none |           tg256 |         56.25 ± 0.73 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          4 |     2048 |   none |           pp512 |       510.41 ± 11.51 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          4 |     2048 |   none |          pp2048 |      1670.86 ± 75.73 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          4 |     2048 |   none |           tg256 |         56.46 ± 0.42 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          8 |      512 |   none |           pp512 |        445.26 ± 0.51 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          8 |      512 |   none |          pp2048 |        440.25 ± 1.10 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          8 |      512 |   none |           tg256 |         43.39 ± 1.09 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          8 |     1024 |   none |           pp512 |        438.22 ± 6.88 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          8 |     1024 |   none |          pp2048 |        822.92 ± 4.52 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          8 |     1024 |   none |           tg256 |         43.63 ± 0.88 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          8 |     2048 |   none |           pp512 |        439.09 ± 6.42 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          8 |     2048 |   none |          pp2048 |      1465.12 ± 51.93 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |          8 |     2048 |   none |           tg256 |         43.47 ± 1.07 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         16 |      512 |   none |           pp512 |        359.36 ± 4.09 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         16 |      512 |   none |          pp2048 |        355.18 ± 5.51 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         16 |      512 |   none |           tg256 |         31.20 ± 0.93 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         16 |     1024 |   none |           pp512 |       359.25 ± 11.71 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         16 |     1024 |   none |          pp2048 |       655.74 ± 11.98 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         16 |     1024 |   none |           tg256 |         28.39 ± 0.61 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         16 |     2048 |   none |           pp512 |        344.37 ± 3.71 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         16 |     2048 |   none |          pp2048 |       1134.73 ± 9.60 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         16 |     2048 |   none |           tg256 |         30.05 ± 1.44 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         32 |      512 |   none |           pp512 |        252.70 ± 4.74 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         32 |      512 |   none |          pp2048 |        261.05 ± 6.46 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         32 |      512 |   none |           tg256 |         21.95 ± 0.94 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         32 |     1024 |   none |           pp512 |        262.11 ± 3.20 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         32 |     1024 |   none |          pp2048 |        494.34 ± 6.73 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         32 |     1024 |   none |           tg256 |         22.46 ± 0.45 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         32 |     2048 |   none |           pp512 |        270.94 ± 0.96 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         32 |     2048 |   none |          pp2048 |       890.14 ± 14.63 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         32 |     2048 |   none |           tg256 |         22.39 ± 0.25 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         64 |      512 |   none |           pp512 |        268.71 ± 4.83 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         64 |      512 |   none |          pp2048 |        267.28 ± 1.35 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         64 |      512 |   none |           tg256 |         22.50 ± 0.23 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         64 |     1024 |   none |           pp512 |        268.71 ± 1.89 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         64 |     1024 |   none |          pp2048 |       488.67 ± 13.40 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         64 |     1024 |   none |           tg256 |         22.34 ± 0.65 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         64 |     2048 |   none |           pp512 |        264.43 ± 4.89 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         64 |     2048 |   none |          pp2048 |       883.28 ± 12.70 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |         64 |     2048 |   none |           tg256 |         22.53 ± 0.36 |

build: fd1c0ec3f (8834)

## Backend: vulkan

| | |
|---|---|
| **GPU 0** | AMD Radeon AI PRO R9700 (RADV GFX1201) (31 GiB) |
| **GPU 1** | AMD Radeon AI PRO R9700 (RADV GFX1201) (31 GiB) |
| **RAM** | 126 GiB |
| **Kernel** | 6.17.0-20-generic |
| **llama.cpp** | 23b8cc499 (2026-04-18) |


### n_cpu_moe=0,4,8,16,32,64

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          0 |      512 |   none |           pp512 |     2970.63 ± 157.02 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          0 |      512 |   none |          pp2048 |      2919.32 ± 10.38 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          0 |      512 |   none |           tg256 |        112.42 ± 0.57 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          0 |     1024 |   none |           pp512 |      2985.22 ± 30.14 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          0 |     1024 |   none |          pp2048 |      3158.04 ± 12.18 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          0 |     1024 |   none |           tg256 |        112.12 ± 0.43 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          0 |     2048 |   none |           pp512 |      2895.40 ± 12.64 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          0 |     2048 |   none |          pp2048 |      3262.37 ± 11.35 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          0 |     2048 |   none |           tg256 |        112.01 ± 0.45 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          4 |      512 |   none |           pp512 |       902.38 ± 28.10 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          4 |      512 |   none |          pp2048 |      1069.11 ± 17.40 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          4 |      512 |   none |           tg256 |         71.01 ± 0.72 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          4 |     1024 |   none |           pp512 |      1062.26 ± 52.02 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          4 |     1024 |   none |          pp2048 |      1610.36 ± 11.31 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          4 |     1024 |   none |           tg256 |         70.76 ± 0.27 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          4 |     2048 |   none |           pp512 |      1045.47 ± 49.41 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          4 |     2048 |   none |          pp2048 |      2132.35 ± 21.89 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          4 |     2048 |   none |           tg256 |         70.68 ± 0.69 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          8 |      512 |   none |           pp512 |       622.29 ± 30.31 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          8 |      512 |   none |          pp2048 |       677.22 ± 13.18 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          8 |      512 |   none |           tg256 |         48.53 ± 0.18 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          8 |     1024 |   none |           pp512 |        641.34 ± 5.87 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          8 |     1024 |   none |          pp2048 |      1073.01 ± 39.20 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          8 |     1024 |   none |           tg256 |         48.47 ± 0.13 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          8 |     2048 |   none |           pp512 |       652.50 ± 14.99 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          8 |     2048 |   none |          pp2048 |      1533.75 ± 12.07 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |          8 |     2048 |   none |           tg256 |         48.49 ± 0.16 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         16 |      512 |   none |           pp512 |       427.85 ± 14.35 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         16 |      512 |   none |          pp2048 |        424.34 ± 9.33 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         16 |      512 |   none |           tg256 |         34.42 ± 0.16 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         16 |     1024 |   none |           pp512 |       437.56 ± 31.08 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         16 |     1024 |   none |          pp2048 |       688.59 ± 32.36 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         16 |     1024 |   none |           tg256 |         34.34 ± 0.15 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         16 |     2048 |   none |           pp512 |       429.02 ± 19.24 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         16 |     2048 |   none |          pp2048 |      1107.67 ± 27.59 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         16 |     2048 |   none |           tg256 |         34.40 ± 0.16 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         32 |      512 |   none |           pp512 |        250.15 ± 9.86 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         32 |      512 |   none |          pp2048 |        256.79 ± 4.11 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         32 |      512 |   none |           tg256 |         23.14 ± 0.04 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         32 |     1024 |   none |           pp512 |        254.46 ± 9.62 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         32 |     1024 |   none |          pp2048 |        436.85 ± 1.64 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         32 |     1024 |   none |           tg256 |         23.08 ± 0.08 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         32 |     2048 |   none |           pp512 |       254.03 ± 11.47 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         32 |     2048 |   none |          pp2048 |        714.73 ± 1.59 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         32 |     2048 |   none |           tg256 |         23.10 ± 0.06 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         64 |      512 |   none |           pp512 |        250.67 ± 4.97 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         64 |      512 |   none |          pp2048 |        256.59 ± 5.38 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         64 |      512 |   none |           tg256 |         23.17 ± 0.05 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         64 |     1024 |   none |           pp512 |        250.85 ± 3.75 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         64 |     1024 |   none |          pp2048 |        431.53 ± 3.44 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         64 |     1024 |   none |           tg256 |         23.13 ± 0.08 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         64 |     2048 |   none |           pp512 |        245.00 ± 4.31 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         64 |     2048 |   none |          pp2048 |       706.77 ± 14.00 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |         64 |     2048 |   none |           tg256 |         23.16 ± 0.02 |

build: fd1c0ec3f (8834)

=== Done ===

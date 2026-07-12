# single no-fit-moe UD-Q5_K_XL gemma-4-26B-A4B-it 2026-04-19 17:13:19 EDT

| | |
|---|---|
| **Model** | gemma-4-26B-A4B-it |
| **Quant** | UD-Q5_K_XL |
| **Scope** | single |
| **Mode** | no-fit-moe |
| **Timestamp** | 2026-04-19 17:13:19 EDT |
| **Detail** | --n-cpu-moe 999, run without and with --fit-target |
| **pp** | 512,2048 |
| **tg** | 256 |
| **ubatch** | 512,1024,2048 |
| **fit-target** | 512 MiB |
| **n-cpu-moe** | 999 |

## Backend: rocm

| | |
|---|---|
| **GPU 0** | AMD Radeon AI PRO R9700 (31 GiB) |
| **GPU 1** | AMD Radeon AI PRO R9700 (31 GiB) |
| **RAM** | 126 GiB |
| **Kernel** | 6.17.0-20-generic |
| **llama.cpp** | 23b8cc499 (2026-04-18) |


### no-fit-target n_cpu_moe=999

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |   none |           pp512 |        267.75 ± 4.79 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |   none |          pp2048 |        253.22 ± 3.38 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |   none |           tg256 |         21.15 ± 0.09 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |   none |           pp512 |        264.03 ± 3.52 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |   none |          pp2048 |        470.19 ± 4.14 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |   none |           tg256 |         21.18 ± 0.03 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |   none |           pp512 |        254.47 ± 3.14 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |   none |          pp2048 |        848.91 ± 6.40 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |   none |           tg256 |         20.95 ± 0.05 |

build: fd1c0ec3f (8834)


### fit-target=512 n_cpu_moe=999

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | ---------: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |   none |        512 |           pp512 |        609.63 ± 3.19 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |   none |        512 |          pp2048 |        584.89 ± 1.53 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |   none |        512 |           tg256 |         72.10 ± 0.08 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |   none |        512 |           pp512 |       604.56 ± 10.31 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |   none |        512 |          pp2048 |       1070.73 ± 2.97 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |   none |        512 |           tg256 |         71.97 ± 0.20 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |   none |        512 |           pp512 |        611.47 ± 2.32 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |   none |        512 |          pp2048 |       1919.92 ± 8.43 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |   none |        512 |           tg256 |         71.93 ± 0.22 |

build: fd1c0ec3f (8834)

## Backend: vulkan

| | |
|---|---|
| **GPU 0** | AMD Radeon AI PRO R9700 (RADV GFX1201) (31 GiB) |
| **GPU 1** | AMD Radeon AI PRO R9700 (RADV GFX1201) (31 GiB) |
| **RAM** | 126 GiB |
| **Kernel** | 6.17.0-20-generic |
| **llama.cpp** | 23b8cc499 (2026-04-18) |


### no-fit-target n_cpu_moe=999

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |   none |           pp512 |        251.14 ± 7.71 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |   none |          pp2048 |        250.31 ± 5.46 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |   none |           tg256 |         23.18 ± 0.06 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |   none |           pp512 |        261.28 ± 8.96 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |   none |          pp2048 |       422.08 ± 10.18 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |   none |           tg256 |         23.11 ± 0.10 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |   none |           pp512 |       230.45 ± 10.45 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |   none |          pp2048 |       698.88 ± 18.01 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |   none |           tg256 |         23.12 ± 0.07 |

build: fd1c0ec3f (8834)


### fit-target=512 n_cpu_moe=999

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | ---------: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |   none |        512 |           pp512 |     2995.42 ± 151.12 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |   none |        512 |          pp2048 |      2959.43 ± 10.44 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |   none |        512 |           tg256 |        112.38 ± 1.55 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |   none |        512 |           pp512 |     2986.14 ± 151.38 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |   none |        512 |          pp2048 |      3232.57 ± 14.38 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |   none |        512 |           tg256 |        112.69 ± 0.19 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |   none |        512 |           pp512 |      2983.09 ± 35.06 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |   none |        512 |          pp2048 |       3322.96 ± 8.01 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |   none |        512 |           tg256 |        112.85 ± 0.35 |

build: fd1c0ec3f (8834)

=== Done ===

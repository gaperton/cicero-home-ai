# All GPUs No-Fit vs Fit-Target — gemma-4-26B-A4B-it (UD-Q5_K_XL)

Uses layer split across all visible GPUs with `-sm layer`. Compares a heavy MoE CPU-offload setup with and without automatic fit-target placement.

- Run time: 2026-04-19 17:28:37 EDT
- Prompt sweep: `512,2048`
- Generation length: `256`
- Ubatch sweep: `512,1024,2048`
- Core bench flags: `-ngl 999 -fa on -r 3 -b 2048`
- MoE offload: `--n-cpu-moe 999`
- Fit target comparison: off vs `512 MiB`

| | |
|---|---|
| **Model** | gemma-4-26B-A4B-it |
| **Quant** | UD-Q5_K_XL |
| **Scope** | all |
| **Mode** | no-fit-moe |
| **Timestamp** | 2026-04-19 17:28:37 EDT |
| **Detail** | --n-cpu-moe 999, run without and with --fit-target |
| **pp** | 512,2048 |
| **tg** | 256 |
| **ubatch** | 512,1024,2048 |
| **fit-target** | 512 MiB |
| **n-cpu-moe** | 999 |

## ROCm

AMD ROCm backend.

| | |
|---|---|
| **GPU 0** | AMD Radeon AI PRO R9700 (31 GiB) |
| **GPU 1** | AMD Radeon AI PRO R9700 (31 GiB) |
| **RAM** | 126 GiB |
| **Kernel** | 6.17.0-20-generic |
| **llama.cpp** | 23b8cc499 (2026-04-18) |


### No Fit Target

Runs `--n-cpu-moe 999` without automatic fitting.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |           pp512 |        261.22 ± 9.93 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |          pp2048 |        264.09 ± 3.99 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |           tg256 |         22.28 ± 0.39 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |           pp512 |        268.36 ± 1.29 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |          pp2048 |        485.04 ± 2.91 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |           tg256 |         22.28 ± 0.07 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |           pp512 |        260.71 ± 2.71 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |          pp2048 |        865.16 ± 9.65 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |           tg256 |         22.48 ± 0.25 |

build: fd1c0ec3f (8834)


### With Fit Target 512 MiB

Runs `--n-cpu-moe 999` with `-fitt 512`.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | ---------: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |        512 |           pp512 |        620.61 ± 4.09 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |        512 |          pp2048 |        610.75 ± 1.19 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |      512 |        512 |           tg256 |         66.09 ± 1.64 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |        512 |           pp512 |        624.83 ± 1.33 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |        512 |          pp2048 |      1141.75 ± 23.71 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     1024 |        512 |           tg256 |         64.86 ± 3.27 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |        512 |           pp512 |        625.57 ± 1.90 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |        512 |          pp2048 |       2097.50 ± 4.15 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | ROCm       | 999 |        999 |     2048 |        512 |           tg256 |         67.08 ± 1.28 |

build: fd1c0ec3f (8834)

## Vulkan

Vulkan backend with `RADV_DEBUG=nocompute`.

| | |
|---|---|
| **GPU 0** | AMD Radeon AI PRO R9700 (RADV GFX1201) (31 GiB) |
| **GPU 1** | AMD Radeon AI PRO R9700 (RADV GFX1201) (31 GiB) |
| **RAM** | 126 GiB |
| **Kernel** | 6.17.0-20-generic |
| **llama.cpp** | 23b8cc499 (2026-04-18) |


### No Fit Target

Runs `--n-cpu-moe 999` without automatic fitting.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |           pp512 |        246.95 ± 7.09 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |          pp2048 |        242.23 ± 3.29 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |           tg256 |         20.60 ± 0.05 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |           pp512 |        250.45 ± 6.61 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |          pp2048 |        402.43 ± 5.97 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |           tg256 |         20.61 ± 0.08 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |           pp512 |        223.94 ± 9.81 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |          pp2048 |       649.17 ± 16.17 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |           tg256 |         20.65 ± 0.05 |

build: fd1c0ec3f (8834)


### With Fit Target 512 MiB

Runs `--n-cpu-moe 999` with `-fitt 512`.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | ---------: | --------------: | -------------------: |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |        512 |           pp512 |      2246.94 ± 77.83 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |        512 |          pp2048 |     4063.05 ± 142.00 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |      512 |        512 |           tg256 |         90.28 ± 0.09 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |        512 |           pp512 |     2329.27 ± 110.83 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |        512 |          pp2048 |     3408.81 ± 770.47 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     1024 |        512 |           tg256 |         90.12 ± 0.02 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |        512 |           pp512 |      2465.77 ± 53.53 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |        512 |          pp2048 |      3312.96 ± 39.70 |
| gemma4 26B.A4B Q5_K - Medium   |  19.75 GiB |    25.23 B | Vulkan     | 999 |        999 |     2048 |        512 |           tg256 |         90.24 ± 0.05 |

build: fd1c0ec3f (8834)

=== Done ===

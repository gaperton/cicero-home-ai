# Single GPU No-Fit vs Fit-Target — Qwen3.5-122B-A10B (UD-Q3_K_XL)

Forces the model onto one GPU with `-sm none -mg 0`. Compares a heavy MoE CPU-offload setup with and without automatic fit-target placement.

Purpose: test a hard placement case and show whether automatic fit-target placement recovers performance versus a naive CPU-offloaded setup.

- Run time: 2026-04-19 20:17:53 EDT
- Prompt sweep: `512,2048`
- Generation length: `256`
- Ubatch sweep: `512,1024,2048`
- Core bench flags: `-ngl 999 -fa on -r 3 -b 2048`
- MoE offload: `--n-cpu-moe 999`
- Fit target comparison: off vs `512 MiB`

## How To Read This Report

- `pp512` and `pp2048` are prompt-processing throughput tests; they show how fast the model consumes a 512-token or 2048-token prompt.
- `tg256` is token-generation throughput over 256 generated tokens; it is the closest metric here to interactive decoding speed.
- `n_ubatch` is the prompt microbatch size; larger values usually help prompt-processing throughput more than generation throughput.
- `n_cpu_moe` is the number of MoE experts forced to CPU RAM; higher values mean more CPU/RAM/PCIe involvement and usually lower speed.
- `fitt` means llama.cpp automatically adjusts placement to fit available VRAM while leaving the requested free-memory margin.

| | |
|---|---|
| **Model** | Qwen3.5-122B-A10B |
| **Quant** | UD-Q3_K_XL |
| **Scope** | single |
| **Mode** | no-fit-moe |
| **Timestamp** | 2026-04-19 20:17:53 EDT |
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

This is the control case for a difficult placement: it shows performance when the model is pushed toward CPU-offloaded MoE execution without help from fit-target placement.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |   none |           pp512 |        162.25 ± 3.22 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |   none |          pp2048 |        163.09 ± 0.42 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |   none |           tg256 |         14.42 ± 0.15 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |   none |           pp512 |        164.26 ± 2.48 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |   none |          pp2048 |        278.21 ± 2.66 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |   none |           tg256 |         14.44 ± 0.09 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |   none |           pp512 |        162.83 ± 1.33 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |   none |          pp2048 |        464.49 ± 4.72 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |   none |           tg256 |         14.44 ± 0.15 |

build: fd1c0ec3f (8834)


### With Fit Target 512 MiB

Runs `--n-cpu-moe 999` with `-fitt 512`.

This is the recovery case: compare it against the no-fit-target run to see whether llama.cpp's automatic placement makes a difficult model placement fast again.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |   none |        512 |           pp512 |        321.51 ± 3.86 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |   none |        512 |          pp2048 |        317.17 ± 2.65 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |   none |        512 |           tg256 |         20.82 ± 0.45 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |   none |        512 |           pp512 |        315.59 ± 7.85 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |   none |        512 |          pp2048 |        504.37 ± 6.14 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |   none |        512 |           tg256 |         20.81 ± 0.49 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |   none |        512 |           pp512 |        313.93 ± 5.02 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |   none |        512 |          pp2048 |        742.43 ± 5.88 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |   none |        512 |           tg256 |         20.30 ± 0.35 |

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

This is the control case for a difficult placement: it shows performance when the model is pushed toward CPU-offloaded MoE execution without help from fit-target placement.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |   none |           pp512 |         98.46 ± 2.04 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |   none |          pp2048 |         98.27 ± 1.55 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |   none |           tg256 |         14.59 ± 0.15 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |   none |           pp512 |         99.42 ± 3.94 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |   none |          pp2048 |        157.69 ± 2.34 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |   none |           tg256 |         14.55 ± 0.11 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |   none |           pp512 |         98.15 ± 1.95 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |   none |          pp2048 |        259.32 ± 1.84 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |   none |           tg256 |         14.57 ± 0.04 |

build: fd1c0ec3f (8834)


### With Fit Target 512 MiB

Runs `--n-cpu-moe 999` with `-fitt 512`.

This is the recovery case: compare it against the no-fit-target run to see whether llama.cpp's automatic placement makes a difficult model placement fast again.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |   none |        512 |           pp512 |        235.47 ± 1.65 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |   none |        512 |          pp2048 |        232.42 ± 0.92 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |   none |        512 |           tg256 |         20.80 ± 0.35 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |   none |        512 |           pp512 |        237.42 ± 3.90 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |   none |        512 |          pp2048 |       368.36 ± 21.66 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |   none |        512 |           tg256 |         20.77 ± 0.25 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |   none |        512 |           pp512 |        203.18 ± 2.35 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |   none |        512 |          pp2048 |        497.24 ± 4.21 |
| qwen35moe 122B.A10B Q3_K - Medium |  53.05 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |   none |        512 |           tg256 |         20.51 ± 0.35 |

build: fd1c0ec3f (8834)

=== Done ===

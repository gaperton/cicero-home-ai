# All GPUs No-Fit vs Fit-Target — Qwen3.5-122B-A10B (UD-Q4_K_XL)

Uses layer split across all visible GPUs with `-sm layer`. Compares a heavy MoE CPU-offload setup with and without automatic fit-target placement.

Purpose: test a hard placement case and show whether automatic fit-target placement recovers performance versus a naive CPU-offloaded setup.

- Run time: 2026-04-19 21:15:46 EDT
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
| **Quant** | UD-Q4_K_XL |
| **Scope** | all |
| **Mode** | no-fit-moe |
| **Timestamp** | 2026-04-19 21:15:46 EDT |
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

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |           pp512 |        115.60 ± 6.17 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |          pp2048 |        121.08 ± 0.99 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |           tg256 |         12.60 ± 0.04 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |           pp512 |        124.71 ± 1.18 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |          pp2048 |        211.39 ± 2.37 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |           tg256 |         12.60 ± 0.06 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |           pp512 |        123.23 ± 0.99 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |          pp2048 |        359.15 ± 1.85 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |           tg256 |         12.58 ± 0.05 |

build: fd1c0ec3f (8834)


### With Fit Target 512 MiB

Runs `--n-cpu-moe 999` with `-fitt 512`.

This is the recovery case: compare it against the no-fit-target run to see whether llama.cpp's automatic placement makes a difficult model placement fast again.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |        512 |           pp512 |        475.28 ± 9.57 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |        512 |          pp2048 |      364.96 ± 173.48 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |        512 |           tg256 |        19.51 ± 11.55 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |        512 |           pp512 |      319.62 ± 227.02 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |        512 |          pp2048 |      533.21 ± 293.42 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |        512 |           tg256 |         27.01 ± 0.01 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |        512 |           pp512 |       460.73 ± 10.40 |

[Thread debugging using libthread_db enabled]
Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
0x000074ff95d10813 in __GI___wait4 (pid=335822, stat_loc=0x0, options=0, usage=0x0) at ../sysdeps/unix/sysv/linux/wait4.c:30

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

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |           pp512 |         70.94 ± 0.67 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |          pp2048 |         71.11 ± 1.22 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |           tg256 |         11.60 ± 0.02 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |           pp512 |         71.46 ± 2.19 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |          pp2048 |        113.05 ± 0.94 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |           tg256 |         11.62 ± 0.07 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |           pp512 |         71.62 ± 1.82 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |          pp2048 |        184.87 ± 0.83 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |           tg256 |         11.60 ± 0.04 |

build: fd1c0ec3f (8834)


### With Fit Target 512 MiB

Runs `--n-cpu-moe 999` with `-fitt 512`.

This is the recovery case: compare it against the no-fit-target run to see whether llama.cpp's automatic placement makes a difficult model placement fast again.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |        512 |           pp512 |        353.37 ± 3.44 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |        512 |          pp2048 |        351.61 ± 3.33 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |        512 |           tg256 |         27.45 ± 0.33 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |        512 |           pp512 |       343.10 ± 18.55 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |        512 |          pp2048 |        491.54 ± 4.24 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |        512 |           tg256 |         25.03 ± 0.11 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |        512 |           pp512 |        319.99 ± 6.54 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |        512 |          pp2048 |        623.67 ± 6.67 |
| qwen35moe 122B.A10B Q4_K - Medium |  71.73 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |        512 |           tg256 |         26.94 ± 0.42 |

build: fd1c0ec3f (8834)

=== Done ===

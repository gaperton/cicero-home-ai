# All GPUs No-Fit vs Fit-Target — Qwen3.5-122B-A10B (UD-IQ4_XS)

Uses layer split across all visible GPUs with `-sm layer`. Compares a heavy MoE CPU-offload setup with and without automatic fit-target placement.

Purpose: test a hard placement case and show whether automatic fit-target placement recovers performance versus a naive CPU-offloaded setup.

- Run time: 2026-04-19 20:42:31 EDT
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
| **Quant** | UD-IQ4_XS |
| **Scope** | all |
| **Mode** | no-fit-moe |
| **Timestamp** | 2026-04-19 20:42:31 EDT |
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
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |           pp512 |        149.94 ± 3.40 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |          pp2048 |        145.83 ± 8.67 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |           tg256 |         13.60 ± 0.10 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |           pp512 |        154.57 ± 2.03 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |          pp2048 |        259.89 ± 2.09 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |           tg256 |         13.63 ± 0.05 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |           pp512 |        152.21 ± 0.89 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |          pp2048 |        426.32 ± 5.35 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |           tg256 |         13.68 ± 0.07 |

build: fd1c0ec3f (8834)


### With Fit Target 512 MiB

Runs `--n-cpu-moe 999` with `-fitt 512`.

This is the recovery case: compare it against the no-fit-target run to see whether llama.cpp's automatic placement makes a difficult model placement fast again.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |        512 |           pp512 |        810.28 ± 3.15 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |        512 |          pp2048 |       776.08 ± 24.88 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |      512 |        512 |           tg256 |         34.10 ± 1.57 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |        512 |           pp512 |        806.66 ± 8.16 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |        512 |          pp2048 |      1099.08 ± 14.90 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     1024 |        512 |           tg256 |         36.85 ± 0.38 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |        512 |           pp512 |       760.51 ± 30.35 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |        512 |          pp2048 |       1386.68 ± 3.98 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | ROCm       | 999 |        999 |     2048 |        512 |           tg256 |         36.96 ± 0.44 |

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

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | --------------: | -------------------: |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |           pp512 |         91.58 ± 2.55 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |          pp2048 |         90.09 ± 1.47 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |           tg256 |         12.36 ± 0.30 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |           pp512 |         88.65 ± 3.38 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |          pp2048 |        142.25 ± 1.04 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |           tg256 |         11.92 ± 0.24 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |           pp512 |         88.92 ± 1.88 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |          pp2048 |        225.14 ± 3.62 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |           tg256 |         12.30 ± 0.09 |

build: fd1c0ec3f (8834)


### With Fit Target 512 MiB

Runs `--n-cpu-moe 999` with `-fitt 512`.

This is the recovery case: compare it against the no-fit-target run to see whether llama.cpp's automatic placement makes a difficult model placement fast again.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |       fitt |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | ---------: | --------------: | -------------------: |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |        512 |           pp512 |       882.80 ± 52.13 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |        512 |          pp2048 |      1294.06 ± 11.35 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |      512 |        512 |           tg256 |         49.91 ± 0.01 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |        512 |           pp512 |       898.42 ± 11.34 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |        512 |          pp2048 |      1391.34 ± 40.51 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     1024 |        512 |           tg256 |         49.94 ± 0.06 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |        512 |           pp512 |       847.78 ± 96.48 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |        512 |          pp2048 |       1283.26 ± 5.33 |
| qwen35moe 122B.A10B IQ4_XS - 4.25 bpw |  56.08 GiB |   122.11 B | Vulkan     | 999 |        999 |     2048 |        512 |           tg256 |         49.91 ± 0.08 |

build: fd1c0ec3f (8834)

=== Done ===

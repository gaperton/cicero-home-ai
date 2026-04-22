# Single GPU MoE CPU-Offload Sweep — gemma-4-26B-A4B-it (UD-IQ4_XS)

Forces the model onto one GPU with `-sm none -mg 0`. Sweeps `--n-cpu-moe` to show how moving experts to CPU affects throughput.

Purpose: measure the cost of MoE expert offload and show how throughput changes as more experts are forced out of VRAM.

- Run time: 2026-04-21 21:15:53 EDT
- Prompt sweep: `512,2048`
- Generation length: `256`
- Ubatch sweep: `512,1024,2048`
- Core bench flags: `-ngl 999 -fa on -r 3 -b 2048`
- MoE sweep: `--n-cpu-moe 0,4,8,16,32,64`

## How To Read This Report

- `pp512` and `pp2048` are prompt-processing throughput tests; they show how fast the model consumes a 512-token or 2048-token prompt.
- `tg256` is token-generation throughput over 256 generated tokens; it is the closest metric here to interactive decoding speed.
- `n_ubatch` is the prompt microbatch size; larger values usually help prompt-processing throughput more than generation throughput.
- `n_cpu_moe` is the number of MoE experts forced to CPU RAM; higher values mean more CPU/RAM/PCIe involvement and usually lower speed.
- `fitt` means llama.cpp automatically adjusts placement to fit available VRAM while leaving the requested free-memory margin.

| | |
|---|---|
| **Model** | gemma-4-26B-A4B-it |
| **Quant** | UD-IQ4_XS |
| **Scope** | single |
| **Mode** | fit-moe |
| **Timestamp** | 2026-04-21 21:15:53 EDT |
| **Detail** | full VRAM with --n-cpu-moe sweep |
| **pp** | 512,2048 |
| **tg** | 256 |
| **ubatch** | 512,1024,2048 |

## ROCm

AMD ROCm backend.

| | |
|---|---|
| **GPU 0** | AMD Radeon AI PRO R9700 (31 GiB) |
| **GPU 1** | AMD Radeon AI PRO R9700 (31 GiB) |
| **RAM** | 126 GiB |
| **Kernel** | 6.17.0-20-generic |
| **llama.cpp** | 23b8cc499 (2026-04-18) |


### MoE CPU-Offload Sweep

Sweeping `--n-cpu-moe` across `0,4,8,16,32,64` while keeping the rest of the benchmark settings fixed.

This is the sensitivity test: it shows how much performance is lost as more MoE experts are forced into CPU RAM instead of staying resident in VRAM.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | --------------: | -------------------: |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          0 |      512 |   none |           pp512 |        577.27 ± 2.15 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          0 |      512 |   none |          pp2048 |        554.28 ± 3.71 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          0 |      512 |   none |           tg256 |         72.97 ± 0.33 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          0 |     1024 |   none |           pp512 |        572.65 ± 8.80 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          0 |     1024 |   none |          pp2048 |       1038.60 ± 9.29 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          0 |     1024 |   none |           tg256 |         72.82 ± 0.33 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          0 |     2048 |   none |           pp512 |        573.89 ± 7.55 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          0 |     2048 |   none |          pp2048 |      1790.98 ± 14.84 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          0 |     2048 |   none |           tg256 |         72.75 ± 0.33 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          4 |      512 |   none |           pp512 |        514.90 ± 1.13 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          4 |      512 |   none |          pp2048 |        498.78 ± 0.18 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          4 |      512 |   none |           tg256 |         58.49 ± 0.50 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          4 |     1024 |   none |           pp512 |        510.93 ± 3.54 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          4 |     1024 |   none |          pp2048 |        920.04 ± 3.60 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          4 |     1024 |   none |           tg256 |         58.23 ± 0.07 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          4 |     2048 |   none |           pp512 |        506.72 ± 5.47 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          4 |     2048 |   none |          pp2048 |      1608.35 ± 10.16 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          4 |     2048 |   none |           tg256 |         58.91 ± 0.44 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          8 |      512 |   none |           pp512 |        461.14 ± 2.54 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          8 |      512 |   none |          pp2048 |        450.07 ± 1.13 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          8 |      512 |   none |           tg256 |         46.33 ± 2.89 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          8 |     1024 |   none |           pp512 |        460.89 ± 1.67 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          8 |     1024 |   none |          pp2048 |        832.09 ± 1.71 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          8 |     1024 |   none |           tg256 |         48.21 ± 1.53 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          8 |     2048 |   none |           pp512 |        460.44 ± 1.66 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          8 |     2048 |   none |          pp2048 |       1469.58 ± 7.82 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |          8 |     2048 |   none |           tg256 |         46.65 ± 2.11 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         16 |      512 |   none |           pp512 |        392.61 ± 5.69 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         16 |      512 |   none |          pp2048 |        384.69 ± 2.82 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         16 |      512 |   none |           tg256 |         32.73 ± 0.22 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         16 |     1024 |   none |           pp512 |        394.13 ± 6.61 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         16 |     1024 |   none |          pp2048 |        703.05 ± 3.09 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         16 |     1024 |   none |           tg256 |         32.71 ± 0.63 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         16 |     2048 |   none |           pp512 |        395.52 ± 4.80 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         16 |     2048 |   none |          pp2048 |       1263.27 ± 1.76 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         16 |     2048 |   none |           tg256 |         33.14 ± 0.12 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         32 |      512 |   none |           pp512 |        311.09 ± 4.49 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         32 |      512 |   none |          pp2048 |        307.88 ± 2.26 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         32 |      512 |   none |           tg256 |         25.69 ± 0.03 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         32 |     1024 |   none |           pp512 |        314.59 ± 1.83 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         32 |     1024 |   none |          pp2048 |        559.67 ± 0.47 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         32 |     1024 |   none |           tg256 |         25.60 ± 0.15 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         32 |     2048 |   none |           pp512 |        314.76 ± 1.67 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         32 |     2048 |   none |          pp2048 |       1018.83 ± 1.96 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         32 |     2048 |   none |           tg256 |         25.68 ± 0.05 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         64 |      512 |   none |           pp512 |        310.64 ± 3.48 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         64 |      512 |   none |          pp2048 |        308.85 ± 2.77 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         64 |      512 |   none |           tg256 |         25.66 ± 0.10 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         64 |     1024 |   none |           pp512 |        315.22 ± 0.54 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         64 |     1024 |   none |          pp2048 |        559.64 ± 0.49 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         64 |     1024 |   none |           tg256 |         25.71 ± 0.07 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         64 |     2048 |   none |           pp512 |        312.67 ± 1.44 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         64 |     2048 |   none |          pp2048 |       1015.27 ± 7.79 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | ROCm       | 999 |         64 |     2048 |   none |           tg256 |         25.66 ± 0.04 |

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


### MoE CPU-Offload Sweep

Sweeping `--n-cpu-moe` across `0,4,8,16,32,64` while keeping the rest of the benchmark settings fixed.

This is the sensitivity test: it shows how much performance is lost as more MoE experts are forced into CPU RAM instead of staying resident in VRAM.

| model                          |       size |     params | backend    | ngl |  n_cpu_moe | n_ubatch |     sm |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ---------: | -------: | -----: | --------------: | -------------------: |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          0 |      512 |   none |           pp512 |      3071.64 ± 25.41 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          0 |      512 |   none |          pp2048 |       2946.14 ± 6.25 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          0 |      512 |   none |           tg256 |        120.94 ± 0.87 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          0 |     1024 |   none |           pp512 |      3026.90 ± 35.10 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          0 |     1024 |   none |          pp2048 |      3172.81 ± 23.20 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          0 |     1024 |   none |           tg256 |        120.67 ± 0.68 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          0 |     2048 |   none |           pp512 |      2927.22 ± 23.80 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          0 |     2048 |   none |          pp2048 |       3261.11 ± 6.58 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          0 |     2048 |   none |           tg256 |        120.38 ± 0.62 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          4 |      512 |   none |           pp512 |      1391.15 ± 62.12 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          4 |      512 |   none |          pp2048 |      1427.97 ± 18.13 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          4 |      512 |   none |           tg256 |         73.45 ± 1.06 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          4 |     1024 |   none |           pp512 |      1400.38 ± 40.67 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          4 |     1024 |   none |          pp2048 |      2010.18 ± 24.89 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          4 |     1024 |   none |           tg256 |         72.76 ± 1.24 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          4 |     2048 |   none |           pp512 |      1396.13 ± 65.59 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          4 |     2048 |   none |          pp2048 |      2496.55 ± 16.98 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          4 |     2048 |   none |           tg256 |         74.32 ± 1.04 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          8 |      512 |   none |           pp512 |       987.67 ± 43.99 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          8 |      512 |   none |          pp2048 |       979.52 ± 18.23 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          8 |      512 |   none |           tg256 |         50.92 ± 0.50 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          8 |     1024 |   none |           pp512 |       938.03 ± 25.69 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          8 |     1024 |   none |          pp2048 |      1449.71 ± 18.37 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          8 |     1024 |   none |           tg256 |         50.97 ± 0.17 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          8 |     2048 |   none |           pp512 |       951.35 ± 13.50 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          8 |     2048 |   none |          pp2048 |      1991.06 ± 24.39 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |          8 |     2048 |   none |           tg256 |         51.26 ± 0.65 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         16 |      512 |   none |           pp512 |       648.04 ± 25.24 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         16 |      512 |   none |          pp2048 |       634.06 ± 22.26 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         16 |      512 |   none |           tg256 |         37.93 ± 0.56 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         16 |     1024 |   none |           pp512 |       643.64 ± 47.98 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         16 |     1024 |   none |          pp2048 |      1004.11 ± 19.44 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         16 |     1024 |   none |           tg256 |         37.81 ± 0.48 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         16 |     2048 |   none |           pp512 |       653.44 ± 19.52 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         16 |     2048 |   none |          pp2048 |      1520.48 ± 35.34 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         16 |     2048 |   none |           tg256 |         38.13 ± 0.20 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         32 |      512 |   none |           pp512 |        395.96 ± 9.07 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         32 |      512 |   none |          pp2048 |        396.54 ± 8.60 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         32 |      512 |   none |           tg256 |         28.28 ± 0.07 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         32 |     1024 |   none |           pp512 |        387.66 ± 9.41 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         32 |     1024 |   none |          pp2048 |        662.51 ± 9.40 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         32 |     1024 |   none |           tg256 |         28.25 ± 0.21 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         32 |     2048 |   none |           pp512 |       398.75 ± 10.36 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         32 |     2048 |   none |          pp2048 |       1061.95 ± 4.02 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         32 |     2048 |   none |           tg256 |         28.28 ± 0.14 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         64 |      512 |   none |           pp512 |        393.53 ± 5.63 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         64 |      512 |   none |          pp2048 |       398.12 ± 14.70 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         64 |      512 |   none |           tg256 |         28.35 ± 0.25 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         64 |     1024 |   none |           pp512 |        391.25 ± 2.32 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         64 |     1024 |   none |          pp2048 |        666.70 ± 9.19 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         64 |     1024 |   none |           tg256 |         28.17 ± 0.30 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         64 |     2048 |   none |           pp512 |       380.19 ± 12.31 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         64 |     2048 |   none |          pp2048 |      1036.53 ± 19.61 |
| gemma4 26B.A4B IQ4_XS - 4.25 bpw |  12.48 GiB |    25.23 B | Vulkan     | 999 |         64 |     2048 |   none |           tg256 |         28.10 ± 0.11 |

build: fd1c0ec3f (8834)

=== Done ===

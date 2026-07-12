# Single GPU MoE CPU-Offload Sweep — Qwen3.6-35B-A3B (UD-Q5_K_XL)

Forces the model onto one GPU with `-sm none -mg 0`. Sweeps `--n-cpu-moe` to show how moving experts to CPU affects throughput.

Purpose: measure the cost of MoE expert offload and show how throughput changes as more experts are forced out of VRAM.

- Run time: 2026-04-19 18:11:55 EDT
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
| **Model** | Qwen3.6-35B-A3B |
| **Quant** | UD-Q5_K_XL |
| **Scope** | single |
| **Mode** | fit-moe |
| **Timestamp** | 2026-04-19 18:11:55 EDT |
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
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          0 |      512 |   none |           pp512 |     1312.27 ± 149.86 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          0 |      512 |   none |          pp2048 |      1383.16 ± 96.09 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          0 |      512 |   none |           tg256 |         72.13 ± 0.59 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          0 |     1024 |   none |           pp512 |      1233.60 ± 21.11 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          0 |     1024 |   none |          pp2048 |     2116.44 ± 125.03 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          0 |     1024 |   none |           tg256 |         71.98 ± 0.50 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          0 |     2048 |   none |           pp512 |      1232.81 ± 24.27 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          0 |     2048 |   none |          pp2048 |      2835.32 ± 58.20 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          0 |     2048 |   none |           tg256 |         71.91 ± 0.55 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          4 |      512 |   none |           pp512 |        985.58 ± 0.81 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          4 |      512 |   none |          pp2048 |       951.26 ± 29.61 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          4 |      512 |   none |           tg256 |         63.22 ± 0.61 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          4 |     1024 |   none |           pp512 |       885.25 ± 28.06 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          4 |     1024 |   none |          pp2048 |      1493.64 ± 41.25 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          4 |     1024 |   none |           tg256 |         63.35 ± 0.36 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          4 |     2048 |   none |           pp512 |       894.55 ± 39.72 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          4 |     2048 |   none |          pp2048 |      2285.71 ± 11.95 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          4 |     2048 |   none |           tg256 |         63.24 ± 0.40 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          8 |      512 |   none |           pp512 |       762.04 ± 18.99 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          8 |      512 |   none |          pp2048 |        765.90 ± 0.85 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          8 |      512 |   none |           tg256 |         56.19 ± 0.57 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          8 |     1024 |   none |           pp512 |       726.97 ± 31.46 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          8 |     1024 |   none |          pp2048 |      1249.55 ± 49.67 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          8 |     1024 |   none |           tg256 |         56.37 ± 0.51 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          8 |     2048 |   none |           pp512 |       718.70 ± 18.04 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          8 |     2048 |   none |          pp2048 |      1902.40 ± 61.89 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |          8 |     2048 |   none |           tg256 |         56.57 ± 0.25 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         16 |      512 |   none |           pp512 |        561.76 ± 8.62 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         16 |      512 |   none |          pp2048 |        551.18 ± 3.17 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         16 |      512 |   none |           tg256 |         44.44 ± 0.32 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         16 |     1024 |   none |           pp512 |        547.23 ± 7.55 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         16 |     1024 |   none |          pp2048 |       939.39 ± 13.44 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         16 |     1024 |   none |           tg256 |         44.52 ± 0.12 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         16 |     2048 |   none |           pp512 |       547.43 ± 18.91 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         16 |     2048 |   none |          pp2048 |      1486.97 ± 23.60 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         16 |     2048 |   none |           tg256 |         44.42 ± 0.27 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         32 |      512 |   none |           pp512 |        375.02 ± 4.05 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         32 |      512 |   none |          pp2048 |        367.32 ± 4.13 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         32 |      512 |   none |           tg256 |         32.82 ± 0.60 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         32 |     1024 |   none |           pp512 |        369.85 ± 9.26 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         32 |     1024 |   none |          pp2048 |        632.96 ± 9.23 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         32 |     1024 |   none |           tg256 |         32.84 ± 0.93 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         32 |     2048 |   none |           pp512 |        367.25 ± 5.63 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         32 |     2048 |   none |          pp2048 |       1061.90 ± 9.89 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         32 |     2048 |   none |           tg256 |         33.05 ± 0.69 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         64 |      512 |   none |           pp512 |       324.94 ± 17.71 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         64 |      512 |   none |          pp2048 |        317.67 ± 3.35 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         64 |      512 |   none |           tg256 |         29.37 ± 0.45 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         64 |     1024 |   none |           pp512 |        322.44 ± 6.81 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         64 |     1024 |   none |          pp2048 |        557.69 ± 5.37 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         64 |     1024 |   none |           tg256 |         29.01 ± 0.61 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         64 |     2048 |   none |           pp512 |        323.27 ± 9.09 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         64 |     2048 |   none |          pp2048 |       934.93 ± 13.83 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | ROCm       | 999 |         64 |     2048 |   none |           tg256 |         29.07 ± 0.17 |

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
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          0 |      512 |   none |           pp512 |      2826.25 ± 66.79 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          0 |      512 |   none |          pp2048 |      2768.96 ± 11.67 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          0 |      512 |   none |           tg256 |        129.75 ± 0.39 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          0 |     1024 |   none |           pp512 |       2775.72 ± 9.21 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          0 |     1024 |   none |          pp2048 |      3252.20 ± 30.89 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          0 |     1024 |   none |           tg256 |        129.37 ± 0.17 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          0 |     2048 |   none |           pp512 |      2741.04 ± 15.51 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          0 |     2048 |   none |          pp2048 |      3471.48 ± 10.72 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          0 |     2048 |   none |           tg256 |        129.34 ± 0.26 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          4 |      512 |   none |           pp512 |        924.39 ± 6.77 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          4 |      512 |   none |          pp2048 |      1096.00 ± 14.91 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          4 |      512 |   none |           tg256 |         91.46 ± 0.96 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          4 |     1024 |   none |           pp512 |      1109.33 ± 22.74 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          4 |     1024 |   none |          pp2048 |      1626.10 ± 37.21 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          4 |     1024 |   none |           tg256 |         91.56 ± 0.08 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          4 |     2048 |   none |           pp512 |      1106.08 ± 23.73 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          4 |     2048 |   none |          pp2048 |       2259.38 ± 5.59 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          4 |     2048 |   none |           tg256 |         91.59 ± 0.37 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          8 |      512 |   none |           pp512 |        662.95 ± 6.91 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          8 |      512 |   none |          pp2048 |        746.78 ± 2.13 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          8 |      512 |   none |           tg256 |         65.73 ± 0.37 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          8 |     1024 |   none |           pp512 |       730.41 ± 23.23 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          8 |     1024 |   none |          pp2048 |      1169.33 ± 19.81 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          8 |     1024 |   none |           tg256 |         65.57 ± 0.81 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          8 |     2048 |   none |           pp512 |        726.42 ± 6.23 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          8 |     2048 |   none |          pp2048 |      1688.42 ± 70.72 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |          8 |     2048 |   none |           tg256 |         65.78 ± 0.48 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         16 |      512 |   none |           pp512 |       442.99 ± 11.37 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         16 |      512 |   none |          pp2048 |        463.34 ± 4.25 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         16 |      512 |   none |           tg256 |         49.59 ± 0.10 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         16 |     1024 |   none |           pp512 |        459.28 ± 8.22 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         16 |     1024 |   none |          pp2048 |       786.74 ± 16.66 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         16 |     1024 |   none |           tg256 |         49.52 ± 0.27 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         16 |     2048 |   none |           pp512 |        466.72 ± 4.48 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         16 |     2048 |   none |          pp2048 |      1225.91 ± 36.39 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         16 |     2048 |   none |           tg256 |         49.69 ± 0.13 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         32 |      512 |   none |           pp512 |        274.16 ± 0.98 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         32 |      512 |   none |          pp2048 |        269.98 ± 3.66 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         32 |      512 |   none |           tg256 |         34.51 ± 0.02 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         32 |     1024 |   none |           pp512 |        271.16 ± 3.76 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         32 |     1024 |   none |          pp2048 |        477.14 ± 6.26 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         32 |     1024 |   none |           tg256 |         34.35 ± 0.15 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         32 |     2048 |   none |           pp512 |        269.26 ± 4.04 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         32 |     2048 |   none |          pp2048 |        804.91 ± 2.45 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         32 |     2048 |   none |           tg256 |         34.36 ± 0.21 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         64 |      512 |   none |           pp512 |        230.97 ± 6.33 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         64 |      512 |   none |          pp2048 |        227.63 ± 1.00 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         64 |      512 |   none |           tg256 |         29.64 ± 0.15 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         64 |     1024 |   none |           pp512 |        233.91 ± 4.23 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         64 |     1024 |   none |          pp2048 |        407.11 ± 2.66 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         64 |     1024 |   none |           tg256 |         29.77 ± 0.17 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         64 |     2048 |   none |           pp512 |        228.98 ± 2.86 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         64 |     2048 |   none |          pp2048 |        705.15 ± 6.02 |
| qwen35moe 35B.A3B Q5_K - Medium |  24.76 GiB |    34.66 B | Vulkan     | 999 |         64 |     2048 |   none |           tg256 |         29.84 ± 0.11 |

build: fd1c0ec3f (8834)

=== Done ===

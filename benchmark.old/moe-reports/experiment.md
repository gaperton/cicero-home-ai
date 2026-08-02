#

## 1 GPU fit

Test model that completely fit single GPU VRAM.

- Flags: -fa 1 -r 3 -sm none -mg 0 --ubatch-size 512,2048,4096 --batch-size 4096 -n 256 -p 512,2048
- Basic test, common for dense and MoE. -ngl -1
- MoE test, measuring --n-cpu-moe 0, 4, 8, 16, 32, 64

Qwen 3.6 35B-A3B

Draw moe offload chart

## 1 GPU no fit

Test MoE model that doesn't fit single GPU VRAM, but fit 2 GPU VRAM.

122B-a10b

- --n-cpu-moe 999 with and without --fit-target 512

## 2 GPU fit

moe offload chart

## 2 GPU no fit

- --n-cpu-moe 999 with and without --fit-target 512

122B-a10b
M2.7
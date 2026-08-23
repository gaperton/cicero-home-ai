# Generic model benchmarks

These scripts benchmark the shared `../llama.cpp/` build independently of
Hindsight:

| File | What it measures |
| --- | --- |
| `bench.sh` | Raw `llama-bench` prefill/decode performance per model and quant on one GPU. |
| `bench-split.sh` | One-card, layer-split, and tensor-split performance for the same model. |

Generated reports go to `reports/`. Hindsight-specific load generation,
end-to-end tests, and reports are documented in
[`../hindsight/benchmark/`](../hindsight/benchmark/README.md).

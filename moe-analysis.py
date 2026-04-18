#!/usr/bin/env python3
"""
moe-analysis.py — Analyse llama-bench MoE markdown report.

Usage:
    python3 moe-analysis.py moe-reports/bench-moe-*.md
"""
import re
import sys
import glob
from pathlib import Path

try:
    import pandas as pd
    from scipy.stats import spearmanr
except ImportError:
    sys.exit("Install deps: pip install pandas scipy")


ROW_RE = re.compile(
    r"\|\s*[^|]+\|\s*[\d.]+ GiB\s*\|\s*[\d.]+ B\s*\|\s*\w+\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\w+)\s*\|\s*(pp\d+|tg\d+)\s*\|\s*([\d.]+)\s*±"
)

def parse_file(path):
    rows = []
    for line in Path(path).read_text().splitlines():
        m = ROW_RE.search(line)
        if m:
            ngl, n_cpu_moe, n_batch, n_ubatch, sm, test, speed = m.groups()
            rows.append({
                "n_cpu_moe": int(n_cpu_moe),
                "n_batch":   int(n_batch),
                "n_ubatch":  int(n_ubatch),
                "sm":        sm.strip(),
                "test":      test.strip(),
                "t_s":       float(speed),
            })
    return rows

def marginal(df, param, metric):
    return df[df.test == metric].groupby(param)["t_s"].mean().round(1)

def correlations(df, metric):
    sub = df[df.test == metric].copy()
    sub["sm_num"] = (sub["sm"] == "layer").astype(int)
    results = {}
    for col in ["n_cpu_moe", "n_batch", "n_ubatch", "sm_num"]:
        r, p = spearmanr(sub[col], sub["t_s"])
        results[col] = (round(r, 3), round(p, 4))
    return results

def print_section(title, df):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

    metrics = ["pp512", "pp2048", "tg256"]
    params  = ["n_cpu_moe", "n_ubatch", "n_batch", "sm"]

    print("\n--- Marginal means (t/s) ---")
    for param in params:
        print(f"\n  by {param}:")
        header = f"    {'value':>10}" + "".join(f"  {m:>8}" for m in metrics)
        print(header)
        vals = sorted(df[param].unique(), key=lambda x: (str(x) if isinstance(x, str) else x))
        for v in vals:
            row = f"    {str(v):>10}"
            for m in metrics:
                mean = df[(df[param] == v) & (df.test == m)]["t_s"].mean()
                row += f"  {mean:>8.1f}"
            print(row)

    print("\n--- Spearman correlation with t/s (r, p-value) ---")
    header = f"  {'param':>12}" + "".join(f"  {m:>18}" for m in metrics)
    print(header)
    param_labels = {"n_cpu_moe": "n_cpu_moe", "n_batch": "n_batch", "n_ubatch": "n_ubatch", "sm_num": "sm (layer=1)"}
    for col, label in param_labels.items():
        row = f"  {label:>12}"
        for m in metrics:
            r, p = correlations(df, m)[col]
            row += f"  {r:>+.3f} (p={p:.4f})"
        print(row)

def main():
    paths = sys.argv[1:] or sorted(glob.glob("moe-reports/*.md"))
    if not paths:
        sys.exit("No report files found.")

    all_rows = []
    for p in paths:
        rows = parse_file(p)
        if rows:
            print(f"Loaded {len(rows)} rows from {p}")
            all_rows.extend(rows)

    if not all_rows:
        sys.exit("No data rows parsed — check the file format.")

    df = pd.DataFrame(all_rows)
    print_section("All files combined" if len(paths) > 1 else paths[0], df)

if __name__ == "__main__":
    main()

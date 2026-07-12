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


# llama-bench omits constant columns; fitt column appears only when --fitt is used.
# Four possible row formats:
#   sm + fitt   | ngl | n_cpu_moe | n_ubatch | sm | fitt | test | t/s |
#   sm only     | ngl | n_cpu_moe | n_ubatch | sm | test | t/s |
#   fitt only   | ngl | n_cpu_moe | n_ubatch | fitt | test | t/s |
#   neither     | ngl | n_cpu_moe | n_ubatch | test | t/s |

_PRE  = r"\|\s*[^|]+\|\s*[\d.]+ GiB\s*\|\s*[\d.]+ B\s*\|\s*\w+\s*\|\s*\d+\s*\|(?:\s*\d+\s*\|)?\s*"
_NUM  = r"(\d+)\s*\|"
_SM   = r"\s*([a-zA-Z]\w*)\s*\|"
_TEST = r"\s*(pp\d+|tg\d+)\s*\|\s*([\d.]+)\s*±"

ROW_SM_FITT = re.compile(_PRE + _NUM + _SM + _NUM + _TEST)   # n_ubatch, sm, fitt, test, speed
ROW_SM      = re.compile(_PRE + _NUM + _SM + _TEST)           # n_ubatch, sm, test, speed
ROW_FITT    = re.compile(_PRE + _NUM + _NUM + _TEST)          # n_ubatch, fitt, test, speed
ROW_PLAIN   = re.compile(_PRE + _NUM + _TEST)                 # n_ubatch, test, speed

BACKEND_HDR = re.compile(r"##\s*Backend:\s*(\w+)")
SM_HDR      = re.compile(r"###\s*sm=(\w+)")
FITT_HDR    = re.compile(r"####.*-fitt\s+(\d+)")
NO_FITT_HDR = re.compile(r"####.*no\s+-?fitt", re.IGNORECASE)

def parse_file(path):
    rows = []
    current_backend = None
    current_sm      = None
    current_fitt    = 0      # 0 = no --fitt

    for line in Path(path).read_text().splitlines():
        if BACKEND_HDR.search(line):
            current_backend = BACKEND_HDR.search(line).group(1); continue
        if SM_HDR.search(line):
            current_sm = SM_HDR.search(line).group(1); continue
        if NO_FITT_HDR.search(line):
            current_fitt = 0; continue
        if FITT_HDR.search(line):
            current_fitt = int(FITT_HDR.search(line).group(1)); continue

        def row(n_ubatch, sm, fitt, test, speed):
            rows.append({
                "backend":   current_backend or "unknown",
                "n_cpu_moe": current_n_cpu_moe,
                "n_ubatch":  int(n_ubatch),
                "sm":        sm,
                "fitt":      int(fitt),
                "test":      test.strip(),
                "t_s":       float(speed),
            })

        # extract n_cpu_moe from the line directly (always present)
        nc = re.search(r"\|\s*\d+\s*\|\s*(\d+)\s*\|", line)
        if not nc:
            continue
        current_n_cpu_moe = int(nc.group(1))

        m = ROW_SM_FITT.search(line)
        if m:
            row(m.group(1), m.group(2).strip(), m.group(3), m.group(4), m.group(5)); continue
        m = ROW_SM.search(line)
        if m:
            row(m.group(1), m.group(2).strip(), current_fitt, m.group(3), m.group(4)); continue
        m = ROW_FITT.search(line)
        if m:
            row(m.group(1), current_sm or "none", m.group(2), m.group(3), m.group(4)); continue
        m = ROW_PLAIN.search(line)
        if m:
            row(m.group(1), current_sm or "none", current_fitt, m.group(2), m.group(3))
    return rows

def marginal(df, param, metric):
    return df[df.test == metric].groupby(param)["t_s"].mean().round(1)

def correlations(df, metric):
    sub = df[df.test == metric].copy()
    sub["sm_num"] = (sub["sm"] == "layer").astype(int)
    results = {}
    for col in ["n_cpu_moe", "n_ubatch", "fitt", "sm_num"]:
        r, p = spearmanr(sub[col], sub["t_s"])
        results[col] = (round(r, 3), round(p, 4))
    return results

def print_section(title, df):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

    metrics = ["pp512", "pp2048", "tg256"]
    has_fitt = df["fitt"].nunique() > 1
    params   = ["n_cpu_moe", "n_ubatch", "sm"] + (["fitt"] if has_fitt else [])

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
    param_labels = {"n_cpu_moe": "n_cpu_moe", "n_ubatch": "n_ubatch",
                    "fitt": "fitt", "sm_num": "sm (layer=1)"}
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

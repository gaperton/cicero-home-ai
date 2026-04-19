#!/usr/bin/env python3
"""
moe-charts.py — Generate PNG charts from llama-bench MoE markdown reports.

Usage:
    python3 moe-charts.py moe-reports/bench-moe-*.md
"""
import re
import sys
import glob
from pathlib import Path

try:
    import pandas as pd
    import matplotlib.pyplot as plt
    import matplotlib.ticker as ticker
except ImportError:
    sys.exit("Install deps: pip install pandas matplotlib --break-system-packages")

_PRE  = r"\|\s*[^|]+\|\s*[\d.]+ GiB\s*\|\s*[\d.]+ B\s*\|\s*\w+\s*\|\s*\d+\s*\|(?:\s*\d+\s*\|)?\s*"
_NUM  = r"(\d+)\s*\|"
_SM   = r"\s*([a-zA-Z]\w*)\s*\|"
_TEST = r"\s*(pp\d+|tg\d+)\s*\|\s*([\d.]+)\s*±"

ROW_SM_FITT = re.compile(_PRE + _NUM + _SM + _NUM + _TEST)
ROW_SM      = re.compile(_PRE + _NUM + _SM + _TEST)
ROW_FITT    = re.compile(_PRE + _NUM + _NUM + _TEST)
ROW_PLAIN   = re.compile(_PRE + _NUM + _TEST)

BACKEND_HDR = re.compile(r"##\s*Backend:\s*(\w+)")
SM_HDR      = re.compile(r"###\s*sm=(\w+)")
FITT_HDR    = re.compile(r"####.*-fitt\s+(\d+)")
NO_FITT_HDR = re.compile(r"####.*no\s+-?fitt", re.IGNORECASE)

def parse_file(path):
    rows = []
    current_backend = None
    current_sm      = None
    current_fitt    = 0

    for line in Path(path).read_text().splitlines():
        if BACKEND_HDR.search(line):
            current_backend = BACKEND_HDR.search(line).group(1); continue
        if SM_HDR.search(line):
            current_sm = SM_HDR.search(line).group(1); continue
        if NO_FITT_HDR.search(line):
            current_fitt = 0; continue
        if FITT_HDR.search(line):
            current_fitt = int(FITT_HDR.search(line).group(1)); continue

        nc = re.search(r"\|\s*\d+\s*\|\s*(\d+)\s*\|", line)
        if not nc:
            continue
        n_cpu_moe = int(nc.group(1))

        def make_row(n_ubatch, sm, fitt, test, speed):
            return {
                "backend":   current_backend or "unknown",
                "n_cpu_moe": n_cpu_moe,
                "n_ubatch":  int(n_ubatch),
                "sm":        sm,
                "fitt":      int(fitt),
                "test":      test.strip(),
                "t_s":       float(speed),
            }

        m = ROW_SM_FITT.search(line)
        if m:
            rows.append(make_row(m.group(1), m.group(2).strip(), m.group(3), m.group(4), m.group(5))); continue
        m = ROW_SM.search(line)
        if m:
            rows.append(make_row(m.group(1), m.group(2).strip(), current_fitt, m.group(3), m.group(4))); continue
        m = ROW_FITT.search(line)
        if m:
            rows.append(make_row(m.group(1), current_sm or "none", m.group(2), m.group(3), m.group(4))); continue
        m = ROW_PLAIN.search(line)
        if m:
            rows.append(make_row(m.group(1), current_sm or "none", current_fitt, m.group(2), m.group(3)))
    return rows

def setup_ax(ax, title, xlabel, ylabel):
    ax.set_title(title, fontsize=11, fontweight="bold")
    ax.set_xlabel(xlabel, fontsize=9)
    ax.set_ylabel(ylabel, fontsize=9)
    ax.grid(axis="y", linestyle="--", alpha=0.4)
    ax.spines[["top", "right"]].set_visible(False)
    ax.legend(fontsize=8)

def backend_ls(backend):
    return "--" if "ulkan" in backend else "-"

def plot_cpu_moe_effect(df, out_dir, tag):
    """n_cpu_moe vs t/s — ROCm solid, Vulkan dashed; color = sm × metric."""
    backends   = sorted(df["backend"].unique())
    sms        = sorted(df["sm"].unique())
    moe_labels = [str(v) for v in sorted(df["n_cpu_moe"].unique())]
    moe_x      = list(range(len(moe_labels)))
    colors     = plt.rcParams["axes.prop_cycle"].by_key()["color"]

    # Assign a color per (metric_short, sm) combination
    pp_combos = [(m, sm) for sm in sms for m in ["pp512", "pp2048"]]
    tg_combos = [(sm,)   for sm in sms]
    pp_color  = {k: colors[i % len(colors)] for i, k in enumerate(pp_combos)}
    tg_color  = {k: colors[i % len(colors)] for i, k in enumerate(tg_combos)}

    fig, axes = plt.subplots(1, 2, figsize=(11, 4))
    fig.suptitle("n_cpu_moe effect — ROCm solid, Vulkan dashed", fontsize=13, fontweight="bold")

    for backend in backends:
        bdf = df[df.backend == backend]
        ls  = backend_ls(backend)

        ax = axes[0]
        for sm in sms:
            for metric in ["pp512", "pp2048"]:
                sub = bdf[(bdf.test == metric) & (bdf.sm == sm)]
                if sub.empty: continue
                grp = sub.groupby("n_cpu_moe")["t_s"].mean()
                ys  = [grp.get(int(l), float("nan")) for l in moe_labels]
                ax.plot(moe_x, ys, marker="o", linestyle=ls,
                        color=pp_color[(metric, sm)],
                        label=f"{metric} sm={sm} ({backend})")

        ax = axes[1]
        for sm in sms:
            sub = bdf[(bdf.test == "tg256") & (bdf.sm == sm)]
            if sub.empty: continue
            grp = sub.groupby("n_cpu_moe")["t_s"].mean()
            ys  = [grp.get(int(l), float("nan")) for l in moe_labels]
            ax.plot(moe_x, ys, marker="o", linestyle=ls,
                    color=tg_color[(sm,)],
                    label=f"sm={sm} ({backend})")

    for ax, title in zip(axes, ["Prompt processing", "Token generation"]):
        ax.set_xticks(moe_x)
        ax.set_xticklabels(moe_labels)
        setup_ax(ax, title, "n_cpu_moe", "t/s")

    fig.tight_layout()
    path = out_dir / f"{tag}_cpu_moe.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"  {path}")

def plot_ubatch_effect(df, out_dir, tag):
    """n_ubatch vs pp2048 — ROCm solid, Vulkan dashed; color = n_cpu_moe."""
    backends = sorted(df["backend"].unique())
    sms      = sorted(df["sm"].unique())
    moe_vals = sorted(df["n_cpu_moe"].unique())
    colors   = plt.rcParams["axes.prop_cycle"].by_key()["color"]
    moe_color = {n: colors[i % len(colors)] for i, n in enumerate(moe_vals)}

    fig, axes = plt.subplots(1, max(len(sms), 1), figsize=(6 * max(len(sms), 1), 4), squeeze=False)
    fig.suptitle("ubatch effect on pp2048 — ROCm solid, Vulkan dashed", fontsize=13, fontweight="bold")

    for backend in backends:
        bdf = df[(df.backend == backend) & (df.test == "pp2048")]
        ls  = backend_ls(backend)
        for ax, sm in zip(axes[0], sms):
            sub = bdf[bdf.sm == sm]
            for n in moe_vals:
                grp = sub[sub.n_cpu_moe == n].groupby("n_ubatch")["t_s"].mean()
                if grp.empty: continue
                ax.plot(grp.index, grp.values, marker="o", linestyle=ls,
                        color=moe_color[n], label=f"n_cpu_moe={n} ({backend})")
            setup_ax(ax, f"sm={sm}", "n_ubatch", "t/s (pp2048)")

    fig.tight_layout()
    path = out_dir / f"{tag}_ubatch.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"  {path}")

def plot_backend_compare(df, out_dir, tag):
    """Side-by-side backend comparison at n_cpu_moe=0, best ubatch."""
    if df["backend"].nunique() < 2:
        return

    metrics  = ["pp512", "pp2048", "tg256"]
    titles   = ["Prompt 512 tokens", "Prompt 2048 tokens", "Generation 256 tokens"]
    backends = sorted(df["backend"].unique())
    sms      = sorted(df["sm"].unique())

    fig, axes = plt.subplots(1, 3, figsize=(14, 4))
    fig.suptitle("Backend comparison — n_cpu_moe=0, best ubatch per sm", fontsize=13, fontweight="bold")

    base = df[df.n_cpu_moe == 0]
    x    = range(len(sms))
    w    = 0.35

    for ax, metric, title in zip(axes, metrics, titles):
        for i, backend in enumerate(backends):
            means = []
            for sm in sms:
                val = base[(base.backend == backend) & (base.sm == sm) & (base.test == metric)]["t_s"].max()
                means.append(val)
            offset = (i - (len(backends) - 1) / 2) * w
            bars = ax.bar([xi + offset for xi in x], means, w, label=backend)
            ax.bar_label(bars, fmt="%.0f", fontsize=7, padding=2)

        ax.set_xticks(list(x))
        ax.set_xticklabels([f"sm={s}" for s in sms])
        setup_ax(ax, title, "", "t/s")

    fig.tight_layout()
    path = out_dir / f"{tag}_backend_compare.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"  {path}")

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
        sys.exit("No data rows parsed.")

    df      = pd.DataFrame(all_rows)
    out_dir = Path("moe-reports")
    tag     = Path(paths[0]).stem if len(paths) == 1 else "combined"

    print("Generating charts:")
    plot_cpu_moe_effect(df, out_dir, tag)
    plot_ubatch_effect(df, out_dir, tag)
    plot_backend_compare(df, out_dir, tag)
    print("Done.")

if __name__ == "__main__":
    main()

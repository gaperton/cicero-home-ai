"""Operation-level Hindsight benchmark: Retain / Recall / Reflect / Consolidation.

Mirrors the methodology recorded in
../experiments/2026-08-installation-and-tuning-log.md so the numbers are
comparable to the Gemma and Qwen tables: a bilingual three-item workload with an
exact access code, one warm-up workflow plus three measured ones, each on its own
disposable bank that is deleted afterwards.

A workflow only counts if it is *valid*: Recall must retrieve the code from a
Russian query, and Reflect must state the code. Timing a wrong answer is
meaningless -- that is what made the earlier Qwen comparison undefensible.

The production `hermes` bank is measured separately and READ-ONLY (Recall and
Reflect only), because the disposable banks are far too small to expose the
300-candidate rerank path that dominates real Recall latency.
"""
import json
import statistics
import time
import unicodedata
import urllib.error
import urllib.request

# gpt-oss renders the access code with typographic dashes and non-breaking spaces
# (e.g. "ORION‑7741"), so a naive `CODE in answer` check reports a correct
# answer as a failure. Normalise before comparing.
_PUNCT = {0x2010: "-", 0x2011: "-", 0x2012: "-", 0x2013: "-", 0x2014: "-",
          0x2212: "-", 0x00A0: " ", 0x202F: " ", 0x2009: " "}


def norm(s: str) -> str:
    return unicodedata.normalize("NFKC", (s or "")).translate(_PUNCT)

API = "http://127.0.0.1:8888/v1/default"
CODE = "ORION-7741"
WARMUP = 1
RUNS = 3

ITEMS = [
    {"content": f"Daniel's telescope access code is {CODE}. He keeps it in the observatory safe.",
     "context": "Personal equipment note"},
    {"content": "Анна водит собаку к ветеринару на улице Садовой по вторникам.",
     "context": "Расписание"},
    {"content": "The quarterly architecture review meets in the Aurora room on the third floor.",
     "context": "Meeting logistics"},
]
RU_QUERY = "Какой код доступа к телескопу у Даниэля?"


def req(method, path, body=None, timeout=400):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(API + path, data=data,
                               headers={"Content-Type": "application/json"}, method=method)
    t0 = time.time()
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            payload = resp.read()
    except urllib.error.HTTPError as e:
        return time.time() - t0, {"__error__": f"HTTP {e.code}", "__body__": e.read()[:300].decode("utf-8", "replace")}
    except Exception as e:
        return time.time() - t0, {"__error__": str(e)}
    el = time.time() - t0
    try:
        return el, json.loads(payload) if payload else {}
    except Exception:
        return el, {}


def texts_of(d):
    return " ".join((m.get("text") or "") for m in (d.get("memories") or d.get("results") or []))


def workflow(bank):
    """One full Retain -> Recall -> Reflect -> Consolidate cycle. Returns timings + validity."""
    req("PUT", f"/banks/{bank}", {"name": bank})
    out = {}

    out["retain"], d = req("POST", f"/banks/{bank}/memories", {"items": ITEMS})
    if "__error__" in d:
        return None, f"retain failed: {d}"

    out["recall"], d = req("POST", f"/banks/{bank}/memories/recall", {"query": RU_QUERY})
    if "__error__" in d:
        return None, f"recall failed: {d}"
    recall_ok = CODE in norm(texts_of(d))

    out["reflect"], d = req("POST", f"/banks/{bank}/reflect", {"query": RU_QUERY})
    if "__error__" in d:
        return None, f"reflect failed: {d}"
    answer = d.get("text") or d.get("answer") or ""
    reflect_ok = CODE in norm(answer)

    out["consolidation"], d = req("POST", f"/banks/{bank}/consolidate", {})
    if "__error__" in d:
        return None, f"consolidate failed: {d}"

    out["llm_heavy"] = out["retain"] + out["reflect"] + out["consolidation"]
    out["complete"] = sum(out[k] for k in ("retain", "recall", "reflect", "consolidation"))
    valid = recall_ok and reflect_ok
    return out, ("valid" if valid else f"INVALID (recall_ok={recall_ok} reflect_ok={reflect_ok}) answer={answer[:120]!r}")


def main():
    stamp = int(time.time())
    print(f"=== Disposable-bank workflow: {WARMUP} warm-up + {RUNS} measured ===\n")
    results, notes = [], []
    for i in range(WARMUP + RUNS):
        bank = f"bench-{stamp}-{i}"
        tag = "warmup" if i < WARMUP else f"run {i - WARMUP + 1}"
        try:
            out, status = workflow(bank)
        finally:
            req("DELETE", f"/banks/{bank}", timeout=120)
        if out is None:
            print(f"  {tag:8s} FAILED: {status}")
            notes.append((tag, status))
            continue
        print(f"  {tag:8s} retain={out['retain']:6.2f}s recall={out['recall']:5.2f}s "
              f"reflect={out['reflect']:6.2f}s consol={out['consolidation']:6.2f}s "
              f"complete={out['complete']:6.2f}s  [{status.split(' ')[0]}]")
        if status != "valid":
            notes.append((tag, status))
        if i >= WARMUP and status == "valid":
            results.append(out)

    if results:
        print(f"\n  {'operation':16s} {'runs':38s} {'median':>8s}")
        for op in ("retain", "recall", "reflect", "consolidation", "llm_heavy", "complete"):
            vals = [r[op] for r in results]
            runs = " / ".join(f"{v:.3f}" for v in vals)
            print(f"  {op:16s} {runs:38s} {statistics.median(vals):7.3f}s")
    else:
        print("\n  no valid measured workflows")

    print(f"\n=== Production bank `hermes` (read-only), {RUNS} runs ===\n")
    q = "Which two GPU models are installed in the cicero host?"
    for op, path, body in (("recall", "/banks/hermes/memories/recall", {"query": q}),
                           ("reflect", "/banks/hermes/reflect", {"query": q})):
        vals, ok = [], 0
        for _ in range(RUNS):
            el, d = req("POST", path, body)
            if "__error__" in d:
                print(f"  {op}: ERROR {d}")
                break
            vals.append(el)
            blob = texts_of(d) if op == "recall" else (d.get("text") or d.get("answer") or "")
            if "R9700" in norm(blob):
                ok += 1
        if vals:
            print(f"  {op:8s} {' / '.join(f'{v:.3f}' for v in vals):32s} median={statistics.median(vals):6.3f}s  correct={ok}/{len(vals)}")

    if notes:
        print("\n=== validity notes ===")
        for tag, s in notes:
            print(f"  {tag}: {s}")


if __name__ == "__main__":
    main()

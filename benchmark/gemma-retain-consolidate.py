"""Stress Retain + Consolidation only, on a disposable bank.

Reflect is deliberately never called. The point is to test the hypothesis that
Gemma's runaway is confined to the tool-call path: llm_info shows Retain uses
response_schema=FactExtractionResponse and Consolidation uses
_ConsolidationBatchResponse — both the response_format branch of common/chat.cpp,
whose grammar IS derived from the JSON schema and therefore bounded. Only Reflect
uses tool_choice, and only that path gets the unbounded generic `gemma4-dict`.

Writes to a throwaway bank and deletes it afterwards; the production `psychology`
bank is never mutated. Consolidation on a real bank rewrites real memories, so
that is not something to run casually.

Volume is the point: enough items, long and multi-fact enough, that generations
get into the 1000+ token range where google-deepmind/gemma#622 says collapse
appears — and enough memories that consolidation prompts approach the ~5.5k-8k
seen on `psychology`.
"""
import json
import statistics
import subprocess
import time
import urllib.error
import urllib.request

API = "http://127.0.0.1:8888/v1/default"
BANK = f"gemma-rc-{int(time.time())}"
BATCHES = 6


def req(method, path, body=None, timeout=400):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(API + path, data=data,
                               headers={"Content-Type": "application/json"}, method=method)
    t0 = time.time()
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            payload = resp.read()
    except urllib.error.HTTPError as e:
        return time.time() - t0, {"__error__": f"HTTP {e.code}",
                                  "__body__": e.read()[:300].decode("utf-8", "replace")}
    except Exception as e:
        return time.time() - t0, {"__error__": f"{type(e).__name__}: {e}"}
    el = time.time() - t0
    try:
        return el, json.loads(payload) if payload else {}
    except Exception:
        return el, {}


def psql(sql):
    out = subprocess.run(["psql", "--dbname", "hindsight", "-t", "-A", "-F", "|", "-c", sql],
                         capture_output=True, text=True)
    return [l for l in out.stdout.strip().split("\n") if l]


# Multi-fact, entity-dense, bilingual items — each should extract several facts,
# which is what pushes Retain generations long.
def items_for(n):
    return [
        {"content": f"Batch {n}: Daniel moved the quarterly architecture review from Tuesday to "
                    f"Thursday because Anna has recurring clinic appointments on Tuesday mornings. "
                    f"The review now meets in the Aurora room on the third floor at 14:00, and "
                    f"Priya took over the agenda from Marcus after the reorg.",
         "context": "Meeting logistics"},
        {"content": f"Партия {n}: Анна водит собаку к ветеринару на улице Садовой по вторникам. "
                    f"Они ходят пешком, так как собака боится машин. Ветеринара зовут Игорь, он "
                    f"работает там с 2019 года и обычно принимает после обеда.",
         "context": "Расписание"},
        {"content": f"Batch {n}: The observatory safe was rekeyed in March; Daniel keeps the "
                    f"telescope access code there, and only he and Priya know the new combination. "
                    f"Marcus objected to the change, arguing it slowed down night sessions, but "
                    f"the safety committee overruled him after the December incident.",
         "context": "Equipment and access"},
        {"content": f"Batch {n}: Priya prefers written updates over standups, reads them in the "
                    f"morning, and has said repeatedly that she finds interruptions during deep "
                    f"work more costly than a delayed answer. Daniel disagrees but has adapted.",
         "context": "Working preferences"},
    ]


def main():
    print(f"=== Gemma Retain + Consolidation stress (bank {BANK}, Reflect never called) ===\n")
    req("PUT", f"/banks/{BANK}", {"name": BANK})
    retains, consols = [], []
    failures = []
    try:
        for i in range(BATCHES):
            el, d = req("POST", f"/banks/{BANK}/memories", {"items": items_for(i)})
            if "__error__" in d:
                print(f"  batch {i}  RETAIN FAILED: {d}")
                failures.append(("retain", i, str(d)))
            else:
                retains.append(el)
                print(f"  batch {i}  retain={el:6.2f}s")

            el, d = req("POST", f"/banks/{BANK}/consolidate", {})
            if "__error__" in d:
                print(f"  batch {i}  CONSOLIDATE FAILED: {d}")
                failures.append(("consolidate", i, str(d)))
            else:
                consols.append(el)

        n_mem = psql(f"SELECT count(*) FROM memory_units WHERE bank_id='{BANK}';")
        print(f"\n  memories in bank: {n_mem[0] if n_mem else '?'}")
        if retains:
            print(f"  retain      median={statistics.median(retains):6.2f}s  max={max(retains):6.2f}s")
        if consols:
            print(f"  consolidate median={statistics.median(consols):6.2f}s  max={max(consols):6.2f}s")

        print("\n=== llm_requests for this bank ===\n")
        rows = psql(f"""
            SELECT operation, status, count(*), max(input_tokens), max(output_tokens),
                   max(duration_ms), count(*) FILTER (WHERE output_tokens > 1500)
            FROM llm_requests WHERE bank_id='{BANK}'
            GROUP BY 1,2 ORDER BY 1,2;""")
        print(f"  {'operation':16s} {'status':8s} {'n':>4s} {'max_in':>8s} {'max_out':>8s} {'max_ms':>8s} {'>1500tok':>9s}")
        for r in rows:
            op, st, n, mi, mo, ms, big = (r.split("|") + [""] * 7)[:7]
            print(f"  {op:16s} {st:8s} {n:>4s} {mi:>8s} {mo:>8s} {ms:>8s} {big:>9s}")

        fr = psql(f"""
            SELECT operation, llm_info->>'finish_reason', count(*)
            FROM llm_requests WHERE bank_id='{BANK}'
            GROUP BY 1,2 ORDER BY 1,2;""")
        print("\n  finish reasons:")
        for r in fr:
            print(f"    {r}")

        errs = psql(f"""
            SELECT operation, left(replace(coalesce(error,''),'|','/'),160)
            FROM llm_requests WHERE bank_id='{BANK}' AND status<>'success' LIMIT 10;""")
        if errs:
            print("\n  ERRORS:")
            for e in errs:
                print(f"    {e}")
        else:
            print("\n  no failed llm_requests")
    finally:
        req("DELETE", f"/banks/{BANK}", timeout=180)
        print(f"\n  disposable bank {BANK} deleted")

    if failures:
        print("\n=== HTTP failures ===")
        for f in failures:
            print(f"  {f}")
    else:
        print("\nNo HTTP failures.")


if __name__ == "__main__":
    main()

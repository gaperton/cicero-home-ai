#!/usr/bin/env python3
"""bench-streams.py — per-request AND aggregate pp/tg for a model on the live router.

bench-combined.sh measures Hindsight's request shape. This isolates the two
extremes instead: a prefill-dominated request (big prompt, ~no generation) and a
decode-dominated one (small prompt, long generation), each at 1 and 2 concurrent
streams.

It reports both rates because they answer different questions and diverge once the
card is saturated:
  per-request  what one caller experiences
  aggregate    what the card actually delivers  (tokens in the burst / burst wall)
Two streams can each run at half speed while aggregate is unchanged — that is
saturation, and only the aggregate column reveals it.

Prompts are randomised per request so the slot prefix cache never hits; a cached
prefill would report a meaningless pp.
"""
import argparse, json, random, statistics, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

WPT = 4.92  # measured tokens per filler word for this tokenizer family

def filler(tokens, rng):
    return " ".join("token%d" % rng.randint(0, 99999) for _ in range(int(tokens / WPT)))

def one(base, model, ptok, ntok, extra, timeout, force_gen=False):
    rng = random.Random(random.random())          # unique prompt => no cache hit
    body = {"model": model,
            "messages": [{"role": "user", "content": filler(ptok, rng) + "\n\nContinue."}],
            "max_tokens": ntok, "temperature": 0.8, "cache_prompt": False}
    # A decode benchmark must actually decode. On filler text the model hits EOS
    # after a few dozen tokens, which silently turns a "tg-heavy" case into a
    # prefill measurement; ignore_eos pins generation to exactly max_tokens.
    if force_gen:
        body["ignore_eos"] = True
    body.update(extra)
    req = urllib.request.Request(base + "/v1/chat/completions",
                                 json.dumps(body).encode(), {"Content-Type": "application/json"})
    d = json.load(urllib.request.urlopen(req, timeout=timeout))
    t = d.get("timings") or {}
    return {"pp_n": t.get("prompt_n", 0), "pp": t.get("prompt_per_second", 0.0),
            "tg_n": t.get("predicted_n", 0), "tg": t.get("predicted_per_second", 0.0)}

def burst(base, model, ptok, ntok, streams, extra, timeout, force_gen=False):
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=streams) as ex:
        futs = [ex.submit(one, base, model, ptok, ntok, extra, timeout, force_gen)
                for _ in range(streams)]
        res = [f.result() for f in futs]
    return time.time() - t0, res


def burst_mixed(base, model, pp_prompt, tg_gen, extra, timeout):
    """One prefill-heavy and one decode-heavy request, fired together.

    This is the shape production actually runs: Hindsight prefills a large prompt
    on one slot while another slot is mid-generation. Measuring the two extremes in
    isolation misses the interference entirely — under tensor split that
    interference cost 33x, under layer split about 16%.
    """
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=2) as ex:
        f_pp = ex.submit(one, base, model, pp_prompt, 8, extra, timeout, False)
        f_tg = ex.submit(one, base, model, 512, tg_gen, extra, timeout, True)
        r_pp, r_tg = f_pp.result(), f_tg.result()
    return time.time() - t0, r_pp, r_tg

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--repeats", type=int, default=3)
    ap.add_argument("--pp-prompt", type=int, default=16384, help="pp-heavy prompt tokens")
    ap.add_argument("--tg-gen", type=int, default=512, help="tg-heavy generated tokens")
    ap.add_argument("--extra-body", default="{}")
    ap.add_argument("--timeout", type=float, default=1800)
    a = ap.parse_args()
    base = "http://%s:%d" % (a.host, a.port)
    extra = json.loads(a.extra_body)

    cases = [("pp-heavy", a.pp_prompt, 8, False), ("tg-heavy", 512, a.tg_gen, True)]
    print("model=%s  port=%d  repeats=%d" % (a.model, a.port, a.repeats))
    print()
    print("%-10s %-8s | %10s %10s | %10s %10s | %8s" %
          ("workload", "streams", "pp/req", "tg/req", "pp AGG", "tg AGG", "burst"))
    print("-" * 78)
    for name, ptok, ntok, force in cases:
        for streams in (1, 2):
            burst(base, a.model, ptok, ntok, streams, extra, a.timeout, force)   # warmup
            walls, ppr, tgr, aggpp, aggtg = [], [], [], [], []
            for _ in range(a.repeats):
                w, res = burst(base, a.model, ptok, ntok, streams, extra, a.timeout, force)
                walls.append(w)
                ppr += [r["pp"] for r in res]; tgr += [r["tg"] for r in res]
                aggpp.append(sum(r["pp_n"] for r in res) / w)
                aggtg.append(sum(r["tg_n"] for r in res) / w)
            med = statistics.median
            print("%-10s %-8d | %10.1f %10.2f | %10.1f %10.2f | %7.2fs" %
                  (name, streams, med(ppr), med(tgr), med(aggpp), med(aggtg), med(walls)))

    # mixed: one prefill-heavy + one decode-heavy, concurrently
    burst_mixed(base, a.model, a.pp_prompt, a.tg_gen, extra, a.timeout)   # warmup
    walls, ppr, tgr, aggpp, aggtg = [], [], [], [], []
    for _ in range(a.repeats):
        w, r_pp, r_tg = burst_mixed(base, a.model, a.pp_prompt, a.tg_gen, extra, a.timeout)
        walls.append(w); ppr.append(r_pp["pp"]); tgr.append(r_tg["tg"])
        aggpp.append(r_pp["pp_n"] / w); aggtg.append(r_tg["tg_n"] / w)
    med = statistics.median
    print("%-10s %-8s | %10.1f %10.2f | %10.1f %10.2f | %7.2fs" %
          ("mixed", "1pp+1tg", med(ppr), med(tgr), med(aggpp), med(aggtg), med(walls)))
    return 0

if __name__ == "__main__":
    sys.exit(main())

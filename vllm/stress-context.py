#!/usr/bin/env python3
"""Fill the shared KV pool with long-context requests and record peak VRAM.

Validates KV_CACHE_MEMORY_BYTES / MAX_MODEL_LEN / MAX_NUM_SEQS in config.env: fires --long
requests of ~--ctx prompt tokens each (enough to exceed the pool, so vLLM must
queue or preempt) plus --decode short streams, samples each card's VRAM from sysfs
every 0.25 s, and reads vLLM's preemption counter. A pass means every request
completed and no card ran out of VRAM.

  ./vllm/stress-context.py                     # 3 x ~180k-token prompts + 4 decode streams
  ./vllm/stress-context.py --long 2 --ctx 190000
"""
import argparse, glob, json, os, random, re, threading, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def corpus():
    root = os.path.join(REPO, "llama.cpp")
    files = sorted(glob.glob(f"{root}/src/*.cpp") + glob.glob(f"{root}/tools/server/*.cpp")
                   + glob.glob(f"{root}/ggml/src/*.c") + glob.glob(f"{root}/ggml/src/ggml-cpu/*.c*"))
    return "\n".join(open(f, errors="replace").read() for f in files)

def cards():
    return sorted(d for d in glob.glob("/sys/class/drm/card*/device")
                  if os.path.exists(f"{d}/mem_info_vram_used"))

def vram(d):
    return int(open(f"{d}/mem_info_vram_used").read()), int(open(f"{d}/mem_info_vram_total").read())

def metric(base, name):
    try:
        text = urllib.request.urlopen(base + "/metrics", timeout=10).read().decode()
        return sum(float(m) for m in re.findall(rf"^{name}(?:{{[^}}]*}})? ([0-9.e+]+)$", text, re.M))
    except Exception:
        return None

def count_tokens(base, model, content):
    req = urllib.request.Request(base + "/tokenize", json.dumps({"model": model, "prompt": content}).encode(),
                                 {"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=120))["count"]

def long_prompt(base, model, text, ctx):
    """A random slice of the corpus, trimmed to ~ctx tokens via vLLM's /tokenize."""
    # Token density varies ~2x across the sources, so proportional rescaling can
    # oscillate. Fix the start and bisect the slice length instead: the token
    # count is monotonic in it, so this always converges.
    hi = int(ctx * 5.0)
    if len(text) < hi + 1:
        raise SystemExit(f"corpus too small: {len(text)} chars")
    start = random.randint(0, len(text) - hi - 1)
    lo, n = 0, 0
    for _ in range(24):
        mid = (lo + hi) // 2
        body = text[start:start + mid]
        n = count_tokens(base, model, body)
        if ctx * 0.97 <= n <= ctx:
            break
        if n > ctx:
            hi = mid
        else:
            lo = mid
    else:
        raise SystemExit(f"could not size a {ctx}-token prompt (last {n})")
    return f"session-{random.getrandbits(64):016x}\n" + body + "\n\nName the three most important functions above."

def request(base, model, content, max_tokens, timeout=3600):
    body = {"model": model, "messages": [{"role": "user", "content": content}],
            "max_tokens": max_tokens, "temperature": 1.0, "top_p": 0.95}
    req = urllib.request.Request(base + "/v1/chat/completions", json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    t0 = time.time()
    try:
        d = json.load(urllib.request.urlopen(req, timeout=timeout))
        return {"ok": True, "s": round(time.time() - t0, 1), "prompt": d["usage"]["prompt_tokens"],
                "gen": d["usage"]["completion_tokens"]}
    except Exception as e:
        return {"ok": False, "s": round(time.time() - t0, 1), "error": repr(e)[:300]}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8080")
    ap.add_argument("--model", default="qwen3.8-27b")
    ap.add_argument("--long", type=int, default=3, help="concurrent long-context requests")
    ap.add_argument("--ctx", type=int, default=180000, help="approx prompt tokens per long request")
    ap.add_argument("--decode", type=int, default=4, help="concurrent short decode streams")
    a = ap.parse_args()

    text = corpus()
    devs = cards()
    peak = {d: 0 for d in devs}
    total = {d: vram(d)[1] for d in devs}
    stop = threading.Event()

    def sample():
        while not stop.is_set():
            for d in devs:
                peak[d] = max(peak[d], vram(d)[0])
            time.sleep(0.25)

    pre0 = metric(a.base, "vllm:num_preemptions_total")
    idle = {d: vram(d)[0] for d in devs}
    threading.Thread(target=sample, daemon=True).start()
    jobs = []
    for i in range(a.long):
        jobs.append(("long", long_prompt(a.base, a.model, text, a.ctx), 256))
    for _ in range(a.decode):
        jobs.append(("decode", "Write a detailed explanation of how a hash map handles collisions, with code.", 1024))

    t0 = time.time()
    with ThreadPoolExecutor(len(jobs)) as ex:
        res = list(ex.map(lambda j: (j[0], request(a.base, a.model, j[1], j[2])), jobs))
    stop.set()
    time.sleep(0.3)

    for kind, r in res:
        print(kind, json.dumps(r))
    pre1 = metric(a.base, "vllm:num_preemptions_total")
    GiB = 2 ** 30
    for d in devs:
        print(f"{d.split('/')[-2]}: idle {idle[d]/GiB:.2f} GiB, peak {peak[d]/GiB:.2f} / {total[d]/GiB:.2f} GiB, "
              f"min free {(total[d]-peak[d])/GiB:.2f} GiB")
    print(f"wall {time.time()-t0:.0f}s, preemptions {None if pre0 is None or pre1 is None else int(pre1-pre0)}, "
          f"all ok: {all(r['ok'] for _, r in res)}")

if __name__ == "__main__":
    main()

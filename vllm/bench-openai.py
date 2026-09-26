#!/usr/bin/env python3
"""Runtime-agnostic OpenAI-API benchmark (vLLM or llama.cpp), client-side timing only.

hindsight/benchmark/bench-streams.py reads llama.cpp's `timings` field, which vLLM
does not return, and uses random filler that makes MTP acceptance meaningless. This
times the stream itself, on real prompts, so both servers are measured the same way.

decode    : real prompts (prose/code/json/reasoning), recommended Qwen sampling, concurrency 1/2/4/8
prefill   : real-text prompts (llama.cpp sources) of ~4k/16k/64k target size, max_tokens=1,
            unique nonce prefix so the prefix cache never hits
mixed     : one ~32k prefill fired while a decode stream is running (production shape)
toolcall  : N tool-call requests, counts well-formed calls

  ./vllm/bench-openai.py --label vllm-mtp                        # against :8080
  ./vllm/bench-openai.py --label x --base http://127.0.0.1:8000  # another server

Results append to --out as JSON lines. The first prefill size includes any lazy
kernel compilation on a cold server; re-run it before trusting that one number.
"""
import argparse, json, random, statistics, time, threading, urllib.request, glob, os
from concurrent.futures import ThreadPoolExecutor

PROMPTS = {
    "prose": "Explain, for a curious non-specialist, how a refrigerator moves heat from the inside to the outside. Cover the refrigerant cycle, why compression heats a gas, and why the coils on the back are warm.",
    "code": "Write a Python module implementing an LRU cache class with get/put, O(1) operations, a max size, optional TTL expiry per entry, and thread safety. Include type hints and a short pytest test suite.",
    "json": "Produce a JSON array of 12 fictional employees. Each object must have: id (int), name, email, department (one of engineering/sales/support/finance), start_date (YYYY-MM-DD), skills (array of 3 strings), manager_id (int or null). Output only JSON.",
    "reason": "A train leaves city A at 09:00 at 80 km/h towards city B, 400 km away. Another leaves B at 10:00 towards A at 120 km/h. A bird flies back and forth between the trains at 150 km/h starting at 10:00 from B's train. When do the trains meet, and how far has the bird flown? Show your work.",
}
SAMPLING = {"temperature": 1.0, "top_p": 0.95, "top_k": 20, "min_p": 0.0, "presence_penalty": 0.0}

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def corpus():
    root = os.path.join(REPO, "llama.cpp")  # the stack's own llama.cpp checkout
    files = sorted(glob.glob(f"{root}/src/*.cpp")) + sorted(glob.glob(f"{root}/tools/server/*.cpp"))
    return "\n".join(open(f, errors="replace").read() for f in files)

CORPUS = None

def stream(base, model, messages, max_tokens, extra=None, timeout=1800):
    body = {"model": model, "messages": messages, "max_tokens": max_tokens, "stream": True,
            "stream_options": {"include_usage": True}}
    body.update(SAMPLING); body.update(extra or {})
    req = urllib.request.Request(base + "/v1/chat/completions", json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    t0 = time.time(); t_first = t_last = None; usage = None; n_chunks = 0
    with urllib.request.urlopen(req, timeout=timeout) as r:
        for raw in r:
            line = raw.decode().strip()
            if not line.startswith("data:"): continue
            data = line[5:].strip()
            if data == "[DONE]": break
            d = json.loads(data)
            if d.get("usage"): usage = d["usage"]
            for ch in d.get("choices") or []:
                de = ch.get("delta") or {}
                if de.get("content") or de.get("reasoning_content") or de.get("reasoning") or de.get("tool_calls"):
                    now = time.time(); n_chunks += 1
                    if t_first is None: t_first = now
                    t_last = now
    t_end = time.time()
    ct = (usage or {}).get("completion_tokens", 0); pt = (usage or {}).get("prompt_tokens", 0)
    ttft = (t_first or t_end) - t0
    dec = (ct - 1) / (t_last - t_first) if (t_first and t_last and t_last > t_first and ct > 1) else 0.0
    return {"ttft": ttft, "decode": dec, "ct": ct, "pt": pt, "wall": t_end - t0}

def run_decode(base, model, conc, reps, max_tokens):
    rows = []
    kinds = list(PROMPTS)
    for rep in range(reps):
        jobs = [kinds[(rep * conc + i) % len(kinds)] for i in range(conc)]
        t0 = time.time()
        with ThreadPoolExecutor(conc) as ex:
            res = list(ex.map(lambda k: (k, stream(base, model, [{"role": "user", "content": PROMPTS[k]}], max_tokens)), jobs))
        wall = time.time() - t0
        agg = sum(r["ct"] for _, r in res) / wall
        rows.append((agg, res))
    per = [r["decode"] for _, res in rows for _, r in res]
    ttft = [r["ttft"] for _, res in rows for _, r in res]
    return {"conc": conc, "agg_tps_median": statistics.median(a for a, _ in rows),
            "per_req_tps_median": statistics.median(per), "per_req_tps_min": min(per),
            "ttft_median": statistics.median(ttft),
            "by_kind": {k: round(statistics.median([r["decode"] for _, res in rows for kk, r in res if kk == k]), 1)
                        for k in PROMPTS if any(kk == k for _, res in rows for kk, _ in res)}}

def long_prompt(ntok):
    global CORPUS
    if CORPUS is None: CORPUS = corpus()
    chars = int(ntok * 3.3)
    # Fixed slice per size so every server and run gets the same text (token
    # density varies ~2x across the sources); the nonce still defeats prefix caching.
    start = random.Random(ntok).randint(0, max(0, len(CORPUS) - chars - 1))
    nonce = "session-%016x" % random.getrandbits(64)
    return [{"role": "user", "content": nonce + "\n" + CORPUS[start:start + chars] + "\n\nSummarize the code above in one sentence."}]

def run_prefill(base, model, sizes, reps):
    out = []
    for n in sizes:
        res = [stream(base, model, long_prompt(n), 1) for _ in range(reps)]
        out.append({"target": n, "prompt_tokens": res[0]["pt"],
                    "ttft_median": statistics.median(r["ttft"] for r in res),
                    "pp_tps_median": statistics.median(r["pt"] / r["ttft"] for r in res)})
    return out

def run_mixed(base, model, pp_tokens, reps):
    out = []
    for _ in range(reps):
        res = {}
        def dec(): res["tg"] = stream(base, model, [{"role": "user", "content": PROMPTS["code"]}], 768)
        th = threading.Thread(target=dec); th.start()
        time.sleep(3)  # let decode get going
        res["pp"] = stream(base, model, long_prompt(pp_tokens), 1)
        th.join()
        out.append(res)
    return {"pp_tokens": out[0]["pp"]["pt"],
            "decode_during_prefill_tps_median": statistics.median(r["tg"]["decode"] for r in out),
            "prefill_ttft_median": statistics.median(r["pp"]["ttft"] for r in out)}

TOOLS = [{"type": "function", "function": {"name": "get_weather", "description": "Get current weather for a city",
          "parameters": {"type": "object", "properties": {"city": {"type": "string"}, "unit": {"type": "string", "enum": ["c", "f"]}},
                         "required": ["city", "unit"]}}},
         {"type": "function", "function": {"name": "create_event", "description": "Create a calendar event",
          "parameters": {"type": "object", "properties": {"title": {"type": "string"}, "start": {"type": "string", "description": "ISO 8601"},
                         "attendees": {"type": "array", "items": {"type": "string"}}}, "required": ["title", "start"]}}}]
TOOL_PROMPTS = ["What's the weather in Lisbon in celsius?",
                "Schedule 'Design review' tomorrow 2026-09-27 at 15:00 with alice@example.com and bob@example.com.",
                "Is it colder in Oslo or Helsinki right now? Use fahrenheit."]

def run_tools(base, model, n):
    ok = 0; fails = []
    for i in range(n):
        body = {"model": model, "messages": [{"role": "user", "content": TOOL_PROMPTS[i % len(TOOL_PROMPTS)]}],
                "tools": TOOLS, "max_tokens": 4096}
        body.update(SAMPLING)
        req = urllib.request.Request(base + "/v1/chat/completions", json.dumps(body).encode(), {"Content-Type": "application/json"})
        try:
            d = json.load(urllib.request.urlopen(req, timeout=600))
            calls = d["choices"][0]["message"].get("tool_calls") or []
            good = bool(calls) and all(json.loads(c["function"]["arguments"]) is not None and c["function"]["name"] in ("get_weather", "create_event") for c in calls)
            ok += good
            if not good: fails.append((i, d["choices"][0].get("finish_reason"), str(d["choices"][0]["message"])[:300]))
        except Exception as e:
            fails.append((i, "error", repr(e)[:300]))
    return {"ok": ok, "n": n, "fails": fails[:5]}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8080")
    ap.add_argument("--model", default="qwen3.8-27b")
    ap.add_argument("--label", required=True)
    ap.add_argument("--conc", default="1,2,4,8")
    ap.add_argument("--reps", type=int, default=3)
    ap.add_argument("--max-tokens", type=int, default=512)
    ap.add_argument("--prefill", default="4096,16384,65536")
    ap.add_argument("--tools", type=int, default=15)
    ap.add_argument("--out", default="bench-results.jsonl")
    ap.add_argument("--parts", default="decode,prefill,mixed,tools", help="subset of decode,prefill,mixed,tools")
    a = ap.parse_args()
    random.seed()
    # warmup
    stream(a.base, a.model, [{"role": "user", "content": "Say hello."}], 32)
    res = {"label": a.label, "time": time.strftime("%Y-%m-%d %H:%M:%S")}
    parts = set(a.parts.split(","))
    if "decode" in parts:
        res["decode"] = [run_decode(a.base, a.model, int(c), a.reps, a.max_tokens) for c in a.conc.split(",")]
        for d in res["decode"]: print(a.label, "decode", json.dumps(d), flush=True)
    if "prefill" in parts:
        res["prefill"] = run_prefill(a.base, a.model, [int(x) for x in a.prefill.split(",")], 2)
        print(a.label, "prefill", json.dumps(res["prefill"]), flush=True)
    if "mixed" in parts:
        res["mixed"] = run_mixed(a.base, a.model, 32768, 2)
        print(a.label, "mixed", json.dumps(res["mixed"]), flush=True)
    if a.tools and "tools" in parts:
        res["tools"] = run_tools(a.base, a.model, a.tools)
        print(a.label, "tools", json.dumps(res["tools"]), flush=True)
    with open(a.out, "a") as f: f.write(json.dumps(res) + "\n")

if __name__ == "__main__":
    main()

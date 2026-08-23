#!/usr/bin/env python3
"""hindsight-load.py — drive a llama-server with Hindsight's real request shape.

This is the load generator behind `bench-mtp.sh`. It does not talk to Hindsight
at all (that is `bench-hindsight.py`); it replays the *shape* of the traffic
Hindsight puts on the llama.cpp router so a model or a server flag can be A/B'd
without a Hindsight install, a bank, or a 300-candidate rerank in the way.

What "Hindsight-shaped" means here, all of it measured and recorded in
../experiments/2026-08-installation-and-tuning-log.md and
../../gpu-0-1/combined.ini:

- **Decode-dominated, contrary to the old README claim.** Over the 480 recorded calls,
  uncached prompt tokens total ~1.71M and generated tokens ~170k; at this
  machine's measured 4,139 tok/s prefill and 134 tok/s decode that is ~430 s of
  prefill against ~1,270 s of decode. The "~90% prompt processing" line in
  the installation log came from four hand-timed `hermes` calls with 23k prompts and
  50-250 outputs; the real per-bank mix is the other way round, mostly because
  Retain generates ~600 tokens off ~820 uncached prompt tokens. Both regimes
  are covered by the profiles below, and this is exactly why the MTP question
  is worth re-asking rather than assuming the prefill answer.
- **Request sizes and output lengths from the recorded traffic.** The
  `llm_requests` table of the `psychology` bank holds 480 real gpt-oss-20b
  calls with exact token counts; the profile table below is derived from it.
- **Measured concurrency, not the semaphore.** `HINDSIGHT_API_LLM_MAX_CONCURRENT`
  is 3, but the recorded overlap averages 1.06 for Consolidation, 2.45 for
  Retain and 1.33 for Reflect — only Retain arrives in bursts. Each profile
  therefore defaults to its own measured concurrency; `--concurrency` overrides
  it to study the saturated case. The wall time of one such round is the metric.
- **The real system prompts.** `../templates/retain.md` and
  `../templates/consolidate.md` are Hindsight's own, ~2,400 tokens each, and they
  are a fixed shared prefix on every call of their kind.
- **Strict structured output.** Hindsight runs with strict schemas enabled, so
  Retain and Consolidation decode under a JSON grammar. Grammar-constrained
  sampling is part of the cost and interacts with speculative decoding.
- **The system prefix IS cached, the payload is not.** `llm_requests` reports
  44% of Consolidation and 64% of Retain input tokens served from cache, and
  the cached count matches the system prompt almost exactly (2,364 cached vs a
  ~2,497-token system prompt). So the shared prefix is held identical here and
  `cache_prompt` is left on, while every request's payload is freshly generated
  and therefore always reprocessed. `cache_n` is reported to confirm the split.
  Disabling the cache would roughly double the measured prefill work.
- **Sampling comes from the preset, not the client.** Verified by proxy
  capture: only Retain sends a temperature (0.1); Reflect and Consolidation
  send no sampling at all and inherit the server's. This script does the same,
  so the `temp` in the preset is what is being exercised.

System prompts are read from the `llm_requests` table when Postgres is
reachable (the system message is Hindsight's own template, not user content),
falling back to `../templates/*.md`. That matters for sizing: the captured
`../templates/retain.md` is ~9,970 chars while the prompt actually sent is ~7,166,
and at a 2,365-token target the difference is most of the payload budget.

The remaining approximation is Reflect's structure: it is really a 3-4 turn tool
loop whose prompt grows from ~2.3k to 14k-38k tokens, replayed here as a single
turn at the loop's dominant size.

Usage:
    hindsight-load.py --profile retain [--port 8099] [--concurrency N]
                      [--repeats 3] [--warmup 1] [--extra-body JSON]

Prints one TSV line on stdout:
    prompt_n  cache_n  pp_tps  tg_tps  predicted_n  burst_wall  agg_pp_tps
    accept  errors  concurrency  share
where prompt_n is llama.cpp's *processed* count (cache hits are in cache_n),
burst_wall covers all `concurrency` requests, and `share` is this operation's
fraction of recorded LLM calls, for weighting the mix. A human-readable trace
goes to stderr. Exits non-zero if no request succeeded.
"""
import argparse
import json
import random
import statistics
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
TEMPLATES_DIR = SCRIPT_DIR.parent / "templates"

# --- Output schemas -------------------------------------------------------
# Shaped after the field lists in ../templates/retain.md and ../templates/consolidate.md.
# The exact schema Hindsight sends is not captured; what matters for the
# benchmark is that decoding runs under a JSON grammar of this complexity.
RETAIN_SCHEMA = {
    "type": "object",
    "properties": {
        "facts": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "what": {"type": "string"},
                    "when": {"type": "string"},
                    "where": {"type": "string"},
                    "who": {"type": "string"},
                    "why": {"type": "string"},
                    "fact_kind": {"type": "string", "enum": ["event", "conversation"]},
                    "fact_type": {"type": "string", "enum": ["world", "assistant"]},
                    "entities": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["what", "when", "where", "who", "why",
                             "fact_kind", "fact_type", "entities"],
            },
        },
    },
    "required": ["facts"],
}

_CONSOLIDATE_ENTRY = {
    "type": "object",
    "properties": {
        "text": {"type": "string"},
        "observation_id": {"type": "string"},
        "source_fact_ids": {"type": "array", "items": {"type": "string"}},
        "reason": {"type": "string"},
    },
    "required": ["text", "source_fact_ids", "reason"],
}

CONSOLIDATE_SCHEMA = {
    "type": "object",
    "properties": {
        "creates": {"type": "array", "items": _CONSOLIDATE_ENTRY},
        "updates": {"type": "array", "items": _CONSOLIDATE_ENTRY},
        "deletes": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["creates", "updates", "deletes"],
}

REFLECT_SYSTEM = """You are a memory reflection system. Answer the user's question using ONLY the recalled memories below.

- Cite the memory that supports each claim.
- If the memories do not contain the answer, say so plainly instead of guessing.
- Answer in the language of the question.
- Be concise: two or three sentences unless the question needs more.
"""

# Profile shapes, taken from the 480 real gpt-oss-20b calls the `psychology`
# bank recorded in `llm_requests` (2026-08-05..06), not from the four hand-timed
# calls in the installation log's "Prefill dominates" table. Those four came from the
# `hermes` bank and are not representative: they made Retain look like a 23k-token
# prefill job when it is really ~2.4k in / ~600 out.
#
#   op             calls  %time  in p50   cached   out p50/avg  concurrency
#   consolidation   369    53%    5,493    44%      255 / 294    1.06 avg
#   retain           77    34%    2,365    64%      596 / 611    2.45 avg
#   reflect          33    13%   14,369     n/r      82 / 446    1.33 avg
#
# `target` is the FULL prompt including the system prefix, so it is directly
# comparable to `input_tokens` in that table. `concurrency` is the measured
# average overlap for that operation, rounded — the router is not saturated by
# most of this traffic. `share` is the operation's share of LLM calls, used to
# weight the mix summary.
PROFILES = {
    "retain":      {"system_file": "retain.md",      "db_op": "retain",
                    "target": 2365,  "max_tokens": 600, "concurrency": 2, "share": 0.16,
                    "schema": RETAIN_SCHEMA,      "temperature": 0.1},
    "consolidate": {"system_file": "consolidate.md", "db_op": "consolidation",
                    "target": 5493,  "max_tokens": 255, "concurrency": 1, "share": 0.77,
                    "schema": CONSOLIDATE_SCHEMA, "temperature": None},
    "reflect":     {"system_file": None,             "db_op": "reflect",
                    "target": 14369, "max_tokens": 450, "concurrency": 1, "share": 0.07,
                    "schema": None,               "temperature": None},
    # Reflect's p90. Its tool loop grows the prompt over 3-4 turns (2.3k -> 38k),
    # so the tail is a third of Reflect's own cost. Not in the default set.
    "reflect-long": {"system_file": None,            "db_op": "reflect",
                     "target": 31564, "max_tokens": 450, "concurrency": 1, "share": 0.0,
                     "schema": None,              "temperature": None},
}

# --- Payload material -----------------------------------------------------
# Bilingual, because the deployment's retrieval and extraction are both
# exercised across Russian and English (see the multilingual matrix in
# installation log). Mixed-script text also tokenizes less efficiently, which is
# the realistic case here.
PEOPLE = ["Daniel", "Anna", "Sergey", "Miriam", "Kolya", "Elena", "Tomas", "Дарья",
          "Игорь", "Наталья", "Priya", "Marek", "Оля", "Виктор", "Sasha", "Lena"]
PLACES = ["the Aurora room", "the observatory", "Садовая улица", "the Vulkan lab",
          "the third floor", "дача под Тверью", "the machine room", "Тимирязевский парк"]
THINGS = ["the R9700 card", "the reranker preset", "the telescope mount", "квартальный отчёт",
          "the backup schedule", "гидропонная система", "the harmony template", "PostgreSQL dump"]
EN_TURNS = [
    "{p}: I moved {t} over to {pl} last night, it took about three hours and nothing broke.",
    "{p}: Honestly {t} has been the flakiest part of the setup since March, I keep restarting it.",
    "{p}: We agreed the review meets in {pl} every second Thursday, {p2} books the room.",
    "{p}: {p2} finished the certification last week and is now leading the work on {t}.",
    "{p}: Do not touch {t} before Friday — {p2} is still running measurements against it.",
    "{p}: The smell of solder in {pl} was awful, but the fix held all weekend.",
    "{p}: I prefer to keep {t} on the second machine, it never contends with anything there.",
]
RU_TURNS = [
    "{p}: Я перенёс {t} в {pl} вчера вечером, заняло часа три, ничего не сломалось.",
    "{p}: {p2} записал ребёнка к врачу на вторник, поэтому встречу сдвинули.",
    "{p}: Мы договорились, что {t} остаётся на второй машине — там оно ни с чем не конкурирует.",
    "{p}: В {pl} было шумно, но {p2} всё равно дочитал отчёт до конца.",
    "{p}: Не трогай {t} до пятницы, {p2} ещё снимает замеры.",
    "{p}: {p2} сказала, что переезд назначен на конец месяца, коробки уже собраны.",
]
FACT_LINES = [
    "{p} moved {t} to {pl} and reported no regressions afterwards.",
    "{p} prefers {t} kept on the secondary host to avoid contention.",
    "{p} и {p2} договорились о встрече в {pl} во второй четверг месяца.",
    "{p} completed a certification and now leads the work on {t}.",
    "{p} наблюдал, что {t} ведёт себя нестабильно с марта.",
    "{p} booked {pl} for the quarterly review at {p2}'s request.",
]
OBS_LINES = [
    "{p} owns {t} and has maintained it since 2024.",
    "{p} works with {p2} on the {t} effort; the two split responsibilities by machine.",
    "{p} регулярно проводит встречи в {pl}.",
    "{p} has repeatedly reported instability in {t}.",
]


def _fill(rng, template):
    p, p2 = rng.sample(PEOPLE, 2)
    return template.format(p=p, p2=p2, pl=rng.choice(PLACES), t=rng.choice(THINGS))


def retain_blocks(rng, n):
    """Conversation turns, the raw material a Retain call extracts facts from."""
    out = []
    for i in range(n):
        pool = RU_TURNS if rng.random() < 0.4 else EN_TURNS
        out.append(f"[{9 + (i // 6) % 12:02d}:{(i * 7) % 60:02d}] " + _fill(rng, rng.choice(pool)))
    return out


def consolidate_blocks(rng, n):
    """`[uuid] fact (temporal fields)` lines, per ../templates/consolidate.md."""
    out = []
    for _ in range(n):
        day = rng.randint(1, 28)
        out.append(f"  [{uuid.UUID(int=rng.getrandbits(128), version=4)}] "
                   f"{_fill(rng, rng.choice(FACT_LINES))} "
                   f"(occurred_start=2026-0{rng.randint(1, 8)}-{day:02d}, mentioned_at=2026-08-{day:02d})")
    return out


def observation_blocks(rng, n):
    return [json.dumps({"id": str(uuid.UUID(int=rng.getrandbits(128), version=4)),
                        "text": _fill(rng, rng.choice(OBS_LINES)),
                        "proof_count": rng.randint(1, 9)}, ensure_ascii=False)
            for _ in range(n)]


def recall_blocks(rng, n):
    """Recalled memory units, the context a Reflect call reasons over."""
    return [f"- [{i + 1}] {_fill(rng, rng.choice(FACT_LINES))}" for i in range(n)]


def build_user(profile, rng, n):
    if profile == "retain":
        return ("Event Date: 2026-08-06\n\n"
                "Extract facts from the following conversation transcript:\n\n"
                + "\n".join(retain_blocks(rng, n)))
    if profile == "consolidate":
        n_obs = max(1, n // 4)
        return ("MISSION: keep one canonical observation per facet.\n\n"
                "### New facts\n\n" + "\n".join(consolidate_blocks(rng, n)) +
                "\n\n### Existing observations\n\n[" +
                ",\n".join(observation_blocks(rng, n_obs)) + "]\n")
    return ("Recalled memories:\n\n" + "\n".join(recall_blocks(rng, n)) +
            "\n\nQuestion: какой код доступа к телескопу и кто отвечает за перенос оборудования?\n")


# --- HTTP -----------------------------------------------------------------
def post(url, body, timeout):
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


# Set from --model. A single-model llama-server infers the model from its own
# command line, but a router (gpu-0-1/) serves several and rejects both /tokenize
# and /v1/chat/completions with HTTP 400 unless the request names one.
MODEL = None


def count_tokens(base, text, timeout):
    payload = {"content": text}
    if MODEL:
        payload["model"] = MODEL
    return len(post(f"{base}/tokenize", payload, timeout).get("tokens", []))


def calibrate(base, profile, system, target, timeout, seed=0):
    """Grow the payload until system+user hits the profile's prompt-token target.

    The chat template adds ~50-100 tokens on top; the authoritative number is
    the server's own `prompt_n`, which is what gets reported.
    """
    sys_tokens = count_tokens(base, system, timeout) if system else 0
    rng = random.Random(seed)
    probe = build_user(profile, rng, 20)
    per_block = max(1.0, (count_tokens(base, probe, timeout) - 20) / 20.0)
    n = max(4, int((target - sys_tokens) / per_block))
    for _ in range(8):
        total = sys_tokens + count_tokens(base, build_user(profile, random.Random(seed), n), timeout)
        if total >= target * 0.98:
            return n, total
        n += max(2, int((target - total) / per_block))
    return n, total


def system_prompt_from_db(db, operation, timeout=20):
    """The exact system message last sent for this operation, from llm_requests.

    Only `input->0`, which is Hindsight's own template — no bank content. Any
    failure (no psql, no database, empty table) falls back to ../templates/.
    """
    sql = ("SELECT input->0->>'content' FROM llm_requests "
           f"WHERE operation = '{operation}' AND jsonb_typeof(input) = 'array' "
           "AND input->0->>'role' = 'system' ORDER BY started_at DESC LIMIT 1")
    try:
        out = subprocess.run(["psql", "--dbname", db, "-Atq", "-c", sql],
                             capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None
    text = out.stdout.strip("\n")
    return text if out.returncode == 0 and len(text) > 200 else None


def one_request(base, system, user, cfg, extra_body, timeout):
    body = {
        "messages": ([{"role": "system", "content": system}] if system else []) +
                    [{"role": "user", "content": user}],
        "max_tokens": cfg["max_tokens"],
        # Left on deliberately: production serves 44-64% of Retain and
        # Consolidation input tokens from the slot prefix cache, and that is
        # exactly the (identical, shared) system prompt. The payload differs
        # every call and is reprocessed regardless.
        "cache_prompt": True,
        "stream": False,
    }
    if MODEL:
        body["model"] = MODEL
    if cfg["temperature"] is not None:
        body["temperature"] = cfg["temperature"]
    if cfg["schema"] is not None:
        body["response_format"] = {"type": "json_schema",
                                   "json_schema": {"name": "hindsight", "strict": True,
                                                   "schema": cfg["schema"]}}
    body.update(extra_body)

    t0 = time.time()
    try:
        d = post(f"{base}/v1/chat/completions", body, timeout)
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}: {e.read()[:200].decode('utf-8', 'replace')}"}
    except Exception as e:  # noqa: BLE001 — a dead server is a result too
        return {"error": str(e)}
    t = d.get("timings") or {}
    if not t:
        return {"error": "no timings in response"}
    return {
        "wall": time.time() - t0,
        "prompt_n": t.get("prompt_n", 0),
        "pp": t.get("prompt_per_second", 0.0),
        "predicted_n": t.get("predicted_n", 0),
        "tg": t.get("predicted_per_second", 0.0),
        "cache_n": t.get("cache_n", 0),
        "draft_n": t.get("draft_n", 0),
        "draft_ok": t.get("draft_n_accepted", 0),
    }


def burst(base, system, users, cfg, extra_body, timeout):
    """Fire all requests at once and time the whole burst, not the parts."""
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=len(users)) as pool:
        futures = [pool.submit(one_request, base, system, u, cfg, extra_body, timeout)
                   for u in users]
        results = [f.result() for f in futures]
    return time.time() - t0, results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", required=True, choices=sorted(PROFILES))
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--model", default=None,
                    help="model id to address; required against a router (e.g. 'llm' "
                         "on gpu-0-1's :8080), unnecessary for a single-model server")
    ap.add_argument("--port", type=int, default=8099)
    ap.add_argument("--concurrency", type=int, default=0,
                    help="0 = the profile's measured average overlap")
    ap.add_argument("--repeats", type=int, default=3)
    ap.add_argument("--warmup", type=int, default=1)
    ap.add_argument("--extra-body", default="{}",
                    help="JSON merged into every request body, e.g. Hindsight's LLM_EXTRA_BODY")
    ap.add_argument("--templates-dir", default=str(TEMPLATES_DIR))
    ap.add_argument("--db", default="hindsight",
                    help="Postgres database to read the real system prompts from")
    ap.add_argument("--no-db", action="store_true", help="use ../templates/ instead of the DB")
    ap.add_argument("--timeout", type=float, default=300.0)
    args = ap.parse_args()
    global MODEL
    MODEL = args.model

    base = f"http://{args.host}:{args.port}"
    cfg = PROFILES[args.profile]
    extra_body = json.loads(args.extra_body)
    concurrency = args.concurrency or cfg["concurrency"]

    system, source = None, None
    if not args.no_db:
        system = system_prompt_from_db(args.db, cfg["db_op"])
        source = "llm_requests" if system else None
    if system is None and cfg["system_file"]:
        path = Path(args.templates_dir) / cfg["system_file"]
        if not path.is_file():
            print(f"error: missing system prompt {path}", file=sys.stderr)
            return 2
        system, source = path.read_text(encoding="utf-8"), str(path.name)
    if system is None:
        system, source = REFLECT_SYSTEM, "built-in"

    try:
        n_blocks, est = calibrate(base, args.profile, system, cfg["target"], args.timeout)
    except Exception as e:  # noqa: BLE001 — usually a server that never came up
        print(f"  [{args.profile}] cannot reach {base}: {e}", file=sys.stderr)
        return 2
    print(f"  [{args.profile}] system={source} payload={n_blocks} blocks, ~{est} tokens "
          f"(target {cfg['target']}), {concurrency} concurrent, max_tokens {cfg['max_tokens']}",
          file=sys.stderr)

    walls, per_req, errors = [], [], []
    for i in range(args.warmup + args.repeats):
        tag = "warmup" if i < args.warmup else f"run {i - args.warmup + 1}"
        # Distinct content per request AND per repeat: real Retain and
        # Consolidation prompts never share a prefix worth caching.
        users = [build_user(args.profile, random.Random(1000 * i + w), n_blocks)
                 for w in range(concurrency)]
        wall, results = burst(base, system, users, cfg, extra_body, args.timeout)
        errs = [r["error"] for r in results if "error" in r]
        ok = [r for r in results if "error" not in r]
        if errs:
            errors.extend(errs)
            print(f"  {tag:8s} {len(errs)}/{len(results)} FAILED: {errs[0]}", file=sys.stderr)
        if ok:
            print(f"  {tag:8s} wall={wall:6.2f}s  prompt={ok[0]['prompt_n']:>6} tok  "
                  f"cached={statistics.median(r['cache_n'] for r in ok):>6.0f}  "
                  f"pp={statistics.median(r['pp'] for r in ok):7.1f} t/s  "
                  f"tg={statistics.median(r['tg'] for r in ok):6.1f} t/s  "
                  f"gen={statistics.median(r['predicted_n'] for r in ok):>4.0f} tok",
                  file=sys.stderr)
        if i >= args.warmup and ok and not errs:
            walls.append(wall)
            per_req.extend(ok)

    if not per_req:
        print("0\t0\t0.00\t0.00\t0\t0.00\t0.00\tn/a\t%d" % len(errors))
        return 1

    med = statistics.median
    draft_n = sum(r["draft_n"] for r in per_req)
    draft_ok = sum(r["draft_ok"] for r in per_req)
    accept = f"{100.0 * draft_ok / draft_n:.1f}%" if draft_n else "n/a"
    wall_med = med(walls)
    # Aggregate prefill across the burst: what the router actually delivers to
    # concurrent Hindsight operations, not what one idle slot can do. prompt_n
    # is llama.cpp's *processed* count, so cache hits are correctly excluded.
    agg_pp = sum(r["prompt_n"] for r in per_req) / len(walls) / wall_med if wall_med else 0.0
    # Aggregate decode, the counterpart of agg_pp: total tokens generated per burst
    # divided by the burst's wall time. With concurrency > 1 this is what the card
    # actually delivers; the `tg` column is one stream's rate and understates it.
    agg_tg = sum(r["predicted_n"] for r in per_req) / len(walls) / wall_med if wall_med else 0.0

    print(f"  agg over burst: pp={agg_pp:.1f} t/s  tg={agg_tg:.1f} t/s  "
          f"(conc={concurrency}, burst={wall_med:.2f}s)", file=sys.stderr)
    print("\t".join([
        f"{med(r['prompt_n'] for r in per_req):.0f}",
        f"{med(r['cache_n'] for r in per_req):.0f}",
        f"{med(r['pp'] for r in per_req):.2f}",
        f"{med(r['tg'] for r in per_req):.2f}",
        f"{med(r['predicted_n'] for r in per_req):.0f}",
        f"{wall_med:.2f}",
        f"{agg_pp:.2f}",
        f"{agg_tg:.2f}",
        accept,
        str(len(errors)),
        str(concurrency),
        f"{cfg['share']:.2f}",
    ]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

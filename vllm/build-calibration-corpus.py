#!/usr/bin/env python3
"""Build the private FP8-KV calibration corpus for calibrate-kv.sh.

Mixes real local traffic-like text so the per-layer Q/K/V maxima cover what the
model actually sees. Russian matters: on Russian text layer 7's V reaches 1.23x
its English maximum, so an English-only corpus would clip it (README,
"FP8 KV-cache calibration"). Sources, all read locally:

  - Hindsight documents (psychology / teams-chat / hermes banks), via psql
  - Open WebUI chats (~/.open-webui/webui.db), as chat messages
  - llama.cpp sources (code)
  - vllm/sample-config/*.md (Russian technical prose)
  - the radiance fork's 8-prompt fixture (agent/tool, reasoning, multilingual),
    fetched from GitHub

Output: vllm/calibration/corpus/calib.jsonl (gitignored: it contains private text).
"""
import glob, json, os, random, sqlite3, subprocess, urllib.request

VLLM = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(VLLM)
OUT = os.path.join(VLLM, "calibration", "corpus", "calib.jsonl")
FIXTURE = ("https://raw.githubusercontent.com/magiccodingman/vllm-radiance/"
           "main/benchmarks/fixtures/fp8-kv-calibration.jsonl")
CPT = 3.2  # rough chars/token, only for capping sizes
rng = random.Random(17)
items = []

def cap(text, tokens):
    return text[: int(tokens * CPT)]

def psql(q):
    out = subprocess.run(["psql", "--dbname", "hindsight", "-At", "-F", "\x1f", "-R", "\x1e", "-c", q],
                         capture_output=True, text=True, check=True).stdout
    return [r.split("\x1f") for r in out.split("\x1e") if r.strip()]

# Hindsight documents: what Retain reads
try:
    for bank, n, tokens in (("psychology", 12, 16000), ("teams-chat", 8, 12000), ("hermes", 2, 8000)):
        rows = psql(f"select id, original_text from documents where bank_id='{bank}' "
                    "and length(original_text) > 3000 order by id")
        rng.shuffle(rows)
        items += [{"id": f"{bank}-{i}", "text": cap(t, tokens)} for i, (_, t) in enumerate(rows[:n])]
        if bank == "psychology" and len(rows) > n:  # one long-context item
            longest = max(rows[n:], key=lambda r: len(r[1]))
            items.append({"id": "psychology-long", "text": cap(longest[1], 30000)})
except (OSError, subprocess.CalledProcessError) as e:
    print(f"warning: Hindsight documents skipped ({e})")

# Open WebUI chats with real content
db = os.path.expanduser("~/.open-webui/webui.db")
if os.path.exists(db):
    chats = []
    for (chat,) in sqlite3.connect(f"file:{db}?mode=ro", uri=True).execute("select chat from chat"):
        d = json.loads(chat) if isinstance(chat, str) else chat
        msgs = d.get("messages") or list((d.get("history") or {}).get("messages", {}).values())
        msgs = [{"role": m["role"], "content": str(m.get("content", ""))} for m in msgs
                if m.get("role") in ("user", "assistant", "system") and m.get("content")]
        if sum(len(m["content"]) for m in msgs) > 1000:
            chats.append(msgs)
    items += [{"id": f"openwebui-{i}", "messages": m} for i, m in enumerate(chats[:4])]

# code
files = sorted(glob.glob(f"{REPO}/llama.cpp/src/*.cpp") + glob.glob(f"{REPO}/llama.cpp/tools/server/*.cpp"))
rng.shuffle(files)
items += [{"id": f"code-{i}", "text": cap(open(f, errors="replace").read(), 12000)} for i, f in enumerate(files[:4])]

# Russian prose
for f in sorted(glob.glob(f"{VLLM}/sample-config/**/*.md", recursive=True)):
    text = open(f, errors="replace").read()
    for i in range(0, len(text), 9000):
        if len(text[i:i + 9000]) > 2000:
            items.append({"id": f"ru-{os.path.basename(f)[:-3]}-{i // 9000}", "text": text[i:i + 9000]})

# the fork's fixture
try:
    for line in urllib.request.urlopen(FIXTURE, timeout=30).read().decode().splitlines():
        if line.strip():
            items.append(json.loads(line))
except OSError as e:
    print(f"warning: fork fixture skipped ({e})")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as fh:
    fh.writelines(json.dumps(r, ensure_ascii=False) + "\n" for r in items)
chars = sum(len(r.get("text", "")) + sum(len(m["content"]) for m in r.get("messages", [])) for r in items)
print(f"{OUT}: {len(items)} items, ~{int(chars / CPT):,} tokens")

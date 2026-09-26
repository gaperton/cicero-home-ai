# Mem0

Mem0's self-hosted server on `cicero`, run with Mem0's own reference Docker
Compose stack (`server/` in the Mem0 repo, "Self-Hosted Setup" in its docs).
Nothing here reimplements Mem0: `install.sh` clones a release tag, applies two
small patches (the documented provider change, and `extra_body` for the LLM), and
adapts the stack with a Compose override.

Mem0 publishes no maintained server package: `mem0ai` on PyPI is the library
only, and the `mem0/mem0-api-server` image on Docker Hub was last pushed
2025-09-10 (pre-1.0). Building from the tagged source is the supported path.

## Services

| Component | Endpoint | Runs as |
| --- | --- | --- |
| Mem0 API | `http://cicero.local:8890` (OpenAPI at `/docs`) | container `mem0-dev-mem0-1`, host network |
| Mem0 dashboard | `http://cicero.local:3001` | container `mem0-dev-mem0-dashboard-1`, host network |
| LLM and reranker | `http://127.0.0.1:8080/v1` | shared llama.cpp router (`cicero-home-ai.service`) |
| PostgreSQL | `127.0.0.1:5432`, databases `mem0` + `mem0_app` | host cluster shared with Hindsight, role `mem0` |

Both containers use `restart: unless-stopped` and come back with Docker at boot.
Auth is on (upstream default): clients send `X-API-Key`. The admin login
(`admin@mem0.dev`, `seed.sh`'s default; override with `MEM0_ADMIN_EMAIL` before the
first install — the server rejects reserved domains such as `.local`) and the first
API key are in `~/.config/mem0/admin.json`.

## Install and upgrade

```bash
./mem0/install.sh            # v2.2.0
./mem0/install.sh v2.3.0     # upgrade to another tag
```

The first run asks for sudo once, to create the `mem0` role and databases
(`configure-postgresql.sh`). Re-running keeps `.env`, the admin and all data.
If Docker was just installed, log in again (or prefix `sg docker -c`) so the
`docker` group applies.

On upgrade, check that `patches/local-models/mem0.patch` still applies — the
script stops if it does not — and back up both databases first:

```bash
pg_dump "host=127.0.0.1 dbname=mem0 user=mem0" -Fc -f mem0-$(date +%F).dump
pg_dump "host=127.0.0.1 dbname=mem0_app user=mem0" -Fc -f mem0_app-$(date +%F).dump
```

(password: `POSTGRES_PASSWORD` in `mem0/upstream/server/.env`). Memory change
history is SQLite in `~/.local/share/mem0/history/history.db`, root-owned because
the container writes it.

## Layout

| Path | Purpose |
| --- | --- |
| `install.sh` | Clone the tag into `upstream/`, apply patches, create `.env`, build and start, seed the admin, apply `configure.json`. |
| `patches/local-models/` | The documented change: `huggingface` embedder + spaCy in the image. |
| `patches/openai-extra-body/` | `extra_body` for the `openai` LLM, to turn Qwen's thinking off without losing temperature. |
| `docker-compose.override.yaml` | Host Postgres and router, ports 8890/3001, pinned `mem0ai`, bge-m3 cache mount. Symlinked into `upstream/server/`. |
| `server.env` | Template for `upstream/server/.env` (secrets filled in once). |
| `configure.json` | Runtime config sent to `POST /configure`; persisted in `mem0_app`. |
| `configure-postgresql.sh` | Root-only: role `mem0`, databases `mem0`/`mem0_app`, pgvector. |
| `upstream/` | Gitignored shallow clone of `mem0ai/mem0` at the installed tag. |

## Configuration

| Part | Setting | Where |
| --- | --- | --- |
| LLM | `qwen3.8-27b` on the router, thinking off, temperature 0.1, max 4096 tokens | `configure.json` + patch |
| Embedder | `BAAI/bge-m3`, CPU, sentence-transformers, 1024 dims | `configure.json` + patch |
| Vector store | pgvector, collection `memories`, 1024 dims | `server.env` + `configure.json` |
| Telemetry | off | `MEM0_TELEMETRY=false` in `.env` |

- **Thinking off, with Hindsight's sampling.** Stock Mem0 can only switch Qwen's
  thinking off with `is_reasoning_model: true` + `reasoning_effort: "none"`, which
  also drops `temperature`, `top_p` and `max_tokens`. The `openai-extra-body`
  patch adds an `extra_body` key instead, so `configure.json` sends
  `chat_template_kwargs: {enable_thinking: false}` alongside temperature 0.1 (as
  Hindsight's Retain), top_p 0.95 (the preset's) and a 4096-token cap.
- `POST /configure` merges into the stored overrides, so removing a key from
  `configure.json` does not remove it from the server; set it explicitly instead.
- **Same embeddings as Hindsight.** The image pins Hindsight's torch,
  sentence-transformers and transformers versions and mounts Hindsight's
  Hugging Face cache read-only, offline. Verified bit-identical vectors between
  Mem0's and Hindsight's load paths on 2026-09-24.
- **No reranking.** The server's `POST /search` has no `rerank` option and
  `Memory.search()` defaults it off, so a configured reranker would never run.
  (Mem0's `cohere` reranker does work against `qwen3-reranker` with
  `CO_API_URL=http://127.0.0.1:8080`; only the REST route is missing.)
- **Add is append-only.** Mem0 2.x never updates or deletes memories itself; a
  correction becomes a new memory linked to the old one.
- The dashboard's Configuration page edits the same persisted overrides as
  `configure.json`; the next `install.sh` run reapplies `configure.json`.

## Operations

```bash
cd mem0/upstream/server
docker compose ps
docker compose logs -f mem0
docker compose up -d --force-recreate mem0     # after editing .env
curl -fsS http://127.0.0.1:8890/auth/setup-status
```

## Security

Both containers use the host network, so ufw (default `INPUT` policy `DROP`)
decides who reaches ports 8890 and 3001, exactly as for Hindsight's 8888. Local
clients (Hermes on cicero) need nothing. LAN browsers need both ports opened,
because the dashboard's browser code calls the API on 8890 directly:

```bash
sudo ufw allow from 192.168.68.0/22 to any port 8890,3001 proto tcp comment 'mem0'
sudo ufw allow from fd9a:67f:254c:41c4::/64 to any port 8890,3001 proto tcp comment 'mem0'
```

The second rule covers LAN clients that resolve `cicero.local` over IPv6 (Avahi
publishes with `use-ipv6=yes`; the prefix is the host's ULA on `enp4s0`).

A bridge-network container cannot reach the host's API through ufw at all, which
is why the dashboard is not left on upstream's Compose network.

Keep ports 8890 and 3001 on the trusted LAN. The dashboard's CORS origin is
`http://cicero.local:3001`; opening it by IP address breaks API calls from the
browser. Do not commit `upstream/server/.env` or `admin.json`.

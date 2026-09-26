#!/usr/bin/env bash
# Install or upgrade Mem0's self-hosted server with its reference Docker Compose
# stack (API + dashboard), adapted to cicero by docker-compose.override.yaml.
#
#   ./mem0/install.sh            # tag below
#   ./mem0/install.sh v2.3.0     # another release tag
#
# Safe to re-run. Keeps server/.env, the admin credentials and all data.
set -euo pipefail

TAG="${1:-v2.2.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/upstream"
SERVER="$SRC/server"
ENV_FILE="$SERVER/.env"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mem0"
ADMIN_FILE="$CONFIG_DIR/admin.json"
API_URL="http://127.0.0.1:8890"
DASHBOARD_URL="http://cicero.local:3001"

[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: not a release tag: $TAG" >&2; exit 1; }
for command in git docker curl psql python3 openssl; do
    command -v "$command" >/dev/null || { echo "error: missing command: $command" >&2; exit 1; }
done
docker info >/dev/null 2>&1 || {
    echo "error: cannot reach Docker. Log in again after 'usermod -aG docker', or run: sg docker -c $0" >&2
    exit 1
}
[[ -d "$HOME/.local/share/hindsight/cache/huggingface/hub/models--BAAI--bge-m3" ]] || {
    echo "error: BAAI/bge-m3 is missing from Hindsight's Hugging Face cache" >&2
    exit 1
}

# --- Source: upstream tag plus local patches (same rule as llama.cpp's patches/:
# a patch that no longer applies is a hard failure, never skipped).
if [[ ! -d "$SRC/.git" ]]; then
    git clone --quiet --depth 1 --branch "$TAG" https://github.com/mem0ai/mem0.git "$SRC"
else
    # Drop the previous run's patches, including files they created. Ignored files
    # (server/.env) survive; the override symlink is recreated below.
    git -C "$SRC" checkout --quiet -- .
    git -C "$SRC" clean --quiet -fd
    git -C "$SRC" fetch --quiet --depth 1 origin tag "$TAG"
    git -C "$SRC" -c advice.detachedHead=false checkout --quiet "$TAG"
fi
for patch in "$SCRIPT_DIR"/patches/*/mem0.patch; do
    echo "Applying $(basename "$(dirname "$patch")")"
    git -C "$SRC" apply "$patch"
done
ln -sfn "$SCRIPT_DIR/docker-compose.override.yaml" "$SERVER/docker-compose.override.yaml"

# --- server/.env: created once with fresh secrets; only MEM0AI_VERSION follows the tag.
if [[ ! -f "$ENV_FILE" ]]; then
    sed -e "s|@POSTGRES_PASSWORD@|$(openssl rand -hex 24)|" \
        -e "s|@JWT_SECRET@|$(openssl rand -hex 48)|" \
        "$SCRIPT_DIR/server.env" > "$ENV_FILE"
    echo "Created $ENV_FILE"
fi
chmod 600 "$ENV_FILE"
sed -i "s|^MEM0AI_VERSION=.*|MEM0AI_VERSION=${TAG#v}|" "$ENV_FILE"
pg_password="$(sed -n 's/^POSTGRES_PASSWORD=//p' "$ENV_FILE")"

# --- PostgreSQL: role mem0 and databases mem0 / mem0_app on the host cluster.
if ! PGPASSWORD="$pg_password" psql -w "host=127.0.0.1 dbname=mem0 user=mem0" \
        -Atc "SELECT 1 FROM pg_extension WHERE extname = 'vector'" 2>/dev/null | grep -qx 1; then
    echo "Creating the mem0 role and databases (sudo) ..."
    printf '%s\n' "$pg_password" | sudo "$SCRIPT_DIR/configure-postgresql.sh"
fi

# --- Containers.
mkdir -p "$HOME/.local/share/mem0/history" "$CONFIG_DIR"
(cd "$SERVER" && docker compose up -d --build)

echo "Waiting for the API (first start installs mem0ai and runs migrations) ..."
for _ in {1..90}; do
    curl -fsS "$API_URL/auth/setup-status" >/dev/null 2>&1 && break
    sleep 2
done
curl -fsS "$API_URL/auth/setup-status" >/dev/null || {
    echo "error: Mem0 API did not come up at $API_URL" >&2
    (cd "$SERVER" && docker compose logs --tail 50 mem0) >&2
    exit 1
}

# --- Admin and API key, once, with upstream's own seed script (make bootstrap).
# The login must pass the server's email validation, which rejects reserved
# domains such as .local; seed.sh's own default is used unless MEM0_ADMIN_EMAIL is set.
if [[ ! -f "$ADMIN_FILE" ]]; then
    seed_out="$(cd "$SERVER" && env API_URL="$API_URL" DASHBOARD_URL="$DASHBOARD_URL" OUTPUT=json \
        ${MEM0_ADMIN_EMAIL:+"EMAIL=$MEM0_ADMIN_EMAIL"} ./scripts/seed.sh)" || true
    if ! printf '%s\n' "$seed_out" | tail -n 1 | python3 -c 'import json,sys; json.load(sys.stdin)["api_key"]' 2>/dev/null; then
        echo "error: seeding the admin failed:" >&2
        printf '%s\n' "$seed_out" >&2
        exit 1
    fi
    (umask 077 && printf '%s\n' "$seed_out" | tail -n 1 > "$ADMIN_FILE")
fi
api_key="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["api_key"])' "$ADMIN_FILE")"

# --- Runtime configuration (persisted in mem0_app, reapplied on every restart).
curl -fsS -X POST "$API_URL/configure" -H "X-API-Key: $api_key" \
    -H "Content-Type: application/json" --data @"$SCRIPT_DIR/configure.json" >/dev/null
echo "Effective configuration:"
curl -fsS "$API_URL/configure" -H "X-API-Key: $api_key" | python3 -c '
import json, sys
c = json.load(sys.stdin)
for part in ("llm", "embedder", "vector_store"):
    cfg = c[part]["config"]
    print("  " + part + ":", c[part]["provider"], cfg.get("model") or cfg.get("dbname", ""))'

echo "Mem0 API:       http://cicero.local:8890  (docs at /docs)"
echo "Mem0 dashboard: $DASHBOARD_URL"
echo "Admin login and API key: $ADMIN_FILE"

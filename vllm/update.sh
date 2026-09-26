#!/usr/bin/env bash
# vllm/update.sh — Refresh the pinned image and the model, then restart if running.
#
#   ./vllm/update.sh             # re-pull IMAGE from config.env, refresh the model
#   ./vllm/update.sh 1.0.400     # switch config.env to that radiance tag first
#
# The image is pinned in config.env on purpose (see there). Without an argument
# this only picks up a re-pushed tag and model revisions, and prints whether a
# newer published tag exists. Compile caches are cleared whenever the image
# changes: a stale torch.compile/Triton cache from another build fails or hangs.
set -euo pipefail

VLLM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT="cicero-vllm.service"
export PATH="$HOME/.local/bin:$PATH"

if [ -n "${1:-}" ]; then
    [[ "$1" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "error: not a version tag: $1" >&2; exit 1; }
    sed -i "s|^IMAGE=\(.*\):.*|IMAGE=\1:$1|" "$VLLM_DIR/config.env"
fi
# shellcheck source=config.env
source "$VLLM_DIR/config.env"

latest="$(curl -fsS "https://hub.docker.com/v2/repositories/${IMAGE%:*}/tags?page_size=25&ordering=last_updated" 2>/dev/null \
    | python3 -c 'import sys,json,re; t=[r["name"] for r in json.load(sys.stdin)["results"] if re.fullmatch(r"\d+\.\d+\.\d+", r["name"])]; print(max(t, key=lambda v: tuple(map(int, v.split(".")))) if t else "")' 2>/dev/null || true)"
if [ -n "$latest" ] && [ "$latest" != "${IMAGE##*:}" ]; then
    echo "Note: newest published tag is $latest (pinned: ${IMAGE##*:}). Upgrade with: ./vllm/update.sh $latest"
fi

before="$(docker image inspect --format '{{.Id}}' "$IMAGE" 2>/dev/null || true)"
docker pull "$IMAGE"
after="$(docker image inspect --format '{{.Id}}' "$IMAGE")"

"$VLLM_DIR/download-model.sh"

# Keep the installed unit in sync with the repo copy.
"$VLLM_DIR/install-service.sh"

changed=0
[ "$before" != "$after" ] && changed=1
if [ "$changed" = 1 ]; then
    echo "Image changed; clearing compile caches in $VLLM_DIR/cache"
    was_active=0
    systemctl --user is-active --quiet "$UNIT" && was_active=1
    [ "$was_active" = 1 ] && systemctl --user stop "$UNIT"
    # The container writes these as root; clear them from inside a container.
    docker run --rm -v "$VLLM_DIR/cache:/cache" --entrypoint sh "$IMAGE" -c 'rm -rf /cache/* /cache/.[!.]*' || true
    [ "$was_active" = 1 ] && systemctl --user start "$UNIT"
elif systemctl --user is-active --quiet "$UNIT"; then
    systemctl --user restart "$UNIT"
fi
echo "Updated: $IMAGE, $MODEL_REPO"

#!/usr/bin/env bash
# build.sh — Pull latest llama.cpp, re-apply local patches, and rebuild.
#
# llama.cpp/ tracks upstream master and is not a submodule, so `git pull` would
# either refuse to run or silently drop any local fix. Local fixes therefore live
# in patches/ as the source of truth and are re-applied here on every build.
# A patch that stops applying is a hard error — see apply_patches() for why.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

TARGETS="llama-cli llama-mtmd-cli llama-server llama-gguf-split llama-bench"
LLAMA_DIR="$SCRIPT_DIR/llama.cpp"
PATCH_DIR="$SCRIPT_DIR/patches"

# Re-apply every patches/llamacpp-*.patch to the freshly pulled tree.
#
# Three outcomes per patch, and the third one matters:
#   applies cleanly   -> apply it
#   already applied   -> skip (reverse-check succeeds)
#   neither           -> STOP. Either the fix landed upstream (delete the patch)
#                        or upstream moved and it needs rebasing. Building on
#                        regardless would quietly ship a binary without the fix,
#                        and these patches exist because the unpatched behaviour
#                        is a hang, not a cosmetic difference.
apply_patches() {
    shopt -s nullglob
    local patches=("$PATCH_DIR"/llamacpp-*.patch)
    shopt -u nullglob

    if [ ${#patches[@]} -eq 0 ]; then
        echo "build.sh: no llama.cpp patches to apply"
        return 0
    fi

    local p name
    for p in "${patches[@]}"; do
        name="$(basename "$p")"
        if git -C "$LLAMA_DIR" apply --check "$p" 2>/dev/null; then
            git -C "$LLAMA_DIR" apply "$p"
            echo "build.sh: applied $name"
        elif git -C "$LLAMA_DIR" apply --reverse --check "$p" 2>/dev/null; then
            echo "build.sh: $name already applied, skipping"
        else
            echo "build.sh: ERROR — $name no longer applies to llama.cpp@$(git -C "$LLAMA_DIR" rev-parse --short HEAD)" >&2
            echo "  If the fix landed upstream, delete patches/$name." >&2
            echo "  Otherwise rebase it against the new tree. Refusing to build without it." >&2
            return 1
        fi
    done
}

# `./build.sh --patch-only` re-applies patches without pulling or rebuilding.
# Useful after a manual `git -C llama.cpp pull`, and to check that the patches
# still apply before committing to a full rebuild.
if [ "${1:-}" = "--patch-only" ]; then
    apply_patches
    exit $?
fi

# Discard the previous build's applied patches so the pull can fast-forward.
# Safe because patches/ is the source of truth for every local change to
# llama.cpp/ — but it does mean ad hoc edits in that tree are NOT preserved.
# If you are experimenting there, capture the work as a patch first:
#     git -C llama.cpp diff > patches/llamacpp-<topic>.patch
if [ -n "$(git -C "$LLAMA_DIR" status --porcelain --untracked-files=no)" ]; then
    echo "build.sh: discarding local changes in llama.cpp/ (re-applied from patches/ below):"
    git -C "$LLAMA_DIR" status --short --untracked-files=no | sed 's/^/  /'
    git -C "$LLAMA_DIR" checkout -- .
fi

git -C "$LLAMA_DIR" pull
apply_patches

cmake "$LLAMA_DIR" -B "$LLAMA_DIR/build" -DBUILD_SHARED_LIBS=OFF $CMAKE_FLAGS
cmake --build "$LLAMA_DIR/build" --config Release -j --target $TARGETS
cp "$LLAMA_DIR"/build/bin/llama-* "$LLAMA_DIR/"

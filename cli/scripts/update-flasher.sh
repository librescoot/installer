#!/usr/bin/env bash
# Pull librescoot-flasher-linux-arm into cli/assets/ for embedding.
#
# Usage:
#   scripts/update-flasher.sh              # use the tag pinned in FLASHER_VERSION
#   scripts/update-flasher.sh <tag>        # fetch a specific tag (e.g. v0.3.4)
#   scripts/update-flasher.sh latest       # resolve and fetch the newest release
#
# Requires: gh (GitHub CLI) authenticated for the librescoot org.
set -euo pipefail

REPO="librescoot/librescoot-flasher"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS_DIR="$CLI_DIR/assets"

if [ $# -ge 1 ]; then
  TAG="$1"
else
  TAG="$(tr -d '[:space:]' < "$ASSETS_DIR/FLASHER_VERSION")"
  echo "Using tag from FLASHER_VERSION: $TAG"
fi

# We only embed linux-arm — the binary the trampoline runs on the MDB to
# drive the DBC's USB mass-storage device. Host-side flashing uses the
# system's own dd / bmap-writer (no per-host binary needed in the CLI).
ASSET="librescoot-flasher-linux-arm"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI not found in PATH" >&2
  exit 1
fi

if [ "$TAG" = "latest" ]; then
  TAG="$(gh release view --repo "$REPO" --json tagName --jq .tagName)"
  echo "Resolved latest tag: $TAG"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $REPO@$TAG into $TMP"
gh release download "$TAG" --repo "$REPO" --pattern "$ASSET" --dir "$TMP"

install -m 0755 "$TMP/$ASSET" "$ASSETS_DIR/$ASSET"

if [ $# -ge 1 ]; then
  echo "$TAG" > "$ASSETS_DIR/FLASHER_VERSION"
fi

echo
echo "Flasher binary updated to $TAG."
echo "  file $ASSETS_DIR/$ASSET"

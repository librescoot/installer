#!/usr/bin/env bash
# Pull librescoot-flasher release artifacts into assets/tools/.
#
# Usage:
#   scripts/update-flasher.sh              # use the tag pinned in FLASHER_VERSION
#   scripts/update-flasher.sh <tag>        # fetch a specific tag (e.g. v0.2.0)
#   scripts/update-flasher.sh latest       # resolve and fetch the newest release
#
# If a tag is passed, FLASHER_VERSION is rewritten to match.
# Requires: gh (GitHub CLI) authenticated for the librescoot org.
set -euo pipefail

REPO="librescoot/librescoot-flasher"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/assets/tools"

if [ $# -ge 1 ]; then
  TAG="$1"
else
  TAG="$(tr -d '[:space:]' < "$TOOLS_DIR/FLASHER_VERSION")"
  echo "Using tag from FLASHER_VERSION: $TAG"
fi

# Platform-arch binaries we ship with the installer. Linux-arm is uploaded to
# the MDB during trampoline provisioning; the others are host flashers.
ASSETS=(
  "librescoot-flasher-linux-amd64"
  "librescoot-flasher-linux-arm"
  "librescoot-flasher-darwin-arm64"
  "librescoot-flasher-windows-amd64.exe"
)

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
for asset in "${ASSETS[@]}"; do
  gh release download "$TAG" --repo "$REPO" --pattern "$asset" --dir "$TMP"
done

echo "Installing into $TOOLS_DIR"
for asset in "${ASSETS[@]}"; do
  install -m 0755 "$TMP/$asset" "$TOOLS_DIR/$asset"
done

if [ $# -ge 1 ]; then
  echo "$TAG" > "$TOOLS_DIR/FLASHER_VERSION"
fi

echo
echo "Flasher binaries updated to $TAG. Review with:"
echo "  git status assets/tools/"
echo "  file assets/tools/librescoot-flasher-*"

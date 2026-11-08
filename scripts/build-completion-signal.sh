#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/assets/tools"
(
  cd "$root/tool/completion-signal"
  CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 GOTOOLCHAIN=go1.25.14 \
    go build -trimpath -ldflags='-s -w' -o "$root/assets/tools/completion-signal-linux-arm" .
)

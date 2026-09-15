#!/bin/sh
set -eu

PHASE="${1:-}"
EXPECTED_ARTIFACT="${2:-}"
EXPECTED_VERSION="${3:-}"
BEFORE_BOOT="${4:-}"
BEFORE_ROOT="${5:-}"
TARGET_ROOT="${6:-}"

OS_RELEASE="${OS_RELEASE:-/etc/os-release}"
BOOT_ID_FILE="${BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}"
MOUNTINFO_FILE="${MOUNTINFO_FILE:-/proc/self/mountinfo}"
MENDER_UPDATE="${MENDER_UPDATE:-mender-update}"
REDIS_CLI="${REDIS_CLI:-redis-cli}"
REDIS_HOST="${REDIS_HOST:-192.168.7.1}"

[ "$PHASE" = precommit ] || [ "$PHASE" = committed ] || [ "$PHASE" = managed ] || exit 2
[ -n "$EXPECTED_ARTIFACT" ] && [ -n "$EXPECTED_VERSION" ] || exit 3
[ -n "$BEFORE_BOOT" ] && [ -n "$BEFORE_ROOT" ] || exit 4
if [ "$PHASE" != managed ]; then
  [ -n "$TARGET_ROOT" ] || exit 5
fi

. "$OS_RELEASE" 2>/dev/null || exit 11
boot=$(cat "$BOOT_ID_FILE" 2>/dev/null) || exit 12
root=$(awk '$5 == "/" { print $3 }' "$MOUNTINFO_FILE") || exit 13
[ -n "$boot" ] && [ "$boot" != "$BEFORE_BOOT" ] || exit 14
[ -n "$root" ] && [ "$root" != "$BEFORE_ROOT" ] || exit 15
[ -z "$TARGET_ROOT" ] || [ "$root" = "$TARGET_ROOT" ] || exit 16
# Yocto canonicalizes VERSION_ID to lowercase, while release metadata keeps the
# timestamp separator as uppercase T. Compare the canonical forms; artifact
# identity below remains byte-exact.
actual_version=$(printf '%s' "${VERSION_ID:-}" | tr '[:upper:]' '[:lower:]')
expected_version=$(printf '%s' "$EXPECTED_VERSION" | tr '[:upper:]' '[:lower:]')
[ -n "$actual_version" ] && [ "$actual_version" = "$expected_version" ] || {
  echo "health-fail: version expected=$EXPECTED_VERSION actual=${VERSION_ID:-missing}" >&2
  exit 17
}

redis=$($REDIS_CLI -h "$REDIS_HOST" ping 2>/dev/null) || {
  echo "health-fail: Redis at $REDIS_HOST did not answer" >&2
  exit 18
}
[ "$redis" = PONG ] || exit 19

artifact=""
if [ "$PHASE" != precommit ]; then
  artifact=$($MENDER_UPDATE show-artifact 2>/dev/null) || exit 20
  [ "$artifact" = "$EXPECTED_ARTIFACT" ] || exit 21
fi

printf '%s|%s|%s|%s\n' "$boot" "$root" "${VERSION_ID:-}" "$artifact"

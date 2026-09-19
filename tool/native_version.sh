#!/bin/sh
set -eu

version=${1:-dev}
fallback_build=${2:-1}
clean=${version#v}
name_candidate=${clean%%-*}

if printf '%s\n' "$name_candidate" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  native_name=$name_candidate
else
  native_name=0.0.0
fi

prerelease_build=
if printf '%s\n' "$version" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+-(alpha|beta|rc)[.-][0-9]+$'; then
  prerelease_build=${version##*[.-]}
fi
case "$fallback_build" in
  ''|*[!0-9]*) fallback_build=1 ;;
esac
native_build=${prerelease_build:-$fallback_build}

printf 'name=%s\n' "$native_name"
printf 'build=%s\n' "$native_build"

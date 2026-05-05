#!/usr/bin/env bash
# Generate Markdown release notes from conventional-commit messages.
#
# Usage:
#   scripts/changelog.sh [--from <ref>] [--to <ref>] [--repo owner/name]
#
# Defaults:
#   --to    HEAD (or the tag at HEAD if there is one)
#   --from  the tag immediately preceding --to. If --to is itself a tag,
#           that's `git describe --tags --abbrev=0 <to>^`; otherwise it's
#           the most recent tag reachable from --to.
#   --repo  parsed from `git remote get-url origin`
#
# Commits are grouped by conventional-commit type (feat, fix, ui, perf,
# refactor, docs, ci, chore, ...). Anything with a `!` (e.g. `feat!:` or
# `fix(scope)!:`) is surfaced under "Breaking changes". Commits that don't
# match the conventional format land under "Other".

set -euo pipefail

from_ref=""
to_ref=""
repo=""

while [ $# -gt 0 ]; do
    case "$1" in
        --from) from_ref="$2"; shift 2 ;;
        --to)   to_ref="$2";   shift 2 ;;
        --repo) repo="$2";     shift 2 ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "unknown arg: $1" >&2
            exit 2
            ;;
    esac
done

if [ -z "$to_ref" ]; then
    if to_tag=$(git describe --tags --exact-match HEAD 2>/dev/null); then
        to_ref="$to_tag"
    else
        to_ref="HEAD"
    fi
fi

if [ -z "$from_ref" ]; then
    if git describe --tags --exact-match "$to_ref" >/dev/null 2>&1; then
        from_ref=$(git describe --tags --abbrev=0 "${to_ref}^" 2>/dev/null || true)
    else
        from_ref=$(git describe --tags --abbrev=0 "$to_ref" 2>/dev/null || true)
    fi
fi

if [ -z "$repo" ]; then
    origin=$(git remote get-url origin 2>/dev/null || echo "")
    case "$origin" in
        git@github.com:*) repo="${origin#git@github.com:}"; repo="${repo%.git}" ;;
        https://github.com/*) repo="${origin#https://github.com/}"; repo="${repo%.git}" ;;
    esac
fi

if [ -n "$from_ref" ]; then
    range="${from_ref}..${to_ref}"
else
    range="$to_ref"
fi

# Groups keyed by canonical heading. Order here is the rendering order.
groups_order=(
    "Breaking changes"
    "Features"
    "Bug fixes"
    "UI"
    "Performance"
    "Refactoring"
    "Documentation"
    "CI"
    "Build"
    "Chores"
    "Reverts"
    "Other"
)

declare -A groups
for g in "${groups_order[@]}"; do groups["$g"]=""; done

map_type() {
    case "$1" in
        feat|feature)        echo "Features" ;;
        fix|bug|bugfix)      echo "Bug fixes" ;;
        ui)                  echo "UI" ;;
        perf)                echo "Performance" ;;
        refactor)            echo "Refactoring" ;;
        docs|doc)            echo "Documentation" ;;
        ci)                  echo "CI" ;;
        build)               echo "Build" ;;
        chore|test|style)    echo "Chores" ;;
        revert)              echo "Reverts" ;;
        *)                   echo "Other" ;;
    esac
}

# Read commits as TAB-separated <sha>\t<subject>. --no-merges drops merge
# commits; squash-merge commits stay because they're regular commits.
while IFS=$'\t' read -r sha subject; do
    [ -z "$sha" ] && continue

    type=""
    scope=""
    breaking=""
    desc="$subject"

    cc_re='^([a-zA-Z]+)(\(([^)]+)\))?(!)?: (.+)$'
    if [[ "$subject" =~ $cc_re ]]; then
        type="${BASH_REMATCH[1]}"
        scope="${BASH_REMATCH[3]}"
        breaking="${BASH_REMATCH[4]}"
        desc="${BASH_REMATCH[5]}"
    fi

    type_lc="$(echo "$type" | tr '[:upper:]' '[:lower:]')"

    if [ -n "$breaking" ]; then
        bucket="Breaking changes"
    else
        bucket=$(map_type "$type_lc")
    fi

    short="${sha:0:7}"
    if [ -n "$repo" ]; then
        link="([\`${short}\`](https://github.com/${repo}/commit/${sha}))"
    else
        link="(\`${short}\`)"
    fi

    # Strip the redundant `installer` scope — this is the installer repo.
    # Keep informative scopes like `download`, `keycard`, `sidebar`, etc.
    if [ -n "$scope" ] && [ "$scope" != "installer" ]; then
        line="- **${scope}:** ${desc} ${link}"
    else
        line="- ${desc} ${link}"
    fi

    groups["$bucket"]+="${line}"$'\n'
done < <(git log --no-merges --reverse --pretty=tformat:'%H%x09%s' "$range")

# Render
echo "## What's changed"
echo

any_section=0
for g in "${groups_order[@]}"; do
    content="${groups[$g]:-}"
    if [ -n "$content" ]; then
        any_section=1
        echo "### $g"
        echo
        printf "%s" "$content"
        echo
    fi
done

if [ "$any_section" -eq 0 ]; then
    echo "_No notable changes._"
    echo
fi

if [ -n "$repo" ] && [ -n "$from_ref" ]; then
    echo "**Full changelog**: https://github.com/${repo}/compare/${from_ref}...${to_ref}"
elif [ -n "$repo" ]; then
    echo "**Full changelog**: https://github.com/${repo}/commits/${to_ref}"
fi

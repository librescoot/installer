#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

CHANNELS = ("stable", "testing", "nightly", "bootstrap")
BOARDS = ("mdb", "dbc")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def fail(message: str) -> None:
    raise ValueError(message)


def load_manifest(filename: str) -> dict:
    data = json.loads(Path(filename).read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        fail("manifest root is not an object")
    return data


def validate_release(channel: str, release: object) -> set[str]:
    if not isinstance(release, dict):
        fail(f"{channel} is not an object")
    if not isinstance(release.get("tag_name"), str) or not release["tag_name"]:
        fail(f"{channel} has no tag_name")
    if not isinstance(release.get("published_at"), str):
        fail(f"{channel} has no published_at")
    if not isinstance(release.get("prerelease"), bool):
        fail(f"{channel} has no prerelease flag")
    assets = release.get("assets")
    if not isinstance(assets, list) or not assets:
        fail(f"{channel} has no assets")

    names: set[str] = set()
    for asset in assets:
        if not isinstance(asset, dict):
            fail(f"{channel} contains an invalid asset")
        name = asset.get("name")
        size = asset.get("size")
        digest = asset.get("sha256")
        url = asset.get("url")
        if not isinstance(name, str) or not name:
            fail(f"{channel} contains an unnamed asset")
        if name in names:
            fail(f"{channel} contains duplicate asset {name}")
        if not isinstance(size, int) or isinstance(size, bool) or size <= 0:
            fail(f"{channel}/{name} has an invalid size")
        if not isinstance(digest, str) or not SHA256.fullmatch(digest):
            fail(f"{channel}/{name} has an invalid SHA-256")
        if not isinstance(url, str) or not url.startswith("https://"):
            fail(f"{channel}/{name} has an invalid URL")
        names.add(name)
    return names


def require_artifact(names: set[str], channel: str, board: str, suffix: str) -> None:
    if not any(f"-unu-{board}-" in name and name.endswith(suffix) for name in names):
        fail(f"{channel} has no {board} {suffix} artifact")


def validate(filename: str) -> None:
    manifest = load_manifest(filename)
    releases = {}
    for channel in CHANNELS:
        if channel not in manifest:
            fail(f"missing {channel} release")
        releases[channel] = validate_release(channel, manifest[channel])

    for channel in ("stable", "testing", "nightly"):
        for board in BOARDS:
            require_artifact(releases[channel], channel, board, ".mender")
            require_artifact(releases[channel], channel, board, ".sdimg.gz")
            require_artifact(releases[channel], channel, board, ".sdimg.bmap")
    for board in BOARDS:
        minimal = {name for name in releases["bootstrap"] if "-minimal-" in name}
        require_artifact(minimal, "bootstrap", board, ".sdimg.gz")
        require_artifact(minimal, "bootstrap", board, ".sdimg.bmap")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} MANIFEST", file=sys.stderr)
        sys.exit(2)
    try:
        validate(sys.argv[1])
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"invalid release manifest: {error}", file=sys.stderr)
        sys.exit(1)

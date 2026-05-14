# librescoot-install (CLI)

A Linux/macOS command-line installer for Librescoot. Flashes the MDB,
drives the on-MDB DBC trampoline, optionally seeds settings and keycard
UIDs, and survives moving between scooters mid-run by persisting state
on the MDB itself.

The Flutter GUI installer (in the `main` branch of this repo) does the
same job through a wizard; this CLI is for batch installs, scripted
provisioning, and operators who'd rather type than click.

## Install

```bash
make build           # fetches the embedded ARM flasher, builds bin/librescoot-install
```

Cross-compile targets:

```bash
make build-linux-amd64
make build-linux-arm
make build-darwin-arm64
make build-windows-amd64
```

Pinned `librescoot-flasher` tag lives in `assets/FLASHER_VERSION`. The
ARM build is embedded into the CLI and uploaded to the MDB during the
DBC trampoline phase — there is no host-side flasher binary embedded;
the CLI uses the system's own `dd` or `bmap-writer` for host I/O.

## Commands

```
librescoot-install <command> [flags]

install        run the full sequential flow (phase1 + phase2 + phase3) with prompts
phase1         flash MDB and boot it into Librescoot (host-attended)
phase2         stage DBC artifacts and start the trampoline (detaches on MDB)
phase3         finish: persist channel, unlock, start keycard, reboot
auto           detect current phase and run the next applicable one
station        long-running loop: auto-run phase when scooter connects, prompt to swap
apply-profile  push a TOML profile (settings + keycard UIDs) to a scooter
```

All commands need `--password` (or `MDB_PASSWORD` env). Default MDB host
is `192.168.7.1`. Add `--verbose` to see executed commands.

### Typical batch flow

```bash
# Stage 1 — attend the scooter, flash MDB, then walk away
librescoot-install phase1 \
  --channel testing \
  --osm-tiles ./tiles/berlin.mbtiles \
  --valhalla-tiles ./tiles/berlin-valhalla.tar \
  --language de \
  --yes

# Stage 2 — kick off DBC trampoline (detaches on MDB; CLI exits)
librescoot-install phase2 --channel testing

# Optional — wait for the trampoline to report success (or run from station mode)
# librescoot-install phase2 --channel testing --yes   # --yes also enables wait

# Stage 3 — finish (after trampoline reports success)
librescoot-install phase3 --language de --channel testing

# Pre-seed settings + keycards
librescoot-install apply-profile --file fleet-profile.toml
```

### Auto / station

```bash
# Detect what phase this scooter is in and run the next one
librescoot-install auto --channel testing

# Long-running loop — connect a scooter, the CLI runs the right phase,
# then prompts you to swap. Ctrl-C to exit.
librescoot-install station --channel testing
```

State lives on the MDB at `/data/installer/state.json`; it is the
source of truth for "what phase are we in". `auto` and `station` read
it (and fall back to probing scooter state when the file is missing).

## Profile format (`apply-profile`)

A small subset of TOML: `[section]` headers, `key = value` scalars, and
inline arrays of strings under `[keycards]`. Settings keys correspond
1:1 with `settings-service` (see `settings.schema.json` in the
settings-service repo).

```toml
[scooter]
auto-standby-seconds = 600
dual-battery = "true"

[alarm]
enabled = "false"
duration-seconds = 30

[cellular]
apn = "internet.provider.de"

[dashboard]
language = "de"
theme = "dark"

[keycards]
master_uids     = ["04B1A2C3D4E5F6"]
authorized_uids = ["DEADBEEFCAFE01", "DEADBEEFCAFE02", "AA-BB-CC-DD-EE-FF"]
```

UID separators (` `, `:`, `-`) are stripped on load and the result is
upper-cased. Settings are sent through `redis-cli` HSET +
PUBLISH-per-key on the MDB; settings-service watches the `settings`
pub/sub channel and persists changes to `/data/settings.toml`
automatically — no service restart needed. Keycard UIDs are written
atomically (tmp + `sync` + rename) to `/data/keycard/{master,authorized}_uids.txt`.

## Network

The MDB exposes RNDIS at USB `0525:a4a2` and switches to USB Mass
Storage at `0525:a4a5` during flashing. The host needs `192.168.7.50/24`
on the corresponding `enx*` / `usb0` interface; the CLI configures this
itself if NetworkManager hasn't (`sudo` is required for `ip addr add`).

## Embedded assets

- `assets/trampoline.sh.template` — the on-MDB script that drives the
  DBC flash, tile upload, and post-flash reboot. Substituted with the
  staged paths at runtime.
- `assets/librescoot-flasher-linux-arm` — ARM build of the flasher
  binary, uploaded to the MDB; fetched at build time by
  `scripts/update-flasher.sh` based on `assets/FLASHER_VERSION`.
- `assets/fw_setenv` / `assets/fw_env.config` — stock-MDB U-Boot env
  tools (statically linked) for setting the UMS bootcmd before the
  install.
- `assets/fw_setenv-dbc` / `assets/fw_env-dbc.config` — same, but for
  the DBC's U-Boot env layout (different MMC offset).

## Out of scope

- CBB reconnect handholding (operator handles it)
- BLE pairing (the finish phase unlocks the scooter so the dashboard
  is reachable; pair via mobile app)
- Master keycard teach-in (the finish phase starts
  `librescoot-keycard`; the operator taps a card to teach it)
- Map tile generation (point at pre-built files with `--osm-tiles` /
  `--valhalla-tiles`)

# Librescoot Installer

Two flavours, same job: flash an MDB with Librescoot, drive the on-MDB
trampoline to flash the DBC, and bring the scooter up to a state where
it can be paired and ridden.

- **GUI** — a Flutter desktop wizard, see the [`main`
  branch](https://github.com/librescoot/installer/tree/main). Hands an
  operator through every step with screenshots and confirmations.
- **CLI** — `cli/`, this branch. Headless, scriptable, phase-aware. Built
  for batch installs and operators who'd rather type than click.

## Which one do I want?

| You're… | Use |
|---|---|
| Flashing your own scooter, once | GUI |
| Provisioning a fleet | CLI |
| Pre-seeding settings or keycard UIDs from a profile | CLI |
| Scripting installs from CI | CLI |
| Auto-detecting "where is this scooter in the flow" | CLI |

## CLI quickstart

Build (`make` fetches the embedded ARM flasher binary, then compiles):

```bash
cd cli
make build
./bin/librescoot-install --help
```

Single-shot install with prompts (closest to the GUI flow):

```bash
MDB_PASSWORD=... ./bin/librescoot-install install --channel testing
```

Unattended batch flow (phase-split, scriptable):

```bash
MDB_PASSWORD=... ./bin/librescoot-install phase1 --channel testing --yes
# ... operator unplugs scooter, plugs in the next one
MDB_PASSWORD=... ./bin/librescoot-install phase2 --channel testing
# ... later, when the on-MDB trampoline reports success
MDB_PASSWORD=... ./bin/librescoot-install phase3 --channel testing
```

Station mode (one CLI invocation, many scooters):

```bash
MDB_PASSWORD=... ./bin/librescoot-install station --channel testing
```

Pre-seed settings + keycard UIDs from a TOML profile:

```bash
MDB_PASSWORD=... ./bin/librescoot-install apply-profile --file fleet.toml
```

Full command reference and the profile format live in
[`cli/README.md`](cli/README.md).

## Target hardware

- MDB ethernet mode: `VID 0525`, `PID A4A2`
- MDB mass-storage mode: `VID 0525`, `PID A4A5`
- MDB SDP recovery: `VID 15A2`, `PID 007D`
- DBC SDP recovery: `VID 15A2`, `PID 0061`

Network: the MDB is at `192.168.7.1`; the host configures
`192.168.7.50/24` on the corresponding `enx*` / `usb0` interface.

## Safety model (CLI)

- Refuses to flash anything not in the expected USB `0525:*` range.
- Skips block devices that look like the system disk (`sda` if mounted).
- Stages everything on the MDB under `/data/installer/` so the cleanup at
  the finish phase removes it with a single `rm -rf`.
- Persists state on the MDB at `/data/installer/state.json` — so `auto`
  and `station` can resume on the right phase if you crash, time out, or
  pick the scooter up on a different host machine later.
- Disables `auto-standby` and the alarm on every SSH entry so a locked
  scooter can't suspend or scream at you mid-flash; restores at the
  finish phase.
- Holds the MDB USB gadget at `always-on` for the duration of the
  install; resets to `auto` at the finish phase.

## Repo layout

```
cli/                # Go CLI installer (this branch's main deliverable)
  main.go           # subcommand dispatch
  install.go        # phase orchestration (phase1/2/3, full install)
  trampoline.go     # DBC trampoline driver + embedded ARM flasher
  profile.go        # apply-profile (TOML → Redis + /data/keycard)
  state.go          # /data/installer/state.json on the MDB
  station.go        # long-running USB-watcher loop
  ssh.go            # SSH helpers with reconnect-on-disconnect
  mdb.go            # USB / RNDIS / network plumbing
  bootloader.go     # fw_setenv-driven UMS handoff
  flash.go          # host-side dd / bmap-writer
  boot.go           # post-flash boot wait
  release.go        # GitHub release downloads (MDB + DBC + bmaps)
  log.go            # console output
  assets/           # embedded: trampoline script, fw tools, ARM flasher
  scripts/          # update-flasher.sh (fetches pinned flasher tag)

lib/, screens/, …   # Flutter installer sources (main branch)
```

## License

CC-BY-NC-4.0, same as `main`.

# LibreScoot Simple GUI Installer — Design Spec

## Overview

A Flutter desktop application (Windows, macOS, Linux) that guides users through a complete LibreScoot firmware installation on both MDB and DBC boards. Replaces the existing 6-step MDB-only installer with a comprehensive 14-phase wizard that handles firmware download, two-phase safe flashing, and autonomous DBC flashing via a trampoline script.

## Installation Flow

### Phase 0: Welcome

- Display prerequisites: PH2 screwdriver or H4 screwdriver for footwell screws, flat head screwdriver or PH1 for USB cable, USB laptop to Mini-B cable, ~45 minutes
- Channel selection: `stable` (default if available) → `testing` (fallback) → `nightly` (opt-in)
- Ask: "Will your scooter be online or offline?" (most are offline)
- If offline: select region from German states for offline map + routing tile download
- If online: ask if user wants offline maps anyway (for faster/reliable navigation) or will use online tiles + routing
- Begin background downloads in priority order:
  1. MDB firmware image (needed first)
  2. DBC firmware image
  3. Display map tiles (`.mbtiles`, 12–500 MB depending on region)
  4. Routing tiles (`.tar`, 12–712 MB depending on region)
- Show download progress; can proceed to Phase 1 while downloading

**Region selection (15 options):**

| Region | OSM Tiles | Valhalla Tiles |
|--------|-----------|---------------|
| Baden-Württemberg | 317 MB | 479 MB |
| Bayern | 384 MB | 712 MB |
| Berlin & Brandenburg | 141 MB | 214 MB |
| Bremen | 12 MB | 12 MB |
| Hamburg | 24 MB | 20 MB |
| Hessen | 172 MB | 224 MB |
| Mecklenburg-Vorpommern | 60 MB | 75 MB |
| Niedersachsen | 266 MB | 373 MB |
| Nordrhein-Westfalen | 500 MB | 548 MB |
| Rheinland-Pfalz | 133 MB | 174 MB |
| Saarland | 31 MB | 27 MB |
| Sachsen | 119 MB | 141 MB |
| Sachsen-Anhalt | 88 MB | 97 MB |
| Schleswig-Holstein | 85 MB | 116 MB |
| Thüringen | 79 MB | 84 MB |

### Phase 1: Physical Prep

Instructions with descriptions and images (use placeholders for now):

1. Remove footwell cover (Fußraumabdeckung) - image shows footwell cover and highlights screw locations
2. Unscrew internal DBC USB cable from MDB - image shows USB connector close up
3. Connect laptop USB cable to MDB

### Phase 2: MDB Connect

Automatic steps:

1. Detect RNDIS device (VID `0525`, PID `A4A2`)
2. Install INF driver if needed (Windows only, via `pnputil`)
3. Configure USB network interface (host IP `192.168.7.50`, MDB at `192.168.7.1`, subnet `255.255.255.0`)
4. SSH into MDB (`root@192.168.7.1`), detect firmware version, authenticate with version-specific password

### Phase 3: Health Check

Query Redis on MDB to verify scooter readiness:

| Check | Redis Command | Threshold |
|-------|--------------|-----------|
| AUX battery charge | `HGET aux-battery charge` | ≥ 50% |
| CBB state of health | `HGET cb-battery state-of-health` | ≥ 99% |
| CBB charge | `HGET cb-battery charge` | ≥ 80% |
| Main battery present | `HGET battery:0 present` | if `true`, user is told to remove it in phase 4; if `false`, we continue |

If any check fails, display current values and instruct user to charge/fix before retrying.

### Phase 4: Battery Removal

1. Open seatbox via Redis: `LPUSH scooter:seatbox open`
2. Instruct user to remove main battery (Fahrakku) IF present
3. Poll `HGET battery:0 present` until `false`
4. Seatbox remains open for the rest of the installation

### Phase 5: MDB → UMS

1. Upload `fw_setenv` binary and `fw_env.config` to MDB `/tmp`
2. Set bootloader: `fw_setenv bootcmd "ums 0 mmc 1"`, `fw_setenv bootdelay 0`
3. Optionally set fuse bits for legacy boards: `fuse prog -y 0 5 0x00002860; fuse prog -y 0 6 0x00000010`
4. Reboot MDB
5. Wait for UMS device detection (VID `0525`, PID `A4A5`)

### Phase 6: MDB Flash

Two-phase write strategy for safety. While U-Boot has `bootcmd "ums 0 mmc 1"`, any interruption during Phase A leaves the device safely looping back to UMS mode.

**Disk layout (MDB — `/dev/mmcblk1`):**

| Offset | Content |
|--------|---------|
| 0x000 | MBR |
| 0x400 | U-Boot (`u-boot-dtb.imx`, ~461KB) |
| 0x800000 (8MB) | U-Boot env primary (128KB) |
| 0x1000000 (16MB) | U-Boot env redundant (128KB) |
| Sector 49152 (24MB) | /boot partition (32MB FAT32) |
| 56MB | rootfs-A (512MB ext4) |
| 568MB | rootfs-B (512MB ext4) |
| 1080MB | /data (remaining space, ext4) |

**Phase A — Write partitions (safe):**
```
gunzip -c image.sdimg.gz | dd bs=4M skip=6 seek=6 of=/dev/TARGET
```
Writes everything from 24MB onwards. If interrupted, U-Boot still boots to UMS.

**Phase B — Write boot sector (commits the flash):**
```
gunzip -c image.sdimg.gz | dd bs=4M count=6 of=/dev/TARGET
sync
```
Writes first 24MB including U-Boot and MBR. After this, U-Boot will boot Linux on next power cycle.

Progress tracking via dd stderr output parsing.

### Phase 7: Scooter Prep

MDB is in UMS mode (no OS running) — instructions only, no Redis verification. **Strong warnings required.**

1. **Disconnect CBB** — Emphasize: "The main battery must already be removed before disconnecting CBB. Failure to follow this order risks electrical damage."
2. **Disconnect one AUX pole** — This removes power from MDB. USB connection will disappear. Emphasize that ONLY one pole, ideally the positive pole (the outermost one, color-coded red) should be removed, so avoid risk of inverting polarity.

### Phase 8: MDB Boot

1. Instruct user to reconnect AUX pole
2. Wait for USB re-enumeration:
   - If UMS device (PID `A4A5`) appears → flash didn't take, retry from Phase 6
   - If RNDIS device (PID `A4A2`) appears → MDB booted into LibreScoot, continue
   - If nothing appears → check AUX connection, check cable
3. User visual feedback: DBC boot LED turns orange on startup, green during boot, off when running
4. Ping MDB (`192.168.7.1`) until stable for 10 consecutive seconds (accounts for partition resize reboots)
5. Re-establish SSH connection

### Phase 9: CBB Reconnect

1. Instruct user to reconnect CBB (more power capacity for DBC flash phases)
2. Verify via Redis: `HGET cb-battery present` = `true`

### Phase 10: DBC Prep & Configuration

Parallel uploads to MDB `/data` via SCP (block if any background downloads still running):

1. Upload DBC firmware image (`librescoot-unu-dbc-*.sdimg.gz`)
2. Upload display map tiles (`tiles_{region}.mbtiles`) — if offline maps selected
3. Upload routing tiles (`valhalla_tiles_{region}.tar`) — if offline routing selected
4. Upload SHA256 checksums for tile verification
5. Generate and upload trampoline shell script (includes tile installation steps)
6. Start trampoline script on MDB in background (`nohup`)
7. Instruct user: "Please disconnect USB from laptop and reconnect the DBC USB cable to MDB"


### Phase 11: DBC Flash

Trampoline script runs autonomously on MDB. Installer cannot communicate with MDB during this phase.

**Trampoline sequence:**

1. Detect laptop USB disconnect (poll `/sys/class/udc/ci_hdrc.0/state`)
2. Boot LED → amber; front ring position light on (constant = working)
3. Wait for USB network to form with DBC (MDB gadget, DBC host → `192.168.7.x`)
4. `lsc dbc on-wait` — power on DBC, wait for it to be reachable
5. Boot LED → green; additional position lights on
6. SSH to DBC (`root@192.168.7.2`):
   - Stop dashboard UI: `systemctl stop dbc-dashboard-ui` (or equivalent)
   - Upload fw_setenv tools
   - Set bootloader: `fw_setenv bootcmd "ums 0 mmc 2"`, `fw_setenv bootdelay 0`
   - Optionally set DBC fuse bits: `fuse prog -y 0 5 0x00003860; fuse prog -y 0 6 0x00000010`
7. Reboot DBC
8. Switch MDB USB to host mode (unload gadget modules, exact mechanism TBD — verify on hardware)
9. Wait for DBC block device to appear (`/dev/sdX` on MDB)
10. Two-phase flash DBC (same strategy as MDB, 24MB split):
    ```
    gunzip -c /data/dbc-image.sdimg.gz | dd bs=4M skip=6 seek=6 of=/dev/sdX
    gunzip -c /data/dbc-image.sdimg.gz | dd bs=4M count=6 of=/dev/sdX
    sync
    ```
11. Switch MDB USB back to gadget mode (reload `g_ether`)
12. Power cycle DBC
13. Wait for DBC to boot, SSH in
14. Install map tiles on DBC (if selected):
    - Copy `/data/tiles_{region}.mbtiles` → DBC `/data/maps/map.mbtiles`
    - Copy `/data/valhalla_tiles_{region}.tar` → DBC `/data/valhalla/tiles.tar`
    - Verify SHA256 checksums
    - Restart Valhalla routing service: `systemctl restart valhalla`
15. Run firstrun: `systemctl start firstrun` → DBC displays "Erfolgreich!"
16. Write status file to `/data/trampoline-status` (success/failure + details)
17. Boot LED → green (success) or red (error)

**LED signals during trampoline:**

| State | Boot LED | Scooter LEDs |
|-------|----------|-------------|
| Started / working | Amber | Front ring constant |
| DBC connected | Green | Front + rear position lights constant |
| DBC flashing | Green | All position lights constant |
| Success | Green | Brief celebration, then off |
| Error | Red | Hazard flashers (`lsc led cue blink-both`) |

**Timeout/fallback:**
- Each step has a timeout (e.g. 60s for DBC ping, 120s for UMS device)
- On failure: write error to status file, switch USB back to gadget mode, trigger hazard flashers
- On success: write success to status file, boot LED green

### Phase 12: Reconnect & Verify

1. Instruct user: "Reconnect USB cable from MDB to laptop" (hazard flashers = error, green boot LED = success)
2. Wait for RNDIS device detection
3. SSH into MDB, read `/data/trampoline-status`
4. If error: display error log, offer retry options
5. If success: continue

### Phase 13: Finish

1. Instruct user:
   - Reconnect internal DBC USB cable to MDB (screw it back)
   - Insert main battery
   - Close seatbox
   - Replace footwell cover
   - Unlock scooter (keycard/BT pairing handled by LibreScoot first-run)
2. Offer to delete downloaded firmware images and tiles (show total size)
3. Display: "Welcome to LibreScoot!"

## Firmware Download & Caching

### Release Resolution

**Firmware images:**
- GitHub API: `GET /repos/librescoot/librescoot/releases`
- Channel matching: find latest release where tag starts with channel name (`stable-*`, `testing-*`, `nightly-*`)
- Channel priority for default: `stable` → `testing` (only if no stable release exists)
- Asset selection: `librescoot-unu-mdb-<tag>.sdimg.gz` and `librescoot-unu-dbc-<tag>.sdimg.gz`
- Filter to `unu-*` variants only

**Map tiles (if offline maps selected):**
- Display tiles: `GET /repos/librescoot/osm-tiles/releases/tags/latest`
  - Asset: `tiles_{slug}.mbtiles` + `tiles_{slug}.mbtiles.sha256`
- Routing tiles: `GET /repos/librescoot/valhalla-tiles/releases/tags/latest`
  - Asset: `valhalla_tiles_{slug}.tar` + `valhalla_tiles_{slug}.tar.sha256`
- Region slug mapping: lowercase with hyphens (e.g. `schleswig-holstein`), Berlin+Brandenburg combined as `berlin_brandenburg`

### Caching

- Cache directory:
  - Linux/macOS: `~/.cache/librescoot-installer/`
  - Windows: `%LOCALAPPDATA%\LibreScoot\Installer\cache\`
- Cache key: full asset filename (unique per channel + timestamp)
- Validation: check file exists and matches expected size from GitHub API
- No automatic cleanup; user offered deletion at end of install

### Download Behavior

- Starts in background during Phase 0 after channel selection
- Progress: MB downloaded / total MB with progress bar
- Firmware must complete before Phase 6 (MDB Flash) — firmware downloads can overlap with Phases 1-5
- Tile downloads must complete before Phase 10 (DBC Prep) — tiles can download during Phases 1-9
- On failure: retry with exponential backoff, offer local file selection as fallback
- No GitHub authentication required (public releases)

## Architecture

### Services (existing, modified)

- **FlashService** — Add two-phase write capability: `skip`/`seek` and `count` parameters for dd. Support two-pass gunzip streaming.
- **SshService** — Add Redis query commands (`HGET`, `LPUSH`), seatbox control, fw_setenv for DBC (`ums 0 mmc 2`), DBC SSH via MDB proxy.
- **UsbDetector** — No changes. Already detects RNDIS (`A4A2`) and UMS (`A4A5`).
- **NetworkService** — No changes.
- **ElevationService** — No changes.
- **DriverService** — No changes.

### Services (new)

- **DownloadService** — GitHub API client, release resolution by channel, download with progress callbacks, cache management. Handles firmware images (librescoot/librescoot), display tiles (librescoot/osm-tiles), and routing tiles (librescoot/valhalla-tiles).
- **TrampolineService** — Generate trampoline shell script (templated with DBC image path, tile paths, timeouts), upload to MDB via SCP, upload DBC image + tiles, parse status file after reconnect.

### Models

- **InstallerPhase** — Enum replacing current `InstallerStep` (14 phases)
- **ScooterHealth** — Holds Redis health check values (AUX charge, CBB SoH, CBB charge, battery present)
- **DownloadState** — Channel, selected release tag, download progress, cached status
- **TrampolineStatus** — Parsed from `/data/trampoline-status` (success/error, details, checksums)

### State Management

StatefulWidget + setState (current pattern). The flow is linear; a full state management library is not warranted.

## UI Design

### Layout

Vertical stepper wizard:
- **Left sidebar** (~200px): numbered phase list, current phase highlighted (green), completed phases checked (gray), future phases dimmed
- **Main area**: current phase content — instructions, status messages, progress bars, verification checklists
- **Bottom**: Back/Next navigation (disabled during automatic phases)

### Theme

Dark theme with teal accent (matching current app). Material 3.

## Error Handling & Recovery

### Per-Phase Recovery

| Phase | Failure | Recovery |
|-------|---------|----------|
| 0 | Download fails | Retry with backoff, offer local file fallback |
| 2 | RNDIS not detected | Retry detection, check cable/driver guidance |
| 2 | SSH auth fails | Try all known passwords, prompt manual entry |
| 3 | Charge too low | Show values, instruct to charge, retry |
| 4 | Seatbox won't open | Retry command |
| 5 | fw_setenv fails | Retry, show SSH error |
| 5 | UMS never appears | Timeout → suggest power cycle |
| 6 | dd fails (Phase A) | Safe — U-Boot loops to UMS, retry |
| 6 | dd fails (Phase B) | Dangerous but rare — retry |
| 8 | UMS appears instead of RNDIS | Flash didn't take → retry from Phase 6 |
| 8 | Nothing appears | Check AUX, check cable |
| 11 | Trampoline error | Read status file, display log, offer retry |
| 11 | USB never reconnects | Timeout → instruct reconnect, read log |

### Resume Detection

On app launch, detect current device state:
- RNDIS device → SSH in, check if LibreScoot or stock → determine phase
- UMS device → MDB in flash-ready state, resume from Phase 6
- No device → start from Phase 1

## DBC Partition Layout

Confirmed identical boot area layout to MDB (24MB split applies):

| Offset | Content |
|--------|---------|
| Sector 49152 (24MB) | /boot (32MB FAT32) |
| 56MB | rootfs-A (1GB ext4) |
| ~1.1GB | rootfs-B (1GB ext4) |
| ~2.1GB | /data (remaining, ext4) |

U-Boot env at same offsets: 8MB and 16MB (128KB each).
DBC eMMC is `/dev/mmcblk3` in Linux, `mmc 2` in U-Boot.
DBC fuse bits differ: `0x00003860` (vs MDB's `0x00002860`).

## USB Topology

MDB has one physical USB connector (ci_hdrc.0, OTG). An internal cable normally connects DBC to this port.

**Cable swaps during installation:**

| When | Action | Result |
|------|--------|--------|
| Phase 1 | Disconnect DBC cable, connect laptop | Laptop ↔ MDB (RNDIS) |
| Phase 10 | Disconnect laptop, reconnect DBC cable | MDB ↔ DBC (network, then UMS) |
| Phase 12 | Disconnect DBC cable, connect laptop | Laptop ↔ MDB (verify results) |
| Phase 13 | Disconnect laptop, reconnect DBC cable permanently | Normal operation restored |

**USB role switching on MDB:**
- Gadget mode: `g_ether` kernel module (RNDIS network)
- Host mode: unload gadget modules (exact mechanism TBD — verify on hardware)
- Detach detection: poll `/sys/class/udc/ci_hdrc.0/state`

## Scoped Out / Deferred

- **MDB backup** (dd of running system before flash) — deferred to future version
- **Keycard enrollment / Bluetooth pairing** — handled by LibreScoot first-run experience, not the installer
- **Advanced mode** — use CLI installer or manual steps
- **Redis-verified physical steps during UMS mode** (Phase 7) — impossible, instruction-only

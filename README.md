# Librescoot Installer

> **Beta development.** The automatic dashboard handoff and its LED/front-ring signals require physical hardware validation. Automated tests and simulated recordings do not establish hardware safety. Flashing firmware carries inherent risk; use at your own risk, with no warranty expressed or implied.

Part of the [Librescoot](https://librescoot.org/) open-source platform.

Cross-platform desktop app for installing [Librescoot](https://librescoot.org) on the unu Scooter Pro (MDB + DBC).

## What it does

Step-by-step wizard for converting stock scooterOS to Librescoot:

1. Download firmware and map tiles from GitHub releases (stable/testing/nightly)
2. Connect to the MDB over USB RNDIS, detect hardware, read serial and firmware version
3. Flash MDB: set U-Boot to mass storage mode, write image with `librescoot-flasher` (bmap support for sparse writes)
4. Flash DBC: autonomous "trampoline" process where the MDB switches to USB host, flashes the DBC, and reboots
5. Post-install: offline map tiles, Bluetooth pairing, keycard setup

Also handles Librescoot-to-Librescoot re-flashing (detects installed firmware, offers skip options).

## Download

Grab the latest build for your platform at [downloads.librescoot.org](https://downloads.librescoot.org).

## Platforms

| Platform | MDB Flash | DBC Flash | Notes |
|----------|-----------|-----------|-------|
| Linux    | Yes       | Yes       | Primary, tested end-to-end |
| macOS    | Yes       | Yes       | Uses `authopen` for raw disk access |
| Windows  | Yes       | Yes       | Bundled RNDIS driver, `diskpart` for disk management |

## What you need

- USB cable (laptop Mini-B to scooter MDB)
- PH2 or H4 screwdriver for the footwell screws
- About 20 minutes

The installer handles elevation, driver installation, and network config on its own.

## USB device IDs

| Mode | VID | PID | What |
|------|-----|-----|------|
| Ethernet (RNDIS) | `0525` | `A4A2` | SSH access for bootloader config |
| Mass Storage (UMS) | `0525` | `A4A5` | Direct eMMC access for flashing |
| Recovery (NXP) | `15A2` | `0061` | DBC i.MX6SL boot ROM in SDP / serial-download mode (detected, not used) |
| Recovery (NXP) | `15A2` | `007D` | MDB i.MX6UL boot ROM in SDP / serial-download mode (detected, not used) |

## Project layout

```
lib/                              # Flutter/Dart GUI
  screens/installer_screen.dart   #   Wizard flow
  services/
    ssh_service.dart              #   SSH, bootloader config
    flash_service.dart            #   Platform-specific writes
    download_service.dart         #   GitHub releases, caching
    trampoline_service.dart       #   Autonomous DBC flash
    usb_detector.dart             #   USB device detection
    network_service.dart          #   RNDIS interface config

assets/
  tools/                          # Platform binaries (flasher, fw_setenv)
    FLASHER_VERSION               #   Pinned librescoot-flasher tag
  drivers/                        # Windows RNDIS driver
  trampoline.sh.template          # DBC flash script, runs on MDB
  images/                         # Instructional photos

scripts/
  update-flasher.sh               # Pull flasher binaries from upstream
```

The flash tool is maintained in [librescoot/librescoot-flasher][flasher-repo].
CI fetches the release artifacts pinned in `assets/tools/FLASHER_VERSION`
before each build; for local development run `scripts/update-flasher.sh`.

[flasher-repo]: https://github.com/librescoot/librescoot-flasher

## Device-owned installation

Every authenticated connection, including a silent reconnect, must match the device's chip UID for this installer session. An unreadable or different UID blocks the connection before setup or queued commands can run. Start a new installer session to install another scooter. Dashboard handoff requests a vehicle lock and requires confirmed `stand-by` before arming or launching work.

A running dashboard handoff, MDB update or finalization owns the installation. Reconnecting observes that work without changing services, replacing its run state or cleaning up its files. The installer waits across the MDB activation reboot.

Finishing without the dashboard can still install the selected MDB update and reboot the MDB. The confirmation states this when the MDB update is pending. A finalized incomplete dashboard outcome is reported as incomplete, not treated as an interrupted run.

## Diagnostic logs

The in-app log, copied log text, saved run log and exported dashboard diagnostics mask keycard UIDs and Bluetooth MAC addresses. Pairing and enrollment still use the actual identifiers. Review logs for personal information before sharing.

## Development

Installer sounds are prepared in the background when the screen starts. Playback uses prepared sources; unavailable cues are skipped and preparation retries without blocking installation. `--recording-demo` implies `--dry-run`: it hides simulation controls and simulates card taps, but never enables physical device operations. `--dry-run` retains interactive simulation controls. Both modes preserve simulation isolation when starting another installer run.

Linux builds need `libgstreamer1.0-dev` and `libgstreamer-plugins-base1.0-dev`; local audio playback also needs `gstreamer1.0-plugins-good`. Desktop release packaging includes these playback plugins in the AppImage.

```bash
flutter pub get
scripts/update-flasher.sh          # populate assets/tools/ with flasher binaries
flutter run -d linux               # or macos, windows
```

Run `flutter test` and `flutter analyze` locally before publishing changes. CI runs the full test suite for stable release tags (without a prerelease suffix); regular pushes and beta tags build without it. Manual workflow runs can enable `run_tests`. Failed stable-release tests block all platform builds.

Published prereleases refresh the downloads site's separate beta listing without replacing its stable downloads. Stable releases also refresh the main site.

Release builds:

```bash
flutter build linux --release
flutter build macos --release
flutter build windows --release
```

Cross-compile the flasher:

```bash
cd flasher && make build-all
```

## License

This project is dual-licensed. The source code is available under the
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa].
The maintainers reserve the right to grant separate licenses for commercial distribution; please contact the maintainers to discuss commercial licensing.

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png

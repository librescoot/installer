# LibreScoot Installer

> **Beta software.** Tested on all three platforms against real hardware, but things can still go wrong. Flashing firmware carries inherent risk. Use at your own risk, no warranty expressed or implied.

Cross-platform desktop app for installing [LibreScoot](https://librescoot.org) on unu scooters (MDB + DBC).

## What it does

Step-by-step wizard for converting stock scooterOS to LibreScoot:

1. Download firmware and map tiles from GitHub releases (stable/testing/nightly)
2. Connect to the MDB over USB RNDIS, detect hardware, read serial and firmware version
3. Flash MDB: set U-Boot to mass storage mode, write image with `librescoot-flasher` (bmap support for sparse writes)
4. Flash DBC: autonomous "trampoline" process where the MDB switches to USB host, flashes the DBC, and reboots
5. Post-install: offline map tiles, Bluetooth pairing, keycard setup

Also handles LibreScoot-to-LibreScoot re-flashing (detects installed firmware, offers skip options).

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
| Recovery (NXP) | `15A2` | `0061` | DBC SDP mode (detected, not used) |

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

flasher/                          # Go flash tool (cross-platform)
  main.go                         #   bmap, gzip, sequential, two-phase

cli/                              # Go CLI installer (feat/cli-installer)
  main.go                         #   Headless, for scripted/remote use

assets/
  tools/                          # Platform binaries (flasher, fw_setenv)
  drivers/                        # Windows RNDIS driver
  trampoline.sh.template          # DBC flash script, runs on MDB
  images/                         # Instructional photos
```

## Development

```bash
flutter pub get
flutter run -d linux    # or macos, windows
```

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

[CC BY-NC 4.0](LICENSE)

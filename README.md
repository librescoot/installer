# LibreScoot Installer

Cross-platform desktop installer for flashing LibreScoot firmware to MDB/DBC hardware.

## What It Does

The app provides a guided workflow to:

1. Select a `.wic` or `.wic.gz` firmware image.
2. Detect a connected LibreScoot board over USB.
3. Configure a USB network interface for device communication.
4. Connect over SSH to prepare the device for mass-storage flashing mode.
5. Detect the mass-storage device and flash firmware safely.

Target device identifiers:

- Ethernet mode: `VID 0525`, `PID A4A2`
- Mass-storage mode: `VID 0525`, `PID A4A5`
- Recovery mode (detected only): `VID 15A2`, `PID 0061`

## Safety Model

Flashing is gated by validation checks before any write occurs:

- Blocks known system disks (platform-specific checks).
- Requires LibreScoot vendor/product IDs for flashing.
- Validates expected device size range (`1 GB` to `16 GB`).
- Shows a final destructive-action confirmation dialog.

## Prerequisites

- Flutter SDK compatible with Dart `^3.9.0`.
- Desktop host: Windows, macOS, or Linux.
- Administrative/root privileges (the app attempts to self-elevate on launch).
- Firmware image file (`.wic` or `.wic.gz`).
- `assets/passwords.yml` present at runtime (versioned SSH passwords, base64-encoded).

### Windows Notes

- The RNDIS driver may be required for USB ethernet mode.
- Driver files are in `assets/drivers/` (`librescoot_rndis.inf`, `README.txt`).
- `assets/tools/dd.exe` is used for flashing on Windows.

## Network Configuration

The installer configures the host USB interface as:

- Host IP: `192.168.7.50`
- Subnet: `255.255.255.0`
- Device IP (MDB): `192.168.7.1`

## Project Structure

```text
lib/
  main.dart                    # App entry point + elevation bootstrap
  screens/home_screen.dart     # Installer wizard UI and flow control
  services/
    elevation_service.dart     # Cross-platform privilege elevation
    usb_detector.dart          # USB VID/PID detection and metadata
    network_service.dart       # USB network interface discovery/config
    ssh_service.dart           # SSH connection + boot mode prep
    flash_service.dart         # Safe firmware write per platform

assets/
  drivers/                     # Windows RNDIS driver assets
  tools/                       # Flashing helper tools (e.g., dd.exe)
```

## Development

Install dependencies:

```bash
flutter pub get
```

Run locally:

```bash
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

Build:

```bash
flutter build macos
flutter build windows
flutter build linux
```

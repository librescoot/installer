LibreScoot RNDIS Driver for Windows
====================================

This driver enables Windows to recognize the LibreScoot MDB when
connected via USB in ethernet mode.

AUTOMATIC INSTALLATION (requires admin):
  1. Open Command Prompt as Administrator
  2. Run: pnputil /add-driver librescoot_rndis.inf /install

MANUAL INSTALLATION:
  1. Connect the LibreScoot MDB via USB
  2. Open Device Manager
  3. Find the unknown device (yellow warning icon)
  4. Right-click -> Update driver
  5. Browse my computer for drivers
  6. Select this folder
  7. Click Next and allow installation

TROUBLESHOOTING:
  - If Windows 11 doesn't show the device, try:
    Device Manager -> Action -> Add legacy hardware
  - If driver installation fails, try disabling
    Secure Boot temporarily in BIOS

Device IDs:
  VID: 0525 (Linux Foundation)
  PID: A4A2 (RNDIS Ethernet Gadget)

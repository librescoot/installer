RNDIS Driver for Windows
========================

This signed driver enables Windows to recognize USB RNDIS ethernet
gadgets including the LibreScoot MDB.

AUTOMATIC INSTALLATION (requires admin):
  1. Open Command Prompt as Administrator
  2. Run: pnputil /add-driver RNDIS.inf /install

MANUAL INSTALLATION:
  1. Connect the device via USB
  2. Open Device Manager
  3. Find the unknown device (yellow warning icon)
  4. Right-click -> Update driver
  5. Browse my computer for drivers
  6. Select this folder
  7. Click Next

Device IDs:
  VID: 0525 (Linux Foundation)
  PID: A4A2 (RNDIS Ethernet Gadget)

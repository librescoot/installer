// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LibreScoot Installer';

  @override
  String get elevationWarning =>
      'Running without administrator privileges. Some operations may fail.';

  @override
  String get phaseWelcomeTitle => 'Welcome';

  @override
  String get phaseWelcomeDescription => 'Prerequisites and firmware selection';

  @override
  String get phasePhysicalPrepTitle => 'Physical Prep';

  @override
  String get phasePhysicalPrepDescription => 'Open footwell, connect USB';

  @override
  String get phaseMdbConnectTitle => 'MDB Connect';

  @override
  String get phaseMdbConnectDescription => 'Detect device and establish SSH';

  @override
  String get phaseHealthCheckTitle => 'Health Check';

  @override
  String get phaseHealthCheckDescription => 'Verify scooter readiness';

  @override
  String get phaseBatteryRemovalTitle => 'Battery Removal';

  @override
  String get phaseBatteryRemovalDescription =>
      'Open seatbox, remove main battery';

  @override
  String get phaseMdbToUmsTitle => 'MDB → UMS';

  @override
  String get phaseMdbToUmsDescription => 'Configure bootloader for flashing';

  @override
  String get phaseMdbFlashTitle => 'MDB Flash';

  @override
  String get phaseMdbFlashDescription => 'Write firmware to MDB';

  @override
  String get phaseScooterPrepTitle => 'Scooter Prep';

  @override
  String get phaseScooterPrepDescription => 'Disconnect CBB and AUX';

  @override
  String get phaseMdbBootTitle => 'MDB Boot';

  @override
  String get phaseMdbBootDescription => 'Reconnect AUX, wait for boot';

  @override
  String get phaseCbbReconnectTitle => 'CBB Reconnect';

  @override
  String get phaseCbbReconnectDescription => 'Reconnect CBB for DBC flash';

  @override
  String get phaseDbcPrepTitle => 'DBC Prep';

  @override
  String get phaseDbcPrepDescription => 'Upload DBC image and tiles';

  @override
  String get phaseDbcFlashTitle => 'DBC Flash';

  @override
  String get phaseDbcFlashDescription => 'Autonomous DBC installation';

  @override
  String get phaseReconnectTitle => 'Reconnect';

  @override
  String get phaseReconnectDescription => 'Verify DBC installation';

  @override
  String get phaseFinishTitle => 'Finish';

  @override
  String get phaseFinishDescription => 'Reassemble and welcome';

  @override
  String get welcomeHeading => 'Welcome to LibreScoot Installer';

  @override
  String get welcomeSubheading =>
      'This wizard will guide you through installing LibreScoot firmware on your scooter.';

  @override
  String get whatYouNeed => 'What you need:';

  @override
  String get prerequisiteScrewdriverPH2 =>
      'PH2 or H4 screwdriver for footwell screws';

  @override
  String get prerequisiteScrewdriverFlat =>
      'Flat head or PH1 screwdriver for USB cable';

  @override
  String get prerequisiteUsbCable => 'USB cable (laptop to Mini-B)';

  @override
  String get prerequisiteTime => 'About 45 minutes';

  @override
  String get firmwareChannel => 'Firmware Channel';

  @override
  String get channelStable => 'Stable';

  @override
  String get channelTesting => 'Testing';

  @override
  String get channelNightly => 'Nightly';

  @override
  String get channelStableDesc => 'Tested and reliable';

  @override
  String get channelTestingDesc => 'Latest features, may have rough edges';

  @override
  String get channelNightlyDesc => 'Built daily from main, for developers';

  @override
  String channelLatest(String date) {
    return 'Latest: $date';
  }

  @override
  String get channelNoReleases => 'No releases available';

  @override
  String get loadingChannels => 'Loading available channels...';

  @override
  String get region => 'Region';

  @override
  String get selectRegion => 'Select your region';

  @override
  String get startInstallation => 'Start Installation';

  @override
  String get selectRegionError => 'Please select a region for offline maps';

  @override
  String get resolvingReleases => 'Resolving releases...';

  @override
  String get physicalPrepHeading => 'Physical Preparation';

  @override
  String get physicalPrepSubheading =>
      'Prepare your scooter for USB connection.';

  @override
  String get removeFootwellCover => 'Remove footwell cover';

  @override
  String get removeFootwellCoverDesc =>
      'Four screws to remove — PH2 Phillips from factory, H4 hex or Torx if serviced by a good shop.';

  @override
  String get removeFootwellCoverImage =>
      '[Photo: footwell cover with screw locations highlighted]';

  @override
  String get unscrewUsbCable => 'Unscrew USB cable from MDB';

  @override
  String get unscrewUsbCableDesc =>
      'Disconnect the internal DBC USB cable from the MDB board. Use a flat head or PH1 screwdriver.';

  @override
  String get unscrewUsbCableImage =>
      '[Photo: USB Mini-B connector on MDB, close-up]';

  @override
  String get connectLaptopUsb => 'Connect laptop USB cable';

  @override
  String get connectLaptopUsbDesc =>
      'Plug your USB cable into the MDB port and connect the other end to your laptop.';

  @override
  String get doneDetectDevice => 'Done — Detect Device';

  @override
  String get connectingToMdb => 'Connecting to MDB';

  @override
  String get waitingForUsbDevice => 'Waiting for USB device...';

  @override
  String get waitingForRndis =>
      'Waiting for USB device... Make sure your laptop is connected to the MDB via USB.';

  @override
  String get checkingRndisDriver => 'Checking RNDIS driver...';

  @override
  String get installingRndisDriver => 'Installing RNDIS driver...';

  @override
  String get configuringNetwork => 'Configuring network...';

  @override
  String get connectingSsh => 'Connecting via SSH...';

  @override
  String get connected => 'Connected!';

  @override
  String sshConnectionFailed(String error) {
    return 'SSH connection failed: $error. Check cable and retry.';
  }

  @override
  String get healthCheckHeading => 'Health Check';

  @override
  String get verifyingReadiness => 'Verifying scooter readiness...';

  @override
  String get continueButton => 'Continue';

  @override
  String get retryButton => 'Retry';

  @override
  String get proceedAtOwnRisk => 'Proceed at my own risk';

  @override
  String get auxBatteryCharge => 'AUX battery charge';

  @override
  String get cbbStateOfHealth => 'CBB state of health';

  @override
  String get cbbCharge => 'CBB charge';

  @override
  String get mainBattery => 'Main battery';

  @override
  String get present => 'present';

  @override
  String get notPresent => 'not present';

  @override
  String get batteryRemovalHeading => 'Battery Removal';

  @override
  String get seatboxOpening => 'Seatbox is opening...';

  @override
  String get seatboxOpeningDesc => 'The seatbox will open automatically.';

  @override
  String get removeMainBattery => 'Remove the main battery';

  @override
  String get removeMainBatteryDesc =>
      'Lift the main battery (Fahrakku) out of the seatbox.';

  @override
  String get openSeatbox => 'Open Seatbox';

  @override
  String get mainBatteryAlreadyRemoved => 'Main battery already removed';

  @override
  String get openingSeatbox => 'Opening seatbox...';

  @override
  String get waitingForBatteryRemoval => 'Waiting for battery removal...';

  @override
  String get batteryRemoved => 'Battery removed!';

  @override
  String get configuringMdbBootloader => 'Configuring MDB Bootloader';

  @override
  String get preparing => 'Preparing...';

  @override
  String get uploadingBootloaderTools => 'Uploading bootloader tools...';

  @override
  String get rebootingMdbUms => 'Rebooting MDB into mass storage mode...';

  @override
  String get waitingForUmsDevice => 'Waiting for UMS device...';

  @override
  String get readyToFlash => 'Ready to begin flashing';

  @override
  String get readyToFlashHint =>
      'The device is in flashing mode. You can create manual backups via SSH before proceeding.';

  @override
  String get beginFlashing => 'Begin flashing';

  @override
  String get flashingMdb => 'Flashing MDB';

  @override
  String get flashingMdbSubheading =>
      'Two-phase write: partitions first, boot sector last.';

  @override
  String get waitingForMdbFirmware => 'Waiting for MDB firmware download...';

  @override
  String get noDevicePath => 'Error: no device path available';

  @override
  String get mdbFlashComplete => 'MDB flash complete!';

  @override
  String get scooterPrepHeading => 'Scooter Preparation';

  @override
  String get scooterPrepSubheading =>
      'MDB firmware has been written. Now prepare for reboot.';

  @override
  String get disconnectCbb => 'Disconnect the CBB';

  @override
  String get disconnectCbbDesc =>
      'The main battery must already be removed before disconnecting CBB. Failure to follow this order risks electrical damage.';

  @override
  String get disconnectAuxPole => 'Disconnect one AUX pole';

  @override
  String get disconnectAuxPoleDesc =>
      'Remove ONLY the positive pole (outermost, color-coded red) to avoid risk of inverting polarity. This will remove power from the MDB — the USB connection will disappear.';

  @override
  String get disconnectAuxPoleImage =>
      '[Photo: AUX battery poles, positive (red/outermost) highlighted]';

  @override
  String get auxDisconnectWarning =>
      'The USB connection will be lost when you disconnect AUX. This is expected — the installer will wait for the MDB to reboot.';

  @override
  String get doneCbbAuxDisconnected => 'Done — I disconnected CBB and AUX';

  @override
  String get waitingForMdbBoot => 'Waiting for MDB Boot';

  @override
  String get reconnectAuxPole => 'Reconnect the AUX pole';

  @override
  String get reconnectAuxPoleDesc =>
      'Reconnect the positive AUX pole. The MDB will power on and boot into LibreScoot.';

  @override
  String get dbcLedHint =>
      'DBC LED: orange = starting, green = booting, off = running';

  @override
  String get mdbStillUms =>
      'MDB still in UMS mode — flash may not have taken. Retrying...';

  @override
  String get mdbDetectedNetwork =>
      'MDB detected in network mode. Waiting for stable connection...';

  @override
  String pingStable(int count) {
    return 'Ping stable: $count/10';
  }

  @override
  String get waitingStableConnection => 'Waiting for stable connection...';

  @override
  String get reconnectingSsh => 'Reconnecting SSH...';

  @override
  String sshReconnectionFailed(String error) {
    return 'SSH reconnection failed: $error';
  }

  @override
  String get reconnectCbbHeading => 'Reconnect CBB';

  @override
  String get reconnectCbb => 'Reconnect the CBB';

  @override
  String get reconnectCbbDesc =>
      'Plug the CBB cable back in. This provides more power for the DBC flash.';

  @override
  String get verifyCbbConnection => 'Verify CBB Connection';

  @override
  String get checkingCbb => 'Checking CBB...';

  @override
  String get cbbConnected => 'CBB connected!';

  @override
  String waitingForCbb(int attempts) {
    return 'Waiting for CBB... ($attempts)';
  }

  @override
  String get cbbNotDetected => 'CBB not detected. Please check the connection.';

  @override
  String get preparingDbcFlash => 'Preparing DBC Flash';

  @override
  String get waitingForDownloads => 'Waiting for downloads to complete...';

  @override
  String get startingTrampoline => 'Starting trampoline script...';

  @override
  String uploadError(String error) {
    return 'Upload error: $error';
  }

  @override
  String get dbcFlashInProgress => 'DBC Flash in Progress';

  @override
  String get disconnectUsbFromLaptop => 'Disconnect USB from laptop';

  @override
  String get disconnectUsbFromLaptopDesc =>
      'Unplug the USB cable from your laptop.';

  @override
  String get reconnectDbcUsbToMdb => 'Reconnect DBC USB cable to MDB';

  @override
  String get reconnectDbcUsbToMdbDesc =>
      'Screw the internal DBC USB cable back into the MDB port.';

  @override
  String get mdbFlashingDbcAutonomously =>
      'The MDB is now flashing the DBC autonomously.';

  @override
  String get watchLightsForProgress => 'Watch the scooter lights for progress:';

  @override
  String get ledFrontRingPulse => 'Front ring pulsing';

  @override
  String get ledFrontRingPulseMeaning => 'Waiting for connection';

  @override
  String get ledFrontRingSolid => 'Front ring solid';

  @override
  String get ledFrontRingSolidMeaning => 'DBC connected, working';

  @override
  String get disconnectCbbImage => '[Photo: CBB connector location under seat]';

  @override
  String get ledBlinkerProgress => 'Blinkers light up clockwise';

  @override
  String get ledBlinkerProgressMeaning => 'Flash progress (25% per blinker)';

  @override
  String get ledBootGreen => 'Boot LED green';

  @override
  String get ledBootGreenMeaning => 'Success — reconnect laptop';

  @override
  String get ledHazardFlashers => 'Hazard flashers';

  @override
  String get ledHazardFlashersMeaning => 'Error — reconnect laptop to see log';

  @override
  String get bootLedGreenReconnect => 'Boot LED is green — Reconnect Laptop';

  @override
  String get hazardFlashersCheckError => 'Hazard flashers — Check Error';

  @override
  String get verifyingDbcInstallation => 'Verifying DBC Installation';

  @override
  String get reconnectUsbToLaptop => 'Reconnect USB to laptop...';

  @override
  String get waitingForRndisDevice => 'Waiting for RNDIS device...';

  @override
  String get readingTrampolineStatus => 'Reading trampoline status...';

  @override
  String get dbcFlashSuccessful => 'DBC flash successful!';

  @override
  String dbcFlashFailed(String message) {
    return 'DBC flash failed: $message';
  }

  @override
  String get dbcFlashError => 'DBC Flash Error';

  @override
  String get closeButton => 'Close';

  @override
  String get trampolineStatusUnknown =>
      'Trampoline status unknown. Check /data/trampoline.log on MDB.';

  @override
  String get welcomeToLibreScoot => 'Welcome to LibreScoot!';

  @override
  String get finalSteps => 'Final steps:';

  @override
  String get disconnectUsbFromLaptopFinal => 'Disconnect USB from laptop';

  @override
  String get disconnectUsbFromLaptopFinalDesc =>
      'Unplug the USB cable from your laptop.';

  @override
  String get reconnectDbcUsbCable => 'Reconnect DBC USB cable';

  @override
  String get reconnectDbcUsbCableDesc =>
      'Screw the internal DBC USB cable back into MDB.';

  @override
  String get insertMainBattery => 'Insert main battery';

  @override
  String get insertMainBatteryDesc =>
      'Place the main battery back into the seatbox.';

  @override
  String get closeSeatboxAndFootwell => 'Close seatbox and footwell';

  @override
  String get closeSeatboxAndFootwellDesc =>
      'Close the seatbox and replace the footwell cover.';

  @override
  String get unlockScooter => 'Unlock your scooter';

  @override
  String get unlockScooterDesc =>
      'Keycard and Bluetooth pairing will be set up during LibreScoot first run.';

  @override
  String deleteCachedDownloads(String sizeMb) {
    return 'Delete cached downloads ($sizeMb MB)';
  }

  @override
  String deletedCache(String sizeMb) {
    return 'Deleted $sizeMb MB';
  }

  @override
  String get downloads => 'Downloads';

  @override
  String get downloadMdbFirmware => 'MDB Firmware';

  @override
  String get downloadDbcFirmware => 'DBC Firmware';

  @override
  String get downloadMapTiles => 'Map Tiles';

  @override
  String get downloadRoutingTiles => 'Routing Tiles';

  @override
  String get homeAppTitle => 'LibreScoot Installer';

  @override
  String get notElevated => 'Not elevated';

  @override
  String get selectFirmwareStep => 'Select Firmware';

  @override
  String get connectDeviceStep => 'Connect Device';

  @override
  String get configureNetworkStep => 'Configure Network';

  @override
  String get prepareDeviceStep => 'Prepare Device';

  @override
  String get flashFirmwareStep => 'Flash Firmware';

  @override
  String get completeStep => 'Complete';

  @override
  String get selectFirmwareImage => 'Select Firmware Image';

  @override
  String get selectFirmwareHint =>
      'Choose a .sdimg.gz, .sdimg, .wic.gz, .wic, or .img firmware file to flash';

  @override
  String get selectFile => 'Select File';

  @override
  String get changeFile => 'Change File';

  @override
  String get deviceConnected => 'Device Connected';

  @override
  String get connectYourDevice => 'Connect Your Device';

  @override
  String get connectMdbViaUsb =>
      'Connect the MDB via USB and wait for detection';

  @override
  String get backButton => 'Back';

  @override
  String get configuringNetworkHeading => 'Configuring Network';

  @override
  String get settingUpNetwork => 'Setting up network interface...';

  @override
  String get readyToConfigureNetwork =>
      'Ready to configure network for device communication';

  @override
  String get configureNetworkButton => 'Configure Network';

  @override
  String get preparingDevice => 'Preparing Device';

  @override
  String get readyToPrepare => 'Ready to Prepare';

  @override
  String get prepareForFlashing => 'Prepare for Flashing';

  @override
  String get flashingFirmware => 'Flashing Firmware';

  @override
  String get startFlashing => 'Start Flashing';

  @override
  String get installationComplete => 'Installation Complete!';

  @override
  String get installationCompleteDesc =>
      'Your device has been successfully flashed.\nIt will reboot automatically.';

  @override
  String get flashAnotherDevice => 'Flash Another Device';

  @override
  String get flashDryRun => 'Flash Dry Run';

  @override
  String get safetyCheckFailed => 'Safety Check Failed';

  @override
  String get cannotFlashSafety =>
      'Cannot flash this device due to safety concerns:';

  @override
  String get okButton => 'OK';

  @override
  String get confirmFlashOperation => 'Confirm Flash Operation';

  @override
  String get aboutToWriteFirmware => 'You are about to write firmware to:';

  @override
  String get deviceLabel => 'Device';

  @override
  String get pathLabel => 'Path';

  @override
  String get sizeLabel => 'Size';

  @override
  String get firmwareLabel => 'Firmware:';

  @override
  String get warningsLabel => 'Warnings:';

  @override
  String get eraseWarning =>
      'This will ERASE ALL DATA on the device. This action cannot be undone.';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get flashDeviceButton => 'Flash Device';

  @override
  String get installingUsbDriver => 'Installing USB driver...';

  @override
  String get usbDriverInstalled => 'USB driver installed successfully';

  @override
  String driverInstallFailed(String error) {
    return 'Driver install failed: $error';
  }

  @override
  String get autoLoadedFirmware =>
      'Auto-loaded firmware from current directory';

  @override
  String get deviceDisconnected =>
      'Device disconnected. Reconnect/wait for mass storage mode.';

  @override
  String get waitingForMdbNetwork => 'Waiting for MDB network to settle...';

  @override
  String get findingNetworkInterface => 'Finding network interface...';

  @override
  String get couldNotFindInterface => 'Could not find USB network interface';

  @override
  String get networkConfigured => 'Network configured successfully';

  @override
  String get selectFirmwareFileError =>
      'Please select a .sdimg.gz, .sdimg, .wic.gz, .wic, or .img file';

  @override
  String errorOpeningFilePicker(String error) {
    return 'Error opening file picker: $error';
  }

  @override
  String get configuringBootloader =>
      'Configuring bootloader for mass storage mode...';

  @override
  String get rebootingDevice => 'Rebooting device...';

  @override
  String get waitingForMassStorage =>
      'Waiting for device to reboot in mass storage mode...';

  @override
  String get deviceReadyForFlashing => 'Device ready for flashing';

  @override
  String get selectFirmwareDialogTitle => 'Select Firmware Image';

  @override
  String connectedTo(String host, String firmware, String serial) {
    return 'Connected to: $host\nFirmware: $firmware\nSerial: $serial';
  }

  @override
  String connectedToFirmware(String version) {
    return 'Connected to $version';
  }

  @override
  String get unknown => 'Unknown';

  @override
  String modeLabel(String mode) {
    return 'Mode: $mode';
  }

  @override
  String get backingUpConfig => 'Backing up device configuration...';

  @override
  String get configBackedUp => 'Device configuration backed up';

  @override
  String get noConfigFound => 'No device configuration found to back up';

  @override
  String get restoringConfig => 'Restoring device configuration...';

  @override
  String healthCheckFailed(String error) {
    return 'Health check failed: $error';
  }

  @override
  String flashError(String error) {
    return 'Flash error: $error';
  }

  @override
  String get flashComplete => 'Flash complete!';

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get regionHint => 'For offline maps and navigation support';

  @override
  String get skipOfflineMaps => 'Skip offline maps';

  @override
  String get skipOfflineMapsHint =>
      'You can install maps later via the scooter\'s web interface';

  @override
  String get bluetoothPairingHeading => 'Bluetooth Pairing';

  @override
  String get bluetoothPairingHint =>
      'Pair your phone or other Bluetooth devices with the scooter.';

  @override
  String get startPairing => 'Start pairing';

  @override
  String get skipPairing => 'Skip';

  @override
  String get pairingActive => 'Pairing mode active — searching for devices...';

  @override
  String blePinCode(String pin) {
    return 'PIN: $pin';
  }

  @override
  String get blePinHint => 'Enter this PIN on your device to complete pairing.';

  @override
  String get pairingComplete => 'Pairing complete!';

  @override
  String get pairAnotherDevice => 'Pair another device';

  @override
  String get willAskForElevation =>
      'Start Installation (will ask for elevation)';

  @override
  String get installationContinuesInNewWindow =>
      'Installation continues in the new window';

  @override
  String get youCanCloseThisWindow => 'You can close this window.';
}

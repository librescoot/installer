// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Librescoot Installer';

  @override
  String get elevationWarning =>
      'Running without administrator privileges. Some operations may fail.';

  @override
  String get phaseWelcomeTitle => 'Welcome';

  @override
  String get phaseWelcomeDescription => 'Prerequisites and firmware selection';

  @override
  String get phasePhysicalPrepTitle => 'Prepare Scooter';

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
  String get phaseBatteryRemovalTitle => 'Remove Battery';

  @override
  String get phaseBatteryRemovalDescription =>
      'Open seatbox, remove main battery';

  @override
  String get phaseMdbToUmsTitle => 'Prepare for Flashing';

  @override
  String get phaseMdbToUmsDescription => 'Configure bootloader for flashing';

  @override
  String get phaseMdbFlashTitle => 'Flash Image';

  @override
  String get phaseMdbFlashDescription => 'Write firmware to MDB';

  @override
  String get phaseScooterPrepTitle => 'Disconnect Power';

  @override
  String get phaseScooterPrepDescription => 'Disconnect CBB and AUX';

  @override
  String get phaseMdbBootTitle => 'Reboot';

  @override
  String get phaseMdbBootDescription => 'Reconnect AUX, wait for boot';

  @override
  String get phaseCbbReconnectTitle => 'Reconnect CBB & Battery';

  @override
  String get phaseCbbReconnectDescription => 'Reconnect CBB for DBC flash';

  @override
  String get phaseDbcPrepTitle => 'Upload Files';

  @override
  String get phaseDbcPrepDescription => 'Upload DBC image and tiles';

  @override
  String get phaseDbcFlashTitle => 'Flash Image';

  @override
  String get phaseDbcFlashDescription => 'Autonomous DBC installation';

  @override
  String get phaseReconnectTitle => 'Verify';

  @override
  String get phaseReconnectDescription => 'Verify DBC installation';

  @override
  String get phaseBluetoothPairingTitle => 'Bluetooth';

  @override
  String get phaseBluetoothPairingDescription => 'Pair phone or other devices';

  @override
  String get phaseFinishTitle => 'Finish';

  @override
  String get phaseFinishDescription => 'Reassemble and welcome';

  @override
  String get majorStepPrepare => 'Prepare';

  @override
  String get majorStepConnect => 'Connect';

  @override
  String get majorStepMdbFlash => 'Flash MDB';

  @override
  String get majorStepDbcFlash => 'Flash DBC';

  @override
  String get majorStepFinish => 'Finish';

  @override
  String get majorStepSkippedSuffix => 'skipped';

  @override
  String get welcomeHeading => 'Welcome to Librescoot Installer';

  @override
  String get welcomeSubheading =>
      'This wizard will guide you through installing Librescoot firmware on your scooter.';

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
  String get prerequisiteTime => 'About 20 minutes';

  @override
  String get reliabilityWarningTitle => 'Before you start';

  @override
  String get reliabilityWarningBody =>
      'The flash takes several minutes and any USB drop or laptop sleep mid-flash leaves the MDB in an inconsistent state. Please check:\n• A known-good USB cable, plugged in firmly at both ends — flaky cables are the #1 cause of failed installs\n• Laptop on power, or fully charged — battery saver / sleep can break the flash\n• Use a direct USB port, not a USB hub if possible\n• Don\'t unplug or move things around once the flash starts';

  @override
  String get noPowerCycleWarningTitle =>
      'DO NOT power-cycle anything during the install';

  @override
  String get noPowerCycleWarningBody =>
      'If something looks stuck, gives no feedback, or behaves weirdly: PAUSE and ask in Discord first. Do NOT pull the AUX battery, do NOT disconnect the CBB, do NOT yank USB, do NOT reboot the scooter or your laptop. The installer can recover from almost any state — but only if you don\'t intervene. Power-cycling mid-flash is what bricks scooters.';

  @override
  String get elevationRequiredTitle => 'Administrator privileges required';

  @override
  String get elevationRequiredBody =>
      'Librescoot Installer needs administrator privileges to write to the scooter\'s storage and configure the network interface. The elevation prompt was declined or failed.\n\nClose this window and re-launch the installer, then approve the elevation prompt.';

  @override
  String get quitButton => 'Quit';

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
  String get waitingForUnlock => 'Unlock the scooter to continue...';

  @override
  String get unlockTimeout =>
      'Timed out waiting for scooter to be unlocked. Unlock and retry.';

  @override
  String get awaitingUnlockHeading => 'Unlock your scooter';

  @override
  String get awaitingUnlockDetail =>
      'Please unlock your scooter to continue. Use your keycard or paired phone.';

  @override
  String get awaitingParkHeading => 'Park your scooter';

  @override
  String get awaitingParkDetail =>
      'Please park your scooter (flip the kickstand down) to continue.';

  @override
  String get awaitingParkContinueAnyway => 'Continue anyway';

  @override
  String get lockingScooter => 'Locking scooter for flashing...';

  @override
  String get connected => 'Connected!';

  @override
  String sshConnectionFailed(String error) {
    return 'SSH connection failed: $error. Check cable and retry.';
  }

  @override
  String get manualPasswordTitle => 'Root password required';

  @override
  String get manualPasswordPrompt =>
      'Could not determine the root password automatically. Enter the root password for this device.';

  @override
  String manualPasswordPromptVersion(String version) {
    return 'Could not determine the root password automatically for firmware $version. Enter the root password for this device.';
  }

  @override
  String manualPasswordPromptRetry(int remaining) {
    return 'That password didn\'t work. Try again ($remaining attempts left).';
  }

  @override
  String get manualPasswordFieldLabel => 'Password';

  @override
  String get manualPasswordSubmit => 'Connect';

  @override
  String get untestedFirmwareHeading => 'Untested firmware version';

  @override
  String untestedFirmwareBody(String version) {
    return 'Installation has not been tested on firmware versions older than 1.12.0 (yours: $version). The installer should still work, but please share any issues on the Librescoot Discord.';
  }

  @override
  String get openLibrescootDiscord => 'Open Librescoot Discord';

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
  String get riskAuxLow =>
      'Low 12V battery could cause the MDB or DBC to shut down during flashing. The LED indicators may also fail. Close the seatbox with the main battery inserted and wait for it to charge.';

  @override
  String get riskCbbSoh =>
      'Degraded CBB health may cause unreliable power delivery during flashing.';

  @override
  String get riskCbbCharge =>
      'Low CBB charge increases the risk of power loss during the DBC flash. Close the seatbox with the main battery inserted and wait for the CBB to charge.';

  @override
  String get riskNoBattery =>
      'Without the main battery, the 12V auxiliary battery will drain faster. The scooter may shut down during extended operations.';

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
      'The device is in flashing mode. You can mount the device to create manual backups before proceeding.';

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
      'Reconnect the positive AUX pole. The MDB will power on and boot into Librescoot.';

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
  String get stableConnectionStallHint =>
      'Connection still unstable — USB ethernet may have lost its IP. On Linux, your NetworkManager may be fighting for the interface (try disabling IPv6). See log for details.';

  @override
  String get reconnectingSsh => 'Reconnecting SSH...';

  @override
  String sshReconnectionFailed(String error) {
    return 'SSH reconnection failed: $error';
  }

  @override
  String get reconnectCbbHeading => 'Reconnect CBB & Battery';

  @override
  String get reconnectCbb => 'Reinstall the main battery and reconnect the CBB';

  @override
  String get reconnectCbbDesc =>
      'Put the main battery back in the seatbox and plug the CBB cable back in. The scooter needs full power for the DBC flash.';

  @override
  String get verifyCbbConnection => 'Verify CBB Connection';

  @override
  String get verifyBatteryPresence => 'Verify battery';

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
  String get cbbDetectionMayTakeMinutes =>
      'This can take several minutes, please be patient.';

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
  String get ledFrontRingPulse => 'Front ring breathing';

  @override
  String get ledFrontRingPulseMeaning =>
      'Preparing DBC (configuring bootloader, waiting for connection)';

  @override
  String get ledFrontRingSolid => 'Front ring glows briefly';

  @override
  String get ledFrontRingSolidMeaning => 'Flash complete — success!';

  @override
  String get disconnectCbbImage => '[Photo: CBB connector location under seat]';

  @override
  String get ledBlinkerProgress => 'Blinkers glow progressively';

  @override
  String get ledBlinkerProgressMeaning =>
      'Flash progress — dim = done, breathing = active segment';

  @override
  String get ledBootGreen => 'Boot LED blinking green';

  @override
  String get ledBootGreenMeaning => 'Success — reconnect laptop';

  @override
  String get ledRearLightSolid => 'All four blinkers (hazards) flashing';

  @override
  String get ledRearLightSolidMeaning =>
      'Error — reconnect laptop to see log; the indicators stop once you reconnect';

  @override
  String get bootLedGreenReconnect =>
      'Boot LED is blinking green — Reconnect Laptop';

  @override
  String get rearLightCheckError => 'Hazards flashing — Check Error';

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
  String get welcomeToLibrescoot => 'Welcome to Librescoot!';

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
      'Use one of the keycards you registered, or unlock via Bluetooth.';

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
  String get downloadsFinished => 'Downloads finished';

  @override
  String get downloadsFinishedHint => 'You can continue offline.';

  @override
  String get downloadMdbFirmware => 'MDB Firmware';

  @override
  String get downloadDbcFirmware => 'DBC Firmware';

  @override
  String get downloadMapTiles => 'Map Tiles';

  @override
  String get downloadRoutingTiles => 'Routing Tiles';

  @override
  String get homeAppTitle => 'Librescoot Installer';

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
      'You can install maps later by re-running the installer';

  @override
  String get bluetoothPairingHeading => 'Bluetooth Pairing';

  @override
  String get bluetoothPairingHint =>
      'Pair your phone or other Bluetooth devices with the scooter.';

  @override
  String get startPairing => 'Unlock and start pairing';

  @override
  String get skipPairing => 'Skip';

  @override
  String get pairingActive => 'Scooter unlocked';

  @override
  String get pairingActiveHint =>
      'Search for the scooter in your phone\'s Bluetooth settings and pair it. Press Done when finished.';

  @override
  String get pairingDone => 'Done';

  @override
  String get blePinHint => 'Enter this PIN on your device to complete pairing.';

  @override
  String get bleAlreadyConnected => 'A device is already connected';

  @override
  String get bleAlreadyConnectedHint =>
      'You can pair additional devices or press Done to continue.';

  @override
  String get keycardLearningHeading => 'Keycard Setup';

  @override
  String get keycardLearningBody =>
      'Register the NFC cards you want to use to unlock and lock the scooter. Click Start, hold each card to the reader one by one, then click Done.';

  @override
  String get keycardLearnedAck =>
      'Keycards registered. Click Continue to finish, or Add more cards to register additional ones.';

  @override
  String get keycardStartLearning => 'Start';

  @override
  String get keycardAddMore => 'Add more cards';

  @override
  String get keycardLearningActive => 'Learning mode active';

  @override
  String get keycardLearningActiveHint =>
      'Hold each card to the reader. Click Done when finished.';

  @override
  String get keycardStopLearning => 'Done';

  @override
  String keycardStartLearningFailed(String error) {
    return 'Could not start keycard learning: $error';
  }

  @override
  String get willAskForElevation =>
      'Start Installation (will ask for elevation)';

  @override
  String get installationContinuesInNewWindow =>
      'Installation continues in the new window';

  @override
  String get youCanCloseThisWindow => 'You can close this window.';

  @override
  String get cannotQuitWhileFlashing =>
      'Cannot quit while flashing is in progress';

  @override
  String get showLogTooltip => 'Show log';

  @override
  String get retryMdbConnect => 'Retry';

  @override
  String get retryMdbToUms => 'Retry';

  @override
  String get showLog => 'Show Log';

  @override
  String get retryMdbFlash => 'Retry';

  @override
  String get retryMdbBoot => 'Retry';

  @override
  String get retryDbcPrep => 'Retry';

  @override
  String get retryVerification => 'Retry verification';

  @override
  String get retryDbcFlash => 'Retry DBC flash';

  @override
  String get skipToFinish => 'Skip to finish';

  @override
  String get skipKeycardSetup => 'Skip';

  @override
  String get finished => 'Finished';

  @override
  String get keepCachedDownloads => 'Keep cached downloads';

  @override
  String get librescootFirmwareDetected => 'Librescoot firmware detected';

  @override
  String get skipMdbReflash => 'Skip MDB reflash';

  @override
  String get keepCurrentMdbFirmware => 'Keep current MDB firmware';

  @override
  String get skipDbcFlashOption => 'Skip DBC flash';

  @override
  String get onlyFlashMdbSkipDbc => 'Only flash MDB, skip DBC entirely';

  @override
  String firmwareVersionDisplay(String version) {
    return 'Firmware: $version';
  }

  @override
  String get openSeatboxButton => 'Open seatbox';

  @override
  String get reconnectCbbStep => 'Reconnect the CBB';

  @override
  String get reconnectCbbStepDesc =>
      'Plug the CBB cable back into the connector under the seat. Without the CBB, the MDB could shut down during flashing.';

  @override
  String get insertMainBatteryStep => 'Insert the main battery';

  @override
  String get insertMainBatteryStepDesc =>
      'Put the main battery back in the seatbox. Without it, the CBB or 12V auxiliary battery could run empty during flashing, which may cause the MDB or DBC to shut down.';

  @override
  String get cbbDetected => 'CBB detected';

  @override
  String get batteryDetected => 'Battery detected';

  @override
  String get proceedWithoutCbb => 'I understand the risks, proceed anyway';

  @override
  String get checkingCbbAndBattery => 'Checking CBB and battery...';

  @override
  String get waitingForUsbDisconnect => 'Waiting for USB disconnect...';

  @override
  String get dbcWillCyclePower =>
      'The DBC will turn on and off multiple times during this process. Do not disconnect the USB cable between MDB and DBC.';

  @override
  String get ledBootAmber => 'Boot LED amber';

  @override
  String get ledBootAmberMeaning => 'Flashing in progress';

  @override
  String get ledBootRedError => 'Boot LED blinking red';

  @override
  String get ledBootRedMeaning =>
      'Error — reconnect laptop to check log; the indicators stop once you reconnect';

  @override
  String get flashingTakesAbout10Min =>
      'Flashing takes about 10 minutes. Reconnect the laptop USB cable when done.';

  @override
  String get waitingForMdbToReconnect => 'Waiting for MDB to reconnect...';

  @override
  String get ledIsGreen => 'LED is green';

  @override
  String get ledIsRed => 'LED is red';

  @override
  String get ledAmberWaitNotice =>
      'Most important: do NOT disconnect USB or power while this is running. While the boot LED is amber/orange, flashing is still in progress — hands off, don\'t click anything. The LED will start blinking once it\'s done: green = success, red = error. Only continue once it\'s blinking.';

  @override
  String get phaseKeycardSetupTitle => 'Keycard Setup';

  @override
  String get phaseKeycardSetupDescription => 'Register your keycards';

  @override
  String get usingLocalFirmwareImages => 'Using local firmware images';

  @override
  String get mdbDetectedUmsSkipping =>
      'MDB detected in UMS mode — skipping to flash.';

  @override
  String get waitingForMdbToReboot => 'Waiting for MDB to reboot...';

  @override
  String get mdbDetectedWaitingForSsh => 'MDB detected, waiting for SSH...';

  @override
  String get reconnectedToMdb => 'Reconnected to MDB';

  @override
  String get verifyingBootloaderConfig => 'Verifying bootloader config...';

  @override
  String get umsNotDetectedTimeout =>
      'UMS device not detected within 60s. MDB may have booted back into Linux.';

  @override
  String get waitingForDevicePath => 'Waiting for device path...';

  @override
  String get noDevicePathFound =>
      'No device path found. Check USB connection and retry.';

  @override
  String get mdbDisconnectedFlashingDbc =>
      'MDB disconnected — flashing DBC autonomously...';

  @override
  String get mdbReconnectedVerifying => 'MDB reconnected! Verifying...';

  @override
  String get logDebugShell => 'Log & Debug Shell';

  @override
  String get copyToClipboard => 'Copy to clipboard';

  @override
  String get debugCommandHint => 'Run a command in the installer context...';

  @override
  String mbOnDisk(String size) {
    return '$size MB on disk';
  }

  @override
  String get beforeImageLabel => 'Before';

  @override
  String get afterImageLabel => 'After';

  @override
  String get language => 'Language';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get gettingStartedTitle => 'Getting started';

  @override
  String get gettingStartedOpenMenuTitle => 'Open the menu';

  @override
  String get gettingStartedOpenMenuDesc =>
      'While parked, give two short pulls in a row on the left brake lever. Use the brake levers to scroll and select; the on-screen hints show what each lever does.';

  @override
  String get gettingStartedDriveMenuTitle => 'Quick menu while riding';

  @override
  String get gettingStartedDriveMenuDesc =>
      'Hold the seatbox button to open the on-screen quick menu and cycle through options. Release to highlight the next option, then press once briefly to confirm.';

  @override
  String get gettingStartedUpdateModeTitle => 'Open Update Mode again later';

  @override
  String get gettingStartedUpdateModeDesc =>
      'To install map or routing updates, change settings, or copy other files: turn the scooter on, open the menu, go to Settings → System → Update Mode…, then connect a computer via USB.';

  @override
  String get gettingStartedNavigationTitle => 'Navigate to a destination';

  @override
  String get gettingStartedNavigationDesc =>
      'Open the menu → Navigation → Enter Address…, Recent Destinations or Saved Locations. Use Save Current Location to keep the spot you\'re at for later, and Save to Favorites on a recent entry to keep it long-term.';

  @override
  String get gettingStartedFooter =>
      'More on librescoot.org and in the handbook.';

  @override
  String get gettingStartedLinkWebsite => 'librescoot.org';

  @override
  String get gettingStartedLinkHandbook => 'Handbook';
}

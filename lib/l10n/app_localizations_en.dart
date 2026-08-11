// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get phaseWelcomeTitle => 'Welcome';

  @override
  String get phaseWelcomeDescription => 'Prerequisites and firmware selection';

  @override
  String get phaseNoticesTitle => 'Notices';

  @override
  String get phaseNoticesDescription => 'Important warnings before you start';

  @override
  String get phasePhysicalPrepTitle => 'Prepare Scooter';

  @override
  String get phasePhysicalPrepDescription => 'Open footwell, connect USB';

  @override
  String get phaseMdbConnectTitle => 'MDB Connect';

  @override
  String get phaseMdbConnectDescription => 'Detect device and establish SSH';

  @override
  String get phaseResumeDetectedTitle => 'Resume';

  @override
  String get phaseResumeDetectedDescription => 'Interrupted installation found';

  @override
  String get phaseHealthCheckTitle => 'Health Check';

  @override
  String get phaseHealthCheckDescription => 'Verify scooter readiness';

  @override
  String get phaseBatteryRemovalTitle => 'Switch Off Battery';

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
  String get phaseDashboardPrepTitle => 'Dashboard Prep';

  @override
  String get phaseDashboardPrepDescription =>
      'Pair, enroll keycards, stage DBC image';

  @override
  String get phaseDbcSwapAndFlashTitle => 'Flash Image';

  @override
  String get phaseDbcSwapAndFlashDescription =>
      'Swap cable; scooter flashes the DBC';

  @override
  String get phaseReconnectTitle => 'Verify';

  @override
  String get phaseReconnectDescription =>
      'Verify after an interrupted DBC flash';

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
  String get majorStepMdbPrep => 'Dashboard Prep';

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
      'The flash takes several minutes and any USB drop or laptop sleep mid-flash leaves the MDB in an inconsistent state. Please check:\n• A known-good USB cable, plugged in firmly at both ends. Flaky cables are the #1 cause of failed installs\n• Laptop on power, or fully charged. Battery saver / sleep can break the flash\n• Use a direct USB port, not a USB hub if possible\n• Don\'t unplug or move things around once the flash starts';

  @override
  String get noPowerCycleWarningTitle =>
      'DO NOT power-cycle anything during the install';

  @override
  String get noPowerCycleWarningBody =>
      'If something looks stuck, gives no feedback, or behaves weirdly: PAUSE and ask in Discord first. Do NOT pull the AUX battery, do NOT disconnect the CBB, do NOT yank USB, do NOT reboot the scooter or your laptop. The installer can recover from almost any state. But only if you don\'t intervene. Power-cycling mid-flash is what bricks scooters.';

  @override
  String get noticesHeading => 'Read this before continuing';

  @override
  String get noticesSubheading =>
      'Two things that will save your install if you take them seriously.';

  @override
  String get noticesAcknowledgeButton => 'I\'ve read this, continue';

  @override
  String get noticesWaitingForDownloads => 'Downloading firmware...';

  @override
  String get noticesContinueOfflineAnyway =>
      'Continue anyway (I\'ll have internet at the scooter)';

  @override
  String get backButton => 'Back';

  @override
  String get elevationRequiredTitle => 'Administrator privileges required';

  @override
  String get elevationRequiredBody =>
      'Librescoot Installer needs administrator privileges to write to the scooter\'s storage and configure the network interface. The elevation prompt was declined or could not be shown.\n\nClick Continue to dismiss this dialog and try again. If you keep declining the prompt, the installer cannot proceed.';

  @override
  String get elevationNoticeWelcome =>
      'When you click Start Installation, your system will ask you to allow administrator access. The installer needs it to write to the scooter\'s storage and configure networking.';

  @override
  String get requestingAdminPrivileges =>
      'Requesting administrator privileges...';

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
      'Four screws to remove. PH2 Phillips from factory, H4 hex or Torx if serviced by a good shop.';

  @override
  String get unscrewUsbCable => 'Unscrew USB cable from MDB';

  @override
  String get unscrewUsbCableDesc =>
      'Disconnect the internal DBC USB cable from the MDB board. Use a flat head or PH1 screwdriver.';

  @override
  String get connectLaptopUsb => 'Connect laptop USB cable';

  @override
  String get connectLaptopUsbDesc =>
      'Plug your USB cable into the MDB port and connect the other end to your laptop.';

  @override
  String get doneDetectDevice => 'Done. Detect Device';

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
  String get configuringNetwork => 'Configuring network...';

  @override
  String get connectingSsh => 'Connecting via SSH...';

  @override
  String get waitingForUnlock => 'Unlock the scooter to continue...';

  @override
  String get unfinishedInstallDetected =>
      'Unfinished installation detected, continuing without unlock...';

  @override
  String get waitingForBatteryData => 'Waiting for AUX/CBB battery data...';

  @override
  String get resumeFoundHeading => 'Interrupted installation found';

  @override
  String get resumeFoundBody =>
      'A previous installation on this scooter did not finish. The unlock step has been skipped and disabled services were re-enabled. Continuing will pick the installation up where it left off.';

  @override
  String get resumeFoundLastError => 'Last recorded error:';

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
  String get incompleteImageStatus =>
      'Incomplete firmware image detected. Re-flashing to recover...';

  @override
  String get incompleteImageHeading => 'Incomplete firmware image';

  @override
  String get incompleteImageBody =>
      'This scooter is running a minimal recovery image with no battery telemetry. This can happen when a previous install wrote the wrong image. Continue to re-flash the full firmware and finish setup.';

  @override
  String get reflashToRecover => 'Re-flash to recover';

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
  String get deactivateMainBatteryHeading => 'Main Battery';

  @override
  String get deactivateMainBattery => 'Deactivate main battery';

  @override
  String get deactivateMainBatteryStep =>
      'The scooter will switch off the main battery. You do not need to take it out of the seatbox.';

  @override
  String get deactivatingMainBattery => 'Switching off the main battery...';

  @override
  String get mainBatteryDeactivated => 'Main battery switched off';

  @override
  String get mainBatteryAlreadyOff => 'Main battery is already off';

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
  String get mdbFlashComplete => 'MDB flash complete!';

  @override
  String flashProgressMb(String mb) {
    return '$mb MB written';
  }

  @override
  String flashProgressMbOfTotal(String mb, String total) {
    return '$mb / $total MB written';
  }

  @override
  String flashProgressEta(int minutes, int seconds) {
    return '${minutes}m ${seconds}s remaining';
  }

  @override
  String flashProgressBootSector(String mb) {
    return 'Boot sector: $mb MB written';
  }

  @override
  String get scooterPrepHeading => 'Scooter Preparation';

  @override
  String get scooterPrepSubheading =>
      'MDB firmware has been written. Now prepare for reboot.';

  @override
  String get disconnectCbb => 'Disconnect the CBB';

  @override
  String get disconnectCbbDesc =>
      'The main battery must already be switched off (the previous step) before disconnecting the CBB. Failure to follow this order risks electrical damage.';

  @override
  String get disconnectAuxPole => 'Disconnect one AUX pole';

  @override
  String get disconnectAuxPoleDesc =>
      'Remove ONLY the positive pole (outermost, the red cable and pole) to avoid risk of inverting polarity. This will remove power from the MDB; the USB connection will disappear.';

  @override
  String get auxDisconnectWarning =>
      'The USB connection will be lost when you disconnect AUX. This is expected. The installer will wait for the MDB to reboot.';

  @override
  String get doneCbbAuxDisconnected => 'Done. I disconnected CBB and AUX';

  @override
  String get waitingForMdbBoot => 'Waiting for MDB Boot';

  @override
  String get reconnectAuxPole => 'Reconnect the AUX pole';

  @override
  String get reconnectAuxPoleDesc =>
      'Reconnect the positive AUX pole. The MDB will power on and boot into Librescoot.';

  @override
  String get reconnectCbbFirstDesc =>
      'Reconnect the CBB first, while the AUX is still disconnected, so it connects to a powered-down scooter.';

  @override
  String get cbbBeforeAuxWarning =>
      'Reconnect the CBB before the AUX. Connecting the CBB while the scooter is powered risks the main battery being live.';

  @override
  String get dbcLedHint =>
      'DBC LED: orange = starting, green = booting, off = running';

  @override
  String get mdbStillUms =>
      'MDB still in UMS mode. Flash may not have taken. Retrying...';

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
      'Connection still unstable. USB ethernet may have lost its IP. On Linux, your NetworkManager may be fighting for the interface (try disabling IPv6). See log for details.';

  @override
  String get reconnectingSsh => 'Reconnecting SSH...';

  @override
  String sshReconnectionFailed(String error) {
    return 'SSH reconnection failed: $error';
  }

  @override
  String get reconnectCbbHeading => 'Verify CBB and main battery';

  @override
  String get verifyCbbConnection => 'Verify CBB Connection';

  @override
  String get verifyBatteryPresence => 'Verify battery';

  @override
  String get checkingCbb => 'Checking CBB...';

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
  String get finishStepsAboveToContinue =>
      'Finish the steps above to continue.';

  @override
  String get startingTrampoline => 'Starting trampoline script...';

  @override
  String uploadError(String error) {
    return 'Upload error: $error';
  }

  @override
  String get dbcReadyButton => 'Begin flashing DBC';

  @override
  String get dbcFlashInProgress => 'DBC Flash in Progress';

  @override
  String get dbcFlashSwapCablesTitle => 'Swap USB to the DBC';

  @override
  String get disconnectUsbFromLaptop =>
      'Unplug the laptop USB cable from the MDB';

  @override
  String get disconnectUsbFromLaptopDesc =>
      'Unplug the laptop USB cable from the MDB to free the port for the DBC cable.';

  @override
  String get reconnectDbcUsbToMdb => 'Reconnect DBC USB cable to MDB';

  @override
  String get reconnectDbcUsbToMdbDesc =>
      'Plug the internal DBC USB cable into the MDB port. Don\'t screw it in yet.';

  @override
  String get verifyingDbcInstallation => 'Verifying DBC Installation';

  @override
  String get reconnectUsbToLaptop =>
      'Unplug the DBC cable from the MDB and plug the laptop back in...';

  @override
  String get waitingForRndisDevice => 'Waiting for RNDIS device...';

  @override
  String get readingTrampolineStatus => 'Reading trampoline status...';

  @override
  String readingTrampolineStatusElapsed(int elapsed) {
    return 'Reading trampoline status… (${elapsed}s)';
  }

  @override
  String get dbcFlashSuccessful => 'DBC flash successful!';

  @override
  String get dbcAlreadyCurrentTitle => 'Dashboard already up to date';

  @override
  String dbcAlreadyCurrentBody(String version) {
    return 'The dashboard (DBC) already runs Librescoot $version. Flash it again anyway?';
  }

  @override
  String get dbcAlreadyCurrentReflash => 'Flash again';

  @override
  String get dbcAlreadyCurrentSkip => 'Skip DBC flash';

  @override
  String get dbcPrepComplete => 'DBC image ready to flash';

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
      'Trampoline status unknown. Check /data/installer/trampoline.log on the MDB.';

  @override
  String get welcomeToLibrescoot => 'Welcome to Librescoot!';

  @override
  String get finalSteps => 'Final steps:';

  @override
  String get disconnectUsbFromLaptopFinal => 'Unplug the laptop from the MDB';

  @override
  String get disconnectUsbFromLaptopFinalDesc =>
      'If the laptop is still plugged into the MDB port, unplug it now. The DBC cable goes back into that port.';

  @override
  String get reconnectDbcUsbCable =>
      'Reconnect and screw down the DBC USB cable';

  @override
  String get reconnectDbcUsbCableDesc =>
      'Plug the internal DBC USB cable back into the MDB port if it isn\'t already, then gently screw it in to secure it.';

  @override
  String get screwDbcUsbCable => 'Screw the DBC USB cable down';

  @override
  String get screwDbcUsbCableDesc =>
      'The DBC cable is already plugged into the MDB port; gently screw it in to secure it.';

  @override
  String get closeSeatboxAndFootwell => 'Replace the footwell cover';

  @override
  String get closeSeatboxAndFootwellDesc =>
      'Clip the metal bars back in first, then fit the footwell cover and screw it down.';

  @override
  String get unlockScooter => 'Unlock your scooter';

  @override
  String get unlockScooterDesc =>
      'Use a keycard or paired phone if you set one up, or the button in the app.';

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
  String get safetyCheckFailed => 'Safety Check Failed';

  @override
  String get cannotFlashSafety =>
      'Cannot flash this device due to safety concerns:';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get unknown => 'Unknown';

  @override
  String get backingUpConfig => 'Backing up device configuration...';

  @override
  String get configBackedUp => 'Device configuration backed up';

  @override
  String get restoringConfig => 'Restoring device configuration...';

  @override
  String healthCheckFailed(String error) {
    return 'Health check failed: $error';
  }

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get regionHint => 'For offline maps and navigation support';

  @override
  String get skipOfflineMaps => 'Skip offline maps';

  @override
  String get bluetoothPairingHeading => 'Bluetooth Pairing';

  @override
  String get bluetoothPairingHint =>
      'Pair your phone or other Bluetooth devices with the scooter.';

  @override
  String get bleMacLabel => 'BLE address';

  @override
  String get startPairing => 'Start pairing';

  @override
  String get skipPairing => 'Skip';

  @override
  String get pairingActive => 'Pairing mode active';

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
  String keycardLearnedAck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keycards registered',
      one: '1 keycard registered',
    );
    return '$_temp0. Click Continue to finish, or Add more cards to register additional ones.';
  }

  @override
  String keycardLearningTapped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keycards tapped',
      one: '1 keycard tapped',
      zero: 'No keycards tapped yet',
    );
    return '$_temp0';
  }

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
  String get keycardEntryAlreadyConfiguredHeading =>
      'Keycards already configured';

  @override
  String keycardEntryAlreadyConfiguredBody(int master, int authorized) {
    String _temp0 = intl.Intl.pluralLogic(
      master,
      locale: localeName,
      other: '$master master cards are set',
      one: '1 master card is set',
      zero: 'No master card is set',
    );
    String _temp1 = intl.Intl.pluralLogic(
      authorized,
      locale: localeName,
      other: '$authorized unlock cards are registered',
      one: '1 unlock card is registered',
      zero: 'no unlock cards are registered',
    );
    return '$_temp0 and $_temp1. You can keep this state, or wipe everything and start over.';
  }

  @override
  String get keycardEntryContinueButton => 'Continue';

  @override
  String get keycardStartOverButton => 'Start over';

  @override
  String get keycardStartOverConfirmTitle => 'Wipe all keycards?';

  @override
  String get keycardStartOverConfirmBody =>
      'This deletes the master card and every registered unlock card on the scooter. You\'ll need to re-register them. Continue?';

  @override
  String get keycardStartOverConfirmYes => 'Wipe everything';

  @override
  String get keycardStartOverConfirmNo => 'Cancel';

  @override
  String get keycardCardsStageContinueButton => 'Continue';

  @override
  String get keycardCardsStageAddMasterButton => 'Add master card (advanced)';

  @override
  String get keycardMasterStageHeading => 'Add master card';

  @override
  String get keycardMasterStageWarningHeading =>
      'WARNING: master card is NOT for unlocking';

  @override
  String get keycardMasterStageWarningBody =>
      'The master card is used to manage other keycards. It CANNOT unlock the scooter. Do NOT use any of the cards you just registered as unlock cards. Use a separate, fresh card.';

  @override
  String get keycardMasterStageHint => 'Hold the master card to the reader.';

  @override
  String get keycardCardDuplicateToast => 'This card is already registered.';

  @override
  String get keycardMasterStageRejectedToast =>
      'This card is already registered as an unlock card.';

  @override
  String get keycardMasterStageSaveFailedToast =>
      'Could not save master card: write failed.';

  @override
  String get keycardMasterStageLearnedToast => 'Master card registered.';

  @override
  String get keycardMasterStageSkipButton => 'Skip';

  @override
  String get keycardSimulateTapButton => '[DRY RUN] Simulate tap';

  @override
  String get keycardSimulateMasterTapButton => '[DRY RUN] Simulate master tap';

  @override
  String get keycardSimulateRejectedTapButton =>
      '[DRY RUN] Simulate already-authorized rejection';

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
  String get reconnectCbbStep => 'Reconnect the CBB';

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
  String get finishRebootingTitle => 'Rebooting scooter…';

  @override
  String get finishRebootingBody =>
      'The MDB is rebooting; the USB connection will drop by itself. No need to touch the cable yet.';

  @override
  String get networkConfigNeedsPermission =>
      'macOS is asking for permission to change network settings. Click Allow in the system dialog, then hit Retry.';

  @override
  String get dbcWalkAwayHeadline =>
      'Swap done. The install is now running on its own.';

  @override
  String get dbcWalkAwayBody =>
      'The scooter now flashes the dashboard on its own. This takes 10 to 20 minutes. In the meantime, have a look at the first steps below and the handbook.';

  @override
  String get dbcWalkAwayLedProgress =>
      'Progress: the keycard LED on the dashboard pulses amber in groups. One pulse shortly after the start, up to four pulses near the end. The dashboard itself may turn on and off several times; that\'s normal.';

  @override
  String get dbcWalkAwayDone =>
      'Done: the LED stops pulsing and stays off. Then screw the DBC cable down, close everything up, unlock the scooter, and ride.';

  @override
  String get dbcWalkAwayFailure =>
      'If the scooter flashes its hazard lights or the keycard LED blinks red instead, something went wrong: plug the laptop back into the MDB.';

  @override
  String get dbcWalkAwayDoneButton => 'Continue to finish';

  @override
  String get dbcWalkAwayWentWrongButton => 'Something went wrong';

  @override
  String get phaseKeycardSetupTitle => 'Keycard Setup';

  @override
  String get phaseKeycardSetupDescription => 'Register your keycards';

  @override
  String get usingLocalFirmwareImages => 'Using local firmware images';

  @override
  String get mdbDetectedUmsSkipping =>
      'MDB detected in UMS mode. Skipping to flash.';

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
      'MDB disconnected. Flashing DBC autonomously...';

  @override
  String get logDebugShell => 'Log & Debug Shell';

  @override
  String get copyToClipboard => 'Copy to clipboard';

  @override
  String logFilePath(String path) {
    return 'Log file: $path';
  }

  @override
  String get revealLogFile => 'Show in folder';

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
      'The seatbox button only opens the quick menu in drive mode (kickstand up). Hold the seatbox button to open the on-screen quick menu; the entries cycle automatically every second while you keep holding. Release to stop on the highlighted entry, then press once briefly within about a second to confirm.';

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

  @override
  String get substepWaitRndis => 'Wait for MDB (RNDIS) on USB';

  @override
  String get substepConfigureNetwork => 'Configure network';

  @override
  String get substepConnectSsh => 'Connect SSH';

  @override
  String get substepDisableHazards => 'Disable alarm and auto-standby';

  @override
  String get substepReadStatus => 'Read trampoline status';

  @override
  String elapsedSeconds(int seconds) {
    return '${seconds}s elapsed';
  }

  @override
  String get reconnectTimeoutHeading => 'Taking longer than usual';

  @override
  String reconnectTimeoutBody(int minutes) {
    return 'It has been $minutes min without the MDB coming back as an RNDIS device. The DBC\'s first boot can take a while (partition resize, map install). You can keep waiting, or restart / skip below.';
  }

  @override
  String get usbDeviceCurrentlyDetected => 'Currently detected USB device';

  @override
  String get usbDeviceNone => 'none';

  @override
  String get collectingUsbInfo => 'Collecting USB device info…';

  @override
  String get usbInfoUnsupportedPlatform =>
      'USB info collection not supported on this platform.';

  @override
  String get usbInfoCollectFailed => 'Failed to collect USB info';

  @override
  String internalError(String error) {
    return 'Internal error: $error';
  }

  @override
  String get copyLog => 'Copy log';

  @override
  String get tileLabelMaps => 'Maps';

  @override
  String get tileLabelRoutes => 'Routes';
}

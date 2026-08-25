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
  String get phaseResumeDetectedTitle => 'Previous Attempt';

  @override
  String get phaseResumeDetectedDescription => 'Interrupted installation found';

  @override
  String get phaseHealthCheckTitle => 'Health Check';

  @override
  String get phaseHealthCheckDescription => 'Verify scooter readiness';

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
  String get majorStepPrepare => 'Set up';

  @override
  String get majorStepConnect => 'Connect';

  @override
  String get majorStepMdbFlash => 'Prepare MDB';

  @override
  String get majorStepPairing => 'Pairing & Cards';

  @override
  String get majorStepMdbInstall => 'Install MDB';

  @override
  String get majorStepDbcFlash => 'Install DBC';

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
      'The flash takes several minutes and any USB drop or laptop sleep mid-flash leaves the MDB in an inconsistent state. Check:\n• A known-good USB cable, plugged in firmly at both ends. Flaky cables are the #1 cause of failed installs\n• Laptop on power, or fully charged. Battery saver / sleep can break the flash\n• Use a direct USB port, not a USB hub if possible\n• Don\'t unplug or move things around once the flash starts';

  @override
  String get noPowerCycleWarningTitle =>
      'DO NOT power-cycle anything during the install';

  @override
  String get noPowerCycleWarningBody =>
      'If something looks stuck, gives no feedback, or behaves oddly: stop and ask in Discord before doing anything else. Do not pull the AUX battery, disconnect the CBB, unplug USB, or restart the scooter or your laptop. The installer can recover from almost any state, as long as nothing interrupts it. Cutting power mid-flash is what bricks scooters.';

  @override
  String get downloadsFailedHeading => 'Could not reach the download server';

  @override
  String get downloadsFailedBody =>
      'Check the laptop\'s internet connection, then try again. You can also continue offline if you already have the firmware cached.';

  @override
  String get downloadsRetry => 'Retry';

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
  String get selectRegionError => 'Select a region for offline maps';

  @override
  String get resolvingReleases => 'Resolving releases...';

  @override
  String get physicalPrepHeading => 'Physical preparation';

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
      'Disconnect the internal DBC USB cable from the MDB. Use a flat head or PH1 screwdriver.';

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
      'The scooter is not damaged. An installation was interrupted, and this screen clears what it left behind before starting again.';

  @override
  String get resumeWhatHappensHeading => 'What happens when you continue';

  @override
  String get resumeWhatHappensCleanup =>
      'The leftovers are cleared: the onboot script the previous run armed is disarmed, and the services it stopped are started again.';

  @override
  String get resumeWhatHappensRestart =>
      'The installation runs from the beginning. Nothing is resumed, so no half-finished step is carried over.';

  @override
  String get resumeWhatHappensKeep =>
      'Nothing extra is lost. The previous run had already made whatever changes it made; starting again does not repeat that cost.';

  @override
  String get resumeTakesAsLong =>
      'It takes as long as a normal installation, about 20 minutes.';

  @override
  String get resumeClearingLeftovers =>
      'Clearing what the previous run left behind...';

  @override
  String resumeCleanupFailed(String error) {
    return 'The previous install could not be made safe: $error\n\nNothing else will run until cleanup succeeds.';
  }

  @override
  String get resumeFoundLastError => 'Last recorded error:';

  @override
  String get resumeRunningHeading =>
      'An install is still running on the scooter';

  @override
  String get resumeRunningBody =>
      'The scooter is still working through the previous install. Nothing here touches it while it runs.';

  @override
  String get resumeRunningWait =>
      'Wait for the scooter to finish. This carries on by itself afterwards.';

  @override
  String resumeStageLabel(String stage) {
    return 'Last step: $stage';
  }

  @override
  String get resumeActorScooter => 'on the scooter';

  @override
  String get resumeActorInstaller => 'in the installer';

  @override
  String get resumeLogHeading => 'Last lines from the scooter\'s log';

  @override
  String get awaitingUnlockHeading => 'Unlock your scooter';

  @override
  String get awaitingUnlockDetail =>
      'Unlock the scooter so the installer can carry on.';

  @override
  String get awaitingUnlockHintKeycard =>
      'Hold your keycard against the reader on the handlebars';

  @override
  String get awaitingUnlockHintPhone => 'Or use a paired phone';

  @override
  String get awaitingUnlockWatching =>
      'The installer continues automatically once the scooter is unlocked.';

  @override
  String get awaitingParkWatching =>
      'The installer continues automatically once the scooter is parked.';

  @override
  String get awaitingParkHeading => 'Park your scooter';

  @override
  String get awaitingParkDetail =>
      'Park your scooter (flip the kickstand down) to continue.';

  @override
  String get awaitingParkContinueAnyway => 'Continue anyway';

  @override
  String get lockingScooter => 'Locking the scooter for flashing...';

  @override
  String get connected => 'Connected';

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
    return 'Installation has not been tested on firmware versions older than 1.12.0 (yours: $version). The installer should still work, but share any issues on the Librescoot Discord.';
  }

  @override
  String get openLibrescootDiscord => 'Open Librescoot Discord';

  @override
  String get healthCheckHeading => 'Health check';

  @override
  String get verifyingReadiness => 'Verifying scooter readiness...';

  @override
  String get incompleteImageStatus =>
      'Incomplete firmware image detected. Re-flashing to recover...';

  @override
  String get incompleteImageHeading => 'Incomplete firmware image';

  @override
  String get incompleteImageBody =>
      'This scooter is running a minimal recovery image. It boots and answers, but carries none of the vehicle services. This can happen if an earlier installation did not finish. Continue to re-flash the full firmware and finish setup.';

  @override
  String get reflashToRecover => 'Re-flash to recover';

  @override
  String get stockFirmwareStatus =>
      'Stock firmware detected. Ready to install Librescoot...';

  @override
  String get stockFirmwareHeading => 'Stock firmware';

  @override
  String get stockFirmwareBody =>
      'This scooter is running its original firmware. Nothing is wrong with it. Some readings here come from a different set of keys and are shown as unknown rather than measured. Continue to install Librescoot.';

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
  String get healthValueUnknown => 'cannot be read';

  @override
  String get riskAuxLow =>
      'Low 12V battery could cause the MDB or DBC to shut down during flashing. The LED indicators may also fail. Close the seatbox with the main battery inserted and wait for the AUX battery to charge.';

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
  String get openSeatbox => 'Open Seatbox';

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
  String get readyToFlashTargetLabel => 'Target';

  @override
  String get readyToFlashImageLabel => 'Image to write';

  @override
  String get readyToFlashErases =>
      'This erases the main board. Everything currently on it is replaced.';

  @override
  String get readyToFlashDuration =>
      'The write takes about a minute. Do not disconnect USB or power while it runs.';

  @override
  String get readyToFlashNoTarget => 'No target device resolved yet.';

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
  String get mdbFlashComplete => 'MDB flash complete';

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
  String get scooterPrepHeading => 'Scooter preparation';

  @override
  String get scooterPrepSubheading =>
      'MDB firmware has been written. Now prepare for reboot.';

  @override
  String get disconnectCbb => 'Disconnect the CBB';

  @override
  String get disconnectCbbDesc =>
      'The main battery must already be removed before disconnecting CBB. Doing this out of order risks electrical damage.';

  @override
  String get disconnectAuxPole => 'Disconnect one AUX pole';

  @override
  String get disconnectAuxPoleDesc =>
      'Remove only the positive terminal (outer, red cable and post) to avoid reversing polarity. This cuts power to the MDB, so the USB connection drops.';

  @override
  String get auxDisconnectWarning =>
      'The USB connection drops when you disconnect AUX. That is expected. Reconnect the AUX pole on the next screen to start the MDB.';

  @override
  String get doneCbbAuxDisconnected => 'Done, the scooter is restarting';

  @override
  String get doneAuxDisconnected => 'Done, AUX is disconnected';

  @override
  String get brakeResetHeading => 'Restart the scooter';

  @override
  String get brakeResetIntro =>
      'Squeeze and hold both brake levers. Every ten seconds, let go of the right one for about a second, then squeeze it again. After the fourth hold, just let go. The scooter restarts.';

  @override
  String get brakeResetAfterNote =>
      'The USB connection disappears while it restarts. That is expected, and the installer waits for the board to come back.';

  @override
  String get brakePacerStart => 'Start the timer';

  @override
  String get brakePacerStop => 'Stop';

  @override
  String get brakePacerRestart => 'Run it again';

  @override
  String get brakePacerDone =>
      'That is the pattern. Let go now. The scooter restarts a few seconds later on its own.';

  @override
  String get brakeDiagramBlipLegend =>
      'Right lever released for about a second';

  @override
  String brakeDiagramEndLegend(int seconds) {
    return 'Just let go at $seconds seconds';
  }

  @override
  String get brakeBandBothHeld => 'Left lever held down throughout';

  @override
  String get brakeBlipRight => 'Right lever off, now';

  @override
  String get brakeLeftStaysHint =>
      'The left lever stays squeezed the whole time.';

  @override
  String get brakeLeadInLabel => 'Squeeze both brakes in';

  @override
  String get brakeLeadInHint =>
      'Step over to the handlebars and put a hand on each lever.';

  @override
  String get brakeKeepHolding => 'Hold both brakes';

  @override
  String get scooterPrepManualFallback => 'Or cut the power by hand';

  @override
  String get deactivatingMainBattery => 'Turning the main battery off...';

  @override
  String get waitingForMdbBoot => 'Waiting for MDB boot';

  @override
  String get mdbBootRestartingNote =>
      'The scooter is restarting on its own. This takes a minute or two.';

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
      'MDB still in UMS mode. Flash may not have taken. Retrying...';

  @override
  String get waitingForMdbRestart => 'Waiting for the scooter to restart...';

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
  String get reconnectCbbHeading => 'Reconnect the CBB';

  @override
  String get verifyCbbConnection => 'Verify CBB Connection';

  @override
  String get verifyBatteryPresence => 'Verify battery';

  @override
  String get turningMainBatteryOff => 'Turning the main battery off first...';

  @override
  String get turningMainBatteryOn => 'Turning the main battery back on...';

  @override
  String get checkingCbb => 'Checking CBB...';

  @override
  String waitingForCbb(int attempts) {
    return 'Waiting for CBB... ($attempts)';
  }

  @override
  String get cbbNotDetected => 'CBB not detected. Check the connection.';

  @override
  String get cbbDetectionMayTakeMinutes => 'This can take several minutes.';

  @override
  String get preparingDbcFlash => 'Preparing DBC Flash';

  @override
  String get preparingDbcFlashSubtitle =>
      'Everything the dashboard needs goes onto the MDB first.';

  @override
  String get preparingDbcFlashExplainer =>
      'The DBC hangs off the MDB, not off your laptop. So the installer copies the image, the firmware and the offline maps onto the MDB, together with a script that takes over from there. The cable swap comes after that: laptop off, DBC cable back onto the MDB. From then on the MDB flashes the dashboard on its own.';

  @override
  String get waitingForDownloads => 'Waiting for downloads to complete...';

  @override
  String get startingTrampoline => 'Starting the on-device install script...';

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
  String get dbcFlashSwapCablesDeadline =>
      'The scooter is already waiting for the dashboard. It gives up after a few minutes, so do this now rather than later. No need to rush the screws.';

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
  String get ledBlinkerProgress => 'Blinkers light up in turn';

  @override
  String get blinkerPosFL => 'front left';

  @override
  String get blinkerPosFR => 'front right';

  @override
  String get blinkerPosBR => 'rear right';

  @override
  String get blinkerPosBL => 'rear left';

  @override
  String get blinkerStepPrep => 'Prepare DBC';

  @override
  String get blinkerStepFlash => 'Flash DBC';

  @override
  String get blinkerStepRestart => 'Restart DBC';

  @override
  String get blinkerStepMaps => 'Upload maps';

  @override
  String get verifyingDbcInstallation => 'Verifying DBC installation';

  @override
  String get reconnectUsbToLaptop => 'Reconnect USB to laptop...';

  @override
  String get waitingForRndisDevice => 'Waiting for RNDIS device...';

  @override
  String get readingTrampolineStatus => 'Reading trampoline status...';

  @override
  String readingTrampolineStatusElapsed(int elapsed) {
    return 'Reading trampoline status… (${elapsed}s)';
  }

  @override
  String get dbcFlashSuccessful => 'DBC flash complete';

  @override
  String dbcInstallSuccessfulVersion(String version) {
    return 'DBC install successful, now running $version';
  }

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
  String get welcomeToLibrescoot => 'Welcome to Librescoot';

  @override
  String get finalSteps => 'Final steps:';

  @override
  String get finishNextHeading => 'What happens next';

  @override
  String get finishNextDbcFlash =>
      'When you reconnect the DBC cable, the scooter starts installing the dashboard by itself. That takes about 20 minutes. Leave the power connected and let it finish; the boot light shows it working.';

  @override
  String get finishNextOnDevice =>
      'When you reconnect the DBC cable, the scooter finishes the rest by itself. You do not need to plug the laptop back in.';

  @override
  String get finishNextNothing =>
      'The main board is done and nothing else runs on the scooter. Reassemble it and ride.';

  @override
  String get disconnectUsbFromLaptopFinal =>
      'Unplug the laptop USB cable from the MDB';

  @override
  String get disconnectUsbFromLaptopFinalDesc =>
      'Unplug the laptop USB cable from the MDB. The DBC cable goes back into that port next.';

  @override
  String get reconnectDbcUsbCable => 'Reconnect DBC USB cable';

  @override
  String get reconnectDbcUsbCableDesc =>
      'Plug the internal DBC USB cable back into the MDB port, then gently screw it in to secure it.';

  @override
  String get closeSeatboxAndFootwell => 'Replace the footwell cover';

  @override
  String get closeSeatboxAndFootwellDesc =>
      'Clip the metal bars back in first, then fit the footwell cover and screw it down.';

  @override
  String get unlockScooter => 'Unlock your scooter';

  @override
  String get unlockScooterDesc =>
      'Use one of the keycards you registered, or unlock via Bluetooth.';

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
  String get assetChipMdbArtifact => 'MDB artifact';

  @override
  String get assetChipDbcArtifact => 'DBC artifact';

  @override
  String get assetChipMdbImage => 'MDB image';

  @override
  String get assetChipDbcImage => 'DBC image';

  @override
  String get assetChipMaps => 'Maps';

  @override
  String get assetChipRoutes => 'Routes';

  @override
  String get downloadMdbFirmware => 'MDB Firmware';

  @override
  String get downloadDbcFirmware => 'DBC Firmware';

  @override
  String get downloadMapTiles => 'Map Tiles';

  @override
  String get downloadRoutingTiles => 'Routing Tiles';

  @override
  String get safetyCheckFailed => 'Safety check failed';

  @override
  String get cannotFlashSafety =>
      'Cannot flash this device due to safety concerns:';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get confirmFlashTargetTitle => 'Confirm the flash target';

  @override
  String get confirmFlashTargetBody =>
      'Windows could not confirm this disk is not your system disk. Check the target before flashing.';

  @override
  String get confirmFlashTargetDetected => 'Detected Librescoot device';

  @override
  String get confirmFlashTargetOthers => 'Other USB disks on this machine:';

  @override
  String get confirmFlashTargetInternalHidden =>
      'Internal disks are not shown.';

  @override
  String get confirmFlashTargetAccept => 'Flash this disk';

  @override
  String get flashTargetNotConfirmed =>
      'Flashing cancelled: the target disk was not confirmed.';

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
  String get bluetoothPairingHeading => 'Bluetooth pairing';

  @override
  String get bluetoothPairingHint =>
      'Pair your phone or other Bluetooth devices with the scooter.';

  @override
  String get bleMacLabel => 'BLE address';

  @override
  String get startPairing => 'Start pairing';

  @override
  String get blePreparingRadio =>
      'Restarting the Bluetooth radio, wait for this before pairing.';

  @override
  String get skipPairing => 'Skip';

  @override
  String get pairingActive => 'Ready to pair';

  @override
  String get pairingActiveHint =>
      'Search for the scooter in your phone\'s Bluetooth settings and pair it. Press Done when finished.';

  @override
  String get pairingDone => 'Done';

  @override
  String get blePinHint => 'Enter this PIN on your device to complete pairing.';

  @override
  String get blePairedHeading => 'Device paired';

  @override
  String get blePairedHint =>
      'To pair another device, disconnect this one on the device itself first. The scooter holds only one Bluetooth connection at a time.';

  @override
  String get bleLinkHeldHeading => 'A device is holding the connection';

  @override
  String get bleLinkHeldHint =>
      'The scooter holds only one Bluetooth connection at a time, and it will not advertise while one is up. Disconnect it on the connected device before pairing a new one.';

  @override
  String get keycardLearningHeading => 'Keycard setup';

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
  String get keycardStopScanning => 'Stop';

  @override
  String get keycardSkipConfirmTitle => 'Skip without a keycard?';

  @override
  String get keycardSkipConfirmBody =>
      'No card is taught in, so the scooter cannot be unlocked with one. Only the phone will work.';

  @override
  String get keycardSkipConfirmAction => 'Skip anyway';

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
      'The master card cannot unlock the scooter';

  @override
  String get keycardMasterStageWarningBody =>
      'The master card manages your other keycards. It cannot unlock the scooter, and none of the cards you just registered can serve as a master. Use a separate, unused card.';

  @override
  String get keycardMasterStageHint => 'Hold the master card to the reader.';

  @override
  String get keycardCardDuplicateToast => 'This card is already registered.';

  @override
  String get keycardMasterStageRejectedToast =>
      'This card is already registered as an unlock card.';

  @override
  String get keycardMasterStageSaveFailedToast =>
      'Could not save master card. Try again.';

  @override
  String get keycardMasterStageLearnedToast => 'Master card registered.';

  @override
  String get keycardMasterStageStartFailed =>
      'Master card setup could not be started';

  @override
  String get keycardMasterStageRetryButton => 'Try again';

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
  String get phaseInstallPlanTitle => 'Install Plan';

  @override
  String get phaseInstallPlanDescription => 'Choose what happens to each board';

  @override
  String get phaseMdbArtifactTitle => 'MDB Update';

  @override
  String get phaseMdbArtifactDescription => 'Install the firmware artifact';

  @override
  String get majorStepMdbUpgrade => 'Upgrade MDB';

  @override
  String get majorStepDbcUpgrade => 'Upgrade DBC';

  @override
  String get installPlanHeading => 'What should the installer do?';

  @override
  String installPlanIntro(String version) {
    return 'Pick an action for each board. Target version: $version';
  }

  @override
  String get boardMdb => 'MDB (main board)';

  @override
  String get boardDbc => 'DBC (dashboard)';

  @override
  String boardVersionCurrent(String version) {
    return 'Currently $version';
  }

  @override
  String boardVersionLastSeen(String version) {
    return 'Last seen running $version';
  }

  @override
  String previousRunSummary(String when, String version) {
    return 'Last install finished $when, leaving $version';
  }

  @override
  String get boardVersionUnknown => 'Version unknown';

  @override
  String get actionUpgrade => 'Upgrade';

  @override
  String get actionUpgradeDetail => 'Keeps settings, keycards, maps and trips';

  @override
  String get actionCleanInstall => 'Clean install';

  @override
  String get actionCleanInstallDetail =>
      'Erases settings and trip history. Keycards and maps are set up again later in this run';

  @override
  String get actionUpgradeDetailDbc => 'Keeps the offline maps';

  @override
  String get actionCleanInstallDetailDbc => 'Erases the offline maps only';

  @override
  String get actionCleanInstallDetailDbcTiles =>
      'Erases the offline maps. They are installed again in this run';

  @override
  String get actionLeave => 'Leave alone';

  @override
  String get actionLeaveDetail => 'This board is not touched';

  @override
  String get upgradeBlockedNotLibrescoot =>
      'Upgrade needs Librescoot to already be installed';

  @override
  String get upgradeBlockedStateUnknown =>
      'Upgrade needs a known version on this board';

  @override
  String get upgradeBlockedMinimalImage =>
      'This board is running a bootstrap image and has to be installed';

  @override
  String get upgradeBlockedNoMender =>
      'This board has no update client, so it can only be reinstalled';

  @override
  String get planTilesNeedDbcHandoff =>
      'Refreshing map tiles needs the DBC cable swap, even with the DBC left alone';

  @override
  String get actionLeaveBlockedStockMdb =>
      'A stock main board has to be installed before anything else can be done';

  @override
  String get planDbcNeedsLibrescootMdb =>
      'The dashboard can only be reached through the MDB, and the tools that reach it are part of Librescoot. Install the MDB in this run, or leave the dashboard alone.';

  @override
  String get planNothingToDo =>
      'Nothing selected. Pick at least one action to continue.';

  @override
  String get releaseMissingAssetsTitle => 'This release cannot be installed';

  @override
  String releaseMissingAssetsBody(String tag, String assets) {
    return 'The $tag release does not publish everything the installer needs: $assets. Go back and pick a different channel, or wait for a release that has them.';
  }

  @override
  String get assetMdbArtifact => 'the MDB firmware artifact';

  @override
  String get assetDbcArtifact => 'the DBC firmware artifact';

  @override
  String get assetMdbImage => 'the MDB system image';

  @override
  String get assetDbcImage => 'the DBC system image';

  @override
  String get artifactStaging => 'Uploading firmware artifact...';

  @override
  String artifactInstalling(int percent) {
    return 'Installing firmware ($percent%)';
  }

  @override
  String get artifactVerifying => 'Verifying installed version...';

  @override
  String get waitingForDbcUpload =>
      'Waiting for the dashboard transfer to finish...';

  @override
  String get artifactStillMinimal =>
      'The MDB came back on the bootstrap image, so the firmware artifact did not take. Retry, or write the full image instead.';

  @override
  String artifactVersionMismatch(String found, String expected) {
    return 'The MDB still reports $found after the reboot, not $expected. The install was rolled back, so nothing was changed. Retry, or write the full image instead.';
  }

  @override
  String get artifactInstallFailedHeading => 'Firmware install failed';

  @override
  String get artifactStagingInBackground => 'Finishing the firmware install...';

  @override
  String get artifactNoneDownloaded =>
      'No firmware artifact was downloaded for this board.';

  @override
  String get dbcImageMissing =>
      'The DBC system image this plan needs is missing.';

  @override
  String get artifactRebootTimeout =>
      'The MDB did not come back after the reboot.';

  @override
  String get artifactPreflightNoMender =>
      'This board has no update client, so it cannot take a firmware artifact.';

  @override
  String artifactPreflightOtaBusy(String status) {
    return 'The scooter is running its own update right now ($status). Let it finish and reboot, then retry.';
  }

  @override
  String artifactPreflightNoSpace(int freeMiB, int neededMiB) {
    return 'Not enough space in /data: $freeMiB MiB free, $neededMiB MiB needed.';
  }

  @override
  String get artifactRetry => 'Retry';

  @override
  String get artifactFallBackToFullImage => 'Write the full image instead';

  @override
  String get fallBackWipeTitle => 'This erases the scooter\'s data';

  @override
  String get fallBackWipeBody =>
      'Writing the full image reformats the data partition. Settings, paired keycards, offline maps and trip history are all lost, and the scooter comes back as if it were new. The upgrade you started would have kept them.\n\nRetrying the firmware artifact keeps the data. Only write the full image if the artifact keeps failing.';

  @override
  String get fallBackWipeConfirm => 'Erase and write the full image';

  @override
  String get dbcCleanInstallButton => 'Erase the DBC and install from scratch';

  @override
  String get dbcCleanInstallTitle => 'This erases the DBC';

  @override
  String get dbcCleanInstallBody =>
      'The dashboard\'s last known version is only what the main board saw the last time the two were powered together, so a board the plan treated as upgradable may have no update client at all. Installing from scratch writes the bootstrap image first, which reformats the DBC\'s data partition and loses its offline maps. Anything on the main board, including settings, paired keycards and trip history, is untouched.\n\nThis needs another cable swap: the installer stages the files, you screw the dashboard cable back onto the main board, and the rest runs unattended.';

  @override
  String get dbcCleanInstallConfirm => 'Erase and install the DBC';

  @override
  String firmwareVersionDisplay(String version) {
    return 'Firmware: $version';
  }

  @override
  String healthVersionPlan(String current, String target) {
    return 'Installed $current, installing $target';
  }

  @override
  String healthAuxVoltage(int mv) {
    return '$mv mV';
  }

  @override
  String get openSeatboxButton => 'Open seatbox';

  @override
  String get reconnectCbbStep => 'Reconnect the CBB';

  @override
  String get reconnectCbbStepDesc =>
      'Plug the CBB cable back into the connector in the footwell. Without the CBB, the MDB could shut down during flashing.';

  @override
  String get mainBatteryMissingHeading => 'No main battery detected';

  @override
  String get mainBatteryMissingHint =>
      'The dashboard flash draws from the main battery. Put it back in the seatbox before continuing.';

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
  String get dbcFlashDurationHeadline =>
      'The DBC flash can take 10 to 20 minutes.';

  @override
  String get finishHandoverTitle => 'Waiting for the scooter to unlock';

  @override
  String get finishHandoverBody =>
      'Stay with the scooter until it unlocks itself. Then you can unplug the USB cable.';

  @override
  String get networkConfigNeedsPermission =>
      'macOS is asking for permission to change network settings. Click Allow in the system dialog, then hit Retry.';

  @override
  String get waitingForMdb => 'Waiting for the MDB...';

  @override
  String get dbcFlashAllDone => 'Continue to the last step';

  @override
  String get dbcFlashSequence =>
      'From here the scooter carries on by itself: it writes the image to the dashboard, restarts it and copies the maps over. Progress is shown on the dashboard screen. Stay with the scooter until one of these two things happens.';

  @override
  String get dbcFlashDoNotDisconnect =>
      'Do not disconnect USB or power while this runs.';

  @override
  String get dbcFlashDoneSignal =>
      'Done: the scooter unlocks itself. That is the signal, there is nothing else to wait for.';

  @override
  String get dbcFlashFailSignal =>
      'Failed: the dashboard LED blinks red and the hazards come on. Plug USB back into the MDB and fetch the log here.';

  @override
  String get dbcFlashLedIsTheSignal =>
      'The LED on the dashboard is the error signal: if it blinks red, something has gone wrong.';

  @override
  String get dbcFlashSomethingWrong =>
      'LED blinking red: reconnect USB and fetch the log';

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
  String get mdbReconnectedVerifying => 'MDB reconnected. Verifying...';

  @override
  String get logDebugShell => 'Log & Debug Shell';

  @override
  String internalError(String error) {
    return 'Internal error: $error';
  }

  @override
  String get copyLog => 'Copy log';

  @override
  String get copyToClipboard => 'Copy to clipboard';

  @override
  String logFilePath(String path) {
    return 'Log file: $path';
  }

  @override
  String get revealLogFile => 'Show in folder';

  @override
  String get debugShell => 'Debug shell';

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
  String get gettingStartedTitle => 'Using your scooter';

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
  String get upgradeDowngradeWarning =>
      'This is older than what the board runs now. Upgrade keeps settings, keycards, maps and trips, and older services may not read data a newer version wrote. Install fresh if anything misbehaves afterwards.';

  @override
  String get upgradeChannelSwitchWarning =>
      'This is a different release channel to what the board runs now. Upgrade keeps settings, keycards, maps and trips, which the other channel\'s services may not read the same way. Install fresh if anything misbehaves afterwards.';

  @override
  String get tightenDbcCable => 'Screw the dashboard cable down';

  @override
  String get tightenDbcCableDesc =>
      'The internal dashboard USB cable is already plugged into the MDB. Tighten the screws now.';

  @override
  String get finalRide => 'Ride off';

  @override
  String get finalRideDesc =>
      'The scooter unlocked itself when the install finished. If it did not, use one of the keycards you set up, or unlock over Bluetooth.';

  @override
  String notEnoughDiskSpace(String needed) {
    return 'Not enough disk space: $needed more is required. Free up space and try again.';
  }

  @override
  String get keycardFinishCards => 'Finish';

  @override
  String waitStepCounter(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String waitRemaining(String duration) {
    return 'about $duration left';
  }

  @override
  String waitElapsed(String time) {
    return '$time elapsed';
  }

  @override
  String waitLongerThanUsual(String time) {
    return '$time · longer than usual';
  }

  @override
  String get waitShowLog => 'Show log';

  @override
  String get waitHideLog => 'Hide log';

  @override
  String get blePairingWhy =>
      'A paired phone can unlock the scooter and show its state through the app. You can skip this and do it later.';

  @override
  String get blePairingStep1 => 'Open Bluetooth on your phone';

  @override
  String get blePairingStep1Desc =>
      'Your phone\'s Bluetooth settings, or the app.';

  @override
  String get blePairingStep2 => 'Pick the scooter from the device list';

  @override
  String get blePairingStep2Desc => 'It shows up under the address given here.';

  @override
  String get blePairingStep3 => 'Confirm the PIN';

  @override
  String get blePairingStep3Desc =>
      'The PIN appears on this screen as soon as your phone asks for it.';

  @override
  String get blePairingOneAtATime =>
      'The scooter holds one Bluetooth connection at a time. If a device is already connected, disconnect it there first.';

  @override
  String get keycardWhy =>
      'A card you teach the scooter unlocks it without a phone. You can teach it several, and repeat this later at any time. A clean install clears cards taught before it.';

  @override
  String get keycardStep1 => 'Start learning';

  @override
  String get keycardStep1Desc => 'The scooter then waits for a card.';

  @override
  String get keycardStep2 => 'Hold the card against the reader';

  @override
  String get keycardStep2Desc =>
      'The reader sits at the front of the dashboard. Hold it there until the installer counts the card.';

  @override
  String get keycardStep3 => 'Press Finish';

  @override
  String get keycardStep3Desc =>
      'That ends the learning and the cards take effect.';

  @override
  String get keycardPanelHeading => 'Reader';

  @override
  String get keycardReaderPreparing => 'Preparing';

  @override
  String get keycardReaderReady => 'Ready';

  @override
  String get keycardReaderUnreachable => 'Reader not reachable';

  @override
  String get keycardReaderScanning => 'Hold a card to the reader';

  @override
  String get keycardTaughtThisSession => 'Taught in now';

  @override
  String get keycardTaughtAlready => 'Already on the scooter';

  @override
  String get keycardNeedOneToFinish => 'One card is enough to finish.';

  @override
  String get keycardPreparingReader => 'Preparing the card reader...';

  @override
  String get blePairingDeviceName => 'Device name';

  @override
  String get blePairingStateIdle => 'Pairing not started';

  @override
  String get blePairingStateVisible => 'Visible, waiting for a device';

  @override
  String get blePinConfirmTitle => 'Confirm this PIN on your phone';

  @override
  String get blePinConfirmHint =>
      'Your phone shows the same number. If they match, confirm it there.';

  @override
  String get blePairingStep2DescCompare =>
      'Compare the name and address on the right if several devices show up.';

  @override
  String get blePairingStep3DescOverlay =>
      'The installer shows it in large type as soon as your phone asks.';
}

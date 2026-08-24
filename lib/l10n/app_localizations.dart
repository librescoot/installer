import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @phaseWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get phaseWelcomeTitle;

  /// No description provided for @phaseWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Prerequisites and firmware selection'**
  String get phaseWelcomeDescription;

  /// No description provided for @phaseNoticesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get phaseNoticesTitle;

  /// No description provided for @phaseNoticesDescription.
  ///
  /// In en, this message translates to:
  /// **'Important warnings before you start'**
  String get phaseNoticesDescription;

  /// No description provided for @phasePhysicalPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare Scooter'**
  String get phasePhysicalPrepTitle;

  /// No description provided for @phasePhysicalPrepDescription.
  ///
  /// In en, this message translates to:
  /// **'Open footwell, connect USB'**
  String get phasePhysicalPrepDescription;

  /// No description provided for @phaseMdbConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'MDB Connect'**
  String get phaseMdbConnectTitle;

  /// No description provided for @phaseMdbConnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Detect device and establish SSH'**
  String get phaseMdbConnectDescription;

  /// No description provided for @phaseResumeDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Previous Attempt'**
  String get phaseResumeDetectedTitle;

  /// No description provided for @phaseResumeDetectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Interrupted installation found'**
  String get phaseResumeDetectedDescription;

  /// No description provided for @phaseHealthCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Check'**
  String get phaseHealthCheckTitle;

  /// No description provided for @phaseHealthCheckDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify scooter readiness'**
  String get phaseHealthCheckDescription;

  /// No description provided for @phaseMdbToUmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare for Flashing'**
  String get phaseMdbToUmsTitle;

  /// No description provided for @phaseMdbToUmsDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure bootloader for flashing'**
  String get phaseMdbToUmsDescription;

  /// No description provided for @phaseMdbFlashTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash Image'**
  String get phaseMdbFlashTitle;

  /// No description provided for @phaseMdbFlashDescription.
  ///
  /// In en, this message translates to:
  /// **'Write firmware to MDB'**
  String get phaseMdbFlashDescription;

  /// No description provided for @phaseScooterPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Power'**
  String get phaseScooterPrepTitle;

  /// No description provided for @phaseScooterPrepDescription.
  ///
  /// In en, this message translates to:
  /// **'Disconnect CBB and AUX'**
  String get phaseScooterPrepDescription;

  /// No description provided for @phaseMdbBootTitle.
  ///
  /// In en, this message translates to:
  /// **'Reboot'**
  String get phaseMdbBootTitle;

  /// No description provided for @phaseMdbBootDescription.
  ///
  /// In en, this message translates to:
  /// **'Reconnect AUX, wait for boot'**
  String get phaseMdbBootDescription;

  /// No description provided for @phaseCbbReconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reconnect CBB & Battery'**
  String get phaseCbbReconnectTitle;

  /// No description provided for @phaseCbbReconnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Reconnect CBB for DBC flash'**
  String get phaseCbbReconnectDescription;

  /// No description provided for @phaseDbcPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Files'**
  String get phaseDbcPrepTitle;

  /// No description provided for @phaseDbcPrepDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload DBC image and tiles'**
  String get phaseDbcPrepDescription;

  /// No description provided for @phaseDbcFlashTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash Image'**
  String get phaseDbcFlashTitle;

  /// No description provided for @phaseDbcFlashDescription.
  ///
  /// In en, this message translates to:
  /// **'Autonomous DBC installation'**
  String get phaseDbcFlashDescription;

  /// No description provided for @phaseReconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get phaseReconnectTitle;

  /// No description provided for @phaseReconnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify DBC installation'**
  String get phaseReconnectDescription;

  /// No description provided for @phaseBluetoothPairingTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get phaseBluetoothPairingTitle;

  /// No description provided for @phaseBluetoothPairingDescription.
  ///
  /// In en, this message translates to:
  /// **'Pair phone or other devices'**
  String get phaseBluetoothPairingDescription;

  /// No description provided for @phaseFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get phaseFinishTitle;

  /// No description provided for @phaseFinishDescription.
  ///
  /// In en, this message translates to:
  /// **'Reassemble and welcome'**
  String get phaseFinishDescription;

  /// No description provided for @majorStepPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare'**
  String get majorStepPrepare;

  /// No description provided for @majorStepConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get majorStepConnect;

  /// No description provided for @majorStepMdbFlash.
  ///
  /// In en, this message translates to:
  /// **'Prepare MDB'**
  String get majorStepMdbFlash;

  /// No description provided for @majorStepPairing.
  ///
  /// In en, this message translates to:
  /// **'Pairing & Cards'**
  String get majorStepPairing;

  /// No description provided for @majorStepMdbInstall.
  ///
  /// In en, this message translates to:
  /// **'Install MDB'**
  String get majorStepMdbInstall;

  /// No description provided for @majorStepDbcFlash.
  ///
  /// In en, this message translates to:
  /// **'Install DBC'**
  String get majorStepDbcFlash;

  /// No description provided for @majorStepFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get majorStepFinish;

  /// No description provided for @majorStepSkippedSuffix.
  ///
  /// In en, this message translates to:
  /// **'skipped'**
  String get majorStepSkippedSuffix;

  /// No description provided for @welcomeHeading.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Librescoot Installer'**
  String get welcomeHeading;

  /// No description provided for @welcomeSubheading.
  ///
  /// In en, this message translates to:
  /// **'This wizard will guide you through installing Librescoot firmware on your scooter.'**
  String get welcomeSubheading;

  /// No description provided for @whatYouNeed.
  ///
  /// In en, this message translates to:
  /// **'What you need:'**
  String get whatYouNeed;

  /// No description provided for @prerequisiteScrewdriverPH2.
  ///
  /// In en, this message translates to:
  /// **'PH2 or H4 screwdriver for footwell screws'**
  String get prerequisiteScrewdriverPH2;

  /// No description provided for @prerequisiteScrewdriverFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat head or PH1 screwdriver for USB cable'**
  String get prerequisiteScrewdriverFlat;

  /// No description provided for @prerequisiteUsbCable.
  ///
  /// In en, this message translates to:
  /// **'USB cable (laptop to Mini-B)'**
  String get prerequisiteUsbCable;

  /// No description provided for @prerequisiteTime.
  ///
  /// In en, this message translates to:
  /// **'About 20 minutes'**
  String get prerequisiteTime;

  /// No description provided for @reliabilityWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get reliabilityWarningTitle;

  /// No description provided for @reliabilityWarningBody.
  ///
  /// In en, this message translates to:
  /// **'The flash takes several minutes and any USB drop or laptop sleep mid-flash leaves the MDB in an inconsistent state. Check:\n• A known-good USB cable, plugged in firmly at both ends. Flaky cables are the #1 cause of failed installs\n• Laptop on power, or fully charged. Battery saver / sleep can break the flash\n• Use a direct USB port, not a USB hub if possible\n• Don\'t unplug or move things around once the flash starts'**
  String get reliabilityWarningBody;

  /// No description provided for @noPowerCycleWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'DO NOT power-cycle anything during the install'**
  String get noPowerCycleWarningTitle;

  /// No description provided for @noPowerCycleWarningBody.
  ///
  /// In en, this message translates to:
  /// **'If something looks stuck, gives no feedback, or behaves oddly: stop and ask in Discord before doing anything else. Do not pull the AUX battery, disconnect the CBB, unplug USB, or restart the scooter or your laptop. The installer can recover from almost any state, as long as nothing interrupts it. Cutting power mid-flash is what bricks scooters.'**
  String get noPowerCycleWarningBody;

  /// No description provided for @downloadsFailedHeading.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the download server'**
  String get downloadsFailedHeading;

  /// No description provided for @downloadsFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Check the laptop\'s internet connection, then try again. You can also continue offline if you already have the firmware cached.'**
  String get downloadsFailedBody;

  /// No description provided for @downloadsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloadsRetry;

  /// No description provided for @noticesHeading.
  ///
  /// In en, this message translates to:
  /// **'Read this before continuing'**
  String get noticesHeading;

  /// No description provided for @noticesSubheading.
  ///
  /// In en, this message translates to:
  /// **'Two things that will save your install if you take them seriously.'**
  String get noticesSubheading;

  /// No description provided for @noticesAcknowledgeButton.
  ///
  /// In en, this message translates to:
  /// **'I\'ve read this, continue'**
  String get noticesAcknowledgeButton;

  /// No description provided for @noticesWaitingForDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloading firmware...'**
  String get noticesWaitingForDownloads;

  /// No description provided for @noticesContinueOfflineAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway (I\'ll have internet at the scooter)'**
  String get noticesContinueOfflineAnyway;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @elevationRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Administrator privileges required'**
  String get elevationRequiredTitle;

  /// No description provided for @elevationRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Librescoot Installer needs administrator privileges to write to the scooter\'s storage and configure the network interface. The elevation prompt was declined or could not be shown.\n\nClick Continue to dismiss this dialog and try again. If you keep declining the prompt, the installer cannot proceed.'**
  String get elevationRequiredBody;

  /// No description provided for @elevationNoticeWelcome.
  ///
  /// In en, this message translates to:
  /// **'When you click Start Installation, your system will ask you to allow administrator access. The installer needs it to write to the scooter\'s storage and configure networking.'**
  String get elevationNoticeWelcome;

  /// No description provided for @requestingAdminPrivileges.
  ///
  /// In en, this message translates to:
  /// **'Requesting administrator privileges...'**
  String get requestingAdminPrivileges;

  /// No description provided for @firmwareChannel.
  ///
  /// In en, this message translates to:
  /// **'Firmware Channel'**
  String get firmwareChannel;

  /// No description provided for @channelStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get channelStable;

  /// No description provided for @channelTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get channelTesting;

  /// No description provided for @channelNightly.
  ///
  /// In en, this message translates to:
  /// **'Nightly'**
  String get channelNightly;

  /// No description provided for @channelStableDesc.
  ///
  /// In en, this message translates to:
  /// **'Tested and reliable'**
  String get channelStableDesc;

  /// No description provided for @channelTestingDesc.
  ///
  /// In en, this message translates to:
  /// **'Latest features, may have rough edges'**
  String get channelTestingDesc;

  /// No description provided for @channelNightlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Built daily from main, for developers'**
  String get channelNightlyDesc;

  /// No description provided for @channelNoReleases.
  ///
  /// In en, this message translates to:
  /// **'No releases available'**
  String get channelNoReleases;

  /// No description provided for @loadingChannels.
  ///
  /// In en, this message translates to:
  /// **'Loading available channels...'**
  String get loadingChannels;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @selectRegion.
  ///
  /// In en, this message translates to:
  /// **'Select your region'**
  String get selectRegion;

  /// No description provided for @startInstallation.
  ///
  /// In en, this message translates to:
  /// **'Start Installation'**
  String get startInstallation;

  /// No description provided for @selectRegionError.
  ///
  /// In en, this message translates to:
  /// **'Select a region for offline maps'**
  String get selectRegionError;

  /// No description provided for @resolvingReleases.
  ///
  /// In en, this message translates to:
  /// **'Resolving releases...'**
  String get resolvingReleases;

  /// No description provided for @physicalPrepHeading.
  ///
  /// In en, this message translates to:
  /// **'Physical preparation'**
  String get physicalPrepHeading;

  /// No description provided for @physicalPrepSubheading.
  ///
  /// In en, this message translates to:
  /// **'Prepare your scooter for USB connection.'**
  String get physicalPrepSubheading;

  /// No description provided for @removeFootwellCover.
  ///
  /// In en, this message translates to:
  /// **'Remove footwell cover'**
  String get removeFootwellCover;

  /// No description provided for @removeFootwellCoverDesc.
  ///
  /// In en, this message translates to:
  /// **'Four screws to remove. PH2 Phillips from factory, H4 hex or Torx if serviced by a good shop.'**
  String get removeFootwellCoverDesc;

  /// No description provided for @unscrewUsbCable.
  ///
  /// In en, this message translates to:
  /// **'Unscrew USB cable from MDB'**
  String get unscrewUsbCable;

  /// No description provided for @unscrewUsbCableDesc.
  ///
  /// In en, this message translates to:
  /// **'Disconnect the internal DBC USB cable from the MDB. Use a flat head or PH1 screwdriver.'**
  String get unscrewUsbCableDesc;

  /// No description provided for @connectLaptopUsb.
  ///
  /// In en, this message translates to:
  /// **'Connect laptop USB cable'**
  String get connectLaptopUsb;

  /// No description provided for @connectLaptopUsbDesc.
  ///
  /// In en, this message translates to:
  /// **'Plug your USB cable into the MDB port and connect the other end to your laptop.'**
  String get connectLaptopUsbDesc;

  /// No description provided for @doneDetectDevice.
  ///
  /// In en, this message translates to:
  /// **'Done. Detect Device'**
  String get doneDetectDevice;

  /// No description provided for @connectingToMdb.
  ///
  /// In en, this message translates to:
  /// **'Connecting to MDB'**
  String get connectingToMdb;

  /// No description provided for @waitingForUsbDevice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for USB device...'**
  String get waitingForUsbDevice;

  /// No description provided for @waitingForRndis.
  ///
  /// In en, this message translates to:
  /// **'Waiting for USB device... Make sure your laptop is connected to the MDB via USB.'**
  String get waitingForRndis;

  /// No description provided for @checkingRndisDriver.
  ///
  /// In en, this message translates to:
  /// **'Checking RNDIS driver...'**
  String get checkingRndisDriver;

  /// No description provided for @configuringNetwork.
  ///
  /// In en, this message translates to:
  /// **'Configuring network...'**
  String get configuringNetwork;

  /// No description provided for @connectingSsh.
  ///
  /// In en, this message translates to:
  /// **'Connecting via SSH...'**
  String get connectingSsh;

  /// No description provided for @waitingForUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock the scooter to continue...'**
  String get waitingForUnlock;

  /// No description provided for @unfinishedInstallDetected.
  ///
  /// In en, this message translates to:
  /// **'Unfinished installation detected, continuing without unlock...'**
  String get unfinishedInstallDetected;

  /// No description provided for @waitingForBatteryData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for AUX/CBB battery data...'**
  String get waitingForBatteryData;

  /// No description provided for @resumeFoundHeading.
  ///
  /// In en, this message translates to:
  /// **'Interrupted installation found'**
  String get resumeFoundHeading;

  /// No description provided for @resumeFoundBody.
  ///
  /// In en, this message translates to:
  /// **'A previous installation on this scooter did not finish. Continuing clears what it left behind: the onboot script it armed is disarmed, and the services it stopped are started again. The installation then runs from the beginning; nothing is resumed.'**
  String get resumeFoundBody;

  /// No description provided for @resumeClearingLeftovers.
  ///
  /// In en, this message translates to:
  /// **'Clearing what the previous run left behind...'**
  String get resumeClearingLeftovers;

  /// No description provided for @resumeCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'The previous install could not be made safe: {error}\n\nNothing else will run until cleanup succeeds.'**
  String resumeCleanupFailed(String error);

  /// No description provided for @resumeFoundLastError.
  ///
  /// In en, this message translates to:
  /// **'Last recorded error:'**
  String get resumeFoundLastError;

  /// No description provided for @resumeRunningHeading.
  ///
  /// In en, this message translates to:
  /// **'An install is still running on the scooter'**
  String get resumeRunningHeading;

  /// No description provided for @resumeRunningBody.
  ///
  /// In en, this message translates to:
  /// **'The scooter is still working through the previous install. Nothing here touches it while it runs.'**
  String get resumeRunningBody;

  /// No description provided for @resumeRunningWait.
  ///
  /// In en, this message translates to:
  /// **'Wait for the scooter to finish. This carries on by itself afterwards.'**
  String get resumeRunningWait;

  /// No description provided for @resumeStageLabel.
  ///
  /// In en, this message translates to:
  /// **'Last step: {stage}'**
  String resumeStageLabel(String stage);

  /// No description provided for @resumeActorScooter.
  ///
  /// In en, this message translates to:
  /// **'on the scooter'**
  String get resumeActorScooter;

  /// No description provided for @resumeActorInstaller.
  ///
  /// In en, this message translates to:
  /// **'in the installer'**
  String get resumeActorInstaller;

  /// No description provided for @resumeLogHeading.
  ///
  /// In en, this message translates to:
  /// **'Last lines from the scooter\'s log'**
  String get resumeLogHeading;

  /// No description provided for @awaitingUnlockHeading.
  ///
  /// In en, this message translates to:
  /// **'Unlock your scooter'**
  String get awaitingUnlockHeading;

  /// No description provided for @awaitingUnlockDetail.
  ///
  /// In en, this message translates to:
  /// **'Unlock your scooter to continue. Use your keycard or paired phone.'**
  String get awaitingUnlockDetail;

  /// No description provided for @awaitingParkHeading.
  ///
  /// In en, this message translates to:
  /// **'Park your scooter'**
  String get awaitingParkHeading;

  /// No description provided for @awaitingParkDetail.
  ///
  /// In en, this message translates to:
  /// **'Park your scooter (flip the kickstand down) to continue.'**
  String get awaitingParkDetail;

  /// No description provided for @awaitingParkContinueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get awaitingParkContinueAnyway;

  /// No description provided for @lockingScooter.
  ///
  /// In en, this message translates to:
  /// **'Locking the scooter for flashing...'**
  String get lockingScooter;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @sshConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH connection failed: {error}. Check cable and retry.'**
  String sshConnectionFailed(String error);

  /// No description provided for @manualPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Root password required'**
  String get manualPasswordTitle;

  /// No description provided for @manualPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Could not determine the root password automatically. Enter the root password for this device.'**
  String get manualPasswordPrompt;

  /// No description provided for @manualPasswordPromptVersion.
  ///
  /// In en, this message translates to:
  /// **'Could not determine the root password automatically for firmware {version}. Enter the root password for this device.'**
  String manualPasswordPromptVersion(String version);

  /// No description provided for @manualPasswordPromptRetry.
  ///
  /// In en, this message translates to:
  /// **'That password didn\'t work. Try again ({remaining} attempts left).'**
  String manualPasswordPromptRetry(int remaining);

  /// No description provided for @manualPasswordFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get manualPasswordFieldLabel;

  /// No description provided for @manualPasswordSubmit.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get manualPasswordSubmit;

  /// No description provided for @untestedFirmwareHeading.
  ///
  /// In en, this message translates to:
  /// **'Untested firmware version'**
  String get untestedFirmwareHeading;

  /// No description provided for @untestedFirmwareBody.
  ///
  /// In en, this message translates to:
  /// **'Installation has not been tested on firmware versions older than 1.12.0 (yours: {version}). The installer should still work, but share any issues on the Librescoot Discord.'**
  String untestedFirmwareBody(String version);

  /// No description provided for @openLibrescootDiscord.
  ///
  /// In en, this message translates to:
  /// **'Open Librescoot Discord'**
  String get openLibrescootDiscord;

  /// No description provided for @healthCheckHeading.
  ///
  /// In en, this message translates to:
  /// **'Health check'**
  String get healthCheckHeading;

  /// No description provided for @verifyingReadiness.
  ///
  /// In en, this message translates to:
  /// **'Verifying scooter readiness...'**
  String get verifyingReadiness;

  /// No description provided for @incompleteImageStatus.
  ///
  /// In en, this message translates to:
  /// **'Incomplete firmware image detected. Re-flashing to recover...'**
  String get incompleteImageStatus;

  /// No description provided for @incompleteImageHeading.
  ///
  /// In en, this message translates to:
  /// **'Incomplete firmware image'**
  String get incompleteImageHeading;

  /// No description provided for @incompleteImageBody.
  ///
  /// In en, this message translates to:
  /// **'This scooter is running a minimal recovery image with no battery telemetry. This can happen when a previous install wrote the wrong image. Continue to re-flash the full firmware and finish setup.'**
  String get incompleteImageBody;

  /// No description provided for @reflashToRecover.
  ///
  /// In en, this message translates to:
  /// **'Re-flash to recover'**
  String get reflashToRecover;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @proceedAtOwnRisk.
  ///
  /// In en, this message translates to:
  /// **'Proceed at my own risk'**
  String get proceedAtOwnRisk;

  /// No description provided for @auxBatteryCharge.
  ///
  /// In en, this message translates to:
  /// **'AUX battery charge'**
  String get auxBatteryCharge;

  /// No description provided for @cbbStateOfHealth.
  ///
  /// In en, this message translates to:
  /// **'CBB state of health'**
  String get cbbStateOfHealth;

  /// No description provided for @cbbCharge.
  ///
  /// In en, this message translates to:
  /// **'CBB charge'**
  String get cbbCharge;

  /// No description provided for @mainBattery.
  ///
  /// In en, this message translates to:
  /// **'Main battery'**
  String get mainBattery;

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'present'**
  String get present;

  /// No description provided for @notPresent.
  ///
  /// In en, this message translates to:
  /// **'not present'**
  String get notPresent;

  /// No description provided for @riskAuxLow.
  ///
  /// In en, this message translates to:
  /// **'Low 12V battery could cause the MDB or DBC to shut down during flashing. The LED indicators may also fail. Close the seatbox with the main battery inserted and wait for the AUX battery to charge.'**
  String get riskAuxLow;

  /// No description provided for @riskCbbSoh.
  ///
  /// In en, this message translates to:
  /// **'Degraded CBB health may cause unreliable power delivery during flashing.'**
  String get riskCbbSoh;

  /// No description provided for @riskCbbCharge.
  ///
  /// In en, this message translates to:
  /// **'Low CBB charge increases the risk of power loss during the DBC flash. Close the seatbox with the main battery inserted and wait for the CBB to charge.'**
  String get riskCbbCharge;

  /// No description provided for @riskNoBattery.
  ///
  /// In en, this message translates to:
  /// **'Without the main battery, the 12V auxiliary battery will drain faster. The scooter may shut down during extended operations.'**
  String get riskNoBattery;

  /// No description provided for @openSeatbox.
  ///
  /// In en, this message translates to:
  /// **'Open Seatbox'**
  String get openSeatbox;

  /// No description provided for @configuringMdbBootloader.
  ///
  /// In en, this message translates to:
  /// **'Configuring MDB Bootloader'**
  String get configuringMdbBootloader;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get preparing;

  /// No description provided for @uploadingBootloaderTools.
  ///
  /// In en, this message translates to:
  /// **'Uploading bootloader tools...'**
  String get uploadingBootloaderTools;

  /// No description provided for @rebootingMdbUms.
  ///
  /// In en, this message translates to:
  /// **'Rebooting MDB into mass storage mode...'**
  String get rebootingMdbUms;

  /// No description provided for @waitingForUmsDevice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for UMS device...'**
  String get waitingForUmsDevice;

  /// No description provided for @readyToFlash.
  ///
  /// In en, this message translates to:
  /// **'Ready to begin flashing'**
  String get readyToFlash;

  /// No description provided for @readyToFlashHint.
  ///
  /// In en, this message translates to:
  /// **'The device is in flashing mode. You can mount the device to create manual backups before proceeding.'**
  String get readyToFlashHint;

  /// No description provided for @beginFlashing.
  ///
  /// In en, this message translates to:
  /// **'Begin flashing'**
  String get beginFlashing;

  /// No description provided for @flashingMdb.
  ///
  /// In en, this message translates to:
  /// **'Flashing MDB'**
  String get flashingMdb;

  /// No description provided for @flashingMdbSubheading.
  ///
  /// In en, this message translates to:
  /// **'Two-phase write: partitions first, boot sector last.'**
  String get flashingMdbSubheading;

  /// No description provided for @waitingForMdbFirmware.
  ///
  /// In en, this message translates to:
  /// **'Waiting for MDB firmware download...'**
  String get waitingForMdbFirmware;

  /// No description provided for @mdbFlashComplete.
  ///
  /// In en, this message translates to:
  /// **'MDB flash complete'**
  String get mdbFlashComplete;

  /// No description provided for @flashProgressMb.
  ///
  /// In en, this message translates to:
  /// **'{mb} MB written'**
  String flashProgressMb(String mb);

  /// No description provided for @flashProgressMbOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{mb} / {total} MB written'**
  String flashProgressMbOfTotal(String mb, String total);

  /// No description provided for @flashProgressEta.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s remaining'**
  String flashProgressEta(int minutes, int seconds);

  /// No description provided for @flashProgressBootSector.
  ///
  /// In en, this message translates to:
  /// **'Boot sector: {mb} MB written'**
  String flashProgressBootSector(String mb);

  /// No description provided for @scooterPrepHeading.
  ///
  /// In en, this message translates to:
  /// **'Scooter preparation'**
  String get scooterPrepHeading;

  /// No description provided for @scooterPrepSubheading.
  ///
  /// In en, this message translates to:
  /// **'MDB firmware has been written. Now prepare for reboot.'**
  String get scooterPrepSubheading;

  /// No description provided for @disconnectCbb.
  ///
  /// In en, this message translates to:
  /// **'Disconnect the CBB'**
  String get disconnectCbb;

  /// No description provided for @disconnectCbbDesc.
  ///
  /// In en, this message translates to:
  /// **'The main battery must already be removed before disconnecting CBB. Doing this out of order risks electrical damage.'**
  String get disconnectCbbDesc;

  /// No description provided for @disconnectAuxPole.
  ///
  /// In en, this message translates to:
  /// **'Disconnect one AUX pole'**
  String get disconnectAuxPole;

  /// No description provided for @disconnectAuxPoleDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove only the positive terminal (outer, red cable and post) to avoid reversing polarity. This cuts power to the MDB, so the USB connection drops.'**
  String get disconnectAuxPoleDesc;

  /// No description provided for @auxDisconnectWarning.
  ///
  /// In en, this message translates to:
  /// **'The USB connection will be lost when you disconnect AUX. This is expected. The installer will wait for the MDB to reboot.'**
  String get auxDisconnectWarning;

  /// No description provided for @doneCbbAuxDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Done, the scooter is restarting'**
  String get doneCbbAuxDisconnected;

  /// No description provided for @brakeResetHeading.
  ///
  /// In en, this message translates to:
  /// **'Restart the scooter'**
  String get brakeResetHeading;

  /// No description provided for @brakeResetIntro.
  ///
  /// In en, this message translates to:
  /// **'Squeeze and hold both brake levers. Every ten seconds, let go of the right one for about a second, then squeeze it again. After the fourth hold, just let go. The scooter cuts its own power and boots again.'**
  String get brakeResetIntro;

  /// No description provided for @brakeResetAfterNote.
  ///
  /// In en, this message translates to:
  /// **'The USB connection disappears the moment the power drops. That is expected, and the installer waits for the board to come back.'**
  String get brakeResetAfterNote;

  /// No description provided for @brakePacerStart.
  ///
  /// In en, this message translates to:
  /// **'Start the timer'**
  String get brakePacerStart;

  /// No description provided for @brakePacerStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get brakePacerStop;

  /// No description provided for @brakePacerRestart.
  ///
  /// In en, this message translates to:
  /// **'Run it again'**
  String get brakePacerRestart;

  /// No description provided for @brakePacerDone.
  ///
  /// In en, this message translates to:
  /// **'That is the pattern. Let go now. The scooter cuts its own power in a few seconds and comes back on its own.'**
  String get brakePacerDone;

  /// No description provided for @brakeDiagramBlipLegend.
  ///
  /// In en, this message translates to:
  /// **'Right lever released for about a second'**
  String get brakeDiagramBlipLegend;

  /// No description provided for @brakeDiagramEndLegend.
  ///
  /// In en, this message translates to:
  /// **'Just let go at {seconds} seconds'**
  String brakeDiagramEndLegend(int seconds);

  /// No description provided for @brakeBandBothHeld.
  ///
  /// In en, this message translates to:
  /// **'Left lever held down throughout'**
  String get brakeBandBothHeld;

  /// No description provided for @brakeBlipRight.
  ///
  /// In en, this message translates to:
  /// **'Right lever off, now'**
  String get brakeBlipRight;

  /// No description provided for @brakeLeftStaysHint.
  ///
  /// In en, this message translates to:
  /// **'The left lever stays squeezed the whole time.'**
  String get brakeLeftStaysHint;

  /// No description provided for @brakeLeadInLabel.
  ///
  /// In en, this message translates to:
  /// **'Squeeze both brakes in'**
  String get brakeLeadInLabel;

  /// No description provided for @brakeLeadInHint.
  ///
  /// In en, this message translates to:
  /// **'Step over to the handlebars and put a hand on each lever.'**
  String get brakeLeadInHint;

  /// No description provided for @brakeKeepHolding.
  ///
  /// In en, this message translates to:
  /// **'Hold both brakes'**
  String get brakeKeepHolding;

  /// No description provided for @scooterPrepManualFallback.
  ///
  /// In en, this message translates to:
  /// **'Or cut the power by hand'**
  String get scooterPrepManualFallback;

  /// No description provided for @deactivatingMainBattery.
  ///
  /// In en, this message translates to:
  /// **'Turning the main battery off...'**
  String get deactivatingMainBattery;

  /// No description provided for @waitingForMdbBoot.
  ///
  /// In en, this message translates to:
  /// **'Waiting for MDB boot'**
  String get waitingForMdbBoot;

  /// No description provided for @mdbBootRestartingNote.
  ///
  /// In en, this message translates to:
  /// **'The scooter is restarting on its own. This takes a minute or two.'**
  String get mdbBootRestartingNote;

  /// No description provided for @reconnectAuxPole.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the AUX pole'**
  String get reconnectAuxPole;

  /// No description provided for @reconnectAuxPoleDesc.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the positive AUX pole. The MDB will power on and boot into Librescoot.'**
  String get reconnectAuxPoleDesc;

  /// No description provided for @dbcLedHint.
  ///
  /// In en, this message translates to:
  /// **'DBC LED: orange = starting, green = booting, off = running'**
  String get dbcLedHint;

  /// No description provided for @mdbStillUms.
  ///
  /// In en, this message translates to:
  /// **'MDB still in UMS mode. Flash may not have taken. Retrying...'**
  String get mdbStillUms;

  /// No description provided for @waitingForMdbRestart.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the scooter to restart...'**
  String get waitingForMdbRestart;

  /// No description provided for @mdbDetectedNetwork.
  ///
  /// In en, this message translates to:
  /// **'MDB detected in network mode. Waiting for stable connection...'**
  String get mdbDetectedNetwork;

  /// No description provided for @pingStable.
  ///
  /// In en, this message translates to:
  /// **'Ping stable: {count}/10'**
  String pingStable(int count);

  /// No description provided for @waitingStableConnection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for stable connection...'**
  String get waitingStableConnection;

  /// No description provided for @stableConnectionStallHint.
  ///
  /// In en, this message translates to:
  /// **'Connection still unstable. USB ethernet may have lost its IP. On Linux, your NetworkManager may be fighting for the interface (try disabling IPv6). See log for details.'**
  String get stableConnectionStallHint;

  /// No description provided for @reconnectingSsh.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting SSH...'**
  String get reconnectingSsh;

  /// No description provided for @sshReconnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH reconnection failed: {error}'**
  String sshReconnectionFailed(String error);

  /// No description provided for @reconnectCbbHeading.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the CBB'**
  String get reconnectCbbHeading;

  /// No description provided for @verifyCbbConnection.
  ///
  /// In en, this message translates to:
  /// **'Verify CBB Connection'**
  String get verifyCbbConnection;

  /// No description provided for @verifyBatteryPresence.
  ///
  /// In en, this message translates to:
  /// **'Verify battery'**
  String get verifyBatteryPresence;

  /// No description provided for @turningMainBatteryOff.
  ///
  /// In en, this message translates to:
  /// **'Turning the main battery off first...'**
  String get turningMainBatteryOff;

  /// No description provided for @turningMainBatteryOn.
  ///
  /// In en, this message translates to:
  /// **'Turning the main battery back on...'**
  String get turningMainBatteryOn;

  /// No description provided for @checkingCbb.
  ///
  /// In en, this message translates to:
  /// **'Checking CBB...'**
  String get checkingCbb;

  /// No description provided for @waitingForCbb.
  ///
  /// In en, this message translates to:
  /// **'Waiting for CBB... ({attempts})'**
  String waitingForCbb(int attempts);

  /// No description provided for @cbbNotDetected.
  ///
  /// In en, this message translates to:
  /// **'CBB not detected. Check the connection.'**
  String get cbbNotDetected;

  /// No description provided for @cbbDetectionMayTakeMinutes.
  ///
  /// In en, this message translates to:
  /// **'This can take several minutes.'**
  String get cbbDetectionMayTakeMinutes;

  /// No description provided for @preparingDbcFlash.
  ///
  /// In en, this message translates to:
  /// **'Preparing DBC Flash'**
  String get preparingDbcFlash;

  /// No description provided for @waitingForDownloads.
  ///
  /// In en, this message translates to:
  /// **'Waiting for downloads to complete...'**
  String get waitingForDownloads;

  /// No description provided for @startingTrampoline.
  ///
  /// In en, this message translates to:
  /// **'Starting the on-device install script...'**
  String get startingTrampoline;

  /// No description provided for @uploadError.
  ///
  /// In en, this message translates to:
  /// **'Upload error: {error}'**
  String uploadError(String error);

  /// No description provided for @dbcReadyButton.
  ///
  /// In en, this message translates to:
  /// **'Begin flashing DBC'**
  String get dbcReadyButton;

  /// No description provided for @dbcFlashInProgress.
  ///
  /// In en, this message translates to:
  /// **'DBC Flash in Progress'**
  String get dbcFlashInProgress;

  /// No description provided for @dbcFlashSwapCablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Swap USB to the DBC'**
  String get dbcFlashSwapCablesTitle;

  /// No description provided for @dbcFlashSwapCablesDeadline.
  ///
  /// In en, this message translates to:
  /// **'The scooter is already waiting for the dashboard. It gives up after a few minutes, so do this now rather than later. No need to rush the screws.'**
  String get dbcFlashSwapCablesDeadline;

  /// No description provided for @disconnectUsbFromLaptop.
  ///
  /// In en, this message translates to:
  /// **'Unplug the laptop USB cable from the MDB'**
  String get disconnectUsbFromLaptop;

  /// No description provided for @disconnectUsbFromLaptopDesc.
  ///
  /// In en, this message translates to:
  /// **'Unplug the laptop USB cable from the MDB to free the port for the DBC cable.'**
  String get disconnectUsbFromLaptopDesc;

  /// No description provided for @reconnectDbcUsbToMdb.
  ///
  /// In en, this message translates to:
  /// **'Reconnect DBC USB cable to MDB'**
  String get reconnectDbcUsbToMdb;

  /// No description provided for @reconnectDbcUsbToMdbDesc.
  ///
  /// In en, this message translates to:
  /// **'Plug the internal DBC USB cable into the MDB port. Don\'t screw it in yet.'**
  String get reconnectDbcUsbToMdbDesc;

  /// No description provided for @ledBlinkerProgress.
  ///
  /// In en, this message translates to:
  /// **'Blinkers light up in turn'**
  String get ledBlinkerProgress;

  /// No description provided for @blinkerPosFL.
  ///
  /// In en, this message translates to:
  /// **'front left'**
  String get blinkerPosFL;

  /// No description provided for @blinkerPosFR.
  ///
  /// In en, this message translates to:
  /// **'front right'**
  String get blinkerPosFR;

  /// No description provided for @blinkerPosBR.
  ///
  /// In en, this message translates to:
  /// **'rear right'**
  String get blinkerPosBR;

  /// No description provided for @blinkerPosBL.
  ///
  /// In en, this message translates to:
  /// **'rear left'**
  String get blinkerPosBL;

  /// No description provided for @blinkerStepPrep.
  ///
  /// In en, this message translates to:
  /// **'Prepare DBC'**
  String get blinkerStepPrep;

  /// No description provided for @blinkerStepFlash.
  ///
  /// In en, this message translates to:
  /// **'Flash DBC'**
  String get blinkerStepFlash;

  /// No description provided for @blinkerStepRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart DBC'**
  String get blinkerStepRestart;

  /// No description provided for @blinkerStepMaps.
  ///
  /// In en, this message translates to:
  /// **'Upload maps'**
  String get blinkerStepMaps;

  /// No description provided for @verifyingDbcInstallation.
  ///
  /// In en, this message translates to:
  /// **'Verifying DBC installation'**
  String get verifyingDbcInstallation;

  /// No description provided for @reconnectUsbToLaptop.
  ///
  /// In en, this message translates to:
  /// **'Reconnect USB to laptop...'**
  String get reconnectUsbToLaptop;

  /// No description provided for @waitingForRndisDevice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for RNDIS device...'**
  String get waitingForRndisDevice;

  /// No description provided for @readingTrampolineStatus.
  ///
  /// In en, this message translates to:
  /// **'Reading trampoline status...'**
  String get readingTrampolineStatus;

  /// No description provided for @readingTrampolineStatusElapsed.
  ///
  /// In en, this message translates to:
  /// **'Reading trampoline status… ({elapsed}s)'**
  String readingTrampolineStatusElapsed(int elapsed);

  /// No description provided for @dbcFlashSuccessful.
  ///
  /// In en, this message translates to:
  /// **'DBC flash complete'**
  String get dbcFlashSuccessful;

  /// No description provided for @dbcInstallSuccessfulVersion.
  ///
  /// In en, this message translates to:
  /// **'DBC install successful, now running {version}'**
  String dbcInstallSuccessfulVersion(String version);

  /// No description provided for @dbcFlashFailed.
  ///
  /// In en, this message translates to:
  /// **'DBC flash failed: {message}'**
  String dbcFlashFailed(String message);

  /// No description provided for @dbcFlashError.
  ///
  /// In en, this message translates to:
  /// **'DBC Flash Error'**
  String get dbcFlashError;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @trampolineStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Trampoline status unknown. Check /data/trampoline.log on MDB.'**
  String get trampolineStatusUnknown;

  /// No description provided for @welcomeToLibrescoot.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Librescoot'**
  String get welcomeToLibrescoot;

  /// No description provided for @finalSteps.
  ///
  /// In en, this message translates to:
  /// **'Final steps:'**
  String get finalSteps;

  /// No description provided for @disconnectUsbFromLaptopFinal.
  ///
  /// In en, this message translates to:
  /// **'Unplug the laptop USB cable from the MDB'**
  String get disconnectUsbFromLaptopFinal;

  /// No description provided for @disconnectUsbFromLaptopFinalDesc.
  ///
  /// In en, this message translates to:
  /// **'Unplug the laptop USB cable from the MDB. The DBC cable goes back into that port next.'**
  String get disconnectUsbFromLaptopFinalDesc;

  /// No description provided for @reconnectDbcUsbCable.
  ///
  /// In en, this message translates to:
  /// **'Reconnect DBC USB cable'**
  String get reconnectDbcUsbCable;

  /// No description provided for @reconnectDbcUsbCableDesc.
  ///
  /// In en, this message translates to:
  /// **'Plug the internal DBC USB cable back into the MDB port, then gently screw it in to secure it.'**
  String get reconnectDbcUsbCableDesc;

  /// No description provided for @closeSeatboxAndFootwell.
  ///
  /// In en, this message translates to:
  /// **'Replace the footwell cover'**
  String get closeSeatboxAndFootwell;

  /// No description provided for @closeSeatboxAndFootwellDesc.
  ///
  /// In en, this message translates to:
  /// **'Clip the metal bars back in first, then fit the footwell cover and screw it down.'**
  String get closeSeatboxAndFootwellDesc;

  /// No description provided for @unlockScooter.
  ///
  /// In en, this message translates to:
  /// **'Unlock your scooter'**
  String get unlockScooter;

  /// No description provided for @unlockScooterDesc.
  ///
  /// In en, this message translates to:
  /// **'Use one of the keycards you registered, or unlock via Bluetooth.'**
  String get unlockScooterDesc;

  /// No description provided for @deletedCache.
  ///
  /// In en, this message translates to:
  /// **'Deleted {sizeMb} MB'**
  String deletedCache(String sizeMb);

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloadsFinished.
  ///
  /// In en, this message translates to:
  /// **'Downloads finished'**
  String get downloadsFinished;

  /// No description provided for @downloadsFinishedHint.
  ///
  /// In en, this message translates to:
  /// **'You can continue offline.'**
  String get downloadsFinishedHint;

  /// No description provided for @assetChipMdbArtifact.
  ///
  /// In en, this message translates to:
  /// **'MDB artifact'**
  String get assetChipMdbArtifact;

  /// No description provided for @assetChipDbcArtifact.
  ///
  /// In en, this message translates to:
  /// **'DBC artifact'**
  String get assetChipDbcArtifact;

  /// No description provided for @assetChipMdbImage.
  ///
  /// In en, this message translates to:
  /// **'MDB image'**
  String get assetChipMdbImage;

  /// No description provided for @assetChipDbcImage.
  ///
  /// In en, this message translates to:
  /// **'DBC image'**
  String get assetChipDbcImage;

  /// No description provided for @assetChipMaps.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get assetChipMaps;

  /// No description provided for @assetChipRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get assetChipRoutes;

  /// No description provided for @downloadMdbFirmware.
  ///
  /// In en, this message translates to:
  /// **'MDB Firmware'**
  String get downloadMdbFirmware;

  /// No description provided for @downloadDbcFirmware.
  ///
  /// In en, this message translates to:
  /// **'DBC Firmware'**
  String get downloadDbcFirmware;

  /// No description provided for @downloadMapTiles.
  ///
  /// In en, this message translates to:
  /// **'Map Tiles'**
  String get downloadMapTiles;

  /// No description provided for @downloadRoutingTiles.
  ///
  /// In en, this message translates to:
  /// **'Routing Tiles'**
  String get downloadRoutingTiles;

  /// No description provided for @safetyCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Safety check failed'**
  String get safetyCheckFailed;

  /// No description provided for @cannotFlashSafety.
  ///
  /// In en, this message translates to:
  /// **'Cannot flash this device due to safety concerns:'**
  String get cannotFlashSafety;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @confirmFlashTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm the flash target'**
  String get confirmFlashTargetTitle;

  /// No description provided for @confirmFlashTargetBody.
  ///
  /// In en, this message translates to:
  /// **'Windows could not confirm this disk is not your system disk. Check the target before flashing.'**
  String get confirmFlashTargetBody;

  /// No description provided for @confirmFlashTargetDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected Librescoot device'**
  String get confirmFlashTargetDetected;

  /// No description provided for @confirmFlashTargetOthers.
  ///
  /// In en, this message translates to:
  /// **'Other USB disks on this machine:'**
  String get confirmFlashTargetOthers;

  /// No description provided for @confirmFlashTargetInternalHidden.
  ///
  /// In en, this message translates to:
  /// **'Internal disks are not shown.'**
  String get confirmFlashTargetInternalHidden;

  /// No description provided for @confirmFlashTargetAccept.
  ///
  /// In en, this message translates to:
  /// **'Flash this disk'**
  String get confirmFlashTargetAccept;

  /// No description provided for @flashTargetNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Flashing cancelled: the target disk was not confirmed.'**
  String get flashTargetNotConfirmed;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @backingUpConfig.
  ///
  /// In en, this message translates to:
  /// **'Backing up device configuration...'**
  String get backingUpConfig;

  /// No description provided for @configBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Device configuration backed up'**
  String get configBackedUp;

  /// No description provided for @restoringConfig.
  ///
  /// In en, this message translates to:
  /// **'Restoring device configuration...'**
  String get restoringConfig;

  /// No description provided for @healthCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Health check failed: {error}'**
  String healthCheckFailed(String error);

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(String error);

  /// No description provided for @regionHint.
  ///
  /// In en, this message translates to:
  /// **'For offline maps and navigation support'**
  String get regionHint;

  /// No description provided for @skipOfflineMaps.
  ///
  /// In en, this message translates to:
  /// **'Skip offline maps'**
  String get skipOfflineMaps;

  /// No description provided for @bluetoothPairingHeading.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth pairing'**
  String get bluetoothPairingHeading;

  /// No description provided for @bluetoothPairingHint.
  ///
  /// In en, this message translates to:
  /// **'Pair your phone or other Bluetooth devices with the scooter.'**
  String get bluetoothPairingHint;

  /// No description provided for @bleMacLabel.
  ///
  /// In en, this message translates to:
  /// **'BLE address'**
  String get bleMacLabel;

  /// No description provided for @startPairing.
  ///
  /// In en, this message translates to:
  /// **'Start pairing'**
  String get startPairing;

  /// No description provided for @blePreparingRadio.
  ///
  /// In en, this message translates to:
  /// **'Restarting the Bluetooth radio, wait for this before pairing.'**
  String get blePreparingRadio;

  /// No description provided for @skipPairing.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipPairing;

  /// No description provided for @pairingActive.
  ///
  /// In en, this message translates to:
  /// **'Ready to pair'**
  String get pairingActive;

  /// No description provided for @pairingActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Search for the scooter in your phone\'s Bluetooth settings and pair it. Press Done when finished.'**
  String get pairingActiveHint;

  /// No description provided for @pairingDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get pairingDone;

  /// No description provided for @blePinHint.
  ///
  /// In en, this message translates to:
  /// **'Enter this PIN on your device to complete pairing.'**
  String get blePinHint;

  /// No description provided for @blePairedHeading.
  ///
  /// In en, this message translates to:
  /// **'Device paired'**
  String get blePairedHeading;

  /// No description provided for @blePairedHint.
  ///
  /// In en, this message translates to:
  /// **'To pair another device, disconnect this one on the device itself first. The scooter holds only one Bluetooth connection at a time.'**
  String get blePairedHint;

  /// No description provided for @bleLinkHeldHeading.
  ///
  /// In en, this message translates to:
  /// **'A device is holding the connection'**
  String get bleLinkHeldHeading;

  /// No description provided for @bleLinkHeldHint.
  ///
  /// In en, this message translates to:
  /// **'The scooter holds only one Bluetooth connection at a time, and it will not advertise while one is up. Disconnect it on the connected device before pairing a new one.'**
  String get bleLinkHeldHint;

  /// No description provided for @keycardLearningHeading.
  ///
  /// In en, this message translates to:
  /// **'Keycard setup'**
  String get keycardLearningHeading;

  /// No description provided for @keycardLearningBody.
  ///
  /// In en, this message translates to:
  /// **'Register the NFC cards you want to use to unlock and lock the scooter. Click Start, hold each card to the reader one by one, then click Done.'**
  String get keycardLearningBody;

  /// No description provided for @keycardLearnedAck.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 keycard registered} other{{count} keycards registered}}. Click Continue to finish, or Add more cards to register additional ones.'**
  String keycardLearnedAck(int count);

  /// No description provided for @keycardLearningTapped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No keycards tapped yet} one{1 keycard tapped} other{{count} keycards tapped}}'**
  String keycardLearningTapped(int count);

  /// No description provided for @keycardStartLearning.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get keycardStartLearning;

  /// No description provided for @keycardAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add more cards'**
  String get keycardAddMore;

  /// No description provided for @keycardLearningActive.
  ///
  /// In en, this message translates to:
  /// **'Learning mode active'**
  String get keycardLearningActive;

  /// No description provided for @keycardLearningActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Hold each card to the reader. Click Done when finished.'**
  String get keycardLearningActiveHint;

  /// No description provided for @keycardStopLearning.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get keycardStopLearning;

  /// No description provided for @keycardStartLearningFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start keycard learning: {error}'**
  String keycardStartLearningFailed(String error);

  /// No description provided for @keycardEntryAlreadyConfiguredHeading.
  ///
  /// In en, this message translates to:
  /// **'Keycards already configured'**
  String get keycardEntryAlreadyConfiguredHeading;

  /// No description provided for @keycardEntryAlreadyConfiguredBody.
  ///
  /// In en, this message translates to:
  /// **'{master, plural, =0{No master card is set} one{1 master card is set} other{{master} master cards are set}} and {authorized, plural, =0{no unlock cards are registered} one{1 unlock card is registered} other{{authorized} unlock cards are registered}}. You can keep this state, or wipe everything and start over.'**
  String keycardEntryAlreadyConfiguredBody(int master, int authorized);

  /// No description provided for @keycardEntryContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get keycardEntryContinueButton;

  /// No description provided for @keycardStartOverButton.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get keycardStartOverButton;

  /// No description provided for @keycardStartOverConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Wipe all keycards?'**
  String get keycardStartOverConfirmTitle;

  /// No description provided for @keycardStartOverConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes the master card and every registered unlock card on the scooter. You\'ll need to re-register them. Continue?'**
  String get keycardStartOverConfirmBody;

  /// No description provided for @keycardStartOverConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Wipe everything'**
  String get keycardStartOverConfirmYes;

  /// No description provided for @keycardStartOverConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get keycardStartOverConfirmNo;

  /// No description provided for @keycardCardsStageContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get keycardCardsStageContinueButton;

  /// No description provided for @keycardCardsStageAddMasterButton.
  ///
  /// In en, this message translates to:
  /// **'Add master card (advanced)'**
  String get keycardCardsStageAddMasterButton;

  /// No description provided for @keycardMasterStageHeading.
  ///
  /// In en, this message translates to:
  /// **'Add master card'**
  String get keycardMasterStageHeading;

  /// No description provided for @keycardMasterStageWarningHeading.
  ///
  /// In en, this message translates to:
  /// **'The master card cannot unlock the scooter'**
  String get keycardMasterStageWarningHeading;

  /// No description provided for @keycardMasterStageWarningBody.
  ///
  /// In en, this message translates to:
  /// **'The master card manages your other keycards. It cannot unlock the scooter, and none of the cards you just registered can serve as a master. Use a separate, unused card.'**
  String get keycardMasterStageWarningBody;

  /// No description provided for @keycardMasterStageHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the master card to the reader.'**
  String get keycardMasterStageHint;

  /// No description provided for @keycardCardDuplicateToast.
  ///
  /// In en, this message translates to:
  /// **'This card is already registered.'**
  String get keycardCardDuplicateToast;

  /// No description provided for @keycardMasterStageRejectedToast.
  ///
  /// In en, this message translates to:
  /// **'This card is already registered as an unlock card.'**
  String get keycardMasterStageRejectedToast;

  /// No description provided for @keycardMasterStageSaveFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Could not save master card. Try again.'**
  String get keycardMasterStageSaveFailedToast;

  /// No description provided for @keycardMasterStageLearnedToast.
  ///
  /// In en, this message translates to:
  /// **'Master card registered.'**
  String get keycardMasterStageLearnedToast;

  /// No description provided for @keycardMasterStageSkipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get keycardMasterStageSkipButton;

  /// No description provided for @keycardSimulateTapButton.
  ///
  /// In en, this message translates to:
  /// **'[DRY RUN] Simulate tap'**
  String get keycardSimulateTapButton;

  /// No description provided for @keycardSimulateMasterTapButton.
  ///
  /// In en, this message translates to:
  /// **'[DRY RUN] Simulate master tap'**
  String get keycardSimulateMasterTapButton;

  /// No description provided for @keycardSimulateRejectedTapButton.
  ///
  /// In en, this message translates to:
  /// **'[DRY RUN] Simulate already-authorized rejection'**
  String get keycardSimulateRejectedTapButton;

  /// No description provided for @installationContinuesInNewWindow.
  ///
  /// In en, this message translates to:
  /// **'Installation continues in the new window'**
  String get installationContinuesInNewWindow;

  /// No description provided for @youCanCloseThisWindow.
  ///
  /// In en, this message translates to:
  /// **'You can close this window.'**
  String get youCanCloseThisWindow;

  /// No description provided for @cannotQuitWhileFlashing.
  ///
  /// In en, this message translates to:
  /// **'Cannot quit while flashing is in progress'**
  String get cannotQuitWhileFlashing;

  /// No description provided for @showLogTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show log'**
  String get showLogTooltip;

  /// No description provided for @retryMdbConnect.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryMdbConnect;

  /// No description provided for @retryMdbToUms.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryMdbToUms;

  /// No description provided for @showLog.
  ///
  /// In en, this message translates to:
  /// **'Show Log'**
  String get showLog;

  /// No description provided for @retryMdbFlash.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryMdbFlash;

  /// No description provided for @retryMdbBoot.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryMdbBoot;

  /// No description provided for @retryDbcPrep.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryDbcPrep;

  /// No description provided for @retryVerification.
  ///
  /// In en, this message translates to:
  /// **'Retry verification'**
  String get retryVerification;

  /// No description provided for @retryDbcFlash.
  ///
  /// In en, this message translates to:
  /// **'Retry DBC flash'**
  String get retryDbcFlash;

  /// No description provided for @skipToFinish.
  ///
  /// In en, this message translates to:
  /// **'Skip to finish'**
  String get skipToFinish;

  /// No description provided for @skipKeycardSetup.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipKeycardSetup;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// No description provided for @keepCachedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Keep cached downloads'**
  String get keepCachedDownloads;

  /// No description provided for @phaseInstallPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Install Plan'**
  String get phaseInstallPlanTitle;

  /// No description provided for @phaseInstallPlanDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose what happens to each board'**
  String get phaseInstallPlanDescription;

  /// No description provided for @phaseMdbArtifactTitle.
  ///
  /// In en, this message translates to:
  /// **'MDB Update'**
  String get phaseMdbArtifactTitle;

  /// No description provided for @phaseMdbArtifactDescription.
  ///
  /// In en, this message translates to:
  /// **'Install the firmware artifact'**
  String get phaseMdbArtifactDescription;

  /// No description provided for @majorStepMdbUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade MDB'**
  String get majorStepMdbUpgrade;

  /// No description provided for @majorStepDbcUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade DBC'**
  String get majorStepDbcUpgrade;

  /// No description provided for @installPlanHeading.
  ///
  /// In en, this message translates to:
  /// **'What should the installer do?'**
  String get installPlanHeading;

  /// No description provided for @installPlanIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick an action for each board. Target version: {version}'**
  String installPlanIntro(String version);

  /// No description provided for @boardMdb.
  ///
  /// In en, this message translates to:
  /// **'MDB (main board)'**
  String get boardMdb;

  /// No description provided for @boardDbc.
  ///
  /// In en, this message translates to:
  /// **'DBC (dashboard)'**
  String get boardDbc;

  /// No description provided for @boardVersionCurrent.
  ///
  /// In en, this message translates to:
  /// **'Currently {version}'**
  String boardVersionCurrent(String version);

  /// No description provided for @boardVersionLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen running {version}'**
  String boardVersionLastSeen(String version);

  /// No description provided for @previousRunSummary.
  ///
  /// In en, this message translates to:
  /// **'Last install finished {when}, leaving {version}'**
  String previousRunSummary(String when, String version);

  /// No description provided for @boardVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Version unknown'**
  String get boardVersionUnknown;

  /// No description provided for @actionUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get actionUpgrade;

  /// No description provided for @actionUpgradeDetail.
  ///
  /// In en, this message translates to:
  /// **'Keeps settings, keycards, maps and trips'**
  String get actionUpgradeDetail;

  /// No description provided for @actionCleanInstall.
  ///
  /// In en, this message translates to:
  /// **'Clean install'**
  String get actionCleanInstall;

  /// No description provided for @actionCleanInstallDetail.
  ///
  /// In en, this message translates to:
  /// **'Erases settings, keycards, maps and trips'**
  String get actionCleanInstallDetail;

  /// No description provided for @actionUpgradeDetailDbc.
  ///
  /// In en, this message translates to:
  /// **'Keeps the offline maps'**
  String get actionUpgradeDetailDbc;

  /// No description provided for @actionCleanInstallDetailDbc.
  ///
  /// In en, this message translates to:
  /// **'Erases the offline maps only'**
  String get actionCleanInstallDetailDbc;

  /// No description provided for @actionLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave alone'**
  String get actionLeave;

  /// No description provided for @actionLeaveDetail.
  ///
  /// In en, this message translates to:
  /// **'This board is not touched'**
  String get actionLeaveDetail;

  /// No description provided for @upgradeBlockedNotLibrescoot.
  ///
  /// In en, this message translates to:
  /// **'Upgrade needs Librescoot to already be installed'**
  String get upgradeBlockedNotLibrescoot;

  /// No description provided for @upgradeBlockedStateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Upgrade needs a known version on this board'**
  String get upgradeBlockedStateUnknown;

  /// No description provided for @upgradeBlockedMinimalImage.
  ///
  /// In en, this message translates to:
  /// **'This board is running a bootstrap image and has to be installed'**
  String get upgradeBlockedMinimalImage;

  /// No description provided for @upgradeBlockedNoMender.
  ///
  /// In en, this message translates to:
  /// **'This board has no update client, so it can only be reinstalled'**
  String get upgradeBlockedNoMender;

  /// No description provided for @planTilesNeedDbcHandoff.
  ///
  /// In en, this message translates to:
  /// **'Refreshing map tiles needs the DBC cable swap, even with the DBC left alone'**
  String get planTilesNeedDbcHandoff;

  /// No description provided for @actionLeaveBlockedStockMdb.
  ///
  /// In en, this message translates to:
  /// **'A stock main board has to be installed before anything else can be done'**
  String get actionLeaveBlockedStockMdb;

  /// No description provided for @planDbcNeedsLibrescootMdb.
  ///
  /// In en, this message translates to:
  /// **'The dashboard can only be reached through the MDB, and the tools that reach it are part of Librescoot. Install the MDB in this run, or leave the dashboard alone.'**
  String get planDbcNeedsLibrescootMdb;

  /// No description provided for @planNothingToDo.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected. Pick at least one action to continue.'**
  String get planNothingToDo;

  /// No description provided for @releaseMissingAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'This release cannot be installed'**
  String get releaseMissingAssetsTitle;

  /// No description provided for @releaseMissingAssetsBody.
  ///
  /// In en, this message translates to:
  /// **'The {tag} release does not publish everything the installer needs: {assets}. Go back and pick a different channel, or wait for a release that has them.'**
  String releaseMissingAssetsBody(String tag, String assets);

  /// No description provided for @assetMdbArtifact.
  ///
  /// In en, this message translates to:
  /// **'the MDB firmware artifact'**
  String get assetMdbArtifact;

  /// No description provided for @assetDbcArtifact.
  ///
  /// In en, this message translates to:
  /// **'the DBC firmware artifact'**
  String get assetDbcArtifact;

  /// No description provided for @assetMdbImage.
  ///
  /// In en, this message translates to:
  /// **'the MDB system image'**
  String get assetMdbImage;

  /// No description provided for @assetDbcImage.
  ///
  /// In en, this message translates to:
  /// **'the DBC system image'**
  String get assetDbcImage;

  /// No description provided for @artifactStaging.
  ///
  /// In en, this message translates to:
  /// **'Uploading firmware artifact...'**
  String get artifactStaging;

  /// No description provided for @artifactInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing firmware ({percent}%)'**
  String artifactInstalling(int percent);

  /// No description provided for @artifactVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying installed version...'**
  String get artifactVerifying;

  /// No description provided for @waitingForDbcUpload.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the dashboard transfer to finish...'**
  String get waitingForDbcUpload;

  /// No description provided for @artifactStillMinimal.
  ///
  /// In en, this message translates to:
  /// **'The MDB came back on the bootstrap image, so the firmware artifact did not take. Retry, or write the full image instead.'**
  String get artifactStillMinimal;

  /// No description provided for @artifactVersionMismatch.
  ///
  /// In en, this message translates to:
  /// **'The MDB still reports {found} after the reboot, not {expected}. The install was rolled back, so nothing was changed. Retry, or write the full image instead.'**
  String artifactVersionMismatch(String found, String expected);

  /// No description provided for @artifactInstallFailedHeading.
  ///
  /// In en, this message translates to:
  /// **'Firmware install failed'**
  String get artifactInstallFailedHeading;

  /// No description provided for @artifactStagingInBackground.
  ///
  /// In en, this message translates to:
  /// **'Finishing the firmware install...'**
  String get artifactStagingInBackground;

  /// No description provided for @artifactNoneDownloaded.
  ///
  /// In en, this message translates to:
  /// **'No firmware artifact was downloaded for this board.'**
  String get artifactNoneDownloaded;

  /// No description provided for @dbcImageMissing.
  ///
  /// In en, this message translates to:
  /// **'The DBC system image this plan needs is missing.'**
  String get dbcImageMissing;

  /// No description provided for @artifactRebootTimeout.
  ///
  /// In en, this message translates to:
  /// **'The MDB did not come back after the reboot.'**
  String get artifactRebootTimeout;

  /// No description provided for @artifactPreflightNoMender.
  ///
  /// In en, this message translates to:
  /// **'This board has no update client, so it cannot take a firmware artifact.'**
  String get artifactPreflightNoMender;

  /// No description provided for @artifactPreflightOtaBusy.
  ///
  /// In en, this message translates to:
  /// **'The scooter is running its own update right now ({status}). Let it finish and reboot, then retry.'**
  String artifactPreflightOtaBusy(String status);

  /// No description provided for @artifactPreflightNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough space in /data: {freeMiB} MiB free, {neededMiB} MiB needed.'**
  String artifactPreflightNoSpace(int freeMiB, int neededMiB);

  /// No description provided for @artifactRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get artifactRetry;

  /// No description provided for @artifactFallBackToFullImage.
  ///
  /// In en, this message translates to:
  /// **'Write the full image instead'**
  String get artifactFallBackToFullImage;

  /// No description provided for @fallBackWipeTitle.
  ///
  /// In en, this message translates to:
  /// **'This erases the scooter\'s data'**
  String get fallBackWipeTitle;

  /// No description provided for @fallBackWipeBody.
  ///
  /// In en, this message translates to:
  /// **'Writing the full image reformats the data partition. Settings, paired keycards, offline maps and trip history are all lost, and the scooter comes back as if it were new. The upgrade you started would have kept them.\n\nRetrying the firmware artifact keeps the data. Only write the full image if the artifact keeps failing.'**
  String get fallBackWipeBody;

  /// No description provided for @fallBackWipeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Erase and write the full image'**
  String get fallBackWipeConfirm;

  /// No description provided for @dbcCleanInstallButton.
  ///
  /// In en, this message translates to:
  /// **'Erase the DBC and install from scratch'**
  String get dbcCleanInstallButton;

  /// No description provided for @dbcCleanInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'This erases the DBC'**
  String get dbcCleanInstallTitle;

  /// No description provided for @dbcCleanInstallBody.
  ///
  /// In en, this message translates to:
  /// **'The dashboard\'s last known version is only what the main board saw the last time the two were powered together, so a board the plan treated as upgradable may have no update client at all. Installing from scratch writes the bootstrap image first, which reformats the DBC\'s data partition and loses its offline maps. Anything on the main board, including settings, paired keycards and trip history, is untouched.\n\nThis needs another cable swap: the installer stages the files, you screw the dashboard cable back onto the main board, and the rest runs unattended.'**
  String get dbcCleanInstallBody;

  /// No description provided for @dbcCleanInstallConfirm.
  ///
  /// In en, this message translates to:
  /// **'Erase and install the DBC'**
  String get dbcCleanInstallConfirm;

  /// No description provided for @firmwareVersionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Firmware: {version}'**
  String firmwareVersionDisplay(String version);

  /// No description provided for @openSeatboxButton.
  ///
  /// In en, this message translates to:
  /// **'Open seatbox'**
  String get openSeatboxButton;

  /// No description provided for @reconnectCbbStep.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the CBB'**
  String get reconnectCbbStep;

  /// No description provided for @reconnectCbbStepDesc.
  ///
  /// In en, this message translates to:
  /// **'Plug the CBB cable back into the connector in the footwell. Without the CBB, the MDB could shut down during flashing.'**
  String get reconnectCbbStepDesc;

  /// No description provided for @mainBatteryMissingHeading.
  ///
  /// In en, this message translates to:
  /// **'No main battery detected'**
  String get mainBatteryMissingHeading;

  /// No description provided for @mainBatteryMissingHint.
  ///
  /// In en, this message translates to:
  /// **'The dashboard flash draws from the main battery. Put it back in the seatbox before continuing.'**
  String get mainBatteryMissingHint;

  /// No description provided for @cbbDetected.
  ///
  /// In en, this message translates to:
  /// **'CBB detected'**
  String get cbbDetected;

  /// No description provided for @batteryDetected.
  ///
  /// In en, this message translates to:
  /// **'Battery detected'**
  String get batteryDetected;

  /// No description provided for @proceedWithoutCbb.
  ///
  /// In en, this message translates to:
  /// **'I understand the risks, proceed anyway'**
  String get proceedWithoutCbb;

  /// No description provided for @checkingCbbAndBattery.
  ///
  /// In en, this message translates to:
  /// **'Checking CBB and battery...'**
  String get checkingCbbAndBattery;

  /// No description provided for @waitingForUsbDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Waiting for USB disconnect...'**
  String get waitingForUsbDisconnect;

  /// No description provided for @dbcFlashDurationHeadline.
  ///
  /// In en, this message translates to:
  /// **'The DBC flash can take 10 to 20 minutes.'**
  String get dbcFlashDurationHeadline;

  /// No description provided for @finishHandoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Finishing the install…'**
  String get finishHandoverTitle;

  /// No description provided for @finishHandoverBody.
  ///
  /// In en, this message translates to:
  /// **'Stay with the scooter until it unlocks itself. Then you can unplug the USB cable.'**
  String get finishHandoverBody;

  /// No description provided for @networkConfigNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'macOS is asking for permission to change network settings. Click Allow in the system dialog, then hit Retry.'**
  String get networkConfigNeedsPermission;

  /// No description provided for @waitingForMdb.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the MDB...'**
  String get waitingForMdb;

  /// No description provided for @dbcFlashAllDone.
  ///
  /// In en, this message translates to:
  /// **'Continue to the last step'**
  String get dbcFlashAllDone;

  /// No description provided for @dbcFlashSequence.
  ///
  /// In en, this message translates to:
  /// **'From here the scooter carries on by itself: it writes the image to the dashboard, restarts it and copies the maps over. Progress is shown on the dashboard screen. Stay with the scooter until one of these two things happens.'**
  String get dbcFlashSequence;

  /// No description provided for @dbcFlashDoNotDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Do not disconnect USB or power while this runs.'**
  String get dbcFlashDoNotDisconnect;

  /// No description provided for @dbcFlashDoneSignal.
  ///
  /// In en, this message translates to:
  /// **'Done: the scooter unlocks itself. That is the signal, there is nothing else to wait for.'**
  String get dbcFlashDoneSignal;

  /// No description provided for @dbcFlashFailSignal.
  ///
  /// In en, this message translates to:
  /// **'Failed: the dashboard LED blinks red and the hazards come on. Plug USB back into the MDB and fetch the log here.'**
  String get dbcFlashFailSignal;

  /// No description provided for @dbcFlashLedIsTheSignal.
  ///
  /// In en, this message translates to:
  /// **'The LED on the dashboard is the error signal: if it blinks red, something has gone wrong.'**
  String get dbcFlashLedIsTheSignal;

  /// No description provided for @dbcFlashSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'LED blinking red: reconnect USB and fetch the log'**
  String get dbcFlashSomethingWrong;

  /// No description provided for @phaseKeycardSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Keycard Setup'**
  String get phaseKeycardSetupTitle;

  /// No description provided for @phaseKeycardSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Register your keycards'**
  String get phaseKeycardSetupDescription;

  /// No description provided for @usingLocalFirmwareImages.
  ///
  /// In en, this message translates to:
  /// **'Using local firmware images'**
  String get usingLocalFirmwareImages;

  /// No description provided for @mdbDetectedUmsSkipping.
  ///
  /// In en, this message translates to:
  /// **'MDB detected in UMS mode. Skipping to flash.'**
  String get mdbDetectedUmsSkipping;

  /// No description provided for @verifyingBootloaderConfig.
  ///
  /// In en, this message translates to:
  /// **'Verifying bootloader config...'**
  String get verifyingBootloaderConfig;

  /// No description provided for @umsNotDetectedTimeout.
  ///
  /// In en, this message translates to:
  /// **'UMS device not detected within 60s. MDB may have booted back into Linux.'**
  String get umsNotDetectedTimeout;

  /// No description provided for @waitingForDevicePath.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device path...'**
  String get waitingForDevicePath;

  /// No description provided for @noDevicePathFound.
  ///
  /// In en, this message translates to:
  /// **'No device path found. Check USB connection and retry.'**
  String get noDevicePathFound;

  /// No description provided for @mdbDisconnectedFlashingDbc.
  ///
  /// In en, this message translates to:
  /// **'MDB disconnected. Flashing DBC autonomously...'**
  String get mdbDisconnectedFlashingDbc;

  /// No description provided for @mdbReconnectedVerifying.
  ///
  /// In en, this message translates to:
  /// **'MDB reconnected. Verifying...'**
  String get mdbReconnectedVerifying;

  /// No description provided for @logDebugShell.
  ///
  /// In en, this message translates to:
  /// **'Log & Debug Shell'**
  String get logDebugShell;

  /// No description provided for @internalError.
  ///
  /// In en, this message translates to:
  /// **'Internal error: {error}'**
  String internalError(String error);

  /// No description provided for @copyLog.
  ///
  /// In en, this message translates to:
  /// **'Copy log'**
  String get copyLog;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyToClipboard;

  /// No description provided for @logFilePath.
  ///
  /// In en, this message translates to:
  /// **'Log file: {path}'**
  String logFilePath(String path);

  /// No description provided for @revealLogFile.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get revealLogFile;

  /// No description provided for @debugCommandHint.
  ///
  /// In en, this message translates to:
  /// **'Run a command in the installer context...'**
  String get debugCommandHint;

  /// No description provided for @mbOnDisk.
  ///
  /// In en, this message translates to:
  /// **'{size} MB on disk'**
  String mbOnDisk(String size);

  /// No description provided for @beforeImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get beforeImageLabel;

  /// No description provided for @afterImageLabel.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get afterImageLabel;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @gettingStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get gettingStartedTitle;

  /// No description provided for @gettingStartedOpenMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Open the menu'**
  String get gettingStartedOpenMenuTitle;

  /// No description provided for @gettingStartedOpenMenuDesc.
  ///
  /// In en, this message translates to:
  /// **'While parked, give two short pulls in a row on the left brake lever. Use the brake levers to scroll and select; the on-screen hints show what each lever does.'**
  String get gettingStartedOpenMenuDesc;

  /// No description provided for @gettingStartedDriveMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick menu while riding'**
  String get gettingStartedDriveMenuTitle;

  /// No description provided for @gettingStartedDriveMenuDesc.
  ///
  /// In en, this message translates to:
  /// **'The seatbox button only opens the quick menu in drive mode (kickstand up). Hold the seatbox button to open the on-screen quick menu; the entries cycle automatically every second while you keep holding. Release to stop on the highlighted entry, then press once briefly within about a second to confirm.'**
  String get gettingStartedDriveMenuDesc;

  /// No description provided for @gettingStartedUpdateModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Update Mode again later'**
  String get gettingStartedUpdateModeTitle;

  /// No description provided for @gettingStartedUpdateModeDesc.
  ///
  /// In en, this message translates to:
  /// **'To install map or routing updates, change settings, or copy other files: turn the scooter on, open the menu, go to Settings → System → Update Mode…, then connect a computer via USB.'**
  String get gettingStartedUpdateModeDesc;

  /// No description provided for @gettingStartedNavigationTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigate to a destination'**
  String get gettingStartedNavigationTitle;

  /// No description provided for @gettingStartedNavigationDesc.
  ///
  /// In en, this message translates to:
  /// **'Open the menu → Navigation → Enter Address…, Recent Destinations or Saved Locations. Use Save Current Location to keep the spot you\'re at for later, and Save to Favorites on a recent entry to keep it long-term.'**
  String get gettingStartedNavigationDesc;

  /// No description provided for @gettingStartedFooter.
  ///
  /// In en, this message translates to:
  /// **'More on librescoot.org and in the handbook.'**
  String get gettingStartedFooter;

  /// No description provided for @gettingStartedLinkWebsite.
  ///
  /// In en, this message translates to:
  /// **'librescoot.org'**
  String get gettingStartedLinkWebsite;

  /// No description provided for @gettingStartedLinkHandbook.
  ///
  /// In en, this message translates to:
  /// **'Handbook'**
  String get gettingStartedLinkHandbook;

  /// No description provided for @substepWaitRndis.
  ///
  /// In en, this message translates to:
  /// **'Wait for MDB (RNDIS) on USB'**
  String get substepWaitRndis;

  /// No description provided for @substepConfigureNetwork.
  ///
  /// In en, this message translates to:
  /// **'Configure network'**
  String get substepConfigureNetwork;

  /// No description provided for @substepConnectSsh.
  ///
  /// In en, this message translates to:
  /// **'Connect SSH'**
  String get substepConnectSsh;

  /// No description provided for @substepDisableHazards.
  ///
  /// In en, this message translates to:
  /// **'Disable alarm and auto-standby'**
  String get substepDisableHazards;

  /// No description provided for @substepReadStatus.
  ///
  /// In en, this message translates to:
  /// **'Read trampoline status'**
  String get substepReadStatus;

  /// No description provided for @elapsedSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s elapsed'**
  String elapsedSeconds(int seconds);

  /// No description provided for @reconnectTimeoutHeading.
  ///
  /// In en, this message translates to:
  /// **'Taking longer than usual'**
  String get reconnectTimeoutHeading;

  /// No description provided for @reconnectTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'It has been {minutes} min without the MDB coming back as an RNDIS device. The DBC\'s first boot can take a while (partition resize, map install). You can keep waiting, or restart / skip below.'**
  String reconnectTimeoutBody(int minutes);

  /// No description provided for @usbDeviceCurrentlyDetected.
  ///
  /// In en, this message translates to:
  /// **'Currently detected USB device'**
  String get usbDeviceCurrentlyDetected;

  /// No description provided for @usbDeviceNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get usbDeviceNone;

  /// No description provided for @collectingUsbInfo.
  ///
  /// In en, this message translates to:
  /// **'Collecting USB device info…'**
  String get collectingUsbInfo;

  /// No description provided for @usbInfoUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'USB info collection not supported on this platform.'**
  String get usbInfoUnsupportedPlatform;

  /// No description provided for @usbInfoCollectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to collect USB info'**
  String get usbInfoCollectFailed;

  /// No description provided for @upgradeDowngradeWarning.
  ///
  /// In en, this message translates to:
  /// **'This is older than what the board runs now. Upgrade keeps settings, keycards, maps and trips, and older services may not read data a newer version wrote. Install fresh if anything misbehaves afterwards.'**
  String get upgradeDowngradeWarning;

  /// No description provided for @upgradeChannelSwitchWarning.
  ///
  /// In en, this message translates to:
  /// **'This is a different release channel to what the board runs now. Upgrade keeps settings, keycards, maps and trips, which the other channel\'s services may not read the same way. Install fresh if anything misbehaves afterwards.'**
  String get upgradeChannelSwitchWarning;

  /// No description provided for @tightenDbcCable.
  ///
  /// In en, this message translates to:
  /// **'Screw the dashboard cable down'**
  String get tightenDbcCable;

  /// No description provided for @tightenDbcCableDesc.
  ///
  /// In en, this message translates to:
  /// **'The internal dashboard USB cable is already plugged into the MDB. Tighten the screws now.'**
  String get tightenDbcCableDesc;

  /// No description provided for @finalRide.
  ///
  /// In en, this message translates to:
  /// **'Ride off'**
  String get finalRide;

  /// No description provided for @finalRideDesc.
  ///
  /// In en, this message translates to:
  /// **'The scooter unlocked itself when the install finished. If it did not, use one of the keycards you set up, or unlock over Bluetooth.'**
  String get finalRideDesc;

  /// No description provided for @notEnoughDiskSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough disk space: {needed} more is required. Free up space and try again.'**
  String notEnoughDiskSpace(String needed);

  /// No description provided for @keycardFinishCards.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get keycardFinishCards;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

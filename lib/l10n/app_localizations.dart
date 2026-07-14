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
  /// **'Resume'**
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

  /// No description provided for @phaseBatteryRemovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Off Battery'**
  String get phaseBatteryRemovalTitle;

  /// No description provided for @phaseBatteryRemovalDescription.
  ///
  /// In en, this message translates to:
  /// **'Open seatbox, remove main battery'**
  String get phaseBatteryRemovalDescription;

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

  /// No description provided for @phaseDashboardPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Prep'**
  String get phaseDashboardPrepTitle;

  /// No description provided for @phaseDashboardPrepDescription.
  ///
  /// In en, this message translates to:
  /// **'Pair, enroll keycards, stage DBC image'**
  String get phaseDashboardPrepDescription;

  /// No description provided for @phaseDbcSwapAndFlashTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash Image'**
  String get phaseDbcSwapAndFlashTitle;

  /// No description provided for @phaseDbcSwapAndFlashDescription.
  ///
  /// In en, this message translates to:
  /// **'Swap cable; scooter flashes the DBC'**
  String get phaseDbcSwapAndFlashDescription;

  /// No description provided for @phaseReconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get phaseReconnectTitle;

  /// No description provided for @phaseReconnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify after an interrupted DBC flash'**
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
  /// **'Flash MDB'**
  String get majorStepMdbFlash;

  /// No description provided for @majorStepMdbPrep.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Prep'**
  String get majorStepMdbPrep;

  /// No description provided for @majorStepDbcFlash.
  ///
  /// In en, this message translates to:
  /// **'Flash DBC'**
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
  /// **'The flash takes several minutes and any USB drop or laptop sleep mid-flash leaves the MDB in an inconsistent state. Please check:\n• A known-good USB cable, plugged in firmly at both ends. Flaky cables are the #1 cause of failed installs\n• Laptop on power, or fully charged. Battery saver / sleep can break the flash\n• Use a direct USB port, not a USB hub if possible\n• Don\'t unplug or move things around once the flash starts'**
  String get reliabilityWarningBody;

  /// No description provided for @noPowerCycleWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'DO NOT power-cycle anything during the install'**
  String get noPowerCycleWarningTitle;

  /// No description provided for @noPowerCycleWarningBody.
  ///
  /// In en, this message translates to:
  /// **'If something looks stuck, gives no feedback, or behaves weirdly: PAUSE and ask in Discord first. Do NOT pull the AUX battery, do NOT disconnect the CBB, do NOT yank USB, do NOT reboot the scooter or your laptop. The installer can recover from almost any state. But only if you don\'t intervene. Power-cycling mid-flash is what bricks scooters.'**
  String get noPowerCycleWarningBody;

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
  /// **'Please select a region for offline maps'**
  String get selectRegionError;

  /// No description provided for @resolvingReleases.
  ///
  /// In en, this message translates to:
  /// **'Resolving releases...'**
  String get resolvingReleases;

  /// No description provided for @physicalPrepHeading.
  ///
  /// In en, this message translates to:
  /// **'Physical Preparation'**
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
  /// **'Disconnect the internal DBC USB cable from the MDB board. Use a flat head or PH1 screwdriver.'**
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
  /// **'A previous installation on this scooter did not finish. The unlock step has been skipped and disabled services were re-enabled. Continuing will pick the installation up where it left off.'**
  String get resumeFoundBody;

  /// No description provided for @resumeFoundLastError.
  ///
  /// In en, this message translates to:
  /// **'Last recorded error:'**
  String get resumeFoundLastError;

  /// No description provided for @awaitingUnlockHeading.
  ///
  /// In en, this message translates to:
  /// **'Unlock your scooter'**
  String get awaitingUnlockHeading;

  /// No description provided for @awaitingUnlockDetail.
  ///
  /// In en, this message translates to:
  /// **'Please unlock your scooter to continue. Use your keycard or paired phone.'**
  String get awaitingUnlockDetail;

  /// No description provided for @awaitingParkHeading.
  ///
  /// In en, this message translates to:
  /// **'Park your scooter'**
  String get awaitingParkHeading;

  /// No description provided for @awaitingParkDetail.
  ///
  /// In en, this message translates to:
  /// **'Please park your scooter (flip the kickstand down) to continue.'**
  String get awaitingParkDetail;

  /// No description provided for @awaitingParkContinueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get awaitingParkContinueAnyway;

  /// No description provided for @lockingScooter.
  ///
  /// In en, this message translates to:
  /// **'Locking scooter for flashing...'**
  String get lockingScooter;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected!'**
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
  /// **'Installation has not been tested on firmware versions older than 1.12.0 (yours: {version}). The installer should still work, but please share any issues on the Librescoot Discord.'**
  String untestedFirmwareBody(String version);

  /// No description provided for @openLibrescootDiscord.
  ///
  /// In en, this message translates to:
  /// **'Open Librescoot Discord'**
  String get openLibrescootDiscord;

  /// No description provided for @healthCheckHeading.
  ///
  /// In en, this message translates to:
  /// **'Health Check'**
  String get healthCheckHeading;

  /// No description provided for @verifyingReadiness.
  ///
  /// In en, this message translates to:
  /// **'Verifying scooter readiness...'**
  String get verifyingReadiness;

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
  /// **'Low 12V battery could cause the MDB or DBC to shut down during flashing. The LED indicators may also fail. Close the seatbox with the main battery inserted and wait for it to charge.'**
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

  /// No description provided for @deactivateMainBatteryHeading.
  ///
  /// In en, this message translates to:
  /// **'Main Battery'**
  String get deactivateMainBatteryHeading;

  /// No description provided for @deactivateMainBattery.
  ///
  /// In en, this message translates to:
  /// **'Deactivate main battery'**
  String get deactivateMainBattery;

  /// No description provided for @deactivateMainBatteryStep.
  ///
  /// In en, this message translates to:
  /// **'The scooter will switch off the main battery. You do not need to take it out of the seatbox.'**
  String get deactivateMainBatteryStep;

  /// No description provided for @deactivatingMainBattery.
  ///
  /// In en, this message translates to:
  /// **'Switching off the main battery...'**
  String get deactivatingMainBattery;

  /// No description provided for @mainBatteryDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Main battery switched off'**
  String get mainBatteryDeactivated;

  /// No description provided for @mainBatteryAlreadyOff.
  ///
  /// In en, this message translates to:
  /// **'Main battery is already off'**
  String get mainBatteryAlreadyOff;

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
  /// **'MDB flash complete!'**
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
  /// **'Scooter Preparation'**
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
  /// **'The main battery must already be switched off (the previous step) before disconnecting the CBB. Failure to follow this order risks electrical damage.'**
  String get disconnectCbbDesc;

  /// No description provided for @disconnectAuxPole.
  ///
  /// In en, this message translates to:
  /// **'Disconnect one AUX pole'**
  String get disconnectAuxPole;

  /// No description provided for @disconnectAuxPoleDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove ONLY the positive pole (outermost, the red cable and pole) to avoid risk of inverting polarity. This will remove power from the MDB; the USB connection will disappear.'**
  String get disconnectAuxPoleDesc;

  /// No description provided for @auxDisconnectWarning.
  ///
  /// In en, this message translates to:
  /// **'The USB connection will be lost when you disconnect AUX. This is expected. The installer will wait for the MDB to reboot.'**
  String get auxDisconnectWarning;

  /// No description provided for @doneCbbAuxDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Done. I disconnected CBB and AUX'**
  String get doneCbbAuxDisconnected;

  /// No description provided for @waitingForMdbBoot.
  ///
  /// In en, this message translates to:
  /// **'Waiting for MDB Boot'**
  String get waitingForMdbBoot;

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

  /// No description provided for @reconnectCbbFirstDesc.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the CBB first, while the AUX is still disconnected, so it connects to a powered-down scooter.'**
  String get reconnectCbbFirstDesc;

  /// No description provided for @cbbBeforeAuxWarning.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the CBB before the AUX. Connecting the CBB while the scooter is powered risks the main battery being live.'**
  String get cbbBeforeAuxWarning;

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
  /// **'Verify CBB and main battery'**
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
  /// **'CBB not detected. Please check the connection.'**
  String get cbbNotDetected;

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

  /// No description provided for @finishStepsAboveToContinue.
  ///
  /// In en, this message translates to:
  /// **'Finish the steps above to continue.'**
  String get finishStepsAboveToContinue;

  /// No description provided for @startingTrampoline.
  ///
  /// In en, this message translates to:
  /// **'Starting trampoline script...'**
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

  /// No description provided for @verifyingDbcInstallation.
  ///
  /// In en, this message translates to:
  /// **'Verifying DBC Installation'**
  String get verifyingDbcInstallation;

  /// No description provided for @reconnectUsbToLaptop.
  ///
  /// In en, this message translates to:
  /// **'Unplug the DBC cable from the MDB and plug the laptop back in...'**
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
  /// **'DBC flash successful!'**
  String get dbcFlashSuccessful;

  /// No description provided for @dbcAlreadyCurrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard already up to date'**
  String get dbcAlreadyCurrentTitle;

  /// No description provided for @dbcAlreadyCurrentBody.
  ///
  /// In en, this message translates to:
  /// **'The dashboard (DBC) already runs Librescoot {version}. Flash it again anyway?'**
  String dbcAlreadyCurrentBody(String version);

  /// No description provided for @dbcAlreadyCurrentReflash.
  ///
  /// In en, this message translates to:
  /// **'Flash again'**
  String get dbcAlreadyCurrentReflash;

  /// No description provided for @dbcAlreadyCurrentSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip DBC flash'**
  String get dbcAlreadyCurrentSkip;

  /// No description provided for @dbcPrepComplete.
  ///
  /// In en, this message translates to:
  /// **'DBC image ready to flash'**
  String get dbcPrepComplete;

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
  /// **'Trampoline status unknown. Check /data/installer/trampoline.log on the MDB.'**
  String get trampolineStatusUnknown;

  /// No description provided for @welcomeToLibrescoot.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Librescoot!'**
  String get welcomeToLibrescoot;

  /// No description provided for @finalSteps.
  ///
  /// In en, this message translates to:
  /// **'Final steps:'**
  String get finalSteps;

  /// No description provided for @disconnectUsbFromLaptopFinal.
  ///
  /// In en, this message translates to:
  /// **'Unplug the laptop from the MDB'**
  String get disconnectUsbFromLaptopFinal;

  /// No description provided for @disconnectUsbFromLaptopFinalDesc.
  ///
  /// In en, this message translates to:
  /// **'If the laptop is still plugged into the MDB port, unplug it now. The DBC cable goes back into that port.'**
  String get disconnectUsbFromLaptopFinalDesc;

  /// No description provided for @reconnectDbcUsbCable.
  ///
  /// In en, this message translates to:
  /// **'Reconnect and screw down the DBC USB cable'**
  String get reconnectDbcUsbCable;

  /// No description provided for @reconnectDbcUsbCableDesc.
  ///
  /// In en, this message translates to:
  /// **'Plug the internal DBC USB cable back into the MDB port if it isn\'t already, then gently screw it in to secure it.'**
  String get reconnectDbcUsbCableDesc;

  /// No description provided for @screwDbcUsbCable.
  ///
  /// In en, this message translates to:
  /// **'Screw the DBC USB cable down'**
  String get screwDbcUsbCable;

  /// No description provided for @screwDbcUsbCableDesc.
  ///
  /// In en, this message translates to:
  /// **'The DBC cable is already plugged into the MDB port; gently screw it in to secure it.'**
  String get screwDbcUsbCableDesc;

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
  /// **'Use a keycard or paired phone if you set one up, or the button in the app.'**
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

  /// No description provided for @safetyCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Safety Check Failed'**
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
  /// **'Bluetooth Pairing'**
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
  /// **'Unlock and start pairing'**
  String get startPairing;

  /// No description provided for @skipPairing.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipPairing;

  /// No description provided for @pairingActive.
  ///
  /// In en, this message translates to:
  /// **'Scooter unlocked'**
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

  /// No description provided for @bleAlreadyConnected.
  ///
  /// In en, this message translates to:
  /// **'A device is already connected'**
  String get bleAlreadyConnected;

  /// No description provided for @bleAlreadyConnectedHint.
  ///
  /// In en, this message translates to:
  /// **'You can pair additional devices or press Done to continue.'**
  String get bleAlreadyConnectedHint;

  /// No description provided for @keycardLearningHeading.
  ///
  /// In en, this message translates to:
  /// **'Keycard Setup'**
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
  /// **'WARNING: master card is NOT for unlocking'**
  String get keycardMasterStageWarningHeading;

  /// No description provided for @keycardMasterStageWarningBody.
  ///
  /// In en, this message translates to:
  /// **'The master card is used to manage other keycards. It CANNOT unlock the scooter. Do NOT use any of the cards you just registered as unlock cards. Use a separate, fresh card.'**
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
  /// **'Could not save master card: write failed.'**
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

  /// No description provided for @librescootFirmwareDetected.
  ///
  /// In en, this message translates to:
  /// **'Librescoot firmware detected'**
  String get librescootFirmwareDetected;

  /// No description provided for @skipMdbReflash.
  ///
  /// In en, this message translates to:
  /// **'Skip MDB reflash'**
  String get skipMdbReflash;

  /// No description provided for @keepCurrentMdbFirmware.
  ///
  /// In en, this message translates to:
  /// **'Keep current MDB firmware'**
  String get keepCurrentMdbFirmware;

  /// No description provided for @skipDbcFlashOption.
  ///
  /// In en, this message translates to:
  /// **'Skip DBC flash'**
  String get skipDbcFlashOption;

  /// No description provided for @onlyFlashMdbSkipDbc.
  ///
  /// In en, this message translates to:
  /// **'Only flash MDB, skip DBC entirely'**
  String get onlyFlashMdbSkipDbc;

  /// No description provided for @firmwareVersionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Firmware: {version}'**
  String firmwareVersionDisplay(String version);

  /// No description provided for @reconnectCbbStep.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the CBB'**
  String get reconnectCbbStep;

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

  /// No description provided for @finishRebootingTitle.
  ///
  /// In en, this message translates to:
  /// **'Rebooting scooter…'**
  String get finishRebootingTitle;

  /// No description provided for @finishRebootingBody.
  ///
  /// In en, this message translates to:
  /// **'The MDB is rebooting; the USB connection will drop by itself. No need to touch the cable yet.'**
  String get finishRebootingBody;

  /// No description provided for @networkConfigNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'macOS is asking for permission to change network settings. Click Allow in the system dialog, then hit Retry.'**
  String get networkConfigNeedsPermission;

  /// No description provided for @dbcWalkAwayHeadline.
  ///
  /// In en, this message translates to:
  /// **'Swap done. The install is now running on its own.'**
  String get dbcWalkAwayHeadline;

  /// No description provided for @dbcWalkAwayBody.
  ///
  /// In en, this message translates to:
  /// **'Leave the scooter alone while it flashes the dashboard. This can take 10 to 20 minutes.'**
  String get dbcWalkAwayBody;

  /// No description provided for @dbcWalkAwayDashboardLit.
  ///
  /// In en, this message translates to:
  /// **'The dashboard will turn on and off several times during the install; that\'s normal. The install is only finished when the keycard LED on the dashboard blinks green: then screw the DBC cable down, close everything up, and unlock the scooter.'**
  String get dbcWalkAwayDashboardLit;

  /// No description provided for @dbcWalkAwayFailure.
  ///
  /// In en, this message translates to:
  /// **'If the scooter flashes its hazard lights or the keycard LED blinks red instead, something went wrong: plug the laptop back into the MDB.'**
  String get dbcWalkAwayFailure;

  /// No description provided for @dbcWalkAwayDashboardLitButton.
  ///
  /// In en, this message translates to:
  /// **'The LED is blinking green'**
  String get dbcWalkAwayDashboardLitButton;

  /// No description provided for @dbcWalkAwayWentWrongButton.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get dbcWalkAwayWentWrongButton;

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

  /// No description provided for @logDebugShell.
  ///
  /// In en, this message translates to:
  /// **'Log & Debug Shell'**
  String get logDebugShell;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyToClipboard;

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

  /// No description provided for @tileLabelMaps.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get tileLabelMaps;

  /// No description provided for @tileLabelRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get tileLabelRoutes;
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

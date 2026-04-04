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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LibreScoot Installer'**
  String get appTitle;

  /// No description provided for @elevationWarning.
  ///
  /// In en, this message translates to:
  /// **'Running without administrator privileges. Some operations may fail.'**
  String get elevationWarning;

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
  /// **'Remove Battery'**
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

  /// No description provided for @welcomeHeading.
  ///
  /// In en, this message translates to:
  /// **'Welcome to LibreScoot Installer'**
  String get welcomeHeading;

  /// No description provided for @welcomeSubheading.
  ///
  /// In en, this message translates to:
  /// **'This wizard will guide you through installing LibreScoot firmware on your scooter.'**
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
  /// **'About 45 minutes'**
  String get prerequisiteTime;

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

  /// No description provided for @channelLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest: {date}'**
  String channelLatest(String date);

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
  /// **'Four screws to remove — PH2 Phillips from factory, H4 hex or Torx if serviced by a good shop.'**
  String get removeFootwellCoverDesc;

  /// No description provided for @removeFootwellCoverImage.
  ///
  /// In en, this message translates to:
  /// **'[Photo: footwell cover with screw locations highlighted]'**
  String get removeFootwellCoverImage;

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

  /// No description provided for @unscrewUsbCableImage.
  ///
  /// In en, this message translates to:
  /// **'[Photo: USB Mini-B connector on MDB, close-up]'**
  String get unscrewUsbCableImage;

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
  /// **'Done — Detect Device'**
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

  /// No description provided for @installingRndisDriver.
  ///
  /// In en, this message translates to:
  /// **'Installing RNDIS driver...'**
  String get installingRndisDriver;

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

  /// No description provided for @batteryRemovalHeading.
  ///
  /// In en, this message translates to:
  /// **'Battery Removal'**
  String get batteryRemovalHeading;

  /// No description provided for @seatboxOpening.
  ///
  /// In en, this message translates to:
  /// **'Seatbox is opening...'**
  String get seatboxOpening;

  /// No description provided for @seatboxOpeningDesc.
  ///
  /// In en, this message translates to:
  /// **'The seatbox will open automatically.'**
  String get seatboxOpeningDesc;

  /// No description provided for @removeMainBattery.
  ///
  /// In en, this message translates to:
  /// **'Remove the main battery'**
  String get removeMainBattery;

  /// No description provided for @removeMainBatteryDesc.
  ///
  /// In en, this message translates to:
  /// **'Lift the main battery (Fahrakku) out of the seatbox.'**
  String get removeMainBatteryDesc;

  /// No description provided for @openSeatbox.
  ///
  /// In en, this message translates to:
  /// **'Open Seatbox'**
  String get openSeatbox;

  /// No description provided for @mainBatteryAlreadyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Main battery already removed'**
  String get mainBatteryAlreadyRemoved;

  /// No description provided for @openingSeatbox.
  ///
  /// In en, this message translates to:
  /// **'Opening seatbox...'**
  String get openingSeatbox;

  /// No description provided for @waitingForBatteryRemoval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for battery removal...'**
  String get waitingForBatteryRemoval;

  /// No description provided for @batteryRemoved.
  ///
  /// In en, this message translates to:
  /// **'Battery removed!'**
  String get batteryRemoved;

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

  /// No description provided for @noDevicePath.
  ///
  /// In en, this message translates to:
  /// **'Error: no device path available'**
  String get noDevicePath;

  /// No description provided for @mdbFlashComplete.
  ///
  /// In en, this message translates to:
  /// **'MDB flash complete!'**
  String get mdbFlashComplete;

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
  /// **'The main battery must already be removed before disconnecting CBB. Failure to follow this order risks electrical damage.'**
  String get disconnectCbbDesc;

  /// No description provided for @disconnectAuxPole.
  ///
  /// In en, this message translates to:
  /// **'Disconnect one AUX pole'**
  String get disconnectAuxPole;

  /// No description provided for @disconnectAuxPoleDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove ONLY the positive pole (outermost, color-coded red) to avoid risk of inverting polarity. This will remove power from the MDB — the USB connection will disappear.'**
  String get disconnectAuxPoleDesc;

  /// No description provided for @disconnectAuxPoleImage.
  ///
  /// In en, this message translates to:
  /// **'[Photo: AUX battery poles, positive (red/outermost) highlighted]'**
  String get disconnectAuxPoleImage;

  /// No description provided for @auxDisconnectWarning.
  ///
  /// In en, this message translates to:
  /// **'The USB connection will be lost when you disconnect AUX. This is expected — the installer will wait for the MDB to reboot.'**
  String get auxDisconnectWarning;

  /// No description provided for @doneCbbAuxDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Done — I disconnected CBB and AUX'**
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
  /// **'Reconnect the positive AUX pole. The MDB will power on and boot into LibreScoot.'**
  String get reconnectAuxPoleDesc;

  /// No description provided for @dbcLedHint.
  ///
  /// In en, this message translates to:
  /// **'DBC LED: orange = starting, green = booting, off = running'**
  String get dbcLedHint;

  /// No description provided for @mdbStillUms.
  ///
  /// In en, this message translates to:
  /// **'MDB still in UMS mode — flash may not have taken. Retrying...'**
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
  /// **'Reconnect CBB & Battery'**
  String get reconnectCbbHeading;

  /// No description provided for @reconnectCbb.
  ///
  /// In en, this message translates to:
  /// **'Reinstall the main battery and reconnect the CBB'**
  String get reconnectCbb;

  /// No description provided for @reconnectCbbDesc.
  ///
  /// In en, this message translates to:
  /// **'Put the main battery back in the seatbox and plug the CBB cable back in. The scooter needs full power for the DBC flash.'**
  String get reconnectCbbDesc;

  /// No description provided for @verifyCbbConnection.
  ///
  /// In en, this message translates to:
  /// **'Verify CBB Connection'**
  String get verifyCbbConnection;

  /// No description provided for @checkingCbb.
  ///
  /// In en, this message translates to:
  /// **'Checking CBB...'**
  String get checkingCbb;

  /// No description provided for @cbbConnected.
  ///
  /// In en, this message translates to:
  /// **'CBB connected!'**
  String get cbbConnected;

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

  /// No description provided for @dbcFlashInProgress.
  ///
  /// In en, this message translates to:
  /// **'DBC Flash in Progress'**
  String get dbcFlashInProgress;

  /// No description provided for @disconnectUsbFromLaptop.
  ///
  /// In en, this message translates to:
  /// **'Disconnect USB from laptop'**
  String get disconnectUsbFromLaptop;

  /// No description provided for @disconnectUsbFromLaptopDesc.
  ///
  /// In en, this message translates to:
  /// **'Unplug the USB cable from your laptop.'**
  String get disconnectUsbFromLaptopDesc;

  /// No description provided for @reconnectDbcUsbToMdb.
  ///
  /// In en, this message translates to:
  /// **'Reconnect DBC USB cable to MDB'**
  String get reconnectDbcUsbToMdb;

  /// No description provided for @reconnectDbcUsbToMdbDesc.
  ///
  /// In en, this message translates to:
  /// **'Screw the internal DBC USB cable back into the MDB port.'**
  String get reconnectDbcUsbToMdbDesc;

  /// No description provided for @mdbFlashingDbcAutonomously.
  ///
  /// In en, this message translates to:
  /// **'The MDB is now flashing the DBC autonomously.'**
  String get mdbFlashingDbcAutonomously;

  /// No description provided for @watchLightsForProgress.
  ///
  /// In en, this message translates to:
  /// **'Watch the scooter lights for progress:'**
  String get watchLightsForProgress;

  /// No description provided for @ledFrontRingPulse.
  ///
  /// In en, this message translates to:
  /// **'Front ring breathing'**
  String get ledFrontRingPulse;

  /// No description provided for @ledFrontRingPulseMeaning.
  ///
  /// In en, this message translates to:
  /// **'Preparing DBC (configuring bootloader, waiting for connection)'**
  String get ledFrontRingPulseMeaning;

  /// No description provided for @ledFrontRingSolid.
  ///
  /// In en, this message translates to:
  /// **'Front ring glows briefly'**
  String get ledFrontRingSolid;

  /// No description provided for @ledFrontRingSolidMeaning.
  ///
  /// In en, this message translates to:
  /// **'Flash complete — success!'**
  String get ledFrontRingSolidMeaning;

  /// No description provided for @disconnectCbbImage.
  ///
  /// In en, this message translates to:
  /// **'[Photo: CBB connector location under seat]'**
  String get disconnectCbbImage;

  /// No description provided for @ledBlinkerProgress.
  ///
  /// In en, this message translates to:
  /// **'Blinkers glow progressively'**
  String get ledBlinkerProgress;

  /// No description provided for @ledBlinkerProgressMeaning.
  ///
  /// In en, this message translates to:
  /// **'Flash progress — dim = done, breathing = active segment'**
  String get ledBlinkerProgressMeaning;

  /// No description provided for @ledBootGreen.
  ///
  /// In en, this message translates to:
  /// **'Boot LED green'**
  String get ledBootGreen;

  /// No description provided for @ledBootGreenMeaning.
  ///
  /// In en, this message translates to:
  /// **'Success — reconnect laptop'**
  String get ledBootGreenMeaning;

  /// No description provided for @ledRearLightSolid.
  ///
  /// In en, this message translates to:
  /// **'Rear light glows briefly'**
  String get ledRearLightSolid;

  /// No description provided for @ledRearLightSolidMeaning.
  ///
  /// In en, this message translates to:
  /// **'Error — reconnect laptop to see log'**
  String get ledRearLightSolidMeaning;

  /// No description provided for @bootLedGreenReconnect.
  ///
  /// In en, this message translates to:
  /// **'Boot LED is green — Reconnect Laptop'**
  String get bootLedGreenReconnect;

  /// No description provided for @rearLightCheckError.
  ///
  /// In en, this message translates to:
  /// **'Rear light on — Check Error'**
  String get rearLightCheckError;

  /// No description provided for @verifyingDbcInstallation.
  ///
  /// In en, this message translates to:
  /// **'Verifying DBC Installation'**
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

  /// No description provided for @dbcFlashSuccessful.
  ///
  /// In en, this message translates to:
  /// **'DBC flash successful!'**
  String get dbcFlashSuccessful;

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

  /// No description provided for @welcomeToLibreScoot.
  ///
  /// In en, this message translates to:
  /// **'Welcome to LibreScoot!'**
  String get welcomeToLibreScoot;

  /// No description provided for @finalSteps.
  ///
  /// In en, this message translates to:
  /// **'Final steps:'**
  String get finalSteps;

  /// No description provided for @disconnectUsbFromLaptopFinal.
  ///
  /// In en, this message translates to:
  /// **'Disconnect USB from laptop'**
  String get disconnectUsbFromLaptopFinal;

  /// No description provided for @disconnectUsbFromLaptopFinalDesc.
  ///
  /// In en, this message translates to:
  /// **'Unplug the USB cable from your laptop.'**
  String get disconnectUsbFromLaptopFinalDesc;

  /// No description provided for @reconnectDbcUsbCable.
  ///
  /// In en, this message translates to:
  /// **'Reconnect DBC USB cable'**
  String get reconnectDbcUsbCable;

  /// No description provided for @reconnectDbcUsbCableDesc.
  ///
  /// In en, this message translates to:
  /// **'Screw the internal DBC USB cable back into MDB.'**
  String get reconnectDbcUsbCableDesc;

  /// No description provided for @insertMainBattery.
  ///
  /// In en, this message translates to:
  /// **'Insert main battery'**
  String get insertMainBattery;

  /// No description provided for @insertMainBatteryDesc.
  ///
  /// In en, this message translates to:
  /// **'Place the main battery back into the seatbox.'**
  String get insertMainBatteryDesc;

  /// No description provided for @closeSeatboxAndFootwell.
  ///
  /// In en, this message translates to:
  /// **'Close seatbox and footwell'**
  String get closeSeatboxAndFootwell;

  /// No description provided for @closeSeatboxAndFootwellDesc.
  ///
  /// In en, this message translates to:
  /// **'Close the seatbox and replace the footwell cover.'**
  String get closeSeatboxAndFootwellDesc;

  /// No description provided for @unlockScooter.
  ///
  /// In en, this message translates to:
  /// **'Unlock your scooter'**
  String get unlockScooter;

  /// No description provided for @unlockScooterDesc.
  ///
  /// In en, this message translates to:
  /// **'Keycard and Bluetooth pairing will be set up during LibreScoot first run.'**
  String get unlockScooterDesc;

  /// No description provided for @deleteCachedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Delete cached downloads ({sizeMb} MB)'**
  String deleteCachedDownloads(String sizeMb);

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

  /// No description provided for @homeAppTitle.
  ///
  /// In en, this message translates to:
  /// **'LibreScoot Installer'**
  String get homeAppTitle;

  /// No description provided for @notElevated.
  ///
  /// In en, this message translates to:
  /// **'Not elevated'**
  String get notElevated;

  /// No description provided for @selectFirmwareStep.
  ///
  /// In en, this message translates to:
  /// **'Select Firmware'**
  String get selectFirmwareStep;

  /// No description provided for @connectDeviceStep.
  ///
  /// In en, this message translates to:
  /// **'Connect Device'**
  String get connectDeviceStep;

  /// No description provided for @configureNetworkStep.
  ///
  /// In en, this message translates to:
  /// **'Configure Network'**
  String get configureNetworkStep;

  /// No description provided for @prepareDeviceStep.
  ///
  /// In en, this message translates to:
  /// **'Prepare Device'**
  String get prepareDeviceStep;

  /// No description provided for @flashFirmwareStep.
  ///
  /// In en, this message translates to:
  /// **'Flash Firmware'**
  String get flashFirmwareStep;

  /// No description provided for @completeStep.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get completeStep;

  /// No description provided for @selectFirmwareImage.
  ///
  /// In en, this message translates to:
  /// **'Select Firmware Image'**
  String get selectFirmwareImage;

  /// No description provided for @selectFirmwareHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a .sdimg.gz, .sdimg, .wic.gz, .wic, or .img firmware file to flash'**
  String get selectFirmwareHint;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get selectFile;

  /// No description provided for @changeFile.
  ///
  /// In en, this message translates to:
  /// **'Change File'**
  String get changeFile;

  /// No description provided for @deviceConnected.
  ///
  /// In en, this message translates to:
  /// **'Device Connected'**
  String get deviceConnected;

  /// No description provided for @connectYourDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect Your Device'**
  String get connectYourDevice;

  /// No description provided for @connectMdbViaUsb.
  ///
  /// In en, this message translates to:
  /// **'Connect the MDB via USB and wait for detection'**
  String get connectMdbViaUsb;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @configuringNetworkHeading.
  ///
  /// In en, this message translates to:
  /// **'Configuring Network'**
  String get configuringNetworkHeading;

  /// No description provided for @settingUpNetwork.
  ///
  /// In en, this message translates to:
  /// **'Setting up network interface...'**
  String get settingUpNetwork;

  /// No description provided for @readyToConfigureNetwork.
  ///
  /// In en, this message translates to:
  /// **'Ready to configure network for device communication'**
  String get readyToConfigureNetwork;

  /// No description provided for @configureNetworkButton.
  ///
  /// In en, this message translates to:
  /// **'Configure Network'**
  String get configureNetworkButton;

  /// No description provided for @preparingDevice.
  ///
  /// In en, this message translates to:
  /// **'Preparing Device'**
  String get preparingDevice;

  /// No description provided for @readyToPrepare.
  ///
  /// In en, this message translates to:
  /// **'Ready to Prepare'**
  String get readyToPrepare;

  /// No description provided for @prepareForFlashing.
  ///
  /// In en, this message translates to:
  /// **'Prepare for Flashing'**
  String get prepareForFlashing;

  /// No description provided for @flashingFirmware.
  ///
  /// In en, this message translates to:
  /// **'Flashing Firmware'**
  String get flashingFirmware;

  /// No description provided for @startFlashing.
  ///
  /// In en, this message translates to:
  /// **'Start Flashing'**
  String get startFlashing;

  /// No description provided for @installationComplete.
  ///
  /// In en, this message translates to:
  /// **'Installation Complete!'**
  String get installationComplete;

  /// No description provided for @installationCompleteDesc.
  ///
  /// In en, this message translates to:
  /// **'Your device has been successfully flashed.\nIt will reboot automatically.'**
  String get installationCompleteDesc;

  /// No description provided for @flashAnotherDevice.
  ///
  /// In en, this message translates to:
  /// **'Flash Another Device'**
  String get flashAnotherDevice;

  /// No description provided for @flashDryRun.
  ///
  /// In en, this message translates to:
  /// **'Flash Dry Run'**
  String get flashDryRun;

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

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @confirmFlashOperation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Flash Operation'**
  String get confirmFlashOperation;

  /// No description provided for @aboutToWriteFirmware.
  ///
  /// In en, this message translates to:
  /// **'You are about to write firmware to:'**
  String get aboutToWriteFirmware;

  /// No description provided for @deviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceLabel;

  /// No description provided for @pathLabel.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get pathLabel;

  /// No description provided for @sizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sizeLabel;

  /// No description provided for @firmwareLabel.
  ///
  /// In en, this message translates to:
  /// **'Firmware:'**
  String get firmwareLabel;

  /// No description provided for @warningsLabel.
  ///
  /// In en, this message translates to:
  /// **'Warnings:'**
  String get warningsLabel;

  /// No description provided for @eraseWarning.
  ///
  /// In en, this message translates to:
  /// **'This will ERASE ALL DATA on the device. This action cannot be undone.'**
  String get eraseWarning;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @flashDeviceButton.
  ///
  /// In en, this message translates to:
  /// **'Flash Device'**
  String get flashDeviceButton;

  /// No description provided for @installingUsbDriver.
  ///
  /// In en, this message translates to:
  /// **'Installing USB driver...'**
  String get installingUsbDriver;

  /// No description provided for @usbDriverInstalled.
  ///
  /// In en, this message translates to:
  /// **'USB driver installed successfully'**
  String get usbDriverInstalled;

  /// No description provided for @driverInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Driver install failed: {error}'**
  String driverInstallFailed(String error);

  /// No description provided for @autoLoadedFirmware.
  ///
  /// In en, this message translates to:
  /// **'Auto-loaded firmware from current directory'**
  String get autoLoadedFirmware;

  /// No description provided for @deviceDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Device disconnected. Reconnect/wait for mass storage mode.'**
  String get deviceDisconnected;

  /// No description provided for @waitingForMdbNetwork.
  ///
  /// In en, this message translates to:
  /// **'Waiting for MDB network to settle...'**
  String get waitingForMdbNetwork;

  /// No description provided for @findingNetworkInterface.
  ///
  /// In en, this message translates to:
  /// **'Finding network interface...'**
  String get findingNetworkInterface;

  /// No description provided for @couldNotFindInterface.
  ///
  /// In en, this message translates to:
  /// **'Could not find USB network interface'**
  String get couldNotFindInterface;

  /// No description provided for @networkConfigured.
  ///
  /// In en, this message translates to:
  /// **'Network configured successfully'**
  String get networkConfigured;

  /// No description provided for @selectFirmwareFileError.
  ///
  /// In en, this message translates to:
  /// **'Please select a .sdimg.gz, .sdimg, .wic.gz, .wic, or .img file'**
  String get selectFirmwareFileError;

  /// No description provided for @errorOpeningFilePicker.
  ///
  /// In en, this message translates to:
  /// **'Error opening file picker: {error}'**
  String errorOpeningFilePicker(String error);

  /// No description provided for @configuringBootloader.
  ///
  /// In en, this message translates to:
  /// **'Configuring bootloader for mass storage mode...'**
  String get configuringBootloader;

  /// No description provided for @rebootingDevice.
  ///
  /// In en, this message translates to:
  /// **'Rebooting device...'**
  String get rebootingDevice;

  /// No description provided for @waitingForMassStorage.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device to reboot in mass storage mode...'**
  String get waitingForMassStorage;

  /// No description provided for @deviceReadyForFlashing.
  ///
  /// In en, this message translates to:
  /// **'Device ready for flashing'**
  String get deviceReadyForFlashing;

  /// No description provided for @selectFirmwareDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Firmware Image'**
  String get selectFirmwareDialogTitle;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to: {host}\nFirmware: {firmware}\nSerial: {serial}'**
  String connectedTo(String host, String firmware, String serial);

  /// No description provided for @connectedToFirmware.
  ///
  /// In en, this message translates to:
  /// **'Connected to {version}'**
  String connectedToFirmware(String version);

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode: {mode}'**
  String modeLabel(String mode);

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

  /// No description provided for @noConfigFound.
  ///
  /// In en, this message translates to:
  /// **'No device configuration found to back up'**
  String get noConfigFound;

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

  /// No description provided for @flashError.
  ///
  /// In en, this message translates to:
  /// **'Flash error: {error}'**
  String flashError(String error);

  /// No description provided for @flashComplete.
  ///
  /// In en, this message translates to:
  /// **'Flash complete!'**
  String get flashComplete;

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

  /// No description provided for @skipOfflineMapsHint.
  ///
  /// In en, this message translates to:
  /// **'You can install maps later by re-running the installer'**
  String get skipOfflineMapsHint;

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

  /// No description provided for @keycardMasterHeading.
  ///
  /// In en, this message translates to:
  /// **'With a master card:'**
  String get keycardMasterHeading;

  /// No description provided for @keycardLearningStep1.
  ///
  /// In en, this message translates to:
  /// **'1. The DBC LED blinks green — no keycards are registered yet.'**
  String get keycardLearningStep1;

  /// No description provided for @keycardLearningStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Hold your first NFC card to the reader. This becomes the master key, and the LED stops blinking.'**
  String get keycardLearningStep2;

  /// No description provided for @keycardLearningStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Tap the master key again to enter learning mode, then tap each card you want to register as a key.'**
  String get keycardLearningStep3;

  /// No description provided for @keycardLearningStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Tap the master key once more to exit learning mode.'**
  String get keycardLearningStep4;

  /// No description provided for @keycardNoMasterHeading.
  ///
  /// In en, this message translates to:
  /// **'Without a master card:'**
  String get keycardNoMasterHeading;

  /// No description provided for @keycardNoMasterHint.
  ///
  /// In en, this message translates to:
  /// **'If you don\'t have a dedicated master card, you can register keycards directly via the installer while the USB cable is still connected.'**
  String get keycardNoMasterHint;

  /// No description provided for @keycardStartLearning.
  ///
  /// In en, this message translates to:
  /// **'Start keycard learning'**
  String get keycardStartLearning;

  /// No description provided for @keycardLearningActive.
  ///
  /// In en, this message translates to:
  /// **'Learning mode active'**
  String get keycardLearningActive;

  /// No description provided for @keycardLearningActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Tap each NFC card you want to register as a key. Press Done when finished.'**
  String get keycardLearningActiveHint;

  /// No description provided for @keycardStopLearning.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get keycardStopLearning;

  /// No description provided for @willAskForElevation.
  ///
  /// In en, this message translates to:
  /// **'Start Installation (will ask for elevation)'**
  String get willAskForElevation;

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

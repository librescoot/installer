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
  /// **'Choose firmware and check prerequisites'**
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
  /// **'Prepare the scooter'**
  String get phasePhysicalPrepTitle;

  /// No description provided for @phasePhysicalPrepDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the footwell and connect USB'**
  String get phasePhysicalPrepDescription;

  /// No description provided for @phaseMdbConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to MDB'**
  String get phaseMdbConnectTitle;

  /// No description provided for @phaseMdbConnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Detect the device and connect with SSH'**
  String get phaseMdbConnectDescription;

  /// No description provided for @phaseResumeDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Previous attempt'**
  String get phaseResumeDetectedTitle;

  /// No description provided for @phaseResumeDetectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Interrupted installation found'**
  String get phaseResumeDetectedDescription;

  /// No description provided for @phaseHealthCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Health check'**
  String get phaseHealthCheckTitle;

  /// No description provided for @phaseHealthCheckDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify scooter readiness'**
  String get phaseHealthCheckDescription;

  /// No description provided for @phaseMdbToUmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare MDB for flashing'**
  String get phaseMdbToUmsTitle;

  /// No description provided for @phaseMdbToUmsDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure the bootloader'**
  String get phaseMdbToUmsDescription;

  /// No description provided for @phaseMdbFlashTitle.
  ///
  /// In en, this message translates to:
  /// **'Write MDB image'**
  String get phaseMdbFlashTitle;

  /// No description provided for @phaseMdbFlashDescription.
  ///
  /// In en, this message translates to:
  /// **'Write the firmware image'**
  String get phaseMdbFlashDescription;

  /// No description provided for @phaseScooterPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect power'**
  String get phaseScooterPrepTitle;

  /// No description provided for @phaseScooterPrepDescription.
  ///
  /// In en, this message translates to:
  /// **'Disconnect the CBB and AUX'**
  String get phaseScooterPrepDescription;

  /// No description provided for @phaseMdbBootTitle.
  ///
  /// In en, this message translates to:
  /// **'Reboot'**
  String get phaseMdbBootTitle;

  /// No description provided for @phaseMdbBootDescription.
  ///
  /// In en, this message translates to:
  /// **'Reconnect AUX and wait for boot'**
  String get phaseMdbBootDescription;

  /// No description provided for @phaseCbbReconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reconnect CBB and battery'**
  String get phaseCbbReconnectTitle;

  /// No description provided for @phaseCbbReconnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the CBB and check the battery'**
  String get phaseCbbReconnectDescription;

  /// No description provided for @phaseDbcPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload files'**
  String get phaseDbcPrepTitle;

  /// No description provided for @phaseDbcPrepDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload files for the dashboard'**
  String get phaseDbcPrepDescription;

  /// No description provided for @phaseDbcFlashTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer dashboard files'**
  String get phaseDbcFlashTitle;

  /// No description provided for @phaseDbcFlashDescription.
  ///
  /// In en, this message translates to:
  /// **'The scooter completes the dashboard work'**
  String get phaseDbcFlashDescription;

  /// No description provided for @phaseReconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get phaseReconnectTitle;

  /// No description provided for @phaseReconnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify dashboard work'**
  String get phaseReconnectDescription;

  /// No description provided for @phaseBluetoothPairingTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get phaseBluetoothPairingTitle;

  /// No description provided for @phaseBluetoothPairingDescription.
  ///
  /// In en, this message translates to:
  /// **'Pair a Bluetooth device'**
  String get phaseBluetoothPairingDescription;

  /// No description provided for @phaseFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get phaseFinishTitle;

  /// No description provided for @phaseFinishDescription.
  ///
  /// In en, this message translates to:
  /// **'Reassemble the scooter'**
  String get phaseFinishDescription;

  /// No description provided for @majorStepPrepare.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
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
  /// **'Install Librescoot firmware on your scooter.'**
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
  /// **'Flashing takes several minutes. A USB disconnect or laptop sleep during the write can leave the MDB in an incomplete state. Check:\n• Use a known-good USB cable, firmly connected at both ends\n• Keep the laptop on power or fully charged; disable battery saver and sleep\n• Use a direct USB port rather than a hub where possible\n• Keep cables and power connected once flashing starts'**
  String get reliabilityWarningBody;

  /// No description provided for @noPowerCycleWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep power connected during flashing'**
  String get noPowerCycleWarningTitle;

  /// No description provided for @noPowerCycleWarningBody.
  ///
  /// In en, this message translates to:
  /// **'If the installer appears stuck or behaves unexpectedly, stop and ask in the Librescoot Discord before changing anything. Unless the installer explicitly directs you otherwise:\n• Keep the AUX battery and CBB connected\n• Keep the USB cable connected\n• Keep the scooter and laptop running\n\nInterrupting power or USB during flashing can leave the scooter unable to boot normally.'**
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
  /// **'Review these warnings before starting.'**
  String get noticesSubheading;

  /// No description provided for @noticesAcknowledgeButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get noticesAcknowledgeButton;

  /// No description provided for @noticesWaitingForDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloading firmware...'**
  String get noticesWaitingForDownloads;

  /// No description provided for @noticesContinueOfflineAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue while downloads run'**
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
  /// **'Librescoot Installer needs administrator privileges to write to the scooter\'s storage and configure the network interface. The elevation prompt was declined or could not be shown.\n\nSelect Continue to dismiss this dialog and try again. The installer cannot continue until access is approved.'**
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
  /// **'Firmware channel'**
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

  /// No description provided for @manifestBundledNotice.
  ///
  /// In en, this message translates to:
  /// **'Offline: these versions come from the list built into this installer and may be out of date.'**
  String get manifestBundledNotice;

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
  /// **'Start installation'**
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

  /// No description provided for @preparingDownloads.
  ///
  /// In en, this message translates to:
  /// **'Preparing downloads...'**
  String get preparingDownloads;

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

  /// No description provided for @keepScooterAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep the scooter awake'**
  String get keepScooterAwake;

  /// No description provided for @keepScooterAwakeDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock the scooter, or put a main battery in the front slot. Without one or the other it suspends partway through the install and takes the USB connection with it.'**
  String get keepScooterAwakeDesc;

  /// No description provided for @removeFootwellCover.
  ///
  /// In en, this message translates to:
  /// **'Remove footwell cover'**
  String get removeFootwellCover;

  /// No description provided for @removeFootwellCoverDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove the four screws. Factory scooters use PH2 Phillips; scooters previously serviced may use H4 hex or Torx.'**
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
  /// **'Detect device'**
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

  /// No description provided for @driverClaimedHeading.
  ///
  /// In en, this message translates to:
  /// **'Another program has claimed the USB port'**
  String get driverClaimedHeading;

  /// No description provided for @driverClaimedBody.
  ///
  /// In en, this message translates to:
  /// **'Windows has handed the scooter\'s USB connection to {driver} instead of the network driver the installer needs. That program installed itself over the top, so the installer cannot take it back on its own.\n\nOpen Device Manager, find the scooter under Ports (COM & LPT), right-click it and choose Uninstall device. Tick \"Attempt to remove the driver for this device\" if it is offered, then unplug the scooter and plug it in again.\n\nNothing on the scooter has been changed and it is safe to close the installer.'**
  String driverClaimedBody(String driver);

  /// No description provided for @driverClaimedDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details for a bug report'**
  String get driverClaimedDetailsLabel;

  /// No description provided for @driverNeedsRebootHeading.
  ///
  /// In en, this message translates to:
  /// **'Windows needs a restart to finish'**
  String get driverNeedsRebootHeading;

  /// No description provided for @driverNeedsRebootBody.
  ///
  /// In en, this message translates to:
  /// **'The network driver installed, but Windows could not swap it in while the scooter was plugged in. Restart your computer and run the installer again.\n\nNothing on the scooter has been changed.'**
  String get driverNeedsRebootBody;

  /// No description provided for @driverRecheck.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get driverRecheck;

  /// No description provided for @connectFailedWhatToCheck.
  ///
  /// In en, this message translates to:
  /// **'What to check'**
  String get connectFailedWhatToCheck;

  /// No description provided for @connectFailedDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get connectFailedDetailsLabel;

  /// No description provided for @connectFailedNoDeviceHeading.
  ///
  /// In en, this message translates to:
  /// **'No USB device has turned up'**
  String get connectFailedNoDeviceHeading;

  /// No description provided for @connectFailedNoDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'The main board announces itself as a network device the moment it is plugged in and awake. So far nothing has appeared on USB at all.\n• The cable goes into the MDB port, the one you took the internal cable out of. Check both ends are seated\n• Plug into the laptop directly, not through a hub or a dock\n• Try a different cable. Charge-only cables carry power and no data\n• The scooter has to be awake. Without a main battery in the front slot it goes to sleep on its own\nThe installer keeps watching and carries on by itself the moment the board turns up. Nothing else to click here.'**
  String get connectFailedNoDeviceBody;

  /// No description provided for @connectFailedDeviceVanishedHeading.
  ///
  /// In en, this message translates to:
  /// **'The USB device disappeared'**
  String get connectFailedDeviceVanishedHeading;

  /// No description provided for @connectFailedDeviceVanishedBody.
  ///
  /// In en, this message translates to:
  /// **'The main board was on USB a moment ago and is gone now. Either the cable moved, or the scooter put itself to sleep and took the connection with it.\n• Check the USB cable at both ends. A plug that shifts is enough\n• Unlock the scooter, or put a main battery in the front slot. Without one or the other it suspends partway through\n• Leave the AUX battery and the CBB connected\nNothing on the scooter has been changed. Try again once the board is back.'**
  String get connectFailedDeviceVanishedBody;

  /// No description provided for @connectFailedNoRouteHeading.
  ///
  /// In en, this message translates to:
  /// **'The scooter is on USB but not reachable'**
  String get connectFailedNoRouteHeading;

  /// No description provided for @connectFailedNoRouteBody.
  ///
  /// In en, this message translates to:
  /// **'The board is on the bus and this computer has no way to send anything to it. The USB network interface came up without the address the installer put on it, which on Linux usually means NetworkManager took the interface over.\n• Try again. The installer sets the address once more on every attempt\n• On Linux, set the interface to unmanaged in NetworkManager, or switch IPv6 off for it\n• Unplug the cable and plug it back in so the interface is created fresh\nThe log has the interface and the route the installer found.'**
  String get connectFailedNoRouteBody;

  /// No description provided for @connectFailedRefusedHeading.
  ///
  /// In en, this message translates to:
  /// **'The scooter turned the connection down'**
  String get connectFailedRefusedHeading;

  /// No description provided for @connectFailedRefusedBody.
  ///
  /// In en, this message translates to:
  /// **'The board answered on the network and refused the connection, so the link works and the part the installer talks to has not started yet. In the first minute after the board powers up that is normal.\n• Give it a few seconds and try again\n• If it is still refusing after a couple of minutes, open the technical details, copy them and ask in the Librescoot Discord\nNothing on the scooter has been changed and it is safe to close the installer.'**
  String get connectFailedRefusedBody;

  /// No description provided for @connectFailedTimeoutHeading.
  ///
  /// In en, this message translates to:
  /// **'No answer from the scooter'**
  String get connectFailedTimeoutHeading;

  /// No description provided for @connectFailedTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'The board is on USB, the installer opened a connection to it, and nothing came back before the time ran out. Usually the board is still booting; sometimes the link is only up on this side.\n• Try again. A board that is still starting answers on the second or third attempt\n• Check the USB cable at both ends and plug into the laptop directly, not through a hub\n• The scooter has to be awake and the AUX battery connected\nNothing on the scooter has been changed.'**
  String get connectFailedTimeoutBody;

  /// No description provided for @connectFailedDroppedHeading.
  ///
  /// In en, this message translates to:
  /// **'The connection dropped while it was being set up'**
  String get connectFailedDroppedHeading;

  /// No description provided for @connectFailedDroppedBody.
  ///
  /// In en, this message translates to:
  /// **'The scooter took the connection and let go of it before it was finished. A board that is restarting does exactly that, and so does one that goes to sleep partway through.\n• Unlock the scooter, or put a main battery in the front slot. Without one or the other it suspends on its own\n• Check the USB cable at both ends\n• Wait until the board has finished starting, then try again\nNothing on the scooter has been changed.'**
  String get connectFailedDroppedBody;

  /// No description provided for @connectFailedAuthHeading.
  ///
  /// In en, this message translates to:
  /// **'The scooter would not let the installer in'**
  String get connectFailedAuthHeading;

  /// No description provided for @connectFailedAuthBody.
  ///
  /// In en, this message translates to:
  /// **'The connection works and every login the installer knows was turned down. On a stock scooter that usually means the root password was changed, which a workshop visit can do.\n• Try again. If the scooter asks for a password, the installer offers a field for it\n• Ask whoever last had the scooter open whether they set a root password\n• Otherwise ask in the Librescoot Discord and bring the technical details below\nNothing on the scooter has been changed and it is safe to close the installer.'**
  String get connectFailedAuthBody;

  /// No description provided for @connectFailedUnknownHeading.
  ///
  /// In en, this message translates to:
  /// **'The installer could not reach the scooter'**
  String get connectFailedUnknownHeading;

  /// No description provided for @connectFailedUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'The connection failed without a specific diagnosis.\n• Check the USB cable at both ends and connect it directly to the laptop\n• Make sure the scooter is awake and the AUX battery is connected\n• Try again in case the failure was temporary\n\nThe technical details below can be included in a bug report. Nothing on the scooter has been changed, and it is safe to close the installer.'**
  String get connectFailedUnknownBody;

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
  /// **'An interrupted installation was detected. The installer will clean up the previous attempt before starting again.'**
  String get resumeFoundBody;

  /// No description provided for @resumeWhatHappensHeading.
  ///
  /// In en, this message translates to:
  /// **'What happens when you continue'**
  String get resumeWhatHappensHeading;

  /// No description provided for @resumeWhatHappensCleanup.
  ///
  /// In en, this message translates to:
  /// **'The leftovers are cleared: the onboot script the previous run armed is disarmed, and the services it stopped are started again.'**
  String get resumeWhatHappensCleanup;

  /// No description provided for @resumeWhatHappensRestart.
  ///
  /// In en, this message translates to:
  /// **'The installation runs from the beginning. Nothing is resumed, so no half-finished step is carried over.'**
  String get resumeWhatHappensRestart;

  /// No description provided for @resumeWhatHappensKeep.
  ///
  /// In en, this message translates to:
  /// **'Restarting does not erase anything beyond changes already made by the interrupted run.'**
  String get resumeWhatHappensKeep;

  /// No description provided for @resumeTakesAsLong.
  ///
  /// In en, this message translates to:
  /// **'It takes as long as a normal installation, about 20 minutes.'**
  String get resumeTakesAsLong;

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
  /// **'Unlock the scooter so the installer can carry on.'**
  String get awaitingUnlockDetail;

  /// No description provided for @awaitingUnlockHintKeycard.
  ///
  /// In en, this message translates to:
  /// **'Hold your keycard against the reader on the handlebars'**
  String get awaitingUnlockHintKeycard;

  /// No description provided for @awaitingUnlockHintPhone.
  ///
  /// In en, this message translates to:
  /// **'Or use Bluetooth if it is configured'**
  String get awaitingUnlockHintPhone;

  /// No description provided for @awaitingUnlockWatching.
  ///
  /// In en, this message translates to:
  /// **'The installer continues automatically once the scooter is unlocked.'**
  String get awaitingUnlockWatching;

  /// No description provided for @awaitingParkWatching.
  ///
  /// In en, this message translates to:
  /// **'The installer continues automatically once the scooter is parked.'**
  String get awaitingParkWatching;

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

  /// No description provided for @manualPasswordUnknown.
  ///
  /// In en, this message translates to:
  /// **'I don\'t know it'**
  String get manualPasswordUnknown;

  /// No description provided for @manualPasswordUnknownHeading.
  ///
  /// In en, this message translates to:
  /// **'The root password is unknown'**
  String get manualPasswordUnknownHeading;

  /// No description provided for @manualPasswordUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'Scooters normally answer with a password the installer already carries. This one does not, which usually means it was changed.\n\nIf a workshop has had the scooter, ask them whether they set a root password. That is the most common reason.\n\nOtherwise ask in the Librescoot Discord and mention the firmware version shown above.\n\nNothing on the scooter has been changed and it is safe to close the installer.'**
  String get manualPasswordUnknownBody;

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
  /// **'This scooter is running a minimal recovery image. It boots and answers, but carries none of the vehicle services. This can happen if an earlier installation did not finish. Continue to re-flash the full firmware and finish setup.'**
  String get incompleteImageBody;

  /// No description provided for @reflashToRecover.
  ///
  /// In en, this message translates to:
  /// **'Re-flash to recover'**
  String get reflashToRecover;

  /// No description provided for @stockFirmwareStatus.
  ///
  /// In en, this message translates to:
  /// **'Stock firmware detected. Ready to install Librescoot...'**
  String get stockFirmwareStatus;

  /// No description provided for @stockFirmwareHeading.
  ///
  /// In en, this message translates to:
  /// **'Stock firmware'**
  String get stockFirmwareHeading;

  /// No description provided for @stockFirmwareBody.
  ///
  /// In en, this message translates to:
  /// **'This scooter is running its original firmware. Nothing is wrong with it. Continue to install Librescoot.'**
  String get stockFirmwareBody;

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

  /// No description provided for @healthValueUnknown.
  ///
  /// In en, this message translates to:
  /// **'cannot be read'**
  String get healthValueUnknown;

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
  /// **'Open seatbox'**
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

  /// No description provided for @readyToFlashTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get readyToFlashTargetLabel;

  /// No description provided for @readyToFlashImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Image to write'**
  String get readyToFlashImageLabel;

  /// No description provided for @readyToFlashErases.
  ///
  /// In en, this message translates to:
  /// **'This overwrites all storage on the main board.'**
  String get readyToFlashErases;

  /// No description provided for @readyToFlashDuration.
  ///
  /// In en, this message translates to:
  /// **'The write takes about a minute. Do not disconnect USB or power while it runs.'**
  String get readyToFlashDuration;

  /// No description provided for @readyToFlashNoTarget.
  ///
  /// In en, this message translates to:
  /// **'No target device found yet.'**
  String get readyToFlashNoTarget;

  /// No description provided for @waitingForDeviceRedetection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the device to be detected again…'**
  String get waitingForDeviceRedetection;

  /// No description provided for @macosDiskNotReadable.
  ///
  /// In en, this message translates to:
  /// **'If macOS says the disk is unreadable, select Ignore. Selecting Eject disconnects the board during installation.'**
  String get macosDiskNotReadable;

  /// No description provided for @macosNoRouteHeading.
  ///
  /// In en, this message translates to:
  /// **'macOS is blocking access to the scooter'**
  String get macosNoRouteHeading;

  /// No description provided for @macosNoRouteBody.
  ///
  /// In en, this message translates to:
  /// **'The scooter responds over USB, but macOS has not allowed the installer to reach it.\n\nOpen Privacy & Security > Local Network and enable access for Librescoot Installer.\n\nThe installer retries automatically after access is enabled.'**
  String get macosNoRouteBody;

  /// No description provided for @macosOpenLocalNetworkSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Local Network settings'**
  String get macosOpenLocalNetworkSettings;

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

  /// No description provided for @flashAwaitingAuthorisation.
  ///
  /// In en, this message translates to:
  /// **'macOS will ask for your password or Touch ID before the write can start. Look for a system dialog, it may be behind this window. Nothing is being written until you approve it.'**
  String get flashAwaitingAuthorisation;

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

  /// No description provided for @flashVerifyingReadback.
  ///
  /// In en, this message translates to:
  /// **'Verifying boot-critical data on the device…'**
  String get flashVerifyingReadback;

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
  /// **'CBB first, then the AUX pole. The main battery is already off at this point: the MDB is parked in flash mode and has stopped talking to it. You do not need to take it out.'**
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
  /// **'The USB connection drops when you disconnect AUX. That is expected. Reconnect the AUX pole on the next screen to start the MDB.'**
  String get auxDisconnectWarning;

  /// No description provided for @doneCbbAuxDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get doneCbbAuxDisconnected;

  /// No description provided for @doneAuxDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get doneAuxDisconnected;

  /// No description provided for @brakeResetHeading.
  ///
  /// In en, this message translates to:
  /// **'Restart the scooter'**
  String get brakeResetHeading;

  /// No description provided for @brakeResetIntro.
  ///
  /// In en, this message translates to:
  /// **'Squeeze and hold both brake levers. Every ten seconds, let go of the right one for about a second, then squeeze it again. After the fourth hold, just let go. The scooter restarts.'**
  String get brakeResetIntro;

  /// No description provided for @brakeResetAfterNote.
  ///
  /// In en, this message translates to:
  /// **'The USB connection disappears while it restarts. That is expected, and the installer waits for the board to come back.'**
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
  /// **'That is the pattern. Let go now. The scooter restarts a few seconds later on its own.'**
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
  /// **'Reconnect the AUX pole only'**
  String get reconnectAuxPole;

  /// No description provided for @reconnectAuxPoleDesc.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the positive AUX pole. Leave the CBB disconnected for now, it goes back on later, before the DBC flash. The MDB will power on and boot into Librescoot.'**
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
  /// **'Verify CBB connection'**
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

  /// No description provided for @mainBatteryNotDetected.
  ///
  /// In en, this message translates to:
  /// **'Main battery not detected. Check that it is fitted correctly.'**
  String get mainBatteryNotDetected;

  /// No description provided for @cbbDetectionMayTakeMinutes.
  ///
  /// In en, this message translates to:
  /// **'This can take several minutes.'**
  String get cbbDetectionMayTakeMinutes;

  /// No description provided for @preparingDbcFlash.
  ///
  /// In en, this message translates to:
  /// **'Preparing DBC installation'**
  String get preparingDbcFlash;

  /// No description provided for @preparingDbcFlashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload the required dashboard files to the MDB first.'**
  String get preparingDbcFlashSubtitle;

  /// No description provided for @preparingDbcFlashExplainer.
  ///
  /// In en, this message translates to:
  /// **'The installer first uploads the dashboard image, firmware, and offline maps to the MDB. When the files are ready, start the on-device installation and replace the laptop cable with the DBC cable. The MDB completes the dashboard work autonomously.'**
  String get preparingDbcFlashExplainer;

  /// No description provided for @preparingMapTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transferring maps'**
  String get preparingMapTransfer;

  /// No description provided for @preparingMapTransferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The offline maps go to the main board first.'**
  String get preparingMapTransferSubtitle;

  /// No description provided for @preparingMapTransferExplainer.
  ///
  /// In en, this message translates to:
  /// **'The installer first uploads the offline maps to the MDB. No dashboard firmware is changed. When the files are ready, start the transfer and replace the laptop cable with the DBC cable. The scooter then copies the maps autonomously.'**
  String get preparingMapTransferExplainer;

  /// No description provided for @skipMapTransfer.
  ///
  /// In en, this message translates to:
  /// **'Skip the maps'**
  String get skipMapTransfer;

  /// No description provided for @majorStepDbcMaps.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get majorStepDbcMaps;

  /// No description provided for @phaseDbcPrepTitleMaps.
  ///
  /// In en, this message translates to:
  /// **'Upload maps'**
  String get phaseDbcPrepTitleMaps;

  /// No description provided for @phaseDbcPrepDescriptionMaps.
  ///
  /// In en, this message translates to:
  /// **'Upload the offline maps'**
  String get phaseDbcPrepDescriptionMaps;

  /// No description provided for @phaseDbcFlashTitleMaps.
  ///
  /// In en, this message translates to:
  /// **'Transfer maps'**
  String get phaseDbcFlashTitleMaps;

  /// No description provided for @phaseDbcFlashDescriptionMaps.
  ///
  /// In en, this message translates to:
  /// **'The scooter copies them over'**
  String get phaseDbcFlashDescriptionMaps;

  /// No description provided for @dbcReadyButtonMaps.
  ///
  /// In en, this message translates to:
  /// **'Start map transfer'**
  String get dbcReadyButtonMaps;

  /// No description provided for @waitingForDownloads.
  ///
  /// In en, this message translates to:
  /// **'Waiting for downloads to complete...'**
  String get waitingForDownloads;

  /// No description provided for @filesStagedWaitingForHandoff.
  ///
  /// In en, this message translates to:
  /// **'Files are ready. Start the dashboard work when you are ready.'**
  String get filesStagedWaitingForHandoff;

  /// No description provided for @handoffEstimateTitle.
  ///
  /// In en, this message translates to:
  /// **'Estimated progress'**
  String get handoffEstimateTitle;

  /// No description provided for @handoffEstimateExplanation.
  ///
  /// In en, this message translates to:
  /// **'The laptop cannot read live progress while the MDB is connected to the DBC. This deliberately cautious estimate uses the selected files and typical timings. Do not reconnect the laptop based on the estimate; wait for the display and blinkers to show the actual state.'**
  String get handoffEstimateExplanation;

  /// No description provided for @handoffEstimateMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String handoffEstimateMinutes(int minutes);

  /// No description provided for @handoffEstimateRemainingRange.
  ///
  /// In en, this message translates to:
  /// **'About {from}–{to} remaining'**
  String handoffEstimateRemainingRange(String from, String to);

  /// No description provided for @handoffEstimateRemainingUpper.
  ///
  /// In en, this message translates to:
  /// **'Up to about {to} remaining'**
  String handoffEstimateRemainingUpper(String to);

  /// No description provided for @handoffEstimateTotalRange.
  ///
  /// In en, this message translates to:
  /// **'Expected total: about {from}–{to}'**
  String handoffEstimateTotalRange(String from, String to);

  /// No description provided for @handoffEstimateTakingLonger.
  ///
  /// In en, this message translates to:
  /// **'Taking longer than expected. Keep the scooter powered and leave the cables connected.'**
  String get handoffEstimateTakingLonger;

  /// No description provided for @startingTrampoline.
  ///
  /// In en, this message translates to:
  /// **'Starting on-device installation...'**
  String get startingTrampoline;

  /// No description provided for @uploadError.
  ///
  /// In en, this message translates to:
  /// **'Upload error: {error}'**
  String uploadError(String error);

  /// No description provided for @trampolineStartFailed.
  ///
  /// In en, this message translates to:
  /// **'The on-device installation could not start. Details are in the installer log, and diagnostic files were saved to {path}. Try again; if it still fails, restore the scooter without this transfer.'**
  String trampolineStartFailed(String path);

  /// No description provided for @trampolineStartFailedNoPath.
  ///
  /// In en, this message translates to:
  /// **'The on-device installation could not start. Details are in the installer log. Try again; if it still fails, restore the scooter without this transfer.'**
  String get trampolineStartFailedNoPath;

  /// No description provided for @restoreScooterWithoutTransfer.
  ///
  /// In en, this message translates to:
  /// **'Restore scooter without this transfer'**
  String get restoreScooterWithoutTransfer;

  /// No description provided for @restoreScooterBeforeClosing.
  ///
  /// In en, this message translates to:
  /// **'Restore the scooter before closing the installer. Retry the transfer or choose Restore scooter without this transfer.'**
  String get restoreScooterBeforeClosing;

  /// No description provided for @finishTransferSkippedPending.
  ///
  /// In en, this message translates to:
  /// **'The transfer was skipped. The scooter is restoring normal services; wait for it to finish before disconnecting power.'**
  String get finishTransferSkippedPending;

  /// No description provided for @finishTransferSkippedConfirmed.
  ///
  /// In en, this message translates to:
  /// **'The requested dashboard or map transfer was not installed. Verify that normal scooter functions are available before riding.'**
  String get finishTransferSkippedConfirmed;

  /// No description provided for @dbcReadyButton.
  ///
  /// In en, this message translates to:
  /// **'Start DBC installation'**
  String get dbcReadyButton;

  /// No description provided for @dbcFlashInProgress.
  ///
  /// In en, this message translates to:
  /// **'DBC installation in progress'**
  String get dbcFlashInProgress;

  /// No description provided for @dbcFlashSwapCablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect the DBC cable to the MDB'**
  String get dbcFlashSwapCablesTitle;

  /// No description provided for @dbcFlashSwapCablesDeadline.
  ///
  /// In en, this message translates to:
  /// **'The scooter is ready for the dashboard connection. Complete this step within a few minutes. You can secure the screws after the connection is confirmed.'**
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
  /// **'Prepare dashboard'**
  String get blinkerStepFlash;

  /// No description provided for @blinkerStepRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart dashboard'**
  String get blinkerStepRestart;

  /// No description provided for @blinkerStepMaps.
  ///
  /// In en, this message translates to:
  /// **'Copy offline maps'**
  String get blinkerStepMaps;

  /// No description provided for @verifyingDbcInstallation.
  ///
  /// In en, this message translates to:
  /// **'Checking dashboard work'**
  String get verifyingDbcInstallation;

  /// No description provided for @reconnectUsbToLaptop.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the laptop USB cable to the MDB…'**
  String get reconnectUsbToLaptop;

  /// No description provided for @waitingForRndisDevice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for RNDIS device...'**
  String get waitingForRndisDevice;

  /// No description provided for @checkingCompletionRecord.
  ///
  /// In en, this message translates to:
  /// **'Checking completion record...'**
  String get checkingCompletionRecord;

  /// No description provided for @readingTrampolineStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking installation status...'**
  String get readingTrampolineStatus;

  /// No description provided for @readingTrampolineStatusElapsed.
  ///
  /// In en, this message translates to:
  /// **'Checking installation status… ({elapsed}s)'**
  String readingTrampolineStatusElapsed(int elapsed);

  /// No description provided for @dbcFlashSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Dashboard work complete'**
  String get dbcFlashSuccessful;

  /// No description provided for @dbcInstallSuccessfulVersion.
  ///
  /// In en, this message translates to:
  /// **'DBC installation complete. Reported version: {version}'**
  String dbcInstallSuccessfulVersion(String version);

  /// No description provided for @dbcFlashFailed.
  ///
  /// In en, this message translates to:
  /// **'Dashboard work failed: {message}'**
  String dbcFlashFailed(String message);

  /// No description provided for @dbcFlashError.
  ///
  /// In en, this message translates to:
  /// **'Dashboard work error'**
  String get dbcFlashError;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @trampolineStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'The installer could not determine whether the dashboard work finished. Open the installer log for details.'**
  String get trampolineStatusUnknown;

  /// No description provided for @welcomeToLibrescoot.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Librescoot'**
  String get welcomeToLibrescoot;

  /// No description provided for @finishStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Installation status'**
  String get finishStatusTitle;

  /// No description provided for @finishPendingHeading.
  ///
  /// In en, this message translates to:
  /// **'Installation still running'**
  String get finishPendingHeading;

  /// No description provided for @finishCompleteHeading.
  ///
  /// In en, this message translates to:
  /// **'Installation complete'**
  String get finishCompleteHeading;

  /// No description provided for @finishSkippedHeading.
  ///
  /// In en, this message translates to:
  /// **'Dashboard transfer skipped'**
  String get finishSkippedHeading;

  /// No description provided for @finalSteps.
  ///
  /// In en, this message translates to:
  /// **'Final steps:'**
  String get finalSteps;

  /// No description provided for @finishNextHeading.
  ///
  /// In en, this message translates to:
  /// **'What happens next'**
  String get finishNextHeading;

  /// No description provided for @finishNextDbcFlash.
  ///
  /// In en, this message translates to:
  /// **'After you reconnect the DBC cable, the scooter starts the requested dashboard work. It can take about 20 minutes. Keep power connected until the process finishes; the boot light indicates activity.'**
  String get finishNextDbcFlash;

  /// No description provided for @finishNextOnDevice.
  ///
  /// In en, this message translates to:
  /// **'After you reconnect the DBC cable, the scooter completes the remaining work. The laptop is not needed for this step.'**
  String get finishNextOnDevice;

  /// No description provided for @finishNextNothing.
  ///
  /// In en, this message translates to:
  /// **'The main board installation is complete. Reassemble the scooter before riding.'**
  String get finishNextNothing;

  /// No description provided for @finishOnDevice.
  ///
  /// In en, this message translates to:
  /// **'The scooter is completing the installation autonomously. Keep it powered on and leave the current cable connection in place until it finishes.'**
  String get finishOnDevice;

  /// No description provided for @finishReconnectDbc.
  ///
  /// In en, this message translates to:
  /// **'The laptop is connected to the MDB again. Reconnect the DBC cable to continue the dashboard work.'**
  String get finishReconnectDbc;

  /// No description provided for @finishConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Requested work complete. Reassemble the scooter and verify that it unlocks before riding.'**
  String get finishConfirmed;

  /// No description provided for @closeInstaller.
  ///
  /// In en, this message translates to:
  /// **'Close installer'**
  String get closeInstaller;

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
  /// **'Reconnect and secure DBC USB cable'**
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
  /// **'Use a registered keycard, or Bluetooth if it is configured.'**
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
  /// **'MDB firmware package'**
  String get assetChipMdbArtifact;

  /// No description provided for @assetChipDbcArtifact.
  ///
  /// In en, this message translates to:
  /// **'DBC firmware package'**
  String get assetChipDbcArtifact;

  /// No description provided for @assetChipMdbImage.
  ///
  /// In en, this message translates to:
  /// **'MDB bootstrap'**
  String get assetChipMdbImage;

  /// No description provided for @assetChipDbcImage.
  ///
  /// In en, this message translates to:
  /// **'DBC bootstrap'**
  String get assetChipDbcImage;

  /// No description provided for @assetChipMdbBlockMap.
  ///
  /// In en, this message translates to:
  /// **'MDB block map'**
  String get assetChipMdbBlockMap;

  /// No description provided for @assetChipDbcBlockMap.
  ///
  /// In en, this message translates to:
  /// **'DBC block map'**
  String get assetChipDbcBlockMap;

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
  /// **'Download MDB firmware'**
  String get downloadMdbFirmware;

  /// No description provided for @downloadDbcFirmware.
  ///
  /// In en, this message translates to:
  /// **'Download DBC firmware'**
  String get downloadDbcFirmware;

  /// No description provided for @downloadMapTiles.
  ///
  /// In en, this message translates to:
  /// **'Download map tiles'**
  String get downloadMapTiles;

  /// No description provided for @downloadRoutingTiles.
  ///
  /// In en, this message translates to:
  /// **'Download routing tiles'**
  String get downloadRoutingTiles;

  /// No description provided for @safetyCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Safety check failed'**
  String get safetyCheckFailed;

  /// No description provided for @cannotFlashSafety.
  ///
  /// In en, this message translates to:
  /// **'Cannot write to this device until these safety checks are addressed:'**
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
  /// **'The installer could not determine whether this disk is a system disk. Check the target before flashing.'**
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
  /// **'Choose which offline maps to download. Installation is selected later with the rest of the plan.'**
  String get regionHint;

  /// No description provided for @skipOfflineMaps.
  ///
  /// In en, this message translates to:
  /// **'Do not download offline maps'**
  String get skipOfflineMaps;

  /// No description provided for @bluetoothPairingHeading.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth pairing'**
  String get bluetoothPairingHeading;

  /// No description provided for @bluetoothPairingHint.
  ///
  /// In en, this message translates to:
  /// **'Pair a Bluetooth device with the scooter.'**
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

  /// No description provided for @pairingStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start Bluetooth pairing: {error}'**
  String pairingStartFailed(String error);

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
  /// **'Select the scooter in your device\'s Bluetooth settings and pair it. Select Finish when complete.'**
  String get pairingActiveHint;

  /// No description provided for @pairingDone.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
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
  /// **'Register the NFC cards you want to use to unlock and lock the scooter. Select Start, hold each card to the reader one at a time, then select Finish.'**
  String get keycardLearningBody;

  /// No description provided for @keycardLearnedAck.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 keycard registered} other{{count} keycards registered}}. Select Continue to finish, or Add more cards to register additional cards.'**
  String keycardLearnedAck(int count);

  /// No description provided for @keycardLearningTapped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No keycards tapped yet} one{1 keycard tapped} other{{count} keycards tapped}}'**
  String keycardLearningTapped(int count);

  /// No description provided for @keycardKnownAdded.
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =0{None of the {total} saved keycards could be registered} one{1 of {total} saved keycards registered} other{{added} of {total} saved keycards registered}}'**
  String keycardKnownAdded(int added, int total);

  /// No description provided for @keycardCardsChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking registered cards...'**
  String get keycardCardsChecking;

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
  /// **'Hold each card to the reader. Select Finish when complete.'**
  String get keycardLearningActiveHint;

  /// No description provided for @keycardStopLearning.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get keycardStopLearning;

  /// No description provided for @keycardStopScanning.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get keycardStopScanning;

  /// No description provided for @keycardSkipConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip without a keycard?'**
  String get keycardSkipConfirmTitle;

  /// No description provided for @keycardSkipConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'No keycard will be registered, so a keycard cannot unlock the scooter. Configure Bluetooth later if you need another unlock method.'**
  String get keycardSkipConfirmBody;

  /// No description provided for @keycardSkipConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Skip anyway'**
  String get keycardSkipConfirmAction;

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
  /// **'This deletes the master card and every registered unlock card on the scooter. You will need to register them again. Continue?'**
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
  /// **'A master card manages other keycards but cannot unlock the scooter. Use a separate card that is not already registered as an unlock card.'**
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

  /// No description provided for @keycardMasterStageStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Master card setup could not be started'**
  String get keycardMasterStageStartFailed;

  /// No description provided for @keycardMasterStageRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get keycardMasterStageRetryButton;

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
  /// **'Show log'**
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

  /// No description provided for @installAnother.
  ///
  /// In en, this message translates to:
  /// **'Install another scooter'**
  String get installAnother;

  /// No description provided for @keepCachedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Keep cached downloads'**
  String get keepCachedDownloads;

  /// No description provided for @finishKeepDownloadedFiles.
  ///
  /// In en, this message translates to:
  /// **'Finish and keep downloaded files'**
  String get finishKeepDownloadedFiles;

  /// No description provided for @phaseInstallPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Installation plan'**
  String get phaseInstallPlanTitle;

  /// No description provided for @phaseInstallPlanDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an action for each board'**
  String get phaseInstallPlanDescription;

  /// No description provided for @phaseMdbArtifactTitle.
  ///
  /// In en, this message translates to:
  /// **'Update MDB'**
  String get phaseMdbArtifactTitle;

  /// No description provided for @phaseMdbArtifactDescription.
  ///
  /// In en, this message translates to:
  /// **'Install the firmware update'**
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
  /// **'Choose installation actions'**
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
  /// **'Erases settings and trip history. Keycards and maps are set up again later in this run'**
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

  /// No description provided for @actionCleanInstallDetailDbcTiles.
  ///
  /// In en, this message translates to:
  /// **'Erases the offline maps. They are installed again in this run'**
  String get actionCleanInstallDetailDbcTiles;

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

  /// No description provided for @planInstallTiles.
  ///
  /// In en, this message translates to:
  /// **'Update the offline maps'**
  String get planInstallTiles;

  /// No description provided for @planInstallTilesDetail.
  ///
  /// In en, this message translates to:
  /// **'Adds a dashboard step: the maps go to the main board, then the cable swaps back and the scooter copies them over.'**
  String get planInstallTilesDetail;

  /// No description provided for @planTilesNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded. Offline maps were skipped on the first screen.'**
  String get planTilesNotDownloaded;

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
  /// **'the MDB firmware package'**
  String get assetMdbArtifact;

  /// No description provided for @assetDbcArtifact.
  ///
  /// In en, this message translates to:
  /// **'the DBC firmware package'**
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
  /// **'Uploading firmware update...'**
  String get artifactStaging;

  /// No description provided for @artifactInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing firmware update ({percent}%)'**
  String artifactInstalling(int percent);

  /// No description provided for @artifactVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying installed version...'**
  String get artifactVerifying;

  /// No description provided for @waitingForDbcUpload.
  ///
  /// In en, this message translates to:
  /// **'Still transferring the dashboard files'**
  String get waitingForDbcUpload;

  /// No description provided for @artifactStillMinimal.
  ///
  /// In en, this message translates to:
  /// **'The MDB restarted with the bootstrap image, so the firmware update was not installed. Retry, or write the full image instead.'**
  String get artifactStillMinimal;

  /// No description provided for @artifactVersionMismatch.
  ///
  /// In en, this message translates to:
  /// **'After restart, the MDB reports {found} rather than {expected}. The update was rolled back. Retry, or write the full image instead.'**
  String artifactVersionMismatch(String found, String expected);

  /// No description provided for @artifactInstallFailedHeading.
  ///
  /// In en, this message translates to:
  /// **'Firmware install failed'**
  String get artifactInstallFailedHeading;

  /// No description provided for @artifactStagingInBackground.
  ///
  /// In en, this message translates to:
  /// **'Uploading the firmware package in the background…'**
  String get artifactStagingInBackground;

  /// No description provided for @artifactNoneDownloaded.
  ///
  /// In en, this message translates to:
  /// **'No firmware update was downloaded for this board.'**
  String get artifactNoneDownloaded;

  /// No description provided for @dbcImageMissing.
  ///
  /// In en, this message translates to:
  /// **'The DBC system image this plan needs is missing.'**
  String get dbcImageMissing;

  /// No description provided for @artifactRebootTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the scooter after the reboot.'**
  String get artifactRebootTimeout;

  /// No description provided for @artifactRebootTimeoutHint.
  ///
  /// In en, this message translates to:
  /// **'Check that the USB cable is firmly connected at both ends and that the scooter has power. A scooter with no main battery fitted can also go to sleep on its own while it waits.'**
  String get artifactRebootTimeoutHint;

  /// No description provided for @artifactRetryDetail.
  ///
  /// In en, this message translates to:
  /// **'Retries from the previous step without reformatting the board.'**
  String get artifactRetryDetail;

  /// No description provided for @artifactFullImageDetail.
  ///
  /// In en, this message translates to:
  /// **'Rewrites the entire board and erases settings, registered keycards, and trips.'**
  String get artifactFullImageDetail;

  /// No description provided for @artifactPreflightNoMender.
  ///
  /// In en, this message translates to:
  /// **'This board has no update client, so it cannot install a firmware update package.'**
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
  /// **'Writing the full image reformats the data partition. Settings, registered keycards, offline maps, and trip history are lost.\n\nRetrying the firmware update uses the existing data rather than reformatting it. Write the full image only if the update continues to fail.'**
  String get fallBackWipeBody;

  /// No description provided for @fallBackWipeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Erase and write the full image'**
  String get fallBackWipeConfirm;

  /// No description provided for @dbcCleanInstallButton.
  ///
  /// In en, this message translates to:
  /// **'Erase and install DBC'**
  String get dbcCleanInstallButton;

  /// No description provided for @dbcCleanInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'This erases the DBC'**
  String get dbcCleanInstallTitle;

  /// No description provided for @dbcCleanInstallBody.
  ///
  /// In en, this message translates to:
  /// **'The dashboard version shown here was last reported to the main board and may be out of date. A dashboard selected for update may not have an update client. Installing from scratch writes the bootstrap image first, reformats the DBC data partition, and removes offline maps. Settings, registered keycards, and trip history on the main board are unaffected.\n\nThis requires another cable swap. The installer uploads the files, then you reconnect and secure the dashboard cable to the main board. The scooter completes the remaining work.'**
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

  /// No description provided for @healthVersionPlan.
  ///
  /// In en, this message translates to:
  /// **'Currently installed: {current} - To install: {target}'**
  String healthVersionPlan(String current, String target);

  /// No description provided for @distroStock.
  ///
  /// In en, this message translates to:
  /// **'unu scooterOS'**
  String get distroStock;

  /// No description provided for @distroLibrescoot.
  ///
  /// In en, this message translates to:
  /// **'Librescoot'**
  String get distroLibrescoot;

  /// No description provided for @healthAuxVoltage.
  ///
  /// In en, this message translates to:
  /// **'{mv} mV'**
  String healthAuxVoltage(int mv);

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
  /// **'Proceed without CBB'**
  String get proceedWithoutCbb;

  /// No description provided for @proceedWithoutMainBattery.
  ///
  /// In en, this message translates to:
  /// **'Proceed without main battery'**
  String get proceedWithoutMainBattery;

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
  /// **'Dashboard work usually takes 10 to 20 minutes.'**
  String get dbcFlashDurationHeadline;

  /// No description provided for @finishHandoverRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring settings and services'**
  String get finishHandoverRestoring;

  /// No description provided for @finishBlockedHeading.
  ///
  /// In en, this message translates to:
  /// **'The install did not finish'**
  String get finishBlockedHeading;

  /// No description provided for @finishBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'The connection to the scooter was lost before the final status check. The dashboard or map transfer may not have started or completed.\n\nCheck the USB cable at both ends, then select Try again. If the connection cannot be restored, close the installer and start it again to resume from the recorded installation state.'**
  String get finishBlockedBody;

  /// No description provided for @finishBlockedRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get finishBlockedRetry;

  /// No description provided for @finishHandoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Finishing installation'**
  String get finishHandoverTitle;

  /// No description provided for @finishHandoverBody.
  ///
  /// In en, this message translates to:
  /// **'Wait for the scooter to complete the final steps before disconnecting USB.'**
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
  /// **'Continue'**
  String get dbcFlashAllDone;

  /// No description provided for @dbcFlashSequence.
  ///
  /// In en, this message translates to:
  /// **'The scooter now completes the requested dashboard work. Progress appears on the dashboard. Stay with the scooter until it completes or reports an error.'**
  String get dbcFlashSequence;

  /// No description provided for @dbcFlashDoNotDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Do not disconnect USB or power while this runs.'**
  String get dbcFlashDoNotDisconnect;

  /// No description provided for @dbcFlashDoneSignal.
  ///
  /// In en, this message translates to:
  /// **'Complete: the scooter returns to its normal state. Verify that it unlocks before riding.'**
  String get dbcFlashDoneSignal;

  /// No description provided for @dbcFlashFailSignal.
  ///
  /// In en, this message translates to:
  /// **'Error: the dashboard LED blinks red and the hazard lights turn on. Reconnect USB to the MDB and retrieve the log here.'**
  String get dbcFlashFailSignal;

  /// No description provided for @dbcFlashLedIsTheSignal.
  ///
  /// In en, this message translates to:
  /// **'The LED on the dashboard is the error signal: if it blinks red, something has gone wrong.'**
  String get dbcFlashLedIsTheSignal;

  /// No description provided for @dbcFlashSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get dbcFlashSomethingWrong;

  /// No description provided for @phaseKeycardSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Keycard setup'**
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
  /// **'MDB disconnected. The scooter is installing the DBC...'**
  String get mdbDisconnectedFlashingDbc;

  /// No description provided for @mdbReconnectedVerifying.
  ///
  /// In en, this message translates to:
  /// **'MDB reconnected. Verifying...'**
  String get mdbReconnectedVerifying;

  /// No description provided for @logDebugShell.
  ///
  /// In en, this message translates to:
  /// **'Log and debug shell'**
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

  /// No description provided for @debugShell.
  ///
  /// In en, this message translates to:
  /// **'Debug shell'**
  String get debugShell;

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
  /// **'Using your scooter'**
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

  /// No description provided for @substepCheckCompletionRecord.
  ///
  /// In en, this message translates to:
  /// **'Check completion record'**
  String get substepCheckCompletionRecord;

  /// No description provided for @substepReadStatus.
  ///
  /// In en, this message translates to:
  /// **'Check pending installation status'**
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
  /// **'The MDB has not returned as a USB network device after {minutes} minutes. Initial dashboard setup can take longer while storage and offline maps are prepared. You can keep waiting, retry verification, retry the dashboard work, or continue to the finish screen.'**
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
  /// **'Ready to ride'**
  String get finalRide;

  /// No description provided for @finalRideDesc.
  ///
  /// In en, this message translates to:
  /// **'Verify that the scooter unlocks. Use a registered keycard, or Bluetooth if it is configured.'**
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

  /// No description provided for @substepCheckExisting.
  ///
  /// In en, this message translates to:
  /// **'Check existing files'**
  String get substepCheckExisting;

  /// No description provided for @substepVerifying.
  ///
  /// In en, this message translates to:
  /// **'verifying {filename}'**
  String substepVerifying(String filename);

  /// No description provided for @substepUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload {filename}'**
  String substepUploadFile(String filename);

  /// No description provided for @substepAlreadyThere.
  ///
  /// In en, this message translates to:
  /// **'already on the scooter'**
  String get substepAlreadyThere;

  /// No description provided for @substepFileImage.
  ///
  /// In en, this message translates to:
  /// **'dashboard image'**
  String get substepFileImage;

  /// No description provided for @substepFileImageMap.
  ///
  /// In en, this message translates to:
  /// **'dashboard image checksums'**
  String get substepFileImageMap;

  /// No description provided for @substepFileFirmware.
  ///
  /// In en, this message translates to:
  /// **'dashboard firmware'**
  String get substepFileFirmware;

  /// No description provided for @substepFileMaps.
  ///
  /// In en, this message translates to:
  /// **'map tiles'**
  String get substepFileMaps;

  /// No description provided for @substepFileRouting.
  ///
  /// In en, this message translates to:
  /// **'routing data'**
  String get substepFileRouting;

  /// No description provided for @substepUploadStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting upload...'**
  String get substepUploadStarting;

  /// No description provided for @substepUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Upload complete'**
  String get substepUploadComplete;

  /// No description provided for @substepUploadNothingToDo.
  ///
  /// In en, this message translates to:
  /// **'All files are already on the scooter'**
  String get substepUploadNothingToDo;

  /// No description provided for @substepRemaining.
  ///
  /// In en, this message translates to:
  /// **'{mins}m {secs}s remaining'**
  String substepRemaining(int mins, int secs);

  /// No description provided for @substepUploadFlasher.
  ///
  /// In en, this message translates to:
  /// **'Upload flasher tool'**
  String get substepUploadFlasher;

  /// No description provided for @substepUploadFwTools.
  ///
  /// In en, this message translates to:
  /// **'Upload DBC bootloader tools'**
  String get substepUploadFwTools;

  /// No description provided for @substepUploadScript.
  ///
  /// In en, this message translates to:
  /// **'Upload installation script'**
  String get substepUploadScript;

  /// No description provided for @waitStepCounter.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String waitStepCounter(int current, int total);

  /// No description provided for @waitRemaining.
  ///
  /// In en, this message translates to:
  /// **'about {duration} left'**
  String waitRemaining(String duration);

  /// No description provided for @waitElapsed.
  ///
  /// In en, this message translates to:
  /// **'{time} elapsed'**
  String waitElapsed(String time);

  /// No description provided for @waitLongerThanUsual.
  ///
  /// In en, this message translates to:
  /// **'{time} · longer than usual'**
  String waitLongerThanUsual(String time);

  /// No description provided for @waitShowLog.
  ///
  /// In en, this message translates to:
  /// **'Show log'**
  String get waitShowLog;

  /// No description provided for @waitHideLog.
  ///
  /// In en, this message translates to:
  /// **'Hide log'**
  String get waitHideLog;

  /// No description provided for @blePairingWhy.
  ///
  /// In en, this message translates to:
  /// **'A paired Bluetooth device can unlock the scooter and show its state through a compatible app. You can skip this and pair a device later.'**
  String get blePairingWhy;

  /// No description provided for @blePairingStep1.
  ///
  /// In en, this message translates to:
  /// **'Open Bluetooth settings'**
  String get blePairingStep1;

  /// No description provided for @blePairingStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Use your device\'s Bluetooth settings or a compatible app.'**
  String get blePairingStep1Desc;

  /// No description provided for @blePairingStep2.
  ///
  /// In en, this message translates to:
  /// **'Pick the scooter from the device list'**
  String get blePairingStep2;

  /// No description provided for @blePairingStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'It shows up under the address given here.'**
  String get blePairingStep2Desc;

  /// No description provided for @blePairingStep3.
  ///
  /// In en, this message translates to:
  /// **'Confirm the PIN'**
  String get blePairingStep3;

  /// No description provided for @blePairingStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'The PIN appears on this screen when your device requests it.'**
  String get blePairingStep3Desc;

  /// No description provided for @blePairingOneAtATime.
  ///
  /// In en, this message translates to:
  /// **'The scooter holds one Bluetooth connection at a time. If a device is already connected, disconnect it there first.'**
  String get blePairingOneAtATime;

  /// No description provided for @keycardWhy.
  ///
  /// In en, this message translates to:
  /// **'A registered keycard can unlock the scooter without Bluetooth. You can register several cards and add more later. A clean install removes previously registered cards.'**
  String get keycardWhy;

  /// No description provided for @keycardStep1.
  ///
  /// In en, this message translates to:
  /// **'Start learning'**
  String get keycardStep1;

  /// No description provided for @keycardStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'The scooter then waits for a card.'**
  String get keycardStep1Desc;

  /// No description provided for @keycardStep2.
  ///
  /// In en, this message translates to:
  /// **'Hold the card against the reader'**
  String get keycardStep2;

  /// No description provided for @keycardStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'The reader sits at the front of the dashboard. Hold it there until the installer counts the card.'**
  String get keycardStep2Desc;

  /// No description provided for @keycardStep3.
  ///
  /// In en, this message translates to:
  /// **'Press Finish'**
  String get keycardStep3;

  /// No description provided for @keycardStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'This ends registration and activates the cards.'**
  String get keycardStep3Desc;

  /// No description provided for @keycardPanelHeading.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get keycardPanelHeading;

  /// No description provided for @keycardReaderPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get keycardReaderPreparing;

  /// No description provided for @keycardReaderReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get keycardReaderReady;

  /// No description provided for @keycardRetryReader.
  ///
  /// In en, this message translates to:
  /// **'Retry reader'**
  String get keycardRetryReader;

  /// No description provided for @keycardReaderUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Reader not reachable'**
  String get keycardReaderUnreachable;

  /// No description provided for @keycardReaderScanning.
  ///
  /// In en, this message translates to:
  /// **'Hold a card to the reader'**
  String get keycardReaderScanning;

  /// No description provided for @keycardCardsTaught.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No keycards registered} =1{1 keycard registered} other{{count} keycards registered}}'**
  String keycardCardsTaught(int count);

  /// No description provided for @keycardMastersRegistered.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 master card registered} other{{count} master cards registered}}'**
  String keycardMastersRegistered(int count);

  /// No description provided for @keycardNeedOneToFinish.
  ///
  /// In en, this message translates to:
  /// **'Register at least one card to finish.'**
  String get keycardNeedOneToFinish;

  /// No description provided for @keycardPreparingReader.
  ///
  /// In en, this message translates to:
  /// **'Preparing the card reader...'**
  String get keycardPreparingReader;

  /// No description provided for @blePairingDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get blePairingDeviceName;

  /// No description provided for @blePairingStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Pairing not started'**
  String get blePairingStateIdle;

  /// No description provided for @blePairingStateVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible, waiting for a device'**
  String get blePairingStateVisible;

  /// No description provided for @blePinConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm this PIN on your device'**
  String get blePinConfirmTitle;

  /// No description provided for @blePinConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Your device shows the same number. If they match, confirm it there.'**
  String get blePinConfirmHint;

  /// No description provided for @blePairingStep2DescCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare the name and address on the right if several devices show up.'**
  String get blePairingStep2DescCompare;

  /// No description provided for @blePairingStep3DescOverlay.
  ///
  /// In en, this message translates to:
  /// **'The installer displays it in large type when your device requests it.'**
  String get blePairingStep3DescOverlay;

  /// No description provided for @dbcSayInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing firmware, this takes a few minutes'**
  String get dbcSayInstalling;

  /// No description provided for @dbcSayInstalled.
  ///
  /// In en, this message translates to:
  /// **'Firmware installed, display restarting'**
  String get dbcSayInstalled;

  /// Shown on the dashboard once the new firmware is up. The version is filled by the trampoline script on the vehicle, not here.
  ///
  /// In en, this message translates to:
  /// **'Firmware {version} is running'**
  String dbcSayRunning(String version);

  /// No description provided for @dbcSayMaps.
  ///
  /// In en, this message translates to:
  /// **'Transferring maps'**
  String get dbcSayMaps;

  /// No description provided for @dbcSayRouting.
  ///
  /// In en, this message translates to:
  /// **'Transferring routing maps'**
  String get dbcSayRouting;

  /// No description provided for @dbcSayFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation failed'**
  String get dbcSayFailed;

  /// No description provided for @dbcSaySwap1.
  ///
  /// In en, this message translates to:
  /// **'Plug the USB cable back into the MDB and'**
  String get dbcSaySwap1;

  /// No description provided for @dbcSaySwap2.
  ///
  /// In en, this message translates to:
  /// **'continue in the installer on the laptop.'**
  String get dbcSaySwap2;

  /// No description provided for @dbcSayDone.
  ///
  /// In en, this message translates to:
  /// **'Installation complete. Verify that the scooter unlocks.'**
  String get dbcSayDone;

  /// No description provided for @dbcSayBanner.
  ///
  /// In en, this message translates to:
  /// **'Installing Librescoot'**
  String get dbcSayBanner;

  /// No description provided for @dbcSayFailOnboot.
  ///
  /// In en, this message translates to:
  /// **'The part after the restart failed repeatedly.'**
  String get dbcSayFailOnboot;

  /// No description provided for @dbcSayFailDbc.
  ///
  /// In en, this message translates to:
  /// **'The display did not come back after flashing.'**
  String get dbcSayFailDbc;

  /// Shown on the dashboard when map transfers failed. The count is filled by the trampoline script on the vehicle, not here.
  ///
  /// In en, this message translates to:
  /// **'Map transfers failed: {count}.'**
  String dbcSayFailTiles(String count);

  /// No description provided for @mainBatteryCharge.
  ///
  /// In en, this message translates to:
  /// **'Main battery charge'**
  String get mainBatteryCharge;

  /// No description provided for @riskMainBatteryLow.
  ///
  /// In en, this message translates to:
  /// **'The main battery is nearly empty. The installation uses the 12 V system, but a low main battery leaves little reserve. Charge the scooter after installation.'**
  String get riskMainBatteryLow;

  /// No description provided for @waitingForBoardRecovery.
  ///
  /// In en, this message translates to:
  /// **'The main board found nothing to start and is waiting in its recovery mode. It restarts itself after about two minutes. Leave the cable and the power alone.'**
  String get waitingForBoardRecovery;
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

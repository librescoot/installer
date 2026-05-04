// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Librescoot Installer';

  @override
  String get elevationWarning =>
      'Ohne Administratorrechte gestartet. Einige Funktionen sind ggf. Eingeschränkt.';

  @override
  String get phaseWelcomeTitle => 'Willkommen';

  @override
  String get phaseWelcomeDescription => 'Voraussetzungen und Firmware-Auswahl';

  @override
  String get phaseNoticesTitle => 'Hinweise';

  @override
  String get phaseNoticesDescription => 'Wichtige Hinweise vor dem Start';

  @override
  String get phasePhysicalPrepTitle => 'Vorbereitung';

  @override
  String get phasePhysicalPrepDescription => 'Fußraum öffnen, USB verbinden';

  @override
  String get phaseMdbConnectTitle => 'MDB verbinden';

  @override
  String get phaseMdbConnectDescription => 'Gerät erkennen und SSH aufbauen';

  @override
  String get phaseHealthCheckTitle => 'Statusprüfung';

  @override
  String get phaseHealthCheckDescription => 'Roller-Bereitschaft prüfen';

  @override
  String get phaseBatteryRemovalTitle => 'Akku entfernen';

  @override
  String get phaseBatteryRemovalDescription =>
      'Sitzbank öffnen, Fahrakku entnehmen';

  @override
  String get phaseMdbToUmsTitle => 'MDB → UMS';

  @override
  String get phaseMdbToUmsDescription => 'Bootloader für Flashen konfigurieren';

  @override
  String get phaseMdbFlashTitle => 'MDB flashen';

  @override
  String get phaseMdbFlashDescription => 'Firmware auf MDB schreiben';

  @override
  String get phaseScooterPrepTitle => 'Roller vorbereiten';

  @override
  String get phaseScooterPrepDescription => 'CBB und AUX trennen';

  @override
  String get phaseMdbBootTitle => 'MDB-Boot';

  @override
  String get phaseMdbBootDescription =>
      'AUX wieder anschließen, auf Boot warten';

  @override
  String get phaseCbbReconnectTitle => 'CBB anschließen';

  @override
  String get phaseCbbReconnectDescription =>
      'CBB für DBC-Flash wieder anschließen';

  @override
  String get phaseDbcPrepTitle => 'DBC vorbereiten';

  @override
  String get phaseDbcPrepDescription => 'DBC-Image und Karten hochladen';

  @override
  String get phaseDbcFlashTitle => 'DBC flashen';

  @override
  String get phaseDbcFlashDescription => 'Autonome DBC-Installation';

  @override
  String get phaseReconnectTitle => 'Verbinden';

  @override
  String get phaseReconnectDescription => 'DBC-Installation prüfen';

  @override
  String get phaseBluetoothPairingTitle => 'Bluetooth';

  @override
  String get phaseBluetoothPairingDescription =>
      'Handy oder andere Geräte koppeln';

  @override
  String get phaseFinishTitle => 'Fertig';

  @override
  String get phaseFinishDescription => 'Zusammenbau und Abschluss';

  @override
  String get majorStepPrepare => 'Vorbereitung';

  @override
  String get majorStepConnect => 'Verbinden';

  @override
  String get majorStepMdbFlash => 'MDB flashen';

  @override
  String get majorStepDbcFlash => 'DBC flashen';

  @override
  String get majorStepFinish => 'Abschluss';

  @override
  String get majorStepSkippedSuffix => 'übersprungen';

  @override
  String get welcomeHeading => 'Willkommen beim Librescoot Installer';

  @override
  String get welcomeSubheading =>
      'Dieser Assistent führt dich durch die Installation der Librescoot-Firmware auf deinem Roller.';

  @override
  String get whatYouNeed => 'Was du brauchst:';

  @override
  String get prerequisiteScrewdriverPH2 =>
      'PH2-Kreuz- oder H4-Innensechskantschraubendreher für die vier Fußbrettschrauben';

  @override
  String get prerequisiteScrewdriverFlat =>
      'Schlitz- oder PH1-Schraubendreher für das USB-Kabel';

  @override
  String get prerequisiteUsbCable => 'USB-Kabel (Laptop zu Mini-B)';

  @override
  String get prerequisiteTime => 'Ungefähr 20 Minuten Zeit';

  @override
  String get reliabilityWarningTitle => 'Bevor du startest';

  @override
  String get reliabilityWarningBody =>
      'Das Flashen dauert mehrere Minuten, und jeder USB-Wackler oder Laptop-Standby mittendrin hinterlässt das MDB in einem inkonsistenten Zustand. Bitte prüfen:\n• Ein zuverlässiges USB-Kabel, an beiden Enden fest eingesteckt. Wackelkontakte sind die häufigste Ursache für gescheiterte Installationen\n• Laptop am Netzteil oder vollgeladen. Energiesparmodus / Standby unterbricht den Flash\n• Möglichst direkter USB-Port, kein USB-Hub\n• Während des Flashens nichts umstecken oder bewegen';

  @override
  String get noPowerCycleWarningTitle =>
      'Während der Installation NICHTS vom Strom trennen oder neu starten';

  @override
  String get noPowerCycleWarningBody =>
      'Wenn irgendwas hängt, keine Rückmeldung gibt oder komisch aussieht: erstmal PAUSE und im Discord nachfragen. Nicht den AUX-Akku ziehen, nicht die CBB abklemmen, nicht USB rausreißen, weder Roller noch Laptop neu starten. Der Installer kann aus fast jedem Zustand wieder rauskommen. Aber nur, wenn du nicht reingrätschst. Mittendrin den Strom trennen ist das, was Roller bricked.';

  @override
  String get noticesHeading => 'Vor dem Weitermachen lesen';

  @override
  String get noticesSubheading =>
      'Zwei Dinge, die deine Installation retten, wenn du sie ernst nimmst.';

  @override
  String get noticesAcknowledgeButton => 'Gelesen, weitermachen';

  @override
  String get noticesWaitingForDownloads => 'Firmware wird geladen...';

  @override
  String get noticesContinueOfflineAnyway =>
      'Trotzdem weiter (am Roller habe ich Internet)';

  @override
  String get backButton => 'Zurück';

  @override
  String get elevationRequiredTitle => 'Administratorrechte erforderlich';

  @override
  String get elevationRequiredBody =>
      'Der Librescoot Installer benötigt Administratorrechte, um auf den Speicher des Rollers zu schreiben und das Netzwerk-Interface zu konfigurieren. Die Berechtigungsanfrage wurde abgelehnt oder konnte nicht angezeigt werden.\n\nKlicke auf Weiter, um den Dialog zu schließen, und versuche es erneut. Wenn du die Anfrage immer wieder ablehnst, kann der Installer nicht fortfahren.';

  @override
  String get elevationNoticeWelcome =>
      'Beim Klick auf Installation starten fragt dein System nach Administratorrechten. Der Installer braucht sie, um auf den Speicher des Rollers zu schreiben und das Netzwerk zu konfigurieren.';

  @override
  String get requestingAdminPrivileges =>
      'Administratorrechte werden angefragt...';

  @override
  String get quitButton => 'Beenden';

  @override
  String get firmwareChannel => 'Firmware-Kanal';

  @override
  String get channelStable => 'Stabil';

  @override
  String get channelTesting => 'Testing';

  @override
  String get channelNightly => 'Nightly';

  @override
  String get channelStableDesc => 'Getestet und zuverlässig';

  @override
  String get channelTestingDesc => 'Neueste Features, evtl. noch ungeschliffen';

  @override
  String get channelNightlyDesc => 'Täglich aus main gebaut, für Entwickler';

  @override
  String get channelNoReleases => 'Keine Releases verfügbar';

  @override
  String get loadingChannels => 'Verfügbare Kanäle werden geladen...';

  @override
  String get region => 'Region';

  @override
  String get selectRegion => 'Region auswählen';

  @override
  String get startInstallation => 'Installation starten';

  @override
  String get selectRegionError =>
      'Bitte wähle eine Region für die Offline-Karten';

  @override
  String get resolvingReleases => 'Releases werden aufgelöst...';

  @override
  String get physicalPrepHeading => 'Physische Vorbereitung';

  @override
  String get physicalPrepSubheading =>
      'Bereite deinen Roller für die USB-Verbindung vor.';

  @override
  String get removeFootwellCover => 'Fußraumabdeckung entfernen';

  @override
  String get removeFootwellCoverDesc =>
      'Vier Schrauben lösen. Ab Werk PH2 Kreuzschrauben, bei guten Werkstätten H4 Innensechskant oder Torx.';

  @override
  String get removeFootwellCoverImage =>
      '[Foto: Fußraumabdeckung mit markierten Schraubenpositionen]';

  @override
  String get unscrewUsbCable => 'USB-Kabel vom MDB lösen';

  @override
  String get unscrewUsbCableDesc =>
      'Trenne das interne DBC-USB-Kabel vom MDB-Board. Verwende einen Schlitz- oder PH1-Schraubendreher.';

  @override
  String get unscrewUsbCableImage =>
      '[Foto: USB-Mini-B-Anschluss am MDB, Nahaufnahme]';

  @override
  String get connectLaptopUsb => 'Laptop-USB-Kabel anschließen';

  @override
  String get connectLaptopUsbDesc =>
      'Stecke dein USB-Kabel in den MDB-Port und verbinde das andere Ende mit deinem Laptop.';

  @override
  String get doneDetectDevice => 'Fertig. Gerät erkennen';

  @override
  String get connectingToMdb => 'Verbindung zum MDB wird hergestellt';

  @override
  String get waitingForUsbDevice => 'Warte auf USB-Gerät...';

  @override
  String get waitingForRndis =>
      'Warte auf USB-Gerät... Stelle sicher, dass dein Laptop per USB mit dem MDB verbunden ist.';

  @override
  String get checkingRndisDriver => 'RNDIS-Treiber wird geprüft...';

  @override
  String get installingRndisDriver => 'RNDIS-Treiber wird installiert...';

  @override
  String get configuringNetwork => 'Netzwerk wird konfiguriert...';

  @override
  String get connectingSsh => 'SSH-Verbindung wird aufgebaut...';

  @override
  String get waitingForUnlock => 'Roller entsperren, um fortzufahren...';

  @override
  String get unlockTimeout =>
      'Zeitlimit beim Warten auf Entsperrung. Roller entsperren und erneut versuchen.';

  @override
  String get awaitingUnlockHeading => 'Roller entsperren';

  @override
  String get awaitingUnlockDetail =>
      'Bitte entsperre deinen Roller, um fortzufahren. Halte deine Schlüsselkarte an den Leser oder benutze ein gekoppeltes Handy.';

  @override
  String get awaitingParkHeading => 'Roller parken';

  @override
  String get awaitingParkDetail =>
      'Bitte parke deinen Roller (Seitenständer ausklappen), um fortzufahren.';

  @override
  String get awaitingParkContinueAnyway => 'Trotzdem weiter';

  @override
  String get lockingScooter => 'Roller wird für das Flashen gesperrt...';

  @override
  String get connected => 'Verbunden!';

  @override
  String sshConnectionFailed(String error) {
    return 'SSH-Verbindung fehlgeschlagen: $error. Kabel prüfen und erneut versuchen.';
  }

  @override
  String get manualPasswordTitle => 'Root-Passwort erforderlich';

  @override
  String get manualPasswordPrompt =>
      'Das Root-Passwort konnte nicht automatisch ermittelt werden. Bitte gib das Root-Passwort für dieses Gerät ein.';

  @override
  String manualPasswordPromptVersion(String version) {
    return 'Das Root-Passwort für Firmware $version konnte nicht automatisch ermittelt werden. Bitte gib das Root-Passwort für dieses Gerät ein.';
  }

  @override
  String manualPasswordPromptRetry(int remaining) {
    return 'Das Passwort war falsch. Bitte erneut versuchen (noch $remaining Versuche).';
  }

  @override
  String get manualPasswordFieldLabel => 'Passwort';

  @override
  String get manualPasswordSubmit => 'Verbinden';

  @override
  String get untestedFirmwareHeading => 'Ungetestete Firmware-Version';

  @override
  String untestedFirmwareBody(String version) {
    return 'Die Installation auf Firmware-Versionen älter als 1.12.0 ist nicht getestet (deine: $version). Der Installer sollte trotzdem funktionieren. Über Feedback im Librescoot-Discord freuen wir uns.';
  }

  @override
  String get openLibrescootDiscord => 'Librescoot-Discord öffnen';

  @override
  String get healthCheckHeading => 'Statusprüfung';

  @override
  String get verifyingReadiness => 'Roller-Bereitschaft wird geprüft...';

  @override
  String get continueButton => 'Weiter';

  @override
  String get retryButton => 'Erneut versuchen';

  @override
  String get proceedAtOwnRisk => 'Auf eigenes Risiko fortfahren';

  @override
  String get auxBatteryCharge => 'AUX-Akku-Ladung';

  @override
  String get cbbStateOfHealth => 'CBB-Zustand';

  @override
  String get cbbCharge => 'CBB-Ladung';

  @override
  String get mainBattery => 'Fahrakku';

  @override
  String get present => 'vorhanden';

  @override
  String get notPresent => 'nicht vorhanden';

  @override
  String get riskAuxLow =>
      'Niedrige 12V-Batterie könnte MDB oder DBC während des Flashens abschalten. LED-Anzeigen könnten ebenfalls ausfallen. Sitzbank mit eingesetztem Fahrakku schließen und warten, bis sie geladen ist.';

  @override
  String get riskCbbSoh =>
      'Schlechter CBB-Zustand kann zu unzuverlässiger Stromversorgung während des Flashens führen.';

  @override
  String get riskCbbCharge =>
      'Niedriger CBB-Ladezustand erhöht das Risiko eines Stromausfalls beim DBC-Flash. Sitzbank mit eingesetztem Fahrakku schließen und warten, bis die CBB geladen ist.';

  @override
  String get riskNoBattery =>
      'Ohne den Fahrakku entlädt sich die 12V-Hilfsbatterie schneller. Der Roller könnte bei längeren Vorgängen herunterfahren.';

  @override
  String get batteryRemovalHeading => 'Akku entfernen';

  @override
  String get seatboxOpening => 'Sitzbank wird geöffnet...';

  @override
  String get seatboxOpeningDesc => 'Die Sitzbank öffnet sich automatisch.';

  @override
  String get removeMainBattery => 'Fahrakku entnehmen';

  @override
  String get removeMainBatteryDesc => 'Hebe den Fahrakku aus der Sitzbank.';

  @override
  String get openSeatbox => 'Sitzbank öffnen';

  @override
  String get mainBatteryAlreadyRemoved => 'Fahrakku bereits entnommen';

  @override
  String get openingSeatbox => 'Sitzbank wird geöffnet...';

  @override
  String get waitingForBatteryRemoval => 'Warte auf Akku-Entnahme...';

  @override
  String get batteryRemoved => 'Akku entnommen!';

  @override
  String get configuringMdbBootloader => 'MDB-Bootloader wird konfiguriert';

  @override
  String get preparing => 'Vorbereitung...';

  @override
  String get uploadingBootloaderTools =>
      'Bootloader-Tools werden hochgeladen...';

  @override
  String get rebootingMdbUms =>
      'MDB wird im Mass-Storage-Modus neu gestartet...';

  @override
  String get waitingForUmsDevice => 'Warte auf UMS-Gerät...';

  @override
  String get readyToFlash => 'Bereit zum Flashen';

  @override
  String get readyToFlashHint =>
      'Das Gerät ist im Flash-Modus. Du kannst das Gerät mounten, um vor dem Fortfahren manuelle Backups zu erstellen.';

  @override
  String get beginFlashing => 'Flashen starten';

  @override
  String get flashingMdb => 'MDB wird geflasht';

  @override
  String get flashingMdbSubheading =>
      'Zweiphasiges Schreiben: erst Partitionen, dann Bootsektor.';

  @override
  String get waitingForMdbFirmware => 'Warte auf MDB-Firmware-Download...';

  @override
  String get noDevicePath => 'Fehler: kein Gerätepfad verfügbar';

  @override
  String get mdbFlashComplete => 'MDB-Flash abgeschlossen!';

  @override
  String get scooterPrepHeading => 'Roller vorbereiten';

  @override
  String get scooterPrepSubheading =>
      'MDB-Firmware wurde geschrieben. Jetzt für den Neustart vorbereiten.';

  @override
  String get disconnectCbb => 'CBB trennen';

  @override
  String get disconnectCbbDesc =>
      'Der Fahrakku muss bereits entnommen sein, bevor du die CBB trennst. Bei falscher Reihenfolge droht ein elektrischer Schaden.';

  @override
  String get disconnectAuxPole => 'Einen AUX-Pol trennen';

  @override
  String get disconnectAuxPoleDesc =>
      'Entferne NUR den Pluspol (außen, rotes Kabel und Pol), um eine Verpolung zu vermeiden. Dadurch wird das MDB stromlos; die USB-Verbindung geht verloren.';

  @override
  String get disconnectAuxPoleImage =>
      '[Foto: AUX-Batteriepole, Pluspol (rot/außen) markiert]';

  @override
  String get auxDisconnectWarning =>
      'Die USB-Verbindung geht verloren, wenn du AUX trennst. Das ist normal. Der Installer wartet auf den Neustart des MDB.';

  @override
  String get doneCbbAuxDisconnected => 'Fertig. CBB und AUX getrennt';

  @override
  String get waitingForMdbBoot => 'Warte auf MDB-Boot';

  @override
  String get reconnectAuxPole => 'AUX-Pol wieder anschließen';

  @override
  String get reconnectAuxPoleDesc =>
      'Schließe den positiven AUX-Pol wieder an. Das MDB startet und bootet Librescoot.';

  @override
  String get dbcLedHint =>
      'DBC-LED: orange = startet, grün = bootet, aus = läuft';

  @override
  String get mdbStillUms =>
      'MDB immer noch im UMS-Modus. Flash war möglicherweise nicht erfolgreich. Neuer Versuch...';

  @override
  String get mdbDetectedNetwork =>
      'MDB im Netzwerkmodus erkannt. Warte auf stabile Verbindung...';

  @override
  String pingStable(int count) {
    return 'Ping stabil: $count/10';
  }

  @override
  String get waitingStableConnection => 'Warte auf stabile Verbindung...';

  @override
  String get stableConnectionStallHint =>
      'Verbindung noch instabil. Die USB-Netzwerkschnittstelle hat eventuell ihre IP verloren. Auf Linux: NetworkManager stört möglicherweise (IPv6 deaktivieren kann helfen). Details im Log.';

  @override
  String get reconnectingSsh => 'SSH wird neu verbunden...';

  @override
  String sshReconnectionFailed(String error) {
    return 'SSH-Neuverbindung fehlgeschlagen: $error';
  }

  @override
  String get reconnectCbbHeading => 'CBB & Batterie wieder anschließen';

  @override
  String get reconnectCbb =>
      'Hauptbatterie einsetzen und CBB wieder anschließen';

  @override
  String get reconnectCbbDesc =>
      'Setze die Hauptbatterie wieder in die Sitzbank ein und stecke das CBB-Kabel wieder ein. Der Roller braucht volle Leistung für den DBC-Flash.';

  @override
  String get verifyCbbConnection => 'CBB-Verbindung prüfen';

  @override
  String get verifyBatteryPresence => 'Akku prüfen';

  @override
  String get checkingCbb => 'CBB wird geprüft...';

  @override
  String get cbbConnected => 'CBB verbunden!';

  @override
  String waitingForCbb(int attempts) {
    return 'Warte auf CBB... ($attempts)';
  }

  @override
  String get cbbNotDetected => 'CBB nicht erkannt. Bitte Verbindung prüfen.';

  @override
  String get cbbDetectionMayTakeMinutes =>
      'Das kann mehrere Minuten dauern, bitte etwas Geduld.';

  @override
  String get preparingDbcFlash => 'DBC-Flash wird vorbereitet';

  @override
  String get waitingForDownloads => 'Warte auf Abschluss der Downloads...';

  @override
  String get startingTrampoline => 'Trampoline-Skript wird gestartet...';

  @override
  String uploadError(String error) {
    return 'Upload-Fehler: $error';
  }

  @override
  String get dbcFlashInProgress => 'DBC wird geflasht';

  @override
  String get disconnectUsbFromLaptop => 'USB vom Laptop trennen';

  @override
  String get disconnectUsbFromLaptopDesc =>
      'Ziehe das USB-Kabel von deinem Laptop ab.';

  @override
  String get reconnectDbcUsbToMdb => 'DBC-USB-Kabel mit MDB verbinden';

  @override
  String get reconnectDbcUsbToMdbDesc =>
      'Schraube das interne DBC-USB-Kabel wieder an den MDB-Port.';

  @override
  String get mdbFlashingDbcAutonomously =>
      'Das MDB flasht jetzt selbstständig das DBC.';

  @override
  String get watchLightsForProgress =>
      'Beobachte die Rollerbeleuchtung für den Fortschritt:';

  @override
  String get ledFrontRingPulse => 'Frontring atmet';

  @override
  String get ledFrontRingPulseMeaning =>
      'DBC wird vorbereitet (Bootloader, Verbindung)';

  @override
  String get ledFrontRingSolid => 'Frontring leuchtet kurz';

  @override
  String get ledFrontRingSolidMeaning => 'Flash abgeschlossen. Erfolg!';

  @override
  String get disconnectCbbImage => '[Foto: CBB-Stecker im Fußraum]';

  @override
  String get ledBlinkerProgress => 'Blinker leuchten nacheinander';

  @override
  String get ledBlinkerProgressMeaning =>
      'Flash-Fortschritt: dauerhaft an = fertig, pulsierend = läuft';

  @override
  String get ledBootGreen => 'Tacho-LED blinkt grün';

  @override
  String get ledBootGreenMeaning => 'Erfolgreich. Laptop wieder verbinden';

  @override
  String get ledRearLightSolid => 'Alle vier Blinker (Warnblinker) blinken';

  @override
  String get ledRearLightSolidMeaning =>
      'Fehler. Laptop verbinden für Log; Blinker und LED gehen aus, sobald du verbunden bist';

  @override
  String get bootLedGreenReconnect => 'LED blinkt grün';

  @override
  String get rearLightCheckError => 'LED blinkt rot, Warnblinker an';

  @override
  String get verifyingDbcInstallation => 'DBC-Installation wird geprüft';

  @override
  String get reconnectUsbToLaptop => 'USB wieder mit Laptop verbinden...';

  @override
  String get waitingForRndisDevice => 'Warte auf RNDIS-Gerät...';

  @override
  String get readingTrampolineStatus => 'Trampoline-Status wird gelesen...';

  @override
  String get dbcFlashSuccessful => 'DBC-Flash erfolgreich!';

  @override
  String dbcFlashFailed(String message) {
    return 'DBC-Flash fehlgeschlagen: $message';
  }

  @override
  String get dbcFlashError => 'DBC-Flash-Fehler';

  @override
  String get closeButton => 'Schließen';

  @override
  String get trampolineStatusUnknown =>
      'Trampoline-Status unbekannt. Prüfe /data/trampoline.log auf dem MDB.';

  @override
  String get welcomeToLibrescoot => 'Willkommen bei Librescoot!';

  @override
  String get finalSteps => 'Letzte Schritte:';

  @override
  String get disconnectUsbFromLaptopFinal => 'USB vom Laptop trennen';

  @override
  String get disconnectUsbFromLaptopFinalDesc =>
      'Ziehe das USB-Kabel von deinem Laptop ab.';

  @override
  String get reconnectDbcUsbCable => 'DBC-USB-Kabel anschließen';

  @override
  String get reconnectDbcUsbCableDesc =>
      'Schraube das interne DBC-USB-Kabel wieder an das MDB.';

  @override
  String get insertMainBattery => 'Fahrakku einsetzen';

  @override
  String get insertMainBatteryDesc =>
      'Setze den Fahrakku wieder in die Sitzbank ein.';

  @override
  String get closeSeatboxAndFootwell => 'Sitzbank und Fußraum schließen';

  @override
  String get closeSeatboxAndFootwellDesc =>
      'Schließe die Sitzbank und setze die Fußraumabdeckung wieder ein.';

  @override
  String get unlockScooter => 'Roller entsperren';

  @override
  String get unlockScooterDesc =>
      'Nutze eine der angelernten Schlüsselkarten oder entsperre über Bluetooth.';

  @override
  String deleteCachedDownloads(String sizeMb) {
    return 'Heruntergeladene Dateien löschen ($sizeMb MB)';
  }

  @override
  String deletedCache(String sizeMb) {
    return '$sizeMb MB gelöscht';
  }

  @override
  String get downloads => 'Downloads';

  @override
  String get downloadsFinished => 'Downloads abgeschlossen';

  @override
  String get downloadsFinishedHint => 'Du kannst jetzt offline weitermachen.';

  @override
  String get downloadMdbFirmware => 'MDB-Firmware';

  @override
  String get downloadDbcFirmware => 'DBC-Firmware';

  @override
  String get downloadMapTiles => 'Kartenkacheln';

  @override
  String get downloadRoutingTiles => 'Routing-Kacheln';

  @override
  String get homeAppTitle => 'Librescoot Installer';

  @override
  String get notElevated => 'Keine Adminrechte';

  @override
  String get selectFirmwareStep => 'Firmware wählen';

  @override
  String get connectDeviceStep => 'Gerät verbinden';

  @override
  String get configureNetworkStep => 'Netzwerk';

  @override
  String get prepareDeviceStep => 'Vorbereiten';

  @override
  String get flashFirmwareStep => 'Flashen';

  @override
  String get completeStep => 'Fertig';

  @override
  String get selectFirmwareImage => 'Firmware-Image auswählen';

  @override
  String get selectFirmwareHint =>
      'Wähle eine .sdimg.gz-, .sdimg-, .wic.gz-, .wic- oder .img-Firmware-Datei';

  @override
  String get selectFile => 'Datei auswählen';

  @override
  String get changeFile => 'Andere Datei';

  @override
  String get deviceConnected => 'Gerät verbunden';

  @override
  String get connectYourDevice => 'Gerät verbinden';

  @override
  String get connectMdbViaUsb =>
      'Verbinde das MDB per USB und warte auf die Erkennung';

  @override
  String get configuringNetworkHeading => 'Netzwerk wird konfiguriert';

  @override
  String get settingUpNetwork => 'Netzwerkschnittstelle wird eingerichtet...';

  @override
  String get readyToConfigureNetwork =>
      'Bereit, das Netzwerk für die Gerätekommunikation zu konfigurieren';

  @override
  String get configureNetworkButton => 'Netzwerk konfigurieren';

  @override
  String get preparingDevice => 'Gerät wird vorbereitet';

  @override
  String get readyToPrepare => 'Bereit zur Vorbereitung';

  @override
  String get prepareForFlashing => 'Für Flashen vorbereiten';

  @override
  String get flashingFirmware => 'Firmware wird geflasht';

  @override
  String get startFlashing => 'Flashen starten';

  @override
  String get installationComplete => 'Installation abgeschlossen!';

  @override
  String get installationCompleteDesc =>
      'Dein Gerät wurde erfolgreich geflasht.\nEs startet automatisch neu.';

  @override
  String get flashAnotherDevice => 'Weiteres Gerät flashen';

  @override
  String get flashDryRun => 'Flash-Probelauf';

  @override
  String get safetyCheckFailed => 'Sicherheitsprüfung fehlgeschlagen';

  @override
  String get cannotFlashSafety =>
      'Dieses Gerät kann aus Sicherheitsgründen nicht geflasht werden:';

  @override
  String get okButton => 'OK';

  @override
  String get confirmFlashOperation => 'Flash-Vorgang bestätigen';

  @override
  String get aboutToWriteFirmware => 'Du schreibst gleich Firmware auf:';

  @override
  String get deviceLabel => 'Gerät';

  @override
  String get pathLabel => 'Pfad';

  @override
  String get sizeLabel => 'Größe';

  @override
  String get firmwareLabel => 'Firmware:';

  @override
  String get warningsLabel => 'Warnungen:';

  @override
  String get eraseWarning =>
      'Dadurch werden ALLE DATEN auf dem Gerät GELÖSCHT. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get cancelButton => 'Abbrechen';

  @override
  String get flashDeviceButton => 'Gerät flashen';

  @override
  String get installingUsbDriver => 'USB-Treiber wird installiert...';

  @override
  String get usbDriverInstalled => 'USB-Treiber erfolgreich installiert';

  @override
  String driverInstallFailed(String error) {
    return 'Treiber-Installation fehlgeschlagen: $error';
  }

  @override
  String get autoLoadedFirmware =>
      'Firmware automatisch aus dem aktuellen Verzeichnis geladen';

  @override
  String get deviceDisconnected =>
      'Gerät getrennt. Neu verbinden oder auf Mass-Storage-Modus warten.';

  @override
  String get waitingForMdbNetwork => 'Warte auf MDB-Netzwerkstabilisierung...';

  @override
  String get findingNetworkInterface => 'Netzwerkschnittstelle wird gesucht...';

  @override
  String get couldNotFindInterface =>
      'USB-Netzwerkschnittstelle nicht gefunden';

  @override
  String get networkConfigured => 'Netzwerk erfolgreich konfiguriert';

  @override
  String get selectFirmwareFileError =>
      'Bitte wähle eine .sdimg.gz-, .sdimg-, .wic.gz-, .wic- oder .img-Datei';

  @override
  String errorOpeningFilePicker(String error) {
    return 'Fehler beim Öffnen der Dateiauswahl: $error';
  }

  @override
  String get configuringBootloader =>
      'Bootloader wird für Mass-Storage-Modus konfiguriert...';

  @override
  String get rebootingDevice => 'Gerät wird neu gestartet...';

  @override
  String get waitingForMassStorage =>
      'Warte auf Neustart im Mass-Storage-Modus...';

  @override
  String get deviceReadyForFlashing => 'Gerät bereit zum Flashen';

  @override
  String get selectFirmwareDialogTitle => 'Firmware-Image auswählen';

  @override
  String connectedTo(String host, String firmware, String serial) {
    return 'Verbunden mit: $host\nFirmware: $firmware\nSeriennummer: $serial';
  }

  @override
  String connectedToFirmware(String version) {
    return 'Verbunden mit $version';
  }

  @override
  String get unknown => 'Unbekannt';

  @override
  String modeLabel(String mode) {
    return 'Modus: $mode';
  }

  @override
  String get backingUpConfig => 'Gerätekonfiguration wird gesichert...';

  @override
  String get configBackedUp => 'Gerätekonfiguration gesichert';

  @override
  String get noConfigFound => 'Keine Gerätekonfiguration zum Sichern gefunden';

  @override
  String get restoringConfig => 'Gerätekonfiguration wird wiederhergestellt...';

  @override
  String healthCheckFailed(String error) {
    return 'Statusprüfung fehlgeschlagen: $error';
  }

  @override
  String flashError(String error) {
    return 'Flash-Fehler: $error';
  }

  @override
  String get flashComplete => 'Flash abgeschlossen!';

  @override
  String errorPrefix(String error) {
    return 'Fehler: $error';
  }

  @override
  String get regionHint => 'Für Offline-Karten und Navigationsunterstützung';

  @override
  String get skipOfflineMaps => 'Offline-Karten überspringen';

  @override
  String get skipOfflineMapsHint =>
      'Karten können später durch erneutes Ausführen des Installers installiert werden';

  @override
  String get bluetoothPairingHeading => 'Bluetooth-Kopplung';

  @override
  String get bluetoothPairingHint =>
      'Koppele dein Handy oder andere Bluetooth-Geräte mit dem Roller.';

  @override
  String get startPairing => 'Entsperren und Kopplung starten';

  @override
  String get skipPairing => 'Überspringen';

  @override
  String get pairingActive => 'Roller entsperrt';

  @override
  String get pairingActiveHint =>
      'Suche den Roller in den Bluetooth-Einstellungen deines Handys und koppele ihn. Drücke Fertig wenn du fertig bist.';

  @override
  String get pairingDone => 'Fertig';

  @override
  String get blePinHint =>
      'Gib diese PIN auf deinem Gerät ein, um die Kopplung abzuschließen.';

  @override
  String get bleAlreadyConnected => 'Ein Gerät ist bereits verbunden';

  @override
  String get bleAlreadyConnectedHint =>
      'Du kannst weitere Geräte koppeln oder auf Fertig drücken.';

  @override
  String get keycardLearningHeading => 'Schlüsselkarten einrichten';

  @override
  String get keycardLearningBody =>
      'Lerne die NFC-Karten an, mit denen du den Roller ent- und verriegeln möchtest. Klicke auf Starten, halte dann nacheinander jede Karte an den Leser, und klicke anschließend auf Fertig.';

  @override
  String keycardLearnedAck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schlüsselkarten angelernt',
      one: '1 Schlüsselkarte angelernt',
    );
    return '$_temp0. Klicke auf Weiter zum Abschließen, oder lerne weitere Karten an.';
  }

  @override
  String keycardLearningTapped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten erfasst',
      one: '1 Karte erfasst',
      zero: 'Noch keine Karte erfasst',
    );
    return '$_temp0';
  }

  @override
  String get keycardStartLearning => 'Starten';

  @override
  String get keycardAddMore => 'Weitere Karten anlernen';

  @override
  String get keycardLearningActive => 'Anlernmodus aktiv';

  @override
  String get keycardLearningActiveHint =>
      'Halte jede Karte an den Leser. Klicke auf Fertig, wenn du fertig bist.';

  @override
  String get keycardStopLearning => 'Fertig';

  @override
  String keycardStartLearningFailed(String error) {
    return 'Kartenanlernung konnte nicht gestartet werden: $error';
  }

  @override
  String get keycardEntryAlreadyConfiguredHeading =>
      'Schlüsselkarten sind bereits eingerichtet';

  @override
  String keycardEntryAlreadyConfiguredBody(int master, int authorized) {
    String _temp0 = intl.Intl.pluralLogic(
      master,
      locale: localeName,
      other: '$master Masterkarten sind gesetzt',
      one: '1 Masterkarte ist gesetzt',
      zero: 'Es ist keine Masterkarte gesetzt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      authorized,
      locale: localeName,
      other: '$authorized Schlüsselkarten sind angelernt',
      one: '1 Schlüsselkarte ist angelernt',
      zero: 'keine Schlüsselkarten sind angelernt',
    );
    return '$_temp0 und $_temp1. Du kannst diesen Zustand behalten, oder alles zurücksetzen und neu beginnen.';
  }

  @override
  String get keycardEntryContinueButton => 'Weiter';

  @override
  String get keycardStartOverButton => 'Von vorn beginnen';

  @override
  String get keycardStartOverConfirmTitle => 'Alle Schlüsselkarten löschen?';

  @override
  String get keycardStartOverConfirmBody =>
      'Damit werden die Masterkarte und alle angelernten Schlüsselkarten auf dem Roller gelöscht. Du musst sie danach erneut anlernen. Fortfahren?';

  @override
  String get keycardStartOverConfirmYes => 'Alles löschen';

  @override
  String get keycardStartOverConfirmNo => 'Abbrechen';

  @override
  String get keycardCardsStageContinueButton => 'Weiter';

  @override
  String get keycardCardsStageAddMasterButton =>
      'Masterkarte hinzufügen (fortgeschritten)';

  @override
  String get keycardMasterStageHeading => 'Masterkarte hinzufügen';

  @override
  String get keycardMasterStageWarningHeading =>
      'ACHTUNG: Die Masterkarte entriegelt den Roller NICHT';

  @override
  String get keycardMasterStageWarningBody =>
      'Die Masterkarte dient nur zur Verwaltung anderer Schlüsselkarten. Mit ihr kannst du den Roller NICHT entriegeln. Verwende KEINE der gerade angelernten Schlüsselkarten. Nimm eine separate, frische Karte.';

  @override
  String get keycardMasterStageHint => 'Halte die Masterkarte an den Leser.';

  @override
  String get keycardMasterStageRejectedToast =>
      'Diese Karte ist bereits als Schlüsselkarte registriert.';

  @override
  String get keycardMasterStageSaveFailedToast =>
      'Masterkarte konnte nicht gespeichert werden: Schreibvorgang fehlgeschlagen.';

  @override
  String get keycardMasterStageLearnedToast => 'Masterkarte wurde registriert.';

  @override
  String get keycardMasterStageSkipButton => 'Überspringen';

  @override
  String get keycardSimulateTapButton => '[DRY RUN] Tap simulieren';

  @override
  String get keycardSimulateMasterTapButton =>
      '[DRY RUN] Master-Tap simulieren';

  @override
  String get keycardSimulateRejectedTapButton =>
      '[DRY RUN] Bereits-angelernt-Ablehnung simulieren';

  @override
  String get willAskForElevation =>
      'Installation starten (fragt nach Berechtigung)';

  @override
  String get installationContinuesInNewWindow =>
      'Die Installation wird im neuen Fenster fortgesetzt';

  @override
  String get youCanCloseThisWindow => 'Du kannst dieses Fenster schließen.';

  @override
  String get cannotQuitWhileFlashing =>
      'Beenden während des Flashens nicht möglich';

  @override
  String get showLogTooltip => 'Log anzeigen';

  @override
  String get retryMdbConnect => 'Erneut versuchen';

  @override
  String get retryMdbToUms => 'Erneut versuchen';

  @override
  String get showLog => 'Log anzeigen';

  @override
  String get retryMdbFlash => 'Erneut versuchen';

  @override
  String get retryMdbBoot => 'Erneut versuchen';

  @override
  String get retryDbcPrep => 'Erneut versuchen';

  @override
  String get retryVerification => 'Überprüfung wiederholen';

  @override
  String get retryDbcFlash => 'DBC-Flash wiederholen';

  @override
  String get skipToFinish => 'Zum Abschluss springen';

  @override
  String get skipKeycardSetup => 'Überspringen';

  @override
  String get finished => 'Fertig';

  @override
  String get keepCachedDownloads => 'Heruntergeladene Dateien behalten';

  @override
  String get librescootFirmwareDetected => 'Librescoot-Firmware erkannt';

  @override
  String get skipMdbReflash => 'MDB nicht neu flashen';

  @override
  String get keepCurrentMdbFirmware => 'Aktuelle MDB-Firmware behalten';

  @override
  String get skipDbcFlashOption => 'DBC-Flash überspringen';

  @override
  String get onlyFlashMdbSkipDbc => 'Nur MDB flashen, DBC überspringen';

  @override
  String firmwareVersionDisplay(String version) {
    return 'Firmware: $version';
  }

  @override
  String get openSeatboxButton => 'Sitzbank öffnen';

  @override
  String get reconnectCbbStep => 'CBB wieder anschließen';

  @override
  String get reconnectCbbStepDesc =>
      'Stecke das CBB-Kabel wieder in den Anschluss im Fußraum. Ohne CBB könnte das MDB während des Flashens herunterfahren.';

  @override
  String get insertMainBatteryStep => 'Fahrakku einsetzen';

  @override
  String get insertMainBatteryStepDesc =>
      'Setze den Fahrakku wieder in die Sitzbank ein. Ohne ihn könnte die CBB oder die 12V-Hilfsbatterie während des Flashens leer werden, was MDB oder DBC zum Absturz bringen kann.';

  @override
  String get cbbDetected => 'CBB erkannt';

  @override
  String get batteryDetected => 'Akku erkannt';

  @override
  String get proceedWithoutCbb =>
      'Ich verstehe die Risiken, trotzdem fortfahren';

  @override
  String get checkingCbbAndBattery => 'CBB und Akku werden geprüft...';

  @override
  String get waitingForUsbDisconnect => 'Warte auf USB-Trennung...';

  @override
  String get dbcWillCyclePower =>
      'Das DBC wird während dieses Vorgangs mehrmals ein- und ausgeschaltet. Trenne das USB-Kabel zwischen MDB und DBC nicht.';

  @override
  String get ledBootAmber => 'Tacho-LED gelb-orange';

  @override
  String get ledBootAmberMeaning => 'Flash läuft';

  @override
  String get ledBootRedError => 'Tacho-LED blinkt rot';

  @override
  String get ledBootRedMeaning =>
      'Fehler. Laptop verbinden und Log prüfen; Blinker und LED gehen aus, sobald du verbunden bist';

  @override
  String get flashingTakesAbout10Min =>
      'Das Flashen dauert etwa 10 Minuten. Erst wenn die Tacho-LED blinkt (grün oder rot), und auch wirklich erst dann, das Laptop-USB-Kabel wieder anschließen.';

  @override
  String get waitingForMdbToReconnect => 'Warte auf MDB-Wiederverbindung...';

  @override
  String get ledIsGreen => 'LED blinkt grün';

  @override
  String get ledIsRed => 'LED blinkt rot';

  @override
  String get ledAmberWaitNotice =>
      'Wichtig: USB und Strom NICHT trennen, solange das hier läuft. Solange die Tacho-LED gelb-orange leuchtet, läuft der Flash noch. Finger weg, nichts anklicken. Wenn der Flash durch ist, fängt die LED an zu blinken: grün = Erfolg, rot = Fehler. Erst weitermachen, wenn sie blinkt.';

  @override
  String get phaseKeycardSetupTitle => 'Schlüsselkarten einrichten';

  @override
  String get phaseKeycardSetupDescription => 'Schlüsselkarten anlernen';

  @override
  String get usingLocalFirmwareImages =>
      'Lokale Firmware-Images werden verwendet';

  @override
  String get mdbDetectedUmsSkipping =>
      'MDB im UMS-Modus erkannt. Direkt zum Flashen.';

  @override
  String get waitingForMdbToReboot => 'Warte auf MDB-Neustart...';

  @override
  String get mdbDetectedWaitingForSsh => 'MDB erkannt, warte auf SSH...';

  @override
  String get reconnectedToMdb => 'MDB wieder verbunden';

  @override
  String get verifyingBootloaderConfig =>
      'Bootloader-Konfiguration wird überprüft...';

  @override
  String get umsNotDetectedTimeout =>
      'UMS-Gerät nicht innerhalb von 60 s erkannt. MDB ist möglicherweise wieder in Linux gebootet.';

  @override
  String get waitingForDevicePath => 'Warte auf Gerätepfad...';

  @override
  String get noDevicePathFound =>
      'Kein Gerätepfad gefunden. USB-Verbindung prüfen und erneut versuchen.';

  @override
  String get mdbDisconnectedFlashingDbc =>
      'MDB getrennt. DBC wird autonom geflasht...';

  @override
  String get mdbReconnectedVerifying =>
      'MDB wieder verbunden! Überprüfung läuft...';

  @override
  String get logDebugShell => 'Log & Debug-Shell';

  @override
  String get copyToClipboard => 'In Zwischenablage kopieren';

  @override
  String get debugCommandHint => 'Befehl im Installer-Kontext ausführen...';

  @override
  String mbOnDisk(String size) {
    return '$size MB belegt';
  }

  @override
  String get beforeImageLabel => 'Vorher';

  @override
  String get afterImageLabel => 'Nachher';

  @override
  String get language => 'Sprache';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get gettingStartedTitle => 'Erste Schritte';

  @override
  String get gettingStartedOpenMenuTitle => 'Menü öffnen';

  @override
  String get gettingStartedOpenMenuDesc =>
      'Im Parkmodus zweimal kurz hintereinander am linken Bremshebel ziehen. Innerhalb des Menüs scrollst und wählst du mit den Bremshebeln; was die jeweilige Bremse gerade tut, steht unten am Bildschirmrand.';

  @override
  String get gettingStartedDriveMenuTitle => 'Kurzmenü während der Fahrt';

  @override
  String get gettingStartedDriveMenuDesc =>
      'Sitzbank-Schalter gedrückt halten, um das Kurzmenü zu öffnen und die Einträge durchzugehen. Loslassen springt zum nächsten Eintrag, ein kurzer Druck bestätigt den ausgewählten Eintrag.';

  @override
  String get gettingStartedUpdateModeTitle =>
      'Update-Modus später erneut öffnen';

  @override
  String get gettingStartedUpdateModeDesc =>
      'Für Karten- oder Routing-Updates, Einstellungen oder weitere Dateiübertragungen: Roller einschalten, Menü öffnen, dann Einstellungen → System → Update-Modus… aufrufen und einen Rechner per USB anschließen.';

  @override
  String get gettingStartedNavigationTitle => 'Zu einem Ziel navigieren';

  @override
  String get gettingStartedNavigationDesc =>
      'Menü → Navigation → Adresse eingeben…, Letzte Ziele oder Gespeicherte Orte. Mit Aktuellen Standort speichern hältst du die aktuelle Position für später fest; In Favoriten speichern bei einem letzten Ziel hält es dauerhaft.';

  @override
  String get gettingStartedFooter => 'Mehr auf librescoot.org und im Handbuch.';

  @override
  String get gettingStartedLinkWebsite => 'librescoot.org';

  @override
  String get gettingStartedLinkHandbook => 'Handbuch';
}

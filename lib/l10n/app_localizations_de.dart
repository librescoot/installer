// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

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
  String get phaseResumeDetectedTitle => 'Fortsetzen';

  @override
  String get phaseResumeDetectedDescription =>
      'Unterbrochene Installation gefunden';

  @override
  String get phaseHealthCheckTitle => 'Statusprüfung';

  @override
  String get phaseHealthCheckDescription => 'Roller-Bereitschaft prüfen';

  @override
  String get phaseBatteryRemovalTitle => 'Akku abschalten';

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
  String get phaseDashboardPrepTitle => 'Dashboard vorbereiten';

  @override
  String get phaseDashboardPrepDescription =>
      'Koppeln, Keycards anlernen, DBC-Image vorbereiten';

  @override
  String get phaseDbcSwapAndFlashTitle => 'DBC flashen';

  @override
  String get phaseDbcSwapAndFlashDescription =>
      'Kabel umstecken; der Roller flasht den DBC';

  @override
  String get phaseReconnectTitle => 'Verbinden';

  @override
  String get phaseReconnectDescription =>
      'Nach einem unterbrochenen DBC-Flash prüfen';

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
  String get majorStepMdbPrep => 'Dashboard vorbereiten';

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
  String get unscrewUsbCable => 'USB-Kabel vom MDB lösen';

  @override
  String get unscrewUsbCableDesc =>
      'Trenne das interne DBC-USB-Kabel vom MDB-Board. Verwende einen Schlitz- oder PH1-Schraubendreher.';

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
  String get configuringNetwork => 'Netzwerk wird konfiguriert...';

  @override
  String get connectingSsh => 'SSH-Verbindung wird aufgebaut...';

  @override
  String get waitingForUnlock => 'Roller entsperren, um fortzufahren...';

  @override
  String get unfinishedInstallDetected =>
      'Unvollständige Installation erkannt, Entsperren wird übersprungen...';

  @override
  String get waitingForBatteryData => 'Warte auf AUX/CBB-Batteriedaten...';

  @override
  String get resumeFoundHeading => 'Unterbrochene Installation gefunden';

  @override
  String get resumeFoundBody =>
      'Eine frühere Installation auf diesem Roller wurde nicht abgeschlossen. Der Entsperr-Schritt wurde übersprungen und deaktivierte Dienste wurden wieder aktiviert. Die Installation wird an der passenden Stelle fortgesetzt.';

  @override
  String get resumeFoundLastError => 'Letzter aufgezeichneter Fehler:';

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
  String get incompleteImageStatus =>
      'Unvollständiges Firmware-Image erkannt. Neuflashen zur Wiederherstellung...';

  @override
  String get incompleteImageHeading => 'Unvollständiges Firmware-Image';

  @override
  String get incompleteImageBody =>
      'Dieser Roller läuft mit einem minimalen Wiederherstellungs-Image ohne Batterie-Telemetrie. Das kann passieren, wenn eine frühere Installation das falsche Image geschrieben hat. Fahre fort, um die vollständige Firmware neu zu flashen und die Einrichtung abzuschließen.';

  @override
  String get reflashToRecover => 'Neu flashen zur Wiederherstellung';

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
  String get deactivateMainBatteryHeading => 'Fahrakku';

  @override
  String get deactivateMainBattery => 'Fahrakku deaktivieren';

  @override
  String get deactivateMainBatteryStep =>
      'Der Roller schaltet den Fahrakku ab. Du musst ihn nicht aus der Sitzbank nehmen.';

  @override
  String get deactivatingMainBattery => 'Fahrakku wird abgeschaltet...';

  @override
  String get mainBatteryDeactivated => 'Fahrakku abgeschaltet';

  @override
  String get mainBatteryAlreadyOff => 'Fahrakku ist bereits abgeschaltet';

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
  String get mdbFlashComplete => 'MDB-Flash abgeschlossen!';

  @override
  String flashProgressMb(String mb) {
    return '$mb MB geschrieben';
  }

  @override
  String flashProgressMbOfTotal(String mb, String total) {
    return '$mb / $total MB geschrieben';
  }

  @override
  String flashProgressEta(int minutes, int seconds) {
    return 'noch $minutes Min. $seconds Sek.';
  }

  @override
  String flashProgressBootSector(String mb) {
    return 'Bootsektor: $mb MB geschrieben';
  }

  @override
  String get scooterPrepHeading => 'Roller vorbereiten';

  @override
  String get scooterPrepSubheading =>
      'MDB-Firmware wurde geschrieben. Jetzt für den Neustart vorbereiten.';

  @override
  String get disconnectCbb => 'CBB trennen';

  @override
  String get disconnectCbbDesc =>
      'Der Fahrakku muss bereits abgeschaltet sein (vorheriger Schritt), bevor du die CBB trennst. Bei falscher Reihenfolge droht ein elektrischer Schaden.';

  @override
  String get disconnectAuxPole => 'Einen AUX-Pol trennen';

  @override
  String get disconnectAuxPoleDesc =>
      'Entferne NUR den Pluspol (außen, rotes Kabel und Pol), um eine Verpolung zu vermeiden. Dadurch wird das MDB stromlos; die USB-Verbindung geht verloren.';

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
  String get reconnectCbbFirstDesc =>
      'Schließe zuerst die CBB wieder an, solange der AUX noch getrennt ist, damit sie an einen stromlosen Roller kommt.';

  @override
  String get cbbBeforeAuxWarning =>
      'Schließe die CBB vor dem AUX an. Wird die CBB bei eingeschaltetem Roller verbunden, kann der Fahrakku unter Spannung stehen.';

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
  String get reconnectCbbHeading => 'CBB und Fahrakku prüfen';

  @override
  String get verifyCbbConnection => 'CBB-Verbindung prüfen';

  @override
  String get verifyBatteryPresence => 'Akku prüfen';

  @override
  String get checkingCbb => 'CBB wird geprüft...';

  @override
  String waitingForCbb(int attempts) {
    return 'Warte auf CBB... ($attempts)';
  }

  @override
  String get cbbNotDetected => 'CBB nicht erkannt. Bitte Verbindung prüfen.';

  @override
  String get preparingDbcFlash => 'DBC-Flash wird vorbereitet';

  @override
  String get waitingForDownloads => 'Warte auf Abschluss der Downloads...';

  @override
  String get finishStepsAboveToContinue =>
      'Schließe die Schritte oben ab, um fortzufahren.';

  @override
  String get startingTrampoline => 'Trampoline-Skript wird gestartet...';

  @override
  String uploadError(String error) {
    return 'Upload-Fehler: $error';
  }

  @override
  String get dbcReadyButton => 'DBC-Flashen beginnen';

  @override
  String get dbcFlashInProgress => 'DBC wird geflasht';

  @override
  String get dbcFlashSwapCablesTitle => 'USB auf das DBC umstecken';

  @override
  String get disconnectUsbFromLaptop => 'Laptop-USB-Kabel vom MDB abziehen';

  @override
  String get disconnectUsbFromLaptopDesc =>
      'Ziehe das Laptop-USB-Kabel vom MDB ab, damit der Port für das DBC-Kabel frei wird.';

  @override
  String get reconnectDbcUsbToMdb => 'DBC-USB-Kabel mit MDB verbinden';

  @override
  String get reconnectDbcUsbToMdbDesc =>
      'Stecke das interne DBC-USB-Kabel in den MDB-Port. Noch nicht festschrauben.';

  @override
  String get verifyingDbcInstallation => 'DBC-Installation wird geprüft';

  @override
  String get reconnectUsbToLaptop =>
      'DBC-Kabel vom MDB abziehen und den Laptop wieder anschließen...';

  @override
  String get waitingForRndisDevice => 'Warte auf RNDIS-Gerät...';

  @override
  String get readingTrampolineStatus => 'Trampoline-Status wird gelesen...';

  @override
  String readingTrampolineStatusElapsed(int elapsed) {
    return 'Trampoline-Status wird gelesen… (${elapsed}s)';
  }

  @override
  String get dbcFlashSuccessful => 'DBC-Flash erfolgreich!';

  @override
  String get dbcAlreadyCurrentTitle => 'Dashboard ist bereits aktuell';

  @override
  String dbcAlreadyCurrentBody(String version) {
    return 'Auf dem Dashboard (DBC) läuft bereits Librescoot $version. Trotzdem neu flashen?';
  }

  @override
  String get dbcAlreadyCurrentReflash => 'Neu flashen';

  @override
  String get dbcAlreadyCurrentSkip => 'DBC-Flash überspringen';

  @override
  String get dbcPrepComplete => 'DBC-Image bereit zum Flashen';

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
      'Trampoline-Status unbekannt. Prüfe /data/installer/trampoline.log auf dem MDB.';

  @override
  String get welcomeToLibrescoot => 'Willkommen bei Librescoot!';

  @override
  String get finalSteps => 'Letzte Schritte:';

  @override
  String get disconnectUsbFromLaptopFinal => 'Laptop vom MDB abziehen';

  @override
  String get disconnectUsbFromLaptopFinalDesc =>
      'Falls der Laptop noch am MDB-Port steckt, zieh ihn jetzt ab. Dort kommt das DBC-Kabel wieder hinein.';

  @override
  String get reconnectDbcUsbCable =>
      'DBC-USB-Kabel anschließen und festschrauben';

  @override
  String get reconnectDbcUsbCableDesc =>
      'Stecke das interne DBC-USB-Kabel wieder in den MDB-Port, falls nicht schon geschehen, und schraube es vorsichtig fest.';

  @override
  String get screwDbcUsbCable => 'DBC-USB-Kabel festschrauben';

  @override
  String get screwDbcUsbCableDesc =>
      'Das DBC-Kabel steckt bereits im MDB-Port; schraube es jetzt vorsichtig fest.';

  @override
  String get closeSeatboxAndFootwell => 'Fußraumabdeckung wieder anbringen';

  @override
  String get closeSeatboxAndFootwellDesc =>
      'Klipse zuerst die Metallbügel wieder ein, setze dann die Fußraumabdeckung auf und schraube sie fest.';

  @override
  String get unlockScooter => 'Roller entsperren';

  @override
  String get unlockScooterDesc =>
      'Nutze eine eingerichtete Schlüsselkarte, ein gekoppeltes Handy oder den Button in der App.';

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
  String get safetyCheckFailed => 'Sicherheitsprüfung fehlgeschlagen';

  @override
  String get cannotFlashSafety =>
      'Dieses Gerät kann aus Sicherheitsgründen nicht geflasht werden:';

  @override
  String get cancelButton => 'Abbrechen';

  @override
  String get confirmFlashTargetTitle => 'Ziel-Laufwerk bestätigen';

  @override
  String get confirmFlashTargetBody =>
      'Windows konnte nicht bestätigen, dass dieses Laufwerk nicht dein Systemlaufwerk ist. Prüfe das Ziel vor dem Flashen.';

  @override
  String get confirmFlashTargetDetected => 'Erkanntes Librescoot-Gerät';

  @override
  String get confirmFlashTargetOthers =>
      'Weitere USB-Laufwerke an diesem Rechner:';

  @override
  String get confirmFlashTargetInternalHidden =>
      'Interne Laufwerke werden nicht angezeigt.';

  @override
  String get confirmFlashTargetAccept => 'Dieses Laufwerk flashen';

  @override
  String get flashTargetNotConfirmed =>
      'Flashen abgebrochen: Das Ziel-Laufwerk wurde nicht bestätigt.';

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
  String get backingUpConfig => 'Gerätekonfiguration wird gesichert...';

  @override
  String get configBackedUp => 'Gerätekonfiguration gesichert';

  @override
  String get restoringConfig => 'Gerätekonfiguration wird wiederhergestellt...';

  @override
  String healthCheckFailed(String error) {
    return 'Statusprüfung fehlgeschlagen: $error';
  }

  @override
  String errorPrefix(String error) {
    return 'Fehler: $error';
  }

  @override
  String get regionHint => 'Für Offline-Karten und Navigationsunterstützung';

  @override
  String get skipOfflineMaps => 'Offline-Karten überspringen';

  @override
  String get bluetoothPairingHeading => 'Bluetooth-Kopplung';

  @override
  String get bluetoothPairingHint =>
      'Koppele dein Handy oder andere Bluetooth-Geräte mit dem Roller.';

  @override
  String get bleMacLabel => 'BLE-Adresse';

  @override
  String get startPairing => 'Kopplung starten';

  @override
  String get skipPairing => 'Überspringen';

  @override
  String get pairingActive => 'Kopplungsmodus aktiv';

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
  String get keycardCardDuplicateToast => 'Diese Karte ist bereits angelernt.';

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
  String get reconnectCbbStep => 'CBB wieder anschließen';

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
  String get finishRebootingTitle => 'Roller startet neu…';

  @override
  String get finishRebootingBody =>
      'Das MDB startet gerade neu; die USB-Verbindung bricht dabei von selbst ab. Du musst noch nichts umstecken.';

  @override
  String get networkConfigNeedsPermission =>
      'macOS fragt nach Erlaubnis, die Netzwerk-Einstellungen zu ändern. Im Systemdialog auf \'Erlauben\' klicken, dann \'Erneut versuchen\' drücken.';

  @override
  String get dbcWalkAwayHeadline =>
      'Umstecken erledigt. Die Installation läuft jetzt von selbst.';

  @override
  String get dbcWalkAwayBody =>
      'Der Roller flasht das Dashboard jetzt selbstständig. Das dauert 10 bis 20 Minuten. Schau dir in der Zwischenzeit die ersten Schritte unten an und wirf einen Blick ins Handbuch.';

  @override
  String get dbcWalkAwayLedProgress =>
      'Fortschritt: Die Keycard-LED am Tacho pulst gelb in Gruppen. Ein Puls kurz nach dem Start, bis zu vier Pulse kurz vor Schluss. Der Tacho selbst geht dabei mehrmals an und aus, das ist normal.';

  @override
  String get dbcWalkAwayDone =>
      'Fertig: Die LED hört auf zu pulsieren und bleibt aus. Dann das DBC-Kabel festschrauben, alles wieder zumachen, Roller entriegeln und losfahren.';

  @override
  String get dbcWalkAwayFailure =>
      'Wenn der Roller mit dem Warnblinker blinkt oder die Keycard-LED rot blinkt, ist etwas schiefgelaufen: den Laptop wieder ans MDB anschließen.';

  @override
  String get dbcWalkAwayDoneButton => 'Weiter zum Abschluss';

  @override
  String get dbcWalkAwayWentWrongButton => 'Etwas ist schiefgelaufen';

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
  String get logDebugShell => 'Log & Debug-Shell';

  @override
  String get copyToClipboard => 'In Zwischenablage kopieren';

  @override
  String logFilePath(String path) {
    return 'Logdatei: $path';
  }

  @override
  String get revealLogFile => 'Im Ordner anzeigen';

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
      'Das Kurzmenü über den Sitzbank-Schalter funktioniert nur im Fahrmodus (Seitenständer oben). Sitzbank-Schalter gedrückt halten, um das Kurzmenü zu öffnen; solange du hältst, wechseln die Einträge automatisch im Sekundentakt weiter. Loslassen, um auf dem hervorgehobenen Eintrag zu stoppen, dann innerhalb etwa einer Sekunde noch einmal kurz drücken, um zu bestätigen.';

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

  @override
  String get substepWaitRndis => 'Warte auf MDB (RNDIS) am USB';

  @override
  String get substepConfigureNetwork => 'Netzwerkkonfiguration';

  @override
  String get substepConnectSsh => 'SSH-Verbindung herstellen';

  @override
  String get substepDisableHazards => 'Alarm und Auto-Standby deaktivieren';

  @override
  String get substepReadStatus => 'Trampoline-Status auslesen';

  @override
  String elapsedSeconds(int seconds) {
    return '${seconds}s vergangen';
  }

  @override
  String get reconnectTimeoutHeading => 'Dauert ungewöhnlich lange';

  @override
  String reconnectTimeoutBody(int minutes) {
    return 'Es sind $minutes Min vergangen, ohne dass das MDB als RNDIS-Gerät aufgetaucht ist. Das DBC braucht beim ersten Boot manchmal länger (Partitions-Resize, Karten-Installation). Du kannst weiter warten, oder unten neu starten / überspringen.';
  }

  @override
  String get usbDeviceCurrentlyDetected => 'Aktuell erkanntes USB-Gerät';

  @override
  String get usbDeviceNone => 'keines';

  @override
  String get collectingUsbInfo => 'USB-Geräteinfos werden gesammelt…';

  @override
  String get usbInfoUnsupportedPlatform =>
      'USB-Geräteinfos werden auf dieser Plattform nicht unterstützt.';

  @override
  String get usbInfoCollectFailed =>
      'USB-Geräteinfos konnten nicht gesammelt werden';

  @override
  String internalError(String error) {
    return 'Interner Fehler: $error';
  }

  @override
  String get copyLog => 'Log kopieren';

  @override
  String get tileLabelMaps => 'Karten';

  @override
  String get tileLabelRoutes => 'Routen';
}

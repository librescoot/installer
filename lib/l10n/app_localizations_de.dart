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
  String get phaseResumeDetectedTitle => 'Vorheriger Versuch';

  @override
  String get phaseResumeDetectedDescription =>
      'Unterbrochene Installation gefunden';

  @override
  String get phaseHealthCheckTitle => 'Statusprüfung';

  @override
  String get phaseHealthCheckDescription => 'Roller-Bereitschaft prüfen';

  @override
  String get phaseMdbToUmsTitle => 'MDB → UMS';

  @override
  String get phaseMdbToUmsDescription => 'Bootloader für Flashen konfigurieren';

  @override
  String get phaseMdbFlashTitle => 'MDB flashen';

  @override
  String get phaseMdbFlashDescription => 'Firmware auf MDB schreiben';

  @override
  String get phaseScooterPrepTitle => 'Strom trennen';

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
  String get phaseReconnectTitle => 'Prüfen';

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
  String get majorStepPrepare => 'Einrichten';

  @override
  String get majorStepConnect => 'Verbinden';

  @override
  String get majorStepMdbFlash => 'MDB vorbereiten';

  @override
  String get majorStepPairing => 'Koppeln & Karten';

  @override
  String get majorStepMdbInstall => 'MDB installieren';

  @override
  String get majorStepDbcFlash => 'DBC installieren';

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
      'PH2-Kreuz- oder H4-Innensechskantschraubendreher für die vier Schrauben der Fußraumabdeckung';

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
      'Wenn etwas hängt, keine Rückmeldung gibt oder sich merkwürdig verhält: halt an und frag im Discord nach, bevor du etwas anderes tust. Zieh nicht den AUX-Akku ab, klemm die CBB nicht ab, zieh kein USB-Kabel und starte weder Roller noch Laptop neu. Der Installer kommt aus fast jedem Zustand wieder heraus, solange ihn nichts unterbricht. Strom mitten im Flash zu trennen ist das, was Roller unbrauchbar macht.';

  @override
  String get downloadsFailedHeading => 'Download-Server nicht erreichbar';

  @override
  String get downloadsFailedBody =>
      'Prüf die Internetverbindung des Laptops und versuch es nochmal. Offline weitermachen geht auch, wenn die Firmware schon im Cache liegt.';

  @override
  String get downloadsRetry => 'Nochmal versuchen';

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
  String get channelTestingDesc => 'Neueste Features, evtl. Noch ungeschliffen';

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
      'Der Roller ist nicht beschädigt. Eine Installation wurde unterbrochen, und dieser Schritt räumt ihre Reste auf, bevor es von vorn losgeht.';

  @override
  String get resumeWhatHappensHeading => 'Was beim Weitermachen passiert';

  @override
  String get resumeWhatHappensCleanup =>
      'Die Reste werden aufgeräumt: das zurückgelassene Onboot-Skript wird entschärft, gestoppte Dienste werden wieder gestartet.';

  @override
  String get resumeWhatHappensRestart =>
      'Die Installation läuft komplett von vorn. Es wird nichts fortgesetzt, kein halbfertiger Schritt wird übernommen.';

  @override
  String get resumeWhatHappensKeep =>
      'Es geht nichts zusätzlich verloren. Was der vorherige Durchlauf geändert hat, hat er bereits geändert; ein Neustart kostet das nicht noch einmal.';

  @override
  String get resumeTakesAsLong =>
      'Es dauert so lange wie eine normale Installation, ungefähr 20 Minuten.';

  @override
  String get resumeClearingLeftovers =>
      'Reste der vorherigen Installation werden aufgeräumt...';

  @override
  String resumeCleanupFailed(String error) {
    return 'Die vorige Installation konnte nicht sicher aufgeräumt werden: $error\n\nEs wird nichts weiter ausgeführt, bis das Aufräumen erfolgreich war.';
  }

  @override
  String get resumeFoundLastError => 'Letzter aufgezeichneter Fehler:';

  @override
  String get resumeRunningHeading =>
      'Auf dem Roller läuft noch eine Installation';

  @override
  String get resumeRunningBody =>
      'Der Roller arbeitet die vorige Installation noch ab. Hier wird nichts angefasst, solange sie läuft.';

  @override
  String get resumeRunningWait =>
      'Warte, bis der Roller fertig ist. Danach geht es hier automatisch weiter.';

  @override
  String resumeStageLabel(String stage) {
    return 'Zuletzt: $stage';
  }

  @override
  String get resumeActorScooter => 'auf dem Roller';

  @override
  String get resumeActorInstaller => 'im Installer';

  @override
  String get resumeLogHeading => 'Letzte Zeilen aus dem Log des Rollers';

  @override
  String get awaitingUnlockHeading => 'Roller entsperren';

  @override
  String get awaitingUnlockDetail =>
      'Entsperre den Roller, damit der Installer weitermachen kann.';

  @override
  String get awaitingUnlockHintKeycard =>
      'Schlüsselkarte an den Leser am Lenker halten';

  @override
  String get awaitingUnlockHintPhone => 'Oder ein gekoppeltes Handy benutzen';

  @override
  String get awaitingUnlockWatching =>
      'Der Installer macht automatisch weiter, sobald der Roller entsperrt ist.';

  @override
  String get awaitingParkWatching =>
      'Der Installer macht automatisch weiter, sobald der Roller geparkt ist.';

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
  String get connected => 'Verbunden';

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
    return 'Die Installation auf Firmware-Versionen älter als 1.12.0 ist nicht getestet (deine: $version). Der Installer sollte trotzdem funktionieren. Probleme bitte im Librescoot-Discord melden.';
  }

  @override
  String get openLibrescootDiscord => 'Librescoot-Discord öffnen';

  @override
  String get healthCheckHeading => 'Statusprüfung';

  @override
  String get verifyingReadiness => 'Roller-Bereitschaft wird geprüft...';

  @override
  String get incompleteImageStatus =>
      'Unvollständiges Firmware-Image erkannt. Neu flashen zur Wiederherstellung...';

  @override
  String get incompleteImageHeading => 'Unvollständiges Firmware-Image';

  @override
  String get incompleteImageBody =>
      'Dieser Roller läuft mit einem minimalen Wiederherstellungs-Image. Es bootet und antwortet, hat aber keine der Fahrzeugdienste. Das kann passieren, wenn eine frühere Installation nicht abgeschlossen wurde. Fahre fort, um die vollständige Firmware neu zu flashen und die Einrichtung abzuschließen.';

  @override
  String get reflashToRecover => 'Neu flashen zur Wiederherstellung';

  @override
  String get stockFirmwareStatus =>
      'Original-Firmware erkannt. Bereit für die Librescoot-Installation...';

  @override
  String get stockFirmwareHeading => 'Original-Firmware';

  @override
  String get stockFirmwareBody =>
      'Dieser Roller läuft mit seiner Original-Firmware. Damit ist alles in Ordnung. Einige Werte hier stehen unter anderen Schlüsseln und werden deshalb als unbekannt statt als gemessen angezeigt. Fahre fort, um Librescoot zu installieren.';

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
  String get healthValueUnknown => 'nicht auslesbar';

  @override
  String get riskAuxLow =>
      'Niedrige AUX-Batterie könnte MDB oder DBC während des Flashens abschalten. LED-Anzeigen könnten ebenfalls ausfallen. Sitzbank mit eingesetztem Fahrakku schließen und warten, bis sie geladen ist.';

  @override
  String get riskCbbSoh =>
      'Schlechter CBB-Zustand kann zu unzuverlässiger Stromversorgung während des Flashens führen.';

  @override
  String get riskCbbCharge =>
      'Niedrige CBB-Ladung erhöht das Risiko eines Stromausfalls beim DBC-Flash. Sitzbank mit eingesetztem Fahrakku schließen und warten, bis die CBB geladen ist.';

  @override
  String get riskNoBattery =>
      'Ohne den Fahrakku entlädt sich die AUX-Batterie schneller. Der Roller könnte bei längeren Vorgängen herunterfahren.';

  @override
  String get openSeatbox => 'Sitzbank öffnen';

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
  String get readyToFlashTargetLabel => 'Ziel';

  @override
  String get readyToFlashImageLabel => 'Zu schreibendes Image';

  @override
  String get readyToFlashErases =>
      'Das löscht das Hauptboard. Alles, was aktuell darauf ist, wird ersetzt.';

  @override
  String get readyToFlashDuration =>
      'Das Schreiben dauert etwa eine Minute. Trenne währenddessen weder USB noch Strom.';

  @override
  String get readyToFlashNoTarget => 'Noch kein Zielgerät ermittelt.';

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
  String get mdbFlashComplete => 'MDB-Flash abgeschlossen';

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
      'Der Fahrakku muss bereits entnommen sein, bevor du die CBB trennst. Bei falscher Reihenfolge droht ein elektrischer Schaden.';

  @override
  String get disconnectAuxPole => 'Einen AUX-Pol trennen';

  @override
  String get disconnectAuxPoleDesc =>
      'Entferne nur den Pluspol (außen, rotes Kabel und Pol), um eine Verpolung zu vermeiden. Dadurch wird das MDB stromlos und die USB-Verbindung geht verloren.';

  @override
  String get auxDisconnectWarning =>
      'Die USB-Verbindung geht verloren, wenn du AUX trennst. Das ist normal. Schließe den AUX-Pol im nächsten Schritt wieder an, um das MDB zu starten.';

  @override
  String get doneCbbAuxDisconnected => 'Fertig, der Roller startet neu';

  @override
  String get doneAuxDisconnected => 'Fertig, AUX ist getrennt';

  @override
  String get brakeResetHeading => 'Roller neu starten';

  @override
  String get brakeResetIntro =>
      'Beide Bremshebel ziehen und halten. Alle zehn Sekunden den rechten Hebel etwa eine Sekunde loslassen und wieder ziehen. Nach dem vierten Halten einfach loslassen. Der Roller startet neu.';

  @override
  String get brakeResetAfterNote =>
      'Die USB-Verbindung verschwindet während des Neustarts. Das ist normal, der Installer wartet auf das MDB.';

  @override
  String get brakePacerStart => 'Timer starten';

  @override
  String get brakePacerStop => 'Abbrechen';

  @override
  String get brakePacerRestart => 'Nochmal';

  @override
  String get brakePacerDone =>
      'Das ist das Muster. Jetzt einfach loslassen. Der Roller startet ein paar Sekunden später von allein neu.';

  @override
  String get brakeDiagramBlipLegend => 'Rechter Hebel etwa eine Sekunde los';

  @override
  String brakeDiagramEndLegend(int seconds) {
    return 'Bei $seconds Sekunden einfach loslassen';
  }

  @override
  String get brakeBandBothHeld => 'Linker Hebel bleibt durchgehend gezogen';

  @override
  String get brakeBlipRight => 'Rechten Hebel jetzt los';

  @override
  String get brakeLeftStaysHint =>
      'Der linke Hebel bleibt die ganze Zeit gezogen.';

  @override
  String get brakeLeadInLabel => 'Beide Bremsen ziehen';

  @override
  String get brakeLeadInHint =>
      'Geh zum Lenker und leg die Hände an die Bremshebel.';

  @override
  String get brakeKeepHolding => 'Beide Bremsen halten';

  @override
  String get scooterPrepManualFallback => 'Oder den Strom von Hand trennen';

  @override
  String get deactivatingMainBattery => 'Fahrakku wird abgeschaltet...';

  @override
  String get waitingForMdbBoot => 'Warte auf MDB-Boot';

  @override
  String get mdbBootRestartingNote =>
      'Der Roller startet von allein neu. Das dauert ein, zwei Minuten.';

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
  String get waitingForMdbRestart => 'Warte auf den Neustart des Rollers...';

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
  String get reconnectCbbHeading => 'CBB wieder anschließen';

  @override
  String get verifyCbbConnection => 'CBB-Verbindung prüfen';

  @override
  String get verifyBatteryPresence => 'Akku prüfen';

  @override
  String get turningMainBatteryOff => 'Fahrakku wird zuerst abgeschaltet...';

  @override
  String get turningMainBatteryOn => 'Fahrakku wird wieder eingeschaltet...';

  @override
  String get checkingCbb => 'CBB wird geprüft...';

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
  String get preparingDbcFlashSubtitle =>
      'Alles, was das Display braucht, wandert zuerst auf das MDB.';

  @override
  String get preparingDbcFlashExplainer =>
      'Das DBC hängt am MDB, nicht am Laptop. Der Installer kopiert deshalb Image, Firmware und Offline-Karten auf das MDB und legt dort ein Skript ab, das den Rest übernimmt. Erst danach kommt der Kabeltausch: Laptop ab, DBC-Kabel wieder ans MDB. Von da an flasht das MDB das Display allein weiter.';

  @override
  String get preparingMapTransfer => 'Karten werden übertragen';

  @override
  String get preparingMapTransferSubtitle =>
      'Die Offline-Karten wandern zuerst auf das MDB.';

  @override
  String get preparingMapTransferExplainer =>
      'Das DBC hängt am MDB, nicht am Laptop. Der Installer kopiert deshalb die Offline-Karten auf das MDB und legt dort ein Skript ab, das den Rest übernimmt. Es wird keine Display-Firmware geschrieben: du hast das DBC auf unverändert gestellt. Danach kommt der Kabeltausch, Laptop ab und DBC-Kabel wieder ans MDB, und die Karten wandern von allein hinüber.';

  @override
  String get skipMapTransfer => 'Karten überspringen';

  @override
  String get majorStepDbcMaps => 'Karten';

  @override
  String get phaseDbcPrepTitleMaps => 'Karten hochladen';

  @override
  String get phaseDbcPrepDescriptionMaps => 'Offline-Karten hochladen';

  @override
  String get phaseDbcFlashTitleMaps => 'Übertragen';

  @override
  String get phaseDbcFlashDescriptionMaps => 'Der Roller kopiert sie selbst';

  @override
  String get dbcReadyButtonMaps => 'Kartenübertragung starten';

  @override
  String get waitingForDownloads => 'Warte auf Abschluss der Downloads...';

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
  String get dbcFlashSwapCablesDeadline =>
      'Der Roller wartet schon auf das Display. Nach ein paar Minuten gibt er auf, mach es also jetzt und nicht später. Die Schrauben können warten.';

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
  String get ledBlinkerProgress => 'Blinker leuchten reihum auf';

  @override
  String get blinkerPosFL => 'vorne links';

  @override
  String get blinkerPosFR => 'vorne rechts';

  @override
  String get blinkerPosBR => 'hinten rechts';

  @override
  String get blinkerPosBL => 'hinten links';

  @override
  String get blinkerStepPrep => 'DBC vorbereiten';

  @override
  String get blinkerStepFlash => 'DBC flashen';

  @override
  String get blinkerStepRestart => 'DBC neu starten';

  @override
  String get blinkerStepMaps => 'Karten laden';

  @override
  String get verifyingDbcInstallation => 'DBC-Installation wird geprüft';

  @override
  String get reconnectUsbToLaptop => 'USB wieder mit Laptop verbinden...';

  @override
  String get waitingForRndisDevice => 'Warte auf RNDIS-Gerät...';

  @override
  String get readingTrampolineStatus => 'Trampoline-Status wird gelesen...';

  @override
  String readingTrampolineStatusElapsed(int elapsed) {
    return 'Trampoline-Status wird gelesen… (${elapsed}s)';
  }

  @override
  String get dbcFlashSuccessful => 'DBC-Flash abgeschlossen';

  @override
  String dbcInstallSuccessfulVersion(String version) {
    return 'DBC-Installation erfolgreich, läuft jetzt $version';
  }

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
  String get welcomeToLibrescoot => 'Willkommen bei Librescoot';

  @override
  String get finalSteps => 'Letzte Schritte:';

  @override
  String get finishNextHeading => 'Was als Nächstes passiert';

  @override
  String get finishNextDbcFlash =>
      'Sobald du das DBC-Kabel wieder ansteckst, installiert der Roller das Display von allein. Das dauert etwa 20 Minuten. Lass den Strom dran und lass ihn fertig werden; das Boot-Licht zeigt, dass er arbeitet.';

  @override
  String get finishNextOnDevice =>
      'Sobald du das DBC-Kabel wieder ansteckst, erledigt der Roller den Rest von allein. Du musst den Laptop nicht noch einmal anstecken.';

  @override
  String get finishNextNothing =>
      'Das Hauptboard ist fertig, auf dem Roller läuft nichts mehr. Bau ihn wieder zusammen und fahr los.';

  @override
  String get disconnectUsbFromLaptopFinal =>
      'Laptop-USB-Kabel vom MDB abziehen';

  @override
  String get disconnectUsbFromLaptopFinalDesc =>
      'Ziehe das Laptop-USB-Kabel vom MDB ab. Dort kommt gleich das DBC-Kabel wieder hinein.';

  @override
  String get reconnectDbcUsbCable => 'DBC-USB-Kabel anschließen';

  @override
  String get reconnectDbcUsbCableDesc =>
      'Stecke das interne DBC-USB-Kabel wieder in den MDB-Port und schraube es jetzt vorsichtig fest.';

  @override
  String get closeSeatboxAndFootwell => 'Fußraumabdeckung wieder anbringen';

  @override
  String get closeSeatboxAndFootwellDesc =>
      'Klipse zuerst die Metallbügel wieder ein, setze dann die Fußraumabdeckung auf und schraube sie fest.';

  @override
  String get unlockScooter => 'Roller entsperren';

  @override
  String get unlockScooterDesc =>
      'Nutze eine der angelernten Schlüsselkarten oder entsperre über Bluetooth.';

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
  String get assetChipMdbArtifact => 'MDB-Artefakt';

  @override
  String get assetChipDbcArtifact => 'DBC-Artefakt';

  @override
  String get assetChipMdbImage => 'MDB-Image';

  @override
  String get assetChipDbcImage => 'DBC-Image';

  @override
  String get assetChipMaps => 'Karten';

  @override
  String get assetChipRoutes => 'Routen';

  @override
  String get downloadMdbFirmware => 'MDB-Firmware';

  @override
  String get downloadDbcFirmware => 'DBC-Firmware';

  @override
  String get downloadMapTiles => 'Kartenkacheln';

  @override
  String get downloadRoutingTiles => 'Routing-Kacheln';

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
      'Der Installer konnte nicht bestätigen, dass dieses Laufwerk nicht deine Systemplatte ist. Prüfe das Ziel vor dem Flashen.';

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
  String get regionHint =>
      'Welche Offline-Karten heruntergeladen werden. Ob sie installiert werden, wird später mit dem Rest des Plans entschieden';

  @override
  String get skipOfflineMaps => 'Offline-Karten nicht herunterladen';

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
  String get blePreparingRadio =>
      'Bluetooth-Funk startet neu, bitte vor dem Koppeln abwarten.';

  @override
  String get skipPairing => 'Überspringen';

  @override
  String get pairingActive => 'Bereit zum Koppeln';

  @override
  String get pairingActiveHint =>
      'Suche den Roller in den Bluetooth-Einstellungen deines Handys und koppele ihn. Drücke Fertig wenn du fertig bist.';

  @override
  String get pairingDone => 'Fertig';

  @override
  String get blePinHint =>
      'Gib diese PIN auf deinem Gerät ein, um die Kopplung abzuschließen.';

  @override
  String get blePairedHeading => 'Gerät gekoppelt';

  @override
  String get blePairedHint =>
      'Um ein weiteres Gerät zu koppeln, trenne die Verbindung zuerst auf diesem Gerät. Der Roller hält immer nur eine Bluetooth-Verbindung.';

  @override
  String get bleLinkHeldHeading => 'Ein Gerät belegt die Verbindung';

  @override
  String get bleLinkHeldHint =>
      'Der Roller hält immer nur eine Bluetooth-Verbindung und sendet nicht, solange eine besteht. Trenne sie auf dem verbundenen Gerät, bevor du ein neues koppelst.';

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
  String get keycardStopScanning => 'Stoppen';

  @override
  String get keycardSkipConfirmTitle => 'Ohne Schlüsselkarte überspringen?';

  @override
  String get keycardSkipConfirmBody =>
      'Es wird keine Karte angelernt. Der Roller lässt sich dann nicht mit einer Karte entsperren, nur per Handy.';

  @override
  String get keycardSkipConfirmAction => 'Trotzdem überspringen';

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
      'Die Masterkarte entriegelt den Roller nicht';

  @override
  String get keycardMasterStageWarningBody =>
      'Die Masterkarte verwaltet deine übrigen Schlüsselkarten. Sie entriegelt den Roller nicht, und keine der eben angelernten Karten kann als Masterkarte dienen. Nimm eine separate, unbenutzte Karte.';

  @override
  String get keycardMasterStageHint => 'Halte die Masterkarte an den Leser.';

  @override
  String get keycardCardDuplicateToast => 'Diese Karte ist bereits angelernt.';

  @override
  String get keycardMasterStageRejectedToast =>
      'Diese Karte ist bereits als Schlüsselkarte angelernt.';

  @override
  String get keycardMasterStageSaveFailedToast =>
      'Masterkarte konnte nicht gespeichert werden: Schreibvorgang fehlgeschlagen.';

  @override
  String get keycardMasterStageLearnedToast => 'Masterkarte wurde angelernt.';

  @override
  String get keycardMasterStageStartFailed =>
      'Die Master-Karten-Einrichtung konnte nicht gestartet werden';

  @override
  String get keycardMasterStageRetryButton => 'Erneut versuchen';

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
  String get phaseInstallPlanTitle => 'Installationsplan';

  @override
  String get phaseInstallPlanDescription =>
      'Festlegen, was mit jedem Board passiert';

  @override
  String get phaseMdbArtifactTitle => 'MDB-Update';

  @override
  String get phaseMdbArtifactDescription => 'Firmware-Artefakt installieren';

  @override
  String get majorStepMdbUpgrade => 'MDB aktualisieren';

  @override
  String get majorStepDbcUpgrade => 'DBC aktualisieren';

  @override
  String get installPlanHeading => 'Was soll der Installer tun?';

  @override
  String installPlanIntro(String version) {
    return 'Aktion pro Board auswählen. Zielversion: $version';
  }

  @override
  String get boardMdb => 'MDB (Hauptboard)';

  @override
  String get boardDbc => 'DBC (Display)';

  @override
  String boardVersionCurrent(String version) {
    return 'Aktuell $version';
  }

  @override
  String boardVersionLastSeen(String version) {
    return 'Zuletzt gesehen mit $version';
  }

  @override
  String previousRunSummary(String when, String version) {
    return 'Letzte Installation abgeschlossen $when, mit $version';
  }

  @override
  String get boardVersionUnknown => 'Version unbekannt';

  @override
  String get actionUpgrade => 'Aktualisieren';

  @override
  String get actionUpgradeDetail =>
      'Behält Einstellungen, Schlüsselkarten, Karten und Fahrten';

  @override
  String get actionCleanInstall => 'Neu installieren';

  @override
  String get actionCleanInstallDetail =>
      'Löscht Einstellungen und Fahrtenverlauf. Schlüsselkarten und Karten werden in diesem Durchlauf neu eingerichtet';

  @override
  String get actionUpgradeDetailDbc => 'Behält die Offline-Karten';

  @override
  String get actionCleanInstallDetailDbc => 'Löscht nur die Offline-Karten';

  @override
  String get actionCleanInstallDetailDbcTiles =>
      'Löscht die Offline-Karten. Sie werden in diesem Durchlauf neu installiert';

  @override
  String get actionLeave => 'Unverändert lassen';

  @override
  String get actionLeaveDetail => 'Dieses Board wird nicht angefasst';

  @override
  String get upgradeBlockedNotLibrescoot =>
      'Aktualisieren setzt eine vorhandene Librescoot-Installation voraus';

  @override
  String get upgradeBlockedStateUnknown =>
      'Aktualisieren setzt eine bekannte Version auf diesem Board voraus';

  @override
  String get upgradeBlockedMinimalImage =>
      'Dieses Board läuft mit einem Bootstrap-Image und muss installiert werden';

  @override
  String get upgradeBlockedNoMender =>
      'Dieses Board hat keinen Update-Client und kann nur neu installiert werden';

  @override
  String get planTilesNeedDbcHandoff =>
      'Für neue Kartendaten muss das DBC-Kabel umgesteckt werden, auch wenn das DBC unverändert bleibt';

  @override
  String get planInstallTiles => 'Offline-Karten aktualisieren';

  @override
  String get planInstallTilesDetail =>
      'Fügt einen DBC-Schritt hinzu: Die Karten wandern auf das MDB, dann wird das Kabel zurückgesteckt und der Roller kopiert sie selbst.';

  @override
  String get planTilesNotDownloaded =>
      'Nicht heruntergeladen. Offline-Karten wurden im ersten Schritt übersprungen.';

  @override
  String get actionLeaveBlockedStockMdb =>
      'Ein Serien-Hauptboard muss installiert werden, bevor sonst etwas geht';

  @override
  String get planDbcNeedsLibrescootMdb =>
      'Das DBC ist nur über das MDB erreichbar, und die Werkzeuge dafür gehören zu Librescoot. Installiere in diesem Durchgang das MDB mit, oder lass das DBC unverändert.';

  @override
  String get planNothingToDo =>
      'Nichts ausgewählt. Mindestens eine Aktion wählen, um fortzufahren.';

  @override
  String get releaseMissingAssetsTitle =>
      'Dieses Release kann nicht installiert werden';

  @override
  String releaseMissingAssetsBody(String tag, String assets) {
    return 'Das Release $tag veröffentlicht nicht alles, was der Installer braucht: $assets. Gehe zurück und wähle einen anderen Kanal, oder warte auf ein Release, das alles enthält.';
  }

  @override
  String get assetMdbArtifact => 'das MDB-Firmware-Artefakt';

  @override
  String get assetDbcArtifact => 'das DBC-Firmware-Artefakt';

  @override
  String get assetMdbImage => 'das MDB-Systemabbild';

  @override
  String get assetDbcImage => 'das DBC-Systemabbild';

  @override
  String get artifactStaging => 'Firmware-Artefakt wird übertragen...';

  @override
  String artifactInstalling(int percent) {
    return 'Firmware wird installiert ($percent%)';
  }

  @override
  String get artifactVerifying => 'Installierte Version wird geprüft...';

  @override
  String get waitingForDbcUpload =>
      'Warte auf das Ende der Display-Übertragung...';

  @override
  String get artifactStillMinimal =>
      'Das MDB ist mit dem Bootstrap-Image zurückgekommen, das Firmware-Artefakt wurde also nicht übernommen. Versuche es erneut oder schreibe stattdessen das vollständige Image.';

  @override
  String artifactVersionMismatch(String found, String expected) {
    return 'Das MDB meldet nach dem Neustart weiterhin $found statt $expected. Die Installation wurde zurückgerollt, es wurde also nichts geändert. Versuche es erneut oder schreibe stattdessen das vollständige Image.';
  }

  @override
  String get artifactInstallFailedHeading =>
      'Firmware-Installation fehlgeschlagen';

  @override
  String get artifactStagingInBackground =>
      'Firmware-Installation wird abgeschlossen...';

  @override
  String get artifactNoneDownloaded =>
      'Für dieses Board wurde kein Firmware-Artefakt heruntergeladen.';

  @override
  String get dbcImageMissing =>
      'Das für diesen Plan benötigte DBC-Systemabbild fehlt.';

  @override
  String get artifactRebootTimeout =>
      'Das MDB ist nach dem Neustart nicht zurückgekommen.';

  @override
  String get artifactPreflightNoMender =>
      'Dieses Board hat keinen Update-Client und kann daher kein Firmware-Artefakt aufnehmen.';

  @override
  String artifactPreflightOtaBusy(String status) {
    return 'Der Roller führt gerade sein eigenes Update aus ($status). Warte, bis es fertig ist und der Roller neu gestartet hat, und versuche es dann erneut.';
  }

  @override
  String artifactPreflightNoSpace(int freeMiB, int neededMiB) {
    return 'Zu wenig Platz in /data: $freeMiB MiB frei, $neededMiB MiB benötigt.';
  }

  @override
  String get artifactRetry => 'Erneut versuchen';

  @override
  String get artifactFallBackToFullImage =>
      'Stattdessen das vollständige Image schreiben';

  @override
  String get fallBackWipeTitle => 'Dabei werden die Daten des Rollers gelöscht';

  @override
  String get fallBackWipeBody =>
      'Beim Schreiben des vollständigen Images wird die Datenpartition neu formatiert. Einstellungen, angelernte Schlüsselkarten, Offline-Karten und Fahrtenhistorie gehen dabei verloren, der Roller kommt wie fabrikneu zurück. Die begonnene Aktualisierung hätte all das behalten.\n\nEin erneuter Versuch mit dem Firmware-Artefakt behält die Daten. Schreibe das vollständige Image nur, wenn das Artefakt weiterhin fehlschlägt.';

  @override
  String get fallBackWipeConfirm => 'Löschen und vollständiges Image schreiben';

  @override
  String get dbcCleanInstallButton => 'DBC löschen und neu installieren';

  @override
  String get dbcCleanInstallTitle => 'Dabei wird das DBC gelöscht';

  @override
  String get dbcCleanInstallBody =>
      'Die zuletzt bekannte Version des DBC ist nur das, was das MDB gesehen hat, als beide zusammen mit Strom versorgt waren. Ein Board, das der Plan für aktualisierbar hielt, hat also womöglich gar keinen Update-Client. Bei einer Neuinstallation wird zuerst das Bootstrap-Image geschrieben, dabei wird die Datenpartition des DBC neu formatiert und die Offline-Karten gehen verloren. Alles auf dem MDB bleibt unberührt, auch Einstellungen, angelernte Schlüsselkarten und Fahrtenhistorie.\n\nDafür muss das Kabel noch einmal umgesteckt werden: Der Installer legt die Dateien ab, du schraubst das DBC-Kabel zurück an das MDB, der Rest läuft unbeaufsichtigt.';

  @override
  String get dbcCleanInstallConfirm => 'DBC löschen und installieren';

  @override
  String firmwareVersionDisplay(String version) {
    return 'Firmware: $version';
  }

  @override
  String healthVersionPlan(String current, String target) {
    return 'Aktuell installierte Version: $current - Zu installierende Version: $target';
  }

  @override
  String get distroStock => 'unu scooterOS';

  @override
  String get distroLibrescoot => 'Librescoot';

  @override
  String healthAuxVoltage(int mv) {
    return '$mv mV';
  }

  @override
  String get openSeatboxButton => 'Sitzbank öffnen';

  @override
  String get reconnectCbbStep => 'CBB wieder anschließen';

  @override
  String get reconnectCbbStepDesc =>
      'Stecke das CBB-Kabel wieder in den Anschluss im Fußraum. Ohne CBB könnte das MDB während des Flashens herunterfahren.';

  @override
  String get mainBatteryMissingHeading => 'Kein Fahrakku erkannt';

  @override
  String get mainBatteryMissingHint =>
      'Der DBC-Flash zieht Strom aus dem Fahrakku. Setz ihn zurück in die Sitzbank, bevor es weitergeht.';

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
  String get dbcFlashDurationHeadline =>
      'Das DBC-Flashen kann 10 bis 20 Minuten dauern.';

  @override
  String get finishHandoverRestoring =>
      'Einstellungen und Dienste werden zurückgesetzt';

  @override
  String get finishHandoverTitle =>
      'Warte darauf, dass der Roller sich entsperrt';

  @override
  String get finishHandoverBody =>
      'Bleib beim Roller, bis er sich entsperrt. Dann kannst du das USB-Kabel abziehen.';

  @override
  String get networkConfigNeedsPermission =>
      'macOS fragt nach Erlaubnis, die Netzwerk-Einstellungen zu ändern. Im Systemdialog auf Erlauben klicken, dann Erneut versuchen drücken.';

  @override
  String get waitingForMdb => 'Warte auf das MDB...';

  @override
  String get dbcFlashAllDone => 'Weiter zum Abschluss';

  @override
  String get dbcFlashSequence =>
      'Ab hier macht der Roller allein weiter: er schreibt das Image auf das Display, startet es neu und spielt die Karten auf. Der Fortschritt steht auf dem Display. Bleib beim Roller, bis eines von beidem passiert.';

  @override
  String get dbcFlashDoNotDisconnect =>
      'USB und Strom nicht trennen, solange das läuft.';

  @override
  String get dbcFlashDoneSignal =>
      'Fertig: der Roller entsperrt sich von selbst. Das ist das Signal, mehr musst du nicht abwarten.';

  @override
  String get dbcFlashFailSignal =>
      'Fehler: die LED am DBC blinkt rot und der Warnblinker geht an. Dann USB zurück auf das MDB stecken und hier das Log holen.';

  @override
  String get dbcFlashLedIsTheSignal =>
      'Die LED am DBC ist das Fehlersignal: blinkt sie rot, ist etwas schiefgegangen.';

  @override
  String get dbcFlashSomethingWrong =>
      'LED blinkt rot: USB zurückstecken und Log holen';

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
  String get mdbReconnectedVerifying =>
      'MDB wieder verbunden. Überprüfung läuft...';

  @override
  String get logDebugShell => 'Log & Debug-Shell';

  @override
  String internalError(String error) {
    return 'Interner Fehler: $error';
  }

  @override
  String get copyLog => 'Log kopieren';

  @override
  String get copyToClipboard => 'In Zwischenablage kopieren';

  @override
  String logFilePath(String path) {
    return 'Logdatei: $path';
  }

  @override
  String get revealLogFile => 'Im Ordner anzeigen';

  @override
  String get debugShell => 'Debug-Shell';

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
  String get gettingStartedTitle => 'So bedienst du den Roller';

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
  String get substepConfigureNetwork => 'Netzwerk konfigurieren';

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
  String get upgradeDowngradeWarning =>
      'Das ist älter als das, was auf dem Board läuft. Aktualisieren behält Einstellungen, Schlüsselkarten, Karten und Fahrten, und ältere Dienste lesen Daten einer neueren Version womöglich nicht. Wenn danach etwas klemmt, neu installieren.';

  @override
  String get upgradeChannelSwitchWarning =>
      'Das ist ein anderer Kanal als der, der auf dem Board läuft. Aktualisieren behält Einstellungen, Schlüsselkarten, Karten und Fahrten, die die Dienste des anderen Kanals womöglich anders lesen. Wenn danach etwas klemmt, neu installieren.';

  @override
  String get tightenDbcCable => 'DBC-Kabel festschrauben';

  @override
  String get tightenDbcCableDesc =>
      'Das interne DBC-USB-Kabel steckt schon im MDB. Schraube es jetzt fest.';

  @override
  String get finalRide => 'Losfahren';

  @override
  String get finalRideDesc =>
      'Der Roller hat sich am Ende der Installation selbst entsperrt. Falls nicht, nimm eine angelernte Schlüsselkarte oder entsperre über Bluetooth.';

  @override
  String notEnoughDiskSpace(String needed) {
    return 'Zu wenig Speicherplatz: $needed fehlen. Schaffe Platz und versuche es erneut.';
  }

  @override
  String get keycardFinishCards => 'Fertig';

  @override
  String get substepCheckExisting => 'Vorhandene Dateien prüfen';

  @override
  String substepVerifying(String filename) {
    return '$filename wird geprüft';
  }

  @override
  String substepUploadFile(String filename) {
    return '$filename übertragen';
  }

  @override
  String get substepUploadFlasher => 'Flash-Werkzeug übertragen';

  @override
  String get substepUploadFwTools => 'DBC-Bootloader-Werkzeuge übertragen';

  @override
  String get substepUploadScript => 'Trampolin-Skript übertragen';

  @override
  String waitStepCounter(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String waitRemaining(String duration) {
    return 'noch etwa $duration';
  }

  @override
  String waitElapsed(String time) {
    return '$time vergangen';
  }

  @override
  String waitLongerThanUsual(String time) {
    return '$time · länger als üblich';
  }

  @override
  String get waitShowLog => 'Protokoll anzeigen';

  @override
  String get waitHideLog => 'Protokoll verbergen';

  @override
  String get blePairingWhy =>
      'Mit einem gekoppelten Handy kannst du den Roller später über die App entsperren und seinen Zustand sehen. Du kannst das auch überspringen und später nachholen.';

  @override
  String get blePairingStep1 => 'Bluetooth am Handy öffnen';

  @override
  String get blePairingStep1Desc =>
      'Die Bluetooth-Einstellungen deines Handys oder die App.';

  @override
  String get blePairingStep2 => 'Roller in der Geräteliste auswählen';

  @override
  String get blePairingStep2Desc =>
      'Er erscheint unter der Adresse, die hier steht.';

  @override
  String get blePairingStep3 => 'PIN bestätigen';

  @override
  String get blePairingStep3Desc =>
      'Die PIN erscheint hier auf dem Bildschirm, sobald dein Handy fragt.';

  @override
  String get blePairingOneAtATime =>
      'Der Roller hält immer nur eine Bluetooth-Verbindung. Ist schon ein Gerät verbunden, trenne es zuerst dort.';

  @override
  String get keycardWhy =>
      'Mit einer angelernten Karte entsperrst du den Roller ohne Handy. Du kannst mehrere Karten anlernen und das später jederzeit wiederholen. Eine Neuinstallation löscht vorher angelernte Karten.';

  @override
  String get keycardStep1 => 'Anlernen starten';

  @override
  String get keycardStep1Desc => 'Der Roller wartet danach auf eine Karte.';

  @override
  String get keycardStep2 => 'Karte an den Leser halten';

  @override
  String get keycardStep2Desc =>
      'Der Leser sitzt vorne am Display. Kurz halten, bis der Installer die Karte zählt.';

  @override
  String get keycardStep3 => 'Fertig drücken';

  @override
  String get keycardStep3Desc =>
      'Damit endet das Anlernen und die Karten gelten.';

  @override
  String get keycardPanelHeading => 'Kartenleser';

  @override
  String get keycardReaderPreparing => 'Wird vorbereitet';

  @override
  String get keycardReaderReady => 'Bereit';

  @override
  String get keycardReaderUnreachable => 'Kartenleser nicht erreichbar';

  @override
  String get keycardReaderScanning => 'Karte an den Leser halten';

  @override
  String keycardCardsTaught(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schlüsselkarten angelernt',
      one: '1 Schlüsselkarte angelernt',
      zero: 'Keine Schlüsselkarte angelernt',
    );
    return '$_temp0';
  }

  @override
  String keycardMastersRegistered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Anlernkarten registriert',
      one: '1 Anlernkarte registriert',
    );
    return '$_temp0';
  }

  @override
  String get keycardNeedOneToFinish => 'Eine Karte reicht zum Abschließen.';

  @override
  String get keycardPreparingReader => 'Kartenleser wird vorbereitet...';

  @override
  String get blePairingDeviceName => 'Gerätename';

  @override
  String get blePairingStateIdle => 'Kopplung nicht gestartet';

  @override
  String get blePairingStateVisible => 'Sichtbar, wartet auf ein Gerät';

  @override
  String get blePinConfirmTitle => 'Diese PIN am Handy bestätigen';

  @override
  String get blePinConfirmHint =>
      'Dein Handy zeigt dieselbe Zahl. Stimmen sie überein, bestätige dort.';

  @override
  String get blePairingStep2DescCompare =>
      'Vergleiche den Namen und die Adresse rechts, wenn mehrere Geräte auftauchen.';

  @override
  String get blePairingStep3DescOverlay =>
      'Der Installer zeigt sie groß an, sobald dein Handy danach fragt.';
}

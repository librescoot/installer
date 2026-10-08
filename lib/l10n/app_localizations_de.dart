// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get laptopCableLabel => 'Laptop-Kabel';

  @override
  String get dashboardCableLabel => 'Dashboard-Kabel';

  @override
  String get verifyingMapsInstallation => 'Karteninstallation prüfen';

  @override
  String get connectionPurpose =>
      'Der Installer erkennt den Hauptcomputer automatisch und richtet die USB-Verbindung ein. Lass das Kabel angeschlossen.';

  @override
  String get checkAgain => 'Erneut prüfen';

  @override
  String get handoffLedSignals =>
      'Die LED am Dashboard blinkt orange, solange auf die Verbindung gewartet wird. Sobald sie dauerhaft orange leuchtet, wurde das Dashboard erkannt und die Installation läuft. Der vordere Leuchtring pulsiert ebenfalls während der Wartezeit. Lass das interne USB-Kabel nach dem Umstecken angeschlossen.';

  @override
  String get handoffDisconnected =>
      'Laptop-Verbindung getrennt. Den weiteren Status erkennst du an den Signalen am Roller.';

  @override
  String get handoffHandsOffBody =>
      'Auch wenn das Dashboard bereits etwas anzeigt, kann die Installation noch laufen. Lass das interne USB-Kabel und die Stromversorgung angeschlossen, bis der Roller den Abschluss signalisiert.';

  @override
  String get handoffCancel => 'Übertragung abbrechen';

  @override
  String get handoffCancelFailed =>
      'Das Warten konnte nicht sicher beendet werden. Lass die Verbindung bestehen und prüfe den Installationsstatus, bevor du etwas veränderst.';

  @override
  String get mapsIncompleteBody =>
      'Es konnte nicht bestätigt werden, dass alle ausgewählten Offline-Karten installiert sind. Du kannst die Karteninstallation später erneut versuchen.';

  @override
  String get retryMaps => 'Karteninstallation wiederholen';

  @override
  String get recoveryCableInstructions =>
      'Lass den Roller eingeschaltet. Löse die beiden Schrauben am internen Dashboard-USB-Stecker am Hauptcomputer (MDB) und ziehe ihn ab. Stecke das Laptop-USB-Kabel in denselben Anschluss. Der Installer stellt die Verbindung wieder her und liest den Installationsstatus und das Fehlerprotokoll aus.';

  @override
  String get reassemblyHeading => 'Roller wieder zusammenbauen';

  @override
  String get checkDashboardCable => 'Dashboard-Kabel prüfen';

  @override
  String get checkDashboardCableDesc =>
      'Prüfe, ob das interne USB-Kabel am Hauptcomputer (MDB) fest sitzt und die beiden Schrauben am Stecker angezogen sind.';

  @override
  String get replaceBraces => 'Querstreben wieder einsetzen';

  @override
  String get replaceBracesDesc =>
      'Setze die beiden Querstreben wieder in ihre Halterungen ein. Achte darauf, keine Kabel einzuklemmen.';

  @override
  String get mdbSoftwareFresh =>
      'Das Grundsystem läuft bereits. Jetzt wird die vollständige Librescoot-Software installiert.';

  @override
  String get mdbSoftwareUpdate =>
      'Die ausgewählte Librescoot-Version wird auf dem Hauptcomputer installiert.';

  @override
  String get downloadsBeforeScooter =>
      'Warte, bis alle Downloads abgeschlossen sind, bevor du zum Roller gehst. Danach kannst du die Installation ohne Internetverbindung fortsetzen.';

  @override
  String get downloadsReadyOffline =>
      'Alles heruntergeladen. Du kannst jetzt mit dem Laptop zum Roller gehen und offline weitermachen.';

  @override
  String get removeBraces => 'Querstreben herausnehmen';

  @override
  String get removeBracesDesc =>
      'Ziehe die beiden eingeklipsten Querstreben nach oben heraus. Dafür musst du keine weiteren Schrauben lösen.';

  @override
  String get continueToUsb => 'Weiter zum USB-Anschluss';

  @override
  String get laptopPrepHeading => 'Laptop anschließen';

  @override
  String get healthCheckPurpose =>
      'Der Installer prüft die Akkus, damit für die Installation ausreichend Strom verfügbar ist.';

  @override
  String get usbPreparationHint =>
      'Der Hauptcomputer startet neu und meldet sich als USB-Laufwerk. Dabei wird die Verbindung kurz unterbrochen. Lass USB-Kabel und Stromversorgung angeschlossen.';

  @override
  String get selectedSettingsRestore =>
      'Die ausgewählten Einstellungen werden nach der Neuinstallation wiederhergestellt.';

  @override
  String get flashAuthorisationHeading => 'Freigabe zum Schreiben erforderlich';

  @override
  String get originalKeycardsNotice =>
      'Schlüsselkarten aus der Original-Firmware müssen neu angelernt werden; ihre Berechtigungen können nicht übernommen werden.';

  @override
  String get continueToBraces => 'Weiter zu den Querstreben';

  @override
  String get handoffShowStatus => 'Weiter zu Status und Signalen';

  @override
  String get handoffCableInstructions => 'USB-Anleitung anzeigen';

  @override
  String handoffElapsed(String elapsed) {
    return 'Seit Kabeltrennung: $elapsed';
  }

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
  String get phaseMdbConnectDescription =>
      'Gerät erkennen und Verbindung herstellen';

  @override
  String get phaseResumeDetectedTitle => 'Vorheriger Versuch';

  @override
  String get phaseResumeDetectedDescription =>
      'Unterbrochene Installation gefunden';

  @override
  String get phaseHealthCheckTitle => 'Statusprüfung';

  @override
  String get phaseHealthCheckDescription => 'Bereitschaft des Rollers prüfen';

  @override
  String get phaseMdbToUmsTitle => 'MDB → UMS';

  @override
  String get phaseMdbToUmsDescription =>
      'Bootloader für den Flashvorgang konfigurieren';

  @override
  String get phaseMdbFlashTitle => 'MDB flashen';

  @override
  String get phaseMdbFlashDescription => 'Firmware auf MDB schreiben';

  @override
  String get phaseScooterPrepTitle => 'Neustart';

  @override
  String get phaseScooterPrepDescription => 'Roller nach Anleitung neu starten';

  @override
  String get phaseMdbBootTitle => 'MDB starten';

  @override
  String get phaseMdbBootDescription =>
      'AUX wieder anschließen und auf den Start warten';

  @override
  String get phaseCbbReconnectTitle => 'CBB anschließen';

  @override
  String get phaseCbbReconnectDescription =>
      'CBB für den DBC-Flash wieder anschließen';

  @override
  String get phaseDbcPrepTitle => 'DBC vorbereiten';

  @override
  String get phaseDbcPrepDescription =>
      'DBC-Systemabbild und Karten übertragen';

  @override
  String get phaseDbcFlashTitle => 'DBC flashen';

  @override
  String get phaseDbcFlashDescription => 'Automatische DBC-Installation';

  @override
  String get phaseReconnectTitle => 'Prüfen';

  @override
  String get phaseReconnectDescription => 'Dashboard-Installation prüfen';

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
      'Dieser Assistent führt dich Schritt für Schritt durch die Installation auf deinem Roller. Plane dafür etwa 20 Minuten ein.';

  @override
  String get updateAvailableTitle => 'Installer-Update verfügbar';

  @override
  String updateAvailableBody(String latestVersion, String currentVersion) {
    return 'Librescoot Installer $latestVersion ist verfügbar. Du verwendest $currentVersion.';
  }

  @override
  String updatePublishedDate(String date) {
    return 'Veröffentlicht am $date';
  }

  @override
  String get updateReleaseNotesTitle => 'Neu in dieser Version';

  @override
  String get updateNotNow => 'Später';

  @override
  String get updateOpenDownloads => 'Downloadseite öffnen';

  @override
  String get requirementsIntro => 'Laptop mit Administratorrechten';

  @override
  String get prerequisiteScrewdriverPH2 =>
      'Kreuzschraubendreher (PH2) oder 4-mm-Innensechskantschlüssel (H4) fürs Fußbrett';

  @override
  String get requirementsFootwell => ' für das Fußbrett, ';

  @override
  String get prerequisiteScrewdriverFlat =>
      'Kleiner Kreuzschraubendreher (PH1) oder Schlitzschraubendreher fürs interne USB-Kabel';

  @override
  String get requirementsDbcCable => ' für die Verschraubung des DBC-Kabels';

  @override
  String get prerequisiteUsbCable => 'USB-Mini-B-Datenkabel';

  @override
  String get requirementsAnd => ' und ';

  @override
  String get requirementsShopLink => 'Shop';

  @override
  String get requirementsOutro =>
      'Laptop ausreichend laden oder Netzteil anschließen; automatischen Ruhezustand deaktivieren.';

  @override
  String get requirementsVideoLink => 'Videoanleitung ansehen ↗';

  @override
  String get reliabilityWarningTitle => 'Verbindung und Laptop vorbereiten';

  @override
  String get reliabilityWarningBody =>
      'Prüfe vor dem Start:\n• Verwende ein zuverlässiges Datenkabel und stecke es an beiden Enden fest ein.\n• Verbinde den Laptop möglichst direkt, ohne Hub oder Dockingstation.\n• Sorge dafür, dass der Laptop ausreichend geladen ist, oder schließe das Netzteil an. Deaktiviere den automatischen Ruhezustand.\n• Bewege während des Schreibens möglichst weder Kabel noch Laptop.';

  @override
  String get noPowerCycleWarningTitle =>
      'Strom und USB nur nach Anweisung trennen';

  @override
  String get noPowerCycleWarningBody =>
      'Wenn der Vorgang scheinbar hängt oder keine Rückmeldung gibt, halte an und frage im Librescoot-Discord nach, bevor du etwas veränderst. Solange der Installer dich nicht ausdrücklich zu etwas anderem auffordert:\n• AUX-Akku und CBB angeschlossen lassen\n• USB-Kabel angeschlossen lassen\n• Roller und Laptop eingeschaltet lassen\n\nEine Unterbrechung während des Schreibens kann dazu führen, dass ein Board nicht mehr startet und wiederhergestellt werden muss.';

  @override
  String get downloadsFailedHeading =>
      'Server für Firmware-Downloads nicht erreichbar';

  @override
  String get downloadsFailedBody =>
      'Prüfe die Internetverbindung des Laptops und versuche es erneut. Du kannst offline fortfahren, wenn die Firmware bereits im Zwischenspeicher liegt.';

  @override
  String get downloadsRetry => 'Erneut versuchen';

  @override
  String get noticesHeading => 'Bevor du deinen Roller vorbereitest';

  @override
  String get noticesSubheading =>
      'Zwei wichtige Hinweise für einen sicheren Installationsvorgang.';

  @override
  String get noticesAcknowledgeButton => 'Gelesen. Weiter';

  @override
  String get noticesWaitingForDownloads => 'Firmware wird geladen…';

  @override
  String get noticesContinueOfflineAnyway =>
      'Fortfahren, während Downloads laufen';

  @override
  String get backButton => 'Zurück';

  @override
  String get elevationRequiredTitle => 'Administratorrechte erforderlich';

  @override
  String get elevationRequiredBody =>
      'Der Librescoot Installer benötigt Administratorrechte, um auf den Speicher des Rollers zu schreiben und die Netzwerkschnittstelle zu konfigurieren. Die Berechtigungsanfrage wurde abgelehnt oder konnte nicht angezeigt werden.\n\nKlicke auf Weiter, um den Dialog zu schließen, und versuche es erneut. Wenn du die Anfrage erneut ablehnst, kann der Installer nicht fortfahren.';

  @override
  String get elevationNoticeWelcome =>
      'Der Installer fragt nach Administratorrechten, um die USB-Verbindung einzurichten und die Software auf den Roller zu schreiben.';

  @override
  String get arm64EmulationNoticeWelcome =>
      'Dieser Rechner hat einen ARM64-Prozessor, der Installer läuft dort in der x64-Emulation. Das kann die USB-Erkennung verlangsamen, und der mitgelieferte USB-Treiber ist nur für x86/x64 gebaut. Am zuverlässigsten ist ein x64-Rechner.';

  @override
  String get requestingAdminPrivileges =>
      'Administratorrechte werden angefragt…';

  @override
  String get firmwareChannel => 'Firmware auswählen';

  @override
  String get channelStable => 'Stabil';

  @override
  String get channelTesting => 'Testing';

  @override
  String get channelNightly => 'Nightly';

  @override
  String get channelStableDesc => 'Getestet und zuverlässig';

  @override
  String get channelRecommended => 'EMPFOHLEN';

  @override
  String get channelTestingDesc =>
      'Testversionen für das nächste Release, ohne Stabilitätsgarantie, nur für technisch versierte Tester*innen empfohlen';

  @override
  String get channelNightlyDesc =>
      'Täglich neu, nur für Entwickler*innen empfohlen';

  @override
  String get nightlyWarningTitle => 'Nightly wirklich auswählen?';

  @override
  String get nightlyWarningLead =>
      'Nightly-Builds sind oft noch nicht getestet und können instabil sein, nicht oder falsch funktionieren oder schlimmstenfalls deinen Roller nicht nutzbar hinterlassen.';

  @override
  String get nightlyWarningBody =>
      'Bitte wähle diesen Kanal nur, wenn du dir der Konsequenzen bewusst bist und diese Wiederherstellung selbst durchführen kannst. Wir können keinen Support für Nightly-Versionen leisten.';

  @override
  String get nightlyWarningCancel => 'Abbrechen';

  @override
  String get nightlyWarningAccept => 'Risiko verstanden, Nightly wählen';

  @override
  String get channelNoReleases => 'Keine Veröffentlichungen verfügbar';

  @override
  String get manifestBundledNotice =>
      'Offline: Diese Versionen stammen aus der im Installer hinterlegten Liste und sind möglicherweise veraltet.';

  @override
  String get loadingChannels => 'Verfügbare Kanäle werden geladen…';

  @override
  String get region => 'Offline-Karten & Navigation';

  @override
  String get localTilesBrowse => 'Durchsuchen…';

  @override
  String get localTilesTitle => 'Eigene Karten- und Navigationsdateien';

  @override
  String get localTilesIntro =>
      'Wähle eine oder beide Dateien. Fehlende Dateien werden für die gewählte Region heruntergeladen.';

  @override
  String get localTilesDrop => 'Dateien hierher ziehen';

  @override
  String get localTilesPick => 'Dateien auswählen';

  @override
  String get localTilesMap => 'Karte (.mbtiles)';

  @override
  String get localTilesRouting => 'Navigation (valhalla_tiles_*.tar[.zst])';

  @override
  String get localTilesUnset => 'Wird heruntergeladen';

  @override
  String get localTilesClear => 'Auswahl entfernen';

  @override
  String get localTilesRemove => 'Datei entfernen';

  @override
  String get localTilesUse => 'Dateien verwenden';

  @override
  String get localTilesActive => 'Eigene Dateien ausgewählt';

  @override
  String get localTilesNoFiles => 'Wähle mindestens eine Datei.';

  @override
  String get localTilesNoRegion => 'Wähle eine Region für die fehlende Datei.';

  @override
  String get localTilesCustomPair =>
      'Für eine eigene Region brauchst du beide Dateien.';

  @override
  String get localTilesInvalidMap =>
      'Die Kartendatei ist keine MBTiles-SQLite-Datei.';

  @override
  String get localTilesUnreadable => 'Die Datei ist nicht lesbar oder leer.';

  @override
  String get localTilesMismatch =>
      'Karten- und Navigationsdatei haben unterschiedliche Regionsnamen.';

  @override
  String get localTilesInvalidRouting =>
      'Die Navigation muss valhalla_tiles_*.tar oder .tar.zst heißen.';

  @override
  String get localTilesInvalidExtension => 'Wähle eine .mbtiles-Kartendatei.';

  @override
  String get localTilesUnsupported =>
      'Nur .mbtiles und valhalla_tiles_*.tar[.zst] sind erlaubt.';

  @override
  String get selectRegion => 'Region auswählen';

  @override
  String get startInstallation => 'Installation starten';

  @override
  String get selectRegionError => 'Wähle eine Region für die Offline-Karten';

  @override
  String get resolvingReleases => 'Veröffentlichungen werden ermittelt…';

  @override
  String get preparingDownloads => 'Herunterladen wird vorbereitet…';

  @override
  String get physicalPrepHeading => 'Fußraum öffnen';

  @override
  String get physicalPrepSubheading =>
      'Öffne zuerst den Fußraum, um den USB-Anschluss zu erreichen.';

  @override
  String get keepScooterAwake => 'Roller entsperren';

  @override
  String get keepScooterAwakeDesc =>
      'Entsperre den Roller mit deiner Schlüsselkarte oder deinem gekoppelten Handy. Lass den Seitenständer ausgeklappt.';

  @override
  String get removeFootwellCover => 'Fußraumabdeckung entfernen';

  @override
  String get removeFootwellCoverDesc =>
      'Löse die vier Schrauben und nimm die Abdeckung ab. Verwende einen Kreuzschraubendreher (PH2) oder 4-mm-Innensechskantschlüssel (H4), je nach Schrauben. Bei reparierten Rollern können auch Torxschrauben verbaut sein.';

  @override
  String get unscrewUsbCable => 'Internes Dashboard-Kabel lösen';

  @override
  String get unscrewUsbCableDesc =>
      'Löse die beiden Schrauben am internen Dashboard-USB-Stecker am Hauptcomputer (MDB) und ziehe ihn ab. Verwende einen kleinen Kreuzschraubendreher (PH1) oder Schlitzschraubendreher.';

  @override
  String get connectLaptopUsb => 'Laptop-USB-Kabel anschließen';

  @override
  String get connectLaptopUsbDesc =>
      'Stecke dein USB-Mini-B-Datenkabel in denselben Anschluss am Hauptcomputer (MDB). Verbinde das andere Ende mit deinem Laptop.';

  @override
  String get doneDetectDevice => 'Fertig. Gerät erkennen';

  @override
  String get connectingToMdb => 'Verbindung zum Roller wird hergestellt';

  @override
  String get waitingForUsbDevice => 'Warte auf USB-Gerät…';

  @override
  String get waitingForRndis =>
      'Warte auf das USB-Gerät… Stelle sicher, dass der Laptop per USB mit dem MDB verbunden ist.';

  @override
  String get checkingRndisDriver => 'RNDIS-Treiber wird geprüft…';

  @override
  String get driverClaimedHeading =>
      'Ein anderes Programm belegt den USB-Anschluss';

  @override
  String driverClaimedBody(String driver) {
    return 'Windows hat die USB-Verbindung des Rollers an $driver statt an den benötigten Netzwerktreiber gebunden. Der Installer kann die Verbindung deshalb nicht verwenden.\n\nÖffne den Geräte-Manager, suche den Roller unter Anschlüsse (COM & LPT), klicke ihn mit der rechten Maustaste an und wähle Gerät deinstallieren. Aktiviere den Haken bei „Die Treibersoftware für dieses Gerät löschen“, falls er angeboten wird. Ziehe den Roller danach ab und stecke ihn wieder an.\n\nAm Roller wurde nichts verändert. Du kannst den Installer gefahrlos schließen.';
  }

  @override
  String get driverClaimedDetailsLabel => 'Details für einen Fehlerbericht';

  @override
  String get driverNeedsRebootHeading => 'Windows braucht einen Neustart';

  @override
  String get driverNeedsRebootBody =>
      'Der Netzwerktreiber wurde installiert, aber Windows konnte ihn nicht aktivieren, solange der Roller angeschlossen war. Starte den Computer neu und führe den Installer danach erneut aus.\n\nAm Roller wurde nichts verändert.';

  @override
  String get driverRecheck => 'Erneut prüfen';

  @override
  String get connectFailedWhatToCheck => 'Was du prüfen kannst';

  @override
  String get connectFailedDetailsLabel => 'Technische Details';

  @override
  String get connectFailedNoDeviceHeading =>
      'Es ist kein USB-Gerät aufgetaucht';

  @override
  String get connectFailedNoDeviceBody =>
      'Das MDB meldet sich als Netzwerkgerät, sobald es angeschlossen und aktiv ist. Bisher wurde über USB kein Gerät erkannt.\n• Stecke das Kabel in den MDB-Port, aus dem du das interne Kabel gezogen hast. Prüfe beide Enden\n• Verbinde es direkt mit dem Laptop, nicht über einen Hub oder eine Dockingstation\n• Verwende ein anderes Kabel. Ladekabel übertragen keine Daten\n• Der Roller muss aktiv sein. Ohne Fahrakku im vorderen Schacht wechselt er automatisch in den Ruhezustand\nDer Installer wartet weiter und fährt automatisch fort, sobald das MDB erkannt wird. Du musst hier nichts anklicken.';

  @override
  String get connectFailedDeviceVanishedHeading =>
      'Das USB-Gerät wurde getrennt';

  @override
  String get connectFailedDeviceVanishedBody =>
      'Das MDB wurde über USB erkannt, ist jetzt aber nicht mehr verbunden. Möglicherweise wurde das Kabel bewegt oder der Roller ist in den Ruhezustand gewechselt.\n• Prüfe das USB-Kabel an beiden Enden\n• Entsperre den Roller oder setze einen Fahrakku in den vorderen Schacht. Ohne eines von beidem wechselt er während der Installation in den Ruhezustand\n• Lass AUX-Akku und CBB angeschlossen\nAm Roller wurde nichts verändert. Versuche es erneut, sobald das MDB wieder erkannt wird.';

  @override
  String get connectFailedNoRouteHeading =>
      'Der Roller ist über USB verbunden, aber nicht erreichbar';

  @override
  String get connectFailedNoRouteBody =>
      'Das MDB ist über USB verbunden, aber dieser Rechner kann es nicht erreichen. Die USB-Netzwerkschnittstelle wurde ohne die vom Installer gesetzte Adresse eingerichtet. Unter Linux übernimmt meist der NetworkManager die Schnittstelle.\n• Versuche es erneut. Der Installer setzt die Adresse bei jedem Versuch neu\n• Setze die Schnittstelle unter Linux im NetworkManager auf „nicht verwaltet“ oder deaktiviere dort IPv6\n• Ziehe das Kabel ab und stecke es wieder an, damit die Schnittstelle neu eingerichtet wird\nIm Protokoll stehen die Schnittstelle und die Route, die der Installer gefunden hat.';

  @override
  String get connectFailedRefusedHeading => 'Verbindung zum Roller abgewiesen';

  @override
  String get connectFailedRefusedBody =>
      'Das MDB hat im Netzwerk geantwortet, aber die Verbindung abgewiesen. Die Netzwerkverbindung steht, der benötigte Dienst ist jedoch noch nicht gestartet. In der ersten Minute nach dem Einschalten ist das normal.\n• Warte einige Sekunden und versuche es erneut\n• Wenn die Verbindung nach einigen Minuten weiterhin abgewiesen wird, öffne die technischen Details, kopiere sie und frage im Librescoot-Discord nach\nAm Roller wurde nichts verändert. Du kannst den Installer gefahrlos schließen.';

  @override
  String get connectFailedTimeoutHeading => 'Keine Antwort vom Roller';

  @override
  String get connectFailedTimeoutBody =>
      'Das MDB ist über USB verbunden, aber innerhalb des Zeitlimits wurde keine Antwort empfangen. Möglicherweise startet der Hauptcomputer noch oder die Verbindung besteht nur auf dieser Seite.\n• Versuche es erneut. Ein noch startender Hauptcomputer antwortet oft beim zweiten oder dritten Versuch\n• Prüfe das USB-Kabel an beiden Enden und verbinde es direkt mit dem Laptop, nicht über einen Hub\n• Der Roller muss aktiv und der AUX-Akku angeschlossen sein\nAm Roller wurde nichts verändert.';

  @override
  String get connectFailedDroppedHeading =>
      'Die Verbindung ist beim Aufbau abgebrochen';

  @override
  String get connectFailedDroppedBody =>
      'Die Verbindung wurde vor dem Abschluss getrennt. Das kann beim Neustart des Hauptcomputers oder beim Wechsel in den Ruhezustand passieren.\n• Entsperre den Roller oder setze einen Fahrakku in den vorderen Schacht. Ohne eines von beidem wechselt er automatisch in den Ruhezustand\n• Prüfe das USB-Kabel an beiden Enden\n• Warte, bis der Hauptcomputer vollständig gestartet ist, und versuche es erneut\nAm Roller wurde nichts verändert.';

  @override
  String get connectFailedAuthHeading => 'Anmeldung am Roller fehlgeschlagen';

  @override
  String get connectFailedAuthBody =>
      'Die Verbindung steht, aber alle dem Installer bekannten Anmeldedaten wurden abgelehnt. Bei einem Serienroller wurde möglicherweise das Root-Passwort geändert, etwa in einer Werkstatt.\n• Versuche es erneut. Wenn der Roller ein Passwort verlangt, zeigt der Installer ein Eingabefeld an\n• Frage nach, ob für den Roller ein Root-Passwort festgelegt wurde\n• Frage andernfalls im Librescoot-Discord nach und füge die technischen Details hinzu\nAm Roller wurde nichts verändert. Du kannst den Installer gefahrlos schließen.';

  @override
  String get connectFailedUnknownHeading =>
      'Der Installer erreicht den Roller nicht';

  @override
  String get connectFailedUnknownBody =>
      'Die Verbindung ist aus einem unbekannten Grund fehlgeschlagen. Die technischen Details unten werden für einen Fehlerbericht benötigt.\n• Prüfe das USB-Kabel an beiden Enden und verbinde es direkt mit dem Laptop, nicht über einen Hub\n• Der Roller muss aktiv und der AUX-Akku angeschlossen sein\n• Versuche es erneut\nAm Roller wurde nichts verändert. Du kannst den Installer gefahrlos schließen.';

  @override
  String get configuringNetwork => 'Netzwerk wird konfiguriert…';

  @override
  String get connectingSsh => 'Verbindung wird hergestellt…';

  @override
  String get waitingForUnlock => 'Roller entsperren, um fortzufahren…';

  @override
  String get unfinishedInstallDetected =>
      'Unvollständige Installation erkannt, Entsperren wird übersprungen…';

  @override
  String get waitingForBatteryData => 'Warte auf AUX- und CBB-Akkudaten…';

  @override
  String get resumeFoundHeading => 'Unterbrochene Installation gefunden';

  @override
  String get resumeFoundBody =>
      'Eine unterbrochene Installation wurde erkannt. Der Installer bereinigt den vorherigen Versuch, bevor er neu beginnt.';

  @override
  String get previousInstallErrorHeading =>
      'Vorherige Installation fehlgeschlagen';

  @override
  String get previousInstallErrorBody =>
      'Auf dem MDB liegt ein Fehler einer früheren Installation. Lies das Protokoll, bevor du fortfährst; der Roller benötigt möglicherweise Aufmerksamkeit.';

  @override
  String get previousInstallErrorNoLog =>
      'Auf dem MDB ist kein Protokolltext erhalten geblieben.';

  @override
  String get resumeWhatHappensHeading => 'Was beim Weitermachen passiert';

  @override
  String get resumeWhatHappensCleanup =>
      'Zurückgebliebene Dateien und das Onboot-Skript werden bereinigt; angehaltene Dienste werden wieder gestartet.';

  @override
  String get resumeWhatHappensRestart =>
      'Die Installation beginnt vollständig neu. Kein unvollständiger Schritt wird fortgesetzt.';

  @override
  String get resumeWhatHappensKeep =>
      'Es gehen keine weiteren Daten verloren. Änderungen des vorherigen Durchlaufs bleiben bestehen.';

  @override
  String get resumeTakesAsLong =>
      'Es dauert so lange wie eine normale Installation, ungefähr 20 Minuten.';

  @override
  String get resumeClearingLeftovers =>
      'Reste der vorherigen Installation werden bereinigt…';

  @override
  String resumeCleanupFailed(String error) {
    return 'Die vorige Installation konnte nicht sicher bereinigt werden: $error\n\nEs wird nichts weiter ausgeführt, bis die Bereinigung erfolgreich war.';
  }

  @override
  String get resumeFoundLastError => 'Letzter aufgezeichneter Fehler:';

  @override
  String get resumeRunningHeading =>
      'Eine Installation läuft noch auf dem Roller';

  @override
  String get resumeRunningBody =>
      'Die vorherige Installation läuft auf dem Roller noch. Währenddessen werden keine Änderungen vorgenommen.';

  @override
  String get resumeRunningWait =>
      'Warte, bis die Installation abgeschlossen ist. Danach geht es hier automatisch weiter.';

  @override
  String resumeStageLabel(String stage) {
    return 'Zuletzt: $stage';
  }

  @override
  String get resumeActorScooter => 'auf dem Roller';

  @override
  String get resumeActorInstaller => 'im Installer';

  @override
  String get resumeLogHeading => 'Letzte Zeilen aus dem Protokoll des Rollers';

  @override
  String get awaitingUnlockHeading => 'Roller entsperren';

  @override
  String get unlockWaitCancelled =>
      'Abgebrochen. Der Installer braucht den Roller im Zustand geparkt. Entsperre ihn mit der Keycard oder der App und versuch es dann erneut.';

  @override
  String get parkWaitCancelled =>
      'Abgebrochen. Der Installer braucht den Roller im Zustand geparkt. Stell ihn ab und versuch es dann erneut.';

  @override
  String get awaitingUnlockDetail =>
      'Entsperre den Roller, damit der Installer fortfahren kann.';

  @override
  String get awaitingUnlockHintKeycard =>
      'Halte die Schlüsselkarte an den Leser am Lenker';

  @override
  String get awaitingUnlockHintPhone => 'Oder verwende ein gekoppeltes Handy';

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
      'Parke den Roller (Seitenständer ausklappen), um fortzufahren.';

  @override
  String get awaitingParkContinueAnyway => 'Trotzdem weiter';

  @override
  String get lockingScooter => 'Roller wird für das Flashen gesperrt…';

  @override
  String get connected => 'Verbunden';

  @override
  String sshConnectionFailed(String error) {
    return 'Verbindung fehlgeschlagen: $error. Prüfe das Kabel und versuche es erneut.';
  }

  @override
  String get manualPasswordTitle => 'Root-Passwort erforderlich';

  @override
  String get manualPasswordPrompt =>
      'Das Root-Passwort konnte nicht automatisch ermittelt werden. Gib das Root-Passwort für dieses Gerät ein.';

  @override
  String manualPasswordPromptVersion(String version) {
    return 'Das Root-Passwort für Firmware $version konnte nicht automatisch ermittelt werden. Gib das Root-Passwort für dieses Gerät ein.';
  }

  @override
  String manualPasswordPromptRetry(int remaining) {
    return 'Das Passwort war falsch. Versuche es erneut ($remaining Versuche verbleiben).';
  }

  @override
  String get manualPasswordFieldLabel => 'Passwort';

  @override
  String get manualPasswordSubmit => 'Verbinden';

  @override
  String get manualPasswordUnknown => 'Ich kenne es nicht';

  @override
  String get manualPasswordUnknownHeading =>
      'Das Root-Passwort ist nicht verfügbar';

  @override
  String get manualPasswordUnknownBody =>
      'Der Installer kennt normalerweise das Root-Passwort des Rollers. Dieses Passwort wurde möglicherweise geändert.\n\nFrage in der Werkstatt nach, falls der Roller dort war, oder frage im Librescoot-Discord nach. Nenne dabei die oben angezeigte Firmware-Version.\n\nAm Roller wurde nichts verändert. Du kannst den Installer gefahrlos schließen.';

  @override
  String get untestedFirmwareHeading => 'Ungetestete Firmware-Version';

  @override
  String untestedFirmwareBody(String version) {
    return 'Die Installation auf Firmware-Versionen älter als 1.12.0 wurde nicht getestet (deine: $version). Der Installer sollte trotzdem funktionieren. Melde Probleme bitte im Librescoot-Discord.';
  }

  @override
  String get openLibrescootDiscord => 'Librescoot-Discord öffnen';

  @override
  String get healthCheckHeading => 'Statusprüfung';

  @override
  String get incompleteImageStatus =>
      'Unvollständiges Firmware-Systemabbild erkannt. Neuinstallation zur Wiederherstellung…';

  @override
  String get incompleteImageHeading => 'Unvollständiges Firmware-Systemabbild';

  @override
  String get incompleteImageBody =>
      'Auf diesem Roller läuft ein minimales Wiederherstellungs-Systemabbild. Es startet und antwortet, enthält aber keine Fahrzeugdienste. Das kann nach einer unterbrochenen Installation passieren. Fahre fort, um das vollständige Systemabbild zu installieren und die Einrichtung abzuschließen.';

  @override
  String get reflashToRecover =>
      'Systemabbild zur Wiederherstellung installieren';

  @override
  String get stockFirmwareStatus =>
      'Original-Firmware erkannt. Bereit für die Librescoot-Installation…';

  @override
  String get stockFirmwareHeading => 'Original-Firmware';

  @override
  String get stockFirmwareBody =>
      'Auf diesem Roller läuft die Original-Firmware. Fahre fort, um Librescoot zu installieren.';

  @override
  String get continueButton => 'Weiter';

  @override
  String get retryButton => 'Erneut versuchen';

  @override
  String get proceedAtOwnRisk => 'Auf eigenes Risiko fortfahren';

  @override
  String get auxBatteryCharge => 'AUX-Akku: Ladestand';

  @override
  String get cbbStateOfHealth => 'CBB: Akkuzustand';

  @override
  String get cbbCharge => 'CBB: Ladestand';

  @override
  String get mainBattery => 'Fahrakku: Ladestand';

  @override
  String get present => 'vorhanden';

  @override
  String get notPresent => 'nicht vorhanden';

  @override
  String get healthValueUnknown => 'nicht auslesbar';

  @override
  String get riskAuxLow =>
      'Ein schwacher AUX-Akku kann MDB oder DBC während des Flashens abschalten. Auch die LED-Anzeigen können ausfallen. Schließe die Sitzbank mit eingesetztem Fahrakku und warte, bis der AUX-Akku geladen ist.';

  @override
  String get riskCbbSoh =>
      'Ein schlechter CBB-Zustand kann während des Flashens zu einer unzuverlässigen Stromversorgung führen.';

  @override
  String get riskCbbCharge =>
      'Eine niedrige CBB-Ladung erhöht beim DBC-Flash das Risiko eines Stromausfalls. Schließe die Sitzbank mit eingesetztem Fahrakku und warte, bis die CBB geladen ist.';

  @override
  String get riskNoBattery =>
      'Ohne Fahrakku entlädt sich der AUX-Akku schneller. Der Roller kann bei längeren Vorgängen herunterfahren.';

  @override
  String get openSeatbox => 'Sitzbank öffnen';

  @override
  String get configuringMdbBootloader => 'Hauptcomputer vorbereiten';

  @override
  String get preparing => 'Vorbereitung…';

  @override
  String get uploadingBootloaderTools =>
      'Bootloader-Werkzeuge werden übertragen…';

  @override
  String get rebootingMdbUms => 'Hauptcomputer wird neu gestartet…';

  @override
  String get waitingForUmsDevice => 'Warte auf das USB-Laufwerk…';

  @override
  String get readyToFlash => 'Hauptcomputer (MDB) neu installieren';

  @override
  String get readyToFlashHint =>
      'Der Hauptcomputer (MDB) ist jetzt als USB-Laufwerk verbunden. Prüfe das Zielgerät vor dem Schreiben.';

  @override
  String get readyToFlashTargetLabel => 'Ziel';

  @override
  String get readyToFlashImageLabel => 'Zu schreibendes Systemabbild';

  @override
  String get readyToFlashErases =>
      'Dabei werden die Daten auf dem Hauptcomputer überschrieben.';

  @override
  String get readyToFlashDuration =>
      'Das Schreiben dauert etwa 2 Minuten. Trenne währenddessen weder das USB-Kabel noch die Stromversorgung. Bewege möglichst weder Kabel noch Laptop.';

  @override
  String get readyToFlashNoTarget => 'Noch kein Zielgerät gefunden.';

  @override
  String get waitingForDeviceRedetection =>
      'Warte darauf, dass das Gerät erneut erkannt wird…';

  @override
  String get macosDiskNotReadable =>
      'macOS meldet möglicherweise, dass das Medium nicht gelesen werden kann. Klicke auf „Ignorieren“, nicht auf „Initialisieren“ oder „Auswerfen“.';

  @override
  String get macosNoRouteHeading =>
      'macOS blockiert den Zugriff auf den Roller';

  @override
  String get macosNoRouteBody =>
      'Die USB-Verbindung steht und das MDB antwortet auf Pings. macOS blockiert jedoch den Zugriff des Installers.\n\nÖffne „Datenschutz & Sicherheit“ > „Lokales Netzwerk“ und aktiviere den Zugriff für Librescoot Installer.\n\nDer Installer fährt automatisch fort, sobald du den Zugriff aktiviert hast.';

  @override
  String get macosOpenLocalNetworkSettings =>
      'Einstellungen „Lokales Netzwerk“ öffnen';

  @override
  String get beginFlashing => 'Installation starten';

  @override
  String get flashingMdb =>
      'Software wird auf den Hauptcomputer (MDB) geschrieben';

  @override
  String get flashingMdbSubheading =>
      'Zweiphasiges Schreiben: erst Partitionen, dann Bootsektor.';

  @override
  String get flashAwaitingAuthorisation =>
      'macOS fragt vor dem Schreiben nach deinem Passwort oder Touch ID. Suche nach einem Systemdialog, der sich hinter diesem Fenster befinden kann. Solange du nicht bestätigst, wird nichts geschrieben.';

  @override
  String get waitingForMdbFirmware =>
      'Warte auf den Download der MDB-Firmware…';

  @override
  String get mdbFlashComplete => 'MDB-Flash abgeschlossen';

  @override
  String get flashVerifyingReadback => 'Geschriebene Daten werden geprüft…';

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
    return 'Noch $minutes Min. $seconds Sek.';
  }

  @override
  String flashProgressBootSector(String mb) {
    return 'Bootsektor: $mb MB geschrieben';
  }

  @override
  String get scooterPrepHeading => 'Roller neu starten';

  @override
  String get scooterPrepSubheading =>
      'Die Software wurde geschrieben. Starte den Roller mit den Bremshebeln neu. Lass USB-Kabel und Stromversorgung angeschlossen.';

  @override
  String get disconnectCbb => 'CBB trennen';

  @override
  String get disconnectCbbDesc =>
      'Trenne zuerst die CBB und dann den AUX-Pol. Der Fahrakku ist zu diesem Zeitpunkt bereits ausgeschaltet; das MDB befindet sich im Flash-Modus und kommuniziert nicht mehr mit ihm. Du musst ihn nicht ausbauen.';

  @override
  String get disconnectAuxPole => 'Einen AUX-Pol trennen';

  @override
  String get disconnectAuxPoleDesc =>
      'Entferne nur den Pluspol (außen, rotes Kabel und Pol), um eine Verpolung zu vermeiden. Dadurch wird das MDB stromlos und die USB-Verbindung geht verloren.';

  @override
  String get auxDisconnectWarning =>
      'Die USB-Verbindung geht verloren, wenn du AUX trennst. Das ist normal. Schließe den AUX-Pol im nächsten Schritt wieder an, um das MDB zu starten.';

  @override
  String get doneBrakeRestart => 'Bremshebel-Neustart ausgelöst';

  @override
  String get brakeResetHeading => 'Roller neu starten';

  @override
  String get brakeResetIntro =>
      'Ziehe beide Bremshebel und halte sie fest. Lass nach 10, 20 und 30 Sekunden nur den rechten Hebel jeweils etwa eine Sekunde los und ziehe ihn wieder. Halte den linken Hebel durchgehend gezogen. Lass nach 40 Sekunden beide Hebel los.';

  @override
  String get brakeResetAfterNote =>
      'Die USB-Verbindung wird während des Neustarts unterbrochen. Das ist normal; der Installer wartet auf den Hauptcomputer.';

  @override
  String get brakePacerStart => 'Timer starten';

  @override
  String get brakePacerStop => 'Timer stoppen';

  @override
  String get brakePacerRestart => 'Erneut starten';

  @override
  String get brakePacerDone =>
      'Wenn du das Muster richtig befolgt hast, sollte der Roller innerhalb von 10–20 Sekunden neu starten. Wenn die LED im Tacho leuchtet, ist der Neustart im Gange.';

  @override
  String get brakeDiagramBlipLegend =>
      'Rechten Hebel etwa eine Sekunde loslassen';

  @override
  String brakeDiagramEndLegend(int seconds) {
    return 'Bei $seconds Sekunden loslassen';
  }

  @override
  String get brakeBandBothHeld => 'Linker Hebel bleibt durchgehend gezogen';

  @override
  String get brakeBlipRight => 'Rechten Hebel jetzt loslassen';

  @override
  String get brakeLeftStaysHint =>
      'Der linke Hebel bleibt die ganze Zeit gezogen.';

  @override
  String get brakeLeadInLabel => 'Beide Bremsen ziehen in';

  @override
  String get brakeLeadInHint =>
      'Gehe zum Lenker und lege die Hände an die Bremshebel.';

  @override
  String get brakeKeepHolding => 'Beide Bremsen ziehen und halten';

  @override
  String get brakeReleaseNow => 'Beide Bremsen loslassen';

  @override
  String get scooterPrepManualFallback =>
      'Alternative: Stromversorgung nach Anleitung trennen';

  @override
  String get confirmManualPowerCut => 'Ich habe CBB und AUX getrennt';

  @override
  String get deactivatingMainBattery => 'Fahrakku wird abgeschaltet…';

  @override
  String get waitingForMdbBoot => 'Warte auf den Hauptcomputer';

  @override
  String get manualRestartFallbackAction => 'Alternative Neustartanleitung';

  @override
  String get manualRestartFallbackTitle => 'Andere Neustartmethode verwenden?';

  @override
  String get manualRestartFallbackWarning =>
      'Der MDB-Start kann einige Minuten dauern. Trenne CBB und AUX nicht während eines laufenden Neustarts. Wechsle nur, wenn der Bremshebel-Neustart nicht funktioniert hat.';

  @override
  String get mdbBootRestartingNote =>
      'Die USB-Verbindung wird kurz unterbrochen. Der Start kann einige Minuten dauern; der Installer fährt automatisch fort. Lass USB-Kabel und Stromversorgung angeschlossen.';

  @override
  String get reconnectAuxPole => 'AUX-Pluspol wieder anschließen';

  @override
  String get reconnectAuxPoleDesc =>
      'Schließe den AUX-Pluspol wieder an. Die CBB bleibt getrennt, bis der Installer dich zum Anschließen auffordert. Der Hauptcomputer startet jetzt mit Librescoot.';

  @override
  String get dbcLedHint =>
      'DBC-LED: orange = startet, grün = bootet, aus = läuft';

  @override
  String get mdbStillUms =>
      'MDB weiterhin im UMS-Modus. Der Flashvorgang war möglicherweise nicht erfolgreich. Neuer Versuch…';

  @override
  String get waitingForMdbRestart => 'Warte auf den Neustart des Rollers…';

  @override
  String mdbBootGaveUp(int minutes) {
    return 'Der Roller ist nach $minutes Minuten nicht zurückgekommen. Ein Board, das das Image nicht übernommen hat, bleibt im Massenspeichermodus und wirkt dadurch tot: kein Licht, kein Netzwerk. Zieh das USB-Kabel ab, steck es wieder ein und versuch es erneut.';
  }

  @override
  String get mdbDetectedNetwork =>
      'MDB im Netzwerkmodus erkannt. Warte auf eine stabile Verbindung…';

  @override
  String pingStable(int count) {
    return 'Ping stabil: $count/10';
  }

  @override
  String get waitingStableConnection => 'Warte auf eine stabile Verbindung…';

  @override
  String get stableConnectionStallHint =>
      'Verbindung weiterhin instabil. Die USB-Netzwerkschnittstelle hat möglicherweise ihre IP-Adresse verloren. Unter Linux kann NetworkManager die Schnittstelle blockieren; das Deaktivieren von IPv6 kann helfen. Details stehen im Protokoll.';

  @override
  String get dashboardRetryIdentityFailed =>
      'Der verbundene Hauptcomputer (MDB) passt nicht zu dieser Installation. Verbinde den ursprünglichen Roller wieder per USB mit dem Laptop.';

  @override
  String get reconnectingSsh => 'Verbindung wird wiederhergestellt…';

  @override
  String sshReconnectionFailed(String error) {
    return 'Erneute Verbindung fehlgeschlagen: $error';
  }

  @override
  String get reconnectCbbHeading => 'CBB wieder anschließen';

  @override
  String get verifyCbbConnection => 'CBB-Verbindung prüfen';

  @override
  String get verifyBatteryPresence => 'Akku prüfen';

  @override
  String get turningMainBatteryOff => 'Fahrakku wird zuerst abgeschaltet…';

  @override
  String get turningMainBatteryOn => 'Fahrakku wird wieder eingeschaltet…';

  @override
  String get checkingCbb => 'CBB wird geprüft…';

  @override
  String waitingForCbb(int attempts) {
    return 'Warte auf CBB… ($attempts)';
  }

  @override
  String get cbbNotDetected => 'CBB nicht erkannt. Prüfe die Verbindung.';

  @override
  String get mainBatteryNotDetected =>
      'Fahrakku nicht erkannt. Prüfe, ob er richtig eingesetzt ist.';

  @override
  String get cbbDetectionMayTakeMinutes =>
      'Die Erkennung kann mehrere Minuten dauern.';

  @override
  String get preparingDbcFlash => 'Dashboard (DBC) vorbereiten';

  @override
  String get preparingDbcFlashSubtitle =>
      'Lass das Laptop-USB-Kabel noch angeschlossen.';

  @override
  String get preparingDbcFlashExplainer =>
      'Der Installer überträgt die Dashboard-Software und die ausgewählten Offline-Karten auf den Hauptcomputer (MDB). Dieser übernimmt anschließend die Installation auf dem Dashboard.';

  @override
  String get preparingMapTransfer => 'Karten werden übertragen';

  @override
  String get preparingMapTransferSubtitle =>
      'Lass das Laptop-USB-Kabel noch angeschlossen.';

  @override
  String get preparingMapTransferExplainer =>
      'Der Installer überträgt die ausgewählten Offline-Karten auf den Hauptcomputer (MDB). Dieser kopiert sie anschließend auf das Dashboard (DBC). Die Dashboard-Software bleibt unverändert.';

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
  String get phaseDbcFlashDescriptionMaps => 'Automatische Kartenübertragung';

  @override
  String get dbcReadyButtonMaps => 'Kartenübertragung starten';

  @override
  String get waitingForDownloads =>
      'Warte, bis das Herunterladen abgeschlossen ist…';

  @override
  String get filesStagedWaitingForHandoff =>
      'Alle Dateien sind übertragen. Der Hauptcomputer wird für das automatische Warten auf das Dashboard vorbereitet. Lass das Laptop-USB-Kabel noch angeschlossen.';

  @override
  String get handoffPreparationFailed =>
      'Alle Dateien sind übertragen, aber die Vorbereitung für das automatische Warten auf das Dashboard ist fehlgeschlagen. Lass das Laptop-USB-Kabel angeschlossen. Du kannst die Vorbereitung erneut versuchen oder den Roller ohne Dashboard-Übertragung wiederherstellen.';

  @override
  String handoffPreparationError(String error) {
    return 'Die Übergabe an das Dashboard konnte nicht vorbereitet werden: $error';
  }

  @override
  String get handoffEstimateBriefDisclaimer =>
      'Zeitbasierte Schätzung ab Abziehen des Laptop-Kabels – keine Live-Daten vom Dashboard.';

  @override
  String get handoffEstimateExplanation =>
      'Die Schätzung läuft ab Kabeltrennung und umfasst auch das Warten auf die Dashboard-Verbindung. Der tatsächliche Start wird durch die dauerhaft orange leuchtende LED angezeigt. Schließe den Laptop nicht aufgrund der Schätzung wieder an; beachte die Signale am Roller.';

  @override
  String handoffEstimateMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String handoffEstimateRemaining(String left) {
    return 'Geschätzt noch $left';
  }

  @override
  String handoffEstimateRemainingUpper(String to) {
    return 'Geschätzt noch bis zu $to';
  }

  @override
  String handoffEstimateTotalRange(String from, String to) {
    return 'Geschätzte Dauer ab Kabeltrennung: $from–$to';
  }

  @override
  String get handoffEstimateTakingLonger =>
      'Die Schätzung ist überschritten. Beachte die Signale am Roller; trenne Kabel und Strom nur nach Anweisung.';

  @override
  String get startingTrampoline =>
      'Installation auf dem Roller wird gestartet…';

  @override
  String uploadError(String error) {
    return 'Übertragungsfehler: $error';
  }

  @override
  String trampolineStartFailed(String path) {
    return 'Die Installation auf dem Roller konnte nicht gestartet werden. Details stehen im Protokoll; Diagnose-Dateien wurden unter $path gespeichert. Versuche es erneut. Falls der Fehler bestehen bleibt, stelle den Roller ohne diese Übertragung wieder her.';
  }

  @override
  String get trampolineStartFailedNoPath =>
      'Die Installation auf dem Roller konnte nicht gestartet werden. Details stehen im Installer-Protokoll. Versuche es erneut. Falls der Fehler bestehen bleibt, stelle den Roller ohne diese Übertragung wieder her.';

  @override
  String get restoreScooterWithoutTransfer =>
      'Roller ohne diese Übertragung wiederherstellen';

  @override
  String get restoreScooterBeforeClosing =>
      'Stelle den Roller wieder her, bevor du den Installer schließt. Versuche die Übertragung erneut oder wähle „Roller ohne diese Übertragung wiederherstellen“.';

  @override
  String get finishTransferSkippedPending =>
      'Die Übertragung wurde übersprungen. Die normalen Dienste werden wiederhergestellt. Der Roller wird automatisch entsperrt, sobald er bereit ist.';

  @override
  String get finishTransferSkippedConfirmed =>
      'Der Roller wurde wiederhergestellt und entsperrt. Die gewünschte Dashboard-Software oder die ausgewählten Karten wurden nicht installiert.';

  @override
  String get dbcReadyButton => 'DBC-Installation starten';

  @override
  String get dbcFlashInProgress => 'Installation auf dem Dashboard (DBC)';

  @override
  String get dbcFlashSwapCablesTitle => 'USB-Kabel umstecken';

  @override
  String get dbcFlashSwapCablesDeadline =>
      'Alle benötigten Dateien sind auf dem Hauptcomputer (MDB). Du kannst jetzt das Kabel umstecken. Der Roller wartet auf das Dashboard.';

  @override
  String get disconnectUsbFromLaptop => 'Laptop-USB-Kabel abziehen';

  @override
  String get disconnectUsbFromLaptopDesc =>
      'Ziehe das Laptop-USB-Kabel am Hauptcomputer (MDB) ab.';

  @override
  String get reconnectDbcUsbToMdb => 'Internes Dashboard-Kabel anschließen';

  @override
  String get reconnectDbcUsbToMdbDesc =>
      'Stecke das interne Dashboard-Kabel in denselben Anschluss. Ziehe die beiden Schrauben am Stecker wieder fest.';

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
  String get blinkerStepFlash => 'Dashboard vorbereiten';

  @override
  String get blinkerStepRestart => 'Dashboard neu starten';

  @override
  String get blinkerStepMaps => 'Offline-Karten kopieren';

  @override
  String get verifyingDbcInstallation =>
      'Installation auf dem Dashboard (DBC) prüfen';

  @override
  String get reconnectUsbToLaptop =>
      'Laptop-USB-Kabel wieder am MDB anschließen…';

  @override
  String get waitingForRndisDevice => 'Warte auf RNDIS-Gerät…';

  @override
  String get checkingCompletionRecord => 'Abschlussprotokoll wird geprüft…';

  @override
  String get readingTrampolineStatus =>
      'Status der laufenden Installation wird geprüft…';

  @override
  String readingTrampolineStatusElapsed(int elapsed) {
    return 'Status der laufenden Installation wird geprüft… (${elapsed}s)';
  }

  @override
  String get dbcFlashSuccessful => 'Dashboard-Installation abgeschlossen';

  @override
  String dbcInstallSuccessfulVersion(String version) {
    return 'DBC-Installation erfolgreich. Version $version läuft jetzt.';
  }

  @override
  String dbcFlashFailed(String message) {
    return 'DBC-Flash fehlgeschlagen: $message';
  }

  @override
  String get dbcFlashError => 'DBC-Flash fehlgeschlagen';

  @override
  String get closeButton => 'Schließen';

  @override
  String get showDetails => 'Details anzeigen';

  @override
  String get dbcIncompleteHeading => 'Dashboard-Installation unvollständig';

  @override
  String get dbcMapsIncompleteHeading => 'Karteninstallation unvollständig';

  @override
  String dbcIncompleteBody(String reason) {
    return 'Die angeforderten Arbeiten auf dem Dashboard wurden nicht als abgeschlossen bestätigt. $reason';
  }

  @override
  String get finishWithoutDbc => 'Unvollständig abschließen';

  @override
  String get finishWithoutDbcConfirmTitle =>
      'Installation unvollständig abschließen?';

  @override
  String get finishWithoutDbcConfirmBody =>
      'Die Installation auf dem Dashboard (DBC) wurde nicht als erfolgreich abgeschlossen bestätigt. Bereits abgeschlossene Arbeiten auf dem Hauptcomputer (MDB) bleiben erhalten. Die Gesamtinstallation bleibt jedoch unvollständig. Du kannst die Dashboard-Installation später erneut versuchen.';

  @override
  String get finishWithoutDbcPendingMdbBody =>
      'Die ausgewählte Software für den Hauptcomputer (MDB) ist übertragen, aber noch nicht installiert. Wenn du fortfährst, wird sie installiert und der Hauptcomputer neu gestartet. Anschließend werden Einstellungen und Dienste wiederhergestellt. Die Dashboard-Installation wird übersprungen; die Gesamtinstallation bleibt unvollständig.';

  @override
  String get dbcFinishedWithoutCompletionReason =>
      'Du hast den Vorgang ohne bestätigte DBC-Installation abgeschlossen.';

  @override
  String get finishWithoutDbcHeading => 'Installation unvollständig';

  @override
  String finishWithoutDbcBody(String reason) {
    return 'Die Installation auf dem Dashboard (DBC) ist nicht als erfolgreich abgeschlossen bestätigt. Bereits abgeschlossene Arbeiten auf dem Hauptcomputer (MDB) bleiben erhalten. $reason';
  }

  @override
  String get trampolineStatusUnknown =>
      'Der Installer konnte nicht feststellen, ob die Dashboard-Installation abgeschlossen wurde. Einzelheiten stehen im Installationsprotokoll.';

  @override
  String get welcomeToLibrescoot => 'Willkommen bei Librescoot';

  @override
  String get finishStatusTitle => 'Installationsstatus';

  @override
  String get finishPendingHeading => 'Installation läuft noch';

  @override
  String get mdbFinishWaitTitle => 'Warte auf den Roller';

  @override
  String get mdbFinishReconnectCable =>
      'Zieh das Laptop-Kabel vom MDB ab und verbinde das DBC-Kabel wieder.';

  @override
  String get mdbFinishKeepCable => 'Lass das DBC-Kabel mit dem MDB verbunden.';

  @override
  String get mdbFinishWaitHint =>
      'Lass den Roller eingeschaltet. Klicke erst bei einem Signal auf das passende Bild.';

  @override
  String get mdbFinishSuccessPrompt =>
      'Der Roller hat sich entsperrt: Das Standlicht und das Rücklicht leuchten';

  @override
  String get mdbFinishFailureTitle => 'Installationsfehler';

  @override
  String get mdbFinishFailureBody =>
      'Die DBC-LED blinkt rot. Verbinde den Laptop wieder mit dem MDB und klicke auf Erneut prüfen. Lass den Roller eingeschaltet.';

  @override
  String get finishCompleteHeading => 'Installation abgeschlossen';

  @override
  String get finishSkippedHeading => 'Dashboard-Übertragung übersprungen';

  @override
  String get finalSteps => 'Letzte Schritte:';

  @override
  String get finishOnDevice =>
      'Der Roller schließt die Installation selbstständig ab. Lass ihn eingeschaltet und behalte die aktuelle Kabelverbindung bei, bis der Vorgang beendet ist.';

  @override
  String get finishReconnectDbc =>
      'Der Laptop ist wieder mit dem MDB verbunden. Schließe das DBC-Kabel wieder an, damit die Installation abgeschlossen werden kann.';

  @override
  String get finishReconnectDbcNoDashboardWork =>
      'Der Roller schließt die Installation selbstständig ab; der Laptop wird nicht mehr gebraucht. Zieh das Laptop-Kabel ab, schließe das DBC-Kabel wieder an und warte, bis der Roller entsperrt.';

  @override
  String get finishConfirmed =>
      'Die Installation ist abgeschlossen. Der Roller ist entsperrt und fahrbereit.';

  @override
  String get finishPendingNowTitle => 'Der Roller arbeitet jetzt allein weiter';

  @override
  String get finishPendingStepsTitle => 'Was jetzt passiert';

  @override
  String get finishPendingStep1 =>
      'Die neue Firmware ist geschrieben und startet beim nächsten Hochfahren.';

  @override
  String get finishPendingStep2 =>
      'Der Roller startet neu und stellt seine Dienste wieder her.';

  @override
  String get finishPendingStep3 =>
      'Schlüsselkarten, Bluetooth und deine Einstellungen werden wieder aktiv.';

  @override
  String get finishPendingStep4 =>
      'Zum Schluss entsperrt sich der Roller selbst.';

  @override
  String get finishPendingDoNowTitle => 'Was du jetzt tun musst';

  @override
  String get finishPendingDoneTitle =>
      'So erkennst du, dass die Installation fertig ist';

  @override
  String get finishPendingDoneBody =>
      'Das Lenkerschloss öffnet sich und der Roller lässt sich einschalten und fahren. Die Fortschrittsanzeige an den Blinkern erlischt.';

  @override
  String get finishPendingDoneTrail =>
      'Der Installer bestätigt dir den Abschluss hier, sobald er den Roller wieder erreicht.';

  @override
  String get finishPendingNotDoneTitle =>
      'Das ist noch nicht das Fertig-Zeichen';

  @override
  String get finishPendingNotDoneBody =>
      'Während der Installation gehen Dashboard und Beleuchtung des Rollers an, und die Blinker zeigen kurz einen Fortschritt. Das gehört zur Installation und heißt nicht, dass sie beendet ist.';

  @override
  String get finishPendingDontTitle => 'Solange bitte nicht';

  @override
  String get finishPendingDont1 =>
      'Den Roller ausschalten oder vom Akku trennen';

  @override
  String get finishPendingDont2 => 'Ihn schon entsperren oder losfahren wollen';

  @override
  String get closeInstaller => 'Installer schließen';

  @override
  String get disconnectUsbFromLaptopFinal =>
      'Laptop-USB-Kabel vom MDB abziehen';

  @override
  String get disconnectUsbFromLaptopFinalDesc =>
      'Ziehe das Laptop-USB-Kabel vom MDB ab. In diesen Anschluss kommt anschließend das DBC-Kabel.';

  @override
  String get reconnectDbcUsbCable =>
      'Internes Dashboard-Kabel anschließen und festschrauben';

  @override
  String get reconnectDbcUsbCableDesc =>
      'Stecke das interne Dashboard-USB-Kabel wieder in denselben Anschluss am Hauptcomputer (MDB) und ziehe die beiden Schrauben am Stecker fest.';

  @override
  String get closeSeatboxAndFootwell => 'Fußraumabdeckung wieder anbringen';

  @override
  String get closeSeatboxAndFootwellDesc =>
      'Setze die Abdeckung auf und befestige sie mit den vier Schrauben.';

  @override
  String get unlockScooter => 'Roller entsperren';

  @override
  String get unlockScooterDesc =>
      'Verwende eine der angelernten Schlüsselkarten oder entsperre den Roller über Bluetooth.';

  @override
  String deletedCache(String sizeMb) {
    return '$sizeMb MB gelöscht';
  }

  @override
  String get downloads => 'Downloads';

  @override
  String get downloadsFinished => 'Herunterladen abgeschlossen';

  @override
  String get downloadsFinishedHint => 'Du kannst jetzt offline weitermachen.';

  @override
  String get assetChipMdbArtifact => 'MDB-Firmware';

  @override
  String get assetChipDbcArtifact => 'DBC-Firmware';

  @override
  String get assetChipMdbImage => 'MDB-Grundsystem';

  @override
  String get assetChipDbcImage => 'DBC-Grundsystem';

  @override
  String get assetChipMdbBlockMap => 'MDB-Blockzuordnung';

  @override
  String get assetChipDbcBlockMap => 'DBC-Blockzuordnung';

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
  String get downloadRoutingTiles => 'Routenkacheln';

  @override
  String get safetyCheckFailed => 'Sicherheitsprüfung fehlgeschlagen';

  @override
  String get cannotFlashSafety =>
      'Dieses Gerät kann aus Sicherheitsgründen nicht geflasht werden:';

  @override
  String get cancelButton => 'Abbrechen';

  @override
  String get confirmFlashTargetTitle => 'Ziellaufwerk bestätigen';

  @override
  String get confirmFlashTargetBody =>
      'Der Installer konnte nicht prüfen, ob dieses Ziel sicher überschrieben werden kann. Kontrolliere das Laufwerk sorgfältig, bevor du fortfährst.';

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
      'Flashen abgebrochen: Das Ziellaufwerk wurde nicht bestätigt.';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get inspectingConfiguration => 'Gerätekonfiguration wird geprüft…';

  @override
  String get backingUpConfig =>
      'Ausgewählte Gerätekonfiguration wird gesichert…';

  @override
  String get configBackedUp => 'Gerätekonfiguration gesichert';

  @override
  String get restoringConfig => 'Gerätekonfiguration wird wiederhergestellt…';

  @override
  String get configurationVerifyingHeading =>
      'Wiederhergestellte Konfiguration wird geprüft';

  @override
  String get configurationVerifyingBody =>
      'Der Roller hat den Abschluss der Installation gemeldet. Der Installer prüft die wiederhergestellte Konfiguration, bevor er den Erfolg bestätigt.';

  @override
  String get configurationVerificationFailedHeading =>
      'Wiederhergestellte Konfiguration konnte nicht geprüft werden';

  @override
  String configurationVerificationFailedBody(String backupPath) {
    return 'Verlasse dich noch nicht auf die wiederhergestellte Konfiguration. Wiederhole die Prüfung, solange der Roller verbunden ist. Die Sicherung auf diesem Computer bleibt hier erhalten:\n$backupPath';
  }

  @override
  String configurationTransferable(String categories) {
    return 'Folgende Daten können übertragen werden: $categories.';
  }

  @override
  String get configurationListAnd => ' und ';

  @override
  String get configurationRestoreHeading =>
      'Welche Einstellungen möchtest du übernehmen?';

  @override
  String get configurationRestoreDetail =>
      'Die folgenden Einstellungen wurden auf deinem Roller gefunden. Wähle aus, welche nach der Neuinstallation wiederhergestellt werden sollen.';

  @override
  String get configurationIdentity => 'Geräteidentität und VIN-Datenbank';

  @override
  String get configurationIdentityDescription =>
      'Erhält Roller-ID, VIN und die Identitätsdatenbank.';

  @override
  String get configurationWireGuard => 'WireGuard-Verbindungen';

  @override
  String get configurationWireGuardDescription =>
      'Erhält VPN-Verbindungen einschließlich privater Schlüssel.';

  @override
  String get configurationUplink => 'Uplink-Dienst';

  @override
  String get configurationUplinkDescription =>
      'Erhält die Konfiguration des Mobilfunk- und Uplink-Dienstes.';

  @override
  String get configurationRadioGaga => 'Cloud-Konfiguration';

  @override
  String get configurationRadioGagaDescription =>
      'Erhält die Cloud-Konfiguration und das zugehörige CA-Zertifikat.';

  @override
  String get configurationSettings => 'Rollereinstellungen';

  @override
  String get configurationSettingsDescription =>
      'Erhält Sprache, Verhalten und weitere persönliche Einstellungen.';

  @override
  String get configurationKeycards => 'Schlüsselkarten';

  @override
  String get configurationKeycardsDescription =>
      'Erhält die Anlernkarte und alle autorisierten Schlüsselkarten.';

  @override
  String get configurationInspectionFailed =>
      'Die vorhandene Konfiguration konnte nicht geprüft werden. Wiederhole vor einer Neuinstallation die Statusprüfung.';

  @override
  String healthCheckFailed(String error) {
    return 'Statusprüfung fehlgeschlagen: $error';
  }

  @override
  String errorPrefix(String error) {
    return 'Fehler: $error';
  }

  @override
  String get skipOfflineMaps =>
      'Offline-Karten und Navigation nicht herunterladen';

  @override
  String get bluetoothPairingHeading => 'Bluetooth-Kopplung';

  @override
  String get bluetoothPairingHint =>
      'Koppele dein Handy, um den Roller zu entsperren und seinen Status abzurufen. Du kannst das auch später einrichten.';

  @override
  String get bleMacLabel => 'BLE-Adresse';

  @override
  String get startPairing => 'Kopplung starten';

  @override
  String pairingStartFailed(String error) {
    return 'Bluetooth-Kopplung konnte nicht gestartet werden: $error';
  }

  @override
  String get blePreparingRadio =>
      'Bluetooth-Funk wird neu gestartet. Warte vor dem Koppeln, bis der Vorgang abgeschlossen ist.';

  @override
  String get skipPairing => 'Überspringen';

  @override
  String get pairingActive => 'Bereit zum Koppeln';

  @override
  String get pairingActiveHint =>
      'Suche den Roller in den Bluetooth-Einstellungen deines Handys und koppele ihn. Drücke Fertig, wenn du fertig bist.';

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
      'Lerne die NFC-Schlüsselkarten an, mit denen du den Roller ent- und verriegeln möchtest. Klicke auf Anlernen starten, halte dann jede Karte einzeln an den Leser und klicke anschließend auf Fertig.';

  @override
  String keycardLearnedAck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schlüsselkarten angelernt',
      one: '1 Schlüsselkarte angelernt',
    );
    return '$_temp0. Klicke auf Weiter zum Abschließen oder lerne weitere Karten an.';
  }

  @override
  String keycardLearningTapped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schlüsselkarten erfasst',
      one: '1 Schlüsselkarte erfasst',
      zero: 'Noch keine Schlüsselkarte erfasst',
    );
    return '$_temp0';
  }

  @override
  String keycardKnownAdded(int added, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added von $total bekannten Schlüsselkarten hinzugefügt',
      one: '1 von $total bekannten Schlüsselkarten hinzugefügt',
      zero:
          'Keine der $total bekannten Schlüsselkarten konnte hinzugefügt werden',
    );
    return '$_temp0';
  }

  @override
  String get keycardCardsChecking =>
      'Registrierte Schlüsselkarten werden geprüft…';

  @override
  String get keycardStartLearning => 'Anlernen starten';

  @override
  String get keycardAddMore => 'Weitere Karten anlernen';

  @override
  String get keycardLearningActive => 'Anlernmodus aktiv';

  @override
  String get keycardLearningActiveHint =>
      'Halte jede Schlüsselkarte an den Leser. Klicke auf Fertig, wenn du fertig bist.';

  @override
  String get keycardStopLearning => 'Fertig';

  @override
  String get keycardStopScanning => 'Stoppen';

  @override
  String get keycardSkipConfirmTitle => 'Ohne Schlüsselkarte überspringen?';

  @override
  String get keycardSkipConfirmBody =>
      'Es wird keine Schlüsselkarte angelernt. Überspringe diesen Schritt nur, wenn du den Roller bereits auf andere Weise zuverlässig entsperren kannst.';

  @override
  String get keycardSkipConfirmAction => 'Trotzdem überspringen';

  @override
  String keycardStartLearningFailed(String error) {
    return 'Das Anlernen der Schlüsselkarten konnte nicht gestartet werden: $error';
  }

  @override
  String get keycardEntryAlreadyConfiguredHeading =>
      'Schlüsselkarten sind bereits eingerichtet';

  @override
  String keycardEntryAlreadyConfiguredBody(int master, int authorized) {
    String _temp0 = intl.Intl.pluralLogic(
      master,
      locale: localeName,
      other: '$master Anlernkarten sind gesetzt',
      one: '1 Anlernkarte ist gesetzt',
      zero: 'Es ist keine Anlernkarte gesetzt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      authorized,
      locale: localeName,
      other: '$authorized Schlüsselkarten sind angelernt',
      one: '1 Schlüsselkarte ist angelernt',
      zero: 'keine Schlüsselkarten sind angelernt',
    );
    return '$_temp0 und $_temp1. Du kannst diesen Zustand beibehalten oder alles zurücksetzen und neu beginnen.';
  }

  @override
  String get keycardEntryContinueButton => 'Weiter';

  @override
  String get keycardStartOverButton => 'Von vorn beginnen';

  @override
  String get keycardStartOverConfirmTitle => 'Alle Schlüsselkarten löschen?';

  @override
  String get keycardStartOverConfirmBody =>
      'Damit werden die Anlernkarte und alle angelernten Schlüsselkarten auf dem Roller gelöscht. Du musst sie danach erneut anlernen. Möchtest du fortfahren?';

  @override
  String get keycardStartOverConfirmYes => 'Alles löschen';

  @override
  String get keycardStartOverConfirmNo => 'Abbrechen';

  @override
  String get keycardCardsStageContinueButton => 'Weiter';

  @override
  String get keycardCardsStageAddMasterButton =>
      'Anlernkarte hinzufügen (fortgeschritten)';

  @override
  String get keycardMasterStageHeading => 'Anlernkarte hinzufügen';

  @override
  String get keycardMasterStageWarningHeading =>
      'Die Anlernkarte entsperrt den Roller nicht';

  @override
  String get keycardMasterStageWarningBody =>
      'Mit der Anlernkarte kannst du später weitere Schlüsselkarten direkt am Roller anlernen. Sie kann den Roller nicht entsperren und ist für die normale Nutzung nicht nötig. Verwende eine separate Karte, die noch nicht als Schlüsselkarte angelernt ist.';

  @override
  String get keycardMasterStageHint =>
      'Sobald der Leser bereit ist, halte die Anlernkarte vorne links an das Dashboard.';

  @override
  String get keycardCardDuplicateToast =>
      'Diese Schlüsselkarte ist bereits angelernt.';

  @override
  String get keycardMasterStageRejectedToast =>
      'Diese Schlüsselkarte ist bereits angelernt.';

  @override
  String get keycardMasterStageSaveFailedToast =>
      'Anlernkarte konnte nicht gespeichert werden. Schreibvorgang fehlgeschlagen.';

  @override
  String get keycardMasterStageLearnedToast => 'Anlernkarte wurde angelernt.';

  @override
  String get keycardMasterStageStartFailed =>
      'Die Einrichtung der Anlernkarte konnte nicht gestartet werden';

  @override
  String get keycardMasterStageRetryButton => 'Erneut versuchen';

  @override
  String get keycardMasterStageSkipButton => 'Überspringen';

  @override
  String get keycardMasterStartPendingClose =>
      'Warte, bis der Kartenleser den Anlernkartenmodus vollständig gestartet hat, bevor du den Installer schließt.';

  @override
  String get keycardSimulateTapButton => 'Kartenkontakt simulieren';

  @override
  String get keycardSimulateMasterTapButton => 'Anlernkarte simulieren';

  @override
  String get keycardSimulateRejectedTapButton =>
      'Ablehnung einer angelernten Karte simulieren';

  @override
  String get installationContinuesInNewWindow =>
      'Die Installation wird im neuen Fenster fortgesetzt';

  @override
  String get youCanCloseThisWindow => 'Du kannst dieses Fenster schließen.';

  @override
  String get cannotQuitWhileFlashing =>
      'Beenden während des Flashens nicht möglich';

  @override
  String get showLogTooltip => 'Protokoll anzeigen';

  @override
  String get retryMdbConnect => 'Erneut versuchen';

  @override
  String get retryMdbToUms => 'Erneut versuchen';

  @override
  String get showLog => 'Log anzeigen';

  @override
  String get muteSounds => 'Ton ausschalten';

  @override
  String get unmuteSounds => 'Ton einschalten';

  @override
  String get retryMdbFlash => 'Erneut versuchen';

  @override
  String get retryMdbBoot => 'Erneut versuchen';

  @override
  String get retryDbcPrep => 'Erneut versuchen';

  @override
  String get retryVerification => 'Überprüfung wiederholen';

  @override
  String get retryDbcFlash => 'Dashboard-Installation wiederholen';

  @override
  String get skipToFinish => 'Zum Abschluss springen';

  @override
  String get skipKeycardSetup => 'Überspringen';

  @override
  String get finished => 'Fertig';

  @override
  String get installAnother => 'Weiteren Roller installieren';

  @override
  String get keepCachedDownloads => 'Heruntergeladene Dateien behalten';

  @override
  String get finishKeepDownloadedFiles => 'Abschließen und Downloads behalten';

  @override
  String get phaseInstallPlanTitle => 'Installationsplan';

  @override
  String get phaseInstallPlanDescription =>
      'Festlegen, was mit jedem Board geschieht';

  @override
  String get phaseMdbArtifactTitle =>
      'Software auf dem Hauptcomputer (MDB) installieren';

  @override
  String get phaseMdbArtifactDescription => 'Firmware installieren';

  @override
  String get majorStepMdbUpgrade => 'MDB aktualisieren';

  @override
  String get majorStepDbcUpgrade => 'DBC aktualisieren';

  @override
  String get installPlanHeading => 'Installation planen';

  @override
  String get installPlanIntro =>
      'Wähle die gewünschte Aktion für Hauptcomputer (MDB) und Dashboard (DBC).';

  @override
  String get boardMdb => 'Hauptcomputer (MDB)';

  @override
  String get boardDbc => 'Dashboard (DBC)';

  @override
  String bootstrapImageLabel(String board) {
    return 'Librescoot-Bootstrap-Image ($board)';
  }

  @override
  String boardVersionCurrent(String version) {
    return 'Aktuell $version';
  }

  @override
  String boardVersionLastSeen(String version) {
    return 'Zuletzt erkannte Version: $version';
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
  String actionUpgradeToVersion(String version) {
    return 'Auf Librescoot $version aktualisieren';
  }

  @override
  String get actionUpgradeDetail =>
      'Behält Einstellungen, Schlüsselkarten und Karten';

  @override
  String get actionCleanInstall => 'Neu installieren';

  @override
  String actionCleanInstallVersion(String version) {
    return 'Librescoot $version neu installieren';
  }

  @override
  String get actionCleanInstallDetail =>
      'Die Daten auf dem Hauptcomputer werden überschrieben. Bestimmte Einstellungen können im nächsten Schritt übernommen werden.';

  @override
  String get actionUpgradeDetailDbc =>
      'Behält Offline-Karten und Navigationsdaten';

  @override
  String get actionCleanInstallDetailDbc =>
      'Löscht Offline-Karten und Navigationsdaten';

  @override
  String get actionCleanInstallDetailDbcTiles =>
      'Offline-Karten und Navigationsdaten werden gelöscht und neu installiert';

  @override
  String get actionLeave => 'Unverändert lassen';

  @override
  String get actionLeaveDetail => 'Dieses Board bleibt unverändert';

  @override
  String get upgradeBlockedNotLibrescoot =>
      'Aktualisieren setzt eine vorhandene Librescoot-Installation voraus';

  @override
  String get upgradeBlockedStateUnknown =>
      'Aktualisieren setzt eine bekannte Version auf diesem Board voraus';

  @override
  String get upgradeBlockedMinimalImage =>
      'Dieses Board läuft nur mit dem Grundsystem und muss neu installiert werden';

  @override
  String get upgradeBlockedNoMender =>
      'Dieses Board hat keinen Update-Client und kann nur neu installiert werden';

  @override
  String get planTilesNeedDbcHandoff =>
      'Für neue Kartendaten muss später das interne Dashboard-Kabel wieder angeschlossen werden, auch wenn die Dashboard-Software unverändert bleibt. Der Installer zeigt dir, wann.';

  @override
  String get planInstallTiles => 'Offline-Karten und Navigation installieren';

  @override
  String get planTilesUnknownDbc =>
      'Die DBC-Software konnte nicht erkannt werden. Offline-Karten können nur auf einer bekannten, vollständigen Librescoot-Installation installiert werden. Wähle für das DBC „Neu installieren“ oder fahre ohne Karten fort und starte den Installer erneut, nachdem das DBC verbunden ist und läuft.';

  @override
  String get planTilesBootstrapDbc =>
      'Das DBC läuft mit einem Bootstrap-Image. Dieses kann keine Offline-Karten verwenden. Wähle für das DBC „Neu installieren“ oder fahre ohne Karten fort und starte den Installer später erneut.';

  @override
  String get planTilesNeedKnownDbc =>
      'Das Dashboard wurde nicht als vollständige Librescoot-Installation erkannt. Installiere die Dashboard-Software neu, um Offline-Karten hinzuzufügen.';

  @override
  String get planTilesNotDownloaded =>
      'Offline-Karten und Navigation wurden nicht heruntergeladen.';

  @override
  String get planChangeOfflineMaps => 'Offline-Karten ändern';

  @override
  String get planMapDownloadsPending =>
      'Offline-Karten werden heruntergeladen. Warte, bevor du mit ihrer Installation fortfährst.';

  @override
  String get actionLeaveBlockedStockMdb =>
      'Auf dem Hauptcomputer (MDB) muss zuerst Librescoot installiert werden';

  @override
  String get planDbcNeedsLibrescootMdb =>
      'Das DBC ist nur über das MDB erreichbar und die benötigten Werkzeuge gehören zu Librescoot. Installiere in diesem Vorgang das MDB mit oder lasse das DBC unverändert.';

  @override
  String get planNothingToDo =>
      'Keine Aktion ausgewählt. Wähle mindestens eine Aktion, um fortzufahren.';

  @override
  String get planMdbInMassStorage =>
      'Der Hauptcomputer (MDB) ist als USB-Laufwerk verbunden. Seine Software konnte nicht erkannt werden; sie wird neu installiert. Auch das Dashboard (DBC) war nicht erreichbar. Wähle unten, was darauf installiert werden soll.';

  @override
  String get releaseMissingAssetsTitle =>
      'Diese Veröffentlichung kann nicht installiert werden';

  @override
  String releaseMissingAssetsBody(String tag, String assets) {
    return 'Die Veröffentlichung $tag enthält nicht alle benötigten Dateien: $assets. Gehe zurück und wähle einen anderen Kanal oder warte auf eine vollständige Veröffentlichung.';
  }

  @override
  String get assetMdbArtifact => 'die MDB-Firmware';

  @override
  String get assetDbcArtifact => 'die DBC-Firmware';

  @override
  String get assetMdbImage => 'das MDB-Grundsystem';

  @override
  String get assetDbcImage => 'das DBC-Grundsystem';

  @override
  String get artifactStaging => 'Firmware wird übertragen…';

  @override
  String artifactInstalling(int percent) {
    return 'Firmware wird installiert ($percent%)';
  }

  @override
  String get artifactVerifying => 'Installierte Version wird geprüft…';

  @override
  String get waitingForDbcUpload => 'Dashboard-Dateien werden noch übertragen';

  @override
  String get artifactStillMinimal =>
      'Das MDB ist mit dem Grundsystem gestartet; die Firmware wurde nicht installiert. Versuche es erneut oder installiere stattdessen das vollständige Systemabbild.';

  @override
  String artifactVersionMismatch(String found, String expected) {
    return 'Das MDB meldet nach dem Neustart weiterhin $found statt $expected. Die Installation wurde zurückgerollt; es wurde nichts geändert. Versuche es erneut oder installiere stattdessen das vollständige Systemabbild.';
  }

  @override
  String get artifactInstallFailedHeading =>
      'Firmware-Installation fehlgeschlagen';

  @override
  String get artifactStagingInBackground =>
      'Firmware wird im Hintergrund übertragen…';

  @override
  String get artifactNoneDownloaded =>
      'Für dieses Board wurde keine Firmware heruntergeladen.';

  @override
  String get dbcImageMissing =>
      'Das für diesen Plan benötigte DBC-Systemabbild fehlt.';

  @override
  String get artifactRebootTimeout =>
      'Der Roller war nach dem Neustart nicht erreichbar.';

  @override
  String get artifactRebootTimeoutHint =>
      'Prüfe, ob das USB-Kabel an beiden Enden fest sitzt und der Roller Strom hat. Ohne eingesetzten Fahrakku kann er während der Wartezeit in den Ruhezustand wechseln.';

  @override
  String get artifactRetryDetail =>
      'Erneuter Versuch an derselben Stelle. Einstellungen und Schlüsselkarten bleiben erhalten.';

  @override
  String get artifactFullImageDetail =>
      'Überschreibt den Speicher des gesamten Boards und löscht Einstellungen und Schlüsselkarten.';

  @override
  String get artifactPreflightNoMender =>
      'Dieses Board hat keinen Update-Client und kann daher keine Firmware-Aktualisierung aufnehmen.';

  @override
  String artifactPreflightOtaBusy(String status) {
    return 'Auf dem Roller läuft gerade ein anderes Update ($status). Warte, bis es abgeschlossen ist und der Roller neu gestartet wurde. Versuche es danach erneut.';
  }

  @override
  String artifactPreflightNoSpace(int freeMiB, int neededMiB) {
    return 'Zu wenig Platz in /data: $freeMiB MiB frei, $neededMiB MiB benötigt.';
  }

  @override
  String get artifactRetry => 'Erneut versuchen';

  @override
  String get artifactFallBackToFullImage =>
      'Stattdessen vollständiges Systemabbild installieren';

  @override
  String get fallBackWipeTitle => 'Dabei werden die Daten des Rollers gelöscht';

  @override
  String get fallBackWipeBody =>
      'Beim Installieren des vollständigen Systemabbilds wird die Datenpartition neu formatiert. Auf der nächsten Seite kannst du auswählen, welche erkannten Identitäts-, Verbindungs-, Einstellungs- und Schlüsselkarten-Daten über den Laptop erhalten bleiben. Offline-Karten gehen weiterhin verloren.\n\nEin erneuter Versuch mit der Firmware-Aktualisierung erhält die vorhandenen Daten. Installiere das vollständige Systemabbild nur, wenn das Paket weiterhin fehlschlägt.';

  @override
  String get fallBackWipeConfirm => 'Prüfen und Systemabbild installieren';

  @override
  String get dbcCleanInstallButton => 'Dashboard löschen und neu installieren';

  @override
  String get dbcCleanInstallTitle =>
      'Dashboard (DBC) löschen und neu installieren?';

  @override
  String get dbcCleanInstallBody =>
      'Wenn die normale Aktualisierung nicht möglich ist, kann eine vollständige Neuinstallation helfen.\n\nDabei werden die Daten auf dem Dashboard gelöscht. Anschließend werden die Dashboard-Software und die ausgewählten Offline-Karten neu installiert. Bereits vorhandene Karten werden nur wieder installiert, wenn sie für diese Installation ausgewählt sind.\n\nDie Daten auf dem Hauptcomputer (MDB), einschließlich Einstellungen und angelernter Schlüsselkarten, bleiben erhalten.\n\nDer Installer bereitet die benötigten Dateien vor und zeigt dir anschließend, wann du das USB-Kabel wieder umstecken sollst.';

  @override
  String get dbcCleanInstallConfirm => 'Dashboard löschen und installieren';

  @override
  String firmwareVersionDisplay(String version) {
    return 'Firmware: $version';
  }

  @override
  String healthVersionPlan(String current, String target) {
    return 'Aktuell installiert: $current; zu installieren: $target';
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
  String get mainBatteryPreflightTitle => 'Fahrakku fehlt beim Vorabcheck';

  @override
  String get mainBatteryPreflightWarning =>
      'Beim Vorabcheck wurde kein Fahrakku erkannt. Ein Stromausfall während des Flashens kann den Roller unbrauchbar machen. Setze den Fahrakku ein und wiederhole die Statusprüfung. Nur mit gesicherter alternativer Stromversorgung fortfahren.';

  @override
  String get mainBatteryHandoffTitle => 'Fahrakku nicht bestätigt';

  @override
  String get mainBatteryHandoffWarning =>
      'Der Fahrakku konnte vor der Dashboard-Installation nicht bestätigt werden. Ohne gesicherte Stromversorgung kann der DBC-Flash fehlschlagen. Fahre nur fort, wenn du das Risiko bewusst übernimmst und die Stromversorgung gesichert hast.';

  @override
  String get mainBatteryPreflightAcknowledge =>
      'Ich habe die Stromversorgung geprüft und übernehme das Risiko eines Flash-Fehlers.';

  @override
  String get mainBatteryPreflightOverride => 'Trotzdem flashen';

  @override
  String get mainBatteryUnverifiableHeading =>
      'Fahrakku kann nicht geprüft werden';

  @override
  String get mainBatteryUnverifiableHint =>
      'Das minimale MDB-System meldet keinen Fahrakku. Prüfe vor der Dashboard-Installation selbst, ob der Fahrakku eingesetzt ist, und bestätige das unten.';

  @override
  String get confirmMainBatteryInstalled => 'Fahrakku ist eingesetzt – weiter';

  @override
  String get proceedWithoutBatteryConfirmation =>
      'Ohne bestätigten Fahrakku fortfahren';

  @override
  String get mainBatteryMissingHeading => 'Kein Fahrakku erkannt';

  @override
  String get mainBatteryMissingHint =>
      'Der DBC-Flash benötigt den Fahrakku. Setze ihn wieder in die Sitzbank ein, bevor du fortfährst.';

  @override
  String get cbbDetected => 'CBB erkannt';

  @override
  String get batteryDetected => 'Akku erkannt';

  @override
  String get proceedWithoutCbb => 'Ohne CBB fortfahren';

  @override
  String get proceedWithoutMainBattery => 'Ohne Fahrakku fortfahren';

  @override
  String get checkingCbbAndBattery => 'CBB und Fahrakku prüfen';

  @override
  String get waitingForUsbDisconnect => 'Warte auf USB-Trennung…';

  @override
  String get dbcFlashDurationHeadline =>
      'Die Dashboard-Installation dauert normalerweise 10 bis 20 Minuten.';

  @override
  String get finishHandoverRestoring =>
      'Einstellungen und Dienste werden wiederhergestellt';

  @override
  String get finishBlockedHeading =>
      'Die Installation wurde nicht abgeschlossen';

  @override
  String get finishBlockedBody =>
      'Die Verbindung zum Roller ist vor der abschließenden Statusprüfung abgebrochen. Die Übertragung der Dashboard-Software oder der Karten wurde möglicherweise nicht gestartet oder nicht abgeschlossen.\n\nPrüfe das USB-Kabel an beiden Enden und wähle „Erneut versuchen“. Wenn die Verbindung nicht wiederhergestellt werden kann, schließe den Installer und starte ihn erneut. Der aufgezeichnete Installationsstand bleibt erhalten.';

  @override
  String get finishBlockedRetry => 'Nochmal versuchen';

  @override
  String get finishHandoverTitle => 'Warte, bis der Roller entsperrt ist';

  @override
  String get finishHandoverBody =>
      'Bleibe beim Roller, bis er entsperrt ist. Ziehe danach das USB-Kabel ab.';

  @override
  String get waitingForMdb => 'Warte auf das MDB…';

  @override
  String get dbcFlashAllDone => 'Weiter zum Abschluss';

  @override
  String get dbcFlashSequence =>
      'Sobald die LED am Dashboard dauerhaft orange leuchtet, beginnt die ausgewählte Installation. Den tatsächlichen Zustand zeigen das Dashboard und die Blinker. Warte, bis der Vorgang abgeschlossen ist oder ein Fehler angezeigt wird.';

  @override
  String get dbcFlashHandsOffHeading => 'Dashboard an heißt noch nicht fertig';

  @override
  String get dbcFlashObservedSuccess => 'Der Roller hat sich entsperrt';

  @override
  String get dbcFlashErrorLabel => 'FEHLER';

  @override
  String get dbcFlashErrorPrompt =>
      'Warnblinker geht an, Dashboard-LED blinkt rot';

  @override
  String get dbcFlashSuccessLabel => 'ERFOLG';

  @override
  String get dbcFlashSuccessPrompt =>
      'Der Roller hat sich entsperrt: Das Standlicht und das Rücklicht leuchten';

  @override
  String get dbcFlashChooseOutcomeHint =>
      'Wenn eines dieser beiden Ereignisse eintritt, klicke das passende Bild.';

  @override
  String get dbcFlashDoNotDisconnect =>
      'Lass USB-Kabel und Stromversorgung angeschlossen. Bewege während des Schreibens möglichst weder Kabel noch Laptop.';

  @override
  String get dbcFlashDoneSignal =>
      'Fertig: Der Roller hat sich automatisch entsperrt, Beleuchtung und Dashboard sind an. Du musst nicht weiter warten.';

  @override
  String get dbcFlashFailSignal =>
      'Fehler: Die LED am DBC blinkt rot und der Warnblinker geht an. Schließe USB wieder am MDB an und öffne hier das Protokoll.';

  @override
  String get dbcFlashLedIsTheSignal =>
      'Die LED am DBC zeigt Fehler an: Wenn sie rot blinkt, ist die Installation fehlgeschlagen.';

  @override
  String get dbcFlashSomethingWrong => 'Ein Fehler ist aufgetreten';

  @override
  String get phaseKeycardSetupTitle => 'Schlüsselkarten einrichten';

  @override
  String get phaseKeycardSetupDescription => 'Schlüsselkarten anlernen';

  @override
  String get usingLocalFirmwareImages =>
      'Lokale Firmware-Systemabbilder werden verwendet';

  @override
  String get mdbDetectedUmsSkipping =>
      'MDB im UMS-Modus erkannt. Direkt zum Flashen.';

  @override
  String get verifyingBootloaderConfig =>
      'Bootloader-Konfiguration wird überprüft…';

  @override
  String get umsNotDetectedTimeout =>
      'UMS-Gerät nicht innerhalb von 3 Minuten erkannt. MDB ist möglicherweise wieder in Linux gebootet.';

  @override
  String get waitingForDevicePath => 'Warte auf Gerätepfad…';

  @override
  String get noDevicePathFound =>
      'Kein Gerätepfad gefunden. Prüfe die USB-Verbindung und versuche es erneut.';

  @override
  String get massStorageWithoutDisk =>
      'Der Roller meldet sich als USB-Gerät, liefert aber kein Laufwerk. Der Installer kann in diesem Zustand nicht flashen. Melde dich damit im Librescoot-Chat.';

  @override
  String get mdbDisconnectedFlashingDbc =>
      'MDB getrennt. DBC wird automatisch geflasht…';

  @override
  String get mdbReconnectedVerifying =>
      'MDB wieder verbunden. Überprüfung läuft…';

  @override
  String get logDebugShell => 'Protokoll und Debug-Shell';

  @override
  String internalError(String error) {
    return 'Interner Fehler: $error';
  }

  @override
  String get copyLog => 'Protokoll kopieren';

  @override
  String get copyToClipboard => 'In Zwischenablage kopieren';

  @override
  String get copyErrorAndLog => 'Fehler + Log kopieren';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String logFilePath(String path) {
    return 'Protokolldatei: $path';
  }

  @override
  String get revealLogFile => 'Im Ordner anzeigen';

  @override
  String get debugShell => 'Debug-Shell';

  @override
  String get debugCommandHint => 'Befehl im Installer-Kontext ausführen…';

  @override
  String get debugStopCommand => 'Stoppen';

  @override
  String get debugCommandStillRunning =>
      'Es läuft noch ein Befehl. Erst stoppen, dann den nächsten starten.';

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
      'Das Kurzmenü über den Sitzbank-Schalter funktioniert nur im Fahrmodus (Seitenständer oben). Halte den Sitzbank-Schalter gedrückt, um es zu öffnen. Solange du ihn hältst, wechseln die Einträge automatisch im Sekundentakt. Lass ihn los, um den hervorgehobenen Eintrag auszuwählen, und drücke innerhalb von etwa einer Sekunde erneut kurz zur Bestätigung.';

  @override
  String get gettingStartedUpdateModeTitle =>
      'Update-Modus später erneut öffnen';

  @override
  String get gettingStartedUpdateModeDesc =>
      'Für Karten- oder Routenaktualisierungen, Einstellungen oder weitere Dateiübertragungen: Schalte den Roller ein, öffne das Menü und wähle Einstellungen → System → Update-Modus… aus. Schließe anschließend einen Rechner per USB an.';

  @override
  String get gettingStartedNavigationTitle => 'Zu einem Ziel navigieren';

  @override
  String get gettingStartedNavigationDesc =>
      'Wähle Menü → Navigation → Adresse eingeben…, Letzte Ziele oder Gespeicherte Orte. Mit Aktuellen Standort speichern speicherst du die aktuelle Position. Mit In Favoriten speichern bleibt ein letztes Ziel dauerhaft gespeichert.';

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
  String get substepConnectSsh => 'Verbindung herstellen';

  @override
  String get substepCheckCompletionRecord => 'Abschlussprotokoll prüfen';

  @override
  String get substepReadStatus => 'Status der laufenden Installation prüfen';

  @override
  String elapsedSeconds(int seconds) {
    return '${seconds}s vergangen';
  }

  @override
  String get reconnectTimeoutHeading => 'Dauert ungewöhnlich lange';

  @override
  String reconnectTimeoutBody(int minutes) {
    return 'Das MDB ist seit $minutes Minuten nicht als USB-Netzwerkgerät zurückgekehrt. Die erste Dashboard-Einrichtung kann länger dauern, während Speicher und Offline-Karten vorbereitet werden. Du kannst weiter warten, die Prüfung wiederholen, die Dashboard-Installation erneut starten oder zum Abschluss gehen.';
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
      'Diese Version ist älter als die aktuell auf dem Board laufende Version. Beim Aktualisieren bleiben Einstellungen, Schlüsselkarten und Karten erhalten. Ältere Dienste können Daten einer neueren Version möglicherweise nicht lesen. Installiere neu, wenn danach Probleme auftreten.';

  @override
  String get upgradeChannelSwitchWarning =>
      'Diese Version stammt aus einem anderen Kanal als die aktuell auf dem Board laufende Version. Beim Aktualisieren bleiben Einstellungen, Schlüsselkarten und Karten erhalten. Die Dienste des anderen Kanals können diese Daten möglicherweise anders lesen. Installiere neu, wenn danach Probleme auftreten.';

  @override
  String get tightenDbcCable => 'DBC-Kabel festschrauben';

  @override
  String get tightenDbcCableDesc =>
      'Das interne DBC-USB-Kabel steckt schon im MDB. Schraube es jetzt fest.';

  @override
  String get finalRide => 'Losfahren';

  @override
  String get finalRideDesc =>
      'Der Roller wurde am Ende der Installation automatisch entsperrt. Falls nicht, verwende eine angelernte Schlüsselkarte oder entsperre ihn über Bluetooth.';

  @override
  String notEnoughDiskSpace(String needed) {
    return 'Zu wenig Speicherplatz: $needed fehlen. Schaffe Speicherplatz und versuche es erneut.';
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
  String get substepAlreadyThere => 'liegt schon auf dem Roller';

  @override
  String get substepFileImage => 'Dashboard-Systemabbild';

  @override
  String get substepFileImageMap => 'Prüfdaten zum Dashboard-Systemabbild';

  @override
  String get substepFileFirmware => 'Dashboard-Firmware';

  @override
  String get substepFileMaps => 'Karten';

  @override
  String get substepFileRouting => 'Routendaten';

  @override
  String get substepUploadStarting => 'Übertragung wird vorbereitet…';

  @override
  String get substepUploadComplete => 'Übertragung abgeschlossen';

  @override
  String get substepUploadNothingToDo =>
      'Alle Dateien sind bereits auf dem Roller';

  @override
  String substepRemaining(int mins, int secs) {
    return 'noch $mins Min. $secs Sek.';
  }

  @override
  String get substepUploadFlasher => 'Flash-Werkzeug übertragen';

  @override
  String get substepUploadFwTools => 'DBC-Bootloader-Werkzeuge übertragen';

  @override
  String get substepUploadScript => 'Installationsskript übertragen';

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
      'Mit einem gekoppelten Handy kannst du den Roller später über die App entsperren und seinen Zustand anzeigen. Du kannst diesen Schritt überspringen und später nachholen.';

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
  String get blePairingStep3 => 'PIN am Handy eingeben';

  @override
  String get blePairingStep3Desc =>
      'Gib die hier angezeigte PIN im Eingabefeld auf deinem Handy ein.';

  @override
  String get blePairingOneAtATime =>
      'Der Roller hält immer nur eine Bluetooth-Verbindung. Ist schon ein Gerät verbunden, trenne es zuerst dort.';

  @override
  String get keycardWhy =>
      'Mit einer angelernten Schlüsselkarte entsperrst du den Roller ohne Handy. Du kannst mehrere Karten anlernen und später weitere hinzufügen.';

  @override
  String get keycardStep1 => 'Anlernen starten';

  @override
  String get keycardStep1Desc =>
      'Klicke auf Anlernen starten und warte, bis der Kartenleser bereit ist.';

  @override
  String get keycardStep2 => 'Schlüsselkarte an den Leser halten';

  @override
  String get keycardStep2Desc =>
      'Halte jede Karte einzeln an den Leser vorne links am Dashboard, bis sie registriert wurde.';

  @override
  String get keycardStep3 => 'Fertig drücken';

  @override
  String get keycardStep3Desc =>
      'Damit wird das Anlernen beendet und die Schlüsselkarten werden aktiviert.';

  @override
  String get keycardPanelHeading => 'Kartenleser';

  @override
  String get keycardReaderPreparing => 'Wird vorbereitet';

  @override
  String get keycardReaderReady => 'Bereit';

  @override
  String get keycardRetryReader => 'Kartenleser erneut versuchen';

  @override
  String get keycardReaderUnreachable => 'Kartenleser nicht erreichbar';

  @override
  String get keycardReaderMissing => 'Kein Kartenleser gefunden';

  @override
  String get keycardReaderMissingHint =>
      'Der Kartenleser ist möglicherweise defekt oder nicht angeschlossen. Prüfe seine Verbindung und versuche es erneut. Fahre nur fort, wenn du den Roller auf andere Weise zuverlässig entsperren kannst.';

  @override
  String get keycardReaderScanning => 'Schlüsselkarte an den Leser halten';

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
      other: '$count Anlernkarten eingerichtet',
      one: '1 Anlernkarte eingerichtet',
    );
    return '$_temp0';
  }

  @override
  String get keycardNeedOneToFinish =>
      'Zum Abschließen musst du mindestens eine Schlüsselkarte anlernen.';

  @override
  String get keycardPreparingReader => 'Kartenleser wird vorbereitet…';

  @override
  String get blePairingDeviceName => 'Gerätename';

  @override
  String get blePairingStateIdle => 'Kopplung nicht gestartet';

  @override
  String get blePairingStateVisible => 'Sichtbar, wartet auf ein Gerät';

  @override
  String get blePinConfirmTitle => 'Diese PIN am Handy eingeben';

  @override
  String get blePinConfirmHint =>
      'Gib diese PIN im Eingabefeld der Bluetooth-Kopplung auf deinem Handy ein und bestätige sie.';

  @override
  String get blePairingStep2DescCompare =>
      'Vergleiche den Namen und die Adresse rechts, wenn mehrere Geräte auftauchen.';

  @override
  String get blePairingStep3DescOverlay =>
      'Gib die hier angezeigte PIN im Eingabefeld der Bluetooth-Kopplung auf deinem Handy ein und bestätige sie.';

  @override
  String get dbcSayInstalling =>
      'Firmware wird installiert. Dies dauert einige Minuten';

  @override
  String get dbcSayInstalled =>
      'Firmware installiert. Dashboard wird neu gestartet';

  @override
  String dbcSayRunning(String version) {
    return 'Firmware $version ist aktiv';
  }

  @override
  String get dbcSayMaps => 'Karten werden übertragen';

  @override
  String get dbcSayRouting => 'Routenkarten werden übertragen';

  @override
  String get dbcSayFailed => 'Installation fehlgeschlagen';

  @override
  String get dbcSaySwap1 => 'USB-Kabel wieder am MDB anschließen und im';

  @override
  String get dbcSaySwap2 => 'Installer auf dem Laptop fortfahren.';

  @override
  String get dbcSayDone => 'Fertig. Der Roller wird jetzt entsperrt.';

  @override
  String get dbcSayBanner => 'Librescoot wird installiert';

  @override
  String get dbcSayFailOnboot =>
      'Der Installationsabschnitt nach dem Neustart ist wiederholt fehlgeschlagen.';

  @override
  String get dbcSayFailDbc =>
      'Das Dashboard hat sich nach dem Schreiben nicht zurückgemeldet.';

  @override
  String dbcSayFailTiles(String count) {
    return 'Fehlgeschlagene Kartenübertragungen: $count';
  }

  @override
  String get mainBatteryCharge => 'Fahrakku-Ladung';

  @override
  String get riskMainBatteryLow =>
      'Der Fahrakku ist fast leer. Die Installation nutzt das 12-V-System, aber ein niedriger Ladestand lässt wenig Reserve. Lade den Roller nach der Installation.';

  @override
  String get waitingForBoardRecovery =>
      'Der Hauptcomputer (MDB) hat kein startfähiges System gefunden und befindet sich im Wiederherstellungsmodus. Nach etwa zwei Minuten wird es automatisch neu gestartet. Lass Kabel und Stromversorgung angeschlossen.';
}

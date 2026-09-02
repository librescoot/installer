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
  String get phaseScooterPrepTitle => 'Strom trennen';

  @override
  String get phaseScooterPrepDescription => 'CBB und AUX trennen';

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
  String get phaseReconnectDescription => 'Display-Arbeiten prüfen';

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
      'Das Flashen dauert mehrere Minuten. Eine instabile USB-Verbindung oder der Ruhemodus des Laptops kann das MDB in einen inkonsistenten Zustand bringen. Prüfe:\n• Ein zuverlässiges USB-Kabel, an beiden Enden fest eingesteckt\n• Laptop am Netzteil oder vollständig geladen. Energiesparmodus und Ruhemodus können den Vorgang unterbrechen\n• Möglichst einen direkten USB-Port, keinen USB-Hub\n• Während des Flashens nichts umstecken oder bewegen';

  @override
  String get noPowerCycleWarningTitle =>
      'Stromversorgung nur nach Anweisung trennen';

  @override
  String get noPowerCycleWarningBody =>
      'Wenn der Vorgang scheinbar hängt oder keine Rückmeldung gibt, halte an und frage im Librescoot-Discord nach, bevor du etwas veränderst. Solange der Installer dich nicht ausdrücklich zu etwas anderem auffordert:\n• AUX-Akku und CBB angeschlossen lassen\n• USB-Kabel angeschlossen lassen\n• Roller und Laptop eingeschaltet lassen\n\nEine Unterbrechung während eines Schreibvorgangs kann dazu führen, dass ein Board nicht mehr startet.';

  @override
  String get downloadsFailedHeading =>
      'Server für Firmware-Downloads nicht erreichbar';

  @override
  String get downloadsFailedBody =>
      'Prüfe die Internetverbindung des Laptops und versuche es erneut. Du kannst offline fortfahren, wenn die Firmware bereits im Zwischenspeicher liegt.';

  @override
  String get downloadsRetry => 'Erneut versuchen';

  @override
  String get noticesHeading => 'Vor dem Weitermachen lesen';

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
      'Wenn du auf Installation starten klickst, fragt dein System nach Administratorrechten. Der Installer benötigt sie, um auf den Speicher des Rollers zu schreiben und das Netzwerk zu konfigurieren.';

  @override
  String get requestingAdminPrivileges =>
      'Administratorrechte werden angefragt…';

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
  String get channelTestingDesc =>
      'Neueste Funktionen, möglicherweise noch nicht ausgereift';

  @override
  String get channelNightlyDesc => 'Täglich aus main gebaut, für Entwickler';

  @override
  String get channelNoReleases => 'Keine Veröffentlichungen verfügbar';

  @override
  String get manifestBundledNotice =>
      'Offline: Diese Versionen stammen aus der im Installer hinterlegten Liste und sind möglicherweise veraltet.';

  @override
  String get loadingChannels => 'Verfügbare Kanäle werden geladen…';

  @override
  String get region => 'Region';

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
  String get physicalPrepHeading => 'Physische Vorbereitung';

  @override
  String get physicalPrepSubheading =>
      'Bereite deinen Roller für die USB-Verbindung vor.';

  @override
  String get keepScooterAwake => 'Roller wach halten';

  @override
  String get keepScooterAwakeDesc =>
      'Entsperre den Roller oder setze einen Fahrakku in den vorderen Schacht. Ohne eines von beidem wechselt der Roller während der Installation in den Ruhezustand und trennt die USB-Verbindung.';

  @override
  String get removeFootwellCover => 'Fußraumabdeckung entfernen';

  @override
  String get removeFootwellCoverDesc =>
      'Löse die vier Schrauben. Ab Werk sind es PH2-Kreuzschrauben, bei Reparaturen können es H4-Innensechskant- oder Torxschrauben sein.';

  @override
  String get unscrewUsbCable => 'USB-Kabel vom MDB lösen';

  @override
  String get unscrewUsbCableDesc =>
      'Trenne das interne DBC-USB-Kabel vom MDB. Verwende einen Schlitz- oder PH1-Schraubendreher.';

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
      'Das MDB ist über USB verbunden, aber innerhalb des Zeitlimits wurde keine Antwort empfangen. Möglicherweise startet das Hauptboard noch oder die Verbindung besteht nur auf dieser Seite.\n• Versuche es erneut. Ein noch startendes Hauptboard antwortet oft beim zweiten oder dritten Versuch\n• Prüfe das USB-Kabel an beiden Enden und verbinde es direkt mit dem Laptop, nicht über einen Hub\n• Der Roller muss aktiv und der AUX-Akku angeschlossen sein\nAm Roller wurde nichts verändert.';

  @override
  String get connectFailedDroppedHeading =>
      'Die Verbindung ist beim Aufbau abgebrochen';

  @override
  String get connectFailedDroppedBody =>
      'Die Verbindung wurde vor dem Abschluss getrennt. Das kann beim Neustart des Hauptboards oder beim Wechsel in den Ruhezustand passieren.\n• Entsperre den Roller oder setze einen Fahrakku in den vorderen Schacht. Ohne eines von beidem wechselt er automatisch in den Ruhezustand\n• Prüfe das USB-Kabel an beiden Enden\n• Warte, bis das Hauptboard vollständig gestartet ist, und versuche es erneut\nAm Roller wurde nichts verändert.';

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
  String get connectingSsh => 'SSH-Verbindung wird aufgebaut…';

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
    return 'SSH-Verbindung fehlgeschlagen: $error. Prüfe das Kabel und versuche es erneut.';
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
  String get configuringMdbBootloader => 'MDB-Bootloader wird konfiguriert';

  @override
  String get preparing => 'Vorbereitung…';

  @override
  String get uploadingBootloaderTools =>
      'Bootloader-Werkzeuge werden übertragen…';

  @override
  String get rebootingMdbUms =>
      'MDB wird im Massenspeichermodus neu gestartet…';

  @override
  String get waitingForUmsDevice => 'Warte auf UMS-Gerät…';

  @override
  String get readyToFlash => 'Bereit zum Flashen';

  @override
  String get readyToFlashHint =>
      'Das Gerät befindet sich im Flash-Modus. Du kannst es einbinden, um vor dem Fortfahren eine manuelle Sicherung zu erstellen.';

  @override
  String get readyToFlashTargetLabel => 'Ziel';

  @override
  String get readyToFlashImageLabel => 'Zu schreibendes Systemabbild';

  @override
  String get readyToFlashErases =>
      'Dabei wird der Speicher des Hauptboards überschrieben. Alle vorhandenen Daten werden ersetzt.';

  @override
  String get readyToFlashDuration =>
      'Das Schreiben dauert etwa eine Minute. Trenne währenddessen weder USB noch Strom.';

  @override
  String get readyToFlashNoTarget => 'Noch kein Zielgerät gefunden.';

  @override
  String get waitingForDeviceRedetection =>
      'Warte darauf, dass das Gerät erneut erkannt wird…';

  @override
  String get macosDiskNotReadable =>
      'macOS meldet möglicherweise, dass das Medium nicht gelesen werden kann. Klicke auf „Ignorieren“. Klicke nicht auf „Auswerfen“, da dadurch das MDB während der Installation getrennt wird.';

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
  String get beginFlashing => 'Flashen starten';

  @override
  String get flashingMdb => 'MDB wird geflasht';

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
  String get flashVerifyingReadback =>
      'Bootkritische Daten auf dem Gerät werden geprüft…';

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
  String get scooterPrepHeading => 'Roller vorbereiten';

  @override
  String get scooterPrepSubheading =>
      'MDB-Firmware wurde geschrieben. Jetzt für den Neustart vorbereiten.';

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
  String get doneCbbAuxDisconnected => 'Neustart ausgelöst';

  @override
  String get doneAuxDisconnected => 'Fertig, AUX ist getrennt';

  @override
  String get brakeResetHeading => 'Roller neu starten';

  @override
  String get brakeResetIntro =>
      'Ziehe beide Bremshebel und halte sie fest. Lass alle zehn Sekunden den rechten Hebel etwa eine Sekunde los und ziehe ihn wieder. Lass nach dem vierten Halten einfach beide los. Der Neustart wird ausgelöst.';

  @override
  String get brakeResetAfterNote =>
      'Die USB-Verbindung verschwindet während des Neustarts. Das ist normal, der Installer wartet auf das MDB.';

  @override
  String get brakePacerStart => 'Timer starten';

  @override
  String get brakePacerStop => 'Timer stoppen';

  @override
  String get brakePacerRestart => 'Erneut starten';

  @override
  String get brakePacerDone =>
      'Das war das richtige Muster. Der Neustart folgt wenige Sekunden später von selbst.';

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
  String get brakeKeepHolding => 'Beide Bremsen halten';

  @override
  String get brakeReleaseNow => 'Beide Bremsen loslassen';

  @override
  String get scooterPrepManualFallback => 'Oder den Strom von Hand trennen';

  @override
  String get deactivatingMainBattery => 'Fahrakku wird abgeschaltet…';

  @override
  String get waitingForMdbBoot => 'Warte auf den MDB-Start';

  @override
  String get mdbBootRestartingNote =>
      'Der Neustart des Rollers dauert ein bis zwei Minuten.';

  @override
  String get reconnectAuxPole => 'Nur den AUX-Pol wieder anschließen';

  @override
  String get reconnectAuxPoleDesc =>
      'Schließe den positiven AUX-Pol wieder an. Die CBB bleibt vorerst getrennt und wird erst vor dem DBC-Flash wieder angeschlossen. Danach startet das MDB mit Librescoot.';

  @override
  String get dbcLedHint =>
      'DBC-LED: orange = startet, grün = bootet, aus = läuft';

  @override
  String get mdbStillUms =>
      'MDB weiterhin im UMS-Modus. Der Flashvorgang war möglicherweise nicht erfolgreich. Neuer Versuch…';

  @override
  String get waitingForMdbRestart => 'Warte auf den Neustart des Rollers…';

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
  String get reconnectingSsh => 'SSH-Verbindung wird wiederhergestellt…';

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
  String get preparingDbcFlash => 'DBC-Flash wird vorbereitet';

  @override
  String get preparingDbcFlashSubtitle =>
      'Die Dateien für das Display werden zuerst auf das MDB übertragen.';

  @override
  String get preparingDbcFlashExplainer =>
      'Der Installer überträgt zuerst Systemabbild, Firmware und Offline-Karten auf das MDB. Sobald die Dateien bereit sind, startest du die Installation auf dem Roller und ersetzt das Laptop-Kabel durch das DBC-Kabel. Das MDB erledigt die Display-Arbeiten anschließend selbstständig.';

  @override
  String get preparingMapTransfer => 'Karten werden übertragen';

  @override
  String get preparingMapTransferSubtitle =>
      'Die Offline-Karten werden zuerst auf das MDB übertragen.';

  @override
  String get preparingMapTransferExplainer =>
      'Der Installer überträgt zuerst die Offline-Karten auf das MDB. Die Display-Firmware bleibt unverändert. Sobald die Dateien bereit sind, startest du die Übertragung und ersetzt das Laptop-Kabel durch das DBC-Kabel. Der Roller kopiert die Karten anschließend selbstständig.';

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
      'Alle Dateien sind bereit. Starte die Display-Arbeiten, wenn du bereit bist.';

  @override
  String get handoffEstimateTitle => 'Geschätzter Fortschritt';

  @override
  String get handoffEstimateExplanation =>
      'Solange das MDB mit dem DBC verbunden ist, kann der Laptop den aktuellen Fortschritt nicht auslesen. Die Schätzung wird aus den Dateigrößen und gemessenen Laufzeiten echter Installationen berechnet. Schließe den Laptop nicht aufgrund der Schätzung wieder an, sondern warte auf den tatsächlichen Zustand an Display und Blinkern.';

  @override
  String handoffEstimateMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String handoffEstimateRemaining(String left) {
    return 'Noch etwa $left';
  }

  @override
  String handoffEstimateRemainingUpper(String to) {
    return 'Noch bis zu etwa $to';
  }

  @override
  String handoffEstimateTotalRange(String from, String to) {
    return 'Voraussichtliche Gesamtdauer: etwa $from–$to';
  }

  @override
  String get handoffEstimateTakingLonger =>
      'Der Vorgang dauert länger als erwartet. Lass den Roller eingeschaltet und die Kabel verbunden.';

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
      'Der Roller wurde wiederhergestellt und entsperrt. Die gewünschte Display- oder Kartenübertragung wurde nicht installiert.';

  @override
  String get dbcReadyButton => 'DBC-Installation starten';

  @override
  String get dbcFlashInProgress => 'DBC wird geflasht';

  @override
  String get dbcFlashSwapCablesTitle => 'DBC-Kabel am MDB anschließen';

  @override
  String get dbcFlashSwapCablesDeadline =>
      'Der Vorgang wartet bereits auf das Display. Nach einigen Minuten läuft die Wartezeit ab. Stecke das Kabel jetzt um; die Schrauben kannst du danach festziehen.';

  @override
  String get disconnectUsbFromLaptop => 'Laptop-USB-Kabel vom MDB abziehen';

  @override
  String get disconnectUsbFromLaptopDesc =>
      'Ziehe das Laptop-USB-Kabel vom MDB ab, damit der Anschluss für das DBC-Kabel frei ist.';

  @override
  String get reconnectDbcUsbToMdb => 'DBC-USB-Kabel mit MDB verbinden';

  @override
  String get reconnectDbcUsbToMdbDesc =>
      'Stecke das interne DBC-USB-Kabel in den MDB-Port. Ziehe die Schrauben noch nicht fest.';

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
  String get blinkerStepFlash => 'Display vorbereiten';

  @override
  String get blinkerStepRestart => 'Display neu starten';

  @override
  String get blinkerStepMaps => 'Offline-Karten kopieren';

  @override
  String get verifyingDbcInstallation => 'Display-Arbeiten werden geprüft';

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
  String get dbcFlashSuccessful => 'Display-Arbeiten abgeschlossen';

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
  String get trampolineStatusUnknown =>
      'Der Installer konnte nicht feststellen, ob die Display-Arbeiten abgeschlossen wurden. Einzelheiten stehen im Installationsprotokoll.';

  @override
  String get welcomeToLibrescoot => 'Willkommen bei Librescoot';

  @override
  String get finishStatusTitle => 'Installationsstatus';

  @override
  String get finishPendingHeading => 'Installation läuft noch';

  @override
  String get finishCompleteHeading => 'Installation abgeschlossen';

  @override
  String get finishSkippedHeading => 'Display-Übertragung übersprungen';

  @override
  String get finalSteps => 'Letzte Schritte:';

  @override
  String get finishOnDevice =>
      'Der Roller schließt die Installation selbstständig ab. Lass ihn eingeschaltet und behalte die aktuelle Kabelverbindung bei, bis der Vorgang beendet ist.';

  @override
  String get finishReconnectDbc =>
      'Der Laptop ist wieder mit dem MDB verbunden. Schließe das DBC-Kabel wieder an, damit die Installation abgeschlossen werden kann.';

  @override
  String get finishConfirmed =>
      'Die Installation ist abgeschlossen. Der Roller ist entsperrt und fahrbereit.';

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
      'DBC-USB-Kabel anschließen und festschrauben';

  @override
  String get reconnectDbcUsbCableDesc =>
      'Stecke das interne DBC-USB-Kabel wieder in den MDB-Port und schraube es jetzt vorsichtig fest.';

  @override
  String get closeSeatboxAndFootwell => 'Fußraumabdeckung wieder anbringen';

  @override
  String get closeSeatboxAndFootwellDesc =>
      'Setze zuerst die Metallbügel wieder ein. Bringe dann die Fußraumabdeckung an und schraube sie fest.';

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
  String get backingUpConfig => 'Gerätekonfiguration wird gesichert…';

  @override
  String get configBackedUp => 'Gerätekonfiguration gesichert';

  @override
  String get restoringConfig => 'Gerätekonfiguration wird wiederhergestellt…';

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
      'Wähle, welche Offline-Karten heruntergeladen werden. Ob sie installiert werden, entscheidest du später zusammen mit dem restlichen Plan.';

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
      'Es wird keine Schlüsselkarte angelernt. Richte später Bluetooth ein, wenn du eine andere Entsperrmethode benötigst.';

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
      'Mit der Anlernkarte verwaltest du weitere Schlüsselkarten. Sie kann den Roller nicht entsperren. Verwende eine separate Karte, die noch nicht als Schlüsselkarte angelernt ist.';

  @override
  String get keycardMasterStageHint => 'Halte die Anlernkarte an den Leser.';

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
  String get keycardSimulateTapButton => '[DRY RUN] Kartenkontakt simulieren';

  @override
  String get keycardSimulateMasterTapButton =>
      '[DRY RUN] Anlernkarte simulieren';

  @override
  String get keycardSimulateRejectedTapButton =>
      '[DRY RUN] Ablehnung einer angelernten Karte simulieren';

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
  String get phaseMdbArtifactTitle => 'MDB-Update';

  @override
  String get phaseMdbArtifactDescription => 'Firmware installieren';

  @override
  String get majorStepMdbUpgrade => 'MDB aktualisieren';

  @override
  String get majorStepDbcUpgrade => 'DBC aktualisieren';

  @override
  String get installPlanHeading => 'Was soll der Installer tun?';

  @override
  String installPlanIntro(String version) {
    return 'Wähle eine Aktion für jedes Board. Zielversion: $version';
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
      'Behält Einstellungen, Schlüsselkarten und Karten';

  @override
  String get actionCleanInstall => 'Neu installieren';

  @override
  String get actionCleanInstallDetail =>
      'Löscht Einstellungen. Schlüsselkarten und Karten werden in diesem Vorgang neu eingerichtet';

  @override
  String get actionUpgradeDetailDbc => 'Behält die Offline-Karten';

  @override
  String get actionCleanInstallDetailDbc => 'Löscht nur die Offline-Karten';

  @override
  String get actionCleanInstallDetailDbcTiles =>
      'Löscht die Offline-Karten. Sie werden in diesem Vorgang neu installiert';

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
      'Für neue Kartendaten muss das DBC-Kabel umgesteckt werden, auch wenn das DBC unverändert bleibt';

  @override
  String get planInstallTiles => 'Offline-Karten aktualisieren';

  @override
  String get planInstallTilesDetail =>
      'Fügt einen DBC-Schritt hinzu: Die Karten werden auf das MDB übertragen. Danach wird das Kabel zurückgesteckt und die Karten werden automatisch installiert.';

  @override
  String get planTilesNotDownloaded =>
      'Nicht heruntergeladen. Offline-Karten wurden im ersten Schritt übersprungen.';

  @override
  String get actionLeaveBlockedStockMdb =>
      'Das Serien-Hauptboard muss installiert werden, bevor weitere Aktionen möglich sind';

  @override
  String get planDbcNeedsLibrescootMdb =>
      'Das DBC ist nur über das MDB erreichbar und die benötigten Werkzeuge gehören zu Librescoot. Installiere in diesem Vorgang das MDB mit oder lasse das DBC unverändert.';

  @override
  String get planNothingToDo =>
      'Keine Aktion ausgewählt. Wähle mindestens eine Aktion, um fortzufahren.';

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
  String get waitingForDbcUpload => 'Display-Dateien werden noch übertragen';

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
      'Beim Installieren des vollständigen Systemabbilds wird die Datenpartition neu formatiert. Einstellungen, angelernte Schlüsselkarten und Offline-Karten gehen verloren. Die begonnene Aktualisierung hätte diese Daten erhalten.\n\nEin erneuter Versuch mit der Firmware-Aktualisierung erhält die Daten. Installiere das vollständige Systemabbild nur, wenn das Paket weiterhin fehlschlägt.';

  @override
  String get fallBackWipeConfirm => 'Löschen und Systemabbild installieren';

  @override
  String get dbcCleanInstallButton => 'DBC löschen und neu installieren';

  @override
  String get dbcCleanInstallTitle => 'Dabei wird das DBC gelöscht';

  @override
  String get dbcCleanInstallBody =>
      'Die zuletzt bekannte DBC-Version basiert auf dem letzten gemeinsamen Betrieb mit dem MDB. Ein als aktualisierbar eingestuftes Board hat daher möglicherweise keinen Update-Client. Bei einer Neuinstallation wird zuerst das Grundsystem installiert. Dabei wird die Datenpartition des DBC formatiert und die Offline-Karten gehen verloren. Die Daten auf dem MDB, einschließlich Einstellungen und angelernter Schlüsselkarten, bleiben erhalten.\n\nStecke dafür das Kabel erneut um: Der Installer überträgt die Dateien, du schließt das DBC-Kabel wieder am MDB an, danach läuft der Vorgang automatisch.';

  @override
  String get dbcCleanInstallConfirm => 'DBC löschen und installieren';

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
  String get checkingCbbAndBattery => 'CBB und Akku werden geprüft…';

  @override
  String get waitingForUsbDisconnect => 'Warte auf USB-Trennung…';

  @override
  String get dbcFlashDurationHeadline =>
      'Die Display-Arbeiten dauern normalerweise 10 bis 20 Minuten.';

  @override
  String get finishHandoverRestoring =>
      'Einstellungen und Dienste werden wiederhergestellt';

  @override
  String get finishBlockedHeading =>
      'Die Installation wurde nicht abgeschlossen';

  @override
  String get finishBlockedBody =>
      'Die Verbindung zum Roller ist vor der abschließenden Statusprüfung abgebrochen. Die Display- oder Kartenübertragung wurde möglicherweise nicht gestartet oder nicht abgeschlossen.\n\nPrüfe das USB-Kabel an beiden Enden und wähle „Erneut versuchen“. Wenn die Verbindung nicht wiederhergestellt werden kann, schließe den Installer und starte ihn erneut. Der aufgezeichnete Installationsstand bleibt erhalten.';

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
      'Der Roller führt jetzt die ausgewählten Display-Arbeiten aus. Den tatsächlichen Zustand zeigen das Display und die Blinker. Warte, bis der Vorgang abgeschlossen ist oder ein Fehler angezeigt wird.';

  @override
  String get dbcFlashDoNotDisconnect =>
      'USB und Strom nicht trennen, solange das läuft.';

  @override
  String get dbcFlashDoneSignal =>
      'Fertig: Der Roller wird automatisch entsperrt. Das ist das Abschlusszeichen; du musst nicht weiter warten.';

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
      'UMS-Gerät nicht innerhalb von 60 s erkannt. MDB ist möglicherweise wieder in Linux gebootet.';

  @override
  String get waitingForDevicePath => 'Warte auf Gerätepfad…';

  @override
  String get noDevicePathFound =>
      'Kein Gerätepfad gefunden. Prüfe die USB-Verbindung und versuche es erneut.';

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
  String get substepConnectSsh => 'SSH-Verbindung herstellen';

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
    return 'Das MDB ist seit $minutes Minuten nicht als USB-Netzwerkgerät zurückgekehrt. Die erste Display-Einrichtung kann länger dauern, während Speicher und Offline-Karten vorbereitet werden. Du kannst weiter warten, die Prüfung wiederholen, die Display-Arbeiten erneut starten oder zum Abschluss gehen.';
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
  String get substepFileImage => 'Display-Systemabbild';

  @override
  String get substepFileImageMap => 'Prüfdaten zum Display-Systemabbild';

  @override
  String get substepFileFirmware => 'Display-Firmware';

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
  String get blePairingStep3 => 'PIN bestätigen';

  @override
  String get blePairingStep3Desc =>
      'Die PIN erscheint hier auf dem Bildschirm, sobald dein Handy fragt.';

  @override
  String get blePairingOneAtATime =>
      'Der Roller hält immer nur eine Bluetooth-Verbindung. Ist schon ein Gerät verbunden, trenne es zuerst dort.';

  @override
  String get keycardWhy =>
      'Mit einer angelernten Schlüsselkarte entsperrst du den Roller ohne Handy. Du kannst mehrere Schlüsselkarten anlernen und das später jederzeit wiederholen. Eine Neuinstallation löscht zuvor angelernte Schlüsselkarten.';

  @override
  String get keycardStep1 => 'Anlernen starten';

  @override
  String get keycardStep1Desc =>
      'Danach wartet der Roller auf eine Schlüsselkarte.';

  @override
  String get keycardStep2 => 'Schlüsselkarte an den Leser halten';

  @override
  String get keycardStep2Desc =>
      'Der Leser befindet sich vorne am Display. Halte die Schlüsselkarte dort, bis der Installer sie zählt.';

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
      'Der Leser sitzt im Display-Gehäuse und hängt über den DBC-Kabelbaum am MDB. Schließe den Kabelbaum an und versuche es erneut.';

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
  String get blePinConfirmTitle => 'Diese PIN am Handy bestätigen';

  @override
  String get blePinConfirmHint =>
      'Dein Handy zeigt dieselbe Zahl. Wenn beide übereinstimmen, bestätige die PIN dort.';

  @override
  String get blePairingStep2DescCompare =>
      'Vergleiche den Namen und die Adresse rechts, wenn mehrere Geräte auftauchen.';

  @override
  String get blePairingStep3DescOverlay =>
      'Der Installer zeigt sie groß an, sobald dein Handy danach fragt.';

  @override
  String get dbcSayInstalling =>
      'Firmware wird installiert. Dies dauert einige Minuten';

  @override
  String get dbcSayInstalled =>
      'Firmware installiert. Display wird neu gestartet';

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
      'Das Display hat sich nach dem Flashen nicht zurückgemeldet.';

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
      'Das Hauptboard hat nichts Startbares gefunden und befindet sich im Wiederherstellungsmodus. Nach etwa zwei Minuten wird es automatisch neu gestartet. Lass Kabel und Stromversorgung angeschlossen.';
}

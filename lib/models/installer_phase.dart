enum InstallerPhase {
  welcome(
    title: 'Welcome',
    description: 'Prerequisites and firmware selection',
    isManual: true,
  ),
  notices(
    title: 'Notices',
    description: 'Important warnings before you start',
    isManual: true,
  ),
  physicalPrep(
    title: 'Physical Prep',
    description: 'Open footwell, connect USB',
    isManual: true,
  ),
  mdbConnect(
    title: 'MDB Connect',
    description: 'Detect device and establish SSH',
    isManual: false,
  ),
  resumeDetected(
    title: 'Resume',
    description: 'Interrupted installation found',
    isManual: true,
    hiddenUnlessActive: true,
  ),
  healthCheck(
    title: 'Health Check',
    description: 'Verify scooter readiness',
    isManual: false,
  ),
  installPlan(
    title: 'Install Plan',
    description: 'Choose what happens to each board',
    isManual: true,
    hiddenUnlessActive: true,
  ),
  mdbToUms(
    title: 'MDB → UMS',
    description: 'Configure bootloader for flashing',
    isManual: false,
  ),
  mdbFlash(
    title: 'MDB Flash',
    description: 'Write firmware to MDB',
    isManual: false,
  ),
  scooterPrep(
    title: 'Scooter Prep',
    description: 'Disconnect CBB and AUX',
    isManual: true,
  ),
  mdbBoot(
    title: 'MDB Boot',
    description: 'Reconnect AUX, wait for boot',
    isManual: true,
  ),
  bluetoothPairing(
    title: 'Bluetooth',
    description: 'Pair phone or other devices',
    isManual: true,
  ),
  keycardSetup(
    title: 'Keycard Setup',
    description: 'Register master and user keycards',
    isManual: true,
  ),
  mdbArtifact(
    title: 'MDB Update',
    description: 'Install the firmware artifact',
    isManual: false,
  ),
  cbbReconnect(
    title: 'CBB Reconnect',
    description: 'Reconnect CBB for DBC flash',
    isManual: true,
  ),
  dbcPrep(
    title: 'DBC Prep',
    description: 'Upload DBC image and tiles',
    isManual: false,
  ),
  dbcFlash(
    title: 'DBC Flash',
    description: 'Autonomous DBC installation',
    isManual: false,
  ),
  reconnect(
    title: 'Reconnect',
    description: 'Verify an interrupted DBC install',
    isManual: true,
    hiddenUnlessActive: true,
  ),
  finish(
    title: 'Finish',
    description: 'Reassemble and welcome',
    isManual: true,
  );

  const InstallerPhase({
    required this.title,
    required this.description,
    required this.isManual,
    this.hiddenUnlessActive = false,
  });

  final String title;
  final String description;
  final bool isManual;

  /// Phases most installs never enter (e.g. resuming an interrupted
  /// install). Shown in the sidebar only while they are the current phase.
  final bool hiddenUnlessActive;
}

/// The phases that are nothing but waiting on the board. They draw as an
/// overlay over the screen the user just left rather than as a screen of
/// their own, because a screen of their own is an empty frame with a spinner
/// in the middle of it.
/// DBC-Vorbereitung and Prüfen are not in here: they already show their own
/// substeps, so they are not empty frames to begin with.
const Set<InstallerPhase> kWaitPhases = {
  InstallerPhase.mdbConnect,
  InstallerPhase.mdbToUms,
  InstallerPhase.mdbBoot,
  InstallerPhase.mdbArtifact,
};

extension InstallerPhaseWait on InstallerPhase {
  bool get isWait => kWaitPhases.contains(this);
}

/// Major step grouping for sidebar display
enum MajorStep {
  prepare('Prepare', [InstallerPhase.welcome, InstallerPhase.notices, InstallerPhase.physicalPrep]),
  connect('Connect', [InstallerPhase.mdbConnect, InstallerPhase.resumeDetected, InstallerPhase.healthCheck, InstallerPhase.installPlan]),
  mdbFlash('Flash MDB', [InstallerPhase.mdbToUms, InstallerPhase.mdbFlash, InstallerPhase.scooterPrep, InstallerPhase.mdbBoot]),
  pairing('Pairing & Cards', [InstallerPhase.bluetoothPairing, InstallerPhase.keycardSetup]),
  mdbInstall('Install MDB', [InstallerPhase.mdbArtifact, InstallerPhase.cbbReconnect]),
  dbcFlash('Flash DBC', [InstallerPhase.dbcPrep, InstallerPhase.dbcFlash, InstallerPhase.reconnect]),
  finish('Finish', [InstallerPhase.finish]);

  const MajorStep(this.title, this.phases);

  final String title;
  final List<InstallerPhase> phases;

  bool containsPhase(InstallerPhase phase) => phases.contains(phase);

  bool isActive(InstallerPhase currentPhase) => containsPhase(currentPhase);

  bool isCompleted(InstallerPhase currentPhase) {
    if (phases.isEmpty) return false;
    return currentPhase.index > phases.last.index;
  }

  static MajorStep forPhase(InstallerPhase phase) {
    return MajorStep.values.firstWhere((s) => s.containsPhase(phase));
  }
}

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
  batteryRemoval(
    title: 'Battery Removal',
    description: 'Open seatbox, remove main battery',
    isManual: true,
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
  cbbReconnect(
    title: 'CBB Reconnect',
    description: 'Reconnect CBB for DBC flash',
    isManual: true,
  ),
  dashboardPrep(
    title: 'Dashboard Prep',
    description: 'Pair, enroll keycards, stage DBC image',
    isManual: false,
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
  dbcSwapAndFlash(
    title: 'DBC Flash',
    description: 'Swap cable; scooter flashes the DBC',
    isManual: true,
  ),
  reconnect(
    title: 'Reconnect',
    description: 'Verify after an interrupted DBC flash',
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

/// Major step grouping for sidebar display
enum MajorStep {
  prepare('Prepare', [InstallerPhase.welcome, InstallerPhase.notices, InstallerPhase.physicalPrep]),
  connect('Connect', [InstallerPhase.mdbConnect, InstallerPhase.resumeDetected, InstallerPhase.healthCheck]),
  mdbFlash('Flash MDB', [InstallerPhase.batteryRemoval, InstallerPhase.mdbToUms, InstallerPhase.mdbFlash, InstallerPhase.scooterPrep, InstallerPhase.mdbBoot, InstallerPhase.cbbReconnect]),
  mdbPrep('Dashboard Prep', [InstallerPhase.dashboardPrep, InstallerPhase.bluetoothPairing, InstallerPhase.keycardSetup]),
  dbc('Flash DBC', [InstallerPhase.dbcSwapAndFlash]),
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
    return MajorStep.values.firstWhere(
      (s) => s.containsPhase(phase),
      orElse: () => MajorStep.connect,
    );
  }
}

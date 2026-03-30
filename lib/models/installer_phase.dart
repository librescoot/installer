enum InstallerPhase {
  welcome(
    title: 'Welcome',
    description: 'Prerequisites and firmware selection',
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
    description: 'Verify DBC installation',
    isManual: true,
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
  });

  final String title;
  final String description;
  final bool isManual;
}

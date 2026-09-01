import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Entering with the MDB already in U-Boot mass storage bypasses both the
/// health check and plan screen. The release image flashed there is only the
/// minimal bootstrap, so losing the implicit clean-install plan skips its
/// .mender artifact and leaves the scooter on the bootstrap image.
void main() {
  late String massStorageBranch;

  setUpAll(() {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final connect = source.indexOf('Future<void> _autoConnectMdb() async {');
    expect(connect, isNot(-1));
    final branch = source.indexOf(
      'if (_device!.mode == DeviceMode.massStorage)',
      connect,
    );
    expect(branch, isNot(-1));
    final end = source.indexOf('\n    // RNDIS mode: normal flow.', branch);
    expect(end, isNot(-1));
    massStorageBranch = source.substring(branch, end);
  });

  test('seeds a direct-mass-storage plan before entering the flash phase', () {
    final seed = massStorageBranch.indexOf('InstallPlan.directMassStorage(');
    final flash = massStorageBranch.indexOf(
      '_setPhase(InstallerPhase.mdbFlash)',
    );

    expect(seed, isNot(-1));
    expect(flash, isNot(-1));
    expect(seed, lessThan(flash));
  });

  test('does not reinterpret explicit local full images as stage 0', () {
    expect(
      massStorageBranch,
      contains('_plan == null && !launchArgs.hasLocalImages'),
    );
  });

  test('marks the expected bootstrap boot before flashing', () {
    expect(massStorageBranch, contains('_expectMinimalMdb = true'));
  });
}

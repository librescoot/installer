import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Entering with the MDB already in U-Boot mass storage bypasses the health
/// check. The release image flashed there is only the minimal bootstrap, so
/// losing the implicit clean-install plan skips its .mender artifact and
/// leaves the scooter on the bootstrap image. The plan screen is still
/// visited: the board in mass storage says nothing about the dashboard, and
/// the run used to assume a clean install there without asking.
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

  test('seeds a direct-mass-storage plan and shows it before flashing', () {
    final seed = massStorageBranch.indexOf('InstallPlan.directMassStorage(');
    final plan = massStorageBranch.indexOf(
      '_setPhase(InstallerPhase.installPlan)',
    );

    expect(seed, isNot(-1));
    expect(plan, isNot(-1));
    expect(seed, lessThan(plan));
    expect(massStorageBranch, contains('_directMassStorageRoute = true'));
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

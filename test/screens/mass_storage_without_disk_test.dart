import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  test('a gadget with no disk is not reported as a cable problem', () {
    final start = source.indexOf('// Resolve the block device path');
    final block = source.substring(start, start + 1400);
    expect(block, contains('l10n.massStorageWithoutDisk'));
    expect(block, contains('DeviceMode.massStorage'));
    expect(
      block.indexOf('l10n.massStorageWithoutDisk'),
      lessThan(block.indexOf('l10n.noDevicePathFound')),
      reason: 'the mass-storage case is the fallback, not the first answer',
    );
  });

  test('the host disk picture is captured before the failure is reported', () {
    final start = source.indexOf('// Resolve the block device path');
    final block = source.substring(start, start + 1400);
    expect(
      block.indexOf('_logMassStorageDiagnostics()'),
      lessThan(block.indexOf('_blockMdbFlash()')),
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();
  final de = File('lib/l10n/app_de.arb').readAsStringSync();
  final en = File('lib/l10n/app_en.arb').readAsStringSync();

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

  String valueOf(String arb, String key) =>
      RegExp('"$key":\\s*"((?:[^"\\\\]|\\\\.)*)"')
          .firstMatch(arb)!
          .group(1)!;

  test('the wording exists in both languages and promises nothing', () {
    final german = valueOf(de, 'massStorageWithoutDisk');
    final english = valueOf(en, 'massStorageWithoutDisk');

    expect(german, contains('Melde dich damit im Librescoot-Chat.'));
    expect(english, contains('Please report this in the Librescoot chat.'));
    for (final text in [
      'sitzbank',
      'seatbox',
      'akku',
      'battery',
      'einschalten',
      'power-cycle',
      'kabel',
      'cable',
    ]) {
      expect(
        german.toLowerCase(),
        isNot(contains(text)),
        reason: 'no remedy or cable advice is claimed until one is verified',
      );
      expect(english.toLowerCase(), isNot(contains(text)));
    }
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

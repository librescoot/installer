import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/l10n/app_localizations_en.dart';
import 'package:librescoot_installer/services/flash_service.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  test('recording controls are hidden without enabling device operations', () {
    expect(
      'if (_isDryRun && !launchArgs.recordingDemo)'.allMatches(source),
      hasLength(2),
    );
    expect(source, contains('if (_isDryRun && launchArgs.recordingDemo)'));
    expect(
      source,
      contains(
        'if (isCurrent() && _keycardLearning) _keycardSimulateCardTap();',
      ),
    );
    expect(source, isNot(contains('[DRY RUN]')));
    for (final lang in ['de', 'en']) {
      final messages =
          jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final entry in messages.entries) {
        if (entry.value is String) {
          expect(entry.value, isNot(contains('[DRY RUN]')), reason: entry.key);
        }
      }
    }
  });

  test('simulated disk uses the nominal MDB capacity and detector name', () {
    expect(source, contains('sizeBytes: FlashService.mdbEmmcBytes'));
    expect(source, contains("name: 'Librescoot MDB (Mass Storage)'"));
    expect(FlashService.mdbEmmcBytes, 7818182656);
    expect(source, isNot(contains("path: '/dev/dry-run-mdb'")));
  });

  test('Bluetooth instructs PIN entry, not numeric comparison', () {
    final de = AppLocalizationsDe();
    final en = AppLocalizationsEn();
    expect(de.blePinConfirmTitle, contains('eingeben'));
    expect(de.blePinConfirmHint, contains('Eingabefeld'));
    expect(de.blePairingStep3DescOverlay, contains('Eingabefeld'));
    expect(en.blePinConfirmHint, contains('input field'));
    expect(de.blePinConfirmHint, isNot(contains('übereinstimmen')));
    expect(en.blePinConfirmHint, isNot(contains('same number')));
  });

  test('stock-card note follows the introduction with explicit spacing', () {
    final start = source.indexOf('Widget _buildKeycardSetup(');
    final intro = source.indexOf('l10n.keycardWhy', start);
    final note = source.indexOf('l10n.originalKeycardsNotice', start);
    expect(note, greaterThan(intro));
    expect(source.substring(intro, note), contains('SizedBox(height: 12)'));
    expect(source.substring(intro, note), contains('EdgeInsets.all(10)'));
  });
}

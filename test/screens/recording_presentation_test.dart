import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}

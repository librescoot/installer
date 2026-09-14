import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/phase_attempt.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();
  final wait = source.substring(
    source.indexOf('Future<void> _waitForMdbBoot(int generation) async {'),
    source.indexOf('_setStatus(l10n.mdbDetectedNetwork);'),
  );

  group('waiting for the board to come back gives up eventually', () {
    test('the poll has a deadline', () {
      expect(
        wait,
        contains('final deadline = DateTime.now().add(_mdbBootCeiling)'),
      );
      expect(wait, contains('expired()'));
    });

    test('the ceiling leaves room for a healthy boot and a recovery cycle', () {
      expect(source, contains('_mdbBootCeiling = Duration(minutes: 10)'));
    });

    test('giving up lands in the failure state, not another wait', () {
      expect(wait, contains('_failMdbBoot(generation, l10n.mdbBootGaveUp('));
    });

    test('that state carries a retry the user can press', () {
      final build = source.substring(
        source.indexOf('Widget _buildMdbBoot(AppLocalizations l10n) {'),
        source.indexOf('void _startMdbBoot('),
      );
      expect(build, contains('if (_mdbBootAttempt.isFailed)'));
      expect(build, contains('_startMdbBoot(explicitRetry: true)'));
    });

    test('a failed attempt can be begun again', () {
      final attempt = PhaseAttempt();
      final first = attempt.begin()!;
      attempt.fail(first, 'gave up');
      expect(attempt.isFailed, isTrue);
      expect(attempt.begin(), isNotNull);
    });

    test('the message says the board looks dead rather than is dead', () {
      final en = File('lib/l10n/app_en.arb').readAsStringSync();
      expect(en, contains('"mdbBootGaveUp"'));
      final de = File('lib/l10n/app_de.arb').readAsStringSync();
      expect(de, contains('"mdbBootGaveUp"'));
      for (final arb in [en, de]) {
        final line = arb
            .split('\n')
            .firstWhere((l) => l.contains('"mdbBootGaveUp":'));
        expect(line, contains('{minutes}'));
      }
    });
  });
}

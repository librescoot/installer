import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/phase_attempt.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  group('entering the finish phase runs its entry work once', () {
    test('a transition to the phase already showing is not an entry', () {
      for (final phase in ['finish', 'keycardSetup']) {
        expect(source, contains('phase == InstallerPhase.$phase && leaving != phase'),
            reason: phase);
      }
    });

    test('nothing calls the entry work directly', () {
      final refs = RegExp(r'_onEnterFinish\b')
          .allMatches(source)
          .map((m) => source.substring(
                source.lastIndexOf('\n', m.start) + 1,
                source.indexOf('\n', m.end),
              ).trim())
          .where((line) => !line.startsWith('///'))
          .toList();
      expect(refs, hasLength(2), reason: 'unguarded caller: $refs');
      expect(refs, contains('await _onEnterFinish();'));
      expect(refs.last, startsWith('Future<void> _onEnterFinish()'));
      expect(
        RegExp(r'_startFinishEntry\b').allMatches(source).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('a second entry is refused while the first is still running', () {
      final attempt = PhaseAttempt();
      final first = attempt.begin();
      expect(first, isNotNull);
      expect(attempt.isRunning, isTrue);
      expect(attempt.begin(), isNull);
    });

    test('a completed entry does not block a later genuine one', () {
      final attempt = PhaseAttempt();
      final first = attempt.begin()!;
      attempt.complete(first);
      expect(attempt.begin(), isNull, reason: 'completed refuses without reset');
      if (!attempt.isRunning) attempt.reset();
      expect(attempt.begin(), isNotNull);
    });

    test('the guard resets only when no run is in flight', () {
      final guard = source.substring(
        source.indexOf('Future<void> _startFinishEntry() async {'),
        source.indexOf('Future<void> _onEnterFinish() async {'),
      );
      expect(guard, contains('if (!_finishAttempt.isRunning) _finishAttempt.reset();'));
    });
  });
}

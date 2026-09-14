import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  group('the finish confirmation poll runs once, not once per USB event', () {
    final start = source.indexOf(
      'Future<void> _refreshFinishCompletion() async {',
    );
    final poll = source.substring(
      start,
      source.indexOf(
        '\n  }',
        source.indexOf('_finishCompletionChecking = false;', start),
      ),
    );

    test('a spent run is remembered', () {
      expect(poll, contains('_finishCompletionExhausted'));
      final entry = poll.substring(
        0,
        poll.indexOf('_finishCompletionChecking = true'),
      );
      expect(
        entry,
        contains('_finishCompletionExhausted'),
        reason: 'the guard has to be tested on entry, not only set',
      );
    });

    test('it is set where the attempts run out', () {
      final tail = poll.substring(
        poll.indexOf('was not confirmed before timeout'),
      );
      expect(tail, contains('_finishCompletionExhausted = true;'));
    });

    test('asking by hand asks again', () {
      final byHand = source.substring(
        source.indexOf('Future<void> _finishAfterDbcSuccess() async {'),
        source.indexOf(
          '_setPhase(InstallerPhase.finish);',
          source.indexOf('Future<void> _finishAfterDbcSuccess() async {'),
        ),
      );
      expect(byHand, contains('_finishCompletionExhausted = false;'));
    });
  });

  group('a phase guard that suppresses work gets reset like the rest', () {
    test('the CBB auto-check re-arms on entering the phase', () {
      final entry = source.substring(
        source.indexOf('if (phase == InstallerPhase.cbbReconnect) {'),
        source.indexOf('} else if (leaving == InstallerPhase.cbbReconnect) {'),
      );
      expect(entry, contains('_cbbPollAbandoned = false;'));
      expect(entry, contains('_cbbAutoCheckStarted = false;'));
    });
  });

  group('timers started from an event do not stack or outlive the widget', () {
    test('the keycard auto-advance is held and replaced, not stacked', () {
      final handler = source.substring(
        source.indexOf("} else if (payload.startsWith('master-learned:')) {"),
        source.indexOf(
          "} else if (payload.startsWith('rejected:already-authorized:')) {",
        ),
      );
      expect(handler, contains('_keycardAdvanceTimer?.cancel();'));
      expect(handler, contains('_keycardAdvanceTimer = Timer('));
    });

    test('every timer field is cancelled in dispose', () {
      final dispose = source.substring(
        source.indexOf('  void dispose() {'),
        source.indexOf('  void _setPhase('),
      );
      final fields = RegExp(r'  Timer\? (_[A-Za-z]+);').allMatches(source);
      expect(fields.length, 3, reason: 'a new timer field needs a dispose too');
      for (final t in fields) {
        expect(
          dispose,
          contains('${t.group(1)}?.cancel()'),
          reason: t.group(1),
        );
      }
    });

    test('master events and their timers check stage ownership', () {
      final handler = source.substring(
        source.indexOf("} else if (payload.startsWith('master-learned:')) {"),
        source.indexOf(
          "} else if (payload.startsWith('rejected:already-authorized:')) {",
        ),
      );
      expect(handler, contains('_keycardMasterLearning ||'));
      expect(handler, contains('ownsKeycardMasterEvent('));
      expect(handler, contains('eventGeneration: generation'));
      expect(handler, contains('await _keycardTearDown();'));
      expect(handler, contains('_setPhase(_phaseAfterKeycardSetup);'));
    });

    test('Start Over invalidates master ownership before reset awaits', () {
      final startOver = source.substring(
        source.indexOf('Future<void> _keycardStartOver() async {'),
        source.indexOf(
          'Future<void> _skipKeycardSetupEntirely()',
          source.indexOf('Future<void> _keycardStartOver() async {'),
        ),
      );
      final invalidate = startOver.indexOf('++_keycardLearningGeneration;');
      final reset = startOver.indexOf("'reset'");
      expect(invalidate, greaterThan(-1));
      expect(reset, greaterThan(invalidate));
      expect(startOver, contains('_keycardMasterOwnerGeneration = null;'));
      expect(startOver, contains('_keycardAdvanceTimer?.cancel();'));
    });
    test('Start Over settles a pending master start before stop and reset', () {
      final startOver = source.substring(
        source.indexOf('Future<void> _keycardStartOver() async {'),
        source.indexOf(
          'Future<void> _skipKeycardSetupEntirely()',
          source.indexOf('Future<void> _keycardStartOver() async {'),
        ),
      );
      final invalidate = startOver.indexOf('++_keycardLearningGeneration;');
      final wait = startOver.indexOf('await pendingStart;');
      final stop = startOver.indexOf("'learn:master:stop'");
      final reset = startOver.indexOf("'reset'");
      expect(
        startOver,
        contains('final pendingStart = _keycardMasterStartPending;'),
      );
      expect(wait, greaterThan(invalidate));
      expect(stop, greaterThan(wait));
      expect(reset, greaterThan(stop));
    });
  });
}

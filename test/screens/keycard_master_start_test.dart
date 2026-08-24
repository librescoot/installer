import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The master stage tells the user to hold a card to the reader. That is only
/// true once the vehicle is in master teach-in and the installer is listening
/// for the event, so neither step may fail quietly: a failed start makes the
/// tap do nothing, and a failed subscribe lets the vehicle enrol the card
/// while the installer never hears about it.
void main() {
  late String source;
  late String start;
  late String stage;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();

    final startBegin = source.indexOf('Future<void> _keycardStartMasterStage(');
    final startEnd = source.indexOf(
      'Future<void> _keycardSubscribeEvents(',
      startBegin,
    );
    expect(startBegin, isNot(-1));
    expect(startEnd, greaterThan(startBegin));
    start = source.substring(startBegin, startEnd);

    final stageBegin = source.indexOf('Widget _buildKeycardMasterStage(');
    final stageEnd = source.indexOf('Widget _buildFinish(', stageBegin);
    expect(stageBegin, isNot(-1));
    expect(stageEnd, greaterThan(stageBegin));
    stage = source.substring(stageBegin, stageEnd);
  });

  test('neither failure is swallowed into a debug line any more', () {
    // Both steps sit in one try, so either one failing records the error.
    expect(start, contains('_keycardMasterStartError = e.toString()'));
    expect(start, isNot(contains('failed to subscribe to keycard events')));
    expect(start, isNot(contains('failed to start master teach-in')));
  });

  test('subscribing and starting are one operation', () {
    final subscribe = start.indexOf('await _keycardSubscribeEvents();');
    final push = start.indexOf("'learn:master:start'");
    final failure = start.indexOf('_keycardMasterStartError = e.toString()');
    expect(subscribe, greaterThan(-1));
    expect(push, greaterThan(subscribe));
    expect(failure, greaterThan(push), reason: 'one catch covers both steps');
  });

  test('the retry clears master mode before asking for it again', () {
    // A push that threw may still have landed, so the board can already be in
    // master mode and a second start would sit on top of the first.
    final stop = start.indexOf("'learn:master:stop'");
    final push = start.indexOf("'learn:master:start'");
    expect(stop, greaterThan(-1), reason: 'retry does not normalise the board');
    expect(push, greaterThan(stop));
    expect(start, contains('if (retry)'));
  });

  test('the mode is claimed before the push, so cleanup can undo it', () {
    // _stopActiveKeycardModes only sends learn:master:stop when this is set.
    // Setting it after a push that throws leaves a board stuck in master mode
    // with nothing left to stop it.
    final claim = start.indexOf('_keycardMasterLearning = true;');
    final push = start.indexOf("'learn:master:start'");
    expect(claim, greaterThan(-1));
    expect(push, greaterThan(claim));
  });

  test('the tap prompt is shown only when the stage really started', () {
    final hint = stage.indexOf('l10n.keycardMasterStageHint');
    final guard = stage.indexOf('if (_keycardMasterStartError == null)');
    expect(guard, greaterThan(-1));
    expect(hint, greaterThan(guard));
    expect(stage, contains('l10n.keycardMasterStageStartFailed'));
    expect(stage, contains('_keycardMasterStartError!'));
  });

  test('a failed stage offers Retry and keeps Skip and Start Over', () {
    expect(stage, contains('_keycardStartMasterStage(retry: true)'));
    expect(stage, contains('l10n.keycardMasterStageRetryButton'));
    expect(stage, contains('_keycardStopMasterStage(advance: true)'));
    expect(stage, contains('_keycardStartOver'));
  });

  test('the error does not survive into a fresh attempt', () {
    expect(start, contains('_keycardMasterStartError = null'));
  });

  test('both languages carry the new strings', () {
    for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_de.arb']) {
      final content = File(arb).readAsStringSync();
      expect(content, contains('keycardMasterStageStartFailed'), reason: arb);
      expect(content, contains('keycardMasterStageRetryButton'), reason: arb);
    }
  });
}

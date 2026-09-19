import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/screens/installer_screen.dart';

void main() {
  test('master stop waits for a pending start command to settle', () async {
    final start = Completer<void>();
    final events = <String>[];

    final stopping = stopKeycardMasterAfterPendingStart(
      pendingStart: start.future.then((_) => events.add('start')),
      sendStop: () async => events.add('stop'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);

    start.complete();
    await stopping;

    expect(events, ['start', 'stop']);
  });

  test('master stop is still sent when the pending start failed', () async {
    final errors = <Object>[];
    final events = <String>[];

    await stopKeycardMasterAfterPendingStart(
      pendingStart: Future<void>.error(StateError('start failed')),
      sendStop: () async => events.add('stop'),
      onStartError: errors.add,
    );

    expect(errors.single, isA<StateError>());
    expect(events, ['stop']);
  });

  test('generic cleanup uses the same start-before-stop ordering', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _stopActiveKeycardModes()');
    final end = source.indexOf('Future<void> _cleanupKeycardPhase()', start);
    final cleanup = source.substring(start, end);

    expect(cleanup, contains('final pendingMasterStart'));
    expect(cleanup, contains('stopKeycardMasterAfterPendingStart('));
    expect(cleanup, contains('pendingStart: pendingMasterStart'));
    expect(cleanup, contains("'learn:master:stop'"));
  });

  test('window close waits until a pending master start has settled', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _handleWindowClose()');
    final end = source.indexOf('Future<void> _exitProcess()', start);
    final close = source.substring(start, end);

    expect(close, contains('_keycardMasterStartPending != null'));
    expect(close, contains('keycardMasterStartPendingClose'));
  });
}

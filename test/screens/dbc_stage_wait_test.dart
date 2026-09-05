import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/download_state.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  group('waiting on the background dashboard upload can end', () {
    test('it waits the way the downloads beside it do', () {
      final start = source.indexOf('if (_dbcStageInFlight) {');
      final wait = source.substring(
        start,
        source.indexOf('_setPhase(_phaseAfterMdbInstall);', start),
      );
      expect(wait, contains('await waitForDownloads('));
      expect(wait, contains('currentError: () => _dbcStageError'));
      expect(wait, isNot(contains('while (_dbcStageInFlight)')));
    });

    test('a throw before the upload own try still releases the waiter', () {
      final launch = source.substring(
        source.indexOf('void _beginBackgroundDbcUpload() {'),
        source.indexOf('Future<bool> _pingMdb({'),
      );
      expect(launch, contains('.catchError('));
      expect(launch, contains('_dbcStageError = e.toString()'));
      expect(launch, contains('_dbcStageInFlight = false'));
    });

    test('a new run starts with no error left over from the last', () {
      final launch = source.substring(
        source.indexOf('void _beginBackgroundDbcUpload() {'),
        source.indexOf('Future<bool> _pingMdb({'),
      );
      expect(launch, contains('_dbcStageError = null;'));
    });
  });

  group('the shared wait says which wait ran out', () {
    test('the subject reaches the timeout message', () async {
      await expectLater(
        waitForDownloads(
          isReady: () => false,
          currentError: () => null,
          isCancelled: () => false,
          subject: 'The dashboard upload',
          pollInterval: const Duration(milliseconds: 1),
          timeout: const Duration(milliseconds: 5),
        ),
        throwsA(
          isA<DownloadWaitFailure>().having(
            (e) => e.toString(),
            'message',
            contains('The dashboard upload did not finish'),
          ),
        ),
      );
    });

    test('an error on the watched thing ends the wait', () async {
      await expectLater(
        waitForDownloads(
          isReady: () => false,
          currentError: () => 'the board went away',
          isCancelled: () => false,
          pollInterval: const Duration(milliseconds: 1),
        ),
        throwsA(isA<DownloadWaitFailure>()),
      );
    });
  });
}

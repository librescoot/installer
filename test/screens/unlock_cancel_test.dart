import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  group('cancelling the unlock wait actually cancels', () {
    final cancel = source.substring(
      source.indexOf('final ok = await _waitForUnlock(l10n);'),
      source.indexOf('await _completeConnectionSetup(l10n);'),
    );

    test('it does not clear the flag the build guard starts on', () {
      expect(cancel, isNot(contains('_mdbConnectStarted = false')));
      expect(cancel, contains('_isProcessing = false'));
    });

    test('it says why the run stopped, in the right direction', () {
      expect(cancel, contains('_unlockCancelledFromRtd'));
      expect(cancel, contains('l10n.parkWaitCancelled'));
      expect(cancel, contains('l10n.unlockWaitCancelled'));
      for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_de.arb']) {
        final text = File(arb).readAsStringSync();
        for (final key in ['unlockWaitCancelled', 'parkWaitCancelled']) {
          expect(text, contains('"$key"'), reason: '$arb missing $key');
        }
      }
    });

    test('which side it was is captured before the overlay clears', () {
      final source =
          File('lib/screens/installer_screen.dart').readAsStringSync();
      final cancelHandler = source.substring(
        source.indexOf('void _userCancelUnlockWait() {'),
        source.indexOf('Future<DeviceInfo> _connectToMdbRetryingRoute('),
      );
      expect(cancelHandler,
          contains("_unlockCancelledFromRtd = _awaitingUnlockState == 'ready-to-drive'"));
    });

    test('the screen it lands on carries a retry', () {
      final build = source.substring(
        source.indexOf('Widget _buildMdbConnect(AppLocalizations l10n) {'),
        source.indexOf('void _retryMdbConnect() {'),
      );
      expect(build, contains('if (!_isProcessing)'));
      expect(build, contains('onPressed: _retryMdbConnect'));
    });

    test('the wait clears its own overlay on the way out', () {
      final wait = source.substring(
        source.indexOf('Future<bool> _waitForUnlock('),
        source.indexOf('void _userCancelUnlockWait() {'),
      );
      expect(wait, contains('setState(() => _awaitingUnlockState = null)'));
    });
  });
}

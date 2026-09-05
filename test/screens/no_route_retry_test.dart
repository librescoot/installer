import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();
  final schedule = source.substring(
    source.indexOf('void _scheduleNoRouteRetry() {'),
    source.indexOf('Widget _buildAwaitingUnlock'),
  );

  group('retrying a link the OS refuses is bounded', () {
    test('the retry keeps existing, because it is the only way to find out',
        () {
      expect(schedule, contains('Timer(const Duration(seconds: 5)'));
      expect(schedule, contains('unawaited(_autoConnectMdb())'));
    });

    test('but it stops after a window', () {
      expect(source, contains('_noRouteRetryWindow = Duration(minutes: 10)'));
      expect(schedule, contains('DateTime.now().difference(since) > _noRouteRetryWindow'));
    });

    test('the window is measured over the run, not restarted each pass', () {
      expect(schedule, contains('_noRouteRetryStart ??= DateTime.now()'));
    });

    test('a user-driven retry starts the window again', () {
      final retry = source.substring(
        source.indexOf('void _retryMdbConnect() {'),
        source.indexOf('ConnectFailure _describeConnectFailure('),
      );
      expect(retry, contains('_noRouteRetryStart = null'));
    });

    test('leaving the phase ends the run', () {
      expect(source, contains('if (leaving == InstallerPhase.mdbConnect && phase != leaving) {'));
    });
  });

  group('the panel the retry is waiting on stays on screen', () {
    test('an auto-retry does not clear the failure it is retrying', () {
      final connect = source.substring(
        source.indexOf('Future<void> _autoConnectMdb() async {'),
        source.indexOf('if (_device!.mode == DeviceMode.massStorage) {'),
      );
      expect(connect, contains('final keepFailure = _mdbConnectNoRoute;'));
      expect(connect, contains('if (!keepFailure) _connectFailure = null;'));
      expect(connect, contains('if (_connectFailure != null && !keepFailure) {'));
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  group('a claimed driver is shown wherever the run is', () {
    test('the panel is dispatched before the phase, not inside one', () {
      final dispatch = source.substring(
        source.indexOf('Widget _phaseContent(AppLocalizations l10n) {'),
        source.indexOf('InstallerPhase.welcome => _buildWelcome(l10n),'),
      );
      expect(dispatch, contains('final blocked = _driverBlocked;'));
      expect(dispatch, contains('return _buildDriverBlocked(l10n, blocked);'));
    });

    test('no phase builder renders it for itself any more', () {
      final connect = source.substring(
        source.indexOf('Widget _buildMdbConnect(AppLocalizations l10n) {'),
        source.indexOf('void _retryMdbConnect() {'),
      );
      expect(connect, isNot(contains('_buildDriverBlocked')));
    });

    test('the check still runs everywhere it did', () {
      expect(
        '_ensureDriverBinding()'.allMatches(source).length,
        greaterThanOrEqualTo(6),
      );
    });
  });

  group('the panel does not outlive the problem', () {
    final ensure = source.substring(
      source.indexOf('Future<bool> _ensureDriverBinding() async {'),
      source.indexOf('Widget _buildDriverBlocked('),
    );

    test('a binding that is fine again takes the panel down', () {
      expect(
        RegExp(r'setState\(\(\) => _driverBlocked = null\)').allMatches(ensure).length,
        2,
        reason: 'both the already-correct and the repaired path must clear it',
      );
    });

    test('a binding that is still wrong puts it back up', () {
      expect(ensure, contains('setState(() => _driverBlocked = result)'));
    });
  });

  group('recheck does what the phase it is shown over needs', () {
    final panel = source.substring(
      source.indexOf('Widget _buildDriverBlocked('),
      source.indexOf('Future<void> _autoConnectMdb() async {'),
    );

    test('it rechecks rather than assuming the driver came back', () {
      expect(panel, contains('await _ensureDriverBinding()'));
    });

    test('only the connect phase restarts an attempt', () {
      expect(panel, contains('_currentPhase == InstallerPhase.mdbConnect'));
      expect(panel, contains('_retryMdbConnect()'));
    });
  });
}

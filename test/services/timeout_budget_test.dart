import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/screens/installer_screen.dart';
import 'package:librescoot_installer/services/update_service.dart';

void main() {
  final screen = File('lib/screens/installer_screen.dart').readAsStringSync();

  group('budgets that a slow board or host must not fail', () {
    test('the keycard service gets more than three seconds to answer', () {
      expect(
        keycardAnswerBudget,
        greaterThanOrEqualTo(const Duration(seconds: 10)),
        reason: 'it answers in milliseconds when ready, and is coming up on a '
            'clean install when it is not',
      );
      expect(
        keycardReaderBudget,
        greaterThanOrEqualTo(const Duration(seconds: 5)),
      );
    });

    test('the keycard waits are budgets, not a small fixed number of polls', () {
      final command = screen.substring(
        screen.indexOf('Future<String?> _keycardCommand('),
        screen.indexOf('KeycardCapability? _keycardCapability;'),
      );
      for (final body in [
        command,
        screen.substring(
          screen.indexOf('Future<KeycardCapability> _keycardDetectCapability('),
          screen.indexOf('Future<int?> _keycardReadMasterCount('),
        ),
      ]) {
        expect(body, contains('keycardAnswerBudget'));
        expect(body, isNot(contains('i < 20')));
      }
      final reader = screen.substring(
        screen.indexOf('Future<KeycardCapability> _keycardCheckReader('),
        screen.indexOf('Future<KeycardCapability> _keycardDetectCapability('),
      );
      expect(reader, contains('keycardReaderBudget'));
      expect(reader, isNot(contains('i < 12')));
    });

    test('the installer update check no longer gives up at 8 s', () {
      expect(
        UpdateService().requestTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 20)),
        reason: 'a field log shows the old 8 s ceiling firing',
      );
    });

    test('the reconnect diagnostics wait for the host to answer', () {
      final diagnostics = screen.substring(
        screen.indexOf('Future<void> _surfaceReconnectDiagnostics('),
        screen.indexOf('String _installedVersionLabel('),
      );
      expect(diagnostics, isNot(contains('Duration(seconds: 8)')));
      expect(diagnostics, isNot(contains('Duration(seconds: 5)')));
    });
  });
}

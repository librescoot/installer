import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('confirmed preflight absence requires an acknowledged override', () {
    final start = source.indexOf('Future<bool> _confirmMainBatteryOverride(');
    final end = source.indexOf(
      '\n  Future<void> _deactivateMainBattery()',
      start,
    );
    final plan = source.substring(start, end);
    expect(plan, contains('barrierDismissible: false'));
    expect(plan, contains('CheckboxListTile('));
    expect(plan, contains('onPressed: acknowledged'));
    expect(plan, contains('_scooterHealth?.batteryPresent == false'));
    expect(
      plan,
      contains('!await _confirmMainBatteryOverride(atPreflight: true)'),
    );
  });

  test(
    'minimal MDB cannot report presence; physical confirmation is needed',
    () {
      final start = source.indexOf('Widget _buildCbbReconnect(');
      final end = source.indexOf('\n  Widget _buildDbcPrep(', start);
      final reconnect = source.substring(start, end);
      expect(reconnect, contains('_mdbStackMissing\n              ? false'));
      expect(reconnect, contains('l10n.confirmMainBatteryInstalled'));
      expect(reconnect, contains('l10n.mainBatteryUnverifiableHeading'));
      expect(
        reconnect,
        contains('_confirmMainBatteryOverride(atPreflight: false)'),
      );
      expect(reconnect, isNot(contains('lsc open')));
    },
  );
}

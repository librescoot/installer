import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('cable restoration depends on port occupancy, not DBC work', () {
    // Whether the DBC cable goes back is about the port: the laptop is in it
    // or not. What the plan decides is only the wording while the finish is
    // still running, since a plan with no dashboard work does not need the
    // cable to finish, only to reassemble.
    final start = source.indexOf('final state = finalScreenState(');
    final end = source.indexOf('\n    final confirmed', start);
    final call = source.substring(start, end);
    expect(call, contains('laptopOccupiesMdbUsb: _device != null'));
    expect(call, isNot(contains('needsHandoff')));
    expect(call, isNot(contains('needsDbcWork')));
  });

  test('the pending wording sends an MDB-only run to the cable', () {
    // Nothing on the board needs the laptop once the phases are queued: it
    // installs, reboots and unlocks on its own. Holding the owner at the
    // laptop "until it finishes" kept them from the one thing left to do.
    final start = source.indexOf('Widget _finishStatus(');
    final end = source.indexOf('\n    final color =', start);
    final body = source.substring(start, end);
    expect(body, contains('l10n.finishReconnectDbcNoDashboardWork'));
    expect(body, contains('_plan?.needsHandoff'));
  });

  test('restoration names disconnect, secured DBC cable, and cover', () {
    final start = source.indexOf('List<Widget> _finalSteps(');
    final end = source.indexOf('\n  Widget _buildGettingStarted(', start);
    final steps = source.substring(start, end);
    expect(steps, contains('disconnectUsbFromLaptopFinal'));
    expect(steps, contains('reconnectDbcUsbCable'));
    expect(steps, contains('closeSeatboxAndFootwell'));

    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    final de = File('lib/l10n/app_de.arb').readAsStringSync();
    expect(en, contains('Reconnect and secure DBC USB cable'));
    expect(de, contains('DBC-USB-Kabel anschließen und festschrauben'));
  });
}

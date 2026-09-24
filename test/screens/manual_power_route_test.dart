import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('viewing AUX instructions does not select the manual restart', () {
    final start = source.indexOf('Widget _buildScooterPrep(');
    final end = source.indexOf('\n  Widget _buildMdbBoot(', start);
    final prep = source.substring(start, end);
    final expansion = prep.substring(prep.indexOf('onExpansionChanged:'));
    expect(expansion, contains('_manualInstructionsSeen = true'));
    expect(
      expansion.substring(0, expansion.indexOf('children: [')),
      isNot(contains('_manualPowerCut = true')),
    );
    expect(expansion, contains('if (_manualInstructionsSeen)'));
    expect(expansion, contains('l10n.confirmManualPowerCut'));
    expect(expansion, contains('() => setState(() => _manualPowerCut = true)'));
    expect(prep, contains('() => setState(() => _manualPowerCut = false)'));
  });

  test('bootstrap battery step does not offer unavailable seatbox action', () {
    final start = source.indexOf('Widget _buildCbbReconnect(');
    final end = source.indexOf('\n  Widget _buildDbcPrep(', start);
    final reconnect = source.substring(start, end);
    expect(reconnect, isNot(contains('lsc open')));
    expect(reconnect, isNot(contains('l10n.openSeatboxButton')));
  });
}

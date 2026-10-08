import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['de', 'en']) {
    final copy =
        jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
            as Map<String, dynamic>;
    test('$locale public connection copy does not name SSH', () {
      for (final key in [
        'phaseMdbConnectDescription',
        'connectingSsh',
        'sshConnectionFailed',
        'reconnectingSsh',
        'sshReconnectionFailed',
        'substepConnectSsh',
      ]) {
        expect(copy[key], isNot(contains('SSH')), reason: key);
      }
    });
  }

  test('German connection and dashboard error wording', () {
    final copy =
        jsonDecode(File('lib/l10n/app_de.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(copy['connectingSsh'], 'Verbindung wird hergestellt…');
    expect(
      copy['dbcFlashErrorPrompt'],
      'Warnblinker geht an, Dashboard-LED blinkt rot',
    );
  });
}

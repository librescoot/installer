import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/journey_log.dart';

void main() {
  test('journey events are structured JSON with null fields preserved', () {
    final line = formatJourneyEvent('install_started', {
      'channel': 'stable',
      'region': null,
      'label': 'Weiter "trotzdem"',
    });

    expect(line, startsWith('Journey: '));
    expect(jsonDecode(line.substring('Journey: '.length)), {
      'event': 'install_started',
      'channel': 'stable',
      'region': null,
      'label': 'Weiter "trotzdem"',
    });
  });
}

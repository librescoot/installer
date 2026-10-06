import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/keycard_progress.dart';

void main() {
  test('stored cards survive missed learning events', () {
    expect(reconciledKeycardTotal(before: 0, observed: 0, stored: 2), 2);
    expect(reconciledKeycardTotal(before: 2, observed: 0, stored: 2), 2);
  });

  test('observed events survive a stale or missing stored count', () {
    expect(reconciledKeycardTotal(before: 1, observed: 2, stored: 1), 3);
    expect(reconciledKeycardTotal(before: 1, observed: 2, stored: null), 3);
    expect(reconciledKeycardTotal(before: 0, observed: 0, stored: 0), 0);
  });

  test('completion and review use the registered total, not only events', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    expect(
      source,
      contains(
        'final registered = (_keycardAuthorizedCount ?? 0) > 0 || sessionDelta > 0;',
      ),
    );
    expect(source, contains('onConnected: _keycardRefreshCounts'));
    expect(source, contains("await _keycardCommand('learn:stop')"));
    expect(
      source,
      isNot(contains('l10n.keycardLearnedAck(_keycardSessionTapCount)')),
    );
    expect(
      source,
      contains('l10n.keycardCardsTaught(_keycardAuthorizedCount ?? 0)'),
    );
  });
}

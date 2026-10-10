import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  String pending() => source.substring(
    source.indexOf('Widget _buildFinishPending('),
    source.indexOf('Widget _finishStatus('),
  );

  test('an unconfirmed finish gets a screen of its own, not a notice', () {
    final finish = source.substring(
      source.indexOf('Widget _buildFinish('),
      source.indexOf('Widget _buildFinishPending('),
    );
    expect(finish, contains('if (!confirmed) {'));
    expect(finish, contains('return _buildFinishPending(l10n, state);'));
  });

  test('reassembly and the first ride wait for the confirmation', () {
    final body = pending();
    expect(body, isNot(contains('_finalSteps(')));
    expect(body, isNot(contains('finalRide')));
    expect(body, isNot(contains('closeSeatboxAndFootwell')));
  });
}

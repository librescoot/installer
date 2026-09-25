import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  test('an observed unlock is not treated as a failed installation', () {
    final start = source.indexOf('Future<void> _finishAfterDbcSuccess()');
    final end = source.indexOf(
      '\n  Future<void> _startDbcVerification()',
      start,
    );
    final success = source.substring(start, end);

    expect(success, contains('_unlockObserved = true'));
    expect(success, isNot(contains('_dbcOutcome = _DbcOutcome.incomplete')));
    expect(success, contains('_setPhase(InstallerPhase.finish)'));
  });

  test('an observed unlock shows quick start before the pending screen', () {
    final start = source.indexOf('Widget _buildFinish(');
    final end = source.indexOf(
      '\n  Widget _buildConfigurationVerificationPending(',
      start,
    );
    final finish = source.substring(start, end);
    final quickStart = finish.indexOf(
      'if (unlockObserved || (confirmed && mdbOnly)) {',
    );
    final pending = finish.indexOf('if (!confirmed) {');

    expect(quickStart, greaterThan(-1));
    expect(quickStart, lessThan(pending));
    expect(
      finish.substring(quickStart, pending),
      contains('_buildGettingStarted(l10n)'),
    );
    expect(
      finish.substring(quickStart, pending),
      isNot(contains('_finishStatus(')),
    );
    expect(
      finish.substring(quickStart, pending),
      isNot(contains('_finalSteps(')),
    );
    expect(finish, contains('_unlockObserved && !_dbcOutcome.isIncomplete'));
    expect(
      finish,
      contains(
        '(deviceConfirmed || unlockObserved) && !configurationConfirmed',
      ),
    );
  });

  test('unverified completion keeps downloaded artifacts on close', () {
    final start = source.indexOf(
      'if (unlockObserved || (confirmed && mdbOnly)) {',
      source.indexOf('Widget _buildFinish('),
    );
    final end = source.indexOf('if (!confirmed) {', start);
    final quickStart = source.substring(start, end);

    expect(quickStart, contains('if (deviceConfirmed)'));
    expect(quickStart, contains('confirmed: deviceConfirmed'));
    expect(
      source,
      contains('if (confirmed && !keepDownloads) await _offerCleanup();'),
    );
  });
}

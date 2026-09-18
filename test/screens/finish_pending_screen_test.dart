import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();
  final de = File('lib/l10n/app_de.arb').readAsStringSync();
  final en = File('lib/l10n/app_en.arb').readAsStringSync();

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

  test('it says what happens, in order, including the unlock', () {
    final body = pending();
    for (final key in [
      'finishPendingStepsTitle',
      'finishPendingStep1',
      'finishPendingStep2',
      'finishPendingStep3',
      'finishPendingStep4',
    ]) {
      expect(body, contains('l10n.$key'));
    }
    expect(de, contains('"finishPendingStep4"'));
    expect(en, contains('"finishPendingStep4"'));
  });

  test('it names the finish signal and the thing that is not one', () {
    final body = pending();
    expect(body, contains('l10n.finishPendingDoneTitle'));
    expect(body, contains('l10n.finishPendingNotDoneTitle'));
    expect(body, contains('l10n.finishPendingNotDoneBody'));
    expect(
      body.indexOf('l10n.finishPendingDoneTitle'),
      lessThan(body.indexOf('l10n.finishPendingNotDoneBody')),
      reason: 'the dashboard switching on is explained after the real signal',
    );
  });

  test('the promise that the installer confirms it stays visible', () {
    expect(pending(), contains('l10n.finishPendingDoneTrail'));
    expect(de, contains('"finishPendingDoneTrail"'));
    expect(en, contains('"finishPendingDoneTrail"'));
  });

  test('reassembly and the first ride wait for the confirmation', () {
    final body = pending();
    expect(body, isNot(contains('_finalSteps(')));
    expect(body, isNot(contains('finalRide')));
    expect(body, isNot(contains('closeSeatboxAndFootwell')));
  });

  test('closing is offered but not as the emphasised action', () {
    final body = pending();
    expect(body, contains('l10n.closeInstaller'));
    expect(body, contains('side: ActionSide.back'));
    expect(
      body,
      isNot(contains('primary: true')),
      reason: 'a filled button here reads as the "done" the owner is after',
    );
  });

  test('every key the pending screen uses exists in both languages', () {
    final keys = RegExp(r'l10n\.(finishPending\w+)')
        .allMatches(pending())
        .map((m) => m.group(1)!)
        .toSet();
    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(de, contains('"$key"'), reason: 'de is missing $key');
      expect(en, contains('"$key"'), reason: 'en is missing $key');
    }
  });
}

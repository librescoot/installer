import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('existing cards do not make master setup a default step', () {
    final start = source.indexOf('Future<void> _onEnterKeycardSetup()');
    final end = source.indexOf('Future<void> _keycardAddKnownCards(', start);
    final entry = source.substring(start, end);
    expect(entry, contains('canMaster && (masters > 0 || cards > 0)'));
    expect(entry, contains('_keycardStage = _KeycardStage.alreadyConfigured;'));
    expect(entry, isNot(contains('cards > 0 && masters == 0')));
  });

  test('master setup remains an advanced action for existing cards', () {
    final start = source.indexOf(
      'List<PhaseAction> _keycardAlreadyConfiguredActions(',
    );
    final end = source.indexOf(
      '\n\n  Widget _buildKeycardAlreadyConfigured',
      start,
    );
    final actions = source.substring(start, end);
    expect(actions, contains('keycardAddMore'));
    expect(actions, contains('keycardCardsStageAddMasterButton'));
    expect(actions, isNot(contains('skipKeycardSetup')));
    expect(actions, contains('(_keycardMasterCount ?? 0) == 0'));

    final master = actions.indexOf('keycardCardsStageAddMasterButton');
    final addMore = actions.indexOf('keycardAddMore');
    expect(master, lessThan(addMore));
    final nextAction = actions.indexOf('PhaseAction(', master + 1);
    expect(
      actions.substring(master, nextAction),
      isNot(contains('primary: true')),
    );
  });

  test('adding another unlock card returns to the teaching stage', () {
    final start = source.indexOf('Future<void> _startKeycardLearning()');
    final end = source.indexOf('\n  Future<void> _stopKeycardLearning(', start);
    final learning = source.substring(start, end);
    expect(learning, contains('_keycardStage = _KeycardStage.cards;'));
  });
}

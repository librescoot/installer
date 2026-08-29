import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every phase puts its buttons in the action bar. The keycard review stage
/// stacked them in the body instead, so finishing the card step was the one
/// place in the flow where the buttons moved.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('the review stage has an action bar of its own', () {
    expect(source, contains('_KeycardStage.cardsReview => _keycardCardsReviewActions(l10n),'));
    expect(source, contains('List<PhaseAction> _keycardCardsReviewActions('));
  });

  test('the review body no longer carries buttons', () {
    final start = source.indexOf('Widget _buildKeycardCardsReview(');
    expect(start, isNot(-1));
    final end = source.indexOf('\n  ///', start);
    final body = source.substring(start, end);
    for (final widget in ['FilledButton', 'OutlinedButton', 'TextButton']) {
      expect(body, isNot(contains(widget)),
          reason: '$widget is still stacked in the body');
    }
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
    expect(actions, contains('(_keycardMasterCount ?? 0) == 0'));

    final master = actions.indexOf('keycardCardsStageAddMasterButton');
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

  test('review keeps continue primary and master setup secondary', () {
    final start = source.indexOf('List<PhaseAction> _keycardCardsReviewActions(');
    final end = source.indexOf('\n  }', start);
    final actions = source.substring(start, end);
    for (final label in [
      'keycardStartOverButton',
      'keycardCardsStageAddMasterButton',
      'keycardAddMore',
      'keycardCardsStageContinueButton',
    ]) {
      expect(actions, contains(label), reason: '$label was dropped');
    }

    final master = actions.indexOf('keycardCardsStageAddMasterButton');
    final continueAction = actions.indexOf('keycardCardsStageContinueButton');
    expect(actions.substring(master, continueAction),
        isNot(contains('primary: true')));
    expect(actions.substring(continueAction), contains('primary: true'));
  });

  test('both languages call master setup advanced', () {
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    final de = File('lib/l10n/app_de.arb').readAsStringSync();
    expect(en, contains('Add master card (advanced)'));
    expect(de, contains('Anlernkarte hinzufügen (fortgeschritten)'));
  });
}

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

  test('it still offers all four choices', () {
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
  });
}

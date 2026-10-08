import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/installer_sounds.dart';
import 'package:librescoot_installer/services/keycard_feedback.dart';

void main() {
  test('duplicate regular card plays the error cue during learning', () {
    expect(
      keycardLearningErrorCue(
        'card-duplicate:11223344',
        learningCards: true,
        learningMaster: false,
      ),
      InstallerCue.error,
    );
  });

  for (final payload in [
    'rejected:already-authorized:11223344',
    'error:save-failed:11223344',
  ]) {
    test('$payload plays an error cue for an owned master session', () {
      expect(
        keycardLearningErrorCue(
          payload,
          learningCards: false,
          learningMaster: true,
        ),
        InstallerCue.error,
      );
    });
  }

  test('save failure during regular learning plays the error cue', () {
    expect(
      keycardLearningErrorCue(
        'error:save-failed:11223344',
        learningCards: true,
        learningMaster: false,
      ),
      InstallerCue.error,
    );
  });

  for (final payload in [
    'card-duplicate:11223344',
    'rejected:already-authorized:11223344',
    'error:save-failed:11223344',
    'card-learned:11223344',
    'master-learned:11223344',
    'reset',
  ]) {
    test('$payload has no error cue outside an active learning session', () {
      expect(
        keycardLearningErrorCue(
          payload,
          learningCards: false,
          learningMaster: false,
        ),
        isNull,
      );
    });
  }

  test('successful events do not generate error cues', () {
    for (final payload in [
      'card-learned:11223344',
      'master-learned:11223344',
    ]) {
      expect(
        keycardLearningErrorCue(
          payload,
          learningCards: true,
          learningMaster: true,
        ),
        isNull,
      );
    }
  });

  test('master rejection is not regular card feedback', () {
    expect(
      keycardLearningErrorCue(
        'rejected:already-authorized:11223344',
        learningCards: true,
        learningMaster: false,
      ),
      isNull,
    );
  });

  test('UI guards feedback by phase and master ownership', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final handler = source.substring(
      source.indexOf('void _handleKeycardEvent('),
      source.indexOf('Future<void> _keycardSimulateMasterEvent('),
    );
    expect(handler, contains('_windowClosing'));
    expect(handler, contains('_currentPhase != InstallerPhase.keycardSetup'));
    expect(handler, contains('keycardLearningErrorCue('));
    expect(handler, contains('ownerGeneration: _keycardMasterOwnerGeneration'));
    expect(handler, contains('_sounds.play(errorCue)'));
    final duplicate = handler.substring(
      handler.indexOf("payload.startsWith('card-duplicate:')"),
      handler.indexOf("payload.startsWith('master-learned:')"),
    );
    expect(duplicate, isNot(contains('_keycardSessionTapCount')));
    expect(duplicate, isNot(contains('InstallerCue.confirmed')));
  });
}

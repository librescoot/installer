import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/l10n/app_localizations_en.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();
  final start = source.indexOf('Widget _buildFinish(');
  final end = source.indexOf(
    'Widget _buildConfigurationVerificationPending(',
    start,
  );
  final finish = source.substring(start, end);

  test('MDB-only work uses outcome cards instead of the verbose wait', () {
    expect(finish, contains('_plan != null && !_plan!.needsHandoff'));
    expect(finish, contains('if (mdbOnly && !_dbcOutcome.isIncomplete)'));
    expect(finish, contains('return _buildMdbOnlyFinishPending(l10n, state)'));
    expect(finish, contains('DbcFlashOutcomes('));
    expect(finish, contains('l10n.mdbFinishReconnectCable'));
    expect(finish, contains('l10n.mdbFinishKeepCable'));
    expect(finish, contains('l10n.mdbFinishWaitHint'));
    expect(finish, contains('successDescription: l10n.mdbFinishSuccessPrompt'));
  });

  test('success opens quick start without a completion record', () {
    expect(
      finish,
      contains('onSuccess: () => setState(() => _unlockObserved = true)'),
    );
    expect(finish, contains('unlockObserved || (confirmed && mdbOnly)'));
    expect(finish, contains('child: _buildGettingStarted(l10n)'));
    expect(finish, contains('confirmed: deviceConfirmed'));
  });

  test('error uses MDB instructions rather than DBC retry controls', () {
    expect(
      finish,
      contains('onError: () => setState(() => _mdbFinishErrorObserved = true)'),
    );
    expect(
      finish,
      contains(
        'if (_mdbFinishErrorObserved) return _buildMdbOnlyFinishFailure(l10n)',
      ),
    );
    final failure = finish.substring(
      finish.indexOf('Widget _buildMdbOnlyFinishFailure('),
    );
    expect(failure, contains('l10n.mdbFinishFailureBody'));
    expect(failure, contains('_retryFinishCompletion()'));
    expect(failure, isNot(contains('_returnToDbcPrep()')));
  });

  test('both languages name the observable signals', () {
    expect(
      AppLocalizationsDe().mdbFinishWaitHint,
      'Lass den Roller eingeschaltet. Klicke erst bei einem Signal auf das passende Bild.',
    );
    expect(
      AppLocalizationsDe().mdbFinishSuccessPrompt,
      'Der Roller hat sich entsperrt: Das Standlicht und das Rücklicht leuchten',
    );
    expect(
      AppLocalizationsEn().mdbFinishSuccessPrompt,
      contains('front position light and rear light'),
    );
    expect(AppLocalizationsDe().mdbFinishFailureBody, contains('DBC-LED'));
    expect(AppLocalizationsEn().mdbFinishFailureBody, contains('DBC LED'));
  });
}

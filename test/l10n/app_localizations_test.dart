import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';

void main() {
  test('handoff actions name the destination page', () async {
    final german = await AppLocalizations.delegate.load(const Locale('de'));
    final english = await AppLocalizations.delegate.load(const Locale('en'));

    expect(german.handoffShowStatus, 'Weiter: Status & Signale');
    expect(english.handoffShowStatus, 'Continue: Status & Signals');
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/l10n/phase_l10n.dart';
import 'package:librescoot_installer/models/installer_phase.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations de;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    de = await AppLocalizations.delegate.load(const Locale('de'));
  });

  test('the board steps say what they do: prepare, then install', () {
    // Writing the stage-0 image over UMS is preparation; the artifact that
    // follows is the install. Calling the first one "flash" put the same word
    // on the two halves and made the second look like a repeat of the first.
    expect(MajorStep.mdbFlash.localizedTitle(en), 'Prepare MDB');
    expect(MajorStep.mdbInstall.localizedTitle(en), 'Install MDB');
    expect(MajorStep.dbcFlash.localizedTitle(en), 'Install DBC');
    expect(MajorStep.mdbFlash.localizedTitle(de), 'MDB vorbereiten');
    expect(MajorStep.mdbInstall.localizedTitle(de), 'MDB installieren');
    expect(MajorStep.dbcFlash.localizedTitle(de), 'DBC installieren');
  });

  test('an upgrade retitles the install steps, in both languages', () {
    expect(
        MajorStep.mdbInstall.localizedTitle(en, upgrade: true), 'Upgrade MDB');
    expect(MajorStep.dbcFlash.localizedTitle(en, upgrade: true), 'Upgrade DBC');
    expect(MajorStep.mdbInstall.localizedTitle(de, upgrade: true),
        'MDB aktualisieren');
    expect(
        MajorStep.dbcFlash.localizedTitle(de, upgrade: true), 'DBC aktualisieren');
  });

  test('the prepare step keeps its name on an upgrade', () {
    // An upgrade skips it, and the sidebar appends "(skipped)". Retitling it
    // to the upgrade wording puts that suffix on a step named exactly like
    // mdbInstall, which is the step doing the upgrade, so the sidebar reads
    // as though the upgrade itself had been skipped.
    expect(MajorStep.mdbFlash.localizedTitle(en, upgrade: true), 'Prepare MDB');
    expect(
        MajorStep.mdbFlash.localizedTitle(de, upgrade: true), 'MDB vorbereiten');
    expect(
      MajorStep.mdbFlash.localizedTitle(de, upgrade: true),
      isNot(MajorStep.mdbInstall.localizedTitle(de, upgrade: true)),
      reason: 'two steps in the same sidebar must not share a title',
    );
  });

  test('the pairing step is titled in both languages', () {
    expect(MajorStep.pairing.localizedTitle(en), 'Pairing & Cards');
    expect(MajorStep.pairing.localizedTitle(de), 'Koppeln & Karten');
  });

  test('the steps that are not per-board ignore the flag', () {
    for (final step in [
      MajorStep.prepare,
      MajorStep.connect,
      MajorStep.pairing,
      MajorStep.finish
    ]) {
      expect(step.localizedTitle(en, upgrade: true), step.localizedTitle(en));
    }
  });
}

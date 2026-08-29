import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String finish;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Widget _buildFinish(');
    final end = source.indexOf(
      '\n  /// Say only what the laptop can prove.',
      start,
    );
    expect(start, greaterThan(-1));
    expect(end, greaterThan(start));
    finish = source.substring(start, end);
  });

  test('keep-downloads is a left-side finish action', () {
    expect(finish, contains('l10n.finishKeepDownloadedFiles'));
    final keep = finish.indexOf('l10n.finishKeepDownloadedFiles');
    final next = finish.indexOf('PhaseAction(', keep);
    expect(finish.substring(keep, next), contains('side: ActionSide.back'));
    expect(finish.substring(keep, next), contains('keepDownloads: true'));
    expect(finish, isNot(contains('CheckboxListTile')));
  });

  test('unfinished runs do not show a confirmed-success heading', () {
    expect(
      finish,
      contains('confirmed ? l10n.welcomeToLibrescoot : l10n.finishStatusTitle'),
    );
    expect(source, contains('l10n.finishPendingHeading'));
    expect(source, contains('l10n.finishCompleteHeading'));
    expect(source, contains('l10n.finishSkippedHeading'));
  });

  test('normal close deletes confirmed downloads before cleanup', () {
    expect(
      source,
      contains('if (confirmed && !keepDownloads) await _offerCleanup();'),
    );
    expect(source, contains('await _cleanupBeforeClose();'));
    expect(finish, contains('keepDownloads: false'));
  });
}

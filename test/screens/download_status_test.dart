import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The status line is the only thing on the setup screens that says what the
/// app is doing. It said "resolving releases" for the whole download, because
/// the resolve finishes in milliseconds against a cached manifest and nothing
/// replaced its status afterwards. A user on a slow link watched that label
/// for minutes while several hundred megabytes came down behind it.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  String bodyOf(String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature not found');
    final end = source.indexOf('\n  void ', start + 1);
    return source.substring(start, end == -1 ? source.length : end);
  }

  test('the download sets a status of its own', () {
    final body = bodyOf('void _downloadInBackground(');
    expect(body, contains('noticesWaitingForDownloads'),
        reason: 'without this the sidebar keeps the resolve step\'s label for '
            'the whole transfer');
    // The same string the Continue button uses, so the two cannot disagree
    // about what the app is doing on one screen.
    final button = source.contains('l10n.noticesWaitingForDownloads');
    expect(button, isTrue);
  });

  test('it says so when the downloads are done', () {
    final body = bodyOf('void _downloadInBackground(');
    expect(body, contains('downloadsFinished'),
        reason: 'the last status a user sees should not be a stale one');
  });

  test('building the queue is named separately', () {
    // Covers the tile repo round trips (when maps are wanted) plus
    // assembling the queue itself. It ran under the previous step's label,
    // which is why "resolving releases" looked slow for the whole stretch.
    expect(source, contains('l10n.preparingDownloads'));
    final at = source.indexOf('l10n.preparingDownloads');
    final build = source.indexOf('buildDownloadQueue(', at);
    expect(build, greaterThan(at),
        reason: 'the status has to be set before the call it describes');
  });

  test('the queue status is set regardless of whether maps are wanted', () {
    expect(source, contains('_setStatus(l10n.preparingDownloads)'),
        reason: 'building the queue takes time either way, so both runs '
            'need an honest status for it');
    expect(source, isNot(contains('if (wantsOfflineMaps) _setStatus(l10n.preparingDownloads)')));
  });
}

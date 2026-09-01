import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('channel, region, and both map toggles invalidate the queue', () {
    expect(RegExp(r'_updateDownloadSelection\(').allMatches(source).length, 5);
    expect(source, contains('_downloadCancellationToken?.cancel();'));
    expect(source, contains('_downloadState.items = [];'));
    expect(source, contains('_downloadState.releaseTag = null;'));
  });

  test('stale resolve, progress, completion, and errors check ownership', () {
    expect(
      RegExp(r'_ownsDownloadGeneration\(').allMatches(source).length,
      greaterThanOrEqualTo(8),
    );
    expect(source, contains('} on DownloadCancelled {'));
  });

  test('DBC staging passes tiles only when the current plan requests them', () {
    expect(
      source,
      contains('osmTilesLocalPath: installTiles ? osmItem?.localPath : null'),
    );
    expect(source, contains('installTiles ? valhallaItem?.localPath : null'));
    expect(
      source,
      contains('region: installTiles ? _downloadState.selectedRegion : null'),
    );
  });
}

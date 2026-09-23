import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('download choices on welcome and plan invalidate the queue', () {
    expect(RegExp(r'_updateDownloadSelection\(').allMatches(source).length, 7);
    expect(source, contains('_downloadCancellationToken?.cancel();'));
    expect(source, contains('_downloadState.items = [];'));
    expect(source, contains('_downloadState.releaseTag = null;'));
  });

  test('changing maps at the plan requeues downloads without repeating health check', () {
    final start = source.indexOf('Future<void> _changePlanOfflineMaps(');
    final end = source.indexOf('Widget _buildInstallPlan(', start);
    expect(start, isNonNegative);
    final handler = source.substring(start, end);
    expect(handler, contains('_updateDownloadSelection('));
    expect(handler, contains('unawaited(_kickoffDownloads())'));
    expect(handler, contains('_plan = _plan!.withTiles('));
    expect(handler, isNot(contains('_setPhase(')));
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

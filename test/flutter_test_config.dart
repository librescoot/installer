import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/download_service.dart';

/// Runs once per test suite, before any test in it.
///
/// Point the download cache at a throwaway directory. Tests serve their
/// manifests from a MockClient, and `_fetchLatest` writes whatever it fetched
/// to `latest.json` in the cache directory; without this the fixture lands in
/// the user's real cache, where the next launch of the installer reads it back
/// as the current release list and shows the fixture's versions instead of the
/// published ones.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final cache =
      await Directory.systemTemp.createTemp('librescoot-installer-test-cache-');
  DownloadService.cacheDirOverride = cache;
  tearDownAll(() async {
    if (await cache.exists()) await cache.delete(recursive: true);
  });
  await testMain();
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/download_state.dart';
import '../models/region.dart';

class DownloadService {
  static const _osmTilesRepo = 'librescoot/osm-tiles';
  static const _valhallaTilesRepo = 'librescoot/valhalla-tiles';
  static const _githubApi = 'https://api.github.com';
  static const _latestManifestUrl =
      'https://downloads.librescoot.org/releases/latest.json';

  final http.Client _client;
  Map<String, dynamic>? _cachedLatest;

  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch the combined latest-per-channel manifest from
  /// downloads.librescoot.org. One round trip yields the current pointer
  /// for every firmware channel.
  ///
  /// Resolution order:
  ///   1. In-memory cache (set by an earlier call this session).
  ///   2. On-disk cache, if less than an hour old.
  ///   3. Network with three retries (0s, 2s, 5s backoff). Fresh installs
  ///      on Windows / macOS see TLS handshake failures on the first try
  ///      because the OS hasn't lazy-fetched intermediates yet, so a
  ///      single attempt isn't enough.
  ///   4. Stale on-disk cache (any age) as a fallback.
  ///   5. Bundled snapshot baked into the app at build time
  ///      (`assets/latest.json.fallback`) as a final fallback so the
  ///      installer can at least show channel choices when offline.
  Future<Map<String, dynamic>> _fetchLatest() async {
    if (_cachedLatest != null) return _cachedLatest!;

    final cacheDir = await getCacheDir();
    final cacheFile = File(p.join(cacheDir.path, 'latest.json'));
    if (await cacheFile.exists()) {
      final age = DateTime.now().difference(await cacheFile.lastModified());
      if (age.inHours < 1) {
        _cachedLatest =
            jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
        return _cachedLatest!;
      }
    }

    const delays = [Duration.zero, Duration(seconds: 2), Duration(seconds: 5)];
    for (var attempt = 0; attempt < delays.length; attempt++) {
      if (delays[attempt] > Duration.zero) {
        await Future.delayed(delays[attempt]);
      }
      try {
        final response = await _client
            .get(Uri.parse(_latestManifestUrl))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          await cacheFile.writeAsString(response.body);
          _cachedLatest = jsonDecode(response.body) as Map<String, dynamic>;
          return _cachedLatest!;
        }
        debugPrint('latest.json fetch HTTP ${response.statusCode} '
            '(attempt ${attempt + 1}/${delays.length})');
      } catch (e) {
        debugPrint('latest.json fetch failed '
            '(attempt ${attempt + 1}/${delays.length}): $e');
      }
    }

    if (await cacheFile.exists()) {
      debugPrint('latest.json: network unavailable, using stale on-disk cache');
      _cachedLatest =
          jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
      return _cachedLatest!;
    }

    try {
      debugPrint('latest.json: using bundled fallback snapshot');
      final bundled = await rootBundle.loadString('assets/latest.json.fallback');
      _cachedLatest = jsonDecode(bundled) as Map<String, dynamic>;
      return _cachedLatest!;
    } catch (e) {
      debugPrint('latest.json: no bundled fallback: $e');
    }

    throw Exception('No release manifest available');
  }

  /// Get platform-appropriate cache directory
  static Future<Directory> getCacheDir() async {
    final String base;
    if (Platform.isWindows) {
      base = p.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Librescoot', 'Installer', 'cache');
    } else {
      base = p.join(Platform.environment['HOME'] ?? '', '.cache', 'librescoot-installer');
    }
    final dir = Directory(base);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Determine which channels have releases available. Returns a map of
  /// channel -> (tag, publishedAt date string) for non-null channel entries.
  Future<Map<DownloadChannel, ({String tag, String date})>> fetchAvailableChannels() async {
    final latest = await _fetchLatest();
    final result = <DownloadChannel, ({String tag, String date})>{};
    for (final channel in DownloadChannel.values) {
      final entry = latest[channel.name];
      if (entry is! Map<String, dynamic>) continue;
      final tag = entry['tag_name'] as String;
      final published = entry['published_at'] as String? ?? '';
      final date = published.length >= 10 ? published.substring(0, 10) : published;
      result[channel] = (tag: tag, date: date);
    }
    return result;
  }

  /// Resolve the latest release for a channel. Returns (tag, assets) or throws.
  Future<({String tag, List<Map<String, dynamic>> assets})> resolveRelease(
    DownloadChannel channel,
  ) async {
    final latest = await _fetchLatest();
    final entry = latest[channel.name];
    if (entry is! Map<String, dynamic>) {
      throw Exception('No release found for channel: ${channel.name}');
    }
    final tag = entry['tag_name'] as String;
    final assets = (entry['assets'] as List).cast<Map<String, dynamic>>();
    return (tag: tag, assets: assets);
  }

  /// Resolve tile release assets for a repo, with disk caching.
  Future<List<Map<String, dynamic>>> resolveTileAssets(
    String repo,
    String assetPrefix,
  ) async {
    final cacheDir = await getCacheDir();
    final cacheKey = repo.replaceAll('/', '_');
    final cacheFile = File(p.join(cacheDir.path, '$cacheKey-latest.json'));

    // Try disk cache first
    if (await cacheFile.exists()) {
      final age = DateTime.now().difference(await cacheFile.lastModified());
      if (age.inHours < 1) {
        final release = jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
        return (release['assets'] as List).cast<Map<String, dynamic>>();
      }
    }

    try {
      final response = await _client.get(
        Uri.parse('$_githubApi/repos/$repo/releases/tags/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (response.statusCode != 200) {
        // Fall back to stale cache
        if (await cacheFile.exists()) {
          final release = jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
          return (release['assets'] as List).cast<Map<String, dynamic>>();
        }
        throw Exception('GitHub API error for $repo: ${response.statusCode}');
      }
      await cacheFile.writeAsString(response.body);
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      return (release['assets'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // Fall back to stale cache on any network error
      if (await cacheFile.exists()) {
        final release = jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
        return (release['assets'] as List).cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  /// Build the full download queue based on channel, region, and offline preference.
  Future<List<DownloadItem>> buildDownloadQueue({
    required DownloadChannel channel,
    Region? region,
    required bool wantsOfflineMaps,
  }) async {
    final items = <DownloadItem>[];
    final cacheDir = await getCacheDir();

    // Firmware images and bmap files
    final release = await resolveRelease(channel);
    for (final asset in release.assets) {
      final name = asset['name'] as String;
      if (!name.contains('unu-')) continue;

      final bool isBmap = name.endsWith('.sdimg.bmap');
      final bool isFirmware = name.endsWith('.sdimg.gz');
      if (!isFirmware && !isBmap) continue;

      final DownloadItemType type;
      if (name.contains('unu-mdb-')) {
        type = isBmap ? DownloadItemType.mdbBmap : DownloadItemType.mdbFirmware;
      } else if (name.contains('unu-dbc-')) {
        type = isBmap ? DownloadItemType.dbcBmap : DownloadItemType.dbcFirmware;
      } else {
        continue;
      }

      final cached = File(p.join(cacheDir.path, name));
      final expectedSize = asset['size'] as int;

      final item = DownloadItem(
        type: type,
        url: asset['url'] as String,
        filename: name,
        expectedSize: expectedSize,
      );

      if (await cached.exists() && await cached.length() == expectedSize) {
        item.localPath = cached.path;
        item.bytesDownloaded = expectedSize;
      }

      items.add(item);
    }

    // Tile downloads
    if (wantsOfflineMaps && region != null) {
      // OSM display tiles
      final osmAssets = await resolveTileAssets(_osmTilesRepo, 'tiles_');
      for (final asset in osmAssets) {
        final name = asset['name'] as String;
        if (name != region.osmTilesFilename) continue;
        final cached = File(p.join(cacheDir.path, name));
        final expectedSize = asset['size'] as int;
        final item = DownloadItem(
          type: DownloadItemType.osmTiles,
          url: asset['browser_download_url'] as String,
          filename: name,
          expectedSize: expectedSize,
        );
        if (await cached.exists() && await cached.length() == expectedSize) {
          item.localPath = cached.path;
          item.bytesDownloaded = expectedSize;
        }
        items.add(item);
      }

      // Valhalla routing tiles
      final valhallaAssets = await resolveTileAssets(_valhallaTilesRepo, 'valhalla_tiles_');
      for (final asset in valhallaAssets) {
        final name = asset['name'] as String;
        if (name != region.valhallaTilesFilename) continue;
        final cached = File(p.join(cacheDir.path, name));
        final expectedSize = asset['size'] as int;
        final item = DownloadItem(
          type: DownloadItemType.valhallaTiles,
          url: asset['browser_download_url'] as String,
          filename: name,
          expectedSize: expectedSize,
        );
        if (await cached.exists() && await cached.length() == expectedSize) {
          item.localPath = cached.path;
          item.bytesDownloaded = expectedSize;
        }
        items.add(item);
      }
    }

    // Sort by enum index so downloads proceed in priority order:
    // MDB firmware -> DBC firmware -> OSM tiles -> routing tiles
    items.sort((a, b) => a.type.index.compareTo(b.type.index));
    return items;
  }

  /// Download a single item with progress callback.
  Future<void> downloadItem(
    DownloadItem item, {
    void Function(int bytesDownloaded, int totalBytes)? onProgress,
  }) async {
    if (item.isComplete) return;

    final cacheDir = await getCacheDir();
    final targetFile = File(p.join(cacheDir.path, item.filename));
    final partFile = File('${targetFile.path}.part');

    final request = http.Request('GET', Uri.parse(item.url));
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Download failed: HTTP ${response.statusCode}');
    }

    final sink = partFile.openWrite();
    var downloaded = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloaded += chunk.length;
      item.bytesDownloaded = downloaded;
      onProgress?.call(downloaded, item.expectedSize);
    }
    await sink.close();

    // Verify size
    if (await partFile.length() != item.expectedSize) {
      await partFile.delete();
      throw Exception('Download size mismatch for ${item.filename}');
    }

    await partFile.rename(targetFile.path);
    item.localPath = targetFile.path;

    // Clean up old versions of the same type in the cache
    await _cleanupOldVersions(cacheDir, item);
  }

  /// Delete older cached files of the same family/channel as the new item.
  /// Files of the *same* family but a *different* channel flavour are kept
  /// (e.g. downloading stable v1.0.1 must not nuke a cached nightly image).
  Future<void> _cleanupOldVersions(Directory cacheDir, DownloadItem item) async {
    final name = item.filename;
    final suffix = name.endsWith('.bmap') ? '.bmap' : p.extension(name);
    final escSuffix = RegExp.escape(suffix);

    RegExp? cleanupPattern;

    final channelMatch =
        RegExp(r'^(.*?-)(nightly|testing|stable)-').firstMatch(name);
    final versionMatch = RegExp(r'^(.*?)-v\d').firstMatch(name);

    if (channelMatch != null) {
      // librescoot-unu-mdb-nightly-20260404T112344.sdimg.gz
      //   -> match librescoot-unu-mdb-nightly-*.sdimg.gz only
      final family = RegExp.escape(channelMatch.group(1)!);
      final channel = channelMatch.group(2)!;
      cleanupPattern = RegExp('^$family$channel-.*$escSuffix\$');
    } else if (versionMatch != null) {
      // librescoot-unu-mdb-v1.0.0.sdimg.gz
      //   -> match librescoot-unu-mdb-vX… only (NOT …-nightly-… etc)
      final family = RegExp.escape(versionMatch.group(1)!);
      cleanupPattern = RegExp('^$family-v\\d.*$escSuffix\$');
    } else {
      // Tiles etc: use everything before the first digit/date
      final tileMatch = RegExp(r'^([a-z_]+)').firstMatch(name);
      final prefix =
          RegExp.escape(tileMatch?.group(1) ?? name.substring(0, 5));
      cleanupPattern = RegExp('^$prefix.*$escSuffix\$');
    }

    try {
      await for (final entity in cacheDir.list()) {
        if (entity is! File) continue;
        final candidate = p.basename(entity.path);
        if (candidate == name) continue;
        if (cleanupPattern.hasMatch(candidate)) {
          debugPrint('Cache cleanup: deleting old $candidate');
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('Cache cleanup error: $e');
    }
  }

  /// Download all items in order, calling onProgress for each.
  Future<void> downloadAll(
    List<DownloadItem> items, {
    void Function(DownloadItem item, int bytesDownloaded, int totalBytes)? onProgress,
  }) async {
    for (final item in items) {
      if (item.isComplete) continue;
      await downloadItem(item, onProgress: (bytes, total) {
        onProgress?.call(item, bytes, total);
      });
    }
  }

  /// Delete all cached files for the given items.
  Future<int> deleteCache(List<DownloadItem> items) async {
    var totalFreed = 0;
    for (final item in items) {
      if (item.localPath != null) {
        final file = File(item.localPath!);
        if (await file.exists()) {
          totalFreed += await file.length();
          await file.delete();
        }
      }
    }
    return totalFreed;
  }

  void dispose() => _client.close();
}

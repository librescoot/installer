import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/download_state.dart';
import '../models/region.dart';

class DownloadService {
  static const _firmwareRepo = 'librescoot/librescoot';
  static const _osmTilesRepo = 'librescoot/osm-tiles';
  static const _valhallaTilesRepo = 'librescoot/valhalla-tiles';
  static const _githubApi = 'https://api.github.com';

  final http.Client _client;
  List<dynamic>? _cachedReleases;

  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch releases from GitHub, with in-memory and on-disk caching.
  Future<List<dynamic>> _fetchReleases() async {
    if (_cachedReleases != null) return _cachedReleases!;

    // Try local cache file first (avoids rate limits during development)
    final cacheDir = await getCacheDir();
    final cacheFile = File(p.join(cacheDir.path, 'releases.json'));
    if (await cacheFile.exists()) {
      final age = DateTime.now().difference(await cacheFile.lastModified());
      if (age.inHours < 1) {
        _cachedReleases = jsonDecode(await cacheFile.readAsString()) as List;
        return _cachedReleases!;
      }
    }

    final response = await _client.get(
      Uri.parse('$_githubApi/repos/$_firmwareRepo/releases'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (response.statusCode != 200) {
      // Fall back to stale cache if API fails
      if (await cacheFile.exists()) {
        _cachedReleases = jsonDecode(await cacheFile.readAsString()) as List;
        return _cachedReleases!;
      }
      throw Exception('GitHub API: ${response.statusCode}');
    }

    // Save to disk cache
    await cacheFile.writeAsString(response.body);
    _cachedReleases = jsonDecode(response.body) as List;
    return _cachedReleases!;
  }

  /// Get platform-appropriate cache directory
  static Future<Directory> getCacheDir() async {
    final String base;
    if (Platform.isWindows) {
      base = p.join(Platform.environment['LOCALAPPDATA'] ?? '', 'LibreScoot', 'Installer', 'cache');
    } else {
      base = p.join(Platform.environment['HOME'] ?? '', '.cache', 'librescoot-installer');
    }
    final dir = Directory(base);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Fetch all releases and determine which channels have releases available.
  /// Returns a map of channel -> (tag, publishedAt date string).
  Future<Map<DownloadChannel, ({String tag, String date})>> fetchAvailableChannels() async {
    final releases = await _fetchReleases();
    final result = <DownloadChannel, ({String tag, String date})>{};

    for (final channel in DownloadChannel.values) {
      for (final release in releases) {
        final tag = release['tag_name'] as String;
        if (tag.startsWith('${channel.name}-')) {
          final published = release['published_at'] as String? ?? '';
          final date = published.length >= 10 ? published.substring(0, 10) : published;
          result[channel] = (tag: tag, date: date);
          break;
        }
      }
    }

    return result;
  }

  /// Resolve the latest release for a channel. Returns (tag, assets) or throws.
  Future<({String tag, List<Map<String, dynamic>> assets})> resolveRelease(
    DownloadChannel channel,
  ) async {
    final releases = await _fetchReleases();
    final channelName = channel.name;

    // For stable channel, try stable first, fall back to testing
    final channelsToTry = channel == DownloadChannel.stable
        ? ['stable', 'testing']
        : [channelName];

    for (final ch in channelsToTry) {
      for (final release in releases) {
        final tag = release['tag_name'] as String;
        if (tag.startsWith('$ch-')) {
          final assets = (release['assets'] as List).cast<Map<String, dynamic>>();
          return (tag: tag, assets: assets);
        }
      }
    }
    throw Exception('No release found for channel: $channelName');
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

  /// Delete older cached files of the same type and channel
  Future<void> _cleanupOldVersions(Directory cacheDir, DownloadItem item) async {
    // Extract channel-aware prefix from filename
    // e.g. "librescoot-unu-mdb-nightly-20260404T112344.sdimg.gz" -> "librescoot-unu-mdb-nightly-"
    // e.g. "tiles_berlin_brandenburg.mbtiles" -> "tiles_" (no channel)
    final name = item.filename;
    final String prefix;
    final channelMatch = RegExp(r'^(.*?-(?:nightly|testing|stable)-)').firstMatch(name);
    if (channelMatch != null) {
      prefix = channelMatch.group(1)!;
    } else {
      // Tiles etc — use everything before the first digit/date
      final tileMatch = RegExp(r'^([a-z_]+)').firstMatch(name);
      prefix = tileMatch?.group(1) ?? name.substring(0, 5);
    }

    final suffix = name.endsWith('.bmap') ? '.bmap' : p.extension(name);

    try {
      await for (final entity in cacheDir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith(prefix) && name.endsWith(suffix) && name != item.filename) {
          debugPrint('Cache cleanup: deleting old $name');
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

import 'dart:convert';
import 'dart:io';

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

  /// Fetch releases from GitHub, caching the result to avoid rate limits.
  Future<List<dynamic>> _fetchReleases() async {
    if (_cachedReleases != null) return _cachedReleases!;
    final response = await _client.get(
      Uri.parse('$_githubApi/repos/$_firmwareRepo/releases'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API: ${response.statusCode}');
    }
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

  /// Resolve tile release assets for a repo.
  Future<List<Map<String, dynamic>>> resolveTileAssets(
    String repo,
    String assetPrefix,
  ) async {
    final response = await _client.get(
      Uri.parse('$_githubApi/repos/$repo/releases/tags/latest'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API error for $repo: ${response.statusCode}');
    }
    final release = jsonDecode(response.body) as Map<String, dynamic>;
    return (release['assets'] as List).cast<Map<String, dynamic>>();
  }

  /// Build the full download queue based on channel, region, and offline preference.
  Future<List<DownloadItem>> buildDownloadQueue({
    required DownloadChannel channel,
    Region? region,
    required bool wantsOfflineMaps,
  }) async {
    final items = <DownloadItem>[];
    final cacheDir = await getCacheDir();

    // Firmware images
    final release = await resolveRelease(channel);
    for (final asset in release.assets) {
      final name = asset['name'] as String;
      if (!name.contains('unu-')) continue;
      if (!name.endsWith('.sdimg.gz')) continue;

      final DownloadItemType type;
      if (name.contains('unu-mdb-')) {
        type = DownloadItemType.mdbFirmware;
      } else if (name.contains('unu-dbc-')) {
        type = DownloadItemType.dbcFirmware;
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

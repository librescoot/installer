# Simple GUI Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 14-phase guided Flutter installer for LibreScoot firmware on MDB + DBC boards with two-phase safe flashing, autonomous DBC flash via trampoline script, GitHub release downloads, and offline map tile provisioning.

**Architecture:** Vertical stepper wizard UI driving a linear phase machine. New services (DownloadService, TrampolineService) alongside modified existing services (FlashService, SshService). Trampoline is a shell script uploaded to MDB that runs autonomously when the laptop is disconnected.

**Tech Stack:** Flutter 3.9+ desktop (Windows/macOS/Linux), dartssh2 for SSH, dart:io HTTP client for GitHub API, existing platform-specific USB/network/flash code.

**Spec:** `docs/specs/2026-03-30-simple-gui-installer-design.md`

---

## File Structure

### New files

```
lib/
  models/
    installer_phase.dart      # Phase enum + metadata (title, description, auto/manual)
    download_state.dart        # Channel, release info, download progress, region config
    scooter_health.dart        # Redis health check values
    trampoline_status.dart     # Parsed trampoline result
    region.dart                # German state regions with slugs and display names
  services/
    download_service.dart      # GitHub API, release resolution, download + cache
    trampoline_service.dart    # Script generation, upload, status parsing
  screens/
    installer_screen.dart      # Main wizard screen (replaces home_screen.dart usage)
  widgets/
    phase_sidebar.dart         # Vertical stepper sidebar
    phase_content.dart         # Main content area dispatcher
    download_progress.dart     # Download progress indicator
    health_check_panel.dart    # Redis health check display
    instruction_step.dart      # Physical instruction with image placeholder + confirm
assets/
  trampoline.sh.template       # Trampoline script template
test/
  services/
    download_service_test.dart
    trampoline_service_test.dart
    flash_service_test.dart
    ssh_service_test.dart
```

### Modified files

```
lib/main.dart                  # Switch from HomeScreen to InstallerScreen
lib/services/services.dart     # Add new service exports
lib/services/flash_service.dart  # Add two-phase write (skip/seek/count params)
lib/services/ssh_service.dart    # Add Redis commands, seatbox, DBC support
pubspec.yaml                   # Add http dependency (for GitHub API)
```

### Kept as-is

```
lib/services/usb_detector.dart
lib/services/network_service.dart
lib/services/elevation_service.dart
lib/services/driver_service.dart
lib/screens/home_screen.dart     # Keep for now, will be removed later
```

---

## Task 1: Models & Enums

**Files:**
- Create: `lib/models/installer_phase.dart`
- Create: `lib/models/region.dart`
- Create: `lib/models/download_state.dart`
- Create: `lib/models/scooter_health.dart`
- Create: `lib/models/trampoline_status.dart`

- [ ] **Step 1: Create InstallerPhase enum**

```dart
// lib/models/installer_phase.dart

enum InstallerPhase {
  welcome(
    title: 'Welcome',
    description: 'Prerequisites and firmware selection',
    isManual: true,
  ),
  physicalPrep(
    title: 'Physical Prep',
    description: 'Open footwell, connect USB',
    isManual: true,
  ),
  mdbConnect(
    title: 'MDB Connect',
    description: 'Detect device and establish SSH',
    isManual: false,
  ),
  healthCheck(
    title: 'Health Check',
    description: 'Verify scooter readiness',
    isManual: false,
  ),
  batteryRemoval(
    title: 'Battery Removal',
    description: 'Open seatbox, remove main battery',
    isManual: true,
  ),
  mdbToUms(
    title: 'MDB → UMS',
    description: 'Configure bootloader for flashing',
    isManual: false,
  ),
  mdbFlash(
    title: 'MDB Flash',
    description: 'Write firmware to MDB',
    isManual: false,
  ),
  scooterPrep(
    title: 'Scooter Prep',
    description: 'Disconnect CBB and AUX',
    isManual: true,
  ),
  mdbBoot(
    title: 'MDB Boot',
    description: 'Reconnect AUX, wait for boot',
    isManual: true,
  ),
  cbbReconnect(
    title: 'CBB Reconnect',
    description: 'Reconnect CBB for DBC flash',
    isManual: true,
  ),
  dbcPrep(
    title: 'DBC Prep',
    description: 'Upload DBC image and tiles',
    isManual: false,
  ),
  dbcFlash(
    title: 'DBC Flash',
    description: 'Autonomous DBC installation',
    isManual: false,
  ),
  reconnect(
    title: 'Reconnect',
    description: 'Verify DBC installation',
    isManual: true,
  ),
  finish(
    title: 'Finish',
    description: 'Reassemble and welcome',
    isManual: true,
  );

  const InstallerPhase({
    required this.title,
    required this.description,
    required this.isManual,
  });

  final String title;
  final String description;
  final bool isManual;
}
```

- [ ] **Step 2: Create Region model**

```dart
// lib/models/region.dart

class Region {
  const Region({
    required this.name,
    required this.slug,
  });

  final String name;
  final String slug;

  String get osmTilesFilename => 'tiles_$slug.mbtiles';
  String get osmTilesChecksumFilename => 'tiles_$slug.mbtiles.sha256';
  String get valhallaTilesFilename => 'valhalla_tiles_$slug.tar';
  String get valhallaTilesChecksumFilename => 'valhalla_tiles_$slug.tar.sha256';

  static const List<Region> all = [
    Region(name: 'Baden-Württemberg', slug: 'baden-wuerttemberg'),
    Region(name: 'Bayern', slug: 'bayern'),
    Region(name: 'Berlin & Brandenburg', slug: 'berlin_brandenburg'),
    Region(name: 'Bremen', slug: 'bremen'),
    Region(name: 'Hamburg', slug: 'hamburg'),
    Region(name: 'Hessen', slug: 'hessen'),
    Region(name: 'Mecklenburg-Vorpommern', slug: 'mecklenburg-vorpommern'),
    Region(name: 'Niedersachsen', slug: 'niedersachsen'),
    Region(name: 'Nordrhein-Westfalen', slug: 'nordrhein-westfalen'),
    Region(name: 'Rheinland-Pfalz', slug: 'rheinland-pfalz'),
    Region(name: 'Saarland', slug: 'saarland'),
    Region(name: 'Sachsen', slug: 'sachsen'),
    Region(name: 'Sachsen-Anhalt', slug: 'sachsen-anhalt'),
    Region(name: 'Schleswig-Holstein', slug: 'schleswig-holstein'),
    Region(name: 'Thüringen', slug: 'thueringen'),
  ];
}
```

- [ ] **Step 3: Create remaining models**

```dart
// lib/models/download_state.dart

enum DownloadChannel { stable, testing, nightly }

enum DownloadItemType { mdbFirmware, dbcFirmware, osmTiles, valhallaTiles }

class DownloadItem {
  DownloadItem({
    required this.type,
    required this.url,
    required this.filename,
    required this.expectedSize,
  });

  final DownloadItemType type;
  final String url;
  final String filename;
  final int expectedSize;
  int bytesDownloaded = 0;
  String? localPath;
  bool get isComplete => localPath != null;
  double get progress => expectedSize > 0 ? bytesDownloaded / expectedSize : 0;
}

class DownloadState {
  DownloadChannel channel = DownloadChannel.stable;
  String? releaseTag;
  bool isOffline = true;
  bool wantsOfflineMaps = true;
  Region? selectedRegion;
  List<DownloadItem> items = [];
  String? error;

  bool get allFirmwareReady =>
      items.where((i) => i.type == DownloadItemType.mdbFirmware ||
                         i.type == DownloadItemType.dbcFirmware)
           .every((i) => i.isComplete);

  bool get allReady => items.every((i) => i.isComplete);

  DownloadItem? itemOfType(DownloadItemType type) =>
      items.where((i) => i.type == type).firstOrNull;
}
```

```dart
// lib/models/scooter_health.dart

class ScooterHealth {
  int? auxCharge;
  int? cbbStateOfHealth;
  int? cbbCharge;
  bool? batteryPresent;

  bool get auxChargeOk => (auxCharge ?? 0) >= 50;
  bool get cbbSohOk => (cbbStateOfHealth ?? 0) >= 99;
  bool get cbbChargeOk => (cbbCharge ?? 0) >= 80;
  bool get allOk => auxChargeOk && cbbSohOk && cbbChargeOk && batteryPresent != null;
}
```

```dart
// lib/models/trampoline_status.dart

enum TrampolineResult { success, error, unknown }

class TrampolineStatus {
  TrampolineStatus({
    required this.result,
    this.message,
    this.errorLog,
  });

  final TrampolineResult result;
  final String? message;
  final String? errorLog;

  factory TrampolineStatus.parse(String content) {
    final lines = content.trim().split('\n');
    if (lines.isEmpty) return TrampolineStatus(result: TrampolineResult.unknown);

    final resultLine = lines.first.trim().toLowerCase();
    if (resultLine == 'success') {
      return TrampolineStatus(
        result: TrampolineResult.success,
        message: lines.length > 1 ? lines.sublist(1).join('\n') : null,
      );
    } else if (resultLine.startsWith('error')) {
      return TrampolineStatus(
        result: TrampolineResult.error,
        message: resultLine,
        errorLog: lines.length > 1 ? lines.sublist(1).join('\n') : null,
      );
    }
    return TrampolineStatus(result: TrampolineResult.unknown, message: content);
  }
}
```

- [ ] **Step 4: Verify models compile**

Run: `cd /Users/teal/src/librescoot/installer && flutter analyze lib/models/`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/models/
git commit -m "feat: add installer models and enums"
```

---

## Task 2: DownloadService

**Files:**
- Create: `lib/services/download_service.dart`
- Modify: `lib/services/services.dart`
- Modify: `pubspec.yaml`
- Create: `test/services/download_service_test.dart`

- [ ] **Step 1: Add http dependency**

In `pubspec.yaml`, add under `dependencies:`:
```yaml
  http: ^1.2.0
```

Run: `flutter pub get`

- [ ] **Step 2: Write DownloadService**

```dart
// lib/services/download_service.dart

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

  DownloadService({http.Client? client}) : _client = client ?? http.Client();

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

  /// Resolve the latest release for a channel. Returns (tag, assets) or throws.
  Future<({String tag, List<Map<String, dynamic>> assets})> resolveRelease(
    DownloadChannel channel,
  ) async {
    final response = await _client.get(
      Uri.parse('$_githubApi/repos/$_firmwareRepo/releases'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('GitHub API error: ${response.statusCode}');
    }

    final releases = jsonDecode(response.body) as List;
    final channelName = channel.name;

    // For default channel, try stable first, fall back to testing
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

  /// Resolve tile release assets for a region.
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
```

- [ ] **Step 3: Add export to services barrel**

In `lib/services/services.dart`, add:
```dart
export 'download_service.dart';
```

- [ ] **Step 4: Write tests for DownloadService**

```dart
// test/services/download_service_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/services/download_service.dart';

void main() {
  group('DownloadService', () {
    late http_testing.MockClient mockClient;

    test('resolveRelease finds testing release', () async {
      mockClient = http_testing.MockClient((request) async {
        if (request.url.path.endsWith('/releases')) {
          return http.Response(jsonEncode([
            {
              'tag_name': 'nightly-20260330T013130',
              'assets': [
                {'name': 'librescoot-unu-mdb-nightly-20260330T013130.sdimg.gz', 'size': 141215162, 'browser_download_url': 'https://example.com/mdb.sdimg.gz'},
                {'name': 'librescoot-unu-dbc-nightly-20260330T013130.sdimg.gz', 'size': 197006162, 'browser_download_url': 'https://example.com/dbc.sdimg.gz'},
              ],
            },
            {
              'tag_name': 'testing-20260318T114803',
              'assets': [
                {'name': 'librescoot-unu-mdb-testing-20260318T114803.sdimg.gz', 'size': 140000000, 'browser_download_url': 'https://example.com/mdb-test.sdimg.gz'},
                {'name': 'librescoot-unu-dbc-testing-20260318T114803.sdimg.gz', 'size': 196000000, 'browser_download_url': 'https://example.com/dbc-test.sdimg.gz'},
              ],
            },
          ]), 200);
        }
        return http.Response('Not found', 404);
      });

      final service = DownloadService(client: mockClient);
      final result = await service.resolveRelease(DownloadChannel.testing);
      expect(result.tag, 'testing-20260318T114803');
      expect(result.assets.length, 2);
    });

    test('resolveRelease falls back from stable to testing', () async {
      mockClient = http_testing.MockClient((request) async {
        return http.Response(jsonEncode([
          {
            'tag_name': 'testing-20260318T114803',
            'assets': [
              {'name': 'librescoot-unu-mdb-testing-20260318T114803.sdimg.gz', 'size': 140000000, 'browser_download_url': 'https://example.com/mdb.sdimg.gz'},
            ],
          },
        ]), 200);
      });

      final service = DownloadService(client: mockClient);
      final result = await service.resolveRelease(DownloadChannel.stable);
      expect(result.tag, startsWith('testing-'));
    });

    test('buildDownloadQueue filters to unu variants only', () async {
      mockClient = http_testing.MockClient((request) async {
        if (request.url.path.endsWith('/releases')) {
          return http.Response(jsonEncode([
            {
              'tag_name': 'testing-20260318T114803',
              'assets': [
                {'name': 'librescoot-unu-mdb-testing-20260318T114803.sdimg.gz', 'size': 100, 'browser_download_url': 'https://example.com/mdb.gz'},
                {'name': 'librescoot-unu-dbc-testing-20260318T114803.sdimg.gz', 'size': 200, 'browser_download_url': 'https://example.com/dbc.gz'},
                {'name': 'librescoot-unu-mdb-testing-20260318T114803.mender', 'size': 300, 'browser_download_url': 'https://example.com/mdb.mender'},
                {'name': 'librescoot-other-mdb-testing-20260318T114803.sdimg.gz', 'size': 400, 'browser_download_url': 'https://example.com/other.gz'},
              ],
            },
          ]), 200);
        }
        return http.Response('Not found', 404);
      });

      final service = DownloadService(client: mockClient);
      final items = await service.buildDownloadQueue(
        channel: DownloadChannel.testing,
        wantsOfflineMaps: false,
      );
      expect(items.length, 2);
      expect(items[0].type, DownloadItemType.mdbFirmware);
      expect(items[1].type, DownloadItemType.dbcFirmware);
    });

    test('Region model generates correct filenames', () {
      final region = Region.all.firstWhere((r) => r.slug == 'berlin_brandenburg');
      expect(region.osmTilesFilename, 'tiles_berlin_brandenburg.mbtiles');
      expect(region.valhallaTilesFilename, 'valhalla_tiles_berlin_brandenburg.tar');
    });
  });
}
```

- [ ] **Step 5: Run tests**

Run: `cd /Users/teal/src/librescoot/installer && flutter test test/services/download_service_test.dart`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add lib/services/download_service.dart lib/services/services.dart pubspec.yaml test/services/download_service_test.dart
git commit -m "feat: add DownloadService for GitHub release + tile downloads"
```

---

## Task 3: SSH Service Redis Extensions

**Files:**
- Modify: `lib/services/ssh_service.dart`
- Create: `test/services/ssh_service_test.dart`

- [ ] **Step 1: Read existing ssh_service.dart**

Read: `lib/services/ssh_service.dart` — understand the current API (connectToMdb, runCommand, etc.)

- [ ] **Step 2: Add Redis query and seatbox methods**

Add to the `SshService` class:

```dart
/// Run a Redis HGET command on the MDB and return the value.
Future<String?> redisHget(String hash, String field) async {
  final result = await runCommand('redis-cli HGET $hash $field');
  final value = result?.trim();
  if (value == null || value.isEmpty || value == '(nil)') return null;
  return value;
}

/// Run a Redis LPUSH command on the MDB.
Future<void> redisLpush(String key, String value) async {
  await runCommand('redis-cli LPUSH $key $value');
}

/// Query scooter health from Redis.
Future<ScooterHealth> queryHealth() async {
  final health = ScooterHealth();
  health.auxCharge = int.tryParse(await redisHget('aux-battery', 'charge') ?? '');
  health.cbbStateOfHealth = int.tryParse(await redisHget('cb-battery', 'state-of-health') ?? '');
  health.cbbCharge = int.tryParse(await redisHget('cb-battery', 'charge') ?? '');
  final batteryPresent = await redisHget('battery:0', 'present');
  health.batteryPresent = batteryPresent == 'true';
  return health;
}

/// Open the seatbox.
Future<void> openSeatbox() async {
  await redisLpush('scooter:seatbox', 'open');
}

/// Check if CBB is connected.
Future<bool> isCbbPresent() async {
  final present = await redisHget('cb-battery', 'present');
  return present == 'true';
}

/// Check if main battery is present.
Future<bool> isBatteryPresent() async {
  final present = await redisHget('battery:0', 'present');
  return present == 'true';
}

/// Upload a file to MDB via SCP/stdin pipe.
/// Uses the existing SSH connection to write file contents.
Future<void> uploadFileToPath(String localPath, String remotePath) async {
  final file = File(localPath);
  final bytes = await file.readAsBytes();
  final base64Content = base64Encode(bytes);
  await runCommand('echo "$base64Content" | base64 -d > $remotePath');
}

/// Configure DBC bootloader for UMS mode (run on MDB, targeting DBC).
Future<void> configureDcbMassStorageMode() async {
  // Upload fw_setenv tools to DBC via MDB
  await runCommand('scp /tmp/fw_setenv root@192.168.7.2:/tmp/fw_setenv');
  await runCommand('scp /tmp/fw_env.config root@192.168.7.2:/tmp/fw_env.config');
  // Set DBC bootloader for UMS
  await runCommand(
    'ssh root@192.168.7.2 "/tmp/fw_setenv -c /tmp/fw_env.config bootcmd '
    '\\"fuse prog -y 0 5 0x00003860; fuse prog -y 0 6 0x00000010; ums 0 mmc 2;\\"" || '
    'ssh root@192.168.7.2 "/tmp/fw_setenv -c /tmp/fw_env.config bootcmd \\"ums 0 mmc 2\\""',
  );
  await runCommand(
    'ssh root@192.168.7.2 "/tmp/fw_setenv -c /tmp/fw_env.config bootdelay 0"',
  );
}

/// Read the trampoline status file from MDB.
Future<TrampolineStatus> readTrampolineStatus() async {
  final content = await runCommand('cat /data/trampoline-status 2>/dev/null');
  if (content == null || content.trim().isEmpty) {
    return TrampolineStatus(result: TrampolineResult.unknown);
  }
  return TrampolineStatus.parse(content);
}
```

Add imports at top of file:
```dart
import 'dart:convert';
import '../models/scooter_health.dart';
import '../models/trampoline_status.dart';
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/services/ssh_service.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/services/ssh_service.dart
git commit -m "feat: add Redis query, seatbox, and DBC commands to SshService"
```

---

## Task 4: Two-Phase Flash in FlashService

**Files:**
- Modify: `lib/services/flash_service.dart`

- [ ] **Step 1: Read existing flash_service.dart**

Read: `lib/services/flash_service.dart` — understand `writeImage()` and platform-specific dd commands.

- [ ] **Step 2: Add two-phase flash method**

Add to `FlashService`:

```dart
/// The boot area size in bytes (24MB = sector 49152 * 512).
/// Everything before this is U-Boot + env. Everything after is partitions.
static const bootAreaBytes = 24 * 1024 * 1024; // 24MB
static const ddBlockSize = 4 * 1024 * 1024; // 4MB
static const bootAreaBlocks = bootAreaBytes ~/ ddBlockSize; // 6 blocks

/// Two-phase flash: write partitions first (safe), then boot sector (commits).
/// Phase A: skip first 24MB, write the rest
/// Phase B: write first 24MB only
Future<void> writeTwoPhase(
  String imagePath,
  String devicePath, {
  void Function(double progress, String message)? onProgress,
}) async {
  final isCompressed = imagePath.endsWith('.gz');

  // Phase A: write partitions (everything from 24MB onwards)
  onProgress?.call(0.0, 'Phase A: Writing partitions...');
  await _runDd(
    imagePath: imagePath,
    devicePath: devicePath,
    isCompressed: isCompressed,
    skip: bootAreaBlocks,
    seek: bootAreaBlocks,
    onProgress: (p, msg) => onProgress?.call(p * 0.9, 'Phase A: $msg'),
  );

  // Phase B: write boot sector (first 24MB)
  onProgress?.call(0.9, 'Phase B: Writing boot sector...');
  await _runDd(
    imagePath: imagePath,
    devicePath: devicePath,
    isCompressed: isCompressed,
    count: bootAreaBlocks,
    onProgress: (p, msg) => onProgress?.call(0.9 + p * 0.1, 'Phase B: $msg'),
  );

  // Sync
  onProgress?.call(1.0, 'Syncing...');
  await _runSync(devicePath);
}

Future<void> _runDd({
  required String imagePath,
  required String devicePath,
  required bool isCompressed,
  int? skip,
  int? seek,
  int? count,
  void Function(double progress, String message)? onProgress,
}) async {
  final ddArgs = <String>[
    'bs=4M',
    if (skip != null) 'skip=$skip',
    if (seek != null) 'seek=$seek',
    if (count != null) 'count=$count',
  ];

  if (Platform.isWindows) {
    await _runDdWindows(imagePath, devicePath, isCompressed, ddArgs, onProgress);
  } else if (Platform.isMacOS) {
    await _runDdUnix(imagePath, devicePath, isCompressed, ddArgs, 'bs=4m', onProgress);
  } else {
    await _runDdUnix(imagePath, devicePath, isCompressed, ddArgs, 'bs=4M', onProgress);
  }
}

Future<void> _runDdUnix(
  String imagePath,
  String devicePath,
  bool isCompressed,
  List<String> extraArgs,
  String bsArg,
  void Function(double progress, String message)? onProgress,
) async {
  final rawDevice = Platform.isMacOS
      ? devicePath.replaceFirst('/dev/disk', '/dev/rdisk')
      : devicePath;

  final ddParams = [bsArg, ...extraArgs.where((a) => !a.startsWith('bs='))];

  final String command;
  if (isCompressed) {
    command = 'gunzip -c "$imagePath" | dd of=$rawDevice ${ddParams.join(' ')} status=progress 2>&1';
  } else {
    command = 'dd if="$imagePath" of=$rawDevice ${ddParams.join(' ')} status=progress 2>&1';
  }

  final process = await Process.start('/bin/sh', ['-c', command]);
  await for (final line in process.stderr.transform(utf8.decoder)) {
    final bytesMatch = RegExp(r'(\d+)\s+bytes').firstMatch(line);
    if (bytesMatch != null) {
      final bytes = int.tryParse(bytesMatch.group(1)!);
      if (bytes != null) {
        onProgress?.call(0.5, '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB written');
      }
    }
  }
  final exitCode = await process.exitCode;
  if (exitCode != 0) throw Exception('dd failed with exit code $exitCode');
}

Future<void> _runDdWindows(
  String imagePath,
  String devicePath,
  bool isCompressed,
  List<String> extraArgs,
  void Function(double progress, String message)? onProgress,
) async {
  // Windows implementation using dd.exe from assets
  // Similar to existing writeImage but with skip/seek/count support
  final ddExe = await _extractAsset('assets/tools/dd.exe');

  String inputSource;
  if (isCompressed) {
    // Decompress with PowerShell GZipStream, pipe to dd
    inputSource = 'powershell -Command "'
        '\$input = [System.IO.File]::OpenRead(\'$imagePath\'); '
        '\$gzip = New-Object System.IO.Compression.GZipStream(\$input, [System.IO.Compression.CompressionMode]::Decompress); '
        '\$gzip.CopyTo([System.Console]::OpenStandardOutput()); '
        '\$gzip.Close(); \$input.Close()" | ';
  } else {
    inputSource = '';
  }

  final ddArgs = extraArgs.where((a) => !a.startsWith('bs=')).toList();
  if (!isCompressed) ddArgs.add('if=$imagePath');
  ddArgs.addAll(['of=$devicePath', 'bs=4M']);

  final command = '$inputSource"$ddExe" ${ddArgs.join(' ')}';
  final process = await Process.start('cmd', ['/c', command]);
  final exitCode = await process.exitCode;
  if (exitCode != 0) throw Exception('dd.exe failed with exit code $exitCode');
}

Future<void> _runSync(String devicePath) async {
  if (Platform.isWindows) {
    // Windows: use diskpart or sync command
    await Process.run('cmd', ['/c', 'sync']);
  } else if (Platform.isMacOS) {
    await Process.run('sync', []);
    await Process.run('diskutil', ['eject', devicePath]);
  } else {
    await Process.run('sync', []);
  }
}
```

Note: Add `import 'dart:convert';` at top if not already present.

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/services/flash_service.dart`
Expected: No errors (may have warnings about unused methods in existing code — that's fine)

- [ ] **Step 4: Commit**

```bash
git add lib/services/flash_service.dart
git commit -m "feat: add two-phase flash to FlashService (boot sector last)"
```

---

## Task 5: TrampolineService

**Files:**
- Create: `lib/services/trampoline_service.dart`
- Create: `assets/trampoline.sh.template`
- Modify: `lib/services/services.dart`
- Create: `test/services/trampoline_service_test.dart`

- [ ] **Step 1: Create trampoline shell script template**

```bash
# assets/trampoline.sh.template
#!/bin/sh
# LibreScoot DBC Trampoline Script
# Generated by installer — runs autonomously on MDB
set -e

STATUS_FILE="/data/trampoline-status"
LOG_FILE="/data/trampoline.log"
DBC_IMAGE="{{DBC_IMAGE_PATH}}"
DBC_IP="192.168.7.2"
BOOT_AREA_BLOCKS=6
INSTALL_TILES="{{INSTALL_TILES}}"
OSM_TILES_FILE="{{OSM_TILES_FILE}}"
VALHALLA_TILES_FILE="{{VALHALLA_TILES_FILE}}"
OSM_SHA256="{{OSM_SHA256}}"
VALHALLA_SHA256="{{VALHALLA_SHA256}}"

log() { echo "$(date '+%H:%M:%S') $1" | tee -a "$LOG_FILE"; }
signal_bootled() { lsc bootled "$1" 2>/dev/null || true; }
signal_leds_on() { lsc led fade front-ring parking-smooth-on 2>/dev/null || true; }
signal_leds_progress() {
  lsc led fade front-ring parking-smooth-on 2>/dev/null || true
  lsc led fade brake-light brake-dim-on 2>/dev/null || true
  lsc led fade number-plates parking-smooth-on 2>/dev/null || true
}
signal_success() {
  lsc led cue parked-to-drive 2>/dev/null || true
  sleep 3
  lsc led cue all-off 2>/dev/null || true
}
signal_error() { lsc led cue blink-both 2>/dev/null || true; }

fail() {
  log "ERROR: $1"
  echo "error: $1" > "$STATUS_FILE"
  cat "$LOG_FILE" >> "$STATUS_FILE"
  signal_bootled red
  signal_error
  # Switch USB back to gadget mode so laptop can reconnect
  modprobe g_ether 2>/dev/null || true
  exit 1
}

# Start
echo "" > "$LOG_FILE"
log "Trampoline started"
signal_bootled amber
signal_leds_on

# Step 1: Wait for laptop USB disconnect
log "Waiting for laptop to disconnect..."
while cat /sys/class/udc/ci_hdrc.0/state 2>/dev/null | grep -q configured; do
  sleep 1
done
log "Laptop disconnected"

# Step 2: Wait for DBC network
log "Powering on DBC..."
lsc dbc on-wait || fail "DBC did not come up"
signal_bootled green
log "DBC is reachable"

# Step 3: Prepare DBC for UMS
log "Configuring DBC bootloader..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$DBC_IP \
  "systemctl stop dbc-dashboard-ui 2>/dev/null; systemctl stop scootui-qt 2>/dev/null" || true

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  /tmp/fw_setenv /tmp/fw_env.config root@$DBC_IP:/tmp/ || fail "Failed to copy fw_setenv to DBC"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$DBC_IP \
  '/tmp/fw_setenv -c /tmp/fw_env.config bootcmd "fuse prog -y 0 5 0x00003860; fuse prog -y 0 6 0x00000010; ums 0 mmc 2;"' \
  || ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$DBC_IP \
  '/tmp/fw_setenv -c /tmp/fw_env.config bootcmd "ums 0 mmc 2"' \
  || fail "Failed to set DBC bootcmd"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$DBC_IP \
  '/tmp/fw_setenv -c /tmp/fw_env.config bootdelay 0' || true

log "Rebooting DBC..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$DBC_IP \
  'reboot' 2>/dev/null || true
sleep 5

# Step 4: Switch to USB host mode
log "Switching USB to host mode..."
rmmod g_ether 2>/dev/null || true
# TBD: exact host mode switch mechanism — may need additional sysfs writes
sleep 2

# Step 5: Wait for DBC block device
log "Waiting for DBC UMS device..."
TIMEOUT=120
ELAPSED=0
DBC_DEV=""
while [ $ELAPSED -lt $TIMEOUT ]; do
  for dev in /dev/sd?; do
    if [ -b "$dev" ]; then
      DBC_DEV="$dev"
      break 2
    fi
  done
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done
[ -z "$DBC_DEV" ] && fail "DBC UMS device not found within ${TIMEOUT}s"
log "DBC device found: $DBC_DEV"

signal_leds_progress

# Step 6: Two-phase flash DBC
log "Phase A: Writing DBC partitions..."
gunzip -c "$DBC_IMAGE" | dd bs=4M skip=$BOOT_AREA_BLOCKS seek=$BOOT_AREA_BLOCKS of=$DBC_DEV 2>>"$LOG_FILE" \
  || fail "DBC Phase A dd failed"

log "Phase B: Writing DBC boot sector..."
gunzip -c "$DBC_IMAGE" | dd bs=4M count=$BOOT_AREA_BLOCKS of=$DBC_DEV 2>>"$LOG_FILE" \
  || fail "DBC Phase B dd failed"

sync
log "DBC flash complete"

# Step 7: Switch back to gadget mode and power cycle DBC
log "Switching USB back to gadget mode..."
modprobe g_ether 2>/dev/null || true
sleep 2

log "Power cycling DBC..."
lsc dbc off 2>/dev/null || true
sleep 3
lsc dbc on-wait || fail "DBC did not come up after flash"

# Step 8: Install tiles if requested
if [ "$INSTALL_TILES" = "true" ]; then
  log "Installing map tiles on DBC..."

  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$DBC_IP \
    "mkdir -p /data/maps /data/valhalla" || fail "Failed to create tile directories on DBC"

  if [ -n "$OSM_TILES_FILE" ] && [ -f "$OSM_TILES_FILE" ]; then
    log "Copying display tiles..."
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      "$OSM_TILES_FILE" root@$DBC_IP:/data/maps/map.mbtiles \
      || fail "Failed to copy display tiles"
  fi

  if [ -n "$VALHALLA_TILES_FILE" ] && [ -f "$VALHALLA_TILES_FILE" ]; then
    log "Copying routing tiles..."
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      "$VALHALLA_TILES_FILE" root@$DBC_IP:/data/valhalla/tiles.tar \
      || fail "Failed to copy routing tiles"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$DBC_IP \
      "systemctl restart valhalla" 2>/dev/null || true
  fi
  log "Tiles installed"
fi

# Step 9: Run firstrun
log "Starting firstrun on DBC..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$DBC_IP \
  "systemctl start firstrun" 2>/dev/null || log "WARNING: firstrun start failed"

# Done
log "Trampoline complete - success"
echo "success" > "$STATUS_FILE"
cat "$LOG_FILE" >> "$STATUS_FILE"
signal_bootled green
signal_success
```

- [ ] **Step 2: Create TrampolineService**

```dart
// lib/services/trampoline_service.dart

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../models/download_state.dart';
import '../models/region.dart';
import '../models/trampoline_status.dart';
import 'ssh_service.dart';

class TrampolineService {
  final SshService _ssh;

  TrampolineService(this._ssh);

  /// Generate the trampoline script from template with actual paths.
  Future<String> generateScript({
    required String dbcImagePath,
    Region? region,
    bool installTiles = false,
  }) async {
    var template = await rootBundle.loadString('assets/trampoline.sh.template');

    template = template
        .replaceAll('{{DBC_IMAGE_PATH}}', dbcImagePath)
        .replaceAll('{{INSTALL_TILES}}', installTiles ? 'true' : 'false')
        .replaceAll('{{OSM_TILES_FILE}}',
            installTiles && region != null ? '/data/${region.osmTilesFilename}' : '')
        .replaceAll('{{VALHALLA_TILES_FILE}}',
            installTiles && region != null ? '/data/${region.valhallaTilesFilename}' : '')
        .replaceAll('{{OSM_SHA256}}', '') // TODO: pass actual checksums if needed
        .replaceAll('{{VALHALLA_SHA256}}', '');

    return template;
  }

  /// Upload DBC image, tiles, and trampoline script to MDB.
  Future<void> uploadAll({
    required String dbcImageLocalPath,
    String? osmTilesLocalPath,
    String? valhallaTilesLocalPath,
    Region? region,
    void Function(String status, double progress)? onProgress,
  }) async {
    final filesToUpload = <MapEntry<String, String>>[];

    // DBC image
    filesToUpload.add(MapEntry(dbcImageLocalPath, '/data/${File(dbcImageLocalPath).uri.pathSegments.last}'));

    // Tiles
    if (osmTilesLocalPath != null && region != null) {
      filesToUpload.add(MapEntry(osmTilesLocalPath, '/data/${region.osmTilesFilename}'));
    }
    if (valhallaTilesLocalPath != null && region != null) {
      filesToUpload.add(MapEntry(valhallaTilesLocalPath, '/data/${region.valhallaTilesFilename}'));
    }

    var uploaded = 0;
    for (final entry in filesToUpload) {
      onProgress?.call('Uploading ${File(entry.key).uri.pathSegments.last}...', uploaded / filesToUpload.length);
      await _uploadViaScp(entry.key, entry.value);
      uploaded++;
    }

    // Generate and upload trampoline script
    onProgress?.call('Uploading trampoline script...', 0.95);
    final dbcRemotePath = '/data/${File(dbcImageLocalPath).uri.pathSegments.last}';
    final script = await generateScript(
      dbcImagePath: dbcRemotePath,
      region: region,
      installTiles: osmTilesLocalPath != null || valhallaTilesLocalPath != null,
    );
    await _ssh.runCommand("cat > /data/trampoline.sh << 'TRAMPOLINE_EOF'\n$script\nTRAMPOLINE_EOF");
    await _ssh.runCommand('chmod +x /data/trampoline.sh');

    onProgress?.call('Upload complete', 1.0);
  }

  /// Start the trampoline script on MDB in background.
  Future<void> start() async {
    await _ssh.runCommand('nohup /data/trampoline.sh > /data/trampoline-stdout.log 2>&1 &');
  }

  /// Read trampoline status (call after reconnecting to MDB).
  Future<TrampolineStatus> readStatus() async {
    return _ssh.readTrampolineStatus();
  }

  Future<void> _uploadViaScp(String localPath, String remotePath) async {
    // Use dd-style upload for large files: cat local file, pipe through SSH
    // For the installer, we use the SSH connection's exec to receive data
    final file = File(localPath);
    final size = await file.length();

    // For large files, use a chunked approach via the SSH session
    // The SshService.uploadFile method handles this
    await _ssh.uploadFileToPath(localPath, remotePath);
  }
}
```

- [ ] **Step 3: Add export to services barrel**

In `lib/services/services.dart`, add:
```dart
export 'trampoline_service.dart';
```

- [ ] **Step 4: Register template as asset**

In `pubspec.yaml`, ensure `assets/` includes the template:
```yaml
  assets:
    - assets/
    - assets/drivers/
    - assets/tools/
```
(The template lives in `assets/` so the existing glob should catch it.)

- [ ] **Step 5: Write tests**

```dart
// test/services/trampoline_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';

void main() {
  group('TrampolineStatus', () {
    test('parses success', () {
      final status = TrampolineStatus.parse('success\nAll done in 5m');
      expect(status.result, TrampolineResult.success);
      expect(status.message, 'All done in 5m');
    });

    test('parses error', () {
      final status = TrampolineStatus.parse('error: DBC UMS device not found\nlog line 1\nlog line 2');
      expect(status.result, TrampolineResult.error);
      expect(status.errorLog, contains('log line'));
    });

    test('handles empty content', () {
      final status = TrampolineStatus.parse('');
      expect(status.result, TrampolineResult.unknown);
    });
  });

  group('Region', () {
    test('has 15 regions', () {
      expect(Region.all.length, 15);
    });

    test('berlin_brandenburg slug is correct', () {
      final region = Region.all.firstWhere((r) => r.name.contains('Berlin'));
      expect(region.slug, 'berlin_brandenburg');
    });
  });
}
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/services/trampoline_service_test.dart`
Expected: All pass

- [ ] **Step 7: Commit**

```bash
git add lib/services/trampoline_service.dart lib/services/services.dart assets/trampoline.sh.template test/services/trampoline_service_test.dart
git commit -m "feat: add TrampolineService and DBC flash script template"
```

---

## Task 6: Wizard UI Scaffold

**Files:**
- Create: `lib/widgets/phase_sidebar.dart`
- Create: `lib/screens/installer_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create phase sidebar widget**

```dart
// lib/widgets/phase_sidebar.dart

import 'package:flutter/material.dart';
import '../models/installer_phase.dart';

class PhaseSidebar extends StatelessWidget {
  const PhaseSidebar({
    super.key,
    required this.currentPhase,
    required this.completedPhases,
  });

  final InstallerPhase currentPhase;
  final Set<InstallerPhase> completedPhases;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF1A1A2E),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'LibreScoot Installer',
              style: TextStyle(
                color: Colors.tealAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final phase in InstallerPhase.values)
            _PhaseItem(
              phase: phase,
              isCurrent: phase == currentPhase,
              isCompleted: completedPhases.contains(phase),
              isPast: phase.index < currentPhase.index,
            ),
        ],
      ),
    );
  }
}

class _PhaseItem extends StatelessWidget {
  const _PhaseItem({
    required this.phase,
    required this.isCurrent,
    required this.isCompleted,
    required this.isPast,
  });

  final InstallerPhase phase;
  final bool isCurrent;
  final bool isCompleted;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Widget leading;

    if (isCompleted || isPast) {
      textColor = Colors.grey;
      leading = const Icon(Icons.check, size: 16, color: Colors.grey);
    } else if (isCurrent) {
      textColor = Colors.tealAccent;
      leading = const Icon(Icons.circle, size: 12, color: Colors.tealAccent);
    } else {
      textColor = Colors.grey.shade700;
      leading = Icon(Icons.circle_outlined, size: 12, color: Colors.grey.shade700);
    }

    return Container(
      color: isCurrent ? Colors.tealAccent.withOpacity(0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Center(child: leading)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phase.title,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create installer screen scaffold**

```dart
// lib/screens/installer_screen.dart

import 'package:flutter/material.dart';

import '../models/installer_phase.dart';
import '../models/download_state.dart';
import '../models/scooter_health.dart';
import '../models/region.dart';
import '../services/services.dart';
import '../widgets/phase_sidebar.dart';

class InstallerScreen extends StatefulWidget {
  const InstallerScreen({super.key});

  @override
  State<InstallerScreen> createState() => _InstallerScreenState();
}

class _InstallerScreenState extends State<InstallerScreen> {
  InstallerPhase _currentPhase = InstallerPhase.welcome;
  final Set<InstallerPhase> _completedPhases = {};
  String _statusMessage = '';
  bool _isProcessing = false;
  double _progress = 0.0;
  bool _isElevated = false;

  // Services
  late final UsbDetector _usbDetector;
  late final DownloadService _downloadService;
  final SshService _sshService = SshService();

  // State
  final DownloadState _downloadState = DownloadState();
  ScooterHealth? _scooterHealth;
  UsbDevice? _device;

  @override
  void initState() {
    super.initState();
    _usbDetector = UsbDetector();
    _downloadService = DownloadService();
    _checkElevation();
    _usbDetector.startMonitoring();
    _usbDetector.deviceStream.listen(_onDeviceChanged);
  }

  @override
  void dispose() {
    _usbDetector.stopMonitoring();
    _downloadService.dispose();
    super.dispose();
  }

  void _checkElevation() async {
    _isElevated = await ElevationService.isElevated();
    if (mounted) setState(() {});
  }

  void _onDeviceChanged(UsbDevice? device) {
    setState(() => _device = device);
  }

  void _setPhase(InstallerPhase phase) {
    setState(() {
      _completedPhases.add(_currentPhase);
      _currentPhase = phase;
      _statusMessage = '';
      _progress = 0.0;
    });
  }

  void _setStatus(String message, {double? progress}) {
    setState(() {
      _statusMessage = message;
      if (progress != null) _progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          PhaseSidebar(
            currentPhase: _currentPhase,
            completedPhases: _completedPhases,
          ),
          Expanded(
            child: Column(
              children: [
                // Elevation warning
                if (!_isElevated)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade900,
                    padding: const EdgeInsets.all(8),
                    child: const Text(
                      'Running without admin privileges. Some operations may fail.',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Phase content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildPhaseContent(),
                  ),
                ),
                // Status bar
                if (_statusMessage.isNotEmpty || _progress > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade800)),
                    ),
                    child: Column(
                      children: [
                        if (_progress > 0)
                          LinearProgressIndicator(value: _progress, minHeight: 4),
                        if (_progress > 0) const SizedBox(height: 8),
                        if (_statusMessage.isNotEmpty)
                          Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent() {
    // Dispatch to phase-specific content builders
    // Each phase gets its own method — implemented in subsequent tasks
    switch (_currentPhase) {
      case InstallerPhase.welcome:
        return _buildWelcome();
      case InstallerPhase.physicalPrep:
        return _buildPhysicalPrep();
      case InstallerPhase.mdbConnect:
        return _buildMdbConnect();
      case InstallerPhase.healthCheck:
        return _buildHealthCheck();
      case InstallerPhase.batteryRemoval:
        return _buildBatteryRemoval();
      case InstallerPhase.mdbToUms:
        return _buildMdbToUms();
      case InstallerPhase.mdbFlash:
        return _buildMdbFlash();
      case InstallerPhase.scooterPrep:
        return _buildScooterPrep();
      case InstallerPhase.mdbBoot:
        return _buildMdbBoot();
      case InstallerPhase.cbbReconnect:
        return _buildCbbReconnect();
      case InstallerPhase.dbcPrep:
        return _buildDbcPrep();
      case InstallerPhase.dbcFlash:
        return _buildDbcFlash();
      case InstallerPhase.reconnect:
        return _buildReconnect();
      case InstallerPhase.finish:
        return _buildFinish();
    }
  }

  // Placeholder phase builders — each returns a centered title + description
  // These will be fleshed out in Task 7+
  Widget _phasePlaceholder(String extra) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentPhase.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_currentPhase.description, style: TextStyle(color: Colors.grey.shade400)),
          const SizedBox(height: 16),
          Text(extra, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildWelcome() => _phasePlaceholder('TODO: channel select, region, download');
  Widget _buildPhysicalPrep() => _phasePlaceholder('TODO: instructions');
  Widget _buildMdbConnect() => _phasePlaceholder('TODO: auto-detect');
  Widget _buildHealthCheck() => _phasePlaceholder('TODO: redis checks');
  Widget _buildBatteryRemoval() => _phasePlaceholder('TODO: seatbox + verify');
  Widget _buildMdbToUms() => _phasePlaceholder('TODO: fw_setenv + reboot');
  Widget _buildMdbFlash() => _phasePlaceholder('TODO: two-phase dd');
  Widget _buildScooterPrep() => _phasePlaceholder('TODO: CBB + AUX instructions');
  Widget _buildMdbBoot() => _phasePlaceholder('TODO: wait for RNDIS');
  Widget _buildCbbReconnect() => _phasePlaceholder('TODO: verify CBB');
  Widget _buildDbcPrep() => _phasePlaceholder('TODO: upload + trampoline');
  Widget _buildDbcFlash() => _phasePlaceholder('TODO: waiting screen');
  Widget _buildReconnect() => _phasePlaceholder('TODO: verify status');
  Widget _buildFinish() => _phasePlaceholder('TODO: reassemble instructions');
}
```

- [ ] **Step 3: Switch main.dart to InstallerScreen**

In `lib/main.dart`, change the home screen:

Replace:
```dart
import 'screens/home_screen.dart';
```
With:
```dart
import 'screens/installer_screen.dart';
```

And in the `MaterialApp`, change `home: const HomeScreen()` to `home: const InstallerScreen()`.

- [ ] **Step 4: Verify it compiles and runs**

Run: `flutter analyze lib/`
Expected: No errors (warnings about unused imports in the placeholder are fine)

Run: `flutter run -d macos` (or the available platform) — verify the app shows the sidebar with phase list and a placeholder content area.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/phase_sidebar.dart lib/screens/installer_screen.dart lib/main.dart
git commit -m "feat: add wizard UI scaffold with stepper sidebar"
```

---

## Task 7: Phase 0 — Welcome Screen

**Files:**
- Modify: `lib/screens/installer_screen.dart`
- Create: `lib/widgets/download_progress.dart`

- [ ] **Step 1: Create download progress widget**

```dart
// lib/widgets/download_progress.dart

import 'package:flutter/material.dart';
import '../models/download_state.dart';

class DownloadProgressWidget extends StatelessWidget {
  const DownloadProgressWidget({super.key, required this.items});

  final List<DownloadItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Downloads', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (item.isComplete)
                  const Icon(Icons.check_circle, size: 16, color: Colors.tealAccent)
                else
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: item.progress > 0 ? item.progress : null,
                      strokeWidth: 2,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelFor(item.type),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                  ),
                ),
                Text(
                  item.isComplete
                      ? '${(item.expectedSize / 1024 / 1024).toStringAsFixed(0)} MB'
                      : '${(item.bytesDownloaded / 1024 / 1024).toStringAsFixed(0)} / ${(item.expectedSize / 1024 / 1024).toStringAsFixed(0)} MB',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _labelFor(DownloadItemType type) => switch (type) {
        DownloadItemType.mdbFirmware => 'MDB Firmware',
        DownloadItemType.dbcFirmware => 'DBC Firmware',
        DownloadItemType.osmTiles => 'Map Tiles',
        DownloadItemType.valhallaTiles => 'Routing Tiles',
      };
}
```

- [ ] **Step 2: Implement _buildWelcome() in installer_screen.dart**

Replace the placeholder `_buildWelcome()` method:

```dart
Widget _buildWelcome() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Welcome to LibreScoot Installer',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('This wizard will guide you through installing LibreScoot firmware on your scooter.',
            style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 24),

        // Prerequisites
        const Text('What you need:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _prerequisite('PH2 or H4 screwdriver for footwell screws'),
        _prerequisite('Flat head or PH1 screwdriver for USB cable'),
        _prerequisite('USB cable (laptop to Mini-B)'),
        _prerequisite('About 45 minutes'),
        const SizedBox(height: 24),

        // Channel selection
        const Text('Firmware Channel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SegmentedButton<DownloadChannel>(
          segments: const [
            ButtonSegment(value: DownloadChannel.stable, label: Text('Stable')),
            ButtonSegment(value: DownloadChannel.testing, label: Text('Testing')),
            ButtonSegment(value: DownloadChannel.nightly, label: Text('Nightly')),
          ],
          selected: {_downloadState.channel},
          onSelectionChanged: (selected) {
            setState(() => _downloadState.channel = selected.first);
          },
        ),
        const SizedBox(height: 24),

        // Online/offline
        const Text('Connectivity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Scooter will be offline'),
          subtitle: const Text('Most scooters are offline — download maps for navigation'),
          value: _downloadState.isOffline,
          onChanged: (v) => setState(() {
            _downloadState.isOffline = v;
            _downloadState.wantsOfflineMaps = v;
          }),
        ),
        if (!_downloadState.isOffline)
          SwitchListTile(
            title: const Text('Download offline maps anyway'),
            subtitle: const Text('Faster and more reliable navigation'),
            value: _downloadState.wantsOfflineMaps,
            onChanged: (v) => setState(() => _downloadState.wantsOfflineMaps = v),
          ),

        // Region selection
        if (_downloadState.wantsOfflineMaps) ...[
          const SizedBox(height: 16),
          const Text('Region', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<Region>(
            value: _downloadState.selectedRegion,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Select your region',
            ),
            items: Region.all
                .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                .toList(),
            onChanged: (r) => setState(() => _downloadState.selectedRegion = r),
          ),
        ],

        const SizedBox(height: 24),

        // Download progress
        if (_downloadState.items.isNotEmpty)
          DownloadProgressWidget(items: _downloadState.items),

        const SizedBox(height: 24),

        // Start button
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _startDownloadsAndContinue,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Start Installation'),
          ),
        ),
      ],
    ),
  );
}

Widget _prerequisite(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const Icon(Icons.check_box_outline_blank, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.grey.shade300)),
      ],
    ),
  );
}

Future<void> _startDownloadsAndContinue() async {
  if (_downloadState.wantsOfflineMaps && _downloadState.selectedRegion == null) {
    _setStatus('Please select a region for offline maps');
    return;
  }

  setState(() => _isProcessing = true);
  _setStatus('Resolving releases...');

  try {
    final items = await _downloadService.buildDownloadQueue(
      channel: _downloadState.channel,
      region: _downloadState.selectedRegion,
      wantsOfflineMaps: _downloadState.wantsOfflineMaps,
    );
    setState(() => _downloadState.items = items);

    // Start downloads in background
    _downloadInBackground();

    // Move to next phase immediately
    _setPhase(InstallerPhase.physicalPrep);
  } catch (e) {
    _setStatus('Error: $e');
  } finally {
    setState(() => _isProcessing = false);
  }
}

void _downloadInBackground() async {
  try {
    await _downloadService.downloadAll(
      _downloadState.items,
      onProgress: (item, bytes, total) {
        if (mounted) setState(() {}); // Trigger rebuild to update progress
      },
    );
  } catch (e) {
    if (mounted) {
      setState(() => _downloadState.error = e.toString());
    }
  }
}
```

Add import at top of `installer_screen.dart`:
```dart
import '../widgets/download_progress.dart';
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/screens/installer_screen.dart lib/widgets/download_progress.dart
git commit -m "feat: implement Phase 0 welcome screen with channel/region selection"
```

---

## Task 8: Phases 1-4 — Physical Prep, Connect, Health Check, Battery

**Files:**
- Modify: `lib/screens/installer_screen.dart`
- Create: `lib/widgets/instruction_step.dart`
- Create: `lib/widgets/health_check_panel.dart`

- [ ] **Step 1: Create instruction step widget**

```dart
// lib/widgets/instruction_step.dart

import 'package:flutter/material.dart';

class InstructionStep extends StatelessWidget {
  const InstructionStep({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    this.isWarning = false,
    this.imagePlaceholder,
  });

  final int number;
  final String title;
  final String description;
  final bool isWarning;
  final String? imagePlaceholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isWarning ? Colors.orange.shade700 : Colors.grey.shade800,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isWarning ? Colors.orange.shade900.withOpacity(0.2) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isWarning ? Colors.orange : Colors.tealAccent,
            foregroundColor: Colors.black,
            child: Text('$number', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                if (imagePlaceholder != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(imagePlaceholder!,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create health check panel**

```dart
// lib/widgets/health_check_panel.dart

import 'package:flutter/material.dart';
import '../models/scooter_health.dart';

class HealthCheckPanel extends StatelessWidget {
  const HealthCheckPanel({super.key, required this.health});

  final ScooterHealth health;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('AUX battery charge', '${health.auxCharge ?? '?'}%', '≥ 50%', health.auxChargeOk),
          _row('CBB state of health', '${health.cbbStateOfHealth ?? '?'}%', '≥ 99%', health.cbbSohOk),
          _row('CBB charge', '${health.cbbCharge ?? '?'}%', '≥ 80%', health.cbbChargeOk),
          _row('Main battery', health.batteryPresent == true ? 'present' : 'not present', '', health.batteryPresent != null),
        ],
      ),
    );
  }

  Widget _row(String label, String value, String threshold, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error,
            size: 16,
            color: ok ? Colors.tealAccent : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(value, style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            color: ok ? Colors.tealAccent : Colors.orange,
          )),
          if (threshold.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(threshold, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Implement Phases 1-4 in installer_screen.dart**

Replace the placeholder methods:

```dart
Widget _buildPhysicalPrep() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Physical Preparation',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Prepare your scooter for USB connection.',
            style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 24),
        const InstructionStep(
          number: 1,
          title: 'Remove footwell cover',
          description: 'Use a PH2 or H4 screwdriver to remove the footwell cover screws.',
          imagePlaceholder: '[Photo: footwell cover with screw locations highlighted]',
        ),
        const InstructionStep(
          number: 2,
          title: 'Unscrew USB cable from MDB',
          description: 'Disconnect the internal DBC USB cable from the MDB board. Use a flat head or PH1 screwdriver.',
          imagePlaceholder: '[Photo: USB Mini-B connector on MDB, close-up]',
        ),
        const InstructionStep(
          number: 3,
          title: 'Connect laptop USB cable',
          description: 'Plug your USB cable into the MDB port and connect the other end to your laptop.',
        ),
        const SizedBox(height: 24),
        // Download progress (still running in background)
        if (_downloadState.items.isNotEmpty)
          DownloadProgressWidget(items: _downloadState.items),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _setPhase(InstallerPhase.mdbConnect),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Done — Detect Device'),
          ),
        ),
      ],
    ),
  );
}

Widget _buildMdbConnect() {
  // Auto-start detection when entering this phase
  if (!_isProcessing && _device == null) {
    Future.microtask(_autoConnectMdb);
  }

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Connecting to MDB',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_device == null) ...[
          const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text(_statusMessage.isEmpty ? 'Waiting for USB device...' : _statusMessage,
              style: TextStyle(color: Colors.grey.shade400)),
        ] else ...[
          Icon(Icons.check_circle, size: 48, color: Colors.tealAccent),
          const SizedBox(height: 16),
          Text('Connected: ${_device!.name}'),
        ],
      ],
    ),
  );
}

Future<void> _autoConnectMdb() async {
  if (_isProcessing) return;
  setState(() => _isProcessing = true);

  // Wait for RNDIS device
  _setStatus('Waiting for RNDIS device (VID 0525:A4A2)...');
  await _waitForDevice(DeviceMode.ethernet);

  // Install driver if Windows
  if (Platform.isWindows) {
    _setStatus('Checking RNDIS driver...');
    final driverService = DriverService();
    final installed = await driverService.isDriverInstalled();
    if (!installed) {
      _setStatus('Installing RNDIS driver...');
      await driverService.installDriver();
    }
  }

  // Configure network
  _setStatus('Configuring network...');
  await NetworkService().configureInterface();

  // SSH connect
  _setStatus('Connecting via SSH...');
  final connected = await _sshService.connectToMdb();
  if (connected) {
    _setStatus('Connected!');
    _setPhase(InstallerPhase.healthCheck);
  } else {
    _setStatus('SSH connection failed. Check cable and retry.');
  }

  setState(() => _isProcessing = false);
}

Future<void> _waitForDevice(DeviceMode mode) async {
  while (_device?.mode != mode) {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
  }
}

Widget _buildHealthCheck() {
  if (_scooterHealth == null && !_isProcessing) {
    Future.microtask(_runHealthCheck);
  }

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Health Check',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Verifying scooter readiness...',
            style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 24),
        if (_scooterHealth != null)
          SizedBox(width: 400, child: HealthCheckPanel(health: _scooterHealth!)),
        const SizedBox(height: 24),
        if (_scooterHealth != null && _scooterHealth!.allOk)
          FilledButton.icon(
            onPressed: () => _setPhase(InstallerPhase.batteryRemoval),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
          ),
        if (_scooterHealth != null && !_scooterHealth!.allOk)
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _scooterHealth = null);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
      ],
    ),
  );
}

Future<void> _runHealthCheck() async {
  setState(() => _isProcessing = true);
  try {
    final health = await _sshService.queryHealth();
    setState(() => _scooterHealth = health);
  } catch (e) {
    _setStatus('Health check failed: $e');
  } finally {
    setState(() => _isProcessing = false);
  }
}

Widget _buildBatteryRemoval() {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Battery Removal',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        if (_scooterHealth?.batteryPresent == true) ...[
          const InstructionStep(
            number: 1,
            title: 'Seatbox is opening...',
            description: 'The seatbox will open automatically.',
          ),
          const InstructionStep(
            number: 2,
            title: 'Remove the main battery',
            description: 'Lift the main battery (Fahrakku) out of the seatbox.',
          ),
          const SizedBox(height: 16),
          if (!_isProcessing)
            FilledButton(
              onPressed: _openSeatboxAndWaitForBattery,
              child: const Text('Open Seatbox'),
            ),
          if (_isProcessing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
          ],
        ] else ...[
          const Icon(Icons.check_circle, size: 48, color: Colors.tealAccent),
          const SizedBox(height: 16),
          const Text('Main battery already removed'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _setPhase(InstallerPhase.mdbToUms),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
          ),
        ],
      ],
    ),
  );
}

Future<void> _openSeatboxAndWaitForBattery() async {
  setState(() => _isProcessing = true);
  _setStatus('Opening seatbox...');
  await _sshService.openSeatbox();

  _setStatus('Waiting for battery removal...');
  while (await _sshService.isBatteryPresent()) {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
  }
  _setStatus('Battery removed!');
  setState(() {
    _scooterHealth?.batteryPresent = false;
    _isProcessing = false;
  });
  _setPhase(InstallerPhase.mdbToUms);
}
```

Add imports:
```dart
import 'dart:io';
import '../widgets/instruction_step.dart';
import '../widgets/health_check_panel.dart';
```

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze lib/`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/installer_screen.dart lib/widgets/instruction_step.dart lib/widgets/health_check_panel.dart
git commit -m "feat: implement Phases 1-4 (physical prep, connect, health, battery)"
```

---

## Task 9: Phases 5-8 — UMS, Flash, Scooter Prep, Boot

**Files:**
- Modify: `lib/screens/installer_screen.dart`

- [ ] **Step 1: Implement Phases 5-8**

Replace the placeholder methods in `installer_screen.dart`:

```dart
Widget _buildMdbToUms() {
  if (!_isProcessing && _device?.mode != DeviceMode.massStorage) {
    Future.microtask(_configureMdbUms);
  }

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Configuring MDB Bootloader',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(_statusMessage.isEmpty ? 'Preparing...' : _statusMessage,
            style: TextStyle(color: Colors.grey.shade400)),
      ],
    ),
  );
}

Future<void> _configureMdbUms() async {
  if (_isProcessing) return;
  setState(() => _isProcessing = true);

  try {
    _setStatus('Uploading bootloader tools...');
    await _sshService.configureMassStorageMode();

    _setStatus('Rebooting MDB into mass storage mode...');
    await _sshService.reboot();

    _setStatus('Waiting for UMS device...');
    await _waitForDevice(DeviceMode.massStorage);

    _setPhase(InstallerPhase.mdbFlash);
  } catch (e) {
    _setStatus('Error: $e');
  } finally {
    setState(() => _isProcessing = false);
  }
}

Widget _buildMdbFlash() {
  if (!_isProcessing && _progress == 0) {
    Future.microtask(_flashMdb);
  }

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Flashing MDB',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Two-phase write: partitions first, boot sector last.',
            style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 24),
        SizedBox(
          width: 400,
          child: Column(
            children: [
              LinearProgressIndicator(value: _progress, minHeight: 8),
              const SizedBox(height: 8),
              Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _flashMdb() async {
  if (_isProcessing) return;
  setState(() => _isProcessing = true);

  // Wait for firmware download if still in progress
  final mdbItem = _downloadState.itemOfType(DownloadItemType.mdbFirmware);
  if (mdbItem == null || !mdbItem.isComplete) {
    _setStatus('Waiting for MDB firmware download...');
    while (mdbItem == null || !mdbItem.isComplete) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }
  }

  try {
    final device = _device;
    if (device?.path == null) {
      _setStatus('Error: no device path available');
      return;
    }

    final flashService = FlashService();
    await flashService.writeTwoPhase(
      mdbItem!.localPath!,
      device!.path!,
      onProgress: (progress, message) {
        _setStatus(message, progress: progress);
      },
    );

    _setStatus('MDB flash complete!');
    await Future.delayed(const Duration(seconds: 1));
    _setPhase(InstallerPhase.scooterPrep);
  } catch (e) {
    _setStatus('Flash error: $e');
  } finally {
    setState(() => _isProcessing = false);
  }
}

Widget _buildScooterPrep() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Scooter Preparation',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('MDB firmware has been written. Now prepare for reboot.',
            style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 24),
        const InstructionStep(
          number: 1,
          title: 'Disconnect the CBB',
          description: 'The main battery must already be removed before disconnecting CBB. '
              'Failure to follow this order risks electrical damage.',
          isWarning: true,
        ),
        const InstructionStep(
          number: 2,
          title: 'Disconnect one AUX pole',
          description: 'Remove ONLY the positive pole (outermost, color-coded red) to avoid '
              'risk of inverting polarity. This will remove power from the MDB — '
              'the USB connection will disappear.',
          isWarning: true,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade900.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade700),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The USB connection will be lost when you disconnect AUX. '
                  'This is expected — the installer will wait for the MDB to reboot.',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _setPhase(InstallerPhase.mdbBoot),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Done — I disconnected CBB and AUX'),
          ),
        ),
      ],
    ),
  );
}

Widget _buildMdbBoot() {
  if (!_isProcessing) {
    Future.microtask(_waitForMdbBoot);
  }

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Waiting for MDB Boot',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const InstructionStep(
          number: 1,
          title: 'Reconnect the AUX pole',
          description: 'Reconnect the positive AUX pole. The MDB will power on and boot into LibreScoot.',
        ),
        const SizedBox(height: 16),
        Text('DBC LED: orange = starting, green = booting, off = running',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 16),
        if (_isProcessing) ...[
          const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
          const SizedBox(height: 16),
        ],
        Text(_statusMessage.isEmpty ? 'Waiting for USB device...' : _statusMessage,
            style: TextStyle(color: Colors.grey.shade400)),
      ],
    ),
  );
}

Future<void> _waitForMdbBoot() async {
  if (_isProcessing) return;
  setState(() => _isProcessing = true);

  _setStatus('Waiting for USB device...');
  // Wait for any device to appear
  while (_device == null) {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
  }

  if (_device?.mode == DeviceMode.massStorage) {
    _setStatus('MDB still in UMS mode — flash may not have taken. Retrying...');
    setState(() => _isProcessing = false);
    _setPhase(InstallerPhase.mdbFlash);
    return;
  }

  // RNDIS mode — MDB is booting into LibreScoot
  _setStatus('MDB detected in network mode. Waiting for stable connection...');

  // Ping until stable for 10 consecutive seconds
  var stableCount = 0;
  while (stableCount < 10) {
    final reachable = await _pingMdb();
    if (reachable) {
      stableCount++;
      _setStatus('Ping stable: $stableCount/10');
    } else {
      stableCount = 0;
      _setStatus('Waiting for stable connection...');
    }
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
  }

  // Re-establish SSH
  _setStatus('Reconnecting SSH...');
  await NetworkService().configureInterface();
  final connected = await _sshService.connectToMdb();
  if (connected) {
    _setPhase(InstallerPhase.cbbReconnect);
  } else {
    _setStatus('SSH reconnection failed. Please check the connection.');
  }

  setState(() => _isProcessing = false);
}

Future<bool> _pingMdb() async {
  try {
    final result = await Process.run('ping', [
      if (Platform.isWindows) ...['-n', '1', '-w', '1000'] else ...['-c', '1', '-W', '1'],
      '192.168.7.1',
    ]);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/installer_screen.dart
git commit -m "feat: implement Phases 5-8 (UMS, flash, scooter prep, boot)"
```

---

## Task 10: Phases 9-13 — CBB, DBC Prep, Flash, Reconnect, Finish

**Files:**
- Modify: `lib/screens/installer_screen.dart`

- [ ] **Step 1: Implement Phases 9-13**

Replace remaining placeholder methods:

```dart
Widget _buildCbbReconnect() {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Reconnect CBB',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        const InstructionStep(
          number: 1,
          title: 'Reconnect the CBB',
          description: 'Plug the CBB cable back in. This provides more power for the DBC flash.',
        ),
        const SizedBox(height: 16),
        if (_isProcessing) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 8),
          Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
        ] else
          FilledButton(
            onPressed: _waitForCbb,
            child: const Text('Verify CBB Connection'),
          ),
      ],
    ),
  );
}

Future<void> _waitForCbb() async {
  setState(() => _isProcessing = true);
  _setStatus('Checking CBB...');

  var attempts = 0;
  while (attempts < 30) {
    if (await _sshService.isCbbPresent()) {
      _setStatus('CBB connected!');
      await Future.delayed(const Duration(seconds: 1));
      _setPhase(InstallerPhase.dbcPrep);
      setState(() => _isProcessing = false);
      return;
    }
    attempts++;
    _setStatus('Waiting for CBB... ($attempts)');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
  }

  _setStatus('CBB not detected. Please check the connection.');
  setState(() => _isProcessing = false);
}

Widget _buildDbcPrep() {
  if (!_isProcessing && _progress == 0) {
    Future.microtask(_uploadDbcFiles);
  }

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Preparing DBC Flash',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          width: 400,
          child: Column(
            children: [
              LinearProgressIndicator(value: _progress, minHeight: 8),
              const SizedBox(height: 8),
              Text(_statusMessage, style: TextStyle(color: Colors.grey.shade400)),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _uploadDbcFiles() async {
  if (_isProcessing) return;
  setState(() => _isProcessing = true);

  // Wait for all downloads to complete
  if (!_downloadState.allReady) {
    _setStatus('Waiting for downloads to complete...');
    while (!_downloadState.allReady) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() {});
      if (!mounted) return;
    }
  }

  try {
    final trampolineService = TrampolineService(_sshService);

    final dbcItem = _downloadState.itemOfType(DownloadItemType.dbcFirmware);
    final osmItem = _downloadState.itemOfType(DownloadItemType.osmTiles);
    final valhallaItem = _downloadState.itemOfType(DownloadItemType.valhallaTiles);

    await trampolineService.uploadAll(
      dbcImageLocalPath: dbcItem!.localPath!,
      osmTilesLocalPath: osmItem?.localPath,
      valhallaTilesLocalPath: valhallaItem?.localPath,
      region: _downloadState.selectedRegion,
      onProgress: (status, progress) {
        _setStatus(status, progress: progress);
      },
    );

    _setStatus('Starting trampoline script...');
    await trampolineService.start();

    await Future.delayed(const Duration(seconds: 1));
    _setPhase(InstallerPhase.dbcFlash);
  } catch (e) {
    _setStatus('Upload error: $e');
  } finally {
    setState(() => _isProcessing = false);
  }
}

Widget _buildDbcFlash() {
  return SingleChildScrollView(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DBC Flash in Progress',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const InstructionStep(
            number: 1,
            title: 'Disconnect USB from laptop',
            description: 'Unplug the USB cable from your laptop.',
          ),
          const InstructionStep(
            number: 2,
            title: 'Reconnect DBC USB cable to MDB',
            description: 'Screw the internal DBC USB cable back into the MDB port.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text('The MDB is now flashing the DBC autonomously.',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Watch the scooter lights for progress:',
                    style: TextStyle(color: Colors.grey.shade400)),
                const SizedBox(height: 8),
                _ledSignal('Front ring on (constant)', 'Working'),
                _ledSignal('Position lights on', 'DBC connected / flashing'),
                _ledSignal('Boot LED green', 'Success — reconnect laptop'),
                _ledSignal('Hazard flashers', 'Error — reconnect laptop to see log'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _setPhase(InstallerPhase.reconnect),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Boot LED is green — Reconnect Laptop'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _setPhase(InstallerPhase.reconnect),
            icon: const Icon(Icons.warning, color: Colors.orange),
            label: const Text('Hazard flashers — Check Error'),
          ),
        ],
      ),
    ),
  );
}

Widget _ledSignal(String signal, String meaning) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const SizedBox(width: 8),
        const Icon(Icons.circle, size: 8, color: Colors.tealAccent),
        const SizedBox(width: 8),
        Expanded(child: Text(signal, style: const TextStyle(fontSize: 13))),
        Text(meaning, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ],
    ),
  );
}

Widget _buildReconnect() {
  if (!_isProcessing) {
    Future.microtask(_verifyDbcFlash);
  }

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Verifying DBC Installation',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_isProcessing) ...[
          const SizedBox(width: 48, height: 48, child: CircularProgressIndicator()),
          const SizedBox(height: 16),
        ],
        Text(_statusMessage.isEmpty ? 'Reconnect USB to laptop...' : _statusMessage,
            style: TextStyle(color: Colors.grey.shade400)),
      ],
    ),
  );
}

Future<void> _verifyDbcFlash() async {
  if (_isProcessing) return;
  setState(() => _isProcessing = true);

  _setStatus('Waiting for RNDIS device...');
  await _waitForDevice(DeviceMode.ethernet);

  _setStatus('Configuring network...');
  await NetworkService().configureInterface();

  _setStatus('Connecting SSH...');
  final connected = await _sshService.connectToMdb();
  if (!connected) {
    _setStatus('SSH connection failed.');
    setState(() => _isProcessing = false);
    return;
  }

  _setStatus('Reading trampoline status...');
  final status = await _sshService.readTrampolineStatus();

  if (status.result == TrampolineResult.success) {
    _setStatus('DBC flash successful!');
    await Future.delayed(const Duration(seconds: 2));
    _setPhase(InstallerPhase.finish);
  } else if (status.result == TrampolineResult.error) {
    _setStatus('DBC flash failed: ${status.message}');
    // Show error log in a dialog
    if (mounted && status.errorLog != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('DBC Flash Error'),
          content: SingleChildScrollView(
            child: SelectableText(status.errorLog!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    }
  } else {
    _setStatus('Trampoline status unknown. Check /data/trampoline.log on MDB.');
  }

  setState(() => _isProcessing = false);
}

Widget _buildFinish() {
  return SingleChildScrollView(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration, size: 64, color: Colors.tealAccent),
          const SizedBox(height: 16),
          const Text('Welcome to LibreScoot!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
          const SizedBox(height: 24),
          const Text('Final steps:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          const InstructionStep(
            number: 1,
            title: 'Disconnect USB from laptop',
            description: 'Unplug the USB cable from your laptop.',
          ),
          const InstructionStep(
            number: 2,
            title: 'Reconnect DBC USB cable',
            description: 'Screw the internal DBC USB cable back into MDB.',
          ),
          const InstructionStep(
            number: 3,
            title: 'Insert main battery',
            description: 'Place the main battery back into the seatbox.',
          ),
          const InstructionStep(
            number: 4,
            title: 'Close seatbox and footwell',
            description: 'Close the seatbox and replace the footwell cover.',
          ),
          const InstructionStep(
            number: 5,
            title: 'Unlock your scooter',
            description: 'Keycard and Bluetooth pairing will be set up during LibreScoot first run.',
          ),
          const SizedBox(height: 24),
          if (_downloadState.items.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _offerCleanup,
              icon: const Icon(Icons.delete_outline),
              label: Text('Delete cached downloads (${_totalCacheSizeMb()} MB)'),
            ),
        ],
      ),
    ),
  );
}

String _totalCacheSizeMb() {
  final total = _downloadState.items.fold<int>(0, (sum, i) => sum + i.expectedSize);
  return (total / 1024 / 1024).toStringAsFixed(0);
}

Future<void> _offerCleanup() async {
  final freed = await _downloadService.deleteCache(_downloadState.items);
  if (mounted) {
    _setStatus('Deleted ${(freed / 1024 / 1024).toStringAsFixed(0)} MB');
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/installer_screen.dart
git commit -m "feat: implement Phases 9-13 (CBB, DBC prep/flash, reconnect, finish)"
```

---

## Task 11: Integration & Polish

**Files:**
- Modify: `lib/screens/installer_screen.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add resume detection on startup**

Add to `_InstallerScreenState.initState()`, after existing init:

```dart
// Check for resume
Future.microtask(_detectResumeState);
```

Add method:
```dart
Future<void> _detectResumeState() async {
  // Check what USB device is currently connected
  await Future.delayed(const Duration(seconds: 2)); // Give USB detector time
  if (_device == null) return; // No device — start from beginning

  if (_device!.mode == DeviceMode.massStorage) {
    // MDB in UMS mode — resume from flash
    _setPhase(InstallerPhase.mdbFlash);
  } else if (_device!.mode == DeviceMode.ethernet) {
    // MDB in RNDIS — check if LibreScoot or stock
    try {
      await NetworkService().configureInterface();
      final connected = await _sshService.connectToMdb();
      if (connected) {
        final version = await _sshService.detectFirmwareVersion();
        if (version?.contains('librescoot') == true) {
          // LibreScoot already running — resume from CBB reconnect or later
          _setPhase(InstallerPhase.cbbReconnect);
        }
      }
    } catch (_) {
      // Ignore — stay at welcome
    }
  }
}
```

- [ ] **Step 2: Verify the full app compiles and runs**

Run: `flutter analyze lib/`
Run: `flutter run -d macos` (or available platform)
Expected: App launches, shows sidebar, welcome screen with channel/region selection.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/installer_screen.dart
git commit -m "feat: add resume detection on startup"
```

- [ ] **Step 4: Final cleanup — remove old home_screen import from main.dart if present**

Verify `lib/main.dart` imports `installer_screen.dart` and not `home_screen.dart`.

- [ ] **Step 5: Commit if changed**

```bash
git add lib/main.dart
git commit -m "chore: ensure main.dart uses InstallerScreen"
```

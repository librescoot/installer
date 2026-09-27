import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/models/local_tile_selection.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/services/download_service.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory dir;
  late File map;
  late File routing;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('local-tile-queue-');
    DownloadService.cacheDirOverride = Directory(path.join(dir.path, 'cache'));
    map = File(path.join(dir.path, 'tiles_custom.mbtiles'));
    routing = File(path.join(dir.path, 'valhalla_tiles_custom.tar.zst'));
    await map.writeAsBytes([...ascii.encode('SQLite format 3\u0000'), 1]);
    await routing.writeAsBytes([1, 2, 3]);
  });
  tearDown(() async {
    DownloadService.cacheDirOverride = null;
    await dir.delete(recursive: true);
  });

  http_testing.MockClient client(List<String> requested) =>
      http_testing.MockClient((request) async {
        requested.add(request.url.path);
        if (request.url.path.endsWith('latest.json')) {
          return http.Response(
            jsonEncode({
              'stable': {'tag_name': 'v1.4.2', 'assets': <Object>[]},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('maps-routing.json')) {
          return http.Response(
            jsonEncode({
              'version': 1,
              'regions': {
                'graz': {
                  'map': {
                    'url': 'https://example.com/tiles_graz.mbtiles',
                    'size': 10,
                  },
                  'routing': {
                    'url': 'https://example.com/valhalla_tiles_graz.tar',
                    'size': 20,
                  },
                },
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

  test(
    'a complete pair skips tile manifests and is never deleted as cache',
    () async {
      final requested = <String>[];
      final service = DownloadService(client: client(requested));
      addTearDown(service.dispose);
      final selection = LocalTileSelection.fromPaths(
        mapPath: map.path,
        routingPath: routing.path,
      );
      final items = await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        region: Region.fromSlug('custom'),
        wantsOfflineMaps: true,
        localTiles: selection,
      );
      expect(requested, ['/releases/latest.json']);
      expect(items.map((item) => item.type), [
        DownloadItemType.osmTiles,
        DownloadItemType.valhallaTiles,
      ]);
      expect(
        items.every((item) => item.userProvided && item.isComplete),
        isTrue,
      );
      await service.downloadAll(items);
      expect(await service.deleteCache(items), 0);
      expect(await map.exists(), isTrue);
      expect(await routing.exists(), isTrue);
    },
  );

  test('one local file replaces only its own download', () async {
    final requested = <String>[];
    final service = DownloadService(client: client(requested));
    addTearDown(service.dispose);
    final grazMap = await map.rename(path.join(dir.path, 'tiles_graz.mbtiles'));
    final items = await service.buildDownloadQueue(
      channel: DownloadChannel.stable,
      region: Region.fromSlug('graz'),
      wantsOfflineMaps: true,
      localTiles: LocalTileSelection.fromPaths(mapPath: grazMap.path),
    );
    expect(requested, contains('/releases/maps-routing.json'));
    expect(items.map((item) => item.filename), [
      'tiles_graz.mbtiles',
      'valhalla_tiles_graz.tar',
    ]);
    expect(items.first.userProvided, isTrue);
    expect(items.last.userProvided, isFalse);
    expect(items.last.isComplete, isFalse);
  });
}

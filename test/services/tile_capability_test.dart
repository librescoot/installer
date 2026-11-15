import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/services/download_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'compressed routing requires an explicit supported codec and digest',
    () async {
      final valid = <String, dynamic>{
        'codec': 'zstd',
        'url': 'https://example.test/valhalla_tiles_graz.tar.zst',
        'size': 80,
        'sha256': 'a' * 64,
      };
      final cases = <(String, Map<String, dynamic>, bool)>[
        ('valid', Map.of(valid), true),
        ('missing codec', Map.of(valid)..remove('codec'), false),
        ('unknown codec', Map.of(valid)..['codec'] = 'future', false),
        (
          'declared requirement',
          Map.of(valid)..['requires'] = ['routing-compressed.format.zstd'],
          false,
        ),
        (
          'unknown requirement',
          Map.of(valid)
            ..['requires'] = [
              'routing-compressed.format.zstd',
              'future.decoder',
            ],
          false,
        ),
        ('missing requirement', Map.of(valid)..['requires'] = [], false),
        (
          'case alias requirement',
          Map.of(valid)..['Requires'] = ['future.decoder'],
          false,
        ),
        ('missing hash', Map.of(valid)..remove('sha256'), false),
        ('malformed hash', Map.of(valid)..['sha256'] = 'abc', false),
        ('zero size', Map.of(valid)..['size'] = 0, false),
        (
          'wrong region',
          Map.of(valid)
            ..['url'] = 'https://example.test/valhalla_tiles_vienna.tar.zst',
          false,
        ),
        (
          'insecure url',
          Map.of(valid)
            ..['url'] = 'http://example.test/valhalla_tiles_graz.tar.zst',
          false,
        ),
      ];
      for (final (name, compressed, useCompressed) in cases) {
        final dir = await Directory.systemTemp.createTemp('tile-capabilities-');
        DownloadService.cacheDirOverride = Directory(p.join(dir.path, 'cache'));
        final manifest = {
          'version': 1,
          'regions': {
            'graz': {
              'map': {
                'url': 'https://example.test/tiles_graz.mbtiles',
                'size': 100,
              },
              'routing': {
                'url': 'https://example.test/valhalla_tiles_graz.tar',
                'size': 200,
                'compressed': compressed,
              },
            },
          },
        };
        final client = MockClient((request) async {
          if (request.url.path == '/releases/latest.json') {
            return http.Response(
              jsonEncode({
                'stable': {'tag_name': 'v1.4.2', 'assets': []},
              }),
              200,
            );
          }
          if (request.url.path == '/releases/maps-routing.json') {
            return http.Response(jsonEncode(manifest), 200);
          }
          return http.Response('not found', 404);
        });
        final service = DownloadService(client: client);
        final items = await service.buildDownloadQueue(
          channel: DownloadChannel.stable,
          region: Region.fromSlug('graz'),
          wantsOfflineMaps: true,
        );
        final routing = items.singleWhere(
          (item) => item.type == DownloadItemType.valhallaTiles,
        );
        expect(
          routing.filename,
          useCompressed
              ? 'valhalla_tiles_graz.tar.zst'
              : 'valhalla_tiles_graz.tar',
          reason: name,
        );
        service.dispose();
        DownloadService.cacheDirOverride = null;
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'unknown full tile requirements do not fall back to legacy indexes',
    () async {
      for (final (kind, key) in [
        ('map', 'requires'),
        ('routing', 'requires'),
        ('map', 'Requires'),
        ('routing', 'Requires'),
      ]) {
        final dir = await Directory.systemTemp.createTemp('tile-capabilities-');
        DownloadService.cacheDirOverride = Directory(p.join(dir.path, 'cache'));
        final map = <String, dynamic>{
          'url': 'https://example.test/tiles_graz.mbtiles',
          'size': 100,
        };
        final routing = <String, dynamic>{
          'url': 'https://example.test/valhalla_tiles_graz.tar',
          'size': 200,
        };
        (kind == 'map' ? map : routing)[key] = ['future.format'];
        final manifest = {
          'version': 1,
          'regions': {
            'graz': {'map': map, 'routing': routing},
          },
        };
        final requested = <String>[];
        final service = DownloadService(
          client: MockClient((request) async {
            requested.add(request.url.path);
            if (request.url.path == '/releases/latest.json') {
              return http.Response(
                jsonEncode({
                  'stable': {'tag_name': 'v1.4.2', 'assets': []},
                }),
                200,
              );
            }
            if (request.url.path == '/releases/maps-routing.json') {
              return http.Response(jsonEncode(manifest), 200);
            }
            return http.Response('not found', 404);
          }),
        );
        await expectLater(
          service.buildDownloadQueue(
            channel: DownloadChannel.stable,
            region: Region.fromSlug('graz'),
            wantsOfflineMaps: true,
          ),
          throwsA(isA<UnsupportedTileCapabilities>()),
        );
        expect(
          requested.where(
            (p) =>
                p.endsWith('/osm-tiles.json') ||
                p.endsWith('/valhalla-tiles.json'),
          ),
          isEmpty,
        );
        expect(await service.fetchAvailableRegions(), isEmpty);
        service.dispose();
        DownloadService.cacheDirOverride = null;
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'index and region requirements fail closed, including aliases',
    () async {
      for (final (level, key) in [
        ('index', 'requires'),
        ('index', 'Requires'),
        ('region', 'requires'),
        ('region', 'Requires'),
      ]) {
        final dir = await Directory.systemTemp.createTemp('tile-capabilities-');
        final cache = Directory(p.join(dir.path, 'cache'));
        DownloadService.cacheDirOverride = cache;
        await cache.create(recursive: true);
        final manifest = <String, dynamic>{
          'version': 1,
          'regions': <String, dynamic>{
            'graz': <String, dynamic>{
              'map': {
                'url': 'https://example.test/tiles_graz.mbtiles',
                'size': 100,
              },
              'routing': {
                'url': 'https://example.test/valhalla_tiles_graz.tar',
                'size': 200,
              },
            },
          },
        };
        final oldCache = File(p.join(cache.path, 'maps-routing.json'));
        await oldCache.writeAsString(jsonEncode(manifest));
        await oldCache.setLastModified(
          DateTime.now().subtract(const Duration(hours: 2)),
        );
        final regions = manifest['regions'] as Map;
        final region = Map<String, dynamic>.from(regions['graz'] as Map);
        regions['graz'] = region;
        (level == 'index' ? manifest : region)[key] = ['future.format'];
        final requested = <String>[];
        final service = DownloadService(
          client: MockClient((request) async {
            requested.add(request.url.path);
            if (request.url.path == '/releases/latest.json') {
              return http.Response(
                jsonEncode({
                  'stable': {'tag_name': 'v1.4.2', 'assets': []},
                }),
                200,
              );
            }
            if (request.url.path == '/releases/maps-routing.json') {
              return http.Response(jsonEncode(manifest), 200);
            }
            return http.Response('not found', 404);
          }),
        );
        await expectLater(
          service.buildDownloadQueue(
            channel: DownloadChannel.stable,
            region: Region.fromSlug('graz'),
            wantsOfflineMaps: true,
          ),
          throwsA(isA<UnsupportedTileCapabilities>()),
          reason: '$level $key',
        );
        if (level == 'index') {
          await expectLater(
            service.fetchAvailableRegions(),
            throwsA(isA<UnsupportedTileCapabilities>()),
          );
        } else {
          expect(await service.fetchAvailableRegions(), isEmpty);
        }
        expect(
          requested.where(
            (path) =>
                path.endsWith('/osm-tiles.json') ||
                path.endsWith('/valhalla-tiles.json'),
          ),
          isEmpty,
        );
        service.dispose();
        DownloadService.cacheDirOverride = null;
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'stale cache with index requirements cannot fall back offline',
    () async {
      final dir = await Directory.systemTemp.createTemp('tile-capabilities-');
      final cache = Directory(p.join(dir.path, 'cache'));
      DownloadService.cacheDirOverride = cache;
      await cache.create(recursive: true);
      final oldCache = File(p.join(cache.path, 'maps-routing.json'));
      await oldCache.writeAsString(
        jsonEncode({
          'version': 1,
          'Requires': ['future.format'],
          'regions': {},
        }),
      );
      await oldCache.setLastModified(
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      final service = DownloadService(
        client: MockClient((request) async => http.Response('offline', 503)),
      );
      await expectLater(
        service.fetchAvailableRegions(),
        throwsA(isA<UnsupportedTileCapabilities>()),
      );
      service.dispose();
      DownloadService.cacheDirOverride = null;
      await dir.delete(recursive: true);
    },
  );

  test('duplicate map requirements are rejected', () async {
    final dir = await Directory.systemTemp.createTemp('tile-capabilities-');
    DownloadService.cacheDirOverride = Directory(p.join(dir.path, 'cache'));
    final service = DownloadService(
      client: MockClient(
        (request) async => http.Response(
          r'{"version":1,"regions":{"graz":{"routing":{"requires":["future"],"requires":[]}}}}',
          200,
        ),
      ),
    );
    await expectLater(service.resolveMapsRouting(), throwsFormatException);
    service.dispose();
    DownloadService.cacheDirOverride = null;
    await dir.delete(recursive: true);
  });
}

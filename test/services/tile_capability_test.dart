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
}

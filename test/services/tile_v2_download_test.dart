import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/services/download_service.dart';
import 'package:librescoot_installer/services/tile_capability_policy.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'v2 selection is bound to the exact DBC artifact and never falls back',
    () async {
      final artifact = 'd' * 64;
      final caps = {
        'map.format.mbtiles-mvt-v1',
        'routing.format.valhalla-3.6.3',
      };
      for (final mode in [
        'valid',
        'official-release',
        'official-full-image',
        'unknown',
        'wrong-region',
        'alias',
        'missing-requirements',
        'insecure-url',
        'bad-digest',
        'duplicate-json',
        'unavailable',
        'unqualified',
      ]) {
        final tag = mode == 'official-release' || mode == 'official-full-image'
            ? 'v1.4.3'
            : 'v1.4.2';
        final dir = await Directory.systemTemp.createTemp('map-v2-');
        DownloadService.cacheDirOverride = Directory(p.join(dir.path, 'cache'));
        final requested = <String>[];
        final map = <String, dynamic>{
          'url': 'https://example.test/tiles_graz.mbtiles',
          'size': 100,
          'sha256': 'a' * 64,
          'kind': 'map',
          'region': 'graz',
          'format': 'mbtiles-mvt-v1',
          'requires': ['map.format.mbtiles-mvt-v1'],
        };
        final routing = <String, dynamic>{
          'url': 'https://example.test/valhalla_tiles_graz.tar',
          'size': 200,
          'sha256': 'b' * 64,
          'kind': 'routing',
          'region': 'graz',
          'format': 'valhalla-3.6.3',
          'requires': ['routing.format.valhalla-3.6.3'],
          'compressed': {
            'url': 'https://example.test/valhalla_tiles_graz.tar.zst',
          },
        };
        if (mode == 'alias') map['Requires'] = ['future.format'];
        if (mode == 'missing-requirements') map.remove('requires');
        if (mode == 'insecure-url') {
          map['url'] = 'http://example.test/tiles_graz.mbtiles';
        }
        if (mode == 'bad-digest') map['sha256'] = 'invalid';
        if (mode == 'unknown') {
          map['requires'] = ['map.format.mbtiles-mvt-v1', 'future.format'];
        }
        if (mode == 'wrong-region') routing['region'] = 'vienna';
        final service = DownloadService(
          tileCapabilitiesByArtifact: {
            if (mode != 'unqualified' &&
                mode != 'official-release' &&
                mode != 'official-full-image')
              artifact: caps,
          },
          client: MockClient((request) async {
            requested.add(request.url.path);
            if (request.url.path == '/releases/latest.json') {
              return http.Response(
                jsonEncode({
                  'stable': {
                    'tag_name': tag,
                    'assets': [
                      {
                        'name': mode == 'official-full-image'
                            ? 'librescoot-unu-dbc-$tag.sdimg.gz'
                            : 'librescoot-unu-dbc-$tag.mender',
                        'url': 'https://example.test/dbc.mender',
                        'size': 1000,
                        'sha256': artifact,
                      },
                    ],
                  },
                }),
                200,
              );
            }
            if (request.url.path == '/releases/v2/maps-routing.json') {
              if (mode == 'unavailable') return http.Response('missing', 404);
              if (mode == 'duplicate-json') {
                return http.Response(
                  r'{"version":2,"regions":{},"regions":{}}',
                  200,
                );
              }
              return http.Response(
                jsonEncode({
                  'version': 2,
                  'regions': {
                    'graz': {'map': map, 'routing': routing},
                  },
                }),
                200,
              );
            }
            if (request.url.path == '/releases/maps-routing.json') {
              return http.Response(
                jsonEncode({
                  'version': 1,
                  'regions': {
                    'graz': {
                      'map': {'url': map['url'], 'size': 100},
                      'routing': {'url': routing['url'], 'size': 200},
                    },
                  },
                }),
                200,
              );
            }
            return http.Response('missing', 404);
          }),
        );
        final queue = service.buildDownloadQueue(
          channel: DownloadChannel.stable,
          region: Region.fromSlug('graz'),
          wantsOfflineMaps: true,
          fullImageBoards: mode == 'official-full-image' ? {Board.dbc} : {},
        );
        if (mode == 'valid' ||
            mode == 'official-full-image' ||
            mode == 'official-release' ||
            mode == 'unqualified') {
          final items = await queue;
          expect(
            items
                .singleWhere((item) => item.type == DownloadItemType.osmTiles)
                .filename,
            'tiles_graz.mbtiles',
          );
          expect(
            items
                .singleWhere(
                  (item) => item.type == DownloadItemType.valhallaTiles,
                )
                .filename,
            'valhalla_tiles_graz.tar',
          );
        } else {
          await expectLater(
            queue,
            throwsA(
              mode == 'unavailable'
                  ? isA<Exception>()
                  : mode == 'duplicate-json'
                  ? isA<FormatException>()
                  : isA<UnsupportedTileCapabilities>(),
            ),
            reason: mode,
          );
        }
        expect(
          requested.contains('/releases/v2/maps-routing.json'),
          mode != 'unqualified',
          reason: mode,
        );
        expect(
          requested.contains('/releases/maps-routing.json'),
          mode == 'unqualified',
          reason: mode,
        );
        service.dispose();
        DownloadService.cacheDirOverride = null;
        await dir.delete(recursive: true);
      }
    },
  );

  test('real producer fixture matches installer capability policy', () async {
    final path = Platform.environment['LIBRESCOOT_MAP_V2_FIXTURE'];
    if (path == null || path.isEmpty) return;
    final index =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    final region =
        (index['regions'] as Map<String, dynamic>)['graz']
            as Map<String, dynamic>;
    final caps = {'map.format.mbtiles-mvt-v1', 'routing.format.valhalla-3.6.3'};
    expect(
      TileCapabilityPolicy.eligibleFull(
        region['map'] as Map<String, dynamic>,
        'map',
        'graz',
        caps,
      ),
      isTrue,
    );
    expect(
      TileCapabilityPolicy.eligibleFull(
        region['routing'] as Map<String, dynamic>,
        'routing',
        'graz',
        caps,
      ),
      isTrue,
    );
  });
}

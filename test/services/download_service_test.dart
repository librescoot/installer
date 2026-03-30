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

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

  group('regionsFromAssets', () {
    List<Map<String, dynamic>> assets(List<String> names) =>
        names.map((n) => <String, dynamic>{'name': n}).toList();

    test('returns the intersection of osm and valhalla slugs', () {
      final regions = DownloadService.regionsFromAssets(
        assets([
          'tiles_bayern.mbtiles',
          'tiles_hessen.mbtiles',
          'tiles_belgium.mbtiles',
          'Custom Shortbread Tiles - June 2026',
        ]),
        assets([
          'valhalla_tiles_bayern.tar',
          'valhalla_tiles_belgium.tar',
          'valhalla_tiles_netherlands.tar',
        ]),
      );
      // Only bayern and belgium appear in both listings.
      expect(regions.map((r) => r.slug), ['bayern', 'belgium']);
    });

    test('orders by catalogue (German first) then unknown slugs', () {
      final regions = DownloadService.regionsFromAssets(
        assets([
          'tiles_zzz-unknown.mbtiles',
          'tiles_belgium.mbtiles',
          'tiles_bayern.mbtiles',
        ]),
        assets([
          'valhalla_tiles_zzz-unknown.tar',
          'valhalla_tiles_belgium.tar',
          'valhalla_tiles_bayern.tar',
        ]),
      );
      expect(regions.map((r) => r.slug), ['bayern', 'belgium', 'zzz-unknown']);
      expect(regions.last.country, 'Weitere');
    });
  });

  group('Region.detectSlugFromIp', () {
    test('maps a German region_code to its slug', () async {
      final client = http_testing.MockClient((request) async {
        expect(request.url.host, 'ipwho.is');
        return http.Response(
            jsonEncode({
              'success': true,
              'country_code': 'DE',
              'region_code': 'BY',
            }),
            200);
      });
      expect(await Region.detectSlugFromIp(client: client), 'bayern');
    });

    test('collapses Berlin and Brandenburg to the combined region', () async {
      for (final code in ['BE', 'BB']) {
        final client = http_testing.MockClient((request) async => http.Response(
            jsonEncode({
              'success': true,
              'country_code': 'DE',
              'region_code': code,
            }),
            200));
        expect(await Region.detectSlugFromIp(client: client),
            'berlin_brandenburg');
      }
    });

    Future<String?> detect(String country, String? region) {
      final client = http_testing.MockClient((request) async => http.Response(
          jsonEncode({
            'success': true,
            'country_code': country,
            if (region != null) 'region_code': region,
          }),
          200));
      return Region.detectSlugFromIp(client: client);
    }

    test('maps neighbour subdivisions to their region', () async {
      expect(await detect('FR', 'IDF'), 'ile-de-france');
      expect(await detect('IT', '25'), 'italy-nord-ovest'); // Lombardy
      expect(await detect('IT', '21'), 'italy-nord-ovest'); // Piedmont
    });

    test('maps fully-covered countries regardless of subdivision', () async {
      expect(await detect('BE', 'VBR'), 'belgium');
      expect(await detect('NL', 'ZH'), 'netherlands');
      expect(await detect('LU', 'LU'), 'luxembourg');
      expect(await detect('NL', null), 'netherlands'); // country default
    });

    test('returns null for uncovered subdivisions and countries', () async {
      expect(await detect('FR', 'HDF'), isNull); // Hauts-de-France: no tiles
      expect(await detect('IT', '72'), isNull); // Campania: not northwest
      expect(await detect('US', 'CA'), isNull);
    });

    test('returns null when the lookup is unsuccessful', () async {
      final client = http_testing.MockClient((request) async =>
          http.Response(jsonEncode({'success': false}), 200));
      expect(await Region.detectSlugFromIp(client: client), isNull);
    });
  });
}

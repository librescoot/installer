import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/services/download_service.dart';
import 'package:path/path.dart' as p;

/// One release asset as it appears in the downloads.librescoot.org manifest.
/// Firmware downloads read `url`; tiles read `browser_download_url`.
Map<String, dynamic> _asset(String name, int size, {String? sha256}) => {
      'name': name,
      'size': size,
      'url': 'https://example.com/$name',
      'browser_download_url': 'https://example.com/$name',
      if (sha256 != null) 'sha256': sha256,
    };

Map<String, dynamic> _release(
  String tag,
  List<Map<String, dynamic>> assets, {
  String publishedAt = '2026-01-01T00:00:00Z',
}) =>
    {'tag_name': tag, 'published_at': publishedAt, 'assets': assets};

/// MockClient that serves the given per-channel manifest from latest.json and
/// 404s everything else.
http_testing.MockClient _manifestClient(Map<String, dynamic> channels) =>
    http_testing.MockClient((request) async {
      if (request.url.path.endsWith('latest.json')) {
        return http.Response(jsonEncode(channels), 200);
      }
      return http.Response('Not found', 404);
    });

void main() {
  group('DownloadService', () {
    // _fetchLatest caches the manifest on disk (shared across instances), so
    // clear it before each test to keep them reading their own mock.
    setUp(() async {
      final dir = await DownloadService.getCacheDir();
      final cache = File(p.join(dir.path, 'latest.json'));
      if (await cache.exists()) await cache.delete();
    });

    test('resolveRelease finds the requested channel', () async {
      final service = DownloadService(
        client: _manifestClient({
          'nightly': _release('nightly-20260330T013130', [
            _asset('librescoot-unu-mdb-nightly-20260330T013130.sdimg.gz', 141215162),
            _asset('librescoot-unu-dbc-nightly-20260330T013130.sdimg.gz', 197006162),
          ]),
          'testing': _release('testing-20260318T114803', [
            _asset('librescoot-unu-mdb-testing-20260318T114803.sdimg.gz', 140000000),
            _asset('librescoot-unu-dbc-testing-20260318T114803.sdimg.gz', 196000000),
          ]),
        }),
      );
      final result = await service.resolveRelease(DownloadChannel.testing);
      expect(result.tag, 'testing-20260318T114803');
      expect(result.assets.length, 2);
    });

    test('resolveRelease throws when the channel is absent', () async {
      final service = DownloadService(
        client: _manifestClient({
          'testing': _release('testing-20260318T114803', [
            _asset('librescoot-unu-mdb-testing-20260318T114803.sdimg.gz', 140000000),
          ]),
        }),
      );
      expect(() => service.resolveRelease(DownloadChannel.stable),
          throwsA(isA<Exception>()));
    });

    test('fetchAvailableChannels reports only channels in the manifest', () async {
      final service = DownloadService(
        client: _manifestClient({
          'testing': _release('testing-20260318T114803', [],
              publishedAt: '2026-03-18T11:48:03Z'),
          'nightly': _release('nightly-20260330T013130', [],
              publishedAt: '2026-03-30T01:31:30Z'),
        }),
      );
      final channels = await service.fetchAvailableChannels();
      expect(channels.containsKey(DownloadChannel.stable), isFalse);
      expect(channels.keys,
          containsAll([DownloadChannel.testing, DownloadChannel.nightly]));
      expect(channels[DownloadChannel.testing]!.tag, 'testing-20260318T114803');
      expect(channels[DownloadChannel.testing]!.date, '2026-03-18');
    });

    test('buildDownloadQueue filters to unu firmware variants only', () async {
      final service = DownloadService(
        client: _manifestClient({
          'testing': _release('testing-20260318T114803', [
            _asset('librescoot-unu-mdb-testing-20260318T114803.sdimg.gz', 100),
            _asset('librescoot-unu-dbc-testing-20260318T114803.sdimg.gz', 200),
            _asset('librescoot-unu-mdb-testing-20260318T114803.mender', 300),
            _asset('librescoot-other-mdb-testing-20260318T114803.sdimg.gz', 400),
          ]),
        }),
      );
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
    test('maps a German subdivision code to its slug', () async {
      final client = http_testing.MockClient((request) async {
        expect(request.url.host, 'ip-api.com');
        return http.Response(
            jsonEncode({
              'status': 'success',
              'countryCode': 'DE',
              'region': 'BY',
            }),
            200);
      });
      expect(await Region.detectSlugFromIp(client: client), 'bayern');
    });

    test('collapses Berlin and Brandenburg to the combined region', () async {
      for (final code in ['BE', 'BB']) {
        final client = http_testing.MockClient((request) async => http.Response(
            jsonEncode({
              'status': 'success',
              'countryCode': 'DE',
              'region': code,
            }),
            200));
        expect(await Region.detectSlugFromIp(client: client),
            'berlin_brandenburg');
      }
    });

    Future<String?> detect(String country, String? region) {
      final client = http_testing.MockClient((request) async => http.Response(
          jsonEncode({
            'status': 'success',
            'countryCode': country,
            if (region != null) 'region': region,
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
          http.Response(jsonEncode({'status': 'fail'}), 200));
      expect(await Region.detectSlugFromIp(client: client), isNull);
    });
  });
}

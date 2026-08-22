import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:librescoot_installer/models/board_state.dart';
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

    test('resolveTileAssets reads the per-repo manifest, not the GitHub API',
        () async {
      final dir = await DownloadService.getCacheDir();
      for (final f in ['librescoot_osm-tiles-latest.json']) {
        final c = File(p.join(dir.path, f));
        if (await c.exists()) await c.delete();
      }
      final requested = <String>[];
      final service = DownloadService(
        client: http_testing.MockClient((request) async {
          requested.add(request.url.toString());
          if (request.url.host == 'api.github.com') {
            return http.Response('should not be called', 500);
          }
          return http.Response(
            jsonEncode([
              {
                'name': 'tiles_berlin_brandenburg.mbtiles',
                'size': 208076800,
                'sha256': 'abc',
                'updated_at': '2026-08-12T16:26:27Z',
                'url':
                    'https://github.com/librescoot/osm-tiles/releases/download/'
                        'tiles-20260812T162557Z/tiles_berlin_brandenburg.mbtiles',
              },
            ]),
            200,
          );
        }),
      );

      final assets = await service.resolveTileAssets(
          'librescoot/osm-tiles', 'tiles_');

      expect(requested.single,
          'https://downloads.librescoot.org/releases/osm-tiles.json');
      expect(assets.single['name'], 'tiles_berlin_brandenburg.mbtiles');
      // The tag has to come from the manifest: it names one immutable build,
      // and a hardcoded 'latest' would silently serve a frozen release.
      expect(assets.single['url'], contains('tiles-20260812T162557Z'));
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
        fullImageBoards: const {Board.mdb, Board.dbc},
      );
      expect(items.length, 3);
      expect(items[0].type, DownloadItemType.mdbArtifact);
      expect(items[1].type, DownloadItemType.mdbFirmware);
      expect(items[2].type, DownloadItemType.dbcFirmware);
    });

    test('Region model generates correct filenames', () {
      final region = Region.all.firstWhere((r) => r.slug == 'berlin_brandenburg');
      expect(region.osmTilesFilename, 'tiles_berlin_brandenburg.mbtiles');
      expect(region.valhallaTilesFilename, 'valhalla_tiles_berlin_brandenburg.tar');
    });

    List<Map<String, dynamic>> fullRelease() => [
          _asset('librescoot-unu-mdb-v1.2.1.sdimg.gz', 330203000),
          _asset('librescoot-unu-mdb-v1.2.1.sdimg.bmap', 5000),
          _asset('librescoot-unu-mdb-minimal-v1.2.1.sdimg.gz', 54100000),
          _asset('librescoot-unu-mdb-minimal-v1.2.1.sdimg.bmap', 5000),
          _asset('librescoot-unu-mdb-v1.2.1.mender', 162700000),
          _asset('librescoot-unu-mdb-v1.2.1.delta', 200000),
          _asset('librescoot-unu-mdb-boot-v1.2.1.tar.gz', 8600000),
          _asset('librescoot-unu-dbc-v1.2.1.sdimg.gz', 444618207),
          _asset('librescoot-unu-dbc-v1.2.1.sdimg.bmap', 5766),
          _asset('librescoot-unu-dbc-minimal-v1.2.1.sdimg.gz', 56716530),
          _asset('librescoot-unu-dbc-minimal-v1.2.1.sdimg.bmap', 6166),
          _asset('librescoot-unu-dbc-v1.2.1.mender', 220542976),
          _asset('librescoot-unu-dbc-v1.2.1.delta', 231405),
          _asset('librescoot-unu-dbc-boot-v1.2.1.tar.gz', 10065759),
        ];

    test('by default queues artifacts and minimal images, not full sdimgs',
        () async {
      final service = DownloadService(
        client: _manifestClient({'stable': _release('v1.2.1', fullRelease())}),
      );
      final items = await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
      );
      final names = items.map((i) => i.filename).toList();

      expect(names, contains('librescoot-unu-mdb-v1.2.1.mender'));
      expect(names, contains('librescoot-unu-dbc-v1.2.1.mender'));
      expect(names, contains('librescoot-unu-mdb-minimal-v1.2.1.sdimg.gz'));
      expect(names, contains('librescoot-unu-dbc-minimal-v1.2.1.sdimg.bmap'));
      expect(names, isNot(contains('librescoot-unu-mdb-v1.2.1.sdimg.gz')));
      expect(names, isNot(contains('librescoot-unu-dbc-v1.2.1.sdimg.gz')));
      expect(names, isNot(contains('librescoot-unu-mdb-v1.2.1.delta')));
      expect(names, isNot(contains('librescoot-unu-mdb-boot-v1.2.1.tar.gz')));
    });

    test('the default queue is 471 MiB, not 739 MiB', () async {
      final service = DownloadService(
        client: _manifestClient({'stable': _release('v1.2.1', fullRelease())}),
      );
      final items = await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
      );
      final total = items.fold<int>(0, (a, i) => a + i.expectedSize);
      expect(total, lessThan(520 * 1000 * 1000));
    });

    test('artifacts sort ahead of images so they download first', () async {
      final service = DownloadService(
        client: _manifestClient({'stable': _release('v1.2.1', fullRelease())}),
      );
      final items = await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
      );
      final firstImage =
          items.indexWhere((i) => i.filename.endsWith('.sdimg.gz'));
      final lastArtifact =
          items.lastIndexWhere((i) => i.filename.endsWith('.mender'));
      expect(lastArtifact, lessThan(firstImage));
    });

    test('fullImageBoards swaps the minimal images for the full ones', () async {
      final service = DownloadService(
        client: _manifestClient({'stable': _release('v1.2.1', fullRelease())}),
      );
      final items = await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
        fullImageBoards: const {Board.mdb, Board.dbc},
      );
      final names = items.map((i) => i.filename).toList();

      expect(names, contains('librescoot-unu-mdb-v1.2.1.sdimg.gz'));
      expect(names, contains('librescoot-unu-dbc-v1.2.1.sdimg.bmap'));
      expect(names, isNot(contains('librescoot-unu-mdb-minimal-v1.2.1.sdimg.gz')));
      expect(names, contains('librescoot-unu-mdb-v1.2.1.mender'),
          reason: 'the artifact is still what gets installed');
    });

    test('a main-board fall-back leaves the dashboard on its stage-0 image',
        () async {
      final service = DownloadService(
        client: _manifestClient({'stable': _release('v1.2.1', fullRelease())}),
      );
      final items = await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
        fullImageBoards: const {Board.mdb},
      );
      final names = items.map((i) => i.filename).toList();

      expect(names, contains('librescoot-unu-mdb-v1.2.1.sdimg.gz'));
      expect(names, contains('librescoot-unu-mdb-v1.2.1.sdimg.bmap'));
      expect(names, isNot(contains('librescoot-unu-mdb-minimal-v1.2.1.sdimg.gz')));

      expect(names, contains('librescoot-unu-dbc-minimal-v1.2.1.sdimg.gz'),
          reason: 'the dashboard did not fall back, so it keeps stage 0');
      expect(names, contains('librescoot-unu-dbc-minimal-v1.2.1.sdimg.bmap'));
      expect(names, isNot(contains('librescoot-unu-dbc-v1.2.1.sdimg.gz')));
    });

    test('a release without artifacts still yields a usable image queue',
        () async {
      final service = DownloadService(
        client: _manifestClient({
          'stable': _release('v1.0.0', [
            _asset('librescoot-unu-mdb-v1.0.0.sdimg.gz', 141215162),
            _asset('librescoot-unu-dbc-v1.0.0.sdimg.gz', 197006162),
          ])
        }),
      );
      final items = await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
        fullImageBoards: const {Board.mdb, Board.dbc},
      );
      expect(items.map((i) => i.type),
          containsAll([DownloadItemType.mdbFirmware, DownloadItemType.dbcFirmware]));
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

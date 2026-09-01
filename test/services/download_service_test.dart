import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
}) => {'tag_name': tag, 'published_at': publishedAt, 'assets': assets};

/// MockClient that serves the given per-channel manifest from latest.json and
/// 404s everything else.
http_testing.MockClient _manifestClient(Map<String, dynamic> channels) =>
    http_testing.MockClient((request) async {
      if (request.url.path.endsWith('latest.json')) {
        return http.Response(jsonEncode(channels), 200);
      }
      return http.Response('Not found', 404);
    });

class _StreamClient extends http.BaseClient {
  _StreamClient(this.stream);

  final Stream<List<int>> stream;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(stream, 200);
}

void main() {
  group('DownloadService', () {
    // _fetchLatest caches the manifest on disk (shared across instances), so
    // clear it before each test to keep them reading their own mock.
    setUp(() async {
      final dir = await DownloadService.getCacheDir();
      final cache = File(p.join(dir.path, 'latest.json'));
      if (await cache.exists()) await cache.delete();
    });

    test('the manifest cache is redirected away from the user cache', () async {
      // _fetchLatest writes every manifest it fetches to disk, so a test run
      // that used the real cache directory would leave a fixture there for the
      // installer to read back as the current release list.
      final dir = await DownloadService.getCacheDir();
      expect(DownloadService.cacheDirOverride, isNotNull);
      expect(dir.path, DownloadService.cacheDirOverride!.path);
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        expect(dir.path, isNot(p.join(home, '.cache', 'librescoot-installer')));
      }
    });

    test('resolveRelease finds the requested channel', () async {
      final service = DownloadService(
        client: _manifestClient({
          'nightly': _release('nightly-20260330T013130', [
            _asset(
              'librescoot-unu-mdb-nightly-20260330T013130.sdimg.gz',
              141215162,
            ),
            _asset(
              'librescoot-unu-dbc-nightly-20260330T013130.sdimg.gz',
              197006162,
            ),
          ]),
          'testing': _release('testing-20260318T114803', [
            _asset(
              'librescoot-unu-mdb-testing-20260318T114803.sdimg.gz',
              140000000,
            ),
            _asset(
              'librescoot-unu-dbc-testing-20260318T114803.sdimg.gz',
              196000000,
            ),
          ]),
        }),
      );
      final result = await service.resolveRelease(DownloadChannel.testing);
      expect(result.tag, 'testing-20260318T114803');
      expect(result.assets.length, 2);
    });

    test(
      'resolveTileAssets reads the per-repo manifest, not the GitHub API',
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
          'librescoot/osm-tiles',
          'tiles_',
        );

        expect(
          requested.single,
          'https://downloads.librescoot.org/releases/osm-tiles.json',
        );
        expect(assets.single['name'], 'tiles_berlin_brandenburg.mbtiles');
        // The tag has to come from the manifest: it names one immutable build,
        // and a hardcoded 'latest' would silently serve a frozen release.
        expect(assets.single['url'], contains('tiles-20260812T162557Z'));
      },
    );

    group('tile manifest cache', () {
      const repo = 'librescoot/osm-tiles';
      const manifestUrl =
          'https://downloads.librescoot.org/releases/osm-tiles.json';
      final good = jsonEncode([
        {
          'name': 'tiles_berlin_brandenburg.mbtiles',
          'size': 208076800,
          'url': 'https://example.com/tiles_berlin_brandenburg.mbtiles',
        },
      ]);

      late File cacheFile;

      setUp(() async {
        final dir = await DownloadService.getCacheDir();
        cacheFile = File(p.join(dir.path, 'librescoot_osm-tiles-latest.json'));
        if (await cacheFile.exists()) await cacheFile.delete();
        final staging = File('${cacheFile.path}.part');
        if (await staging.exists()) await staging.delete();
      });

      /// Serves [body] with [status], and records that it was asked.
      DownloadService serving(
        String body, {
        int status = 200,
        required List<String> requested,
      }) => DownloadService(
        client: http_testing.MockClient((request) async {
          requested.add(request.url.toString());
          return http.Response(body, status);
        }),
      );

      test('a truncated but fresh cache is refetched, not thrown', () async {
        // Half a JSON document, written moments ago: what an interrupted
        // write leaves behind.
        await cacheFile.writeAsString('[{"name": "tiles_berlin');
        final requested = <String>[];
        final service = serving(good, requested: requested);

        final assets = await service.resolveTileAssets(repo, 'tiles_');

        expect(requested.single, manifestUrl);
        expect(assets.single['name'], 'tiles_berlin_brandenburg.mbtiles');
      });

      test('the repaired cache is what the next call reads', () async {
        await cacheFile.writeAsString('[{"name": "tiles_berlin');
        final requested = <String>[];
        final service = serving(good, requested: requested);

        await service.resolveTileAssets(repo, 'tiles_');
        final second = await service.resolveTileAssets(repo, 'tiles_');

        expect(requested, hasLength(1), reason: 'cache was not repaired');
        expect(second.single['name'], 'tiles_berlin_brandenburg.mbtiles');
      });

      test('a fresh cache of the wrong shape is refetched', () async {
        // Valid JSON, no assets key: throws a cast error rather than a
        // FormatException, so catching only the latter would miss it.
        await cacheFile.writeAsString(jsonEncode({'tag_name': 'v1'}));
        final requested = <String>[];
        final service = serving(good, requested: requested);

        final assets = await service.resolveTileAssets(repo, 'tiles_');

        expect(requested.single, manifestUrl);
        expect(assets.single['name'], 'tiles_berlin_brandenburg.mbtiles');
      });

      test('a valid stale cache still serves a failing network', () async {
        await cacheFile.writeAsString(good);
        await cacheFile.setLastModified(
          DateTime.now().subtract(const Duration(hours: 4)),
        );
        final requested = <String>[];
        final service = serving('nope', status: 500, requested: requested);

        final assets = await service.resolveTileAssets(repo, 'tiles_');

        expect(requested, hasLength(1));
        expect(assets.single['name'], 'tiles_berlin_brandenburg.mbtiles');
      });

      test('a broken stale cache surfaces the network failure', () async {
        await cacheFile.writeAsString('{ truncated');
        await cacheFile.setLastModified(
          DateTime.now().subtract(const Duration(hours: 4)),
        );
        final service = serving('nope', status: 500, requested: <String>[]);

        // The manifest error, not a parse error standing in for it.
        await expectLater(
          service.resolveTileAssets(repo, 'tiles_'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('manifest error'),
            ),
          ),
        );
      });

      test('an unparseable response is never cached', () async {
        final service = serving(
          '<html>504 gateway</html>',
          requested: <String>[],
        );

        await expectLater(
          service.resolveTileAssets(repo, 'tiles_'),
          throwsA(anything),
        );
        expect(await cacheFile.exists(), isFalse);
      });

      test('a good fetch leaves no staging file behind', () async {
        final service = serving(good, requested: <String>[]);

        await service.resolveTileAssets(repo, 'tiles_');

        expect(await cacheFile.exists(), isTrue);
        expect(await File('${cacheFile.path}.part').exists(), isFalse);
      });
    });

    test('resolveRelease throws when the channel is absent', () async {
      final service = DownloadService(
        client: _manifestClient({
          'testing': _release('testing-20260318T114803', [
            _asset(
              'librescoot-unu-mdb-testing-20260318T114803.sdimg.gz',
              140000000,
            ),
          ]),
        }),
      );
      expect(
        () => service.resolveRelease(DownloadChannel.stable),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'fetchAvailableChannels reports only channels in the manifest',
      () async {
        final service = DownloadService(
          client: _manifestClient({
            'testing': _release(
              'testing-20260318T114803',
              [],
              publishedAt: '2026-03-18T11:48:03Z',
            ),
            'nightly': _release(
              'nightly-20260330T013130',
              [],
              publishedAt: '2026-03-30T01:31:30Z',
            ),
          }),
        );
        final channels = await service.fetchAvailableChannels();
        expect(channels.containsKey(DownloadChannel.stable), isFalse);
        expect(
          channels.keys,
          containsAll([DownloadChannel.testing, DownloadChannel.nightly]),
        );
        expect(
          channels[DownloadChannel.testing]!.tag,
          'testing-20260318T114803',
        );
        expect(channels[DownloadChannel.testing]!.date, '2026-03-18');
      },
    );

    test('buildDownloadQueue filters to unu firmware variants only', () async {
      final service = DownloadService(
        client: _manifestClient({
          'testing': _release('testing-20260318T114803', [
            _asset('librescoot-unu-mdb-testing-20260318T114803.sdimg.gz', 100),
            _asset('librescoot-unu-dbc-testing-20260318T114803.sdimg.gz', 200),
            _asset('librescoot-unu-mdb-testing-20260318T114803.mender', 300),
            _asset(
              'librescoot-other-mdb-testing-20260318T114803.sdimg.gz',
              400,
            ),
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
      final region = Region.all.firstWhere(
        (r) => r.slug == 'berlin_brandenburg',
      );
      expect(region.osmTilesFilename, 'tiles_berlin_brandenburg.mbtiles');
      expect(
        region.valhallaTilesFilename,
        'valhalla_tiles_berlin_brandenburg.tar',
      );
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

    test(
      'by default queues artifacts and minimal images, not full sdimgs',
      () async {
        final service = DownloadService(
          client: _manifestClient({
            'stable': _release('v1.2.1', fullRelease()),
          }),
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
      },
    );

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
      final firstImage = items.indexWhere(
        (i) => i.filename.endsWith('.sdimg.gz'),
      );
      final lastArtifact = items.lastIndexWhere(
        (i) => i.filename.endsWith('.mender'),
      );
      expect(lastArtifact, lessThan(firstImage));
    });

    test('a valid SHA256 cache entry is restored as complete', () async {
      final bytes = <int>[1, 2, 3, 4];
      final name =
          'librescoot-unu-mdb-minimal-cache-valid-${DateTime.now().microsecondsSinceEpoch}.sdimg.gz';
      final cacheDir = await DownloadService.getCacheDir();
      final cached = File(p.join(cacheDir.path, name));
      addTearDown(() async {
        if (await cached.exists()) await cached.delete();
      });
      await cached.writeAsBytes(bytes);

      final service = DownloadService(
        client: _manifestClient({
          'stable': _release('v1.2.1', [
            _asset(
              name,
              bytes.length,
              sha256: sha256.convert(bytes).toString(),
            ),
          ]),
        }),
      );
      final item = (await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
      )).single;

      expect(item.localPath, cached.path);
      expect(item.bytesDownloaded, bytes.length);
    });

    test(
      'a corrupted same-size cache entry is deleted and redownloaded',
      () async {
        final wanted = <int>[1, 2, 3, 4];
        final name =
            'librescoot-unu-mdb-minimal-cache-corrupt-${DateTime.now().microsecondsSinceEpoch}.sdimg.gz';
        final cacheDir = await DownloadService.getCacheDir();
        final cached = File(p.join(cacheDir.path, name));
        final part = File('${cached.path}.part');
        addTearDown(() async {
          if (await cached.exists()) await cached.delete();
          if (await part.exists()) await part.delete();
        });
        await cached.writeAsBytes(<int>[9, 9, 9, 9]);

        final manifest = {
          'stable': _release('v1.2.1', [
            _asset(
              name,
              wanted.length,
              sha256: sha256.convert(wanted).toString(),
            ),
          ]),
        };
        final service = DownloadService(
          client: http_testing.MockClient((request) async {
            if (request.url.path.endsWith('latest.json')) {
              return http.Response(jsonEncode(manifest), 200);
            }
            if (request.url.path.endsWith(name)) {
              return http.Response.bytes(wanted, 200);
            }
            return http.Response('Not found', 404);
          }),
        );
        final item = (await service.buildDownloadQueue(
          channel: DownloadChannel.stable,
          wantsOfflineMaps: false,
        )).single;

        expect(item.localPath, isNull);
        expect(await cached.exists(), isFalse);

        await service.downloadItem(item);
        expect(item.localPath, cached.path);
        expect(await cached.readAsBytes(), wanted);
      },
    );

    test(
      'a legacy cache entry without SHA256 keeps size-only behavior',
      () async {
        final bytes = <int>[7, 8, 9];
        final name =
            'librescoot-unu-mdb-minimal-cache-legacy-${DateTime.now().microsecondsSinceEpoch}.sdimg.gz';
        final cacheDir = await DownloadService.getCacheDir();
        final cached = File(p.join(cacheDir.path, name));
        addTearDown(() async {
          if (await cached.exists()) await cached.delete();
        });
        await cached.writeAsBytes(bytes);

        final service = DownloadService(
          client: _manifestClient({
            'stable': _release('v1.2.1', [_asset(name, bytes.length)]),
          }),
        );
        final item = (await service.buildDownloadQueue(
          channel: DownloadChannel.stable,
          wantsOfflineMaps: false,
        )).single;

        expect(item.expectedSha256, isNull);
        expect(item.localPath, cached.path);
      },
    );

    // The cache sidecar. Every file that reaches its final name in the cache
    // got there by passing a SHA256 check at download time, so the digest is
    // recorded next to it and the next run compares two strings instead of
    // rehashing several hundred MB of firmware.
    test('a cache entry the sidecar vouches for is restored unhashed', () async {
      final wanted = <int>[1, 2, 3, 4];
      final digest = sha256.convert(wanted).toString();
      final name =
          'librescoot-unu-mdb-minimal-cache-sidecar-${DateTime.now().microsecondsSinceEpoch}.sdimg.gz';
      final cacheDir = await DownloadService.getCacheDir();
      final cached = File(p.join(cacheDir.path, name));
      final sidecar = File('${cached.path}.sha256');
      addTearDown(() async {
        if (await cached.exists()) await cached.delete();
        if (await sidecar.exists()) await sidecar.delete();
      });
      // Content the digest does not describe, at the right size. Restoring it
      // is only possible if the file was never hashed, which is the point.
      await cached.writeAsBytes(<int>[9, 9, 9, 9]);
      await sidecar.writeAsString(digest);

      final service = DownloadService(
        client: _manifestClient({
          'stable': _release('v1.2.1', [
            _asset(name, wanted.length, sha256: digest),
          ]),
        }),
      );
      final item = (await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
      )).single;

      expect(item.localPath, cached.path);
      expect(item.bytesDownloaded, wanted.length);
    });

    test('a finished download leaves the sidecar the next run reads', () async {
      final wanted = <int>[1, 2, 3, 4];
      final digest = sha256.convert(wanted).toString();
      final name =
          'librescoot-unu-mdb-minimal-cache-writes-${DateTime.now().microsecondsSinceEpoch}.sdimg.gz';
      final cacheDir = await DownloadService.getCacheDir();
      final cached = File(p.join(cacheDir.path, name));
      final sidecar = File('${cached.path}.sha256');
      addTearDown(() async {
        if (await cached.exists()) await cached.delete();
        if (await sidecar.exists()) await sidecar.delete();
      });

      final manifest = {
        'stable': _release('v1.2.1', [
          _asset(name, wanted.length, sha256: digest),
        ]),
      };
      final service = DownloadService(
        client: http_testing.MockClient((request) async {
          if (request.url.path.endsWith('latest.json')) {
            return http.Response(jsonEncode(manifest), 200);
          }
          if (request.url.path.endsWith(name)) {
            return http.Response.bytes(wanted, 200);
          }
          return http.Response('Not found', 404);
        }),
      );
      final item = (await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
      )).single;
      await service.downloadItem(item);

      expect(await sidecar.readAsString(), digest);
    });

    test('a cache entry with no sidecar is hashed once and gains one', () async {
      final bytes = <int>[1, 2, 3, 4];
      final digest = sha256.convert(bytes).toString();
      final name =
          'librescoot-unu-mdb-minimal-cache-adopt-${DateTime.now().microsecondsSinceEpoch}.sdimg.gz';
      final cacheDir = await DownloadService.getCacheDir();
      final cached = File(p.join(cacheDir.path, name));
      final sidecar = File('${cached.path}.sha256');
      addTearDown(() async {
        if (await cached.exists()) await cached.delete();
        if (await sidecar.exists()) await sidecar.delete();
      });
      await cached.writeAsBytes(bytes);

      final service = DownloadService(
        client: _manifestClient({
          'stable': _release('v1.2.1', [
            _asset(name, bytes.length, sha256: digest),
          ]),
        }),
      );
      final item = (await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
      )).single;

      expect(item.localPath, cached.path,
          reason: 'a file that hashes correctly is still usable');
      expect(await sidecar.readAsString(), digest,
          reason: 'so the run after this one does not hash it again');
    });

    test('a sidecar that disagrees with the manifest saves nothing', () async {
      final wanted = <int>[1, 2, 3, 4];
      final name =
          'librescoot-unu-mdb-minimal-cache-stale-${DateTime.now().microsecondsSinceEpoch}.sdimg.gz';
      final cacheDir = await DownloadService.getCacheDir();
      final cached = File(p.join(cacheDir.path, name));
      final sidecar = File('${cached.path}.sha256');
      addTearDown(() async {
        if (await cached.exists()) await cached.delete();
        if (await sidecar.exists()) await sidecar.delete();
      });
      await cached.writeAsBytes(<int>[9, 9, 9, 9]);
      // A digest from some older release that reused this filename.
      await sidecar.writeAsString(sha256.convert(<int>[5, 5, 5, 5]).toString());

      final service = DownloadService(
        client: _manifestClient({
          'stable': _release('v1.2.1', [
            _asset(
              name,
              wanted.length,
              sha256: sha256.convert(wanted).toString(),
            ),
          ]),
        }),
      );
      final item = (await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
      )).single;

      expect(item.localPath, isNull);
      expect(await cached.exists(), isFalse);
      expect(await sidecar.exists(), isFalse,
          reason: 'a digest for a file that is gone vouches for the next '
              'thing to take the name');
    });

    test("an evicted old version takes its sidecar with it", () async {
      final wanted = <int>[1, 2, 3, 4];
      final digest = sha256.convert(wanted).toString();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final name = 'librescoot-unu-mdb-minimal-stable-$stamp.sdimg.gz';
      final oldName = 'librescoot-unu-mdb-minimal-stable-${stamp - 1}.sdimg.gz';
      final cacheDir = await DownloadService.getCacheDir();
      final cached = File(p.join(cacheDir.path, name));
      final sidecar = File('${cached.path}.sha256');
      final old = File(p.join(cacheDir.path, oldName));
      final oldSidecar = File('${old.path}.sha256');
      addTearDown(() async {
        for (final f in [cached, sidecar, old, oldSidecar]) {
          if (await f.exists()) await f.delete();
        }
      });
      await old.writeAsBytes(<int>[7, 7, 7]);
      await oldSidecar.writeAsString(sha256.convert(<int>[7, 7, 7]).toString());

      final manifest = {
        'stable': _release('v1.2.1', [
          _asset(name, wanted.length, sha256: digest),
        ]),
      };
      final service = DownloadService(
        client: http_testing.MockClient((request) async {
          if (request.url.path.endsWith('latest.json')) {
            return http.Response(jsonEncode(manifest), 200);
          }
          if (request.url.path.endsWith(name)) {
            return http.Response.bytes(wanted, 200);
          }
          return http.Response('Not found', 404);
        }),
      );
      final item = (await service.buildDownloadQueue(
        channel: DownloadChannel.stable,
        wantsOfflineMaps: false,
      )).single;
      await service.downloadItem(item);

      expect(await old.exists(), isFalse);
      expect(await oldSidecar.exists(), isFalse,
          reason: 'an orphan digest outlives the file it describes and then '
              'vouches for a reused name');
    });

    test('a stalled response stream fails after the idle deadline', () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);
      controller.add([1]);
      final service = DownloadService(
        client: _StreamClient(controller.stream),
        idleTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);
      final item = DownloadItem(
        type: DownloadItemType.mdbArtifact,
        url: 'https://example.com/stalled.mender',
        filename: 'stalled-${DateTime.now().microsecondsSinceEpoch}.mender',
        expectedSize: 2,
      );

      await expectLater(
        service.downloadItem(item),
        throwsA(
          isA<TimeoutException>().having(
            (error) => error.message,
            'message',
            contains('Download stalled'),
          ),
        ),
      );
      expect(item.bytesDownloaded, 0);
      final cacheDir = await DownloadService.getCacheDir();
      expect(
        File(p.join(cacheDir.path, '${item.filename}.part')).existsSync(),
        isFalse,
      );
    });

    test(
      'a superseded generation cancels and removes its partial file',
      () async {
        final controller = StreamController<List<int>>();
        addTearDown(controller.close);
        final service = DownloadService(
          client: _StreamClient(controller.stream),
        );
        addTearDown(service.dispose);
        final generation = DateTime.now().microsecondsSinceEpoch;
        final token = DownloadCancellationToken(generation);
        final item = DownloadItem(
          type: DownloadItemType.mdbArtifact,
          url: 'https://example.com/cancelled.mender',
          filename: 'cancelled-$generation.mender',
          expectedSize: 2,
        );
        final firstChunk = Completer<void>();
        final download = service.downloadItem(
          item,
          cancellationToken: token,
          onProgress: (bytes, total) {
            if (!firstChunk.isCompleted) firstChunk.complete();
          },
        );

        controller.add(<int>[1]);
        await firstChunk.future;
        token.cancel();
        controller.add(<int>[2]);

        await expectLater(download, throwsA(isA<DownloadCancelled>()));
        expect(item.localPath, isNull);
        expect(item.bytesDownloaded, 0);
        final cacheDir = await DownloadService.getCacheDir();
        expect(
          File(
            p.join(cacheDir.path, '${item.filename}.$generation.part'),
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'fullImageBoards swaps the minimal images for the full ones',
      () async {
        final service = DownloadService(
          client: _manifestClient({
            'stable': _release('v1.2.1', fullRelease()),
          }),
        );
        final items = await service.buildDownloadQueue(
          channel: DownloadChannel.stable,
          wantsOfflineMaps: false,
          fullImageBoards: const {Board.mdb, Board.dbc},
        );
        final names = items.map((i) => i.filename).toList();

        expect(names, contains('librescoot-unu-mdb-v1.2.1.sdimg.gz'));
        expect(names, contains('librescoot-unu-dbc-v1.2.1.sdimg.bmap'));
        expect(
          names,
          isNot(contains('librescoot-unu-mdb-minimal-v1.2.1.sdimg.gz')),
        );
        expect(
          names,
          contains('librescoot-unu-mdb-v1.2.1.mender'),
          reason: 'the artifact is still what gets installed',
        );
      },
    );

    test(
      'a main-board fall-back leaves the dashboard on its stage-0 image',
      () async {
        final service = DownloadService(
          client: _manifestClient({
            'stable': _release('v1.2.1', fullRelease()),
          }),
        );
        final items = await service.buildDownloadQueue(
          channel: DownloadChannel.stable,
          wantsOfflineMaps: false,
          fullImageBoards: const {Board.mdb},
        );
        final names = items.map((i) => i.filename).toList();

        expect(names, contains('librescoot-unu-mdb-v1.2.1.sdimg.gz'));
        expect(names, contains('librescoot-unu-mdb-v1.2.1.sdimg.bmap'));
        expect(
          names,
          isNot(contains('librescoot-unu-mdb-minimal-v1.2.1.sdimg.gz')),
        );

        expect(
          names,
          contains('librescoot-unu-dbc-minimal-v1.2.1.sdimg.gz'),
          reason: 'the dashboard did not fall back, so it keeps stage 0',
        );
        expect(names, contains('librescoot-unu-dbc-minimal-v1.2.1.sdimg.bmap'));
        expect(names, isNot(contains('librescoot-unu-dbc-v1.2.1.sdimg.gz')));
      },
    );

    test(
      'a release without artifacts still yields a usable image queue',
      () async {
        final service = DownloadService(
          client: _manifestClient({
            'stable': _release('v1.0.0', [
              _asset('librescoot-unu-mdb-v1.0.0.sdimg.gz', 141215162),
              _asset('librescoot-unu-dbc-v1.0.0.sdimg.gz', 197006162),
            ]),
          }),
        );
        final items = await service.buildDownloadQueue(
          channel: DownloadChannel.stable,
          wantsOfflineMaps: false,
          fullImageBoards: const {Board.mdb, Board.dbc},
        );
        expect(
          items.map((i) => i.type),
          containsAll([
            DownloadItemType.mdbFirmware,
            DownloadItemType.dbcFirmware,
          ]),
        );
      },
    );
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
          200,
        );
      });
      expect(await Region.detectSlugFromIp(client: client), 'bayern');
    });

    test('collapses Berlin and Brandenburg to the combined region', () async {
      for (final code in ['BE', 'BB']) {
        final client = http_testing.MockClient(
          (request) async => http.Response(
            jsonEncode({
              'status': 'success',
              'countryCode': 'DE',
              'region': code,
            }),
            200,
          ),
        );
        expect(
          await Region.detectSlugFromIp(client: client),
          'berlin_brandenburg',
        );
      }
    });

    Future<String?> detect(String country, String? region) {
      final client = http_testing.MockClient(
        (request) async => http.Response(
          jsonEncode({
            'status': 'success',
            'countryCode': country,
            if (region != null) 'region': region,
          }),
          200,
        ),
      );
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
      final client = http_testing.MockClient(
        (request) async => http.Response(jsonEncode({'status': 'fail'}), 200),
      );
      expect(await Region.detectSlugFromIp(client: client), isNull);
    });
  });
}

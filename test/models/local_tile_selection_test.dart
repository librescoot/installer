import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/local_tile_selection.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory dir;
  late File map;
  late File routing;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('local-tiles-');
    map = File(path.join(dir.path, 'tiles_custom.mbtiles'));
    routing = File(path.join(dir.path, 'valhalla_tiles_custom.tar.zst'));
    await map.writeAsBytes([...ascii.encode('SQLite format 3\u0000'), 1]);
    await routing.writeAsBytes([1, 2, 3]);
  });
  tearDown(() async => dir.delete(recursive: true));

  test('accepts either local file and a complete custom pair', () async {
    final mapsOnly = LocalTileSelection.fromPaths(mapPath: map.path);
    expect(mapsOnly.regionSlug, 'custom');
    expect(mapsOnly.routingPath, isNull);
    await mapsOnly.validateFiles();

    final routingOnly = LocalTileSelection.fromPaths(routingPath: routing.path);
    expect(routingOnly.regionSlug, 'custom');
    await routingOnly.validateFiles();

    final both = LocalTileSelection.fromPaths(
      mapPath: map.path,
      routingPath: routing.path,
    );
    expect(both.regionSlug, 'custom');
    await both.validateFiles();
  });

  test('unnamed map can be paired with routing for a custom region', () {
    final selection = LocalTileSelection.fromPaths(
      mapPath: path.join(dir.path, 'my-own.mbtiles'),
      routingPath: routing.path,
    );
    expect(selection.regionSlug, 'custom');
  });

  test('rejects mismatched and unsafe filenames', () {
    expect(
      () => LocalTileSelection.fromPaths(
        mapPath: map.path,
        routingPath: path.join(dir.path, 'valhalla_tiles_other.tar'),
      ),
      throwsA(
        isA<LocalTileException>().having(
          (e) => e.reason,
          'reason',
          LocalTileError.regionMismatch,
        ),
      ),
    );
    expect(
      () => LocalTileSelection.fromPaths(
        routingPath: path.join(dir.path, r'valhalla_tiles_$(rm -rf x).tar'),
      ),
      throwsA(isA<LocalTileException>()),
    );
    expect(
      () => LocalTileSelection.fromPaths(),
      throwsA(isA<LocalTileException>()),
    );
  });

  test('rejects missing and non-SQLite map files', () async {
    await map.writeAsString('not SQLite');
    final selection = LocalTileSelection.fromPaths(mapPath: map.path);
    await expectLater(
      selection.validateFiles(),
      throwsA(
        isA<LocalTileException>().having(
          (e) => e.reason,
          'reason',
          LocalTileError.invalidMap,
        ),
      ),
    );
    await map.delete();
    await expectLater(
      selection.validateFiles(),
      throwsA(
        isA<LocalTileException>().having(
          (e) => e.reason,
          'reason',
          LocalTileError.unreadable,
        ),
      ),
    );
  });
}

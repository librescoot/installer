import 'dart:io';

import 'package:path/path.dart' as path;

enum LocalTileError {
  noFiles,
  mapExtension,
  routingExtension,
  regionMismatch,
  unreadable,
  invalidMap,
}

class LocalTileException implements Exception {
  const LocalTileException(this.reason);

  final LocalTileError reason;
}

/// User-supplied files that take the place of one or both tile downloads.
class LocalTileSelection {
  const LocalTileSelection._({this.mapPath, this.routingPath, this.regionSlug});

  final String? mapPath;
  final String? routingPath;
  final String? regionSlug;

  static final _routingName = RegExp(
    r'^valhalla_tiles_([a-z0-9][a-z0-9_-]*)\.tar(?:\.zst)?$',
    caseSensitive: false,
  );
  static final _mapName = RegExp(
    r'^tiles_([a-z0-9][a-z0-9_-]*)\.mbtiles$',
    caseSensitive: false,
  );

  static String _basename(String filePath) =>
      path.posix.basename(filePath.replaceAll('\\', '/'));

  static bool isMapPath(String filePath) =>
      _basename(filePath).toLowerCase().endsWith('.mbtiles');

  static bool isRoutingPath(String filePath) =>
      _routingName.hasMatch(_basename(filePath));

  factory LocalTileSelection.fromPaths({String? mapPath, String? routingPath}) {
    if (mapPath == null && routingPath == null) {
      throw const LocalTileException(LocalTileError.noFiles);
    }
    if (mapPath != null && !isMapPath(mapPath)) {
      throw const LocalTileException(LocalTileError.mapExtension);
    }
    final route = routingPath == null
        ? null
        : _routingName.firstMatch(_basename(routingPath));
    if (routingPath != null && route == null) {
      throw const LocalTileException(LocalTileError.routingExtension);
    }
    final routeSlug = route?.group(1)?.toLowerCase();
    final mapSlug = mapPath == null
        ? null
        : _mapName.firstMatch(_basename(mapPath))?.group(1)?.toLowerCase();
    if (mapSlug != null && routeSlug != null && mapSlug != routeSlug) {
      throw const LocalTileException(LocalTileError.regionMismatch);
    }
    return LocalTileSelection._(
      mapPath: mapPath,
      routingPath: routingPath,
      regionSlug: routeSlug ?? mapSlug,
    );
  }

  Future<void> validateFiles() async {
    try {
      for (final filePath in [mapPath, routingPath].whereType<String>()) {
        final file = File(filePath);
        if (await FileSystemEntity.type(filePath) !=
                FileSystemEntityType.file ||
            await file.length() == 0) {
          throw const LocalTileException(LocalTileError.unreadable);
        }
      }
      if (mapPath case final filePath?) {
        final map = await File(filePath).open();
        try {
          final header = await map.read(16);
          if (header.length != 16 ||
              String.fromCharCodes(header) != 'SQLite format 3\u0000') {
            throw const LocalTileException(LocalTileError.invalidMap);
          }
        } finally {
          await map.close();
        }
      }
    } on FileSystemException {
      throw const LocalTileException(LocalTileError.unreadable);
    }
  }
}

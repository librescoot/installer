import 'region.dart';

enum DownloadChannel { stable, testing, nightly }

/// Order defines download priority (lowest index = downloaded first).
enum DownloadItemType { mdbFirmware, dbcFirmware, mdbBmap, dbcBmap, osmTiles, valhallaTiles }

class DownloadItem {
  DownloadItem({
    required this.type,
    required this.url,
    required this.filename,
    required this.expectedSize,
  });

  final DownloadItemType type;
  final String url;
  final String filename;
  final int expectedSize;
  int bytesDownloaded = 0;
  String? localPath;
  bool get isComplete => localPath != null;
  double get progress => expectedSize > 0 ? bytesDownloaded / expectedSize : 0;
}

class DownloadState {
  DownloadChannel channel = DownloadChannel.stable;
  String? releaseTag;
  bool isOffline = true;
  bool wantsOfflineMaps = true;
  Region? selectedRegion;
  List<DownloadItem> items = [];
  String? error;

  bool get allFirmwareReady =>
      items.where((i) => i.type == DownloadItemType.mdbFirmware ||
                         i.type == DownloadItemType.dbcFirmware)
           .every((i) => i.isComplete);

  bool get allReady => items.every((i) => i.isComplete);

  DownloadItem? itemOfType(DownloadItemType type) =>
      items.where((i) => i.type == type).firstOrNull;

  /// Get the bmap file path for a firmware type, if downloaded.
  String? bmapPathFor(DownloadItemType firmwareType) {
    final bmapType = firmwareType == DownloadItemType.mdbFirmware
        ? DownloadItemType.mdbBmap
        : DownloadItemType.dbcBmap;
    return itemOfType(bmapType)?.localPath;
  }
}

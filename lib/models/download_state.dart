import 'board_state.dart';
import 'region.dart';

enum DownloadChannel { stable, testing, nightly }

/// Order defines download priority (lowest index = downloaded first). The
/// artifacts come first because every action except Leave alone needs them,
/// while the stage-0 images are only needed by a clean install.
enum DownloadItemType {
  mdbArtifact,
  dbcArtifact,
  mdbFirmware,
  dbcFirmware,
  mdbBmap,
  dbcBmap,
  osmTiles,
  valhallaTiles,
}

class DownloadItem {
  DownloadItem({
    required this.type,
    required this.url,
    required this.filename,
    required this.expectedSize,
    this.expectedSha256,
  });

  final DownloadItemType type;
  final String url;
  final String filename;
  final int expectedSize;
  /// Lower-case hex sha256 from the release's SHA256SUMS, when published.
  /// Null on legacy releases (pre-SHA256SUMS) or for assets the manifest
  /// doesn't list, verification is skipped in those cases.
  final String? expectedSha256;
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

  /// Item types a run cannot proceed without: an artifact and a stage-0
  /// image per board. Recorded when the queue is built, because what is
  /// needed depends on how the installer was started (the local-image flags
  /// supply sdimgs and no artifacts at all).
  ///
  /// Bmaps are deliberately not in here. A missing one costs write speed,
  /// not correctness.
  static const defaultRequiredTypes = {
    DownloadItemType.mdbArtifact,
    DownloadItemType.dbcArtifact,
    DownloadItemType.mdbFirmware,
    DownloadItemType.dbcFirmware,
  };

  /// What [items] has to contain for this run. Empty until a queue is built.
  Set<DownloadItemType> requiredTypes = const {};

  /// Required types the resolved release did not ship at all. Checked when
  /// the queue is built rather than when a phase reaches for the file: a
  /// release with no `.mender` would otherwise surface at the artifact
  /// install, or worse at the DBC prep, after the main board has already
  /// been migrated.
  List<DownloadItemType> get missingRequiredTypes =>
      requiredTypes.where((t) => itemOfType(t) == null).toList();

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

  DownloadItem? artifactFor(Board board) => itemOfType(
      board == Board.mdb ? DownloadItemType.mdbArtifact : DownloadItemType.dbcArtifact);

  DownloadItem? imageFor(Board board) => itemOfType(
      board == Board.mdb ? DownloadItemType.mdbFirmware : DownloadItemType.dbcFirmware);
}

class DownloadWaitFailure implements Exception {
  const DownloadWaitFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class DownloadWaitCancelled implements Exception {
  const DownloadWaitCancelled();
}

Future<void> waitForDownloads({
  required bool Function() isReady,
  required String? Function() currentError,
  required bool Function() isCancelled,
  Duration pollInterval = const Duration(seconds: 1),
  Duration timeout = const Duration(hours: 2),
}) async {
  final elapsed = Stopwatch()..start();
  while (!isReady()) {
    if (isCancelled()) throw const DownloadWaitCancelled();
    final error = currentError();
    if (error != null) throw DownloadWaitFailure(error);
    if (elapsed.elapsed >= timeout) {
      throw DownloadWaitFailure(
        'Downloads did not finish within ${timeout.inMinutes} minutes',
      );
    }
    await Future<void>.delayed(pollInterval);
  }
}

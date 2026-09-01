import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/board_state.dart';
import 'ssh_service.dart';
import 'trampoline_service.dart';

/// Free space required on top of the artifact itself before an install is
/// attempted. mender streams the payload straight to the inactive rootfs, so
/// this is headroom for logs and the state store rather than a second copy.
const int _freeSpaceMarginBytes = 64 * 1024 * 1024;

/// Where a staged artifact lives. `librescoot-ota-seed.inc` puts an image's
/// own artifact here so update-service can resolve a delta base from the
/// running version, and the minimal images seed nothing, so anything we
/// install has to be left at this exact path under its release asset name.
String artifactSeedPath(Board board, String assetName) =>
    '/data/ota/${board.name}/$assetName';

/// Splits mender's stderr into progress ticks and real messages. mender emits
/// progress as `\r<pct>%` and everything else as ordinary lines, which is the
/// same split update-service does in internal/mender/install.go.
class MenderOutputParser {
  MenderOutputParser({required this.onProgress, required this.onLine});

  final void Function(int percent) onProgress;
  final void Function(String line) onLine;
  final StringBuffer _carry = StringBuffer();

  void add(String chunk) {
    final buf = _carry.toString() + chunk;
    _carry.clear();
    var start = 0;
    for (var i = 0; i < buf.length; i++) {
      final c = buf[i];
      if (c == '\r' || c == '\n') {
        _emit(buf.substring(start, i));
        start = i + 1;
      }
    }
    if (start < buf.length) _carry.write(buf.substring(start));
  }

  void flush() {
    final rest = _carry.toString();
    _carry.clear();
    if (rest.isNotEmpty) _emit(rest);
  }

  void _emit(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return;
    if (line.endsWith('%') && !line.contains(' ')) {
      final pct = int.tryParse(line.substring(0, line.length - 1));
      if (pct != null && pct >= 0 && pct <= 100) {
        onProgress(pct);
        return;
      }
    }
    onLine(line);
  }
}

/// Why a preflight refused. The service deliberately has no localisation
/// dependency, so it names the problem and hands the numbers over; the screen
/// turns that into a sentence in the user's language.
enum ArtifactPreflightProblem { noMender, notEnoughSpace, otaInProgress }

/// `ota status:<board>` values that mean the device's own update service is
/// already working on that slot. Installing over it would race it into a
/// mender lock conflict, or throw away an update that is installed and only
/// waiting for a reboot. From update-service's `internal/status/reporter.go`;
/// the rest ("idle", "error") are free to proceed.
const _busyOtaStatuses = {
  'downloading',
  'preparing',
  'installing',
  'pending-reboot',
};

class ArtifactPreflight {
  const ArtifactPreflight({
    required this.hasMender,
    required this.freeBytes,
    required this.requiredBytes,
    this.existingBytes = 0,
    this.otaStatus,
  });

  final bool hasMender;

  /// `ota status:<board>` as the board reports it, or null when there was
  /// nothing to read: a stage-0 image has no redis and no update service, and
  /// an unreadable probe must not block an install the way a positive
  /// reading does.
  final String? otaStatus;

  bool get otaBusy => _busyOtaStatuses.contains(otaStatus?.trim().toLowerCase());

  /// Null when df could not be read. Unknown free space does not block the
  /// install: mender fails loudly on a full filesystem anyway, and refusing
  /// on a failed probe would be worse than trying.
  final int? freeBytes;
  final int requiredBytes;

  /// Bytes already sitting at the seed path, 0 when nothing is there or a
  /// prior probe could not read it. A retry overwrites this rather than
  /// adding to it (the md5 match skips the transfer outright; a mismatch is
  /// truncated and rewritten), so it is not new demand on /data: only the
  /// shortfall between it and [requiredBytes] is.
  final int existingBytes;

  bool get ok => problem == null;

  /// Bytes the install still has to acquire on top of what is already
  /// staged, plus headroom for logs and the state store.
  int get neededBytes {
    final shortfall = requiredBytes - existingBytes;
    return (shortfall > 0 ? shortfall : 0) + _freeSpaceMarginBytes;
  }

  int get neededMiB => (neededBytes / (1024 * 1024)).round();
  int get freeMiB => ((freeBytes ?? 0) / (1024 * 1024)).round();

  ArtifactPreflightProblem? get problem {
    if (!hasMender) return ArtifactPreflightProblem.noMender;
    if (otaBusy) return ArtifactPreflightProblem.otaInProgress;
    final free = freeBytes;
    if (free != null && free < neededBytes) {
      return ArtifactPreflightProblem.notEnoughSpace;
    }
    return null;
  }
}

/// Whether mender spent the run on its own bootstrap Artifact instead of the
/// one it was asked for. It says so in as many words on the way past, and that
/// line is the only signal: the exit status is 0 and the progress still runs to
/// 100%, because from mender's point of view the install it chose to do
/// succeeded.
bool menderConsumedByBootstrap(String output) =>
    output.contains('Installing the bootstrap Artifact');

class ArtifactInstallException implements Exception {
  ArtifactInstallException(this.exitCode, this.stderr);

  final int exitCode;
  final String stderr;

  @override
  String toString() => stderr.trim().isEmpty
      ? 'mender-update install failed (exit $exitCode)'
      : stderr.trim();
}

class ArtifactService {
  ArtifactService(this._ssh, this._trampoline);

  final SshService _ssh;
  final TrampolineService _trampoline;

  /// [assetName] identifies the seed path so a partial or fully-staged
  /// artifact from an earlier attempt counts against the requirement instead
  /// of being double-charged: see [ArtifactPreflight.existingBytes].
  Future<ArtifactPreflight> preflight({
    required Board board,
    required int artifactBytes,
    required String assetName,
  }) async {
    final hasMender = await _ssh.hasMenderUpdate();
    final free = await _ssh.freeBytesOn('/data');
    final existing = await _ssh.remoteFileSizeBytes(
          artifactSeedPath(board, assetName),
        ) ??
        0;
    // An installer that arrives while the device's own update service is
    // mid-OTA would race it into a mender lock conflict.
    final otaStatus = await _ssh.redisHget('ota', 'status:${board.name}');
    return ArtifactPreflight(
      hasMender: hasMender,
      freeBytes: free,
      requiredBytes: artifactBytes,
      existingBytes: existing,
      otaStatus: otaStatus,
    );
  }

  /// Put the artifact at its seed path on the board the installer is
  /// connected to. Safe to call again after a dropped link: the md5 check
  /// inside the uploader skips a file that is already there.
  Future<void> stage({
    required Board board,
    required String localPath,
    void Function(int sent, int total)? onProgress,
  }) async {
    final assetName = File(localPath).uri.pathSegments.last;
    await _trampoline.uploadFile(
      localPath,
      artifactSeedPath(board, assetName),
      onProgress: onProgress,
    );
  }

  /// Run mender against the staged artifact. Exit 0 means installed and a
  /// reboot is required. The commit is not ours: update-service commits
  /// StateNeedsCommit at next start, and u-boot rolls back a rootfs that does
  /// not boot.
  Future<void> install({
    required Board board,
    required String assetName,
    void Function(int percent)? onProgress,
    void Function(String line)? onLog,
  }) async {
    final path = artifactSeedPath(board, assetName);
    final parser = MenderOutputParser(
      onProgress: (pct) => onProgress?.call(pct),
      onLine: (line) {
        debugPrint('mender: $line');
        onLog?.call(line);
      },
    );

    // A board that has just been written from an sdimg has an empty mender
    // datastore, and the first install spends itself initialising that rather
    // than applying our payload: mender writes its own bootstrap Artifact,
    // reports 100%, and leaves the transaction open. The board then reboots
    // onto the same slot still running the bootstrap image, and the next
    // attempt dies with "Update already in progress". Absorb that here.
    //
    // Clearing beforehand is not enough on a virgin datastore, because the
    // bootstrap install happens during our own call. So: clear whatever is
    // stale, install, and if that turn went on the bootstrap Artifact, clear
    // it and install again for real.
    await _clearPendingTransaction();

    var result = await _ssh.runStreaming(
      'mender-update install "$path"',
      onStderr: parser.add,
    );
    parser.flush();

    if (result.exitCode == 0 && menderConsumedByBootstrap(result.stderr)) {
      debugPrint('mender: that install went on the bootstrap Artifact, '
          'clearing it and installing again');
      onLog?.call('mender: bootstrap Artifact installed, retrying');
      await _clearPendingTransaction();
      result = await _ssh.runStreaming(
        'mender-update install "$path"',
        onStderr: parser.add,
      );
      parser.flush();
    }

    if (result.exitCode != 0) {
      throw ArtifactInstallException(result.exitCode, result.stderr);
    }
  }

  /// mender refuses to install while a transaction is open, and both ways of
  /// closing one are fine here: nothing worth keeping has been installed yet,
  /// and commit falls back to rollback on its own when a state script fails,
  /// which is what the bootstrap image does. Exit 2 means there was nothing
  /// open, which is the normal case and not a problem.
  Future<void> _clearPendingTransaction() async {
    try {
      await _ssh.runCommand(
        'mender-update commit >/dev/null 2>&1 || '
        'mender-update rollback >/dev/null 2>&1 || true',
      );
    } catch (e) {
      debugPrint('mender: could not clear a pending transaction (ok): $e');
    }
  }

}

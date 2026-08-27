import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/dashboard_messages.dart';
import '../models/install_plan.dart';
import '../models/region.dart';
import '../models/substep.dart';
import '../models/trampoline_status.dart';
import 'finalize_script.dart';
import 'install_phase_scripts.dart';
import 'ssh_service.dart';

typedef ToolAssetLoader = Future<ByteData> Function(String path);
typedef ToolUploader =
    Future<void> Function(Uint8List content, String remotePath);
typedef RemoteCommandRunner = Future<String> Function(String command);

Future<void> stageDbcBootloaderTools({
  required ToolAssetLoader loadAsset,
  required ToolUploader uploadFile,
  required RemoteCommandRunner runCommand,
}) async {
  const remoteDir = '/data/installer/fwtools/stock-dbc';
  const fwSetenvPath = '$remoteDir/fw_setenv';
  const fwEnvConfigPath = '$remoteDir/fw_env.config';

  await runCommand('mkdir -p $remoteDir');

  final fwSetenv = await loadAsset('assets/tools/fw_setenv-dbc');
  await uploadFile(fwSetenv.buffer.asUint8List(), fwSetenvPath);
  await runCommand('chmod 755 $fwSetenvPath');

  final fwEnvConfig = await loadAsset('assets/tools/fw_env-dbc.config');
  await uploadFile(fwEnvConfig.buffer.asUint8List(), fwEnvConfigPath);

  final verification = await runCommand(
    'if test -s $fwSetenvPath && test -x $fwSetenvPath && '
    'test -s $fwEnvConfigPath; then printf ready; else printf missing; fi',
  );
  if (verification.trim() != 'ready') {
    throw StateError('DBC bootloader tools failed remote verification');
  }
}

/// Directory component of [remotePath], or null when the path has no `/`
/// and so nothing to create ahead of an upload (a bare filename lands
/// wherever the SSH session's own working directory already puts it).
String? remoteDirOf(String remotePath) {
  final slash = remotePath.lastIndexOf('/');
  if (slash < 0) return null;
  final dir = remotePath.substring(0, slash);
  return dir.isEmpty ? null : dir;
}

String createInstallRunId({DateTime? now, int? processId}) {
  final timestamp = (now ?? DateTime.now().toUtc())
      .microsecondsSinceEpoch
      .toRadixString(36);
  final process = (processId ?? pid).toRadixString(36);
  return 'run-$timestamp-$process';
}

String serializeInstallRunState({
  required String runId,
  required String actor,
  required String stage,
  String result = 'running',
  String finish = 'pending',
  int? sequence,
  DateTime? updatedAt,
}) {
  final updated = (updatedAt ?? DateTime.now().toUtc()).toIso8601String();
  return <String>[
    'run-id: $runId',
    'actor: $actor',
    'stage: $stage',
    'result: $result',
    'finish: $finish',
    if (sequence != null) 'sequence: $sequence',
    'updated: $updated',
    '',
  ].join('\n');
}

/// What the upload stage calls its steps.
///
/// The service has no localizations, and the screen that shows these does, so
/// the words come in from there. The defaults are the English ones, which is
/// what a caller with nothing to say should get.
/// One file on its way to the MDB: where it is, where it goes, and what to
/// call it on screen.
class _Upload {
  const _Upload(this.local, this.remote, this.name);

  final String local;
  final String remote;
  final String name;
}

class SubstepLabels {
  const SubstepLabels({
    this.checkExisting = 'Check existing files',
    this.uploadFlasher = 'Upload flasher tool',
    this.uploadFwTools = 'Upload DBC bootloader tools',
    this.uploadScript = 'Upload trampoline script',
    this.uploadFile = _defaultUploadFile,
    this.verifying = _defaultVerifying,
    this.imageName = 'dashboard image',
    this.imageMapName = 'dashboard image checksums',
    this.firmwareName = 'dashboard firmware',
    this.mapsName = 'map tiles',
    this.routingName = 'routing data',
    this.alreadyThere = 'already on the scooter',
    this.starting = 'Starting upload...',
    this.complete = 'Upload complete',
    this.nothingToDo = 'All files are already on the scooter',
    this.remaining = _defaultRemaining,
  });

  final String checkExisting;
  final String uploadFlasher;
  final String uploadFwTools;
  final String uploadScript;
  final String Function(String filename) uploadFile;
  final String Function(String filename) verifying;
  /// What each file is, for someone who is not going to recognise
  /// `valhalla_tiles_berlin.tar.zst`.
  final String imageName;
  final String imageMapName;
  final String firmwareName;
  final String mapsName;
  final String routingName;

  final String alreadyThere;
  final String starting;
  final String complete;
  final String nothingToDo;
  final String Function(int mins, int secs) remaining;

  static String _defaultUploadFile(String filename) => 'Upload $filename';
  static String _defaultVerifying(String filename) => 'verifying $filename';
  static String _defaultRemaining(int mins, int secs) =>
      '${mins}m ${secs}s remaining';
}

class TrampolineService {
  final SshService _ssh;
  bool _pythonServerStarted = false;

  TrampolineService(this._ssh);

  /// Pure substitution, split out of [generateScript] so it can be tested
  /// without the asset bundle.
  ///
  /// Throws [ArgumentError] for the one combination the template cannot
  /// turn into real work: upgrade mode with no artifact and tiles off. That
  /// would render a script which waits for the cable swap, reboots the MDB,
  /// and reports success having installed nothing.
  static String renderTemplate(
    String template, {
    required bool upgradeMode,
    required String dbcImagePath,
    required String dbcMenderPath,
    String dbcTargetVersion = '',
    Region? region,
    bool installTiles = false,
    String? valhallaTilesFilename,
    // The autonomous finish. When [finishOnDevice] is true the trampoline does
    // the work the finish phase would otherwise do over the laptop link, so the
    // user never has to reconnect on the happy path. Every value it needs is
    // known before the cable swap, which is why they can be baked in here.
    DeviceFinish finish = DeviceFinish.laptop,
    // What the dashboard says while this runs. The template carries no prose
    // of its own, so a caller that skips these gets English rather than the
    // German the strings started as.
    DashboardMessages messages = DashboardMessages.english,
  }) {
    if (upgradeMode && dbcMenderPath.isEmpty && !installTiles) {
      throw ArgumentError(
        'upgradeMode is true but dbcMenderPath is empty and installTiles is '
        'false: there is nothing for the trampoline to do',
      );
    }

    // The dashboard lines first: they are prose, and prose is the one thing
    // that could carry a {{PLACEHOLDER}} of its own through the substitutions
    // below if it went last.
    var rendered = template;
    messages.placeholders.forEach((placeholder, value) {
      rendered = rendered.replaceAll(placeholder, value);
    });

    return rendered
        .replaceAll('{{MODE}}', upgradeMode ? 'upgrade' : 'flash')
        .replaceAll('{{DBC_IMAGE_PATH}}', dbcImagePath)
        .replaceAll('{{DBC_MENDER_PATH}}', dbcMenderPath)
        .replaceAll('{{DBC_TARGET_VERSION}}', dbcTargetVersion)
        .replaceAll('{{FINISH_ON_DEVICE}}', finish.onDevice ? 'true' : 'false')
        .replaceAll('{{MDB_ACTION}}', finish.mdbAction.name)
        .replaceAll('{{MDB_TARGET_VERSION}}', finish.mdbTargetVersion)
        .replaceAll('{{FINISH_LANGUAGE}}', finish.language)
        .replaceAll('{{FINISH_CHANNEL}}', finish.otaChannel)
        .replaceAll('{{INSTALL_TILES}}', installTiles ? 'true' : 'false')
        .replaceAll(
          '{{OSM_TILES_FILE}}',
          installTiles && region != null
              ? '/data/installer/${region.osmTilesFilename}'
              : '',
        )
        .replaceAll(
          '{{VALHALLA_TILES_FILE}}',
          installTiles && region != null
              ? '/data/installer/${valhallaTilesFilename ?? region.valhallaTilesFilename}'
              : '',
        )
        // Baked in rather than parsed back out of the filenames on the device:
        // the region is picked here, and the trampoline records it so the
        // dashboard does not have to re-identify it from the release manifest,
        // which needs network the vehicle may not have yet.
        .replaceAll('{{TILES_REGION}}', installTiles && region != null ? region.slug : '')
        .replaceAll(
          '{{TILES_REGION_NAME}}',
          installTiles && region != null ? region.name : '',
        );
  }

  /// Generate the trampoline script from the bundled template.
  ///
  /// [dbcImagePath] is empty in upgrade mode, where no stage-0 image is
  /// written. [dbcMenderPath] is empty when the DBC gets no artifact, which
  /// is the tiles-only job. [dbcTargetVersion] is the VERSION_ID the DBC has
  /// to report once the artifact is live; empty leaves the trampoline with
  /// only "did anything change at all" to go on.
  Future<String> generateScript({
    required bool upgradeMode,
    String dbcImagePath = '',
    String dbcMenderPath = '',
    String dbcTargetVersion = '',
    Region? region,
    bool installTiles = false,
    String? valhallaTilesFilename,
    DeviceFinish finish = DeviceFinish.laptop,
    DashboardMessages messages = DashboardMessages.english,
  }) async {
    final template = await rootBundle.loadString('assets/trampoline.sh.template');
    return renderTemplate(
      template,
      finish: finish,
      messages: messages,
      upgradeMode: upgradeMode,
      dbcImagePath: dbcImagePath,
      dbcMenderPath: dbcMenderPath,
      dbcTargetVersion: dbcTargetVersion,
      region: region,
      installTiles: installTiles,
      valhallaTilesFilename: valhallaTilesFilename,
    );
  }

  /// Check if a remote file exists and matches the local file's md5.
  Future<bool> _remoteFileMatches(String localPath, String remotePath) async {
    try {
      // Get local md5: PowerShell on Windows, `md5 -q` on macOS (no md5sum), md5sum on Linux.
      String localMd5;
      if (Platform.isWindows) {
        final localResult = await Process.run('powershell', [
          '-NoProfile', '-Command',
          '(Get-FileHash "$localPath" -Algorithm MD5).Hash',
        ]);
        if (localResult.exitCode != 0) return false;
        localMd5 = localResult.stdout.toString().trim().toLowerCase();
      } else if (Platform.isMacOS) {
        final localResult = await Process.run('md5', ['-q', localPath]);
        if (localResult.exitCode != 0) return false;
        localMd5 = localResult.stdout.toString().trim().toLowerCase();
      } else {
        final localResult = await Process.run('md5sum', [localPath]);
        if (localResult.exitCode != 0) return false;
        localMd5 = localResult.stdout.toString().split(' ').first.trim().toLowerCase();
      }

      // A file that is not there yet is the normal case on a first upload,
      // not a failure worth an exception line per file. Ask separately so the
      // absent case answers "no match" quietly and the catch below stays for
      // things that actually went wrong.
      final present = (await _ssh.runCommand(
        '[ -f "$remotePath" ] && echo yes || echo no',
      )).trim();
      if (present != 'yes') {
        debugPrint('Trampoline: $remotePath not on the device yet, will upload');
        return false;
      }

      // Get remote md5 (large files can take a while)
      final remoteMd5 = (await _ssh.runCommand(
        'md5sum "$remotePath" 2>/dev/null',
        timeout: const Duration(minutes: 5),
      )).trim().split(' ').first.toLowerCase();

      final match = localMd5.isNotEmpty && localMd5 == remoteMd5;
      if (match) {
        debugPrint('Trampoline: $remotePath already exists and matches (md5=$localMd5)');
      } else {
        debugPrint('Trampoline: $remotePath md5 mismatch: local=$localMd5 remote=$remoteMd5');
      }
      return match;
    } catch (e) {
      debugPrint('Trampoline: md5 check failed for $remotePath: $e');
      return false;
    }
  }

  static const _uploadServerScript = '''
import http.server, os, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")
    def do_PUT(self):
        path = '/data' + self.path
        length = int(self.headers['Content-Length'])
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            remaining = length
            while remaining > 0:
                chunk = self.rfile.read(min(65536, remaining))
                if not chunk: break
                f.write(chunk)
                remaining -= len(chunk)
        self.send_response(200)
        self.end_headers()
    def log_message(self, *a): pass
import socketserver
socketserver.TCPServer.allow_reuse_address = True
http.server.HTTPServer(('0.0.0.0', 8080), H).serve_forever()
''';

  static const _mdbUploadUrl = 'http://192.168.7.1:8080';

  /// Start HTTP upload server on MDB (much faster than SCP/SFTP).
  /// If data-server is already running (new firmware), skip Python startup.
  Future<void> _startUploadServer() async {
    final probeClient = HttpClient();
    try {
      final req = await probeClient
          .getUrl(Uri.parse('$_mdbUploadUrl/'))
          .timeout(const Duration(seconds: 3));
      final resp = await req.close().timeout(const Duration(seconds: 3));
      await resp.drain<void>();
      if (resp.statusCode == 200) {
        debugPrint('Trampoline: permanent data-server detected, skipping Python server');
        _pythonServerStarted = false;
        return;
      }
    } catch (_) {
      // Not running: fall through to start the Python server.
    } finally {
      probeClient.close();
    }

    // Kill any leftover server from previous runs
    debugPrint('Trampoline: cleaning up old upload server...');
    try {
      await _ssh.runCommand('kill \$(pgrep -f upload_srv) 2>/dev/null; fuser -k 8080/tcp 2>/dev/null');
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));

    debugPrint('Trampoline: writing upload server script...');
    await _ssh.runCommand("cat > /tmp/upload_srv.py << 'PYEOF'\n$_uploadServerScript\nPYEOF");
    debugPrint('Trampoline: starting upload server...');
    await _ssh.runCommand('nohup python3 /tmp/upload_srv.py > /tmp/upload_srv.log 2>&1 &');

    // Wait for server to be ready: retry connection
    debugPrint('Trampoline: waiting for upload server...');
    final client = HttpClient();
    try {
      for (var i = 0; i < 30; i++) {
        try {
          final req = await client.getUrl(Uri.parse('$_mdbUploadUrl/'));
          final resp = await req.close().timeout(const Duration(seconds: 2));
          await resp.drain<void>();
          debugPrint('Trampoline: HTTP upload server ready (attempt ${i + 1})');
          _pythonServerStarted = true;
          return;
        } catch (_) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      throw Exception('Upload server not responsive after 30s');
    } finally {
      client.close();
    }
  }

  Future<void> _stopUploadServer() async {
    if (!_pythonServerStarted) {
      debugPrint('Trampoline: no Python server to stop');
      return;
    }
    try {
      await _ssh.runCommand(
        'kill \$(pgrep -f upload_srv) 2>/dev/null; '
        'fuser -k 8080/tcp 2>/dev/null; '
        'rm -f /tmp/upload_srv.py',
      );
    } catch (_) {}
    _pythonServerStarted = false;
    debugPrint('Trampoline: HTTP upload server stopped');
  }

  /// Upload a file via HTTP PUT using raw socket for real transfer progress
  Future<void> _uploadViaHttp(
    String localPath,
    String remotePath, {
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    final file = File(localPath);
    final fileSize = await file.length();
    final remoteFilename = remotePath.startsWith('/data/')
        ? remotePath.substring(5)
        : '/$remotePath';

    // Raw socket: write HTTP headers then stream file data with real progress
    final socket = await Socket.connect('192.168.7.1', 8080);
    try {
      // Send HTTP PUT header
      final header = 'PUT $remoteFilename HTTP/1.1\r\n'
          'Host: 192.168.7.1:8080\r\n'
          'Content-Length: $fileSize\r\n'
          'Connection: close\r\n'
          '\r\n';
      socket.add(header.codeUnits);

      // Stream file in 64KB chunks: socket.add + flush gives real backpressure
      var sent = 0;
      var lastProgress = DateTime.now();
      const chunkSize = 64 * 1024;
      final raf = await file.open();
      try {
        while (sent < fileSize) {
          final remaining = fileSize - sent;
          final readSize = remaining < chunkSize ? remaining : chunkSize;
          final chunk = await raf.read(readSize);
          socket.add(chunk);
          await socket.flush();
          sent += chunk.length;

          final now = DateTime.now();
          if (now.difference(lastProgress).inMilliseconds >= 500 || sent >= fileSize) {
            onProgress?.call(sent, fileSize);
            lastProgress = now;
          }
        }
      } finally {
        await raf.close();
      }

      // Read response
      final response = await socket.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      final responseStr = String.fromCharCodes(response);
      if (!responseStr.contains('200')) {
        throw Exception('HTTP upload failed: $responseStr');
      }
    } finally {
      await socket.close();
    }
  }

  /// Upload one local file to [remotePath] on the MDB over HTTP PUT, using
  /// the device's data-server when it answers and a bootstrapped Python
  /// server when it does not. Skips the transfer when the remote file already
  /// matches by md5, which makes a retry after a dropped link cheap.
  ///
  /// Public because artifact staging needs exactly this and there is no
  /// reason for a second implementation of it.
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final dir = remoteDirOf(remotePath);
    if (dir != null) {
      await _ssh.runCommand('mkdir -p "$dir"');
    }
    if (await _remoteFileMatches(localPath, remotePath)) {
      debugPrint('Trampoline: $remotePath already matches, skipping upload');
      return;
    }
    await _startUploadServer();
    try {
      await _uploadViaHttp(localPath, remotePath, onProgress: onProgress);
    } finally {
      await _stopUploadServer();
    }
  }

  /// Upload DBC image, tiles, and trampoline script to MDB.
  ///
  /// Everything we stage lives under /data/installer/ so cleanup at finish
  /// is a single rm -rf. The only exception is /data/onboot.sh, which is
  /// the path librescoot-onboot.service watches via ConditionPathExists —
  /// the trampoline writes that one itself, and it self-deletes after it
  /// runs on the next boot.
  ///
  /// [onProgress] is the legacy free-form status string + overall progress.
  /// [onSubsteps] is the structured form used by the UI to render a
  /// checklist (✓/⟳/○ per step). Both are called; passing only one is fine.
  Future<void> uploadAll({
    /// Baked into the finalize phase so a device finish files its record under
    /// the same run the laptop started.
    String runId = '',

    /// Recorded alongside it, so a later visit can read what this run was
    /// asked to install rather than inferring it from what survived.
    String releaseTag = '',
    String? dbcImageLocalPath,
    String? dbcBmapLocalPath,
    String? dbcArtifactLocalPath,
    String? dbcTargetVersion,

    /// The MDB's own .mender, already staged on the device. Empty for a plan
    /// that leaves the MDB alone; the phase is queued either way so the join
    /// in 80-reboot.sh always has a verdict to read.
    String mdbArtifactPath = '',
    DeviceFinish finish = DeviceFinish.laptop,
    DashboardMessages messages = DashboardMessages.english,
    String? osmTilesLocalPath,
    String? valhallaTilesLocalPath,
    Region? region,
    void Function(String status, double progress)? onProgress,
    void Function(List<Substep> steps)? onSubsteps,
    SubstepLabels? labels,
  }) async {
    // ums-service is enabled with Restart=always and takes the OTG UDC away
    // from g_ether whenever it switches to mass-storage mode. That tears down
    // usb0 and with it this SSH session, mid-upload, for a transfer measured
    // in hundreds of megabytes. The trampoline masks it too, but only after
    // the laptop is unplugged, which leaves this window unprotected. The
    // finish unmasks and starts it again.
    try {
      await _ssh.runCommand(
        'systemctl stop librescoot-ums 2>/dev/null; '
        'systemctl mask librescoot-ums 2>/dev/null; '
        'ifconfig usb0 192.168.7.1 netmask 255.255.255.0 up 2>/dev/null; true',
      );
    } catch (e) {
      debugPrint('Trampoline: could not park ums-service (ok): $e');
    }

    // Ensure the staging dir exists before any SFTP/HTTP upload — SFTP open
    // won't create parents, and the HTTP fallback's os.makedirs is cheap
    // but only kicks in on the first PUT.
    await _ssh.runCommand('mkdir -p /data/installer');

    final l = labels ?? const SubstepLabels();
    final filesToUpload = <_Upload>[];

    if (dbcImageLocalPath != null) {
      final dbcFilename = File(dbcImageLocalPath).uri.pathSegments.last;
      filesToUpload.add(_Upload(
          dbcImageLocalPath, '/data/installer/$dbcFilename', l.imageName));
    }

    if (dbcBmapLocalPath != null) {
      final bmapFilename = File(dbcBmapLocalPath).uri.pathSegments.last;
      filesToUpload.add(_Upload(
          dbcBmapLocalPath, '/data/installer/$bmapFilename', l.imageMapName));
    }

    // The DBC artifact is staged in /data/installer next to the image rather
    // than in /data/ota/dbc: it is going to the *other* board, and the
    // trampoline is what puts it at the seed path over there.
    if (dbcArtifactLocalPath != null) {
      final artifactFilename = File(dbcArtifactLocalPath).uri.pathSegments.last;
      filesToUpload.add(_Upload(dbcArtifactLocalPath,
          '/data/installer/$artifactFilename', l.firmwareName));
    }

    if (osmTilesLocalPath != null && region != null) {
      filesToUpload.add(_Upload(osmTilesLocalPath,
          '/data/installer/${region.osmTilesFilename}', l.mapsName));
    }
    if (valhallaTilesLocalPath != null && region != null) {
      // Keep whatever name was downloaded: the routing tiles may be the zstd
      // form, and the trampoline decides what to do from the suffix.
      final valhallaFilename =
          File(valhallaTilesLocalPath).uri.pathSegments.last;
      filesToUpload.add(_Upload(valhallaTilesLocalPath,
          '/data/installer/$valhallaFilename', l.routingName));
    }

    final substeps = <Substep>[
      Substep(id: 'check', label: l.checkExisting),
      for (final e in filesToUpload)
        Substep(
            id: 'up:${e.remote}',
            label: l.uploadFile(e.name)),
      if (dbcImageLocalPath != null)
        Substep(id: 'flasher', label: l.uploadFlasher),
      if (dbcImageLocalPath != null)
        Substep(id: 'fwtools', label: l.uploadFwTools),
      Substep(id: 'script', label: l.uploadScript),
    ];
    void setStep(String id, SubstepState state, {String? detail}) {
      final idx = substeps.indexWhere((s) => s.id == id);
      if (idx < 0) return;
      substeps[idx] = substeps[idx].copyWith(state: state, detail: detail);
      onSubsteps?.call(List.unmodifiable(substeps));
    }

    onSubsteps?.call(List.unmodifiable(substeps));

    // Start HTTP upload server early: MDB may be busy creating UMS disk image on first boot
    onProgress?.call(l.starting, 0.0);
    await _startUploadServer();

    // Check which files need uploading (server starts in background while we check)
    setStep('check', SubstepState.active);
    onProgress?.call(l.checkExisting, 0.0);
    final needsUpload = <bool>[];
    final fileSizes = <int>[];
    var totalBytes = 0;
    for (final entry in filesToUpload) {
      final size = await File(entry.local).length();
      fileSizes.add(size);
      final filename = entry.name;
      setStep('check', SubstepState.active, detail: l.verifying(filename));
      onProgress?.call(l.verifying(filename), 0.0);
      final matches = await _remoteFileMatches(entry.local, entry.remote);
      needsUpload.add(!matches);
      if (!matches) totalBytes += size;
    }
    setStep('check', SubstepState.done);

    if (totalBytes == 0) {
      onProgress?.call(l.nothingToDo, 0.95);
      for (final e in filesToUpload) {
        setStep('up:${e.remote}', SubstepState.done, detail: l.alreadyThere);
      }
      await _stopUploadServer();
    } else {
      final skipped = needsUpload.where((n) => !n).length;
      if (skipped > 0) {
        debugPrint('Trampoline: skipping $skipped files that already match');
      }

      var bytesSoFar = 0;
      final stopwatch = Stopwatch()..start();
      try {
        for (var i = 0; i < filesToUpload.length; i++) {
          final entry = filesToUpload[i];
          final filename = entry.name;
          final stepId = 'up:${entry.remote}';

          if (!needsUpload[i]) {
            setStep(stepId, SubstepState.done, detail: 'already on device');
            continue;
          }

          setStep(stepId, SubstepState.active);
          onProgress?.call(l.uploadFile(filename), bytesSoFar / totalBytes);
          final baseBytes = bytesSoFar;
          await _uploadViaHttp(
            entry.local,
            entry.remote,
            onProgress: (sent, total) {
              final overall = (baseBytes + sent) / totalBytes;
              final mb = sent / (1024 * 1024);
              final totalMb = total / (1024 * 1024);
              String eta = '';
              if (overall > 0.01) {
                final elapsed = stopwatch.elapsedMilliseconds / 1000;
                final remaining = (elapsed / overall) * (1.0 - overall);
                final mins = remaining ~/ 60;
                final secs = (remaining % 60).floor();
                eta = ', ${l.remaining(mins, secs)}';
              }
              final detail =
                  '${mb.toStringAsFixed(0)} / ${totalMb.toStringAsFixed(0)} MB$eta';
              setStep(stepId, SubstepState.active, detail: detail);
              onProgress?.call(
                '${l.uploadFile(filename)} - $detail',
                overall,
              );
            },
          );
          setStep(stepId, SubstepState.done);
          bytesSoFar += fileSizes[i];
        }
      } finally {
        await _stopUploadServer();
      }
    }

    // Routing tiles ship as .tar.zst and are unpacked on the dashboard, which
    // only grew zstd in the 2026-08-09 image. An upgrade never writes the
    // stage-0 image that has one, so the board keeps whatever its own firmware
    // shipped, and on stable v1.2.1 that is nothing: the unpack fails and the
    // tiles are lost. Carry one it can run.
    //
    // Only when the routing tiles are actually compressed. It is 625 KB that
    // a run staging a plain tar, or no tiles at all, has no use for.
    if (valhallaTilesLocalPath != null &&
        valhallaTilesLocalPath.endsWith('.zst')) {
      try {
        final zstdAsset = await rootBundle.load('assets/tools/zstd-dbc');
        await _ssh.uploadFile(
          zstdAsset.buffer.asUint8List(),
          '/data/installer/zstd-dbc',
        );
        await _ssh.runCommand('chmod +x /data/installer/zstd-dbc');
        debugPrint(
          'Trampoline: staged zstd for the dashboard '
          '(${zstdAsset.lengthInBytes} bytes)',
        );
      } catch (e) {
        // The trampoline probes the dashboard's own zstd first and only
        // reaches for this one when there is none, so a board that has it is
        // unaffected by this having failed.
        debugPrint('Trampoline: zstd helper not staged ($e)');
      }
    }

    // The flasher and fw_setenv/fw_env tools are only needed to write the
    // stage-0 image, so an upgrade (no dbcImageLocalPath) skips both and
    // never pushes tools it will never run.
    if (dbcImageLocalPath != null) {
      // Upload ARM flasher binary for DBC flash (has bmap + progress support)
      setStep('flasher', SubstepState.active);
      onProgress?.call(l.uploadFlasher, 0.94);
      try {
        final flasherAsset = await rootBundle.load('assets/tools/librescoot-flasher-linux-arm');
        debugPrint('Trampoline: loaded flasher-linux-arm (${flasherAsset.lengthInBytes} bytes)');
        await _ssh.uploadFile(
          flasherAsset.buffer.asUint8List(),
          '/data/installer/librescoot-flasher',
        );
        await _ssh.runCommand('chmod +x /data/installer/librescoot-flasher');
        setStep('flasher', SubstepState.done);
      } catch (e) {
        // trampoline.sh falls back to `gunzip | dd oflag=direct` when the
        // flasher is not executable on the board, so the write still happens
        // without the bmap fast path.
        debugPrint('Trampoline: ARM flasher not uploaded ($e), dd fallback');
        setStep('flasher', SubstepState.degraded, detail: 'dd fallback');
      }

      // Upload stock DBC fw_setenv binary + DBC-specific fw_env config
      setStep('fwtools', SubstepState.active);
      onProgress?.call(l.uploadFwTools, 0.96);
      try {
        await stageDbcBootloaderTools(
          loadAsset: rootBundle.load,
          uploadFile: (content, remotePath) =>
              _ssh.uploadFile(content, remotePath),
          runCommand: (command) => _ssh.runCommand(command),
        );
        setStep('fwtools', SubstepState.done);
      } catch (e) {
        debugPrint('Trampoline: failed to upload DBC tools: $e');
        setStep('fwtools', SubstepState.failed, detail: e.toString());
        rethrow;
      }
    }

    // Always regenerate the trampoline script (small, config may have changed)
    setStep('script', SubstepState.active);
    debugPrint('Trampoline: generating and uploading trampoline script...');
    onProgress?.call(l.uploadScript, 0.98);
    // A stage-0 image means this is a flash job; no image means upgrade,
    // where the artifact goes straight through the on-device update queue.
    final upgradeMode = dbcImageLocalPath == null;
    final dbcRemotePath = dbcImageLocalPath == null
        ? ''
        : '/data/installer/${File(dbcImageLocalPath).uri.pathSegments.last}';
    final dbcMenderRemotePath = dbcArtifactLocalPath == null
        ? ''
        : '/data/installer/${File(dbcArtifactLocalPath).uri.pathSegments.last}';

    final script = await generateScript(
      upgradeMode: upgradeMode,
      dbcImagePath: dbcRemotePath,
      dbcMenderPath: dbcMenderRemotePath,
      dbcTargetVersion: dbcTargetVersion ?? '',
      finish: finish,
      messages: messages,
      region: region,
      installTiles: osmTilesLocalPath != null || valhallaTilesLocalPath != null,
      valhallaTilesFilename: valhallaTilesLocalPath == null
          ? null
          : File(valhallaTilesLocalPath).uri.pathSegments.last,
    );
    // Ensure Unix line endings (LF only): Windows may introduce CRLF which
    // breaks the shebang line and prevents execution on Linux.
    final cleanScript = script.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    debugPrint('Trampoline: script generated (${cleanScript.length} chars)');
    // Unnumbered on purpose. The coordinator at /data/onboot.sh runs the
    // numbered phases it finds; this one is launched over the link and carries
    // a DBC flash, so a board that died in the middle of it must not come back
    // and re-flash a dashboard with nobody watching.
    await _ssh.runCommand('mkdir -p ${SshService.installerScriptsDir}');
    await _ssh.uploadFile(
      Uint8List.fromList(utf8.encode(cleanScript)),
      '${SshService.installerScriptsDir}/trampoline.sh',
    );
    // Before anything can queue a phase, so the boot path never depends on
    // whether the run got far enough to arrange its own recovery.
    await _ssh.installOnbootShim();
    debugPrint('Trampoline: script uploaded');

    // The MDB's own artifact and the reboot that activates it. Queued ahead
    // of the dashboard phase so its install is already running while the
    // dashboard is flashed, and ahead of the handover so the vehicle is on
    // its real image by the time anything unlocks it.
    await _ssh.uploadFile(
      Uint8List.fromList(utf8.encode(MdbArtifactScript.render(
        template: await MdbArtifactScript.loadTemplate(),
        runId: runId,
        artifactPath: mdbArtifactPath,
      ))),
      MdbArtifactScript.remotePath,
    );
    debugPrint('Trampoline: queued ${MdbArtifactScript.phaseName}');

    await _ssh.uploadFile(
      Uint8List.fromList(utf8.encode(RebootPhaseScript.render(
        template: await RebootPhaseScript.loadTemplate(),
        runId: runId,
      ))),
      RebootPhaseScript.remotePath,
    );
    debugPrint('Trampoline: queued ${RebootPhaseScript.phaseName}');

    // Every run that reaches the trampoline now ends in a reboot, so the
    // handover always happens on the far side of one and always belongs to
    // the coordinator. It used to be queued only for a device finish, because
    // an attended run would otherwise have handed the vehicle back in the
    // middle of the install, at the MDB reboot that no longer exists.
    {
      final finalize = FinalizeScript.render(
        template: await FinalizeScript.loadTemplate(),
        mdbAction: finish.mdbAction.name,
        runId: runId,
        mode: upgradeMode ? 'upgrade' : 'flash',
        language: finish.language,
        channel: finish.otaChannel,
        mdbVersion: finish.mdbTargetVersion,
        dbcVersion: dbcTargetVersion ?? '',
        dbcAction: dbcArtifactLocalPath != null || dbcImageLocalPath != null
            ? (upgradeMode ? 'upgrade' : 'cleanInstall')
            : 'leave',
        releaseTag: releaseTag,
        region: region?.slug ?? '',
      );
      await _ssh.uploadFile(
        Uint8List.fromList(utf8.encode(finalize)),
        FinalizeScript.remotePath,
      );
      debugPrint('Trampoline: queued ${FinalizeScript.phaseName}');
    }
    setStep('script', SubstepState.done);

    onProgress?.call(l.complete, 1.0);
    debugPrint('Trampoline: uploadAll complete');
  }

  /// Start the trampoline script on MDB in background.
  Future<void> start({required String runId}) async {
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(runId)) {
      throw ArgumentError.value(runId, 'runId', 'contains unsafe characters');
    }
    // A leftover trampoline from an abandoned run would race this one over the
    // USB role and the dashboard's power. The pattern is bracketed so pgrep and
    // pkill cannot match their own command line, and the kill is its own
    // command because a combined one would carry the pattern in the launcher's
    // arguments and take the launcher with it.
    await _ssh.runCommand(
      "pkill -f 'installer/scripts/[t]rampoline.sh' 2>/dev/null; true",
    );
    await _ssh.runCommand(
      'rm -f ${SshService.installerLastInstall}; '
      'mkdir -p /data/installer; '
      "printf '%s\\n' '$runId' > /data/installer/.run-id.tmp; "
      'mv -f /data/installer/.run-id.tmp /data/installer/run-id',
    );
    await _ssh.writeInstallRunState(
      runId: runId,
      content: serializeInstallRunState(
        runId: runId,
        actor: 'installer',
        stage: 'trampoline-armed',
      ),
    );

    // An old status file reads as this run's verdict if the arming below fails
    // silently, so it goes before anything can be believed.
    await _ssh.runCommand(
      'rm -f /data/installer/trampoline-status; '
      'nohup ${SshService.installerScriptsDir}/trampoline.sh '
      '> /data/installer/trampoline-stdout.log 2>&1 &',
    );

    // nohup backgrounds the process, so the launching shell reports success
    // whether or not it survived. Without this check a trampoline that never
    // started is indistinguishable from one still working, and the user has
    // already swapped the cable by the time anyone could tell.
    for (var attempt = 0; attempt < 5; attempt++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await isRunning()) return;
    }
    throw Exception('Trampoline did not start on the MDB');
  }

  /// Whether a trampoline process is running on the MDB. The bracketed pattern
  /// keeps pgrep from matching its own command line.
  Future<bool> isRunning() async {
    final pid = (await _ssh.runCommand(
      "pgrep -f 'installer/[t]rampoline.sh' 2>/dev/null; true",
    )).trim();
    return pid.isNotEmpty;
  }

  /// Read trampoline status (call after reconnecting to MDB).
  Future<TrampolineStatus> readStatus({String? expectedRunId}) async {
    return _ssh.readTrampolineStatus(expectedRunId: expectedRunId);
  }
}

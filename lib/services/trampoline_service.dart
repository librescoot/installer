import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/region.dart';
import '../models/trampoline_status.dart';
import 'ssh_service.dart';

class TrampolineService {
  final SshService _ssh;

  TrampolineService(this._ssh);

  /// Generate the trampoline script from template with actual paths.
  Future<String> generateScript({
    required String dbcImagePath,
    Region? region,
    bool installTiles = false,
  }) async {
    var template = await rootBundle.loadString('assets/trampoline.sh.template');

    template = template
        .replaceAll('{{DBC_IMAGE_PATH}}', dbcImagePath)
        .replaceAll('{{INSTALL_TILES}}', installTiles ? 'true' : 'false')
        .replaceAll(
          '{{OSM_TILES_FILE}}',
          installTiles && region != null ? '/data/${region.osmTilesFilename}' : '',
        )
        .replaceAll(
          '{{VALHALLA_TILES_FILE}}',
          installTiles && region != null ? '/data/${region.valhallaTilesFilename}' : '',
        );

    return template;
  }

  /// Check if a remote file exists and matches the local file's md5.
  Future<bool> _remoteFileMatches(String localPath, String remotePath) async {
    try {
      // Get local md5
      final localResult = await Process.run('md5sum', [localPath]);
      if (localResult.exitCode != 0) return false;
      final localMd5 = localResult.stdout.toString().split(' ').first.trim();

      // Get remote md5 (large files can take a while)
      final remoteMd5 = (await _ssh.runCommand(
        'md5sum "$remotePath" 2>/dev/null',
        timeout: const Duration(minutes: 5),
      )).trim().split(' ').first;

      final match = localMd5.isNotEmpty && localMd5 == remoteMd5;
      if (match) {
        debugPrint('Trampoline: $remotePath already exists and matches (md5=$localMd5)');
      }
      return match;
    } catch (_) {
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
http.server.HTTPServer(('0.0.0.0', 8080), H).serve_forever()
''';

  static const _mdbUploadUrl = 'http://192.168.7.1:8080';

  /// Start HTTP upload server on MDB (much faster than SCP/SFTP)
  Future<void> _startUploadServer() async {
    debugPrint('Trampoline: writing upload server script...');
    await _ssh.runCommand("cat > /tmp/upload_srv.py << 'PYEOF'\n$_uploadServerScript\nPYEOF");
    debugPrint('Trampoline: starting upload server...');
    await _ssh.runCommand('nohup python3 /tmp/upload_srv.py > /tmp/upload_srv.log 2>&1 &');

    // Wait for server to be ready — retry connection
    debugPrint('Trampoline: waiting for upload server...');
    final client = HttpClient();
    try {
      for (var i = 0; i < 10; i++) {
        try {
          final req = await client.getUrl(Uri.parse('$_mdbUploadUrl/'));
          final resp = await req.close().timeout(const Duration(seconds: 2));
          await resp.drain<void>();
          debugPrint('Trampoline: HTTP upload server ready (attempt ${i + 1})');
          return;
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      throw Exception('Upload server not responsive after 5s');
    } finally {
      client.close();
    }
  }

  Future<void> _stopUploadServer() async {
    try {
      await _ssh.runCommand('kill \$(pgrep -f upload_srv.py) 2>/dev/null; rm -f /tmp/upload_srv.py');
    } catch (_) {}
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

    // Raw socket — write HTTP headers then stream file data with real progress
    final socket = await Socket.connect('192.168.7.1', 8080);
    try {
      // Send HTTP PUT header
      final header = 'PUT $remoteFilename HTTP/1.1\r\n'
          'Host: 192.168.7.1:8080\r\n'
          'Content-Length: $fileSize\r\n'
          'Connection: close\r\n'
          '\r\n';
      socket.add(header.codeUnits);

      // Stream file in 64KB chunks — socket.add + flush gives real backpressure
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

  /// Upload DBC image, tiles, and trampoline script to MDB.
  Future<void> uploadAll({
    required String dbcImageLocalPath,
    String? dbcBmapLocalPath,
    String? osmTilesLocalPath,
    String? valhallaTilesLocalPath,
    Region? region,
    void Function(String status, double progress)? onProgress,
  }) async {
    final filesToUpload = <MapEntry<String, String>>[];

    final dbcFilename = File(dbcImageLocalPath).uri.pathSegments.last;
    filesToUpload.add(MapEntry(dbcImageLocalPath, '/data/$dbcFilename'));

    if (dbcBmapLocalPath != null) {
      final bmapFilename = File(dbcBmapLocalPath).uri.pathSegments.last;
      filesToUpload.add(MapEntry(dbcBmapLocalPath, '/data/$bmapFilename'));
    }

    if (osmTilesLocalPath != null && region != null) {
      filesToUpload.add(MapEntry(osmTilesLocalPath, '/data/${region.osmTilesFilename}'));
    }
    if (valhallaTilesLocalPath != null && region != null) {
      filesToUpload.add(MapEntry(valhallaTilesLocalPath, '/data/${region.valhallaTilesFilename}'));
    }

    // Check which files need uploading
    onProgress?.call('Checking existing files...', 0.0);
    final needsUpload = <bool>[];
    final fileSizes = <int>[];
    var totalBytes = 0;
    for (final entry in filesToUpload) {
      final size = await File(entry.key).length();
      fileSizes.add(size);
      final filename = File(entry.key).uri.pathSegments.last;
      onProgress?.call('Checking $filename...', 0.0);
      final matches = await _remoteFileMatches(entry.key, entry.value);
      needsUpload.add(!matches);
      if (!matches) totalBytes += size;
    }

    if (totalBytes == 0) {
      onProgress?.call('All files already on device', 0.95);
    } else {
      final skipped = needsUpload.where((n) => !n).length;
      if (skipped > 0) {
        debugPrint('Trampoline: skipping $skipped files that already match');
      }

      // Start HTTP upload server on MDB (8+ MB/s vs ~2 MB/s via SFTP)
      onProgress?.call('Starting upload server...', 0.0);
      await _startUploadServer();

      var bytesSoFar = 0;
      final stopwatch = Stopwatch()..start();
      try {
        for (var i = 0; i < filesToUpload.length; i++) {
          if (!needsUpload[i]) continue;

          final entry = filesToUpload[i];
          final filename = File(entry.key).uri.pathSegments.last;
          onProgress?.call('Uploading $filename...', bytesSoFar / totalBytes);
          final baseBytes = bytesSoFar;
          await _uploadViaHttp(
            entry.key,
            entry.value,
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
                eta = ' — ${mins}m ${secs}s remaining';
              }
              onProgress?.call(
                'Uploading $filename... ${mb.toStringAsFixed(0)}/${totalMb.toStringAsFixed(0)} MB$eta',
                overall,
              );
            },
          );
          bytesSoFar += fileSizes[i];
        }
      } finally {
        await _stopUploadServer();
      }
    }

    // Upload ARM flasher binary for DBC flash (has bmap + progress support)
    onProgress?.call('Uploading flasher...', 0.94);
    try {
      final flasherAsset = await rootBundle.load('assets/tools/librescoot-flasher-arm');
      debugPrint('Trampoline: loaded flasher-arm (${flasherAsset.lengthInBytes} bytes)');
      await _ssh.uploadFile(
        flasherAsset.buffer.asUint8List(),
        '/data/librescoot-flasher',
      );
      await _ssh.runCommand('chmod +x /data/librescoot-flasher');
    } catch (e) {
      debugPrint('Trampoline: failed to upload ARM flasher: $e');
    }

    // Upload stock DBC fw_setenv binary + DBC-specific fw_env config
    onProgress?.call('Uploading DBC tools...', 0.96);
    try {
      await _ssh.runCommand('mkdir -p /data/fwtools/stock-dbc');

      final stockFwSetenv = await rootBundle.load('assets/tools/fw_setenv-dbc');
      debugPrint('Trampoline: loaded fw_setenv-dbc (${stockFwSetenv.lengthInBytes} bytes)');
      await _ssh.uploadFile(
        stockFwSetenv.buffer.asUint8List(),
        '/data/fwtools/stock-dbc/fw_setenv',
      );
      // Make executable
      await _ssh.runCommand('chmod +x /data/fwtools/stock-dbc/fw_setenv');

      final dbcFwEnvConfig = await rootBundle.load('assets/tools/fw_env-dbc.config');
      await _ssh.uploadFile(
        dbcFwEnvConfig.buffer.asUint8List(),
        '/data/fwtools/stock-dbc/fw_env.config',
      );
    } catch (e) {
      debugPrint('Trampoline: failed to upload DBC tools: $e');
    }

    // Always regenerate the trampoline script (small, config may have changed)
    debugPrint('Trampoline: generating and uploading trampoline script...');
    onProgress?.call('Uploading trampoline script...', 0.98);
    final dbcRemotePath = '/data/$dbcFilename';

    final script = await generateScript(
      dbcImagePath: dbcRemotePath,
      region: region,
      installTiles: osmTilesLocalPath != null || valhallaTilesLocalPath != null,
    );
    debugPrint('Trampoline: script generated (${script.length} chars)');
    await _ssh.uploadFile(
      Uint8List.fromList(script.codeUnits),
      '/data/trampoline.sh',
    );
    debugPrint('Trampoline: script uploaded');

    onProgress?.call('Upload complete', 1.0);
    debugPrint('Trampoline: uploadAll complete');
  }

  /// Start the trampoline script on MDB in background.
  Future<void> start() async {
    await _ssh.runCommand('nohup /data/trampoline.sh > /data/trampoline-stdout.log 2>&1 &');
  }

  /// Read trampoline status (call after reconnecting to MDB).
  Future<TrampolineStatus> readStatus() async {
    return _ssh.readTrampolineStatus();
  }
}

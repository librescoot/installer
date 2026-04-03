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

      var bytesSoFar = 0;
      for (var i = 0; i < filesToUpload.length; i++) {
        if (!needsUpload[i]) continue;

        final entry = filesToUpload[i];
        final filename = File(entry.key).uri.pathSegments.last;
        onProgress?.call('Uploading $filename...', bytesSoFar / totalBytes);
        final bytes = await File(entry.key).readAsBytes();
        final baseBytes = bytesSoFar;
        await _ssh.uploadFile(
          Uint8List.fromList(bytes),
          entry.value,
          onProgress: (sent, total) {
            final overall = (baseBytes + sent) / totalBytes;
            final mb = sent / (1024 * 1024);
            final totalMb = total / (1024 * 1024);
            onProgress?.call(
              'Uploading $filename... ${mb.toStringAsFixed(0)}/${totalMb.toStringAsFixed(0)} MB',
              overall,
            );
          },
        );
        bytesSoFar += fileSizes[i];
      }
    }

    // Upload stock DBC fw_setenv binary + DBC-specific fw_env config
    // These are the DBC-specific versions (different binary than MDB)
    onProgress?.call('Uploading DBC tools...', 0.96);
    try {
      await _ssh.runCommand('mkdir -p /data/fwtools/stock-dbc');

      final stockFwSetenv = await rootBundle.load('assets/tools/fw_setenv-dbc');
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
    onProgress?.call('Uploading trampoline script...', 0.98);
    final dbcRemotePath = '/data/$dbcFilename';
    final script = await generateScript(
      dbcImagePath: dbcRemotePath,
      region: region,
      installTiles: osmTilesLocalPath != null || valhallaTilesLocalPath != null,
    );
    await _ssh.uploadFile(
      Uint8List.fromList(script.codeUnits),
      '/data/trampoline.sh',
    );

    onProgress?.call('Upload complete', 1.0);
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

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

  /// Upload DBC image, tiles, and trampoline script to MDB.
  Future<void> uploadAll({
    required String dbcImageLocalPath,
    String? osmTilesLocalPath,
    String? valhallaTilesLocalPath,
    Region? region,
    void Function(String status, double progress)? onProgress,
  }) async {
    final filesToUpload = <MapEntry<String, String>>[];

    final dbcFilename = File(dbcImageLocalPath).uri.pathSegments.last;
    filesToUpload.add(MapEntry(dbcImageLocalPath, '/data/$dbcFilename'));

    if (osmTilesLocalPath != null && region != null) {
      filesToUpload.add(MapEntry(osmTilesLocalPath, '/data/${region.osmTilesFilename}'));
    }
    if (valhallaTilesLocalPath != null && region != null) {
      filesToUpload.add(MapEntry(valhallaTilesLocalPath, '/data/${region.valhallaTilesFilename}'));
    }

    var uploaded = 0;
    for (final entry in filesToUpload) {
      final filename = File(entry.key).uri.pathSegments.last;
      onProgress?.call('Uploading $filename...', uploaded / filesToUpload.length);
      final bytes = await File(entry.key).readAsBytes();
      await _ssh.uploadFile(Uint8List.fromList(bytes), entry.value);
      uploaded++;
    }

    onProgress?.call('Uploading trampoline script...', 0.95);
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

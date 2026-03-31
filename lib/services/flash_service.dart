import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Progress callback for flashing operations
typedef ProgressCallback = void Function(double progress, String status);

/// Result of a flash operation
class FlashResult {
  final bool success;
  final String? error;
  final String? checksum;

  FlashResult({
    required this.success,
    this.error,
    this.checksum,
  });
}

/// Safety validation result
class SafetyCheck {
  final bool passed;
  final List<String> warnings;
  final List<String> errors;

  SafetyCheck({
    required this.passed,
    this.warnings = const [],
    this.errors = const [],
  });
}

/// Service for writing firmware images to devices
class FlashService {
  /// Build the command(s) that would be used for flashing without executing.
  Future<String> buildFlashPlan(
    String imagePath,
    String devicePath,
  ) async {
    final isCompressed = imagePath.endsWith('.gz');

    if (Platform.isWindows) {
      final diskMatch = RegExp(r'PHYSICALDRIVE(\d+)').firstMatch(devicePath);
      final diskNumber = diskMatch?.group(1) ?? '?';
      final ddPath = await _getDdPath() ?? '<dd.exe-not-found>';

      if (isCompressed) {
        return [
          'diskpart: select disk $diskNumber',
          'diskpart: offline disk',
          'diskpart: clean',
          'powershell: decompress "$imagePath" -> "$devicePath"',
          'diskpart: select disk $diskNumber',
          'diskpart: online disk',
        ].join('\n');
      }

      return [
        'diskpart: select disk $diskNumber',
        'diskpart: offline disk',
        'diskpart: clean',
        '$ddPath if=$imagePath of=$devicePath bs=4M',
        'diskpart: select disk $diskNumber',
        'diskpart: online disk',
      ].join('\n');
    }

    if (Platform.isMacOS) {
      final diskName = devicePath.replaceFirst('/dev/rdisk', '/dev/disk');
      if (isCompressed) {
        return [
          'diskutil unmountDisk $diskName',
          'gunzip -c "$imagePath" | sudo dd of="$devicePath" bs=4m status=progress',
          '# macOS dd progress: press Ctrl+T while command is running',
          'sync',
          'diskutil eject $diskName',
        ].join('\n');
      }

      return [
        'diskutil unmountDisk $diskName',
        'sudo dd if=$imagePath of=$devicePath bs=4m status=progress',
        '# macOS dd progress: press Ctrl+T while command is running',
        'sync',
        'diskutil eject $diskName',
      ].join('\n');
    }

    if (Platform.isLinux) {
      if (isCompressed) {
        return [
          'umount <partitions of $devicePath>',
          'gunzip -c "$imagePath" | sudo dd of="$devicePath" bs=4M oflag=direct status=progress',
          'sync',
        ].join('\n');
      }

      return [
        'umount <partitions of $devicePath>',
        'sudo dd if=$imagePath of=$devicePath bs=4M oflag=direct status=progress',
        'sync',
      ].join('\n');
    }

    return 'Unsupported platform';
  }

  /// Validate that a device is safe to flash
  ///
  /// Returns a SafetyCheck with any warnings or errors.
  /// Flashing should ONLY proceed if passed is true.
  SafetyCheck validateDevice({
    required String devicePath,
    required int? sizeBytes,
    required bool isRemovable,
    required bool isSystemDisk,
    required int vendorId,
    required int productId,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // CRITICAL: Never flash system disk
    if (isSystemDisk) {
      errors.add('DANGER: This appears to be a system disk. Flashing is blocked.');
    }

    // Must be correct vendor ID
    if (vendorId != 0x0525) {
      errors.add('Wrong vendor ID: 0x${vendorId.toRadixString(16)} (expected 0x0525)');
    }

    // Must be in mass storage mode (PID A4A5)
    if (productId != 0xA4A5) {
      errors.add('Wrong product ID: 0x${productId.toRadixString(16)} (expected 0xa4a5)');
    }

    // Size sanity check
    if (sizeBytes != null) {
      const minSize = 1 * 1024 * 1024 * 1024; // 1 GB
      const maxSize = 16 * 1024 * 1024 * 1024; // 16 GB

      if (sizeBytes < minSize) {
        errors.add('Device too small: ${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB (minimum 1 GB)');
      }
      if (sizeBytes > maxSize) {
        errors.add('Device too large: ${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB (maximum 16 GB)');
      }
    } else {
      warnings.add('Could not determine device size');
    }

    // Warn if not detected as removable (but don't block).
    // macOS often reports USB gadget media as non-removable.
    if (!isRemovable && !Platform.isMacOS) {
      warnings.add('Device not detected as removable media');
    }

    // Path sanity checks
    if (Platform.isWindows) {
      if (!devicePath.contains('PHYSICALDRIVE')) {
        errors.add('Invalid Windows device path: $devicePath');
      }
      // Never allow PHYSICALDRIVE0
      if (devicePath.contains('PHYSICALDRIVE0')) {
        errors.add('DANGER: Cannot flash PHYSICALDRIVE0 (system disk)');
      }
    } else if (Platform.isMacOS) {
      if (devicePath.trim().isEmpty || !devicePath.startsWith('/dev/')) {
        errors.add('Invalid macOS device path: $devicePath');
      }
      // Never allow disk0 or disk1 (typically system)
      if (devicePath.contains('disk0') || devicePath.contains('rdisk0')) {
        errors.add('DANGER: Cannot flash disk0 (system disk)');
      }
      if (RegExp(r'/r?disk1($|s\d+)').hasMatch(devicePath)) {
        warnings.add('disk1 may be the system disk - verify carefully');
      }
    } else if (Platform.isLinux) {
      if (devicePath.trim().isEmpty || !devicePath.startsWith('/dev/')) {
        errors.add('Invalid Linux device path: $devicePath');
      }
      // Never allow sda (typically system)
      if (devicePath.endsWith('/dev/sda') || devicePath == '/dev/sda') {
        errors.add('DANGER: Cannot flash /dev/sda (likely system disk)');
      }
      // Never allow nvme0n1 (system NVMe)
      if (devicePath.contains('nvme0n1')) {
        errors.add('DANGER: Cannot flash nvme0n1 (likely system disk)');
      }
    }

    return SafetyCheck(
      passed: errors.isEmpty,
      warnings: warnings,
      errors: errors,
    );
  }

  /// Write a firmware image to the target device
  ///
  /// [imagePath] - Path to the firmware image (.wic or .wic.gz)
  /// [devicePath] - Device path (e.g., /dev/rdisk2, \\.\PHYSICALDRIVE1)
  /// [onProgress] - Optional callback for progress updates
  Future<FlashResult> writeImage(
    String imagePath,
    String devicePath, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.0, 'Preparing...');

    // Validate paths
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      return FlashResult(success: false, error: 'Image file not found: $imagePath');
    }

    // Check if image is compressed
    final isCompressed = imagePath.endsWith('.gz');

    try {
      if (Platform.isWindows) {
        return _writeWindows(imagePath, devicePath, isCompressed, onProgress);
      } else if (Platform.isMacOS) {
        return _writeMacOS(imagePath, devicePath, isCompressed, onProgress);
      } else if (Platform.isLinux) {
        return _writeLinux(imagePath, devicePath, isCompressed, onProgress);
      }

      return FlashResult(success: false, error: 'Unsupported platform');
    } catch (e) {
      return FlashResult(success: false, error: e.toString());
    }
  }

  Future<FlashResult> _writeWindows(
    String imagePath,
    String devicePath,
    bool isCompressed,
    ProgressCallback? onProgress,
  ) async {
    onProgress?.call(0.1, 'Taking disk offline...');

    // Extract disk number from path like \\.\PHYSICALDRIVE1
    final diskMatch = RegExp(r'PHYSICALDRIVE(\d+)').firstMatch(devicePath);
    if (diskMatch == null) {
      return FlashResult(success: false, error: 'Invalid device path: $devicePath');
    }
    final diskNumber = diskMatch.group(1);

    // Take disk offline with diskpart
    final offlineResult = await _runDiskpart([
      'select disk $diskNumber',
      'offline disk',
      'clean',
    ]);

    if (!offlineResult) {
      return FlashResult(success: false, error: 'Failed to prepare disk');
    }

    onProgress?.call(0.2, 'Writing image...');

    // Use dd.exe from assets
    final ddPath = await _getDdPath();
    if (ddPath == null) {
      return FlashResult(success: false, error: 'dd.exe not found in assets');
    }

    ProcessResult result;
    if (isCompressed) {
      // Decompress and write in one pipeline
      // PowerShell: [System.IO.Compression.GZipStream] for decompression
      result = await Process.run(
        'powershell',
        [
          '-Command',
          '''
          \$input = [System.IO.File]::OpenRead("$imagePath")
          \$gzip = New-Object System.IO.Compression.GZipStream(\$input, [System.IO.Compression.CompressionMode]::Decompress)
          \$output = [System.IO.File]::OpenWrite("$devicePath")
          \$gzip.CopyTo(\$output)
          \$output.Close()
          \$gzip.Close()
          \$input.Close()
          ''',
        ],
        runInShell: true,
      );
    } else {
      // Direct write with dd
      result = await Process.run(
        ddPath,
        [
          'if=$imagePath',
          'of=$devicePath',
          'bs=4M',
        ],
        runInShell: true,
      );
    }

    if (result.exitCode != 0) {
      // Try to bring disk online before returning error
      await _runDiskpart(['select disk $diskNumber', 'online disk']);
      return FlashResult(success: false, error: 'Write failed: ${result.stderr}');
    }

    onProgress?.call(0.9, 'Bringing disk online...');

    // Bring disk back online
    await _runDiskpart([
      'select disk $diskNumber',
      'online disk',
    ]);

    onProgress?.call(1.0, 'Complete');

    return FlashResult(success: true);
  }

  Future<bool> _runDiskpart(List<String> commands) async {
    // Create temp script file
    final tempDir = Directory.systemTemp;
    final scriptFile = File(path.join(tempDir.path, 'diskpart_script.txt'));
    await scriptFile.writeAsString(commands.join('\n'));

    try {
      final result = await Process.run(
        'diskpart',
        ['/s', scriptFile.path],
        runInShell: true,
      );
      return result.exitCode == 0;
    } finally {
      await scriptFile.delete();
    }
  }

  Future<String?> _getDdPath() async {
    // Look for dd.exe in assets/tools/
    final candidates = [
      path.join(Directory.current.path, 'assets', 'tools', 'dd.exe'),
      path.join(Platform.resolvedExecutable, '..', 'data', 'flutter_assets', 'assets', 'tools', 'dd.exe'),
    ];

    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }

  Future<FlashResult> _writeMacOS(
    String imagePath,
    String devicePath,
    bool isCompressed,
    ProgressCallback? onProgress,
  ) async {
    onProgress?.call(0.1, 'Unmounting disk...');

    // Unmount disk first
    final diskName = devicePath.replaceFirst('/dev/rdisk', '/dev/disk');
    final unmountResult = await Process.run('diskutil', ['unmountDisk', diskName]);
    if (unmountResult.exitCode != 0) {
      // Ignore unmount errors - disk might not be mounted
    }

    onProgress?.call(0.2, 'Writing image...');

    final imageSize = await _estimateImageSizeBytes(imagePath, isCompressed);
    final stderrBuffer = StringBuffer();
    int? lastBytesWritten;

    Process process;
    if (isCompressed) {
      // gunzip -c image.wic.gz | dd of=/dev/rdiskX bs=4m
      process = await Process.start(
        'sh',
        [
          '-c',
          'gunzip -c "$imagePath" | dd of="$devicePath" bs=4m status=progress',
        ],
      );
    } else {
      process = await Process.start(
        'dd',
        ['if=$imagePath', 'of=$devicePath', 'bs=4m', 'status=progress'],
      );
    }

    process.stdout.listen((_) {});
    await for (final chunk in process.stderr.transform(utf8.decoder)) {
      stderrBuffer.write(chunk);
      final bytes = _extractLastDdBytes(chunk);
      if (bytes != null && bytes != lastBytesWritten) {
        lastBytesWritten = bytes;
        if (imageSize != null && imageSize > 0) {
          final fraction = (bytes / imageSize).clamp(0.0, 1.0);
          onProgress?.call(0.2 + (0.7 * fraction), 'Writing image... ${(fraction * 100).toStringAsFixed(1)}%');
        } else {
          final mb = bytes / (1024 * 1024);
          onProgress?.call(0.2, 'Writing image... ${mb.toStringAsFixed(1)} MB written');
        }
      }
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      return FlashResult(success: false, error: 'Write failed: ${stderrBuffer.toString().trim()}');
    }

    onProgress?.call(0.9, 'Syncing...');

    // Sync to ensure all data is written
    await Process.run('sync', []);

    // Eject disk
    await Process.run('diskutil', ['eject', diskName]);

    onProgress?.call(1.0, 'Complete');

    return FlashResult(success: true);
  }

  Future<int?> _estimateImageSizeBytes(String imagePath, bool isCompressed) async {
    try {
      if (!isCompressed) {
        return await File(imagePath).length();
      }
      final result = await Process.run('gzip', ['-l', imagePath]);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().trim().split('\n');
        if (lines.length >= 2) {
          final fields = lines.last.trim().split(RegExp(r'\s+'));
          if (fields.length >= 2) {
            return int.tryParse(fields[1]);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  int? _extractLastDdBytes(String text) {
    final matches = RegExp(r'(\d+)\s+bytes').allMatches(text);
    if (matches.isEmpty) return null;
    return int.tryParse(matches.last.group(1)!);
  }

  Future<FlashResult> _writeLinux(
    String imagePath,
    String devicePath,
    bool isCompressed,
    ProgressCallback? onProgress,
  ) async {
    onProgress?.call(0.1, 'Unmounting partitions...');

    // Unmount any partitions
    final partitions = await _findLinuxPartitions(devicePath);
    for (final partition in partitions) {
      await Process.run('umount', [partition]);
    }

    onProgress?.call(0.2, 'Writing image...');

    ProcessResult result;
    if (isCompressed) {
      result = await Process.run(
        'sh',
        [
          '-c',
          'gunzip -c "$imagePath" | dd of="$devicePath" bs=4M oflag=direct status=progress',
        ],
      );
    } else {
      result = await Process.run(
        'dd',
        [
          'if=$imagePath',
          'of=$devicePath',
          'bs=4M',
          'oflag=direct',
          'status=progress',
        ],
      );
    }

    if (result.exitCode != 0) {
      return FlashResult(success: false, error: 'Write failed: ${result.stderr}');
    }

    onProgress?.call(0.9, 'Syncing...');

    await Process.run('sync', []);

    onProgress?.call(1.0, 'Complete');

    return FlashResult(success: true);
  }

  Future<List<String>> _findLinuxPartitions(String devicePath) async {
    final partitions = <String>[];
    try {
      final result = await Process.run('lsblk', ['-n', '-o', 'NAME', devicePath]);
      if (result.exitCode == 0) {
        for (final line in result.stdout.toString().split('\n')) {
          final name = line.trim();
          if (name.isNotEmpty && name != path.basename(devicePath)) {
            partitions.add('/dev/$name');
          }
        }
      }
    } catch (_) {}
    return partitions;
  }

  // ---- Two-phase flash ----

  static const bootAreaBytes = 24 * 1024 * 1024; // 24MB
  static const ddBlockSize = 4 * 1024 * 1024; // 4MB
  static const bootAreaBlocks = bootAreaBytes ~/ ddBlockSize; // 6 blocks

  /// Two-phase flash: write partitions first (safe), then boot sector (commits).
  Future<void> writeTwoPhase(
    String imagePath,
    String devicePath, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final isCompressed = imagePath.endsWith('.gz');

    // Phase A: write partitions (everything from 24MB onwards)
    onProgress?.call(0.0, 'Phase A: Writing partitions...');
    await _runDdPhase(
      imagePath: imagePath,
      devicePath: devicePath,
      isCompressed: isCompressed,
      skip: bootAreaBlocks,
      seek: bootAreaBlocks,
      onProgress: (p, msg) => onProgress?.call(p * 0.9, 'Phase A: $msg'),
    );

    // Phase B: write boot sector (first 24MB)
    onProgress?.call(0.9, 'Phase B: Writing boot sector...');
    await _runDdPhase(
      imagePath: imagePath,
      devicePath: devicePath,
      isCompressed: isCompressed,
      count: bootAreaBlocks,
      onProgress: (p, msg) => onProgress?.call(0.9 + p * 0.1, 'Phase B: $msg'),
    );

    // Sync
    onProgress?.call(1.0, 'Syncing...');
    if (Platform.isMacOS) {
      await Process.run('sync', []);
      await Process.run('diskutil', ['eject', devicePath]);
    } else {
      await Process.run('sync', []);
    }
  }

  Future<void> _runDdPhase({
    required String imagePath,
    required String devicePath,
    required bool isCompressed,
    int? skip,
    int? seek,
    int? count,
    void Function(double progress, String message)? onProgress,
  }) async {
    if (Platform.isWindows) {
      await _runDdPhaseWindows(imagePath, devicePath, isCompressed, skip: skip, seek: seek, count: count, onProgress: onProgress);
    } else {
      await _runDdPhaseUnix(imagePath, devicePath, isCompressed, skip: skip, seek: seek, count: count, onProgress: onProgress);
    }
  }

  Future<void> _runDdPhaseUnix(
    String imagePath,
    String devicePath,
    bool isCompressed, {
    int? skip,
    int? seek,
    int? count,
    void Function(double progress, String message)? onProgress,
  }) async {
    // On macOS, use rdisk for raw (faster) access — but only if not already rdisk
    final rawDevice = Platform.isMacOS && !devicePath.contains('rdisk')
        ? devicePath.replaceFirst('/dev/disk', '/dev/rdisk')
        : devicePath;
    final diskName = rawDevice.replaceFirst('/dev/rdisk', '/dev/disk').replaceFirst('/dev/r', '/dev/');

    // Unmount the disk first (macOS auto-mounts)
    if (Platform.isMacOS) {
      debugPrint('Flash: unmounting $diskName');
      final unmountResult = await Process.run('diskutil', ['unmountDisk', diskName]);
      debugPrint('Flash: unmount result: ${unmountResult.exitCode} ${unmountResult.stderr}');
    }

    final bs = Platform.isMacOS ? 'bs=4m' : 'bs=4M';
    final oflag = Platform.isLinux ? 'oflag=direct' : '';

    final ddParams = <String>[
      bs,
      if (skip != null) 'skip=$skip',
      if (seek != null) 'seek=$seek',
      if (count != null) 'count=$count',
      if (oflag.isNotEmpty) oflag,
      'status=progress',
    ];

    final String command;
    if (isCompressed) {
      command = 'gunzip -c "$imagePath" | dd of=$rawDevice ${ddParams.join(' ')} 2>&1';
    } else {
      command = 'dd if="$imagePath" of=$rawDevice ${ddParams.join(' ')} 2>&1';
    }

    debugPrint('Flash: running: $command');
    final process = await Process.start('/bin/sh', ['-c', command]);

    final output = StringBuffer();
    await for (final line in process.stdout.transform(utf8.decoder)) {
      output.write(line);
      final bytesMatch = RegExp(r'(\d+)\s+bytes').firstMatch(line);
      if (bytesMatch != null) {
        final bytes = int.tryParse(bytesMatch.group(1)!);
        if (bytes != null) {
          onProgress?.call(0.5, '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB written');
        }
      }
    }
    final exitCode = await process.exitCode;
    debugPrint('Flash: dd exit code: $exitCode');
    if (exitCode != 0) {
      debugPrint('Flash: dd output: $output');
      throw Exception('dd failed with exit code $exitCode');
    }
  }

  Future<void> _runDdPhaseWindows(
    String imagePath,
    String devicePath,
    bool isCompressed, {
    int? skip,
    int? seek,
    int? count,
    void Function(double progress, String message)? onProgress,
  }) async {
    final ddExePath = await _getDdPath() ?? '${Directory.current.path}/assets/tools/dd.exe';

    final ddArgs = <String>[
      'bs=4M',
      'of=$devicePath',
      if (skip != null) 'skip=$skip',
      if (seek != null) 'seek=$seek',
      if (count != null) 'count=$count',
    ];

    if (isCompressed) {
      final psScript = '''
\$input = [System.IO.File]::OpenRead('$imagePath')
\$gzip = New-Object System.IO.Compression.GZipStream(\$input, [System.IO.Compression.CompressionMode]::Decompress)
\$output = [System.Console]::OpenStandardOutput()
\$gzip.CopyTo(\$output)
\$gzip.Close()
\$input.Close()
''';
      final command = 'powershell -Command "$psScript" | "$ddExePath" ${ddArgs.join(' ')}';
      final result = await Process.run('cmd', ['/c', command]);
      if (result.exitCode != 0) throw Exception('dd.exe failed: ${result.stderr}');
    } else {
      ddArgs.add('if=$imagePath');
      final result = await Process.run(ddExePath, ddArgs);
      if (result.exitCode != 0) throw Exception('dd.exe failed: ${result.stderr}');
    }
  }

  /// Verify the written image by reading and checksumming
  Future<String?> verifyImage(String devicePath, int sizeBytes) async {
    try {
      ProcessResult result;

      if (Platform.isWindows) {
        // Read first 4MB blocks for verification
        final ddPath = await _getDdPath();
        if (ddPath == null) return null;

        final blocks = (sizeBytes / (4 * 1024 * 1024)).ceil();
        result = await Process.run(
          'powershell',
          [
            '-Command',
            '& "$ddPath" if="$devicePath" bs=4M count=$blocks 2>\$null | Get-FileHash -Algorithm MD5 -InputStream ([System.IO.MemoryStream]::new((cat -Encoding Byte))) | Select-Object -ExpandProperty Hash',
          ],
          runInShell: true,
        );
      } else {
        final blocks = (sizeBytes / (4 * 1024 * 1024)).ceil();
        result = await Process.run(
          'sh',
          [
            '-c',
            'dd if="$devicePath" bs=4M count=$blocks 2>/dev/null | md5sum | cut -d" " -f1',
          ],
        );
      }

      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return null;
  }
}

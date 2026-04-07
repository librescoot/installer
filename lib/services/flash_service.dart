import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
          'gunzip -c "$imagePath" | diskwriter $devicePath',
          '# diskwriter uses macOS Authorization Services for raw disk access',
          'sync',
          'diskutil eject $diskName',
        ].join('\n');
      }

      return [
        'diskutil unmountDisk $diskName',
        'cat $imagePath | diskwriter $devicePath',
        '# diskwriter uses macOS Authorization Services for raw disk access',
        'sync',
        'diskutil eject $diskName',
      ].join('\n');
    }

    if (Platform.isLinux) {
      if (isCompressed) {
        return [
          'umount <partitions of $devicePath>',
          'gunzip -c "$imagePath" | sudo dd of="$devicePath" bs=4M iflag=fullblock oflag=direct status=progress',
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

  /// Two-phase flash for Windows using the Go flasher binary.
  Future<void> _writeTwoPhaseWindows(
    String imagePath,
    String devicePath,
    bool isCompressed,
    void Function(double progress, String message)? onProgress, {
    String? bmapPath,
  }) async {
    final flasherPath = await _getFlasherPath();
    if (flasherPath == null) {
      throw Exception('librescoot-flasher.exe not found in app bundle');
    }

    // The Go flasher takes the disk offline before writing, which prevents
    // Windows from interfering. Bmap and two-phase both work with this approach.
    await _writeWithGoFlasher(flasherPath, imagePath, devicePath, bmapPath, true, onProgress);
  }

  Future<bool> _runDiskpart(List<String> commands) async {
    // Create temp script file
    final tempDir = Directory.systemTemp;
    final scriptFile = File(path.join(tempDir.path, 'diskpart_script.txt'));
    await scriptFile.writeAsString(commands.join('\n'));

    try {
      debugPrint('Flash: diskpart script: ${commands.join("; ")}');
      debugPrint('Flash: diskpart script file: ${scriptFile.path}');
      final result = await Process.run(
        r'C:\Windows\System32\diskpart.exe',
        ['/s', scriptFile.path],
      );
      debugPrint('Flash: diskpart exit=${result.exitCode} stdout=${result.stdout} stderr=${result.stderr}');
      return result.exitCode == 0;
    } finally {
      try { await scriptFile.delete(); } catch (_) {}
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

    final rawDevice = !devicePath.contains('rdisk')
        ? devicePath.replaceFirst('/dev/disk', '/dev/rdisk')
        : devicePath;
    final diskName = rawDevice.replaceFirst('/dev/rdisk', '/dev/disk');

    final unmountResult = await Process.run('diskutil', ['unmountDisk', diskName]);
    if (unmountResult.exitCode != 0) {
      // Ignore unmount errors - disk might not be mounted
    }

    onProgress?.call(0.2, 'Writing image...');

    final diskwriterPath = await _getDiskwriterPath();
    if (diskwriterPath == null) {
      return FlashResult(success: false, error: 'diskwriter binary not found in app bundle');
    }

    final imageSize = await _estimateImageSizeBytes(imagePath, isCompressed);

    // Use diskwriter for authorized raw disk access
    final String command;
    if (isCompressed) {
      command = 'gunzip -c "$imagePath" | "$diskwriterPath" $rawDevice';
    } else {
      command = 'cat "$imagePath" | "$diskwriterPath" $rawDevice';
    }

    final process = await Process.start('/bin/sh', ['-c', command]);
    final stderrBuffer = StringBuffer();
    int? lastBytesWritten;

    process.stdout.listen((_) {});
    await for (final chunk in process.stderr.transform(utf8.decoder)) {
      stderrBuffer.write(chunk);
      // Parse diskwriter progress: "PROGRESS:<bytes>"
      for (final line in chunk.split('\n')) {
        final progressMatch = RegExp(r'PROGRESS:(\d+)').firstMatch(line);
        if (progressMatch != null) {
          final bytes = int.tryParse(progressMatch.group(1)!);
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
      }
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      return FlashResult(success: false, error: 'Write failed: ${stderrBuffer.toString().trim()}');
    }

    onProgress?.call(0.9, 'Syncing...');
    await Process.run('sync', []);

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

  Future<FlashResult> _writeLinux(
    String imagePath,
    String devicePath,
    bool isCompressed,
    ProgressCallback? onProgress,
  ) async {
    onProgress?.call(0.1, 'Unmounting partitions...');

    // Unmount any partitions before writing
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
          'gunzip -c "$imagePath" | dd of="$devicePath" bs=4M iflag=fullblock oflag=direct status=progress',
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
  /// If [bmapPath] is provided and the Go flasher binary is available, uses
  /// bmap-based sparse writes (much faster for images with empty space).
  Future<void> writeTwoPhase(
    String imagePath,
    String devicePath, {
    String? bmapPath,
    void Function(double progress, String message)? onProgress,
  }) async {
    final isCompressed = imagePath.endsWith('.gz');

    if (Platform.isWindows) {
      await _writeTwoPhaseWindows(imagePath, devicePath, isCompressed, onProgress, bmapPath: bmapPath);
    } else if (Platform.isMacOS) {
      final flasherPath = await _getFlasherPath();
      if (flasherPath == null) {
        throw Exception('librescoot-flasher binary not found in app bundle');
      }

      final rawDevice = !devicePath.contains('rdisk')
          ? devicePath.replaceFirst('/dev/disk', '/dev/rdisk')
          : devicePath;
      final diskName = rawDevice.replaceFirst('/dev/rdisk', '/dev/disk');

      // Unmount all partitions (macOS auto-mounts FAT32)
      debugPrint('Flash: unmounting $diskName');
      await Process.run('diskutil', ['unmountDisk', diskName]);

      // Go flasher handles macOS authorization internally via Security.framework
      await _writeWithGoFlasher(flasherPath, imagePath, rawDevice, bmapPath, true, onProgress);
    } else {
      // Linux: single pkexec elevation for both dd phases + verify
      await _writeTwoPhaseLinux(imagePath, devicePath, isCompressed, onProgress, bmapPath: bmapPath);
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
    if (Platform.isMacOS) {
      return _runDdPhaseMacOS(imagePath, devicePath, isCompressed,
          skip: skip, seek: seek, count: count, onProgress: onProgress);
    }
    return _runDdPhaseLinux(imagePath, devicePath, isCompressed,
        skip: skip, seek: seek, count: count, onProgress: onProgress);
  }

  /// macOS: use the diskwriter helper binary to get authorized raw disk access
  /// via AuthorizationCreate + authopen fd-passing.
  Future<void> _runDdPhaseMacOS(
    String imagePath,
    String devicePath,
    bool isCompressed, {
    int? skip,
    int? seek,
    int? count,
    void Function(double progress, String message)? onProgress,
  }) async {
    final rawDevice = !devicePath.contains('rdisk')
        ? devicePath.replaceFirst('/dev/disk', '/dev/rdisk')
        : devicePath;
    final diskName = rawDevice.replaceFirst('/dev/rdisk', '/dev/disk');

    // Unmount the disk first (macOS auto-mounts)
    debugPrint('Flash: unmounting $diskName');
    final unmountResult = await Process.run('diskutil', ['unmountDisk', diskName]);
    debugPrint('Flash: unmount result: ${unmountResult.exitCode} ${unmountResult.stderr}');

    // Locate the diskwriter binary bundled in the app
    final diskwriterPath = await _getDiskwriterPath();
    if (diskwriterPath == null) {
      throw Exception('diskwriter binary not found in app bundle');
    }

    final dwArgs = <String>[
      if (skip != null) '--skip=$skip',
      if (seek != null) '--seek=$seek',
      if (count != null) '--count=$count',
      rawDevice,
    ];

    // Build the pipeline: decompress (if needed) | diskwriter
    final String command;
    if (isCompressed) {
      command = 'gunzip -c "$imagePath" | "$diskwriterPath" ${dwArgs.join(' ')}';
    } else {
      command = 'cat "$imagePath" | "$diskwriterPath" ${dwArgs.join(' ')}';
    }

    debugPrint('Flash: running: $command');
    final process = await Process.start('/bin/sh', ['-c', command]);

    final stderrBuf = StringBuffer();
    process.stdout.listen((_) {}); // drain stdout

    await for (final chunk in process.stderr.transform(utf8.decoder)) {
      stderrBuf.write(chunk);
      // Parse progress lines: "PROGRESS:<bytes>"
      for (final line in chunk.split('\n')) {
        final progressMatch = RegExp(r'PROGRESS:(\d+)').firstMatch(line);
        if (progressMatch != null) {
          final bytes = int.tryParse(progressMatch.group(1)!);
          if (bytes != null) {
            final mb = bytes / (1024 * 1024);
            onProgress?.call(0.5, '${mb.toStringAsFixed(1)} MB written');
          }
        }
      }
    }

    final exitCode = await process.exitCode;
    debugPrint('Flash: diskwriter exit code: $exitCode');
    if (exitCode != 0) {
      debugPrint('Flash: diskwriter output: $stderrBuf');
      throw Exception('diskwriter failed with exit code $exitCode: $stderrBuf');
    }
  }

  /// Linux: use dd, elevating via pkexec if not already root.
  Future<void> _runDdPhaseLinux(
    String imagePath,
    String devicePath,
    bool isCompressed, {
    int? skip,
    int? seek,
    int? count,
    void Function(double progress, String message)? onProgress,
  }) async {
    final isRoot = Platform.environment['USER'] == 'root' ||
        (await Process.run('id', ['-u'])).stdout.toString().trim() == '0';

    final ddParams = <String>[
      'bs=4M',
      if (skip != null) 'skip=$skip',
      if (seek != null) 'seek=$seek',
      if (count != null) 'count=$count',
      'oflag=direct',
      'status=progress',
    ];

    // When not root, wrap dd in pkexec for a one-time auth prompt
    final ddPrefix = isRoot ? 'dd' : 'pkexec dd';

    final String command;
    if (isCompressed) {
      command = 'gunzip -c "$imagePath" | $ddPrefix of=$devicePath iflag=fullblock ${ddParams.join(' ')} 2>&1';
    } else {
      command = '$ddPrefix if="$imagePath" of=$devicePath ${ddParams.join(' ')} 2>&1';
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

  /// Locate the diskwriter binary in the macOS app bundle
  Future<String?> _getDiskwriterPath() async {
    // When running from Xcode / flutter run, the binary is in the app's Resources
    final execDir = path.dirname(Platform.resolvedExecutable);
    final candidates = [
      // App bundle: .app/Contents/Resources/diskwriter
      path.join(execDir, '..', 'Resources', 'diskwriter'),
      // Development fallback: compiled in project directory
      path.join(Directory.current.path, 'macos', 'Runner', 'diskwriter_bin'),
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        debugPrint('Flash: found diskwriter at $candidate');
        return candidate;
      }
    }

    debugPrint('Flash: diskwriter not found, searched: $candidates');
    return null;
  }

  /// Parse bmap XML to get total mapped bytes
  Future<int?> _estimateBmapBytes(String bmapPath) async {
    try {
      final content = await File(bmapPath).readAsString();
      // Parse MappedBlocksCount and BlockSize from XML
      final mappedMatch = RegExp(r'<MappedBlocksCount>\s*(\d+)\s*</MappedBlocksCount>').firstMatch(content);
      final blockSizeMatch = RegExp(r'<BlockSize>\s*(\d+)\s*</BlockSize>').firstMatch(content);
      if (mappedMatch != null) {
        final mapped = int.parse(mappedMatch.group(1)!);
        final bs = blockSizeMatch != null ? int.parse(blockSizeMatch.group(1)!) : 4096;
        return mapped * bs;
      }
    } catch (e) {
      debugPrint('Flash: failed to parse bmap: $e');
    }
    return null;
  }

  /// Locate the Go flasher binary (librescoot-flasher).
  ///
  /// Flutter's per-platform bundle layouts differ:
  /// - Linux/Windows:   <exec_dir>/data/flutter_assets/assets/tools/...
  /// - macOS:           <exec_dir>/../Frameworks/App.framework/Resources/flutter_assets/assets/tools/...
  ///
  /// On macOS, the app may also be running from an AppTranslocation read-only
  /// mount (when launched from a downloaded .dmg without copying to
  /// /Applications), so we stage the binary into a writable temp directory
  /// before chmod'ing it.
  Future<String?> _getFlasherPath() async {
    final execDir = path.dirname(Platform.resolvedExecutable);
    final ext = Platform.isWindows ? '.exe' : '';
    final binaryName = 'librescoot-flasher$ext';
    final candidates = <String>[
      if (Platform.isMacOS)
        path.join(execDir, '..', 'Frameworks', 'App.framework', 'Resources',
            'flutter_assets', 'assets', 'tools', binaryName),
      path.join(execDir, 'data', 'flutter_assets', 'assets', 'tools', binaryName),
      path.join(Directory.current.path, 'assets', 'tools', binaryName),
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        debugPrint('Flash: found Go flasher at $candidate');
        if (Platform.isMacOS) {
          // The bundle may live on a read-only AppTranslocation mount when
          // launched from a downloaded .dmg, so chmod in place fails. Stage
          // it into a writable temp dir before marking it executable.
          return _stageMacOSExecutable(candidate, binaryName);
        }
        if (!Platform.isWindows) {
          // Flutter strips execute permission from bundled assets.
          await Process.run('chmod', ['+x', candidate]);
        }
        return candidate;
      }
    }
    debugPrint('Flash: Go flasher not found in: $candidates');
    return null;
  }

  /// Copy [source] to a writable temp directory and mark it executable.
  /// Re-copies if the staged file is missing or differs in size from source.
  Future<String> _stageMacOSExecutable(String source, String name) async {
    final stageDir = Directory(path.join(Directory.systemTemp.path, 'librescoot-installer'));
    if (!await stageDir.exists()) {
      await stageDir.create(recursive: true);
    }
    final staged = File(path.join(stageDir.path, name));
    final src = File(source);
    final srcLen = await src.length();
    if (!await staged.exists() || await staged.length() != srcLen) {
      await src.copy(staged.path);
      debugPrint('Flash: staged $name to ${staged.path}');
    }
    await Process.run('chmod', ['+x', staged.path]);
    return staged.path;
  }

  /// Write using the Go flasher binary (supports bmap, two-phase, sequential)
  Future<void> _writeWithGoFlasher(
    String flasherPath,
    String imagePath,
    String devicePath,
    String? bmapPath,
    bool isRoot,
    void Function(double progress, String message)? onProgress,
  ) async {
    final flasherArgs = <String>[
      '--image', imagePath,
      '--device', devicePath,
      if (bmapPath != null) ...['--bmap', bmapPath]
      else ...['--two-phase', '--boot-blocks', '$bootAreaBlocks'],
    ];

    debugPrint('Flash: running: $flasherPath ${flasherArgs.join(' ')}');

    // Total bytes will be updated by TOTAL: output from flasher
    var totalBytes = await _estimateImageSizeBytes(imagePath, imagePath.endsWith('.gz')) ?? 0;
    var totalMb = totalBytes / (1024 * 1024);
    // Stopwatch starts on first output (after auth/elevation)
    final stopwatch = Stopwatch();

    onProgress?.call(0.0, bmapPath != null ? 'Bmap flash...' : 'Waiting for authorization...');

    final Process process;
    if (Platform.isWindows) {
      // Windows: run flasher directly (already elevated)
      process = await Process.start(flasherPath, flasherArgs);
    } else if (isRoot) {
      // Unix: already root, run directly
      process = await Process.start(flasherPath, flasherArgs);
    } else {
      // Unix: need elevation via pkexec
      final command = 'pkexec $flasherPath ${flasherArgs.join(' ')}';
      process = await Process.start('/bin/sh', ['-c', command]);
    }
    final output = StringBuffer();

    await for (final chunk in process.stderr.transform(utf8.decoder)) {
      if (!stopwatch.isRunning) stopwatch.start();
      output.write(chunk);
      for (final line in chunk.split('\n')) {
        if (line.startsWith('TOTAL:')) {
          final t = int.tryParse(line.substring(6).trim());
          if (t != null && t > 0) {
            totalBytes = t;
            totalMb = totalBytes / (1024 * 1024);
            debugPrint('Flash: TOTAL=$totalBytes');
          }
        }
        if (line.startsWith('PHASE:')) {
          final phase = line.substring(6).trim();
          if (phase == 'A') onProgress?.call(0.0, 'Phase A: Writing partitions...');
          if (phase == 'B') onProgress?.call(0.9, 'Phase B: Writing boot sector...');
        }
        if (line.startsWith('PROGRESS:')) {
          final bytes = int.tryParse(line.substring(9).trim());
          if (bytes != null && totalBytes > 0) {
            final fraction = (bytes / totalBytes).clamp(0.0, 0.95);
            final mb = bytes / (1024 * 1024);
            String eta = '';
            if (fraction > 0.01) {
              final elapsed = stopwatch.elapsedMilliseconds / 1000;
              final remaining = (elapsed / fraction) * (1.0 - fraction);
              eta = ' — ${remaining ~/ 60}m ${(remaining % 60).floor()}s remaining';
            }
            onProgress?.call(fraction, '${mb.toStringAsFixed(0)} / ${totalMb.toStringAsFixed(0)} MB written$eta');
          }
        }
        if (line.startsWith('CHECKSUM MISMATCH')) {
          debugPrint('Flash: $line');
        }
      }
    }

    final exitCode = await process.exitCode;
    debugPrint('Flash: Go flasher exit code: $exitCode');

    if (exitCode != 0) {
      final out = output.toString();
      debugPrint('Flash: Go flasher output: $out');
      if (exitCode == 126) {
        throw Exception('Authorization was dismissed — flash incomplete');
      }
      throw Exception('Flash failed: $out');
    }

    onProgress?.call(1.0, 'Flash complete');
  }

  /// Linux two-phase flash: single pkexec auth, both phases + verify in one script.
  Future<void> _writeTwoPhaseLinux(
    String imagePath,
    String devicePath,
    bool isCompressed,
    void Function(double progress, String message)? onProgress, {
    String? bmapPath,
  }) async {
    // Unmount any auto-mounted partitions before writing
    final partitions = await _findLinuxPartitions(devicePath);
    for (final partition in partitions) {
      await Process.run('umount', [partition]);
    }

    final isRoot = (await Process.run('id', ['-u'])).stdout.toString().trim() == '0';

    // Try Go flasher first (supports bmap for sparse writes)
    final flasherPath = await _getFlasherPath();
    if (flasherPath != null) {
      await _writeWithGoFlasher(flasherPath, imagePath, devicePath, bmapPath, isRoot, onProgress);
      return;
    }

    debugPrint('Flash: Go flasher not found, falling back to dd');
    final decompressPrefix = isCompressed
        ? 'gunzip -c "$imagePath" |'
        : '';
    final inputArg = isCompressed
        ? 'iflag=fullblock'
        : 'if="$imagePath"';

    // Single shell script that does Phase A, Phase B, sync, and verify
    final script = '''
set -e
echo "PHASE:A"
$decompressPrefix dd $inputArg of=$devicePath bs=4M skip=$bootAreaBlocks seek=$bootAreaBlocks oflag=direct status=progress 2>&1 | tr '\\r' '\\n'
echo "PHASE:B"
$decompressPrefix dd $inputArg of=$devicePath bs=4M count=$bootAreaBlocks oflag=direct status=progress 2>&1 | tr '\\r' '\\n'
echo "PHASE:SYNC"
sync
echo "PHASE:VERIFY"
SRC_HASH=\$($decompressPrefix dd ${isCompressed ? 'iflag=fullblock' : 'if="$imagePath"'} bs=4M count=$bootAreaBlocks 2>/dev/null | md5sum | cut -d' ' -f1)
DEV_HASH=\$(dd if=$devicePath bs=4M count=$bootAreaBlocks iflag=direct 2>/dev/null | md5sum | cut -d' ' -f1)
echo "VERIFY:SRC=\$SRC_HASH"
echo "VERIFY:DEV=\$DEV_HASH"
if [ "\$SRC_HASH" != "\$DEV_HASH" ]; then
  echo "VERIFY:FAIL"
  exit 1
fi
echo "VERIFY:OK"
''';

    final scriptFile = File('/tmp/librescoot-flash.sh');
    await scriptFile.writeAsString(script);
    await Process.run('chmod', ['+x', scriptFile.path]);

    final command = isRoot
        ? '/bin/sh ${scriptFile.path}'
        : 'pkexec /bin/sh ${scriptFile.path}';

    // Estimate total image size for progress calculation
    final imageSize = await _estimateImageSizeBytes(imagePath, isCompressed);
    final totalBytes = imageSize ?? 0;
    // Phase A writes everything after boot area, Phase B writes boot area
    // Progress: Phase A = 0.0-0.9, Phase B = 0.9-0.95, Sync = 0.95, Verify = 0.97
    final phaseABytes = totalBytes > bootAreaBytes ? totalBytes - bootAreaBytes : totalBytes;

    debugPrint('Flash: running two-phase script via ${isRoot ? "sh" : "pkexec"}');
    debugPrint('Flash: estimated image size: $totalBytes bytes, phase A: $phaseABytes bytes');
    onProgress?.call(0.0, 'Phase A: Writing partitions...');

    final process = await Process.start('/bin/sh', ['-c', command]);

    var currentPhase = 'A';
    final output = StringBuffer();
    final stopwatch = Stopwatch()..start();

    await for (final chunk in process.stdout.transform(utf8.decoder)) {
      output.write(chunk);
      for (final line in chunk.split('\n')) {
        if (line.startsWith('PHASE:')) {
          currentPhase = line.substring(6).trim();
          switch (currentPhase) {
            case 'B':
              onProgress?.call(0.9, 'Phase B: Writing boot sector...');
            case 'SYNC':
              onProgress?.call(0.95, 'Syncing...');
            case 'VERIFY':
              onProgress?.call(0.97, 'Verifying boot sector...');
          }
        }
        if (line.startsWith('VERIFY:')) {
          debugPrint('Flash: $line');
        }
        final bytesMatch = RegExp(r'(\d+)\s+bytes').firstMatch(line);
        if (bytesMatch != null) {
          final bytes = int.tryParse(bytesMatch.group(1)!);
          if (bytes != null) {
            final mb = bytes / (1024 * 1024);
            String eta = '';
            if (currentPhase == 'A' && phaseABytes > 0) {
              final fraction = (bytes / phaseABytes).clamp(0.0, 1.0);
              final progress = fraction * 0.9; // Phase A is 0-0.9
              // Calculate ETA
              if (fraction > 0.01) {
                final elapsed = stopwatch.elapsedMilliseconds / 1000;
                final remaining = (elapsed / fraction) * (1.0 - fraction);
                final mins = (remaining / 60).floor();
                final secs = (remaining % 60).floor();
                eta = ' — ${mins}m ${secs}s remaining';
              }
              onProgress?.call(progress, '${mb.toStringAsFixed(0)} MB written$eta');
            } else if (currentPhase == 'B') {
              onProgress?.call(0.92, 'Boot sector: ${mb.toStringAsFixed(1)} MB written');
            }
          }
        }
      }
    }

    final exitCode = await process.exitCode;
    debugPrint('Flash: two-phase script exit code: $exitCode');

    // Clean up script
    try { await scriptFile.delete(); } catch (_) {}

    if (exitCode != 0) {
      final out = output.toString();
      debugPrint('Flash: script output: $out');
      if (out.contains('VERIFY:FAIL')) {
        throw Exception('Boot sector verification FAILED — checksum mismatch. Check log.');
      }
      if (exitCode == 126) {
        throw Exception('Authorization was dismissed — flash incomplete');
      }
      throw Exception('Flash failed with exit code $exitCode');
    }

    onProgress?.call(1.0, 'Boot sector verified');
  }

  /// Verify the boot sector written to disk matches the source image.
  /// Compares md5sum of the first bootAreaBlocks (24 MB) from image vs device.
  Future<void> _verifyBootSector(
    String imagePath,
    String devicePath,
    bool isCompressed,
  ) async {
    // Hash the first bootAreaBlocks from the source image
    final String sourceCmd;
    if (isCompressed) {
      sourceCmd = 'gunzip -c "$imagePath" | dd bs=4M count=$bootAreaBlocks iflag=fullblock 2>/dev/null | md5sum';
    } else {
      sourceCmd = 'dd if="$imagePath" bs=4M count=$bootAreaBlocks 2>/dev/null | md5sum';
    }

    // Hash the first bootAreaBlocks from the device
    final deviceCmd = 'dd if="$devicePath" bs=4M count=$bootAreaBlocks iflag=direct 2>/dev/null | md5sum';

    debugPrint('Flash: verifying boot sector...');
    final results = await Future.wait([
      Process.run('sh', ['-c', sourceCmd]),
      Process.run('sh', ['-c', deviceCmd]),
    ]);

    final sourceHash = results[0].stdout.toString().split(' ').first.trim();
    final deviceHash = results[1].stdout.toString().split(' ').first.trim();

    debugPrint('Flash: VERIFY source=$sourceHash device=$deviceHash');

    if (sourceHash.isEmpty || deviceHash.isEmpty) {
      throw Exception('Boot sector verification failed: could not compute checksums');
    }
    if (sourceHash != deviceHash) {
      throw Exception(
        'Boot sector verification FAILED — checksum mismatch!\n'
        'Expected: $sourceHash\n'
        'Got:      $deviceHash',
      );
    }
    debugPrint('Flash: boot sector verified OK');
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

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

    // Warn if not detected as removable (but don't block)
    if (!isRemovable) {
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
      // Never allow disk0 or disk1 (typically system)
      if (devicePath.contains('disk0') || devicePath.contains('rdisk0')) {
        errors.add('DANGER: Cannot flash disk0 (system disk)');
      }
      if (devicePath.contains('disk1') || devicePath.contains('rdisk1')) {
        warnings.add('disk1 may be the system disk - verify carefully');
      }
    } else if (Platform.isLinux) {
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

    ProcessResult result;
    if (isCompressed) {
      // gunzip -c image.wic.gz | dd of=/dev/rdiskX bs=4m
      result = await Process.run(
        'sh',
        [
          '-c',
          'gunzip -c "$imagePath" | dd of="$devicePath" bs=4m',
        ],
      );
    } else {
      result = await Process.run(
        'dd',
        ['if=$imagePath', 'of=$devicePath', 'bs=4m'],
      );
    }

    if (result.exitCode != 0) {
      return FlashResult(success: false, error: 'Write failed: ${result.stderr}');
    }

    onProgress?.call(0.9, 'Syncing...');

    // Sync to ensure all data is written
    await Process.run('sync', []);

    // Eject disk
    await Process.run('diskutil', ['eject', diskName]);

    onProgress?.call(1.0, 'Complete');

    return FlashResult(success: true);
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

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../l10n/app_localizations.dart';
import 'disk_arbitration_service.dart';
import 'usb_detector.dart' show SystemDiskVerdict;

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
  AppLocalizations? l10n;

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

  /// User area of the eMMC every MDB carries: 15269888 sectors of 512 bytes.
  static const int mdbEmmcBytes = 7818182656;

  /// Exact. Every platform reports the raw device size: Linux from
  /// /sys/block, macOS from diskutil, Windows from Get-Disk. A host that
  /// cannot produce the raw size reports none, which warns rather than
  /// comparing a wrong number.
  static const int mdbEmmcToleranceBytes = 0;

  /// An eMMC that has lost its user area reports a few tens of MB.
  static const int failedEmmcCeilingBytes = 64 * 1024 * 1024;

  static String _gib(int bytes) =>
      (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);

  static String _mib(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

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
    SystemDiskVerdict systemDiskVerdict = SystemDiskVerdict.unknown,
    String? detectedPath,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // devicePath is the only argument describing the disk to be written; the
    // others come from the detected device object, which the caller reads
    // separately. Windows reassigns a freed disk number to the next device,
    // so the two can name different disks. Every check below reads the
    // object, so this is the only one that ties the identity to the path.
    if (detectedPath != null &&
        detectedPath.isNotEmpty &&
        detectedPath != devicePath) {
      errors.add(
        'Device identity does not match the target path: detected on '
        '$detectedPath, about to write to $devicePath',
      );
    }

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

    // Every MDB carries the same eMMC, so this matches one value. A range
    // wide enough for "any small disk" also admits the SD cards and sticks
    // the detector's match pattern can adopt.
    if (sizeBytes != null) {
      final off = (sizeBytes - mdbEmmcBytes).abs();
      if (sizeBytes <= failedEmmcCeilingBytes) {
        errors.add(
          'eMMC reports only ${_mib(sizeBytes)} MB. The eMMC on this board '
          'has failed; it cannot be flashed.',
        );
      } else if (off > mdbEmmcToleranceBytes) {
        errors.add(
          'Unexpected device size: ${_gib(sizeBytes)} GB. Every MDB eMMC is '
          '${_gib(mdbEmmcBytes)} GB, so this is not one, or it is something '
          'we do not have a name for. Refusing.',
        );
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
        // Index 0 does not identify the system disk. Refused because the
        // scooter is never index 0.
        errors.add('DANGER: Cannot flash PHYSICALDRIVE0');
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
      // sda is not inherently the system disk. On a laptop that boots from
      // NVMe it is simply the first USB disk attached, which is what the
      // scooter enumerates as, so refusing it outright blocked the only
      // device the user was trying to flash. It is refused when the storage
      // stack could not be asked (systemDiskVerdict unknown), because then
      // the name is the only evidence there is; a disk with anything mounted
      // on it is refused above regardless of name.
      if (devicePath == '/dev/sda' &&
          systemDiskVerdict != SystemDiskVerdict.notSystem) {
        errors.add('DANGER: /dev/sda could not be confirmed as the scooter. '
            'Refusing, because it is commonly the system disk.');
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

  /// Windows entry point for the Go flasher. Uses the bmap fast path when
  /// [bmapPath] is provided; otherwise falls back to two-phase.
  Future<void> _writeWindowsViaGoFlasher(
    String imagePath,
    String devicePath,
    bool isCompressed,
    void Function(double progress, String message)? onProgress, {
    String? bmapPath,
  }) async {
    final flasherPath = await _getFlasherPath();
    if (flasherPath == null) {
      throw Exception('librescoot-flasher-windows-amd64.exe not found in app bundle');
    }

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

    for (var attempt = 1; attempt <= 3; attempt++) {
      debugPrint('Flash(_writeMacOS): unmounting $diskName (attempt $attempt/3, force)');
      final r = await Process.run('diskutil', ['unmountDisk', 'force', diskName]);
      debugPrint('Flash(_writeMacOS): unmount exit=${r.exitCode} stdout=${(r.stdout as String).trim()} stderr=${(r.stderr as String).trim()}');
      if (r.exitCode == 0) break;
      if (attempt < 3) await Future.delayed(const Duration(milliseconds: 500));
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
              final mbStr = mb.toStringAsFixed(1);
              final base = l10n?.flashProgressMb(mbStr) ?? '$mbStr MB written';
              onProgress?.call(0.2, 'Writing image... $base');
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
      await _writeWindowsViaGoFlasher(imagePath, devicePath, isCompressed, onProgress, bmapPath: bmapPath);
    } else if (Platform.isMacOS) {
      final rawDevice = !devicePath.contains('rdisk')
          ? devicePath.replaceFirst('/dev/disk', '/dev/rdisk')
          : devicePath;
      final diskName = rawDevice.replaceFirst('/dev/rdisk', '/dev/disk');

      // Pre-claim the disk via DiskArbitration. With a claim held, Finder
      // won't auto-mount or pop the "Initialize / Erase / Ignore" dialog
      // for unrecognised partition tables, and authopen no longer hits
      // EPERM on /dev/rdiskN. Falls back gracefully to the cheap force-
      // unmount path if the helper isn't bundled or fails to claim.
      final da = DiskArbitrationService();
      var daClaimed = false;
      final daPath = await DiskArbitrationService.locate();
      if (daPath != null && await da.start(daPath)) {
        daClaimed = await da.claim(diskName);
      } else {
        debugPrint('Flash: daclaim helper unavailable, falling back to force-unmount');
      }

      try {
        // Force-unmount as a belt-and-braces. With a DA claim held this is a
        // no-op (nothing's mounted); without one, it's the cheap fix that
        // pries Finder off the disk after the dialog has appeared.
        for (var attempt = 1; attempt <= 3; attempt++) {
          debugPrint('Flash: unmounting $diskName (attempt $attempt/3, force)');
          final r = await Process.run('diskutil', ['unmountDisk', 'force', diskName]);
          final stderr = (r.stderr as String).trim();
          final stdout = (r.stdout as String).trim();
          debugPrint('Flash: unmount exit=${r.exitCode} stdout=$stdout stderr=$stderr');
          if (r.exitCode == 0) break;
          if (attempt < 3) await Future.delayed(const Duration(milliseconds: 500));
        }

        final flasherPath = await _getFlasherPath();
        if (flasherPath != null) {
          // Go flasher handles macOS authorization internally via Security.framework
          await _writeWithGoFlasher(flasherPath, imagePath, rawDevice, bmapPath, true, onProgress);
        } else {
          // No flasher binary for this arch (e.g. older bundle without
          // darwin-amd64). Fall back to a plain dd write: slower, no
          // bmap fast path, no two-phase, but it gets the bits onto the
          // device. We're already running as root via self-elevation.
          debugPrint('Flash: no Go flasher for ${Abi.current()}, falling back to dd');
          await _writeMacOSDdFallback(imagePath, rawDevice, onProgress);
        }
      } finally {
        if (daClaimed) await da.release(diskName);
        await da.stop();
      }
    } else {
      // Linux: single pkexec elevation for both dd phases + verify
      await _writeTwoPhaseLinux(imagePath, devicePath, isCompressed, onProgress, bmapPath: bmapPath);
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

  /// Locate the Go flasher binary for the current host platform.
  ///
  /// On macOS and Linux the binary is installed with +x by the build system
  /// (Xcode build phase / CMake install), so no chmod is needed at runtime.
  /// Windows bundles it via Flutter assets (no execute bit needed).
  /// macOS dd fallback for hosts without a matching librescoot-flasher
  /// binary in the bundle. Single-phase, no bmap, no two-phase safety —
  /// strictly a "get the bits there" path. We're root via self-elevation,
  /// so writing to /dev/rdiskN works without authopen.
  Future<void> _writeMacOSDdFallback(
    String imagePath,
    String rawDevice,
    void Function(double progress, String message)? onProgress,
  ) async {
    final isCompressed = imagePath.endsWith('.gz');
    final totalBytes = await _estimateImageSizeBytes(imagePath, isCompressed) ?? 0;
    final totalMb = totalBytes / (1024 * 1024);
    onProgress?.call(0.0, 'dd fallback (no Go flasher for this CPU)...');

    // macOS /bin/sh is bash, which supports pipefail: without it, a gunzip
    // I/O error would be swallowed and only dd's (successful) exit code
    // would count, leaving a truncated write reported as success.
    final cmd = isCompressed
        ? 'set -o pipefail; gunzip -c "$imagePath" | dd of=$rawDevice bs=4m'
        : 'dd if="$imagePath" of=$rawDevice bs=4m';

    final process = await Process.start('/bin/sh', ['-c', cmd]);

    // macOS dd prints status only on SIGINFO. Poke it every 2s so the
    // user sees something move.
    final ticker = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final r = await Process.run('pgrep', ['-P', '${process.pid}', 'dd']);
        final ddPid = int.tryParse(r.stdout.toString().trim());
        if (ddPid != null) {
          await Process.run('kill', ['-INFO', '$ddPid']);
        }
      } catch (_) {}
    });

    final stderrBuf = StringBuffer();
    process.stdout.listen((_) {});
    await for (final chunk in process.stderr.transform(utf8.decoder)) {
      stderrBuf.write(chunk);
      // dd status lines look like: "12345678 bytes transferred in 4.2 secs"
      final m = RegExp(r'(\d+) bytes').firstMatch(chunk);
      if (m != null) {
        final bytes = int.tryParse(m.group(1)!) ?? 0;
        final mb = bytes / (1024 * 1024);
        if (totalBytes > 0) {
          final fraction = (bytes / totalBytes).clamp(0.0, 0.95);
          onProgress?.call(fraction,
              'dd: ${mb.toStringAsFixed(0)} / ${totalMb.toStringAsFixed(0)} MB');
        } else {
          final mbStr = mb.toStringAsFixed(0);
          onProgress?.call(0.0, 'dd: ${l10n?.flashProgressMb(mbStr) ?? '$mbStr MB written'}');
        }
      }
    }
    ticker.cancel();

    final exit = await process.exitCode;
    if (exit != 0) {
      throw Exception('dd fallback failed: ${stderrBuf.toString().trim()}');
    }
    await Process.run('sync', []);
    onProgress?.call(1.0, 'dd: complete');
  }

  /// Pick the librescoot-flasher binary that matches the current host
  /// CPU. Returns null on an unsupported (OS, arch) combo: the caller
  /// must then either fall back (macOS) or surface an error.
  String? _flasherBinaryName() {
    final abi = Abi.current();
    if (Platform.isWindows) {
      if (abi == Abi.windowsArm64) return 'librescoot-flasher-windows-arm64.exe';
      return 'librescoot-flasher-windows-amd64.exe';
    }
    if (Platform.isMacOS) {
      if (abi == Abi.macosX64) return 'librescoot-flasher-darwin-amd64';
      return 'librescoot-flasher-darwin-arm64';
    }
    if (Platform.isLinux) {
      if (abi == Abi.linuxArm64) return 'librescoot-flasher-linux-arm64';
      if (abi == Abi.linuxArm) return 'librescoot-flasher-linux-arm';
      return 'librescoot-flasher-linux-amd64';
    }
    return null;
  }

  Future<String?> _getFlasherPath() async {
    final execDir = path.dirname(Platform.resolvedExecutable);
    final binaryName = _flasherBinaryName();
    if (binaryName == null) return null;
    final candidates = <String>[
      if (Platform.isMacOS)
        // Xcode build phase copies it here with +x
        path.join(execDir, '..', 'Resources', binaryName),
      if (Platform.isLinux)
        // CMake installs it next to the executable with +x
        path.join(execDir, binaryName),
      // Flutter assets fallback (Windows, or dev mode)
      path.join(execDir, 'data', 'flutter_assets', 'assets', 'tools', binaryName),
      path.join(Directory.current.path, 'assets', 'tools', binaryName),
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        debugPrint('Flash: found Go flasher at $candidate (${Abi.current()})');
        return candidate;
      }
    }
    debugPrint('Flash: Go flasher $binaryName (${Abi.current()}) not found in: $candidates');
    return null;
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

    // When we run from an AppImage, the bundled flasher lives inside a per-user
    // FUSE mount (/tmp/.mount_*) that root can't read — so `pkexec <flasher>`
    // fails with "Error accessing ...: Permission denied" (exit 127). Copy it
    // out to a normal path root can exec.
    flasherPath = await _ensureFlasherRunnableAsRoot(flasherPath);

    debugPrint('Flash: running: $flasherPath ${flasherArgs.join(' ')}');

    // Total bytes will be updated by TOTAL: output from flasher
    var totalBytes = await _estimateImageSizeBytes(imagePath, imagePath.endsWith('.gz')) ?? 0;
    var totalMb = totalBytes / (1024 * 1024);
    // Stopwatch starts on first output (after auth/elevation)
    final stopwatch = Stopwatch();

    onProgress?.call(0.0, bmapPath != null ? 'Bmap flash...' : 'Waiting for authorization...');

    var sawChecksumMismatch = false;

    final Process process;
    if (Platform.isWindows) {
      // Windows: run flasher directly (already elevated)
      process = await Process.start(flasherPath, flasherArgs);
    } else if (isRoot) {
      // Unix: already root, run directly
      process = await Process.start(flasherPath, flasherArgs);
    } else {
      // Unix, not root: elevate. Prefer pkexec (graphical polkit prompt), fall
      // back to sudo (+ a graphical askpass if one exists). argv is passed
      // directly so paths never need shell quoting.
      final elev = await _elevationArgv();
      if (elev == null) {
        throw Exception(
            'Root is required to flash, but neither pkexec nor sudo was found. '
            'Start the installer as root, e.g. `sudo ./Librescoot-Installer.AppImage`.');
      }
      final env = <String, String>{};
      if (elev.length >= 2 && elev[1] == '-A') {
        final askpass = await _findAskpass();
        if (askpass != null) env['SUDO_ASKPASS'] = askpass;
      }
      final argv = [...elev, flasherPath, ...flasherArgs];
      debugPrint('Flash: elevating via ${elev.join(' ')}');
      process = await Process.start(argv.first, argv.sublist(1),
          environment: env.isEmpty ? null : env);
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
            final mbStr = mb.toStringAsFixed(0);
            final totalMbStr = totalMb.toStringAsFixed(0);
            final base = l10n?.flashProgressMbOfTotal(mbStr, totalMbStr)
                ?? '$mbStr / $totalMbStr MB written';
            String eta = '';
            if (fraction > 0.01) {
              final elapsed = stopwatch.elapsedMilliseconds / 1000;
              final remaining = (elapsed / fraction) * (1.0 - fraction);
              final mins = remaining ~/ 60;
              final secs = (remaining % 60).floor();
              eta = ': ${l10n?.flashProgressEta(mins, secs) ?? '${mins}m ${secs}s remaining'}';
            }
            onProgress?.call(fraction, '$base$eta');
          }
        }
        if (line.startsWith('CHECKSUM MISMATCH')) {
          debugPrint('Flash: $line');
          sawChecksumMismatch = true;
        }
      }
    }

    final exitCode = await process.exitCode;
    debugPrint('Flash: Go flasher exit code: $exitCode');

    // Fatal regardless of exit code: a checksum mismatch means the write is
    // corrupt even if the flasher process itself exited 0.
    if (sawChecksumMismatch) {
      debugPrint('Flash: Go flasher output: ${output.toString()}');
      throw Exception('Flash verification FAILED: checksum mismatch detected during write. Check log.');
    }

    if (exitCode != 0) {
      final out = output.toString();
      debugPrint('Flash: Go flasher output: $out');
      if (exitCode == 126) {
        throw Exception('Authorization was dismissed: flash incomplete');
      }
      throw Exception('Flash failed: ${_humanFlashError(out)}');
    }

    onProgress?.call(1.0, 'Flash complete');
  }

  /// Strip the flasher's machine-readable protocol lines out of a failure.
  ///
  /// The raw output carries a `Bmap: … (14% of …)` line describing how much of
  /// the image is mapped, which people read as "it failed at 14%". It is not
  /// progress, and the percentage that matters is already spelled out by the
  /// explanation below. Keeps the ERROR line and anything that is not one of
  /// the protocol markers.
  @visibleForTesting
  static String humanFlashErrorForTest(String raw) => _humanFlashError(raw);

  static String _humanFlashError(String raw) {
    final kept = raw
        .split('\n')
        .where((l) => !RegExp(r'^\s*(TOTAL:|PHASE:|PROGRESS:|Bmap:)').hasMatch(l))
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    return kept.isEmpty ? raw.trim() : kept.join('\n');
  }

  /// Copy the flasher out of an AppImage's per-user FUSE mount (which a
  /// pkexec/sudo-elevated root can't read) to a normal temp path. No-op
  /// outside an AppImage or off Linux.
  Future<String> _ensureFlasherRunnableAsRoot(String flasherPath) async {
    final inAppImage = Platform.environment.containsKey('APPIMAGE') ||
        flasherPath.contains('/.mount_');
    if (!Platform.isLinux || !inAppImage) return flasherPath;
    try {
      final dir = await Directory.systemTemp.createTemp('librescoot-flasher-');
      await Process.run('chmod', ['0755', dir.path]);
      final dest = path.join(dir.path, path.basename(flasherPath));
      await File(flasherPath).copy(dest);
      await Process.run('chmod', ['0755', dest]);
      debugPrint('Flash: copied flasher out of AppImage mount to $dest');
      return dest;
    } catch (e) {
      debugPrint('Flash: could not copy flasher out of AppImage ($e); using original');
      return flasherPath;
    }
  }

  /// Argv prefix to run a command as root, or null if neither pkexec nor sudo
  /// is available. Prefers pkexec's graphical prompt; sudo gets `-A` when a
  /// graphical askpass exists so it can prompt without a terminal.
  Future<List<String>?> _elevationArgv() async {
    if (await _hasCommand('pkexec')) return ['pkexec'];
    if (await _hasCommand('sudo')) {
      return (await _findAskpass()) != null ? ['sudo', '-A'] : ['sudo'];
    }
    return null;
  }

  /// True if [name] is found on PATH (avoids depending on `which` existing).
  Future<bool> _hasCommand(String name) async {
    final pathEnv = Platform.environment['PATH'] ??
        '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin';
    for (final dir in pathEnv.split(':')) {
      if (dir.isEmpty) continue;
      if (await File(path.join(dir, name)).exists()) return true;
    }
    return false;
  }

  /// A graphical SSH-askpass helper for `sudo -A`, or null if none is found.
  Future<String?> _findAskpass() async {
    final fromEnv = Platform.environment['SUDO_ASKPASS'];
    if (fromEnv != null && fromEnv.isNotEmpty && await File(fromEnv).exists()) {
      return fromEnv;
    }
    const candidates = [
      '/usr/bin/ssh-askpass',
      '/usr/bin/ksshaskpass',
      '/usr/bin/lxqt-openssh-askpass',
      '/usr/bin/x11-ssh-askpass',
      '/usr/libexec/openssh/ssh-askpass',
      '/usr/lib/ssh/x11-ssh-askpass',
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    return null;
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
set -o pipefail
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

    // /bin/sh is dash on most Linux distros, which doesn't support
    // `set -o pipefail`; run the script under bash so that guard actually
    // works instead of being a fatal syntax error under `set -e`.
    var argv = <String>['/bin/bash', scriptFile.path];
    Map<String, String>? env;
    if (!isRoot) {
      final elev = await _elevationArgv();
      if (elev == null) {
        throw Exception(
            'Root is required to flash, but neither pkexec nor sudo was found. '
            'Start the installer as root, e.g. `sudo ./Librescoot-Installer.AppImage`.');
      }
      if (elev.length >= 2 && elev[1] == '-A') {
        final askpass = await _findAskpass();
        if (askpass != null) env = {'SUDO_ASKPASS': askpass};
      }
      argv = [...elev, ...argv];
    }

    // Estimate total image size for progress calculation
    final imageSize = await _estimateImageSizeBytes(imagePath, isCompressed);
    final totalBytes = imageSize ?? 0;
    // Phase A writes everything after boot area, Phase B writes boot area
    // Progress: Phase A = 0.0-0.9, Phase B = 0.9-0.95, Sync = 0.95, Verify = 0.97
    final phaseABytes = totalBytes > bootAreaBytes ? totalBytes - bootAreaBytes : totalBytes;

    debugPrint('Flash: running two-phase script via ${argv.first}');
    debugPrint('Flash: estimated image size: $totalBytes bytes, phase A: $phaseABytes bytes');
    onProgress?.call(0.0, 'Phase A: Writing partitions...');

    final process = await Process.start(argv.first, argv.sublist(1), environment: env);

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
              if (fraction > 0.01) {
                final elapsed = stopwatch.elapsedMilliseconds / 1000;
                final remaining = (elapsed / fraction) * (1.0 - fraction);
                final mins = (remaining / 60).floor();
                final secs = (remaining % 60).floor();
                eta = ': ${l10n?.flashProgressEta(mins, secs) ?? '${mins}m ${secs}s remaining'}';
              }
              final mbStr = mb.toStringAsFixed(0);
              final base = l10n?.flashProgressMb(mbStr) ?? '$mbStr MB written';
              onProgress?.call(progress, '$base$eta');
            } else if (currentPhase == 'B') {
              final mbStr = mb.toStringAsFixed(1);
              onProgress?.call(0.92, l10n?.flashProgressBootSector(mbStr) ?? 'Boot sector: $mbStr MB written');
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
        throw Exception('Boot sector verification FAILED: checksum mismatch. Check log.');
      }
      if (exitCode == 126) {
        throw Exception('Authorization was dismissed: flash incomplete');
      }
      throw Exception('Flash failed with exit code $exitCode');
    }

    onProgress?.call(1.0, 'Boot sector verified');
  }
}

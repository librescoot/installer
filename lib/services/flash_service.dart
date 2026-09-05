import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../l10n/app_localizations.dart';
import 'disk_arbitration_service.dart';
import 'elevation_service.dart';
import 'usb_detector.dart' show SystemDiskVerdict;

/// Progress callback for flashing operations

/// Safety validation result
class SafetyCheck {
  final bool passed;
  final List<String> errors;

  SafetyCheck({required this.passed, this.errors = const []});
}

class FlashStalledException implements Exception {
  final String message;
  const FlashStalledException(this.message);

  @override
  String toString() => message;
}

/// Service for writing firmware images to devices
class FlashService {
  AppLocalizations? l10n;

  static const Duration _flashStallTimeout = Duration(minutes: 3);

  /// User area of the eMMC every MDB carries: 15269888 sectors of 512 bytes.
  /// Matched exactly. Every platform supplies the raw device size, and a host
  /// that cannot reports none, which is handled separately rather than
  /// compared as a wrong number.
  static const int mdbEmmcBytes = 7818182656;

  /// An eMMC that has lost its user area reports a few tens of MB.
  static const int failedEmmcCeilingBytes = 64 * 1024 * 1024;

  static String _gib(int bytes) =>
      (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);

  static String _mib(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  /// Validate that a device is safe to flash
  ///
  /// Returns a SafetyCheck with any errors.
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
      errors.add(
        'DANGER: This appears to be a system disk. Flashing is blocked.',
      );
    }

    // Must be correct vendor ID
    if (vendorId != 0x0525) {
      errors.add(
        'Wrong vendor ID: 0x${vendorId.toRadixString(16)} (expected 0x0525)',
      );
    }

    // Must be in mass storage mode (PID A4A5)
    if (productId != 0xA4A5) {
      errors.add(
        'Wrong product ID: 0x${productId.toRadixString(16)} (expected 0xa4a5)',
      );
    }

    // One value, not a range: a range wide enough for "any small disk" also
    // admits the SD cards and sticks the detector's match pattern can adopt.
    if (sizeBytes != null) {
      if (sizeBytes <= failedEmmcCeilingBytes) {
        errors.add(
          'eMMC reports only ${_mib(sizeBytes)} MB. The eMMC on this board '
          'has failed; it cannot be flashed.',
        );
      } else if (sizeBytes != mdbEmmcBytes) {
        errors.add(
          'Unexpected device size: ${_gib(sizeBytes)} GB, expected '
          '${_gib(mdbEmmcBytes)} GB. This is not an MDB eMMC.',
        );
      }
    } else if (Platform.isWindows) {
      // Windows supplies the size from Get-Disk, which answers for any disk
      // the storage stack can see. No size means that stack cannot answer,
      // which is the state to stop in rather than write through.
      errors.add(
        'Could not determine the device size. The storage stack did not '
        'answer for this disk.',
      );
    } else {
      // Off Windows the size is resolved separately and may not have landed
      // yet. The identity checks above stand on their own, so this is logged
      // and the flash continues.
      debugPrint('Flash: could not determine device size for $devicePath');
    }

    // Removability is one signal among several and the identity checks decide
    // the case, so it is logged rather than enforced.
    if (!isRemovable) {
      debugPrint('Flash: $devicePath is not detected as removable media');
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
        // disk1 is often the internal APFS container. The VID, PID, size and
        // detected-path checks decide the case; the name alone does not.
        debugPrint('Flash: $devicePath is disk1, which is commonly internal');
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
        errors.add(
          'DANGER: /dev/sda could not be confirmed as the scooter. '
          'Refusing, because it is commonly the system disk.',
        );
      }
      // Never allow nvme0n1 (system NVMe)
      if (devicePath.contains('nvme0n1')) {
        errors.add('DANGER: Cannot flash nvme0n1 (likely system disk)');
      }
    }

    return SafetyCheck(passed: errors.isEmpty, errors: errors);
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
      throw Exception(
        'librescoot-flasher-windows-amd64.exe not found in app bundle',
      );
    }

    await _writeWithGoFlasher(
      flasherPath,
      imagePath,
      devicePath,
      bmapPath,
      true,
      onProgress,
    );
  }

  Future<int?> _estimateImageSizeBytes(
    String imagePath,
    bool isCompressed,
  ) async {
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

  Future<List<String>> _findLinuxPartitions(String devicePath) async {
    final result = await _runBounded('lsblk', 'lsblk', [
      '-rpn',
      '-o',
      'PATH,TYPE',
      devicePath,
    ]);
    if (result == null || result.exitCode != 0) {
      throw Exception(
        'Could not enumerate partitions on $devicePath: '
        '${result?.stderr ?? 'command timed out'}',
      );
    }
    return [
      for (final line in result.stdout.toString().split('\n'))
        if (line.trim().isNotEmpty &&
            line.trim().split(RegExp(r'\s+')).last == 'part')
          line.trim().split(RegExp(r'\s+')).first,
    ];
  }

  Future<List<String>> _linuxMountTargets(String partition) async {
    final result = await _runBounded('findmnt', 'findmnt', [
      '-rn',
      '-S',
      partition,
      '-o',
      'TARGET',
    ]);
    // findmnt returns 1 when there are no matches.
    if (result == null) {
      throw Exception(
        'Could not inspect mounts for $partition: command timed out',
      );
    }
    if (result.exitCode != 0 && result.exitCode != 1) {
      throw Exception(
        'Could not inspect mounts for $partition: ${result.stderr}',
      );
    }
    return result.stdout
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static Future<ProcessResult?> _runBounded(
    String label,
    String executable,
    List<String> args, {
    Duration timeout = const Duration(seconds: 30),
    Map<String, String>? environment,
  }) async {
    Process? proc;
    try {
      proc = await Process.start(executable, args, environment: environment);
      final out = proc.stdout.transform(systemEncoding.decoder).join();
      final err = proc.stderr.transform(systemEncoding.decoder).join();
      final code = await proc.exitCode.timeout(timeout);
      return ProcessResult(proc.pid, code, await out, await err);
    } on TimeoutException {
      debugPrint('Flash: $label timed out after ${timeout.inSeconds}s');
      proc?.kill(ProcessSignal.sigkill);
      if (proc != null) {
        try {
          await proc.exitCode.timeout(const Duration(seconds: 1));
        } catch (_) {}
      }
      return null;
    } catch (e) {
      debugPrint('Flash: $label could not run: $e');
      return null;
    }
  }

  static Future<void> _syncOrCarryOn() async {
    if (await _runBounded(
          'sync',
          'sync',
          const [],
          timeout: const Duration(seconds: 30),
        ) ==
        null) {
      debugPrint('Flash: host flush did not complete, continuing without it');
    }
  }

  @visibleForTesting
  static String shellQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";

  Future<void> _prepareLinuxTarget(String devicePath) async {
    final partitions = await _findLinuxPartitions(devicePath);
    await _syncOrCarryOn();

    for (final partition in partitions) {
      for (final target in await _linuxMountTargets(partition)) {
        debugPrint('Flash: unmounting $partition from $target');
        final direct = await _runBounded('umount $target', 'umount', [
          '--',
          target,
        ]);
        if (direct != null && direct.exitCode == 0) continue;
        debugPrint(
          'Flash: plain umount of $target did not take'
          '${direct == null ? ' (timed out)' : ': ${direct.stderr}'}',
        );

        final viaUdisks = await _runBounded(
          'udisksctl unmount $partition',
          'udisksctl',
          ['unmount', '-b', partition, '--no-user-interaction'],
        );
        if (viaUdisks != null && viaUdisks.exitCode == 0) {
          debugPrint('Flash: udisksctl released $partition');
          continue;
        }
        debugPrint(
          'Flash: udisksctl did not release $partition'
          '${viaUdisks == null ? ' (timed out)' : ': ${viaUdisks.stderr}'}',
        );
      }
    }

    final stubborn = <String>[];
    for (final partition in partitions) {
      stubborn.addAll(await _linuxMountTargets(partition));
    }
    if (stubborn.isNotEmpty) {
      final root = await ElevationService.linuxRootPrefix();
      if (root == null) {
        throw Exception(
          'Refusing to flash: ${stubborn.join(', ')} is still mounted and '
          'this system offers no way to ask for the rights to unmount it. '
          'Unmount it by hand, or relaunch the installer with sudo.',
        );
      }
      final script = stubborn
          .map((t) => 'umount -- ${shellQuote(t)}')
          .join('\n');
      debugPrint('Flash: elevating to unmount ${stubborn.join(', ')}');
      final argv = [...root.argv, 'sh', '-c', script];
      final elevated = await _runBounded(
        'elevated umount',
        argv.first,
        argv.sublist(1),
        environment: {...Platform.environment, ...root.environment},
      );
      if (elevated == null) {
        throw Exception(
          'Refusing to flash: unmounting ${stubborn.join(', ')} did not '
          'finish. The board may have dropped off the bus.',
        );
      }
    }

    for (final partition in partitions) {
      final remaining = await _linuxMountTargets(partition);
      if (remaining.isNotEmpty) {
        throw Exception(
          'Refusing to flash: $partition remains mounted at '
          '${remaining.join(', ')}',
        );
      }
    }
    debugPrint(
      'Flash: all partitions below $devicePath are unmounted; '
      'flasher will acquire O_EXCL',
    );
  }

  Future<bool> _macOSHasMountedVolumes(String diskName) async {
    final listed = await _runBounded('diskutil list $diskName', 'diskutil', [
      'list',
      diskName,
    ]);
    if (listed == null || listed.exitCode != 0) {
      throw Exception(
        'Refusing to flash: could not verify mounted volumes on $diskName',
      );
    }
    final identifiers = <String>{diskName};
    final output = listed.stdout.toString();
    for (final match in RegExp(r'\bdisk\d+s\d+\b').allMatches(output)) {
      identifiers.add(match.group(0)!);
    }
    for (final identifier in identifiers) {
      final info = await _runBounded('diskutil info $identifier', 'diskutil', [
        'info',
        identifier,
      ]);
      if (info == null || info.exitCode != 0) {
        throw Exception(
          'Refusing to flash: could not verify mount state of $identifier',
        );
      }
      if (RegExp(
        r'^\s*Mounted:\s+Yes\s*$',
        multiLine: true,
      ).hasMatch(info.stdout.toString())) {
        return true;
      }
    }
    return false;
  }

  // ---- Two-phase flash ----

  static const bootAreaBytes = 24 * 1024 * 1024; // 24MB
  static const ddBlockSize = 4 * 1024 * 1024; // 4MB
  static const bootAreaBlocks = bootAreaBytes ~/ ddBlockSize; // 6 blocks

  /// Two-phase flash: write partitions first (safe), then boot sector (commits).
  /// If [bmapPath] is provided and the Go flasher binary is available, uses
  /// bmap-based sparse writes (much faster for images with empty space).
  /// A bmap maps one image's blocks. Paired with a different image the write
  /// skips whatever the two disagree about, exits zero, and leaves a board
  /// that cannot boot with nothing in the log to say why, so a pair that do
  /// not name the same image is refused and the image is written whole.
  static String? bmapFor(String imagePath, String? bmapPath) {
    if (bmapPath == null) return null;
    final image = imagePath.split(Platform.pathSeparator).last;
    final bmap = bmapPath.split(Platform.pathSeparator).last;
    final stem = image
        .replaceFirst(RegExp(r'\.gz$'), '')
        .replaceFirst(RegExp(r'\.sdimg$'), '');
    if (bmap.startsWith(stem)) return bmapPath;
    debugPrint(
      'Flash: ignoring bmap $bmap, it does not belong to $image; '
      'writing the image whole',
    );
    return null;
  }

  Future<void> writeTwoPhase(
    String imagePath,
    String devicePath, {
    String? bmapPath,
    void Function(double progress, String message)? onProgress,
  }) async {
    bmapPath = bmapFor(imagePath, bmapPath);
    final isCompressed = imagePath.endsWith('.gz');

    if (Platform.isWindows) {
      await _writeWindowsViaGoFlasher(
        imagePath,
        devicePath,
        isCompressed,
        onProgress,
        bmapPath: bmapPath,
      );
    } else if (Platform.isMacOS) {
      final rawDevice = !devicePath.contains('rdisk')
          ? devicePath.replaceFirst('/dev/disk', '/dev/rdisk')
          : devicePath;
      final diskName = rawDevice.replaceFirst('/dev/rdisk', '/dev/disk');

      // Pre-claim the disk via DiskArbitration. With a claim held, Finder
      // won't auto-mount or pop the "Initialize / Erase / Ignore" dialog
      // for unrecognised partition tables, and authopen no longer hits
      final leased = DiskArbitrationService.sharedHelper;
      final da = leased ?? DiskArbitrationService();
      final leaseOwnsHelper = leased != null;
      var daClaimed = false;
      var unmountSucceeded = false;
      var writerMayRemain = false;
      if (leaseOwnsHelper || await da.ensureStarted()) {
        daClaimed = await da.claim(diskName);
      } else {
        debugPrint(
          'Flash: daclaim helper unavailable, falling back to force-unmount',
        );
      }

      try {
        // Force-unmount as a belt-and-braces. With a DA claim held this is a
        // no-op (nothing's mounted); without one, it's the cheap fix that
        // pries Finder off the disk after the dialog has appeared.
        for (var attempt = 1; attempt <= 3; attempt++) {
          debugPrint('Flash: unmounting $diskName (attempt $attempt/3, force)');
          final r = await _runBounded(
            'diskutil unmountDisk $diskName',
            'diskutil',
            ['unmountDisk', 'force', diskName],
          );
          if (r == null) {
            if (attempt < 3) await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          final stderr = (r.stderr as String).trim();
          final stdout = (r.stdout as String).trim();
          debugPrint(
            'Flash: unmount exit=${r.exitCode} stdout=$stdout stderr=$stderr',
          );
          if (r.exitCode == 0) {
            unmountSucceeded = true;
            break;
          }
          if (attempt < 3) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        if (!daClaimed && !unmountSucceeded) {
          throw Exception(
            'Refusing to flash: could not unmount $diskName or claim it '
            'from Disk Arbitration.',
          );
        }
        if (await _macOSHasMountedVolumes(diskName)) {
          throw Exception(
            'Refusing to flash: a volume on $diskName remains mounted.',
          );
        }

        final flasherPath = await _getFlasherPath();
        try {
          if (flasherPath != null) {
            await _writeWithGoFlasher(
              flasherPath,
              imagePath,
              rawDevice,
              bmapPath,
              true,
              onProgress,
            );
          } else {
            debugPrint(
              'Flash: no Go flasher for ${Abi.current()}, falling back to dd',
            );
            await _writeMacOSDdFallback(imagePath, rawDevice, onProgress);
          }
        } on FlashStalledException {
          writerMayRemain = true;
          rethrow;
        }
      } finally {
        if (!writerMayRemain && daClaimed) await da.release(diskName);
        // Only tear down a helper this call started: the board re-enumerates
        // after the write, so the leased watch is still needed.
        if (!writerMayRemain && !leaseOwnsHelper) await da.stop();
      }
    } else {
      // Linux: single pkexec elevation for both dd phases + verify
      await _writeTwoPhaseLinux(
        imagePath,
        devicePath,
        isCompressed,
        onProgress,
        bmapPath: bmapPath,
      );
    }
  }

  /// Locate the Go flasher binary for the current host platform.
  ///
  /// On macOS and Linux the binary is installed with +x by the build system
  /// (Xcode build phase / CMake install), so no chmod is needed at runtime.
  /// Windows bundles it via Flutter assets (no execute bit needed).
  /// macOS dd fallback for hosts without a matching librescoot-flasher
  /// binary in the bundle. Single-phase, no bmap, no two-phase safety:
  /// strictly a "get the bits there" path.
  ///
  /// This used to run dd as itself, on the reasoning that the app had
  /// self-elevated. It no longer does on macOS, and /dev/rdiskN is root-owned,
  /// so that dd could only ever end in "Permission denied" with no prompt
  /// anywhere for the user to answer. dd goes through `sudo -A` and the
  /// osascript askpass now, and where there is no way to ask, this refuses
  /// instead of starting a write that cannot land.
  Future<void> _writeMacOSDdFallback(
    String imagePath,
    String rawDevice,
    void Function(double progress, String message)? onProgress,
  ) async {
    final isCompressed = imagePath.endsWith('.gz');
    final totalBytes =
        await _estimateImageSizeBytes(imagePath, isCompressed) ?? 0;
    final totalMb = totalBytes / (1024 * 1024);
    onProgress?.call(0.0, 'dd fallback (no Go flasher for this CPU)...');

    // Only dd needs the privileges, so sudo wraps dd alone and gunzip stays on
    // this side of the pipe as the user.
    final env = <String, String>{};
    var dd = 'dd';
    final isRoot =
        (await Process.run('id', ['-u'])).stdout.toString().trim() == '0';
    if (!isRoot) {
      final askpass = await _findAskpass();
      if (askpass == null) {
        throw Exception(
          'This build has no flasher for ${Abi.current()} and no way to ask '
          'for the administrator password, so the card cannot be written. '
          'Download the installer again from downloads.librescoot.org.',
        );
      }
      env['SUDO_ASKPASS'] = askpass;
      dd = 'sudo -A dd';
      onProgress?.call(0.0, 'Waiting for authorization...');
    }

    // macOS /bin/sh is bash, which supports pipefail: without it, a gunzip
    // I/O error would be swallowed and only dd's (successful) exit code
    // would count, leaving a truncated write reported as success.
    final cmd = isCompressed
        ? 'set -o pipefail; gunzip -c "$imagePath" | $dd of=$rawDevice bs=4m'
        : '$dd if="$imagePath" of=$rawDevice bs=4m';

    debugPrint('Flash: dd fallback: $cmd');
    final process = await Process.start(
      '/bin/sh',
      ['-c', cmd],
      environment: {...Platform.environment, ...env},
    );

    // macOS dd prints status only on SIGINFO. Poke it every 2s so the user
    // sees something move. Only while we are root: under sudo the dd belongs
    // to root and a signal from this uid bounces off it, so there is nothing
    // to poke and the write runs without a byte counter.
    final ticker = isRoot
        ? Timer.periodic(const Duration(seconds: 2), (_) async {
            try {
              final r = await Process.run('pgrep', [
                '-P',
                '${process.pid}',
                'dd',
              ]);
              final ddPid = int.tryParse(r.stdout.toString().trim());
              if (ddPid != null) {
                await Process.run('kill', ['-INFO', '$ddPid']);
              }
            } catch (_) {}
          })
        : null;

    final stderrBuf = StringBuffer();
    final stalled = Completer<void>();
    Timer? stall;
    var exitCode = -1;
    void resetStall() {
      stall?.cancel();
      stall = Timer(_flashStallTimeout, () {
        if (!stalled.isCompleted) {
          debugPrint('Flash: dd fallback stopped producing output');
          try {
            process.kill(ProcessSignal.sigkill);
          } catch (_) {}
          stalled.complete();
        }
      });
    }

    resetStall();
    final stdoutSub = process.stdout.listen((_) {});
    final stderrSub = process.stderr.transform(utf8.decoder).listen((chunk) {
      resetStall();
      stderrBuf.write(chunk);
      // dd status lines look like: "12345678 bytes transferred in 4.2 secs"
      final m = RegExp(r'(\d+) bytes').firstMatch(chunk);
      if (m != null) {
        final bytes = int.tryParse(m.group(1)!) ?? 0;
        final mb = bytes / (1024 * 1024);
        if (totalBytes > 0) {
          final fraction = (bytes / totalBytes).clamp(0.0, 0.95);
          onProgress?.call(
            fraction,
            'dd: ${mb.toStringAsFixed(0)} / ${totalMb.toStringAsFixed(0)} MB',
          );
        } else {
          final mbStr = mb.toStringAsFixed(0);
          onProgress?.call(
            0.0,
            'dd: ${l10n?.flashProgressMb(mbStr) ?? '$mbStr MB written'}',
          );
        }
      }
    });
    final processDone = process.exitCode.then<void>((code) {
      exitCode = code;
    });
    try {
      await Future.any<void>([processDone, stalled.future]);
    } finally {
      stall?.cancel();
      ticker?.cancel();
      await stdoutSub.cancel();
      await stderrSub.cancel();
    }

    if (stalled.isCompleted) {
      throw FlashStalledException(
        'Flash stalled: the board stopped responding partway through the '
        'write. The privileged writer may still own the device, so the '
        'write must not be retried from this installer. Leave it connected '
        'and contact support.',
      );
    }
    if (exitCode != 0) {
      throw Exception('dd fallback failed: ${stderrBuf.toString().trim()}');
    }
    await _syncOrCarryOn();
    onProgress?.call(1.0, 'dd: complete');
  }

  /// Pick the librescoot-flasher binary that matches the current host
  /// CPU. Returns null on an unsupported (OS, arch) combo: the caller
  /// must then either fall back (macOS) or surface an error.
  String? _flasherBinaryName() {
    final abi = Abi.current();
    if (Platform.isWindows) {
      if (abi == Abi.windowsArm64) {
        return 'librescoot-flasher-windows-arm64.exe';
      }
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
      path.join(
        execDir,
        'data',
        'flutter_assets',
        'assets',
        'tools',
        binaryName,
      ),
      path.join(Directory.current.path, 'assets', 'tools', binaryName),
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        debugPrint('Flash: found Go flasher at $candidate (${Abi.current()})');
        return candidate;
      }
    }
    debugPrint(
      'Flash: Go flasher $binaryName (${Abi.current()}) not found in: $candidates',
    );
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
      '--image',
      imagePath,
      '--device',
      devicePath,
      if (bmapPath != null) ...[
        '--bmap',
        bmapPath,
      ] else ...[
        '--two-phase',
        '--boot-blocks',
        '$bootAreaBlocks',
      ],
    ];

    // When we run from an AppImage, the bundled flasher lives inside a per-user
    // FUSE mount (/tmp/.mount_*) that root can't read, so `pkexec <flasher>`
    // fails with "Error accessing ...: Permission denied" (exit 127). Copy it
    // out to a normal path root can exec.
    flasherPath = await _ensureFlasherRunnableAsRoot(flasherPath);

    debugPrint('Flash: running: $flasherPath ${flasherArgs.join(' ')}');

    // Total bytes will be updated by TOTAL: output from flasher
    var totalBytes =
        await _estimateImageSizeBytes(imagePath, imagePath.endsWith('.gz')) ??
        0;
    var totalMb = totalBytes / (1024 * 1024);
    // Stopwatch starts on first output (after auth/elevation)
    final stopwatch = Stopwatch();

    onProgress?.call(
      0.0,
      bmapPath != null ? 'Bmap flash...' : 'Waiting for authorization...',
    );

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
      final elev = await _elevationInvocation();
      if (elev == null) {
        throw Exception(
          'Root is required to flash, but no graphical elevation method is available. '
          'Start the installer as root, e.g. `sudo ./Librescoot-Installer.AppImage`.',
        );
      }
      final argv = [...elev.argv, flasherPath, ...flasherArgs];
      debugPrint('Flash: elevating via ${elev.argv.join(' ')}');
      process = await Process.start(
        argv.first,
        argv.sublist(1),
        environment: {...Platform.environment, ...elev.environment},
      );
    }
    final output = StringBuffer();

    process.stdout.listen((_) {});

    Timer? stall;
    var stalled = false;
    final finished = Completer<void>();
    late final StreamSubscription<String> stderrSub;

    void endWait() {
      if (!finished.isCompleted) finished.complete();
    }

    void resetStall() {
      stall?.cancel();
      stall = Timer(_flashStallTimeout, () {
        stalled = true;
        debugPrint(
          'Flash: no output for ${_flashStallTimeout.inSeconds}s, '
          'giving up on the flasher',
        );
        try {
          process.kill();
        } catch (e) {
          debugPrint('Flash: could not signal the flasher: $e');
        }
        endWait();
      });
    }

    resetStall();
    try {
      stderrSub = process.stderr
          .transform(utf8.decoder)
          .listen(
            (chunk) {
              resetStall();
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
                  if (phase == 'A') {
                    onProgress?.call(0.0, 'Phase A: Writing partitions...');
                  }
                  if (phase == 'B') {
                    onProgress?.call(0.9, 'Phase B: Writing boot sector...');
                  }
                  if (phase == 'verify') {
                    onProgress?.call(
                      0.95,
                      l10n?.flashVerifyingReadback ??
                          'Verifying boot-critical data on the device…',
                    );
                  }
                }
                if (line.startsWith('PROGRESS:')) {
                  final bytes = int.tryParse(line.substring(9).trim());
                  if (bytes != null && totalBytes > 0) {
                    final fraction = (bytes / totalBytes).clamp(0.0, 0.95);
                    final mb = bytes / (1024 * 1024);
                    final mbStr = mb.toStringAsFixed(0);
                    final totalMbStr = totalMb.toStringAsFixed(0);
                    final base =
                        l10n?.flashProgressMbOfTotal(mbStr, totalMbStr) ??
                        '$mbStr / $totalMbStr MB written';
                    String eta = '';
                    if (fraction > 0.01) {
                      final elapsed = stopwatch.elapsedMilliseconds / 1000;
                      final remaining = (elapsed / fraction) * (1.0 - fraction);
                      final mins = remaining ~/ 60;
                      final secs = (remaining % 60).floor();
                      eta =
                          ': ${l10n?.flashProgressEta(mins, secs) ?? '${mins}m ${secs}s remaining'}';
                    }
                    onProgress?.call(fraction, '$base$eta');
                  }
                }
                if (line.startsWith('CHECKSUM MISMATCH')) {
                  debugPrint('Flash: $line');
                  sawChecksumMismatch = true;
                }
              }
            },
            onDone: endWait,
            onError: (Object e) {
              debugPrint('Flash: flasher stderr failed: $e');
              endWait();
            },
          );
      await finished.future;
    } finally {
      stall?.cancel();
      await stderrSub.cancel();
    }

    var exitTimedOut = false;
    final exitCode = stalled
        ? -1
        : await process.exitCode.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              exitTimedOut = true;
              try {
                process.kill(ProcessSignal.sigkill);
              } catch (_) {}
              return -1;
            },
          );
    debugPrint('Flash: Go flasher exit code: $exitCode');

    if (stalled || exitTimedOut) {
      debugPrint('Flash: Go flasher output: ${output.toString()}');
      throw FlashStalledException(
        'Flash stalled: the board stopped responding partway through the '
        'write. The privileged writer may still own the device, so the '
        'write must not be retried from this installer. Leave it connected '
        'and contact support.',
      );
    }

    // Fatal regardless of exit code: a checksum mismatch means the write is
    // corrupt even if the flasher process itself exited 0.
    if (sawChecksumMismatch) {
      debugPrint('Flash: Go flasher output: ${output.toString()}');
      throw Exception(
        'Flash verification FAILED: checksum mismatch detected during write. Check log.',
      );
    }

    if (exitCode != 0) {
      final out = output.toString();
      debugPrint('Flash: Go flasher output: $out');
      if (exitCode == 126) {
        throw Exception('Authorization was dismissed: flash incomplete');
      }
      throw Exception('Flash failed: ${_humanFlashError(out)}');
    }

    await _flushDevice(devicePath);
    onProgress?.call(1.0, 'Flash complete');
  }

  /// Push what the write left in host buffers down to the device, before
  /// anything cuts its power.
  ///
  /// The dd path has always ended in `sync`; this one ended at "Flash
  /// complete". So the two disagreed about whether the write was durable at
  /// the moment the user is told to restart the scooter, and the restart on
  /// this path is a power cut rather than a shutdown: whatever has not reached
  /// the eMMC by then is gone. A board that comes up without the last of its
  /// bootloader finds nothing to start and drops into its boot ROM.
  ///
  /// Best-effort by design. A flush that cannot be issued is not a reason to
  /// fail a write that succeeded, but it is worth saying so in the log,
  /// because it changes what a boot failure afterwards means.
  Future<void> _flushDevice(String devicePath) async {
    try {
      if (Platform.isLinux) {
        // blockdev asks the block layer to flush and pass a cache sync to the
        // device; the bare sync afterwards covers anything still queued
        // elsewhere. Both are cheap against a write measured in minutes.
        final r = await _runBounded('blockdev --flushbufs', 'blockdev', [
          '--flushbufs',
          devicePath,
        ]);
        if (r != null && r.exitCode != 0) {
          debugPrint('Flash: blockdev --flushbufs said: ${r.stderr}');
        }
        final scoped = await _runBounded('sync $devicePath', 'sync', [
          devicePath,
        ]);
        if (scoped == null || scoped.exitCode != 0) {
          await _syncOrCarryOn();
        }
        debugPrint('Flash: flushed $devicePath');
      } else if (Platform.isMacOS) {
        await _syncOrCarryOn();
        debugPrint('Flash: flushed $devicePath');
      } else {
        // Windows writes to \\.\PHYSICALDRIVE without going through a
        // filesystem cache, and there is no equivalent flush to call from
        // here. Named so a reader does not take the silence for an omission.
        debugPrint('Flash: no host flush needed on this platform');
      }
    } catch (e) {
      debugPrint('Flash: could not flush $devicePath (ok): $e');
    }
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
        .where(
          (l) => !RegExp(
            r'^\s*(TOTAL:|PHASE:|PROGRESS:|VERIFY_PROGRESS:|Bmap:)',
          ).hasMatch(l),
        )
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    return kept.isEmpty ? raw.trim() : kept.join('\n');
  }

  /// Copy the flasher out of an AppImage's per-user FUSE mount (which a
  /// pkexec/sudo-elevated root can't read) to a normal temp path. No-op
  /// outside an AppImage or off Linux.
  Future<String> _ensureFlasherRunnableAsRoot(String flasherPath) async {
    final inAppImage =
        Platform.environment.containsKey('APPIMAGE') ||
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
      debugPrint(
        'Flash: could not copy flasher out of AppImage ($e); using original',
      );
      return flasherPath;
    }
  }

  Future<RootInvocation?> _elevationInvocation() async {
    if (Platform.isLinux) {
      return ElevationService.linuxRootPrefix();
    }
    if (await _hasCommand('pkexec')) {
      return const RootInvocation(['pkexec'], {});
    }
    if (await _hasCommand('sudo')) {
      final askpass = await _findAskpass();
      if (askpass != null) {
        return RootInvocation(const ['sudo', '-A'], {'SUDO_ASKPASS': askpass});
      }
    }
    return null;
  }

  /// True if [name] is found on PATH (avoids depending on `which` existing).
  Future<bool> _hasCommand(String name) async {
    final pathEnv =
        Platform.environment['PATH'] ??
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
    // macOS ships none of the X11 helpers below, and the app does not
    // self-elevate there, so without one `sudo` runs in a GUI with no
    // terminal: it fails before it asks anything and the user is told the
    // flash failed, having never been offered a password box. One is written
    // on demand instead.
    if (Platform.isMacOS) return _writeMacOsAskpass();
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

  /// The helper `sudo -A` runs: ask through osascript, print what was typed.
  ///
  /// A cancelled dialog makes osascript exit non-zero with nothing on stdout,
  /// which sudo reads as an empty password and refuses, so cancelling ends the
  /// flash rather than starting one nobody authorised.
  @visibleForTesting
  static final String macOsAskpassScript = ElevationService.macOsAskpassScript(
    _askpassReason,
  );

  static const String _askpassReason = 'to write to the card';

  ///
  Future<String?>? _macOsAskpassPath;

  Future<String?> _writeMacOsAskpass() async {
    // One per flash service: sudo may ask more than once, and rewriting the
    // script under a running prompt is not worth the risk.
    return _macOsAskpassPath ??= () async {
      try {
        final dir = await Directory.systemTemp.createTemp(
          'librescoot_askpass_',
        );
        final script = File(path.join(dir.path, 'askpass.sh'));
        await script.writeAsString(macOsAskpassScript);
        await Process.run('chmod', ['0700', script.path]);
        return script.path;
      } catch (e) {
        debugPrint('Flash: could not write the askpass helper ($e)');
        return null;
      }
    }();
  }

  /// Linux two-phase flash: single pkexec auth, both phases + verify in one script.
  Future<void> _writeTwoPhaseLinux(
    String imagePath,
    String devicePath,
    bool isCompressed,
    void Function(double progress, String message)? onProgress, {
    String? bmapPath,
  }) async {
    // Desktop volume monitors may mount the UMS partitions as soon as they
    // enumerate. Remove every mount and fail closed; the Linux flasher then
    // opens the whole disk O_EXCL, which prevents a remount through the write,
    // flush, and verification window.
    await _prepareLinuxTarget(devicePath);

    final isRoot =
        (await Process.run('id', ['-u'])).stdout.toString().trim() == '0';

    // Try Go flasher first (supports bmap for sparse writes)
    final flasherPath = await _getFlasherPath();
    if (flasherPath != null) {
      await _writeWithGoFlasher(
        flasherPath,
        imagePath,
        devicePath,
        bmapPath,
        isRoot,
        onProgress,
      );
      return;
    }

    debugPrint('Flash: Go flasher not found, falling back to dd');
    final decompressPrefix = isCompressed ? 'gunzip -c "$imagePath" |' : '';
    final inputArg = isCompressed ? 'iflag=fullblock' : 'if="$imagePath"';

    // Single shell script that does Phase A, Phase B, sync, and verify
    final script =
        '''
set -e
set -o pipefail
echo "PHASE:A"
$decompressPrefix dd $inputArg of=$devicePath bs=4M skip=$bootAreaBlocks seek=$bootAreaBlocks oflag=direct status=progress 2>&1 | tr '\\r' '\\n'
echo "PHASE:B"
$decompressPrefix dd $inputArg of=$devicePath bs=4M count=$bootAreaBlocks oflag=direct status=progress 2>&1 | tr '\\r' '\\n'
echo "PHASE:SYNC"
# Named rather than bare: as root this can flush the device alone, so an
# unrelated wedged filesystem on the host cannot hold the flash up. Older
# coreutils has no `sync FILE`, hence the fallback.
sync $devicePath 2>/dev/null || sync
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
    final env = <String, String>{};
    if (!isRoot) {
      final elev = await _elevationInvocation();
      if (elev == null) {
        throw Exception(
          'Root is required to flash, but no graphical elevation method is available. '
          'Start the installer as root, e.g. `sudo ./Librescoot-Installer.AppImage`.',
        );
      }
      env.addAll(elev.environment);
      argv = [...elev.argv, ...argv];
    }

    // Estimate total image size for progress calculation
    final imageSize = await _estimateImageSizeBytes(imagePath, isCompressed);
    final totalBytes = imageSize ?? 0;
    // Phase A writes everything after boot area, Phase B writes boot area
    // Progress: Phase A = 0.0-0.9, Phase B = 0.9-0.95, Sync = 0.95, Verify = 0.97
    final phaseABytes = totalBytes > bootAreaBytes
        ? totalBytes - bootAreaBytes
        : totalBytes;

    debugPrint('Flash: running two-phase script via ${argv.first}');
    debugPrint(
      'Flash: estimated image size: $totalBytes bytes, phase A: $phaseABytes bytes',
    );
    onProgress?.call(0.0, 'Phase A: Writing partitions...');

    final process = await Process.start(
      argv.first,
      argv.sublist(1),
      environment: {...Platform.environment, ...env},
    );

    var currentPhase = 'A';
    final output = StringBuffer();
    final stopwatch = Stopwatch()..start();
    void handleOutput(String chunk) {
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
              final progress = fraction * 0.9;
              if (fraction > 0.01) {
                final elapsed = stopwatch.elapsedMilliseconds / 1000;
                final remaining = (elapsed / fraction) * (1.0 - fraction);
                final mins = (remaining / 60).floor();
                final secs = (remaining % 60).floor();
                eta =
                    ': ${l10n?.flashProgressEta(mins, secs) ?? '${mins}m ${secs}s remaining'}';
              }
              final mbStr = mb.toStringAsFixed(0);
              final base = l10n?.flashProgressMb(mbStr) ?? '$mbStr MB written';
              onProgress?.call(progress, '$base$eta');
            } else if (currentPhase == 'B') {
              final mbStr = mb.toStringAsFixed(1);
              onProgress?.call(
                0.92,
                l10n?.flashProgressBootSector(mbStr) ??
                    'Boot sector: $mbStr MB written',
              );
            }
          }
        }
      }
    }

    var stalled = false;
    final stalledSignal = Completer<void>();
    Timer? stall;
    void resetStall() {
      stall?.cancel();
      stall = Timer(_flashStallTimeout, () {
        stalled = true;
        debugPrint('Flash: two-phase dd fallback stopped producing output');
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
        if (!stalledSignal.isCompleted) stalledSignal.complete();
      });
    }

    resetStall();
    final stdoutSub = process.stdout.transform(utf8.decoder).listen((chunk) {
      resetStall();
      handleOutput(chunk);
    });
    final stderrSub = process.stderr.transform(utf8.decoder).listen((chunk) {
      resetStall();
      output.write(chunk);
    });
    var exitCode = -1;
    final processDone = process.exitCode.then<void>((code) {
      exitCode = code;
    });
    try {
      await Future.any<void>([processDone, stalledSignal.future]);
    } finally {
      stall?.cancel();
      await stdoutSub.cancel();
      await stderrSub.cancel();
    }
    debugPrint('Flash: two-phase script exit code: $exitCode');

    // Clean up script
    try {
      await scriptFile.delete();
    } catch (_) {}

    if (stalled) {
      throw FlashStalledException(
        'Flash stalled: the board stopped responding partway through the '
        'write. The privileged writer may still own the device, so the '
        'write must not be retried from this installer. Leave it connected '
        'and contact support.',
      );
    }
    if (exitCode != 0) {
      final out = output.toString();
      debugPrint('Flash: script output: $out');
      if (out.contains('VERIFY:FAIL')) {
        throw Exception(
          'Boot sector verification FAILED: checksum mismatch. Check log.',
        );
      }
      if (exitCode == 126) {
        throw Exception('Authorization was dismissed: flash incomplete');
      }
      throw Exception('Flash failed with exit code $exitCode');
    }

    onProgress?.call(1.0, 'Boot sector verified');
  }
}

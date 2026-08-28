// Wrapper around the bundled `daclaim` macOS helper. The helper holds a
// Disk Arbitration claim on a block device for as long as the helper process
// is alive (or until we explicitly release), which prevents Finder from
// auto-mounting the disk and from popping the "Initialize / Erase / Ignore"
// dialog when the partition table isn't recognised.
//
// On Linux/Windows everything here is a no-op.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'package:librescoot_installer/services/usb_detector.dart';

class DiskArbitrationService {
  static final DiskWatchLease _watch = DiskWatchLease();

  /// Arm the peek watch for the MDB's mass-storage gadget. Call *before* the
  /// board is rebooted into UMS mode, not after the disk shows up.
  static Future<void> armWatch() => _watch.arm(
        UsbDetector.targetVendorId,
        UsbDetector.massStoragePid,
      );

  /// Release the watch and every claim the helper holds.
  static Future<void> disarmWatch() => _watch.disarm();

  static DiskArbitrationService? get sharedHelper => _watch.helper;

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  Completer<String>? _pendingReply;
  // Serialises commands so a slow claim can't get its reply mixed up with
  // the next claim/release the caller fires off.
  final _lock = _AsyncLock();

  bool get isRunning => _process != null;

  /// Locate `daclaim` in the app bundle (or development tree). Returns null
  /// if not found, in which case all claim/release calls become no-ops.
  static Future<String?> locate() async {
    if (!Platform.isMacOS) return null;
    final execDir = path.dirname(Platform.resolvedExecutable);
    final candidates = [
      // Inside the .app bundle
      path.join(execDir, '..', 'Resources', 'daclaim'),
      // Dev fallback if someone built it manually
      path.join(Directory.current.path, 'macos', 'Runner', 'daclaim'),
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    return null;
  }

  /// Start the helper subprocess. Safe to call multiple times, second call
  /// is a no-op if already running.
  Future<bool> start(String helperPath) async {
    if (_process != null) return true;
    try {
      _process = await Process.start(helperPath, const []);
      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onLine);
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) => debugPrint('daclaim stderr: $l'));
      _process!.exitCode.then((code) {
        debugPrint('daclaim exited code=$code');
        _process = null;
      });
      // Sanity check the helper is actually responding.
      final pong = await _send('ping');
      if (pong != 'pong') {
        debugPrint('daclaim ping failed: $pong');
        await stop();
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('daclaim start failed: $e');
      _process = null;
      return false;
    }
  }

  /// Locate and start the helper in one step. Returns false when the helper
  /// isn't in the bundle, which is the signal to fall back to force-unmount.
  Future<bool> ensureStarted() async {
    if (_process != null) return true;
    final helperPath = await locate();
    if (helperPath == null) {
      debugPrint('daclaim: helper not found in bundle');
      return false;
    }
    return start(helperPath);
  }

  /// Claim `/dev/diskN`. Pass either "diskN", "/dev/diskN", or "/dev/rdiskN".
  Future<bool> claim(String disk) async {
    final bsd = _bsdName(disk);
    final reply = await _send('claim $bsd');
    final ok = isClaimHeld(reply);
    debugPrint('daclaim claim $bsd: $reply');
    return ok;
  }

  /// Whether a `claim` reply means the disk is ours now. With the watch armed
  /// the disk is normally claimed before the flash path asks, so
  /// "already claimed" is the success case, not a failure.
  @visibleForTesting
  static bool isClaimHeld(String reply) =>
      reply == 'ok' || reply == 'already claimed';

  /// Claim any whole disk that appears under USB [vendorId]:[productId],
  /// before macOS probes it, until [unwatch].
  Future<bool> watch(int vendorId, int productId) async {
    final v = '0x${vendorId.toRadixString(16)}';
    final p = '0x${productId.toRadixString(16)}';
    final reply = await _send('watch $v $p');
    final ok = reply == 'ok' || reply == 'already watching';
    debugPrint('daclaim watch $v:$p: $reply');
    return ok;
  }

  Future<bool> unwatch() async {
    final reply = await _send('unwatch');
    final ok = reply == 'ok' || reply == 'not watching';
    debugPrint('daclaim unwatch: $reply');
    return ok;
  }

  Future<bool> release(String disk) async {
    final bsd = _bsdName(disk);
    final reply = await _send('release $bsd');
    final ok = reply == 'ok';
    debugPrint('daclaim release $bsd: $reply');
    return ok;
  }

  Future<void> stop() async {
    final p = _process;
    if (p == null) return;
    try {
      p.stdin.writeln('quit');
      await p.stdin.flush();
    } catch (_) {}
    try {
      await p.exitCode.timeout(const Duration(seconds: 2), onTimeout: () {
        p.kill(ProcessSignal.sigterm);
        return -1;
      });
    } catch (_) {}
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    _process = null;
    if (_pendingReply != null && !_pendingReply!.isCompleted) {
      _pendingReply!.complete('error: helper exited');
      _pendingReply = null;
    }
  }

  Future<String> _send(String command) async {
    if (_process == null) return 'error: helper not running';
    return _lock.synchronized(() async {
      _pendingReply = Completer<String>();
      try {
        _process!.stdin.writeln(command);
        await _process!.stdin.flush();
      } catch (e) {
        _pendingReply = null;
        return 'error: write failed: $e';
      }
      // Dart timeout sits above the helper's 30s internal DA-op timeout
      // so we receive its "claim timeout" reply before giving up. If we
      // gave up first, the helper's belated reply would land in the next
      // command's completer and desync the protocol.
      final reply = await _pendingReply!.future.timeout(
        const Duration(seconds: 40),
        onTimeout: () => 'error: timeout',
      );
      _pendingReply = null;
      return reply;
    });
  }

  void _onLine(String line) {
    final c = _pendingReply;
    if (c != null && !c.isCompleted) {
      c.complete(line);
    } else {
      debugPrint('daclaim unsolicited: $line');
    }
  }

  static String _bsdName(String disk) {
    var s = disk;
    if (s.startsWith('/dev/')) s = s.substring('/dev/'.length);
    if (s.startsWith('r')) s = s.substring(1); // rdiskN -> diskN
    return s;
  }
}

/// Process-wide lease over the DA peek watch. Armed before the UMS reboot and
/// held until the flash is over, so it outlives any single call: same shape as
/// [AutoPlayServiceLease], serialised so disarm can't race arm.
class DiskWatchLease {
  DiskWatchLease({DiskArbitrationService? service, bool? isMacOS})
      : _service = service ?? DiskArbitrationService(),
        _isMacOS = isMacOS ?? Platform.isMacOS;

  final DiskArbitrationService _service;
  final bool _isMacOS;
  Future<void> _operations = Future<void>.value();
  bool _armed = false;

  /// The running helper, or null. The flash path reuses it rather than
  /// starting a second one, whose claim the first would refuse.
  DiskArbitrationService? get helper => _service.isRunning ? _service : null;

  bool get isArmed => _armed;

  Future<void> arm(int vendorId, int productId) => _enqueue(() async {
        if (!_isMacOS || _armed) return;
        try {
          if (!await _service.ensureStarted()) {
            debugPrint('daclaim: no helper, disk dialog will not be suppressed');
            return;
          }
          _armed = await _service.watch(vendorId, productId);
        } catch (error) {
          debugPrint('daclaim: failed to arm watch: $error');
        }
      });

  Future<void> disarm() => _enqueue(() async {
        if (!_isMacOS || !_armed) return;
        try {
          await _service.unwatch();
        } catch (error) {
          debugPrint('daclaim: failed to disarm watch: $error');
        }
        _armed = false;
        // Stopping releases every claim held, so only disarm after the write.
        try {
          await _service.stop();
        } catch (error) {
          debugPrint('daclaim: failed to stop helper: $error');
        }
      });

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.catchError((_) {});
    return result;
  }
}

/// Tiny async mutex so concurrent callers can't interleave their
/// stdin writes / stdout reads.
class _AsyncLock {
  Future<void> _tail = Future.value();

  Future<T> synchronized<T>(Future<T> Function() body) {
    final completer = Completer<void>();
    final prev = _tail;
    _tail = completer.future;
    return prev.then((_) async {
      try {
        return await body();
      } finally {
        completer.complete();
      }
    });
  }
}

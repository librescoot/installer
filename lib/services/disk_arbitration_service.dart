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

class DiskArbitrationService {
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

  /// Start the helper subprocess. Safe to call multiple times — second call
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

  /// Claim `/dev/diskN`. Pass either "diskN", "/dev/diskN", or "/dev/rdiskN".
  Future<bool> claim(String disk) async {
    final bsd = _bsdName(disk);
    final reply = await _send('claim $bsd');
    final ok = reply == 'ok';
    debugPrint('daclaim claim $bsd: $reply');
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

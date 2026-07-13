import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Service for handling privilege elevation across platforms.
///
/// Strategy: Self-elevate the entire app on startup to avoid
/// multiple UAC/sudo prompts during operation.
class ElevationService {
  /// Check if the current process has admin/root privileges.
  static Future<bool> isElevated() async {
    if (Platform.isWindows) {
      return _isWindowsAdmin();
    } else if (Platform.isMacOS || Platform.isLinux) {
      return _isUnixRoot();
    }
    return false;
  }

  /// Relaunch the app with elevated privileges.
  /// [extraArgs] are appended to the command line (e.g. --channel=testing --region=bayern --auto-start).
  /// Returns true if relaunch was initiated (caller should exit).
  /// Returns false if already elevated or elevation failed.
  static Future<bool> elevateIfNeeded({List<String> extraArgs = const []}) async {
    if (await isElevated()) {
      return false; // Already elevated
    }

    final executable = Platform.resolvedExecutable;
    final args = [...Platform.executableArguments, ...extraArgs];

    if (Platform.isWindows) {
      return _elevateWindows(executable, args);
    } else if (Platform.isMacOS) {
      return _elevateMacOS(executable, args);
    } else if (Platform.isLinux) {
      return _elevateLinux(executable, args);
    }

    return false;
  }

  static Future<bool> _isWindowsAdmin() async {
    // Try to write to a protected location
    // Or use 'net session' which fails without admin
    try {
      final result = await Process.run('net', ['session'], runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isUnixRoot() async {
    // Check effective UID
    try {
      final result = await Process.run('id', ['-u']);
      return result.stdout.toString().trim() == '0';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _elevateWindows(String executable, List<String> args) async {
    // Use PowerShell Start-Process with -Verb RunAs for UAC elevation.
    // ArgumentList wants an array of strings each individually quoted —
    // joining them into one space-separated string breaks for any arg
    // containing spaces (e.g. a path with spaces) and may cause
    // Start-Process to silently fail. Build a real PowerShell array
    // literal and use the call operator so the executable path is
    // resolved before -Verb RunAs hands off to ShellExecuteEx.
    String psQuote(String s) => "'${s.replaceAll("'", "''")}'";
    final psExe = psQuote(executable);
    final psArgArray = args.isEmpty ? '@()' : '@(${args.map(psQuote).join(',')})';
    final psCmd =
        'Start-Process -FilePath $psExe -ArgumentList $psArgArray -Verb RunAs '
        '-ErrorAction Stop';

    debugPrint('Elevation: PowerShell command = $psCmd');
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', psCmd],
        runInShell: true,
      );
      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      debugPrint(
        'Elevation: PowerShell exit=${result.exitCode}'
        '${stdout.isEmpty ? "" : " stdout=$stdout"}'
        '${stderr.isEmpty ? "" : " stderr=$stderr"}',
      );
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Elevation: PowerShell threw: $e');
      return false;
    }
  }

  static Future<bool> _elevateMacOS(String executable, List<String> args) async {
    // Write a launcher script to avoid shell quoting issues with osascript.
    // The script logs to a file for debugging and does NOT use exec (so & works).
    //
    // The launcher lives in a securely-created, unpredictably-named temp dir
    // rather than a fixed /tmp path: a fixed world-writable path lets another
    // local user pre-create/symlink it before we write to it (TOCTOU), which
    // `do shell script ... with administrator privileges` would then execute
    // as root.
    final tempDir = await Directory.systemTemp.createTemp('librescoot_elevate_');
    final launcher = File(path.join(tempDir.path, 'elevate.sh'));
    final logFile = path.join(tempDir.path, 'elevate.log');
    final argLine = args.map((a) => "'${a.replaceAll("'", "'\\''")}'").join(' ');
    // The launcher script MUST exit immediately. do shell script waits for it.
    // Only launch the app in background and exit: nothing else.
    await launcher.writeAsString(
      '#!/bin/sh\n'
      '\'${executable.replaceAll("'", "'\\''")}\' $argLine >> \'$logFile\' 2>&1 &\n',
    );
    await Process.run('chmod', ['+x', launcher.path]);

    try {
      final escapedPath = launcher.path.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      final result = await Process.run('osascript', [
        '-e',
        'do shell script "$escapedPath" with administrator privileges',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    } finally {
      // Best-effort cleanup; the unpredictable path is what matters for
      // correctness, not whether this succeeds. By the time osascript
      // returns, the launcher has already forked the elevated process into
      // the background and exited, so it's safe to remove the temp dir here.
      unawaited(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }());
    }
  }

  static Future<bool> _elevateLinux(String executable, List<String> args) async {
    // Try pkexec first (PolicyKit), fall back to gksudo/kdesudo
    final elevators = ['pkexec', 'gksudo', 'kdesudo', 'sudo'];

    for (final elevator in elevators) {
      try {
        final which = await Process.run('which', [elevator]);
        if (which.exitCode != 0) continue;

        final process = await Process.start(
          elevator,
          [executable, ...args],
        );

        // Process.start returns as soon as the child is spawned; the
        // relaunched app is long-running, so we can't just await exitCode
        // like the sync elevation paths do. Instead, race a short window:
        // pkexec exits 126 immediately if the user cancels the auth dialog
        // and 127 if authentication itself fails, so a quick non-zero exit
        // is a reliable "declined" signal. If nothing has happened after
        // the window, assume the elevated relaunch is up and running.
        final exitCode = await process.exitCode
            .timeout(const Duration(seconds: 2), onTimeout: () => 0);
        if (exitCode != 0) {
          // A fast non-zero exit means the user cancelled/declined the
          // prompt (or auth failed), not that this elevator is missing.
          // Report failure rather than silently trying the next one, so
          // the caller shows the elevation-required dialog instead of
          // treating this as "elevation started" and exiting the app.
          debugPrint('Elevation: $elevator exited $exitCode within window, treating as declined');
          return false;
        }
        // Still running after the window: assume the elevated relaunch is
        // up and the caller should exit.
        return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Run a command with elevation (for cases where we need to run
  /// individual elevated commands rather than the whole app).
  static Future<ProcessResult> runElevated(
    String command,
    List<String> args, {
    String? workingDirectory,
  }) async {
    if (await isElevated()) {
      // Already elevated, run directly
      return Process.run(command, args, workingDirectory: workingDirectory);
    }

    if (Platform.isWindows) {
      // Use PowerShell with RunAs
      final fullCommand = [command, ...args].join(' ');
      return Process.run(
        'powershell',
        [
          '-Command',
          "Start-Process -FilePath 'cmd' -ArgumentList '/c $fullCommand' -Verb RunAs -Wait",
        ],
        workingDirectory: workingDirectory,
        runInShell: true,
      );
    } else {
      // Unix: use sudo
      return Process.run('sudo', [command, ...args], workingDirectory: workingDirectory);
    }
  }
}

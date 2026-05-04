import 'dart:io';

import 'package:flutter/foundation.dart';

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
    // The script logs to /tmp for debugging and does NOT use exec (so & works).
    final launcher = File('/tmp/librescoot-elevate.sh');
    final argLine = args.map((a) => "'${a.replaceAll("'", "'\\''")}'").join(' ');
    // The launcher script MUST exit immediately. do shell script waits for it.
    // Only launch the app in background and exit: nothing else.
    await launcher.writeAsString(
      '#!/bin/sh\n'
      '\'${executable.replaceAll("'", "'\\''")}\' $argLine >> /tmp/librescoot-elevate.log 2>&1 &\n',
    );
    await Process.run('chmod', ['+x', launcher.path]);

    try {
      final result = await Process.run('osascript', [
        '-e',
        'do shell script "/tmp/librescoot-elevate.sh" with administrator privileges',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _elevateLinux(String executable, List<String> args) async {
    // Try pkexec first (PolicyKit), fall back to gksudo/kdesudo
    final elevators = ['pkexec', 'gksudo', 'kdesudo', 'sudo'];

    for (final elevator in elevators) {
      try {
        final which = await Process.run('which', [elevator]);
        if (which.exitCode == 0) {
          await Process.start(
            elevator,
            [executable, ...args],
          );
          // Started successfully, caller should exit
          return true;
        }
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

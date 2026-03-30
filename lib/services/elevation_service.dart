import 'dart:io';

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
    // Use PowerShell Start-Process with -Verb RunAs for UAC elevation
    final escapedExe = executable.replaceAll("'", "''");
    final escapedArgs = args.map((a) => a.replaceAll("'", "''")).join(' ');

    try {
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          "Start-Process -FilePath '$escapedExe' -ArgumentList '$escapedArgs' -Verb RunAs",
        ],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _elevateMacOS(String executable, List<String> args) async {
    // Write a launcher script to avoid all shell quoting issues with osascript.
    final launcher = File('/tmp/librescoot-elevate.sh');
    final argLine = args.map((a) => "'${a.replaceAll("'", "'\\''")}'").join(' ');
    await launcher.writeAsString(
      '#!/bin/sh\n'
      'exec \'${executable.replaceAll("'", "'\\''")}\' $argLine\n',
    );
    await Process.run('chmod', ['+x', launcher.path]);

    try {
      // osascript prompts for password. The & backgrounds the launcher so
      // do shell script returns immediately after auth succeeds.
      final result = await Process.run('osascript', [
        '-e',
        'do shell script "/tmp/librescoot-elevate.sh >/dev/null 2>&1 &" with administrator privileges',
      ]);
      launcher.delete().ignore();
      return result.exitCode == 0;
    } catch (_) {
      launcher.delete().ignore();
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

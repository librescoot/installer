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
    // Use osascript to request admin privileges via GUI dialog.
    // We use 'open -a' to launch the app bundle as a new process, then exit this one.
    // If running from a .app bundle, use the bundle path. Otherwise fall back to direct execution.
    final escapedExe = executable.replaceAll("'", "'\\''");
    final escapedArgs = args.map((a) => "'${a.replaceAll("'", "'\\''")}'").join(' ');

    try {
      // Launch elevated process in background, return immediately
      final script = "do shell script \"'$escapedExe' $escapedArgs &\" with administrator privileges";
      await Process.start('osascript', ['-e', script]);
      // Don't wait for osascript to finish — the caller will exit(0)
      // Give osascript a moment to show the dialog
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
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

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

  /// Quote a single argument the way CommandLineToArgvW expects.
  ///
  /// Start-Process joins its -ArgumentList with spaces and adds no quoting of
  /// its own, so an argument holding a space (the log file under "Librescoot
  /// Installer", an image picked out of a folder with a space in its name)
  /// would otherwise reach the elevated child as two arguments.
  @visibleForTesting
  static String quoteWindowsArg(String arg) {
    if (!arg.contains(' ') && !arg.contains('\t') && !arg.contains('"')) {
      return arg;
    }
    final buffer = StringBuffer('"');
    var backslashes = 0;
    for (final unit in arg.codeUnits) {
      if (unit == 0x5C) {
        backslashes++;
        continue;
      }
      if (unit == 0x22) {
        // Backslashes in front of a quote are doubled, then the quote escaped.
        buffer.write('\\' * (backslashes * 2 + 1));
        backslashes = 0;
        buffer.writeCharCode(unit);
        continue;
      }
      buffer.write('\\' * backslashes);
      backslashes = 0;
      buffer.writeCharCode(unit);
    }
    // A trailing backslash run would otherwise escape the closing quote.
    buffer.write('\\' * (backslashes * 2));
    buffer.write('"');
    return buffer.toString();
  }

  static Future<bool> _elevateWindows(String executable, List<String> args) async {
    // Use PowerShell Start-Process with -Verb RunAs for UAC elevation.
    // ArgumentList wants an array of strings, so build a real PowerShell
    // array literal rather than one space-separated string, which lets the
    // executable path be resolved before -Verb RunAs hands off to
    // ShellExecuteEx.
    String psQuote(String s) => "'${s.replaceAll("'", "''")}'";

    // The quotes quoteWindowsArg adds enter the command as $q rather than as
    // literal characters: runInShell routes this through cmd.exe, which counts
    // quotes and knows nothing about the backslash escaping Dart applies to
    // the argument it passes on. With no double quote in the string, cmd.exe
    // sees one clean quoted region and hands it to PowerShell untouched.
    String psEmbed(String token) {
      if (!token.contains('"')) return psQuote(token);
      final parts = token.split('"');
      final pieces = <String>[];
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) pieces.add(r'$q');
        if (parts[i].isNotEmpty) pieces.add(psQuote(parts[i]));
      }
      return '(${pieces.join('+')})';
    }

    final psExe = psQuote(executable);
    final psArgArray = args.isEmpty
        ? '@()'
        : '@(${args.map((a) => psEmbed(quoteWindowsArg(a))).join(',')})';
    final psCmd =
        r'$q=[char]34; '
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

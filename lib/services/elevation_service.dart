import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class RootInvocation {
  final List<String> argv;
  final Map<String, String> environment;

  const RootInvocation(this.argv, this.environment);

  bool get isDirect => argv.isEmpty;
}

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
      if (result.exitCode == 0) {
        return result.stdout.toString().trim() == '0';
      }
    } catch (_) {
    }
    try {
      final status = await File('/proc/self/status').readAsString();
      final uid = RegExp(r'^Uid:\s*(\d+)', multiLine: true).firstMatch(status);
      if (uid != null) return uid.group(1) == '0';
    } catch (_) {
    }
    return false;
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

  static Future<bool> hasCommand(String name) async {
    final pathEnv = Platform.environment['PATH'] ??
        '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin';
    for (final dir in pathEnv.split(':')) {
      if (dir.isEmpty) continue;
      if (await File(path.join(dir, name)).exists()) return true;
    }
    return false;
  }

  static Future<RootInvocation?> linuxRootPrefix({
    Future<bool> Function()? isRoot,
    Future<bool> Function(String name)? hasCommandOverride,
    Future<String?> Function()? findAskpass,
  }) async {
    final rootCheck = isRoot ?? _isUnixRoot;
    final have = hasCommandOverride ?? hasCommand;
    final askpassFor = findAskpass ?? _findLinuxAskpass;
    if (await rootCheck()) return const RootInvocation([], {});
    if (await have('pkexec')) {
      return const RootInvocation(['pkexec'], {});
    }
    if (await have('sudo')) {
      final askpass = await askpassFor();
      if (askpass != null) {
        return RootInvocation(const ['sudo', '-A'], {
          'SUDO_ASKPASS': askpass,
        });
      }
    }
    return null;
  }

  static String macOsAskpassScript(String reason) => '#!/bin/sh\n'
      'osascript'
      ' -e \'display dialog "Librescoot Installer needs your administrator'
      ' password $reason." with title "Librescoot Installer"'
      ' default answer "" with hidden answer with icon caution\''
      ' -e \'text returned of result\'\n';

  static final Map<String, Future<String?>> _macOsAskpass = {};

  static Future<String?> macOsAskpassPath(String reason) {
    return _macOsAskpass.putIfAbsent(reason, () async {
      try {
        final dir =
            await Directory.systemTemp.createTemp('librescoot_askpass_');
        final script = File(path.join(dir.path, 'askpass.sh'));
        await script.writeAsString(macOsAskpassScript(reason));
        await Process.run('chmod', ['0700', script.path]);
        return script.path;
      } catch (e) {
        debugPrint('Elevation: could not write the askpass helper ($e)');
        return null;
      }
    });
  }

  static Future<RootInvocation?> macOSRootPrefix(String reason) async {
    if (await _isUnixRoot()) return const RootInvocation([], {});
    if (!await hasCommand('sudo')) return null;
    final askpass = await macOsAskpassPath(reason);
    if (askpass == null) return null;
    return RootInvocation(const ['sudo', '-A'], {'SUDO_ASKPASS': askpass});
  }

  static Future<String?> _findLinuxAskpass() async {
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

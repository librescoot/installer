import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef ProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

/// Runs one command at a time from the log dialog's debug shell.
///
/// The command runs in the platform shell with stdin closed, so nothing it
/// starts can wait on input. Output reaches [appendLine] as it is produced,
/// and [stop] ends the process; the process itself is never awaited by the
/// UI, so a command that runs long or forever leaves the dialog usable.
class DebugShell extends ChangeNotifier {
  DebugShell({required this.appendLine, ProcessStarter? starter})
    : _starter = starter ?? Process.start;

  final void Function(String line) appendLine;
  final ProcessStarter _starter;

  Process? _process;
  Future<void>? _finished;

  bool get running => _process != null;

  /// The shell invocation for [command] on this platform.
  static List<String> shellCommand(String command, {bool? windows}) {
    if (windows ?? Platform.isWindows) return ['cmd.exe', '/c', command];
    return ['/bin/sh', '-c', command];
  }

  /// Starts [command]. Returns false, without starting anything, while a
  /// previous command is still running.
  Future<bool> run(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return false;
    if (_process != null) return false;

    appendLine('> $trimmed');
    final argv = shellCommand(trimmed);
    final Process process;
    try {
      process = await _starter(argv.first, argv.sublist(1));
    } catch (e) {
      appendLine('error: $e');
      return false;
    }
    _process = process;
    notifyListeners();

    // Anything reading stdin sees EOF at once instead of waiting forever.
    unawaited(process.stdin.close().catchError((_) {}));

    final done = Future.wait([
      _forward(process.stdout, ''),
      _forward(process.stderr, 'stderr: '),
    ]);
    _finished = () async {
      final code = await process.exitCode;
      // A child the command left behind keeps the pipes open; do not wait on
      // it past a short grace for the last lines to drain.
      await done.timeout(const Duration(seconds: 1), onTimeout: () => []);
      appendLine('exit: $code');
      if (identical(_process, process)) _process = null;
      notifyListeners();
    }();
    return true;
  }

  Future<void> _forward(Stream<List<int>> stream, String prefix) {
    return stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => appendLine('$prefix$line'));
  }

  /// Ends the running command. Asks politely first; if the process is still
  /// there two seconds later it is killed outright.
  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    appendLine('stopping...');
    process.kill(ProcessSignal.sigterm);
    final finished = _finished;
    if (finished == null) return;
    final escalate = Timer(const Duration(seconds: 2), () {
      if (identical(_process, process)) process.kill(ProcessSignal.sigkill);
    });
    try {
      await finished;
    } finally {
      escalate.cancel();
    }
  }

  /// Completes once the running command, if any, has exited.
  Future<void> get finished => _finished ?? Future.value();
}

/// [running] is a verdict in its own right, not a shade of success: the
/// trampoline writes it before the MDB reboot that starts the dashboard work,
/// so a laptop that reads it is looking at a job that has not finished. It
/// used to parse as success, which told an impatient user their dashboard was
/// installed while the board it was about to be written to was still booting.
enum TrampolineResult { success, running, error, unknown }

class InstallRunState {
  InstallRunState({
    required this.runId,
    required this.actor,
    required this.stage,
    required this.result,
    required this.finishState,
  });

  final String? runId;
  final String? actor;
  final String? stage;
  final TrampolineResult result;
  final String? finishState;

  factory InstallRunState.parse(String content) {
    final fields = <String, String>{};
    for (final line in content.split('\n')) {
      final separator = line.indexOf(':');
      if (separator < 1) continue;
      final value = line.substring(separator + 1).trim();
      if (value.isNotEmpty) {
        fields[line.substring(0, separator).trim()] = value;
      }
    }
    final result = switch (fields['result']?.toLowerCase()) {
      'success' => TrampolineResult.success,
      'running' => TrampolineResult.running,
      'error' => TrampolineResult.error,
      _ => TrampolineResult.unknown,
    };
    return InstallRunState(
      runId: fields['run-id'],
      actor: fields['actor'],
      stage: fields['stage'],
      result: result,
      finishState: fields['finish'],
    );
  }

  TrampolineStatus toTrampolineStatus() => TrampolineStatus(
        result: result,
        runId: runId,
        finishState: finishState,
        stage: stage,
        message: stage,
      );
}

class TrampolineStatus {
  TrampolineStatus({
    required this.result,
    this.message,
    this.errorLog,
    this.mode,
    this.mdbVersion,
    this.dbcVersion,
    this.runId,
    this.finishState,
    this.stage,
  });

  final TrampolineResult result;
  final String? message;
  final String? errorLog;

  /// `flash` or `upgrade`, written by the trampoline from its own mode.
  /// Null on a status file written before this existed, and on the
  /// tiles-only paths that still write a bare verdict.
  final String? mode;
  final String? mdbVersion;
  final String? dbcVersion;
  final String? runId;
  final String? finishState;
  final String? stage;

  bool completedFor(String expectedRunId) =>
      result == TrampolineResult.success &&
      runId == expectedRunId &&
      finishState == 'complete';

  factory TrampolineStatus.parse(String content) {
    final lines = content.trim().split('\n');
    if (lines.isEmpty) return TrampolineStatus(result: TrampolineResult.unknown);

    // The verdict is the first line and nothing else; the trampoline appends
    // its log after these fields, so scan the tail for `key: value`.
    String? field(String key) {
      for (final line in lines.skip(1)) {
        final trimmed = line.trim();
        if (trimmed.startsWith('$key: ')) {
          return trimmed.substring(key.length + 2).trim();
        }
      }
      return null;
    }

    final resultLine = lines.first.trim().toLowerCase();
    if (resultLine == 'success') {
      return TrampolineStatus(
        result: TrampolineResult.success,
        message: lines.length > 1 ? lines.sublist(1).join('\n') : null,
        mode: field('mode'),
        mdbVersion: field('mdb'),
        dbcVersion: field('dbc'),
        runId: field('run-id'),
        finishState: field('finish'),
        stage: field('stage'),
      );
    } else if (resultLine == 'running' || resultLine == 'rebooting') {
      // `rebooting` is what older trampolines wrote at the same point.
      return TrampolineStatus(
        result: TrampolineResult.running,
        message: lines.length > 1 ? lines.sublist(1).join('\n') : null,
        mode: field('mode'),
        mdbVersion: field('mdb'),
        dbcVersion: field('dbc'),
        runId: field('run-id'),
        finishState: field('finish'),
        stage: field('stage'),
      );
    } else if (resultLine.startsWith('error')) {
      return TrampolineStatus(
        result: TrampolineResult.error,
        message: resultLine,
        errorLog: lines.length > 1 ? lines.sublist(1).join('\n') : null,
        mode: field('mode'),
        mdbVersion: field('mdb'),
        dbcVersion: field('dbc'),
        runId: field('run-id'),
        finishState: field('finish'),
        stage: field('stage'),
      );
    }
    return TrampolineStatus(result: TrampolineResult.unknown, message: content);
  }

  static TrampolineStatus parseCompletionRecord(String content) {
    return TrampolineStatus.parse(
      content.replaceFirst(RegExp(r'^result:\s*'), ''),
    );
  }
}

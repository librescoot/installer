import '../models/trampoline_status.dart';

typedef InstallLogCommand = Future<String> Function(String command);

class PreviousInstallFailure {
  const PreviousInstallFailure({
    required this.reason,
    required this.logTail,
    this.runId,
  });

  final String reason;
  final String logTail;
  final String? runId;
}

Future<PreviousInstallFailure?> probePreviousInstallFailure(
  InstallLogCommand runCommand,
) async {
  final statusText = await runCommand(
    'cat /data/installer/trampoline-status 2>/dev/null; true',
  );
  final stateText = await runCommand(
    'cat /data/installer/run-state 2>/dev/null || '
    'cat /data/installer-run-state 2>/dev/null; true',
  );
  final completedText = await runCommand(
    'cat /data/installer/last-install 2>/dev/null || '
    'cat /data/last-install 2>/dev/null; true',
  );
  final status = statusText.trim().isEmpty
      ? null
      : TrampolineStatus.parse(statusText);
  final state = stateText.trim().isEmpty
      ? null
      : InstallRunState.parse(stateText);
  final completed = completedText.trim().isEmpty
      ? null
      : InstallRunState.parse(completedText);

  String? runId;
  String? reason;
  if (state?.result == TrampolineResult.error) {
    runId = state?.runId;
    reason = status?.result == TrampolineResult.error && status?.runId == runId
        ? status!.message
        : state?.stage ?? 'error';
  } else if (status?.result == TrampolineResult.error &&
      (state?.runId == null ||
          status?.runId == null ||
          state?.runId == status?.runId) &&
      state?.result != TrampolineResult.success) {
    runId = status?.runId;
    reason = status?.message;
  }
  if (reason == null ||
      (runId != null &&
          completed?.result == TrampolineResult.success &&
          completed?.runId == runId)) {
    return null;
  }

  final safeId = runId != null && RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(runId);
  final currentLog = await runCommand(
    'tail -c 16384 /data/installer/trampoline.log 2>/dev/null; true',
  );
  final archivedLog = safeId
      ? await runCommand(
          'tail -c 16384 /data/installer/history/$runId/trampoline.log '
          '2>/dev/null; true',
        )
      : '';
  return PreviousInstallFailure(
    reason: reason,
    logTail:
        (status?.result == TrampolineResult.error && status?.runId == runId
                ? (currentLog.trim().isNotEmpty ? currentLog : archivedLog)
                : (archivedLog.trim().isNotEmpty ? archivedLog : currentLog))
            .trimRight(),
    runId: runId,
  );
}

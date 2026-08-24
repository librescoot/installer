import 'trampoline_status.dart';

/// What a set of leftovers on the board means for the session about to start.
enum ResumeVerdict {
  /// Nothing was left behind: a normal first run.
  none,

  /// A run is still going on the board. Its files must be left alone: the
  /// services this installer would unmask and the error signals it would
  /// clear are the running trampoline's, not stale.
  running,

  /// A run that stopped without reaching a verdict, or reached a failing one.
  unfinished,

  /// A finished run whose files were never swept. Reported, not resumed:
  /// treating it as damage announced an interrupted install on a healthy
  /// scooter, with no error to explain it.
  completed,
}

ResumeVerdict resumeVerdict({
  required bool leftoversPresent,
  required TrampolineResult result,
  required bool trampolineAlive,
}) {
  if (trampolineAlive) return ResumeVerdict.running;
  if (!leftoversPresent) return ResumeVerdict.none;
  if (result == TrampolineResult.success) return ResumeVerdict.completed;
  return ResumeVerdict.unfinished;
}

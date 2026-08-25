import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/resume_state.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';

/// Reconnecting to a board that has been through an install has to tell three
/// situations apart, and the cost of confusing them is high: clearing the
/// leftovers of a live run breaks it, and resuming a healthy scooter tells the
/// owner their install failed when it did not.
void main() {
  ResumeVerdict verdict({
    bool leftovers = true,
    TrampolineResult result = TrampolineResult.error,
    bool alive = false,
  }) =>
      resumeVerdict(
        leftoversPresent: leftovers,
        result: result,
        trampolineAlive: alive,
      );

  test('a live trampoline outranks whatever the files say', () {
    // The status file still holds the previous verdict while the next run is
    // in its first seconds. Acting on it would clear a running install.
    for (final r in TrampolineResult.values) {
      expect(verdict(result: r, alive: true), ResumeVerdict.running,
          reason: '$r');
    }
  });

  test('a clean board is a first run', () {
    expect(verdict(leftovers: false, result: TrampolineResult.unknown),
        ResumeVerdict.none);
  });

  test('leftovers from a run that succeeded are only reported', () {
    expect(verdict(result: TrampolineResult.success), ResumeVerdict.completed);
  });

  test('anything else counts as unfinished', () {
    expect(verdict(result: TrampolineResult.error), ResumeVerdict.unfinished);
    expect(verdict(result: TrampolineResult.running), ResumeVerdict.unfinished);
    expect(verdict(result: TrampolineResult.unknown), ResumeVerdict.unfinished);
  });
}

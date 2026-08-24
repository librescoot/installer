/// One step inside a phase that waits on the scooter.
///
/// The typical duration is measured, not guessed: it is what the step took on
/// a healthy board in the runs this was built from. It exists so the overlay
/// can answer the question someone in front of a spinner actually has, which
/// is not "what percent" but "how long, and is this normal".
class WaitStep {
  const WaitStep({required this.label, required this.typical, this.matchPrefix});

  final String label;
  final Duration typical;

  /// For a status that carries a number in it ("Firmware wird installiert
  /// (42 %)"), which never equals a fixed label. The stable part identifies
  /// the step; the rest is progress.
  final String? matchPrefix;

  bool matches(String status) =>
      matchPrefix == null ? status == label : status.startsWith(matchPrefix!);
}

/// How a step is going, which is all the overlay needs to draw it.
enum WaitStepState { done, active, todo }

/// A step that has run past its typical time by this much is called out
/// rather than left sitting at the same place. The moment a wait feels stuck
/// is the moment someone reaches for the cable, so the screen says it first.
const Duration kWaitOverdueGrace = Duration(seconds: 20);

bool waitStepIsOverdue(Duration elapsed, Duration typical) =>
    elapsed > typical + kWaitOverdueGrace;

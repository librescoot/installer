/// How long ten stable pings take on a healthy board after a flash.
///
/// Measured, like every other typical here: the gadget is back on the bus at
/// about +10s, the board's network starts answering at ~+114s, and the tenth
/// consecutive ping lands at ~+132s.
///
/// Those are measured from the reboot, but the wait starts when the user says
/// they made the gesture, and the board takes about ten seconds to act on it.
const stableConnectionTypical = Duration(seconds: 145);

/// When waiting for that connection stops being normal and is worth a hint
/// naming likely causes.
///
/// Comfortably past [stableConnectionTypical] rather than close to it. The
/// hint blames the host's network stack, which is a real cause but not the
/// usual one: the usual one is the board still bringing usb0 up. A threshold
/// inside the normal range therefore accuses NetworkManager on a healthy run.
///
/// This has now been too low twice. It first counted loop iterations rather
/// than seconds, so it fired at about 27s. It was then 90s, which a healthy
/// board beat on a run whose carrier was slower than usual: the hint appeared,
/// and the same run recovered on its own half a minute later and finished
/// clean without anyone touching it.
const stableConnectionStallAfter = Duration(seconds: 250);

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

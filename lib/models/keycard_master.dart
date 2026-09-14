/// Whether the installer should send the command that disengages boot-time
/// auto-master-learning.
///
/// `set-master:NONE` is the only command that clears keycard-service's
/// masterLearningMode, but it is destructive: SetMaster replaces the whole
/// master list with the NONE sentinel and persists it. Sent to a board that
/// already has a master it erases a registration the owner made, which is what
/// an upgrade did to a user's card.
///
/// The asymmetry that makes this decidable: keycard-service only arms
/// masterLearningMode at startup when it has no master, so a board with one
/// never needed the command. It is only ever useful where it destroys nothing.
///
/// [masterCount] comes from keycard-service's own published count, which
/// excludes the NONE sentinel. A board carrying only the sentinel therefore
/// reads as zero and has it rewritten, which costs nothing.
///
/// Null is a count nobody could read, not a board with no cards. Staying quiet
/// there risks the next tap being learned as master on a board with none, which
/// is recoverable and is what the operator is at the reader to do anyway.
/// Sending costs a card that cannot be got back.
bool shouldDisengageMasterLearning(int? masterCount) => masterCount == 0;

bool ownsKeycardMasterStart({
  required int startGeneration,
  required int currentGeneration,
  required int? ownerGeneration,
  required bool mounted,
  required bool windowClosing,
  required bool inKeycardPhase,
  required bool masterStage,
}) =>
    mounted &&
    !windowClosing &&
    inKeycardPhase &&
    masterStage &&
    startGeneration == currentGeneration &&
    ownerGeneration == startGeneration;

bool ownsKeycardMasterEvent({
  required int eventGeneration,
  required int currentGeneration,
  required int? ownerGeneration,
  required bool mounted,
  required bool windowClosing,
  required bool inKeycardPhase,
  required bool masterStage,
}) =>
    mounted &&
    !windowClosing &&
    inKeycardPhase &&
    masterStage &&
    eventGeneration == currentGeneration &&
    ownerGeneration == eventGeneration;

/// What the installer does with keycard-service's answer to `learn:start`.
enum LearnStartOutcome {
  /// The service is in learn mode, taps will arrive as events.
  started,

  /// The service refused because it is still waiting to crown the next tap
  /// as master. Only builds before the command fix answer this, and they
  /// answer it exactly when no master is stored, so disengaging with
  /// `set-master:NONE` and asking again destroys nothing.
  disengageMasterAndRetry,

  /// Anything else, including silence: showing a learning screen over a
  /// service that is not learning is how a tap ends up somewhere the owner
  /// did not put it.
  failed,
}

LearnStartOutcome learnStartOutcome(String? result) {
  switch (result?.trim().toLowerCase()) {
    case 'ok':
    // The service got there before the command did: a master tap enters
    // learn mode by itself, and a session already running is the goal.
    case 'error:already in learn mode':
      return LearnStartOutcome.started;
    case 'error:in master learning mode':
      return LearnStartOutcome.disengageMasterAndRetry;
    default:
      return LearnStartOutcome.failed;
  }
}

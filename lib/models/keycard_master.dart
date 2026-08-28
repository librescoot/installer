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

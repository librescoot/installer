/// What the board's keycard-service can do, as three answers rather than two.
///
/// [unreachable] is nobody answering the probe at all. The reader is on the
/// dashboard's front panel, so a board with no dashboard reachable has no
/// reader, which is a different thing from an old service that does not
/// understand the new commands.
enum KeycardCapability { current, legacy, unreachable }

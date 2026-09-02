/// What the board's keycard-service can do, as three answers rather than two.
///
/// [unreachable] is nobody answering the probe at all. The reader is on the
/// dashboard's front panel, so a board with no dashboard reachable has no
/// reader, which is a different thing from an old service that does not
/// understand the new commands.
///
/// [noReader] is a service that answers but has no PN7150 to talk to. It
/// keeps serving commands while it retries the chip in the background, so
/// every probe looks healthy; the only sign is the fault it raises.
enum KeycardCapability { current, legacy, unreachable, noReader }

/// keycard-service raises this into the `keycard:fault` set while it cannot
/// open or initialise the reader, and clears it once polling starts.
const String keycardNfcUnavailableFault = '1';

/// Whether the members of `keycard:fault`, as `redis-cli SMEMBERS` prints
/// them, say the reader is missing.
bool keycardReaderMissing(String smembers) => smembers
    .split(RegExp(r'\s+'))
    .map((code) => code.trim())
    .contains(keycardNfcUnavailableFault);

/// The two computers on the vehicle. [name] is `mdb` / `dbc`, which is also
/// the directory component in `/data/ota/<board>/` and the token in the
/// release asset names.
enum Board { mdb, dbc }

/// How a board's state was learned. The DBC is never reachable while the
/// installer is plugged in, so its version can only ever be last-seen.
enum StateProvenance { live, lastSeen, unknown }

class BoardState {
  const BoardState({
    required this.board,
    required this.isLibrescoot,
    required this.provenance,
    this.version,
    this.artifactName,
    this.hasMender = false,
    this.isMinimalImage = false,
  });

  final Board board;
  final bool isLibrescoot;
  final StateProvenance provenance;

  /// VERSION_ID from /etc/os-release, or the last-seen value from the MDB's
  /// `version:dbc` hash. Null when nothing is known.
  final String? version;

  /// `mender-update show-artifact`, when it could be read.
  final String? artifactName;

  /// A usable `mender-update` was found on the board.
  final bool hasMender;

  /// The board is running a stage-0 bootstrap image: same distro, same
  /// os-release ID, but no service stack. Expected between a stage-0 write
  /// and the artifact's reboot, and a recoverable leftover otherwise.
  final bool isMinimalImage;

  static const unknown = BoardState(
    board: Board.dbc,
    isLibrescoot: false,
    provenance: StateProvenance.unknown,
  );
}

/// Whether a board should be treated as still running a bootstrap image.
///
/// The artifact name is the authority: a stage-0 image carries "minimal" in
/// it. The service-stack probe only overrules that when it actually answered,
/// because a board that could not be asked is not a board that said no.
bool looksLikeBootstrapImage({
  required String? artifactName,
  required bool? hasServiceStack,
}) =>
    (artifactName ?? '').contains('minimal') || hasServiceStack == false;

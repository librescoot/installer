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

/// Which vehicle stack a board is running.
///
/// [stock] and [none] both lack the Librescoot units, and only [none] is a
/// board with something wrong with it.
enum ServiceStack {
  /// Librescoot's own units are installed. Every redis-backed step here works.
  librescoot,

  /// The stock vehicle stack, under its own unit and key names. Healthy, and
  /// the ordinary starting point for an install.
  stock,

  /// No vehicle stack under any known name: a stage-0 bootstrap image, or a
  /// full image that did not come up.
  none,
}

/// Whether a board should be treated as still running a bootstrap image.
///
/// The artifact name is the authority in both directions. mender reports which
/// image is actually running: a name carrying "minimal" is a stage-0 board, and
/// a name that does not is a board that took the artifact. The stack probe is
/// weaker evidence than that, since a stack can be absent for reasons other
/// than the image, so it only decides the case when mender said nothing.
///
/// That asymmetry is the point. A board can boot its new rootfs and still be
/// bringing systemd up, so the probe finds no vehicle unit on an image that
/// plainly has one. Letting the probe outvote the artifact name reported an
/// installed, committed, running artifact as a failed install, and offered to
/// rewrite the eMMC to fix it.
bool looksLikeBootstrapImage({
  required String? artifactName,
  required ServiceStack? serviceStack,
}) {
  final name = artifactName ?? '';
  if (name.isNotEmpty) return name.contains('minimal');
  return serviceStack == ServiceStack.none;
}

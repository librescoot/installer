/// Why the connect phase could not reach the main board, in terms the person
/// standing over the scooter can act on.
///
/// The exception behind each of these reads the same to whoever is holding
/// the screwdriver: a cable that was never plugged in and a board that
/// rebooted mid-handshake both surface as a socket error. Naming the kind is
/// what lets the screen carry a next step instead of a stack trace.
enum ConnectFailureKind {
  /// Nothing has enumerated on USB at all. The cable is not in, it is not a
  /// data cable, or the scooter has no power.
  noUsbDevice,

  /// A device was on the bus and went away. The board slept or restarted, or
  /// the cable moved.
  deviceVanished,

  /// EHOSTUNREACH on macOS, where the board answers pings and the app is
  /// still not allowed to reach it: Local Network permission.
  localNetworkBlocked,

  /// EHOSTUNREACH anywhere else, which is the host having no route to the
  /// board because the address never made it onto the interface.
  noRoute,

  /// The board sent a rejection back. The link works, sshd is not up yet.
  sshRefused,

  /// Nothing came back before the connect timeout.
  sshTimeout,

  /// The link went away between the socket and the end of authentication.
  linkDropped,

  /// Every credential the installer has was turned down.
  authRejected,

  /// Something the installer has no advice for.
  unknown,
}

/// A connect attempt that stopped, with the raw text underneath it.
class ConnectFailure {
  const ConnectFailure({required this.kind, this.details = ''});

  final ConnectFailureKind kind;

  /// The exception and its context, untranslated on purpose: it gets pasted
  /// verbatim to someone who may not read the reporter's language.
  final String details;

  /// Whether the installer is still watching for the condition to clear.
  /// These two fix themselves the moment the user acts, so the screen says so
  /// rather than offering a retry that changes nothing.
  bool get selfHealing =>
      kind == ConnectFailureKind.noUsbDevice ||
      kind == ConnectFailureKind.localNetworkBlocked;
}


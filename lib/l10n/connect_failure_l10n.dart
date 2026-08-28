import 'app_localizations.dart';
import '../models/connect_failure.dart';

/// What the connect screen says for each way the connect can fail.
///
/// Out here rather than inside the screen so both languages can be checked
/// against every kind of the enum, which is the assertion that catches a kind
/// added later with no wording behind it.
extension ConnectFailureL10n on ConnectFailureKind {
  /// The diagnosis, and the phase title: it is the one thing on the screen
  /// the user has to read.
  String heading(AppLocalizations l10n) => switch (this) {
        ConnectFailureKind.noUsbDevice => l10n.connectFailedNoDeviceHeading,
        ConnectFailureKind.deviceVanished =>
          l10n.connectFailedDeviceVanishedHeading,
        // The macOS permission keeps the wording it already has: it is the
        // only failure here where the board is demonstrably fine and the host
        // is the thing saying no.
        ConnectFailureKind.localNetworkBlocked => l10n.macosNoRouteHeading,
        ConnectFailureKind.noRoute => l10n.connectFailedNoRouteHeading,
        ConnectFailureKind.sshRefused => l10n.connectFailedRefusedHeading,
        ConnectFailureKind.sshTimeout => l10n.connectFailedTimeoutHeading,
        ConnectFailureKind.linkDropped => l10n.connectFailedDroppedHeading,
        ConnectFailureKind.authRejected => l10n.connectFailedAuthHeading,
        ConnectFailureKind.unknown => l10n.connectFailedUnknownHeading,
      };

  /// What happened and what to check, as one message carrying its own bullet
  /// list, the way the pre-install notices do.
  String body(AppLocalizations l10n) => switch (this) {
        ConnectFailureKind.noUsbDevice => l10n.connectFailedNoDeviceBody,
        ConnectFailureKind.deviceVanished =>
          l10n.connectFailedDeviceVanishedBody,
        ConnectFailureKind.localNetworkBlocked => l10n.macosNoRouteBody,
        ConnectFailureKind.noRoute => l10n.connectFailedNoRouteBody,
        ConnectFailureKind.sshRefused => l10n.connectFailedRefusedBody,
        ConnectFailureKind.sshTimeout => l10n.connectFailedTimeoutBody,
        ConnectFailureKind.linkDropped => l10n.connectFailedDroppedBody,
        ConnectFailureKind.authRejected => l10n.connectFailedAuthBody,
        ConnectFailureKind.unknown => l10n.connectFailedUnknownBody,
      };
}

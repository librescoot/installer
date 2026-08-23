import 'board_state.dart';

/// What the installer will do to one board.
enum BoardAction {
  /// Apply the .mender in place. Keeps /data.
  upgrade,

  /// Write the minimal stage-0 image, then apply the .mender. Erases /data.
  cleanInstall,

  /// Touch nothing.
  leave,

  /// Write the full sdimg the old way. Not offered on the plan screen; only
  /// reachable from a failure, and the one action that needs a download the
  /// plan did not already queue.
  fullImage,
}

/// Why [BoardAction.upgrade] is not on offer for a board.
enum UpgradeBlocker { notLibrescoot, stateUnknown, minimalImage, noMender }

class BoardPlan {
  const BoardPlan({required this.board, required this.action, this.blocker});

  final Board board;
  final BoardAction action;
  final UpgradeBlocker? blocker;

  bool get canUpgrade => blocker == null;

  BoardPlan withAction(BoardAction action) =>
      BoardPlan(board: board, action: action, blocker: blocker);
}

class InstallPlan {
  const InstallPlan({
    required this.mdb,
    required this.dbc,
    this.installTiles = false,
  });

  final BoardPlan mdb;
  final BoardPlan dbc;
  final bool installTiles;

  bool get needsMdbWork => mdb.action != BoardAction.leave;
  bool get needsDbcWork => dbc.action != BoardAction.leave;

  /// Whether the main board still needs the firmware artifact written on top.
  /// A full image already carries it, and a board the user asked us to leave
  /// alone is not ours to write to, so only Upgrade and Clean install qualify.
  bool get needsMdbArtifact =>
      mdb.action == BoardAction.upgrade ||
      mdb.action == BoardAction.cleanInstall;

  /// Stage 0 writes an sdimg through the u-boot UMS path. An upgrade skips it.
  bool get needsMdbStage0 =>
      mdb.action == BoardAction.cleanInstall || mdb.action == BoardAction.fullImage;
  bool get needsDbcStage0 =>
      dbc.action == BoardAction.cleanInstall || dbc.action == BoardAction.fullImage;

  /// Only the MDB can reach the DBC, so any DBC work means the user has to
  /// swap the cable back. Map tiles live on the DBC, so they count too.
  bool get needsHandoff => needsDbcWork || installTiles;

  bool get isNoOp => !needsMdbWork && !needsHandoff;

  /// Whether the dashboard work in this plan cannot be carried out, because
  /// nothing will be able to carry it out.
  ///
  /// The dashboard is only reachable through the MDB, and the script that does
  /// the reaching runs on the MDB: it wants data-server, bmap-writer,
  /// mender-update and a /data partition to stage into, none of which exist on
  /// a stock board. So dashboard work needs an MDB that either already runs
  /// Librescoot or is being given it in this same run. Leaving a stock MDB
  /// alone and asking for the dashboard anyway is a plan that can only fail,
  /// and it fails late, after the cable swap, with the laptop already unplugged.
  bool dbcWorkStrandedOn(BoardState mdbState) =>
      needsHandoff && !needsMdbWork && !mdbState.isLibrescoot;

  InstallPlan withMdb(BoardPlan v) =>
      InstallPlan(mdb: v, dbc: dbc, installTiles: installTiles);
  InstallPlan withDbc(BoardPlan v) =>
      InstallPlan(mdb: mdb, dbc: v, installTiles: installTiles);
  InstallPlan withTiles(bool v) =>
      InstallPlan(mdb: mdb, dbc: dbc, installTiles: v);

  /// Default action for one board. Upgrade when the board runs Librescoot and
  /// the target differs, Leave alone when it already runs the target, Clean
  /// install for anything we cannot upgrade. Any target version is allowed,
  /// including an older one: mender writes the inactive slot either way.
  static BoardPlan defaultPlanFor(BoardState state, String? targetVersion) {
    final blocker = _blockerFor(state);
    if (blocker != null) {
      return BoardPlan(
          board: state.board, action: BoardAction.cleanInstall, blocker: blocker);
    }
    final same = versionsMatch(state.version, targetVersion);
    return BoardPlan(
      board: state.board,
      action: same ? BoardAction.leave : BoardAction.upgrade,
    );
  }

  static InstallPlan defaults({
    required BoardState mdb,
    required BoardState dbc,
    required String? targetVersion,
    bool installTiles = false,
  }) =>
      InstallPlan(
        mdb: defaultPlanFor(mdb, targetVersion),
        dbc: defaultPlanFor(dbc, targetVersion),
        installTiles: installTiles,
      );

  static UpgradeBlocker? _blockerFor(BoardState state) {
    if (state.isMinimalImage) return UpgradeBlocker.minimalImage;

    if (!state.isLibrescoot) {
      if (state.provenance == StateProvenance.unknown) {
        return UpgradeBlocker.stateUnknown;
      }
      return UpgradeBlocker.notLibrescoot;
    }

    if (state.provenance == StateProvenance.unknown ||
        state.version == null ||
        state.version!.isEmpty) {
      return UpgradeBlocker.stateUnknown;
    }
    if (!state.hasMender) return UpgradeBlocker.noMender;
    return null;
  }

  /// A board's `VERSION_ID` and a release tag name the same thing: the image
  /// recipes derive both from `LIBRESCOOT_VERSION`, which is also the version
  /// component of every published asset name. Only the `v` prefix and case
  /// vary between the two spellings.
  static String normalizeVersion(String v) =>
      v.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '');

  /// Which release channel a version string names. Stable releases are bare
  /// semver; the other two carry their channel as a prefix.
  static String? channelOf(String? version) {
    if (version == null) return null;
    final v = normalizeVersion(version);
    if (v.isEmpty) return null;
    if (v.startsWith('nightly-')) return 'nightly';
    if (v.startsWith('testing-')) return 'testing';
    if (RegExp(r'^\d+\.\d+').hasMatch(v)) return 'stable';
    return null;
  }

  /// Whether installing [target] over [installed] moves the board backwards or
  /// sideways, which is what makes keeping /data a risk: the services that
  /// wrote it are not the services that will read it.
  ///
  /// Returns null when the two cannot be compared at all, which is not the
  /// same as "safe" - it is answered as a warning by the caller only when a
  /// real mismatch is found, so an unknown pair stays quiet.
  static VersionDirection versionDirection(String? installed, String? target) {
    final a = installed == null ? '' : normalizeVersion(installed);
    final b = target == null ? '' : normalizeVersion(target);
    if (a.isEmpty || b.isEmpty) return VersionDirection.unknown;
    if (a == b) return VersionDirection.same;

    final ca = channelOf(installed);
    final cb = channelOf(target);
    if (ca == null || cb == null) return VersionDirection.unknown;
    if (ca != cb) return VersionDirection.otherChannel;

    if (ca == 'stable') {
      final pa = _semver(a);
      final pb = _semver(b);
      if (pa == null || pb == null) return VersionDirection.unknown;
      for (var i = 0; i < 3; i++) {
        if (pb[i] != pa[i]) {
          return pb[i] > pa[i]
              ? VersionDirection.newer
              : VersionDirection.older;
        }
      }
      return VersionDirection.same;
    }

    // nightly and testing carry a sortable timestamp, so string order is date
    // order for a matching prefix.
    final sa = a.substring(ca.length + 1);
    final sb = b.substring(cb.length + 1);
    if (sa.isEmpty || sb.isEmpty) return VersionDirection.unknown;
    final c = sb.compareTo(sa);
    if (c == 0) return VersionDirection.same;
    return c > 0 ? VersionDirection.newer : VersionDirection.older;
  }

  static List<int>? _semver(String v) {
    final m = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(v);
    if (m == null) return null;
    return [
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3) ?? '0'),
    ];
  }

  /// True when a board is running the version [target] names. Null or empty
  /// on either side is never a match: an unreadable version has to fail the
  /// check rather than pass it by default.
  static bool versionsMatch(String? version, String? target) {
    if (version == null || target == null) return false;
    if (version.trim().isEmpty || target.trim().isEmpty) return false;
    return normalizeVersion(version) == normalizeVersion(target);
  }
}

/// What the trampoline needs in order to finish the job on the device instead
/// of handing back to the laptop.
///
/// Every field is known before the cable swap, which is the whole reason the
/// autonomous finish is possible: the user's choices are made on the plan and
/// welcome screens, long before the laptop is unplugged.
class DeviceFinish {
  const DeviceFinish({
    required this.onDevice,
    required this.mdbAction,
    this.mdbTargetVersion = '',
    this.language = '',
    this.otaChannel = '',
    this.startKeycard = false,
  });

  /// Off means the old behaviour: the trampoline stops at the green LED and
  /// the installer's finish phase does the rest over the laptop link.
  final bool onDevice;

  /// Decides whether the pre-install settings are restored or deliberately
  /// discarded. Only [BoardAction.upgrade] promised to keep them.
  final BoardAction mdbAction;

  /// Recorded in the completion record so a later connect can say what the
  /// last run actually did, rather than guessing from leftover files.
  final String mdbTargetVersion;

  final String language;
  final String otaChannel;

  /// True once keycard pairing has already happened, which is what makes
  /// starting keycard-service on the device safe: a master card exists, so
  /// the service cannot silently teach in the next card that gets tapped.
  final bool startKeycard;

  /// The old behaviour, for callers that still hand back to the laptop.
  static const laptop =
      DeviceFinish(onDevice: false, mdbAction: BoardAction.leave);
}

/// How a target version relates to what a board is already running.
enum VersionDirection {
  newer,
  same,
  /// The target is behind what the board runs, within the same channel.
  older,
  /// A different release channel, so neither is straightforwardly ahead.
  otherChannel,
  unknown,
}

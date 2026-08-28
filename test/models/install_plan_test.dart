import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/install_plan.dart';

BoardState _librescoot(Board board, String version,
        {StateProvenance provenance = StateProvenance.live,
        bool hasMender = true}) =>
    BoardState(
      board: board,
      isLibrescoot: true,
      provenance: provenance,
      version: version,
      hasMender: hasMender,
    );

void main() {
  group('dbcWorkStrandedOn', () {
    const stockMdb = BoardState(
        board: Board.mdb, isLibrescoot: false, provenance: StateProvenance.live);
    const lsMdb = BoardState(
        board: Board.mdb,
        isLibrescoot: true,
        provenance: StateProvenance.live,
        version: 'v1.2.1',
        hasMender: true);
    InstallPlan planOf(BoardAction mdb, BoardAction dbc) => InstallPlan(
          mdb: BoardPlan(board: Board.mdb, action: mdb),
          dbc: BoardPlan(board: Board.dbc, action: dbc),
        );

    test('a stock MDB left alone cannot carry dashboard work', () {
      // The script that reaches the dashboard runs on the MDB and needs
      // Librescoot's tooling and its /data partition. This plan fails after
      // the cable swap, with the laptop already unplugged.
      expect(
        planOf(BoardAction.leave, BoardAction.cleanInstall)
            .dbcWorkStrandedOn(stockMdb),
        isTrue,
      );
    });

    test('installing the MDB in the same run is enough', () {
      expect(
        planOf(BoardAction.cleanInstall, BoardAction.cleanInstall)
            .dbcWorkStrandedOn(stockMdb),
        isFalse,
      );
    });

    test('an MDB already running Librescoot can be left alone', () {
      expect(
        planOf(BoardAction.leave, BoardAction.cleanInstall)
            .dbcWorkStrandedOn(lsMdb),
        isFalse,
      );
    });

    test('no dashboard work is never stranded', () {
      expect(
        planOf(BoardAction.leave, BoardAction.leave).dbcWorkStrandedOn(stockMdb),
        isFalse,
      );
    });

    test('tiles count as dashboard work, since they live there', () {
      final tiles = InstallPlan(
        mdb: const BoardPlan(board: Board.mdb, action: BoardAction.leave),
        dbc: const BoardPlan(board: Board.dbc, action: BoardAction.leave),
        installTiles: true,
      );
      expect(tiles.dbcWorkStrandedOn(stockMdb), isTrue);
    });
  });

  group('defaultPlanFor', () {
    test('offers upgrade when the board runs Librescoot and versions differ', () {
      final plan = InstallPlan.defaultPlanFor(
          _librescoot(Board.mdb, 'v1.2.0'), 'v1.2.1');
      expect(plan.action, BoardAction.upgrade);
      expect(plan.canUpgrade, isTrue);
      expect(plan.blocker, isNull);
    });

    test('leaves the board alone when it already runs the target', () {
      final plan = InstallPlan.defaultPlanFor(
          _librescoot(Board.mdb, 'v1.2.1'), 'v1.2.1');
      expect(plan.action, BoardAction.leave);
      expect(plan.canUpgrade, isTrue,
          reason: 'reinstalling the same version is a legitimate repair');
    });

    test('a stock board can only be clean installed', () {
      const state = BoardState(
        board: Board.dbc,
        isLibrescoot: false,
        provenance: StateProvenance.live,
      );
      final plan = InstallPlan.defaultPlanFor(state, 'v1.2.1');
      expect(plan.action, BoardAction.cleanInstall);
      expect(plan.canUpgrade, isFalse);
      expect(plan.blocker, UpgradeBlocker.notLibrescoot);
    });

    test('an unknown DBC can only be clean installed', () {
      const state = BoardState(
        board: Board.dbc,
        isLibrescoot: false,
        provenance: StateProvenance.unknown,
      );
      final plan = InstallPlan.defaultPlanFor(state, 'v1.2.1');
      expect(plan.action, BoardAction.cleanInstall);
      expect(plan.blocker, UpgradeBlocker.stateUnknown);
    });

    test('a board left on a minimal image is clean installed, not upgraded', () {
      const state = BoardState(
        board: Board.mdb,
        isLibrescoot: true,
        provenance: StateProvenance.live,
        version: 'v1.2.1',
        hasMender: true,
        isMinimalImage: true,
      );
      final plan = InstallPlan.defaultPlanFor(state, 'v1.2.1');
      expect(plan.action, BoardAction.cleanInstall);
      expect(plan.blocker, UpgradeBlocker.minimalImage);
    });

    test('no mender client blocks upgrade with its own reason', () {
      final plan = InstallPlan.defaultPlanFor(
          _librescoot(Board.mdb, 'v1.2.0', hasMender: false), 'v1.2.1');
      expect(plan.action, BoardAction.cleanInstall);
      expect(plan.blocker, UpgradeBlocker.noMender);
    });

    test('a last-seen DBC version is good enough to offer an upgrade', () {
      final plan = InstallPlan.defaultPlanFor(
          _librescoot(Board.dbc, 'v1.2.0',
              provenance: StateProvenance.lastSeen),
          'v1.2.1');
      expect(plan.action, BoardAction.upgrade);
    });

    test('an older target is allowed, mender just writes the other slot', () {
      final plan = InstallPlan.defaultPlanFor(
          _librescoot(Board.mdb, 'v1.2.1'), 'v1.2.0');
      expect(plan.action, BoardAction.upgrade);
    });
  });

  group('InstallPlan', () {
    InstallPlan planOf(BoardAction mdb, BoardAction dbc, {bool tiles = false}) =>
        InstallPlan(
          mdb: BoardPlan(board: Board.mdb, action: mdb),
          dbc: BoardPlan(board: Board.dbc, action: dbc),
          installTiles: tiles,
        );

    test('an upgrade needs no stage 0', () {
      final p = planOf(BoardAction.upgrade, BoardAction.leave);
      expect(p.needsMdbWork, isTrue);
      expect(p.needsMdbStage0, isFalse);
      expect(p.needsHandoff, isFalse);
    });

    test('a clean install needs stage 0', () {
      final p = planOf(BoardAction.cleanInstall, BoardAction.leave);
      expect(p.needsMdbStage0, isTrue);
    });

    test('the legacy full image also needs stage 0', () {
      final p = planOf(BoardAction.fullImage, BoardAction.leave);
      expect(p.needsMdbStage0, isTrue);
    });

    test('any DBC work needs the cable swap', () {
      expect(planOf(BoardAction.leave, BoardAction.upgrade).needsHandoff, isTrue);
      expect(planOf(BoardAction.leave, BoardAction.cleanInstall).needsHandoff, isTrue);
    });

    test('tiles pull in the cable swap even when the DBC is left alone', () {
      final p = planOf(BoardAction.upgrade, BoardAction.leave, tiles: true);
      expect(p.needsDbcWork, isFalse);
      expect(p.needsHandoff, isTrue);
    });

    test('leaving both boards alone with no tiles is a no-op', () {
      expect(planOf(BoardAction.leave, BoardAction.leave).isNoOp, isTrue);
      expect(planOf(BoardAction.leave, BoardAction.leave, tiles: true).isNoOp,
          isFalse);
    });
  });

  group('InstallPlan.versionsMatch', () {
    test('ignores the v prefix and surrounding whitespace', () {
      expect(InstallPlan.versionsMatch('1.2.1', 'v1.2.1'), isTrue);
      expect(InstallPlan.versionsMatch(' v1.2.1 ', '1.2.1'), isTrue);
    });

    test('matches the tag spelling of a nightly build', () {
      expect(
        InstallPlan.versionsMatch(
            'nightly-20260330T013130', 'nightly-20260330T013130'),
        isTrue,
      );
    });

    test('a different version is not a match', () {
      expect(InstallPlan.versionsMatch('1.2.0', 'v1.2.1'), isFalse);
    });

    test('an unreadable version never passes by default', () {
      expect(InstallPlan.versionsMatch(null, 'v1.2.1'), isFalse);
      expect(InstallPlan.versionsMatch('', 'v1.2.1'), isFalse);
      expect(InstallPlan.versionsMatch('  ', 'v1.2.1'), isFalse);
      expect(InstallPlan.versionsMatch('1.2.1', null), isFalse);
      expect(InstallPlan.versionsMatch('1.2.1', ''), isFalse);
    });
  });

  group('InstallPlan.needsMdbArtifact', () {
    BoardPlan mdb(BoardAction a) =>
        BoardPlan(board: Board.mdb, action: a);
    InstallPlan planWith(BoardAction a) => InstallPlan(
        mdb: mdb(a), dbc: BoardPlan(board: Board.dbc, action: BoardAction.leave));

    test('a board the user asked us to leave alone gets no artifact', () {
      // The artifact phase uploads a .mender, runs it and reboots the board.
      // None of that is allowed on a plan that said do not touch it.
      expect(planWith(BoardAction.leave).needsMdbArtifact, isFalse);
    });

    test('a full image already carries its firmware', () {
      expect(planWith(BoardAction.fullImage).needsMdbArtifact, isFalse);
    });

    test('upgrade and clean install both want the artifact on top', () {
      expect(planWith(BoardAction.upgrade).needsMdbArtifact, isTrue);
      expect(planWith(BoardAction.cleanInstall).needsMdbArtifact, isTrue);
    });
  });
}

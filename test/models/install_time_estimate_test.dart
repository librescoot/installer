import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/models/install_time_estimate.dart';

BoardPlan _board(Board board, BoardAction action) =>
    BoardPlan(board: board, action: action);

InstallPlan _plan(BoardAction mdb, BoardAction dbc, {bool tiles = false}) =>
    InstallPlan(
      mdb: _board(Board.mdb, mdb),
      dbc: _board(Board.dbc, dbc),
      installTiles: tiles,
    );

const _oneLinkSecond = 10 * 1000 * 1000;

void main() {
  group('InstallEstimateAssets', () {
    test('allows unknown sizes', () {
      const assets = InstallEstimateAssets();
      expect(assets.dbcStage0ImageBytes, isNull);
      expect(assets.dbcArtifactBytes, isNull);
      expect(assets.osmTilesBytes, isNull);
      expect(assets.routingTilesBytes, isNull);
      expect(() => assets.validate(), returnsNormally);
    });

    test('rejects negative sizes instead of treating them as no work', () {
      expect(
        () => const InstallEstimateAssets(dbcArtifactBytes: -1).validate(),
        throwsArgumentError,
      );
    });
  });

  group('InstallTimeEstimate', () {
    test('a plan that leaves both boards alone is zero work', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.leave, BoardAction.leave),
      );

      expect(estimate.typical, Duration.zero);
      expect(estimate.conservativeUpper, Duration.zero);
      expect(estimate.stages, isEmpty);
      expect(estimate.isIndeterminate, isFalse);
    });

    test('maps-only includes one named maps stage and no firmware stages', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.leave, BoardAction.leave, tiles: true),
        assets: const InstallEstimateAssets(
          osmTilesBytes: _oneLinkSecond,
          routingTilesBytes: _oneLinkSecond,
        ),
      );

      expect(estimate.typical, const Duration(seconds: 22));
      expect(estimate.conservativeUpper, const Duration(seconds: 94));
      expect(estimate.stages.map((stage) => stage.name), ['maps']);
      expect(estimate.stages.single.overlapGroup, isNull);
      expect(estimate.isIndeterminate, isFalse);
    });

    test('DBC upgrade uses artifact bytes at the documented link rate', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.leave, BoardAction.upgrade),
        assets: const InstallEstimateAssets(dbcArtifactBytes: _oneLinkSecond),
      );
      final artifact = estimate.stages.single;

      // 1 s upload + 2 min mender allowance + 2 min reboot/SSH allowance.
      expect(estimate.typical, const Duration(seconds: 241));
      expect(estimate.conservativeUpper, const Duration(seconds: 422));
      expect(artifact.name, 'dbc-artifact');
      expect(artifact.typical, const Duration(seconds: 241));
      expect(artifact.weight, 1.0);
      expect(artifact.conservativeWeight, 1.0);
    });

    test('DBC clean install contains stage 0, then artifact work', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.leave, BoardAction.cleanInstall),
        assets: const InstallEstimateAssets(
          dbcStage0ImageBytes: 3 * 1000 * 1000,
          dbcArtifactBytes: _oneLinkSecond,
        ),
      );

      expect(estimate.typical, const Duration(seconds: 361));
      expect(estimate.stages.map((stage) => stage.name), [
        'dbc-stage-0',
        'dbc-artifact',
      ]);
      expect(
        estimate.stages.first.typical,
        const Duration(seconds: 120),
      ); // 3 MB at 210 kB/s + the measured stage-0 overhead.
    });

    test('full image does not add an artifact install', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.leave, BoardAction.fullImage),
        assets: const InstallEstimateAssets(dbcStage0ImageBytes: 0),
      );

      expect(
        estimate.typical,
        InstallEstimateConstants.dbcStage0OverheadTypical,
      );
      expect(estimate.stages.map((stage) => stage.name), ['dbc-stage-0']);
      expect(estimate.stages.single.typical, estimate.typical);
    });

    test('clean MDB includes its stage 0 and final reboot', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.cleanInstall, BoardAction.leave),
      );

      expect(estimate.typical, const Duration(seconds: 90 + 180 + 90));
      expect(estimate.stages.map((stage) => stage.name), [
        'mdb-stage-0',
        'mdb-artifact',
        'mdb-reboot-and-verify',
      ]);
    });

    test('autonomous handoff excludes MDB stage 0 that already finished', () {
      final estimate = InstallTimeEstimate.forAutonomousHandoff(
        plan: _plan(BoardAction.cleanInstall, BoardAction.upgrade),
        assets: const InstallEstimateAssets(dbcArtifactBytes: _oneLinkSecond),
      );

      expect(
        estimate.stages.map((stage) => stage.name),
        isNot(contains('mdb-stage-0')),
      );
      expect(
        estimate.stages.map((stage) => stage.name),
        contains('mdb-artifact'),
      );
      expect(
        estimate.stages.map((stage) => stage.name),
        contains('dbc-artifact'),
      );
      expect(
        estimate.stages.map((stage) => stage.name),
        contains('mdb-reboot-and-verify'),
      );
    });

    test('a full-image MDB fallback still includes its return from UMS', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.fullImage, BoardAction.leave),
      );

      expect(estimate.typical, const Duration(seconds: 90 + 90));
      expect(estimate.stages.map((stage) => stage.name), [
        'mdb-stage-0',
        'mdb-reboot-and-verify',
      ]);
    });

    test('MDB artifact work overlaps the DBC branch', () {
      final mdbOnly = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.upgrade, BoardAction.leave),
      );
      final dbcOnly = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.leave, BoardAction.upgrade),
        assets: const InstallEstimateAssets(dbcArtifactBytes: _oneLinkSecond),
      );
      final both = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.upgrade, BoardAction.upgrade),
        assets: const InstallEstimateAssets(dbcArtifactBytes: _oneLinkSecond),
      );

      // The background MDB worker runs while DBC work runs; only the final
      // MDB reboot is added after the joined work.
      expect(mdbOnly.typical, const Duration(seconds: 180 + 90));
      expect(dbcOnly.typical, const Duration(seconds: 241));
      expect(both.typical, const Duration(seconds: 241 + 90));
      expect(both.typical, lessThan(mdbOnly.typical + dbcOnly.typical));
      expect(
        both.stages
            .where((stage) => stage.overlapGroup == 'mdb-and-dbc-work')
            .length,
        2,
      );
    });

    test(
      'artifact installation overlaps map transfers after artifact upload',
      () {
        final withoutMaps = InstallTimeEstimate.fromPlan(
          plan: _plan(BoardAction.leave, BoardAction.upgrade),
          assets: const InstallEstimateAssets(dbcArtifactBytes: _oneLinkSecond),
        );
        final withMaps = InstallTimeEstimate.fromPlan(
          plan: _plan(BoardAction.leave, BoardAction.upgrade, tiles: true),
          assets: const InstallEstimateAssets(
            dbcArtifactBytes: _oneLinkSecond,
            osmTilesBytes: 100 * 1000 * 1000,
            routingTilesBytes: 100 * 1000 * 1000,
          ),
        );

        // Maps take 40 s nominally, while mender takes 120 s. Their common
        // 120 s portion is max(), not an addition.
        expect(withMaps.typical, withoutMaps.typical);
        expect(withMaps.stages.map((stage) => stage.name), [
          'dbc-artifact',
          'maps',
        ]);
        expect(withMaps.stages.last.typical, const Duration(seconds: 40));
      },
    );

    test('maps can become the critical branch without being added twice', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.leave, BoardAction.upgrade, tiles: true),
        assets: const InstallEstimateAssets(
          dbcArtifactBytes: 0,
          osmTilesBytes: 2 * 1000 * 1000 * 1000,
          routingTilesBytes: 2 * 1000 * 1000 * 1000,
        ),
      );

      // The 2 GB tile files (420 s) take longer than the 2 min install, so
      // they set the overlapped branch; the reboot follows it. Blind addition
      // would give 11 min.
      expect(estimate.typical, const Duration(seconds: 420 + 120));
      expect(estimate.typical, lessThan(const Duration(minutes: 11)));
    });

    test('unknown selected sizes produce broad indeterminate output', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.leave, BoardAction.upgrade, tiles: true),
      );

      expect(estimate.isIndeterminate, isTrue);
      expect(estimate.hasUnknownAssetSizes, isTrue);
      expect(estimate.isBroadEstimate, isTrue);
      expect(estimate.typical, greaterThan(Duration.zero));
      expect(estimate.conservativeUpper, greaterThan(estimate.typical));
      expect(estimate.stages.map((stage) => stage.name), [
        'dbc-artifact',
        'maps',
      ]);
    });

    test('unknown irrelevant sizes do not widen a plan', () {
      final estimate = InstallTimeEstimate.fromPlan(
        plan: _plan(BoardAction.upgrade, BoardAction.leave),
        assets: const InstallEstimateAssets(
          dbcStage0ImageBytes: null,
          dbcArtifactBytes: null,
          osmTilesBytes: null,
          routingTilesBytes: null,
        ),
      );

      // No DBC or map asset is selected, so their unknown sizes are irrelevant.
      expect(estimate.isIndeterminate, isFalse);
      expect(estimate.typical, const Duration(seconds: 270));
    });

    test(
      'weights and weighted durations describe the overlapped wall clock',
      () {
        final estimate = InstallTimeEstimate.fromPlan(
          plan: _plan(
            BoardAction.cleanInstall,
            BoardAction.cleanInstall,
            tiles: true,
          ),
          assets: const InstallEstimateAssets(
            dbcStage0ImageBytes: 3 * 1000 * 1000,
            dbcArtifactBytes: _oneLinkSecond,
            osmTilesBytes: _oneLinkSecond,
            routingTilesBytes: _oneLinkSecond,
          ),
        );

        final typicalWeight = estimate.stages.fold<double>(
          0,
          (sum, stage) => sum + stage.weight,
        );
        final conservativeWeight = estimate.stages.fold<double>(
          0,
          (sum, stage) => sum + stage.conservativeWeight,
        );
        final weightedTypical = estimate.stages.fold<Duration>(
          Duration.zero,
          (sum, stage) => sum + stage.weightedTypicalDuration,
        );
        final weightedConservative = estimate.stages.fold<Duration>(
          Duration.zero,
          (sum, stage) => sum + stage.weightedConservativeDuration,
        );

        expect(typicalWeight, closeTo(1.0, 0.000001));
        expect(conservativeWeight, closeTo(1.0, 0.000001));
        expect(weightedTypical, estimate.typical);
        expect(weightedConservative, estimate.conservativeUpper);
      },
    );

    test('calculation function is equivalent to the factory', () {
      final plan = _plan(BoardAction.leave, BoardAction.upgrade);
      const assets = InstallEstimateAssets(dbcArtifactBytes: _oneLinkSecond);
      final fromFactory = InstallTimeEstimate.fromPlan(
        plan: plan,
        assets: assets,
      );
      final fromFunction = estimateInstallTime(plan: plan, assets: assets);

      expect(fromFunction.typical, fromFactory.typical);
      expect(fromFunction.conservativeUpper, fromFactory.conservativeUpper);
      expect(
        fromFunction.stages.map((stage) => stage.name),
        fromFactory.stages.map((stage) => stage.name),
      );
    });
  });
}

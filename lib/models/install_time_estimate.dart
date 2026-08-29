import 'install_plan.dart';

/// Byte sizes of the assets that can cross the MDB/DBC link during an install.
///
/// A null size means that the asset is selected, but its final staged size is
/// not known yet. It is deliberately different from zero: an unknown asset
/// must widen an estimate rather than disappear from it.
class InstallEstimateAssets {
  const InstallEstimateAssets({
    this.dbcStage0ImageBytes,
    this.dbcArtifactBytes,
    this.osmTilesBytes,
    this.routingTilesBytes,
  });

  final int? dbcStage0ImageBytes;
  final int? dbcArtifactBytes;
  final int? osmTilesBytes;
  final int? routingTilesBytes;

  void validate() {
    for (final entry in {
      'dbcStage0ImageBytes': dbcStage0ImageBytes,
      'dbcArtifactBytes': dbcArtifactBytes,
      'osmTilesBytes': osmTilesBytes,
      'routingTilesBytes': routingTilesBytes,
    }.entries) {
      if (entry.value != null && entry.value! < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'must not be negative',
        );
      }
    }
  }
}

/// Conservative, intentionally boring constants used by [InstallTimeEstimate].
///
/// These are wall-clock allowances, not measurements from a particular run.
/// The 11 MB/s dashboard link comes from the trampoline's upload note. The
/// 2--4 MB/s write range comes from its UMS flash watchdog comment, so the
/// midpoint is used for a typical value and the slow end for the upper value.
/// The broad ceilings preserve the waits currently used by the scripts: 300 s
/// cable/UMS windows, 900 s DBC mender calls, 30 min MDB-artifact joining, and
/// 300 s post-reboot SSH recovery. No constant represents device telemetry.
class InstallEstimateConstants {
  InstallEstimateConstants._();

  static const int dbcLinkBytesPerSecond = 11 * 1000 * 1000;
  static const int conservativeDbcLinkBytesPerSecond = 5 * 1000 * 1000;
  static const int typicalStage0WriteBytesPerSecond = 3 * 1000 * 1000;
  static const int conservativeStage0WriteBytesPerSecond = 2 * 1000 * 1000;

  /// The existing UI says a UMS image write takes about a minute.
  static const Duration mdbStage0Typical = Duration(minutes: 1);
  static const Duration mdbStage0Conservative = Duration(minutes: 3);

  /// The MDB mender worker is backgrounded; the reboot phase joins for 30 min.
  static const Duration mdbArtifactTypical = Duration(minutes: 2);
  static const Duration mdbArtifactConservative = Duration(minutes: 30);

  /// A DBC artifact install is bounded by the 900 s SSH command in the script.
  static const Duration dbcArtifactInstallTypical = Duration(minutes: 2);
  static const Duration dbcArtifactInstallConservative = Duration(minutes: 15);

  /// Includes the 20 s reboot pause and the subsequent SSH recovery window.
  static const Duration dbcRebootTypical = Duration(minutes: 2);
  static const Duration dbcRebootConservative = Duration(minutes: 5);
  static const Duration mdbRebootTypical = Duration(minutes: 3);
  static const Duration mdbRebootConservative = Duration(minutes: 5);

  /// The stage-0 path has two user/USB wait windows in the scripts. Typical is
  /// intentionally shorter than their failure ceiling; the upper value keeps
  /// both the handoff and a slow board in view without promising success.
  static const Duration dbcStage0OverheadTypical = Duration(minutes: 3);
  static const Duration dbcStage0OverheadConservative = Duration(minutes: 10);

  static const Duration mapAssetOverheadTypical = Duration(seconds: 10);
  static const Duration mapAssetOverheadConservative = Duration(minutes: 2);

  /// Used when a selected file has no final size yet. This is a broad range,
  /// not a guess about the file or a claim that it has finished staging.
  static const Duration unknownTransferTypical = Duration(minutes: 10);
  static const Duration unknownTransferConservative = Duration(minutes: 45);
  static const Duration unknownStage0WriteTypical = Duration(minutes: 3);
  static const Duration unknownStage0WriteConservative = Duration(minutes: 15);
}

/// One named portion of an install estimate.
class EstimatedInstallStage {
  const EstimatedInstallStage({
    required this.name,
    required this.typicalDuration,
    required this.conservativeUpperDuration,
    required this.weight,
    required this.conservativeWeight,
    required this.weightedTypicalDuration,
    required this.weightedConservativeDuration,
    this.overlapGroup,
  });

  /// Stable, non-localized identifier for a caller to map to UI text.
  final String name;
  final Duration typicalDuration;
  final Duration conservativeUpperDuration;

  /// Share of the estimate's wall-clock duration allocated to this stage.
  /// Weights add to one, while [typicalDuration] values need not: overlapping
  /// work is represented by the allocation rather than blind addition.
  final double weight;
  final double conservativeWeight;

  /// The portion of wall-clock time allocated to this stage after overlap.
  final Duration weightedTypicalDuration;
  final Duration weightedConservativeDuration;

  /// Stages with the same group can be active at the same time.
  final String? overlapGroup;

  Duration get typical => typicalDuration;
  Duration get conservativeUpper => conservativeUpperDuration;
  Duration get weightedConservative => weightedConservativeDuration;
}

/// A static estimate for a selected [InstallPlan].
///
/// This model has no clock, progress, device status, or completion assertion.
/// [isIndeterminate] is true whenever a selected asset has an unknown size;
/// callers should present the result as a broad estimate rather than as a
/// countdown or a report of what the installer has already done.
class InstallTimeEstimate {
  InstallTimeEstimate._({
    required this.typicalDuration,
    required this.conservativeUpperDuration,
    required this.stages,
    required this.isIndeterminate,
  });

  factory InstallTimeEstimate.fromPlan({
    required InstallPlan plan,
    InstallEstimateAssets assets = const InstallEstimateAssets(),
  }) {
    assets.validate();
    return _build(plan, assets);
  }

  /// Estimate the autonomous work remaining once the laptop disconnects.
  /// MDB stage 0 has already completed by then. An MDB firmware package may
  /// still be running in parallel with the dashboard work, so retain only
  /// that part of the MDB plan.
  factory InstallTimeEstimate.forAutonomousHandoff({
    required InstallPlan plan,
    InstallEstimateAssets assets = const InstallEstimateAssets(),
  }) {
    final remainingPlan = InstallPlan(
      mdb: BoardPlan(
        board: plan.mdb.board,
        action: plan.needsMdbArtifact ? BoardAction.upgrade : BoardAction.leave,
      ),
      dbc: plan.dbc,
      installTiles: plan.installTiles,
    );
    assets.validate();
    return _build(remainingPlan, assets);
  }

  /// Alias useful at call sites that read like a calculation.
  factory InstallTimeEstimate.calculate({
    required InstallPlan plan,
    InstallEstimateAssets assets = const InstallEstimateAssets(),
  }) => InstallTimeEstimate.fromPlan(plan: plan, assets: assets);

  final Duration typicalDuration;
  final Duration conservativeUpperDuration;
  final List<EstimatedInstallStage> stages;
  final bool isIndeterminate;

  Duration get typical => typicalDuration;
  Duration get conservativeUpper => conservativeUpperDuration;
  bool get hasUnknownAssetSizes => isIndeterminate;
  bool get isBroadEstimate => isIndeterminate;

  static InstallTimeEstimate _build(
    InstallPlan plan,
    InstallEstimateAssets assets,
  ) {
    final mdbStage0 =
        plan.mdb.action == BoardAction.cleanInstall ||
            plan.mdb.action == BoardAction.fullImage
        ? const _Durations(
            typical: InstallEstimateConstants.mdbStage0Typical,
            conservative: InstallEstimateConstants.mdbStage0Conservative,
            known: true,
          )
        : _Durations.zero;

    final dbcStage0 = plan.needsDbcStage0
        ? _stage0Duration(assets.dbcStage0ImageBytes)
        : _Durations.zero;
    final mdbArtifact = plan.needsMdbArtifact
        ? const _Durations(
            typical: InstallEstimateConstants.mdbArtifactTypical,
            conservative: InstallEstimateConstants.mdbArtifactConservative,
            known: true,
          )
        : _Durations.zero;

    // The background MDB worker begins before the dashboard phase, so it can
    // overlap the whole DBC branch, including DBC stage 0. The final MDB
    // reboot happens only after both branches have joined.
    final dbcBranch = _dbcWork(plan: plan, assets: assets);
    final parallel = _max(mdbArtifact, dbcBranch);
    // A full-image fallback also leaves mass-storage mode and must wait for
    // the MDB to return, even though it carries its firmware and therefore
    // has no artifact stage.
    final needsMdbReboot =
        plan.needsMdbArtifact || plan.mdb.action == BoardAction.fullImage;
    final finalMdbReboot = needsMdbReboot
        ? const _Durations(
            typical: InstallEstimateConstants.mdbRebootTypical,
            conservative: InstallEstimateConstants.mdbRebootConservative,
            known: true,
          )
        : _Durations.zero;

    final total = _add(_add(mdbStage0, parallel), finalMdbReboot);
    final stages = _stages(
      plan: plan,
      assets: assets,
      mdbStage0: mdbStage0,
      mdbArtifact: mdbArtifact,
      dbcBranch: dbcBranch,
      dbcStage0: dbcStage0,
      finalMdbReboot: finalMdbReboot,
      total: total,
    );

    return InstallTimeEstimate._(
      typicalDuration: total.typical,
      conservativeUpperDuration: total.conservative,
      stages: List.unmodifiable(stages),
      isIndeterminate: !total.known,
    );
  }

  static _Durations _dbcWork({
    required InstallPlan plan,
    required InstallEstimateAssets assets,
  }) {
    final stage0 = plan.needsDbcStage0
        ? _stage0Duration(assets.dbcStage0ImageBytes)
        : _Durations.zero;
    final hasArtifact =
        plan.dbc.action == BoardAction.upgrade ||
        plan.dbc.action == BoardAction.cleanInstall;
    final artifactTransfer = hasArtifact
        ? _transfer(assets.dbcArtifactBytes)
        : _Durations.zero;
    final artifactInstall = hasArtifact
        ? const _Durations(
            typical: InstallEstimateConstants.dbcArtifactInstallTypical,
            conservative:
                InstallEstimateConstants.dbcArtifactInstallConservative,
            known: true,
          )
        : _Durations.zero;
    final maps = plan.installTiles ? _mapsWork(assets) : _Durations.zero;

    // The script uploads the DBC artifact before starting maps. Once the
    // artifact has landed, its install and map transfers run concurrently; the
    // DBC reboot waits for both. Tiles-only work has no reboot.
    final postStage0 = hasArtifact
        ? _add(
            _add(artifactTransfer, _max(artifactInstall, maps)),
            const _Durations(
              typical: InstallEstimateConstants.dbcRebootTypical,
              conservative: InstallEstimateConstants.dbcRebootConservative,
              known: true,
            ),
          )
        : maps;
    return _add(stage0, postStage0);
  }

  static _Durations _mapsWork(InstallEstimateAssets assets) {
    final osm = _mapAsset(assets.osmTilesBytes);
    final routing = _mapAsset(assets.routingTilesBytes);
    // install_tiles uploads display then routing tiles in the foreground.
    return _add(osm, routing);
  }

  static _Durations _mapAsset(int? bytes) {
    final transfer = _transfer(bytes);
    return _add(
      transfer,
      bytes == null
          ? const _Durations(
              typical: InstallEstimateConstants.mapAssetOverheadTypical,
              conservative:
                  InstallEstimateConstants.mapAssetOverheadConservative,
              known: false,
            )
          : const _Durations(
              typical: InstallEstimateConstants.mapAssetOverheadTypical,
              conservative:
                  InstallEstimateConstants.mapAssetOverheadConservative,
              known: true,
            ),
    );
  }

  static _Durations _stage0Duration(int? bytes) {
    final write = bytes == null
        ? const _Durations(
            typical: InstallEstimateConstants.unknownStage0WriteTypical,
            conservative:
                InstallEstimateConstants.unknownStage0WriteConservative,
            known: false,
          )
        : _rateDuration(
            bytes,
            InstallEstimateConstants.typicalStage0WriteBytesPerSecond,
            InstallEstimateConstants.conservativeStage0WriteBytesPerSecond,
          );
    return _add(
      write,
      const _Durations(
        typical: InstallEstimateConstants.dbcStage0OverheadTypical,
        conservative: InstallEstimateConstants.dbcStage0OverheadConservative,
        known: true,
      ),
    );
  }

  static _Durations _transfer(int? bytes) {
    if (bytes == null) {
      return const _Durations(
        typical: InstallEstimateConstants.unknownTransferTypical,
        conservative: InstallEstimateConstants.unknownTransferConservative,
        known: false,
      );
    }
    return _rateDuration(
      bytes,
      InstallEstimateConstants.dbcLinkBytesPerSecond,
      InstallEstimateConstants.conservativeDbcLinkBytesPerSecond,
    );
  }

  static List<EstimatedInstallStage> _stages({
    required InstallPlan plan,
    required InstallEstimateAssets assets,
    required _Durations mdbStage0,
    required _Durations mdbArtifact,
    required _Durations dbcBranch,
    required _Durations dbcStage0,
    required _Durations finalMdbReboot,
    required _Durations total,
  }) {
    if (total.typical == Duration.zero && total.conservative == Duration.zero) {
      return const [];
    }

    final nominal = <String, _Durations>{};
    final effectiveTypical = <String, Duration>{};
    final effectiveConservative = <String, Duration>{};

    void addSerial(String name, _Durations duration) {
      if (duration.typical == Duration.zero &&
          duration.conservative == Duration.zero) {
        return;
      }
      nominal[name] = duration;
      effectiveTypical[name] = duration.typical;
      effectiveConservative[name] = duration.conservative;
    }

    addSerial('mdb-stage-0', mdbStage0);
    if (dbcBranch.typical > Duration.zero ||
        dbcBranch.conservative > Duration.zero) {
      // The branch is decomposed below for names, while this duration is used
      // to allocate the outer MDB/DBC overlap honestly.
      final dbcParts = _dbcParts(plan, assets, dbcStage0);
      final dbcPartTypical = dbcParts
          .map((p) => p.duration.typical)
          .fold(Duration.zero, _addDuration);
      final dbcPartConservative = dbcParts
          .map((p) => p.duration.conservative)
          .fold(Duration.zero, _addDuration);
      final parallelTypical = _max(mdbArtifact, dbcBranch).typical;
      final parallelConservative = _max(mdbArtifact, dbcBranch).conservative;
      final typicalMdbShare = _share(
        parallelTypical,
        mdbArtifact.typical,
        _addDuration(mdbArtifact.typical, dbcPartTypical),
      );
      final conservativeMdbShare = _share(
        parallelConservative,
        mdbArtifact.conservative,
        _addDuration(mdbArtifact.conservative, dbcPartConservative),
      );
      if (mdbArtifact.typical > Duration.zero ||
          mdbArtifact.conservative > Duration.zero) {
        nominal['mdb-artifact'] = mdbArtifact;
        effectiveTypical['mdb-artifact'] = typicalMdbShare;
        effectiveConservative['mdb-artifact'] = conservativeMdbShare;
      }
      for (final part in dbcParts) {
        nominal[part.name] = part.duration;
        effectiveTypical[part.name] = _portion(
          parallelTypical - typicalMdbShare,
          part.duration.typical,
          dbcPartTypical,
        );
        effectiveConservative[part.name] = _portion(
          parallelConservative - conservativeMdbShare,
          part.duration.conservative,
          dbcPartConservative,
        );
      }
    } else if (mdbArtifact.typical > Duration.zero ||
        mdbArtifact.conservative > Duration.zero) {
      addSerial('mdb-artifact', mdbArtifact);
    }
    addSerial('mdb-reboot-and-verify', finalMdbReboot);

    final typicalTotal = total.typical.inMicroseconds;
    final conservativeTotal = total.conservative.inMicroseconds;
    final result = nominal.entries.map((entry) {
      final typicalWeight = typicalTotal == 0
          ? 0.0
          : (effectiveTypical[entry.key]!.inMicroseconds / typicalTotal);
      final conservativeWeight = conservativeTotal == 0
          ? 0.0
          : (effectiveConservative[entry.key]!.inMicroseconds /
                conservativeTotal);
      return EstimatedInstallStage(
        name: entry.key,
        typicalDuration: entry.value.typical,
        conservativeUpperDuration: entry.value.conservative,
        weight: typicalWeight,
        conservativeWeight: conservativeWeight,
        weightedTypicalDuration: effectiveTypical[entry.key]!,
        weightedConservativeDuration: effectiveConservative[entry.key]!,
        overlapGroup: _overlapGroup(
          entry.key,
          hasMdbArtifact: mdbArtifact.typical > Duration.zero,
          hasDbcArtifact:
              plan.dbc.action == BoardAction.upgrade ||
              plan.dbc.action == BoardAction.cleanInstall,
          hasMaps: plan.installTiles,
        ),
      );
    }).toList();

    // Proportional allocation uses rounded microseconds. Put any final
    // rounding remainder on the last visible stage so the weighted view is
    // exactly the same wall-clock estimate as the scalar fields.
    final last = result.last;
    final weightedTypical = result
        .map((stage) => stage.weightedTypicalDuration)
        .fold(Duration.zero, _addDuration);
    final weightedConservative = result
        .map((stage) => stage.weightedConservativeDuration)
        .fold(Duration.zero, _addDuration);
    final correctedTypical =
        last.weightedTypicalDuration + total.typical - weightedTypical;
    final correctedConservative =
        last.weightedConservativeDuration +
        total.conservative -
        weightedConservative;
    result[result.length - 1] = EstimatedInstallStage(
      name: last.name,
      typicalDuration: last.typicalDuration,
      conservativeUpperDuration: last.conservativeUpperDuration,
      weight: typicalTotal == 0
          ? 0.0
          : correctedTypical.inMicroseconds / typicalTotal,
      conservativeWeight: conservativeTotal == 0
          ? 0.0
          : correctedConservative.inMicroseconds / conservativeTotal,
      weightedTypicalDuration: correctedTypical,
      weightedConservativeDuration: correctedConservative,
      overlapGroup: last.overlapGroup,
    );
    return List.unmodifiable(result);
  }

  static List<_NamedDurations> _dbcParts(
    InstallPlan plan,
    InstallEstimateAssets assets,
    _Durations stage0,
  ) {
    final parts = <_NamedDurations>[];
    if (stage0.typical > Duration.zero || stage0.conservative > Duration.zero) {
      parts.add(_NamedDurations('dbc-stage-0', stage0));
    }
    final hasArtifact =
        plan.dbc.action == BoardAction.upgrade ||
        plan.dbc.action == BoardAction.cleanInstall;
    final artifactTransfer = hasArtifact
        ? _transfer(assets.dbcArtifactBytes)
        : _Durations.zero;
    final artifactInstall = hasArtifact
        ? const _Durations(
            typical: InstallEstimateConstants.dbcArtifactInstallTypical,
            conservative:
                InstallEstimateConstants.dbcArtifactInstallConservative,
            known: true,
          )
        : _Durations.zero;
    final maps = plan.installTiles ? _mapsWork(assets) : _Durations.zero;
    final dbcReboot = hasArtifact
        ? const _Durations(
            typical: InstallEstimateConstants.dbcRebootTypical,
            conservative: InstallEstimateConstants.dbcRebootConservative,
            known: true,
          )
        : _Durations.zero;

    if (hasArtifact) {
      parts.add(
        _NamedDurations(
          'dbc-artifact',
          _add(_add(artifactTransfer, artifactInstall), dbcReboot),
        ),
      );
      if (maps.typical > Duration.zero || maps.conservative > Duration.zero) {
        parts.add(_NamedDurations('maps', maps));
      }
      // The public stage durations are nominal. The wall-clock calculation in
      // _dbcWork uses max(install, maps), not this sum.
    } else if (maps.typical > Duration.zero ||
        maps.conservative > Duration.zero) {
      parts.add(_NamedDurations('maps', maps));
    }
    return parts;
  }

  static String? _overlapGroup(
    String name, {
    required bool hasMdbArtifact,
    required bool hasDbcArtifact,
    required bool hasMaps,
  }) {
    final hasDbcWork = hasDbcArtifact || hasMaps || name == 'dbc-stage-0';
    return switch (name) {
      'mdb-artifact' when hasDbcWork => 'mdb-and-dbc-work',
      'dbc-stage-0' when hasMdbArtifact => 'mdb-and-dbc-work',
      'dbc-artifact' when hasMdbArtifact || hasMaps => 'mdb-and-dbc-work',
      'maps' when hasMdbArtifact || hasDbcArtifact => 'mdb-and-dbc-work',
      _ => null,
    };
  }

  static Duration _portion(Duration total, Duration part, Duration whole) {
    if (total == Duration.zero ||
        part == Duration.zero ||
        whole == Duration.zero) {
      return Duration.zero;
    }
    return Duration(
      microseconds:
          (total.inMicroseconds * part.inMicroseconds / whole.inMicroseconds)
              .round(),
    );
  }

  static Duration _share(Duration total, Duration part, Duration whole) =>
      _portion(total, part, whole);

  static _Durations _rateDuration(int bytes, int typicalRate, int upperRate) =>
      _Durations(
        typical: Duration(seconds: _ceilSeconds(bytes, typicalRate)),
        conservative: Duration(seconds: _ceilSeconds(bytes, upperRate)),
        known: true,
      );

  static int _ceilSeconds(int bytes, int bytesPerSecond) =>
      (bytes / bytesPerSecond).ceil();

  static _Durations _add(_Durations a, _Durations b) => _Durations(
    typical: a.typical + b.typical,
    conservative: a.conservative + b.conservative,
    known: a.known && b.known,
  );

  static Duration _addDuration(Duration a, Duration b) => a + b;

  static _Durations _max(_Durations a, _Durations b) => _Durations(
    typical: a.typical >= b.typical ? a.typical : b.typical,
    conservative: a.conservative >= b.conservative
        ? a.conservative
        : b.conservative,
    known: a.known && b.known,
  );
}

class _NamedDurations {
  const _NamedDurations(this.name, this.duration);

  final String name;
  final _Durations duration;
}

class _Durations {
  const _Durations({
    required this.typical,
    required this.conservative,
    required this.known,
  });

  static const zero = _Durations(
    typical: Duration.zero,
    conservative: Duration.zero,
    known: true,
  );

  final Duration typical;
  final Duration conservative;
  final bool known;
}

/// Calculate a static estimate without constructing the result explicitly.
InstallTimeEstimate estimateInstallTime({
  required InstallPlan plan,
  InstallEstimateAssets assets = const InstallEstimateAssets(),
}) => InstallTimeEstimate.fromPlan(plan: plan, assets: assets);

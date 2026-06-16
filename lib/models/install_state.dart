import 'dart:convert';

/// Phases recorded in /data/installer/state.json on the MDB. Kebab-case JSON
/// values keep the door open for future CLI parity (the Go CLI uses the same
/// shape); btPaired/keycardEnrolled are flags layered on top so a Stage-1
/// interruption does not redo pairing/enrollment.
enum InstallPhase {
  mdbFlashed('mdb-flashed'),
  mdbBooted('mdb-booted'),
  btPaired('bt-paired'),
  keycardEnrolled('keycard-enrolled'),
  dbcStaged('dbc-staged'),
  trampolineArmed('trampoline-armed'),
  trampolineOk('trampoline-ok'),
  trampolineErr('trampoline-err'),
  finished('finished'),
  /// Sentinel for an absent or unrecognized phase string; not a progression step.
  unknown('unknown');

  const InstallPhase(this.wire);
  final String wire;

  static InstallPhase fromWire(String? s) =>
      InstallPhase.values.firstWhere((p) => p.wire == s,
          orElse: () => InstallPhase.unknown);
}

class InstallState {
  InstallState({
    required this.phase,
    this.channel,
    this.releaseTag,
    this.dbcImage,
    this.targetDbcVersion,
    this.osmTiles,
    this.valhallaTiles,
    this.language,
    this.serial,
    this.btPaired = false,
    this.keycardEnrolled = false,
  });

  final InstallPhase phase;
  final String? channel;
  final String? releaseTag;
  final String? dbcImage;
  final String? targetDbcVersion;
  final String? osmTiles;
  final String? valhallaTiles;
  final String? language;
  final String? serial;
  final bool btPaired;
  final bool keycardEnrolled;

  /// Only fields that change after the initial write are exposed; the config
  /// fields (channel, releaseTag, image, tiles, language, serial) are fixed.
  InstallState copyWith({
    InstallPhase? phase,
    bool? btPaired,
    bool? keycardEnrolled,
  }) =>
      InstallState(
        phase: phase ?? this.phase,
        channel: channel,
        releaseTag: releaseTag,
        dbcImage: dbcImage,
        targetDbcVersion: targetDbcVersion,
        osmTiles: osmTiles,
        valhallaTiles: valhallaTiles,
        language: language,
        serial: serial,
        btPaired: btPaired ?? this.btPaired,
        keycardEnrolled: keycardEnrolled ?? this.keycardEnrolled,
      );

  Map<String, dynamic> toJson() => {
        'phase': phase.wire,
        if (channel != null) 'channel': channel,
        if (releaseTag != null) 'release_tag': releaseTag,
        if (dbcImage != null) 'dbc_image': dbcImage,
        if (targetDbcVersion != null) 'target_dbc_version': targetDbcVersion,
        if (osmTiles != null) 'osm_tiles': osmTiles,
        if (valhallaTiles != null) 'valhalla_tiles': valhallaTiles,
        if (language != null) 'language': language,
        if (serial != null) 'serial': serial,
        'bt_paired': btPaired,
        'keycard_enrolled': keycardEnrolled,
      };

  factory InstallState.fromJson(Map<String, dynamic> j) => InstallState(
        phase: InstallPhase.fromWire(j['phase'] as String?),
        channel: j['channel'] as String?,
        releaseTag: j['release_tag'] as String?,
        dbcImage: j['dbc_image'] as String?,
        targetDbcVersion: j['target_dbc_version'] as String?,
        osmTiles: j['osm_tiles'] as String?,
        valhallaTiles: j['valhalla_tiles'] as String?,
        language: j['language'] as String?,
        serial: j['serial'] as String?,
        btPaired: j['bt_paired'] as bool? ?? false,
        keycardEnrolled: j['keycard_enrolled'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());
  static InstallState decode(String s) =>
      InstallState.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

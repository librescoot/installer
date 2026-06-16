import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/install_state.dart';

void main() {
  group('InstallState', () {
    test('round-trips through JSON', () {
      final s = InstallState(
        phase: InstallPhase.dbcStaged,
        channel: 'stable',
        releaseTag: 'v1.2.3',
        dbcImage: 'librescoot-dbc-v1.2.3.wic.gz',
        targetDbcVersion: 'v1.2.3',
        osmTiles: 'berlin_brandenburg.osm.tiles',
        valhallaTiles: 'berlin_brandenburg.valhalla.tiles',
        language: 'de',
        serial: 'ABC123',
        btPaired: true,
        keycardEnrolled: false,
      );
      final decoded = InstallState.fromJson(s.toJson());
      expect(decoded.phase, InstallPhase.dbcStaged);
      expect(decoded.channel, 'stable');
      expect(decoded.releaseTag, 'v1.2.3');
      expect(decoded.dbcImage, 'librescoot-dbc-v1.2.3.wic.gz');
      expect(decoded.targetDbcVersion, 'v1.2.3');
      expect(decoded.osmTiles, 'berlin_brandenburg.osm.tiles');
      expect(decoded.valhallaTiles, 'berlin_brandenburg.valhalla.tiles');
      expect(decoded.language, 'de');
      expect(decoded.serial, 'ABC123');
      expect(decoded.btPaired, true);
      expect(decoded.keycardEnrolled, false);
    });

    test('omits null optional fields from JSON', () {
      final json = InstallState(phase: InstallPhase.mdbFlashed).toJson();
      expect(json.containsKey('channel'), isFalse);
      expect(json.containsKey('release_tag'), isFalse);
      expect(json['bt_paired'], false);
      expect(json['keycard_enrolled'], false);
    });

    test('serializes phase as kebab-case string', () {
      final json = InstallState(phase: InstallPhase.trampolineArmed).toJson();
      expect(json['phase'], 'trampoline-armed');
    });

    test('parses kebab-case phase string', () {
      final s = InstallState.fromJson({'phase': 'mdb-booted'});
      expect(s.phase, InstallPhase.mdbBooted);
    });

    test('unknown phase string falls back to unknown', () {
      final s = InstallState.fromJson({'phase': 'bogus'});
      expect(s.phase, InstallPhase.unknown);
    });

    test('encode/decode is stable across a string trip', () {
      final s = InstallState(phase: InstallPhase.btPaired, channel: 'testing');
      final reparsed = InstallState.decode(s.encode());
      expect(reparsed.phase, InstallPhase.btPaired);
      expect(reparsed.channel, 'testing');
    });
  });
}

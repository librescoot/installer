import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/dashboard_messages.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/services/trampoline_service.dart';

void main() {
  group('trampoline.sh.template', () {
    late String template;

    setUpAll(() {
      template = File('assets/trampoline.sh.template').readAsStringSync();
    });

    test('declares the autonomous-finish placeholders', () {
      for (final ph in const [
        '{{FINISH_ON_DEVICE}}',
        '{{MDB_ACTION}}',
        '{{MDB_TARGET_VERSION}}',
        '{{FINISH_LANGUAGE}}',
        '{{FINISH_CHANNEL}}',
      ]) {
        expect(template, contains(ph), reason: '$ph is missing');
      }
    });

    test('carries no prose of its own, only the placeholders for it', () {
      // Every line the trampoline puts on the dashboard is filled by whoever
      // renders this, so that a garage outside Germany can read the one
      // instruction the install cannot proceed without. A literal that creeps
      // back in reaches the vehicle in a language nobody chose.
      for (final ph in DashboardMessages.english.placeholders.keys) {
        expect(template, contains(ph), reason: '$ph is missing');
      }
      final says = RegExp(r'dbc_(?:fail_)?say "([^"]*)"')
          .allMatches(template)
          .map((m) => m.group(1)!)
          .where((arg) => arg.isNotEmpty)
          .toList();
      expect(says, isNotEmpty, reason: 'the say sites moved');
      // The console banner is a printf rather than a dbc_say, so the sweep
      // above cannot see it.
      expect(template, contains(r'{{MSG_BANNER}}'));
      for (final arg in says) {
        expect(
          arg.startsWith('{{MSG_') || arg.startsWith(r'$'),
          isTrue,
          reason: 'literal on the dashboard: "$arg"',
        );
      }
    });

    test('fills every dashboard line it declares', () {
      final out = TrampolineService.renderTemplate(
        template,
        upgradeMode: false,
        dbcImagePath: '/data/installer/dbc.sdimg.gz',
        dbcMenderPath: '/data/installer/dbc.mender',
        messages: DashboardMessages.english,
      );
      expect(out, isNot(contains('{{MSG_')));
      expect(out, contains('dbc_say "Installation failed"'));
      // The version is the script's to fill, on the far side of a reboot this
      // process never sees. It has to reach the vehicle unexpanded.
      expect(out, contains(r'dbc_say "Firmware $DBC_VER running"'));
    });

    test('retires onboot.sh only after the work, not before it', () {
      // onboot.sh used to remove itself before doing anything, so a crash left
      // the vehicle with its services masked and nothing that would ever run
      // again to undo that. Retiring it must be a deliberate act at the end.
      expect(template, contains('retire_onboot()'));
      final guard = template.indexOf('ONBOOT_TRIES');
      final firstRetire = template.indexOf('  retire_onboot\n');
      expect(guard, greaterThan(0));
      expect(firstRetire, greaterThan(guard),
          reason: 'nothing may retire the script before the retry guard runs');
    });

    test('the give-up path restores service rather than protecting the install',
        () {
      // Past the retry cap the masking has outlived its purpose: an unlockable
      // scooter beats a protected one nobody can ride.
      final giveUp = template.indexOf('has failed 3 times');
      expect(giveUp, greaterThan(0));
      final tail = template.substring(giveUp, giveUp + 900);
      expect(tail, contains('unmask librescoot-keycard'));
      expect(tail, contains('unmask librescoot-bluetooth'));
      expect(tail, contains('bootled_blink_red'));
    });

    test('the sweep spares the OTA seed directory', () {
      // /data/ota holds the artifact update-service resolves a delta base
      // from. Deleting it would trade a smaller install for a device that can
      // never take a delta OTA.
      final sweep = template.indexOf(r'rm -rf "$INSTALLER_DIR"');
      expect(sweep, greaterThan(0));
      expect(template, isNot(contains('rm -rf /data/ota')));
    });

    test('declares the mode and artifact placeholders', () {
      expect(template, contains('{{MODE}}'));
      expect(template, contains('{{DBC_MENDER_PATH}}'));
      expect(template, contains('{{DBC_IMAGE_PATH}}'));
      expect(template, contains('{{DBC_TARGET_VERSION}}'));
    });

    test('bakes the target version into the second layer', () {
      // onboot.sh runs after the MDB reboot, so anything it needs has to be
      // written into it rather than inherited.
      expect(template, contains(r'DBC_TARGET="$DBC_TARGET"'));
    });

    test('guards the stage-0 block on flash mode', () {
      expect(template, contains(r'if [ "$MODE" = "flash" ]; then'));
    });

    test('does not enter host mode outside flash mode', () {
      // Nothing writes the role file directly: every switch goes through
      // role_write(), which wraps the write in a 15s timeout. Step 5's call
      // is the one stage 0 depends on, and it is the only host-mode entry
      // that is not inside a function body.
      final roleWrite = template
          .indexOf(r'role_write host || fail "Failed to switch to host mode"');
      expect(roleWrite, greaterThan(0),
          reason: 'the host-mode switch must still exist for stage 0');

      // There are two guards. indexOf finds the first, which only covers the
      // watchdog arm and the image check, so an opens-before-the-role-write
      // assertion on it survives deleting the second guard entirely. Key on
      // the close marker instead: the guard that keeps stage 0 out of upgrade
      // mode is the one whose fi lands after the role write.
      final guardClose = template.indexOf('fi  # end of MODE = flash');
      expect(guardClose, greaterThan(roleWrite),
          reason: 'the stage-0 guard must still close after the role write');

      final guard = template.indexOf(r'if [ "$MODE" = "flash" ]; then');
      expect(guard, greaterThan(0), reason: 'the guard must exist at all');
      expect(guard, lessThan(roleWrite),
          reason: 'the guard has to open before anything touches the OTG role');
    });

    test('rejects an install mode it does not recognise', () {
      expect(template, contains(r'flash|upgrade) log "Mode: $MODE" ;;'));
      expect(template, contains(r'fail "unrecognised install mode: $MODE"'));
    });

    test('a requested artifact that is not staged is an error in both layers',
        () {
      expect(template, contains(r'fail "DBC artifact not found: $DBC_MENDER"'));
      expect(template,
          contains(r'artifact_fail "error: DBC artifact missing on the MDB'));
      expect(template, isNot(contains(r'[ -n "$DBC_MENDER" ] && [ -f "$DBC_MENDER" ]')),
          reason: 'the combined test made a missing artifact look like no artifact');
    });

    test('only flash mode skips the update-service handshake, and the queue is drained',
        () {
      final push = template.indexOf(r'lpush scooter:update:dbc "$DBC_UPDATE_CMD"');
      final modeGate = template.indexOf(r'if [ "$MODE" = "upgrade" ]; then');
      expect(modeGate, greaterThan(0));
      expect(modeGate, lessThan(push),
          reason: 'a stage-0 board has no update-service, so nothing may be queued for it');
      expect(template, contains(r'lrem scooter:update:dbc 0 "$DBC_UPDATE_CMD"'));
    });

    test('the direct mender fallback is reachable only when nothing answered',
        () {
      expect(template, contains(r'artifact_fail "error: DBC update-service refused the artifact'),
          reason: 'an explicit refusal must not fall through to mender');
      expect(template, contains(r'artifact_fail "error: DBC artifact install timed out'),
          reason: 'an exhausted wait may still have an install in flight');
      final absent = template.indexOf(r'DBC_OTA_VERDICT="absent"');
      expect(absent, greaterThan(0),
          reason: 'the fallback needs its own verdict, not a shared else');
    });

    test('stages the artifact to the OTA seed path on the DBC', () {
      expect(template, contains('/data/ota/dbc/'));
      expect(template, contains('mender-update install'));
      expect(template, contains('scooter:update:dbc'));
    });

    test('the transfer helper is available with tiles switched off', () {
      // It has to be defined outside the tiles conditional, because the
      // artifact upload uses it whether or not tiles were selected. Position
      // relative to the tiles block says nothing on its own: the block is
      // emitted early now so install_tiles exists before the artifact section
      // starts it as a job.
      final helper = template.indexOf('upload_to_dbc()');
      expect(helper, greaterThan(0));

      final tilesStart = template.indexOf(r'if [ "$INSTALL_TILES" = "true" ]');
      final tilesEnd = template.indexOf('NOTILES\nfi', tilesStart);
      expect(tilesStart, greaterThan(0));
      expect(tilesEnd, greaterThan(tilesStart));
      expect(helper > tilesStart && helper < tilesEnd, isFalse,
          reason: 'defining it inside the tiles branch would leave the '
              'artifact upload without it when tiles are switched off');
    });

    test('an unreachable DBC with an artifact staged is an error, not success',
        () {
      expect(template, contains('error: DBC not reachable, artifact not installed'));
    });

    test('checks DBC free space before the transfer, not after', () {
      final df = template.indexOf(r"df -kP /data' 2>/dev/null | awk");
      final upload = template.indexOf(
          r'upload_to_dbc "$DBC_MENDER" "/ota/dbc/$DBC_ART_NAME" "DBC artifact"');
      expect(df, greaterThan(0), reason: 'the spec says the trampoline checks');
      expect(upload, greaterThan(0));
      expect(df, lessThan(upload),
          reason: 'a full /data has to be named before ten minutes of retries');
      expect(template,
          contains('artifact_fail "error: not enough space on the DBC'));
    });

    test('a DBC that came back unchanged is a failure, not a success', () {
      // Reading both values and comparing neither is what the MDB side used
      // to do, and it reported a rolled-back install as done.
      expect(template, contains(r'DBC_VER_BEFORE=$('));
      expect(template, contains(r'DBC_ART_AFTER=$('));
      expect(
          template,
          contains(
              'artifact_fail "error: could not read the DBC version after the artifact install"'));
      expect(template,
          contains(r'artifact_fail "error: the DBC came back on $DBC_VER instead of $DBC_TARGET'));
      expect(template,
          contains(r'artifact_fail "error: the DBC came back unchanged on $DBC_VER'));
      expect(
          template,
          contains(
              'artifact_fail "error: the DBC is still running the bootstrap image'),
          reason: 'os-release cannot tell stage 0 from a full image');
    });
  });

  group('the autonomous finish reaches the script', () {
    String render(DeviceFinish finish) => TrampolineService.renderTemplate(
          File('assets/trampoline.sh.template').readAsStringSync(),
          upgradeMode: false,
          dbcImagePath: '/data/installer/dbc.sdimg.gz',
          dbcMenderPath: '/data/installer/dbc.mender',
          finish: finish,
        );

    test('onDevice true renders the flag the guards compare against', () {
      // Both finish blocks are `if [ "$FINISH_ON_DEVICE" = "true" ]`, so
      // anything but that exact string silently hands back to the laptop:
      // no settings restore, no completion record, no reboot, while the LED
      // still blinks green.
      final out = render(const DeviceFinish(
        onDevice: true,
        mdbAction: BoardAction.leave,
        language: 'de',
        otaChannel: 'nightly',
      ));
      expect(out, contains('FINISH_ON_DEVICE="true"'));
      expect(out, contains('FINISH_LANGUAGE="de"'));
      expect(out, contains('FINISH_CHANNEL="nightly"'));
      expect(out, isNot(contains('{{FINISH_ON_DEVICE}}')));
    });

    test('the laptop finish renders false', () {
      final out = render(DeviceFinish.laptop);
      expect(out, contains('FINISH_ON_DEVICE="false"'));
    });

    test('no placeholder survives rendering', () {
      final out = render(const DeviceFinish(
          onDevice: true, mdbAction: BoardAction.upgrade));
      expect(RegExp(r'\{\{[A-Z0-9_]+\}\}').firstMatch(out), isNull,
          reason: 'an unsubstituted placeholder reaches the device as a '
              'literal and every test of it compares false');
    });
  });
}

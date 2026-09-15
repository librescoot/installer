import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory bin;
  late File helper;
  late Map<String, String> env;

  void stub(String name, String body) {
    final f = File('${bin.path}/$name')
      ..writeAsStringSync('#!/bin/sh\n$body\n');
    Process.runSync('chmod', ['755', f.path]);
  }

  ProcessResult run(String body, {Map<String, String> extra = const {}}) {
    final script = File('${root.path}/scenario.sh')
      ..writeAsStringSync('''
set -eu
RUN_ID=run-1
log() { echo "\$*"; }
. '${helper.path}'
$body
''');
    return Process.runSync(
      'sh',
      [script.path],
      environment: {...env, ...extra},
    );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('dbc-control-');
    bin = Directory('${root.path}/bin')..createSync();
    helper = File('${root.path}/device.sh')
      ..writeAsStringSync(
        File('assets/device.sh').readAsStringSync().replaceAll(
          'DBC_CONTROL_DIR=/data/librescoot-installer/dbc-control',
          'DBC_CONTROL_DIR="\$TEST_ROOT/control"',
        ),
      );
    stub(
      'mender-update',
      'echo "\${ARTIFACT:-release-v1.3.0-minimal}"; exit "\${MENDER_RC:-0}"',
    );
    stub(
      'systemctl',
      'echo "\${LOAD_STATE:-not-found}"; exit "\${SYSTEMCTL_RC:-0}"',
    );
    stub('redis-cli', '''
case "\$*" in
  *'hget vehicle dbc-updating') printf '%s' "\${FLAG:-}" ;;
  *'hget ota heartbeat-owner:dbc') printf '%s' "\${OWNER:-}" ;;
  *) exit 90 ;;
esac
''');
    stub('sync', 'exit 0');
    env = {'PATH': '${bin.path}:/usr/bin:/bin', 'TEST_ROOT': root.path};
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('bootstrap outer and generated handoff retain one exclusive owner', () {
    var result = run('dbc_control_acquire outer; dbc_control_record handoff');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    result = run(
      'dbc_control_acquire handoff; dbc_control_check; dbc_control_record committed; dbc_control_release',
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(Directory('${root.path}/control').existsSync(), isTrue);
    result = run(
      'DBC_CONTROL_ACQUIRED=yes; dbc_control_record complete; dbc_control_release',
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(Directory('${root.path}/control').existsSync(), isFalse);
  });

  for (final extra in <Map<String, String>>[
    {'ARTIFACT': 'release-v1.3.1'},
    {'ARTIFACT': 'release-v1.3.1-minimal'},
    {'MENDER_RC': '1'},
    {'LOAD_STATE': 'loaded'},
    {'SYSTEMCTL_RC': '1'},
    {'FLAG': 'true'},
    {'FLAG': 'unknown'},
    {'OWNER': 'foreign'},
  ]) {
    test('rejects unsupported or foreign control $extra', () {
      expect(run('dbc_control_acquire outer', extra: extra).exitCode, isNot(0));
    });
  }

  test('present lsc cannot be mistaken for bootstrap absence', () {
    stub('lsc', 'exit 0');
    expect(run('dbc_control_acquire outer').exitCode, isNot(0));
  });

  test('a competing run or duplicate handoff cannot take ownership', () {
    expect(
      run('dbc_control_acquire outer; dbc_control_record handoff').exitCode,
      0,
    );
    expect(run('dbc_control_acquire outer').exitCode, isNot(0));
    expect(run('RUN_ID=other; dbc_control_acquire handoff').exitCode, isNot(0));
    expect(run('dbc_control_acquire handoff').exitCode, 0);
    expect(run('dbc_control_acquire handoff').exitCode, isNot(0));
  });

  test(
    'handoff revalidates capabilities instead of trusting serialized mode',
    () {
      expect(
        run('dbc_control_acquire outer; dbc_control_record handoff').exitCode,
        0,
      );
      expect(
        run(
          'dbc_control_acquire handoff',
          extra: {'LOAD_STATE': 'loaded'},
        ).exitCode,
        isNot(0),
      );
    },
  );

  for (final state in [
    'artifact-install-unknown',
    'artifact-installed',
    'mask-unknown',
    'mask-prepared',
    'activation-unknown',
    'commit-unknown',
    'ums-preparing',
  ]) {
    test('$state blocks release and automatic re-entry', () {
      expect(
        run(
          'dbc_control_acquire outer; dbc_control_record $state; ! dbc_control_release',
        ).exitCode,
        0,
      );
      expect(run('dbc_control_acquire outer').exitCode, isNot(0));
      expect(run('dbc_control_acquire handoff').exitCode, isNot(0));
    });
  }

  test('control loss stops a running raw writer', () {
    final template = File('assets/trampoline.sh.template').readAsStringSync();
    final start = template.indexOf('wait_flash_with_dbc_control()');
    final end = template.indexOf('\ncollect_mdb_diagnostics()', start);
    final result = run('''
${template.substring(start, end)}
dbc_control_acquire outer
printf foreign > "\$DBC_CONTROL_DIR/owner"
sleep 30 &
pid=\$!
if wait_flash_with_dbc_control "\$pid"; then exit 1; fi
! kill -0 "\$pid" 2>/dev/null
''');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  for (final transportExit in [1, 124]) {
    test('remote artifact write exit $transportExit retains uncertainty without retry', () {
      final template = File('assets/trampoline.sh.template').readAsStringSync();
      final failStart = template.indexOf('artifact_fail()');
      final failEnd = template.indexOf('\n# Install the DBC artifact', failStart);
      final start = template.indexOf('    dbc_control_check || artifact_fail "error: bootstrap control lost before artifact install"');
      final end = template.indexOf('    if ! prepare_dbc_updater_mask;', start);
      final result = run('''
${template.substring(failStart, failEnd)}
dbc_control_acquire outer
DBC_TARGET_MASKED=no
DBC_UPDATE_CMD=''
MODE=flash
DBC_ART_PATH=/artifact
DBC_ACTIVATION_DISPATCHED=no
dbc_install_diagnostics() { :; }
dbc_fail_say() { :; }
write_status() { echo "stage=\$CURRENT_STAGE"; }
signal_error() { :; }
dbc_update_complete() { echo UNSAFE; }
dbc_owned_power_off() { echo UNSAFE; }
dbc_ssh_once_bounded() { echo dispatch; return $transportExit; }
${template.substring(start, end)}
''');
      expect(result.exitCode, 1, reason: result.stderr.toString());
      expect(result.stdout, isNot(contains('UNSAFE')));
      expect('dispatch'.allMatches(result.stdout.toString()).length, 1);
      expect(File('${root.path}/control/state').readAsStringSync().trim(), 'artifact-install-unknown');
      expect(run('dbc_control_acquire handoff').exitCode, isNot(0));
    });
  }

  for (final maskFailure in ['upload', 'transport', 'timeout', 'invalid-result']) {
    test('installed artifact followed by $maskFailure mask failure retains control and power', () {
      final template = File('assets/trampoline.sh.template').readAsStringSync();
      final failStart = template.indexOf('artifact_fail()');
      final failEnd = template.indexOf('\n# Install the DBC artifact', failStart);
      final helperStart = template.indexOf('prepare_dbc_updater_mask()');
      final helperEnd = template.indexOf('restore_dbc_updater_mask()', helperStart);
      final start = template.indexOf('    dbc_control_check || artifact_fail "error: bootstrap control lost before artifact install"');
      final end = template.indexOf('    log "  inactive target', start);
      final result = run('''
${template.substring(failStart, failEnd)}
${template.substring(helperStart, helperEnd)}
dbc_control_acquire outer
INSTALLER_DIR='${root.path}'
DBC_TARGET_MASKED=no
DBC_UPDATE_CMD=''
DBC_EXPECTED_ARTIFACT=release-target
MODE=flash
DBC_ART_PATH=/artifact
dbc_install_diagnostics() { :; }
dbc_fail_say() { :; }
write_status() { :; }
signal_error() { :; }
dbc_update_complete() { echo UNSAFE; }
dbc_owned_power_off() { echo UNSAFE; }
write_dbc_updater_mask_helper() { :; }
upload_to_dbc() { ${maskFailure == 'upload' ? 'return 1' : ':'}; }
dbc_ssh_once_bounded() {
  case "\$2" in
    'mender-update install '*) echo installed; return 0 ;;
    *) echo mask-dispatch >&2; return ${maskFailure == 'timeout' ? 124 : maskFailure == 'transport' ? 1 : 0} ;;
  esac
}
${template.substring(start, end)}
''');
      expect(result.exitCode, 1, reason: result.stderr.toString());
      expect(result.stdout, contains('installed'));
      expect(result.stdout, isNot(contains('UNSAFE')));
      expect('mask-dispatch'.allMatches(result.stderr.toString()).length, maskFailure == 'upload' ? 0 : 1);
      expect(File('${root.path}/control/state').readAsStringSync().trim(), maskFailure == 'upload' ? 'artifact-installed' : 'mask-unknown');
      expect(run('dbc_control_acquire outer').exitCode, isNot(0));
      expect(run('DBC_CONTROL_ACQUIRED=yes; dbc_control_release').exitCode, isNot(0));
    });
  }

  test('activation accepted before transport loss is dispatched only once', () {
    final template = File('assets/trampoline.sh.template').readAsStringSync();
    final helperStart = template.indexOf('dbc_ssh_once_bounded()');
    final helperEnd = template.indexOf('\n# The dashboard', helperStart);
    final start = template.indexOf('    dbc_control_check || artifact_fail "error: bootstrap control lost before activation"');
    final end = template.indexOf('\n  CURRENT_STAGE="verifying-dbc-artifact"', start);
    stub('ssh', 'echo accepted >> "\$TEST_ROOT/reboots"; exit 1');
    final result = run('''
${template.substring(helperStart, helperEnd)}
dbc_control_acquire outer
DBC_VEHICLE_UPDATE=bootstrap
DBC_IP=example
LOG='${root.path}/activation.log'
artifact_fail() { exit 99; }
if true; then
${template.substring(start, end)}
echo read-only-health-reconciliation
''');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File('${root.path}/reboots').readAsLinesSync(), ['accepted']);
    expect(result.stdout, contains('read-only-health-reconciliation'));
    expect(File('${root.path}/control/state').readAsStringSync().trim(), 'activation-unknown');
  });

  test('upgrade recovery cannot issue GPIO or forced power-off', () {
    final template = File('assets/trampoline.sh.template').readAsStringSync();
    final start = template.indexOf('dbc_owned_power_off()');
    final end = template.indexOf('\n# The install is still running', start);
    final result = run('''
${template.substring(start, end)}
DBC_VEHICLE_UPDATE=none
dbc_power_off() { echo UNSAFE; }
dbc_power_off_force() { echo UNSAFE; }
if dbc_owned_power_off; then exit 1; fi
''');
    expect(result.exitCode, 0);
    expect(result.stdout, isNot(contains('UNSAFE')));
  });

  test('post-activation artifact failure retains power and failure stage', () {
    final template = File('assets/trampoline.sh.template').readAsStringSync();
    final start = template.indexOf('artifact_fail()');
    final end = template.indexOf('\n# Install the DBC artifact', start);
    final result = run('''
${template.substring(start, end)}
DBC_TARGET_MASKED=yes
DBC_ACTIVATION_DISPATCHED=yes
DBC_UPDATE_CMD=''
MODE=flash
CURRENT_STAGE=committing-dbc
dbc_install_diagnostics() { :; }
dbc_fail_say() { :; }
write_status() { echo "stage=\$CURRENT_STAGE"; }
signal_error() { :; }
dbc_update_complete() { echo UNSAFE; }
dbc_power_off() { echo UNSAFE; }
artifact_fail 'error: transport lost'
''');
    expect(result.exitCode, 1);
    expect(result.stdout, contains('stage=committing-dbc'));
    expect(result.stdout, isNot(contains('UNSAFE')));
  });
}

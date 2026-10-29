import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late File helper;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dbc-link-');
    Directory('${root.path}/control').createSync();
    File('${root.path}/control/state').writeAsStringSync('artifact-install\n');
    File('${root.path}/clock').writeAsStringSync('100\n');
    File('${root.path}/role').writeAsStringSync('gadget\n');
    File('${root.path}/udc').writeAsStringSync('configured\n');
    File('${root.path}/calls').writeAsStringSync('');
    var source = File('assets/device.sh').readAsStringSync().replaceAll(
      '/data/librescoot-installer/dbc-control',
      '${root.path}/control',
    );
    for (final path in [
      '/sys/kernel/debug/ci_hdrc.0/role',
      '/sys/kernel/debug/usb/ci_hdrc.0/role',
      '/sys/bus/platform/devices/ci_hdrc.0/role',
    ]) {
      source = source.replaceAll(path, '${root.path}/role');
    }
    helper = File('${root.path}/device.sh')..writeAsStringSync(source);
  });
  tearDown(() => root.deleteSync(recursive: true));

  ProcessResult run(String scenario) => Process.runSync('sh', [
    '-c',
    '''
set -eu
TEST_ROOT='${root.path}'
INSTALLER_DIR="\$TEST_ROOT"
RUN_ID=test-run
USB_HANDOFF_UDC_STATE="\$TEST_ROOT/udc"
. '${helper.path}'
DBC_VEHICLE_UPDATE=direct
MODE=flash
DBC_MENDER=firmware.mender
log() { echo "\$*"; }
handoff_now() { cat "\$TEST_ROOT/clock"; }
sleep() {
  echo \$((\$(handoff_now) + \$1)) > "\$TEST_ROOT/clock"
}
dbc_control_check() { [ ! -f "\$TEST_ROOT/lost-control" ]; }
device_timeout() { shift; "\$@"; }
ip() {
  echo "ip \$*" >> "\$TEST_ROOT/calls"
  case "\$*" in
    'route get '*) echo '192.168.7.2 dev usb0 src 192.168.7.1' ;;
  esac
}
ping() { [ -f "\$TEST_ROOT/peer" ]; }
ssh() {
  echo "ssh \$*" >> "\$TEST_ROOT/calls"
  [ -f "\$TEST_ROOT/peer" ] && [ ! -f "\$TEST_ROOT/wrong-host" ]
}
rmmod() {
  echo "rmmod \$*" >> "\$TEST_ROOT/calls"
  [ ! -f "\$TEST_ROOT/unload-fails" ]
}
modprobe() {
  echo "modprobe \$*" >> "\$TEST_ROOT/calls"
  if [ -f "\$TEST_ROOT/rebind-recovers" ]; then touch "\$TEST_ROOT/peer"; fi
}
dbc_power_set() { echo "power \$*" >> "\$TEST_ROOT/calls"; }
dbc_owned_power_off() { echo unsafe-power-cycle >> "\$TEST_ROOT/calls"; return 1; }
$scenario
''',
  ]);

  String calls() => File('${root.path}/calls').readAsStringSync();

  test(
    'waits for a stable identified peer without resetting a healthy link',
    () {
      final result = run(r'touch "$TEST_ROOT/peer"; dbc_wait_install_link 60');
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('stable for 10 seconds'));
      expect(calls(), isNot(contains('rmmod')));
      expect(calls(), isNot(contains('power')));
    },
  );

  test('recovers no-route after rebind without needing sync or power-off', () {
    final result = run(
      r'touch "$TEST_ROOT/rebind-recovers"; dbc_wait_install_link 90',
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls(), contains('rmmod g_ether'));
    expect(calls(), contains('modprobe g_ether'));
    expect(calls(), contains('ip addr replace 192.168.7.1/24 dev usb0'));
    expect(calls(), isNot(contains(' sync')));
    expect(calls(), isNot(contains('power')));
    expect(
      File('${root.path}/control/state').readAsStringSync(),
      'artifact-install\n',
    );
  });

  test('configured UDC alone cannot satisfy dashboard readiness', () {
    final result = run('dbc_wait_install_link 150');
    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('UDC=configured'));
    expect(result.stdout, contains('retaining power and installation state'));
    expect('rmmod'.allMatches(calls()).length, 3);
    expect(calls(), isNot(contains('power')));
    expect(File('${root.path}/control/state').existsSync(), isTrue);
  });

  test('a reachable host with the wrong identity is not the DBC', () {
    final result = run(
      r'touch "$TEST_ROOT/peer" "$TEST_ROOT/wrong-host"; dbc_wait_install_link 45',
    );
    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains('link stable')));
  });

  test('never rebinds during an artifact with unknown write outcome', () {
    final result = run(
      r'echo artifact-install-unknown > "$DBC_CONTROL_DIR/state"; dbc_wait_install_link 45',
    );
    expect(result.exitCode, isNot(0));
    expect(calls(), isNot(contains('rmmod')));
  });

  test('ownership loss stops the wait without changing USB or power', () {
    final result = run(
      r'touch "$TEST_ROOT/lost-control"; dbc_wait_install_link 45',
    );
    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('exclusive DBC control lost'));
    expect(calls(), isNot(contains('rmmod')));
    expect(calls(), isNot(contains('power')));
  });

  test('fresh laptop presence prevents a gadget reset', () {
    final result = run(r'''
mkdir -p "$INSTALLER_DIR/handoff-$RUN_ID"
handoff_now > "$INSTALLER_DIR/handoff-$RUN_ID/heartbeat"
dbc_wait_install_link 45
''');
    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('laptop reconnected'));
    expect(calls(), isNot(contains('rmmod')));
  });

  test('does not change USB role when it is not gadget', () {
    final result = run(
      r'echo host > "$TEST_ROOT/role"; dbc_wait_install_link 45',
    );
    expect(result.exitCode, isNot(0));
    expect(calls(), isNot(contains('rmmod')));
  });

  test('failed module removal does not run the remaining reset sequence', () {
    final result = run(
      r'touch "$TEST_ROOT/unload-fails"; dbc_wait_install_link 45',
    );
    expect(result.exitCode, isNot(0));
    expect(calls(), contains('rmmod g_ether'));
    expect(calls(), isNot(contains('modprobe g_ether')));
  });

  test(
    'generated phase retains state and stops before upload on link failure',
    () {
      final source = File('assets/trampoline.sh.template').readAsStringSync();
      final start = source.indexOf('log "  powering on DBC..."');
      final end = source.indexOf('log "  DBC reachable"', start);
      final result = run('''
write_run_state() { echo "stage:\$*"; }
write_status() { echo "status:\$*"; }
signal_error() { echo error-signal; }
front_pulse_stop() { echo peer-confirmed; }
${source.substring(start, end)}
echo upload-started
''');
      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('stage:waiting-dbc-link'));
      expect(
        result.stdout,
        contains('status:error: dashboard connection unavailable'),
      );
      expect(result.stdout, contains('error-signal'));
      expect(result.stdout, isNot(contains('upload-started')));
      expect(result.stdout, isNot(contains('peer-confirmed')));
      expect(calls(), isNot(contains('unsafe-power-cycle')));
      expect(calls(), isNot(contains('power 0')));
    },
  );
}

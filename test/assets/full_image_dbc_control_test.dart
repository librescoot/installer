import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late File helper;
  late Map<String, String> env;

  void stub(String name, String body) {
    final f = File('${root.path}/bin/$name')
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

  String calls() => File('${root.path}/calls').readAsStringSync();
  File state(String unit, {bool remote = false}) =>
      File('${root.path}/${remote ? 'remote' : 'local'}-$unit');

  setUp(() {
    root = Directory.systemTemp.createTempSync('full-image-dbc-');
    Directory('${root.path}/bin').createSync();
    File('${root.path}/calls').writeAsStringSync('');
    helper = File('${root.path}/device.sh')
      ..writeAsStringSync(
        File('assets/device.sh')
            .readAsStringSync()
            .replaceAll(
              '/data/librescoot-installer/dbc-control',
              '${root.path}/control',
            )
            .replaceAll('/etc/systemd/system/', '${root.path}/units/')
            .replaceAll('/sys/class/gpio', '${root.path}/gpio')
            .replaceAll(
              '/run/librescoot-installer-dbc',
              '${root.path}/remote-control',
            ),
      );
    for (final unit in [
      'librescoot-vehicle.service',
      'librescoot-update.service',
      'librescoot-pm.service',
    ]) {
      state(unit).writeAsStringSync('active\n');
      state(unit, remote: true).writeAsStringSync('active\n');
    }
    stub('mender-update', 'echo release-v1.4.0');
    stub('lsc', 'echo "lsc \$*" >> "\$TEST_ROOT/calls"');
    stub('sleep', 'exit 0');
    stub('timeout', 'shift; exec "\$@"');
    stub('sync', 'echo "sync \${REMOTE:-local}" >> "\$TEST_ROOT/calls"');
    stub('ssh', '''
echo "ssh \$*" >> "\$TEST_ROOT/calls"
[ "\${SSH_FAIL:-no}" != yes ] || exit 1
for command in "\$@"; do :; done
REMOTE=remote sh -c "\$command"
''');
    stub('redis-cli', '''
case "\$*" in
  *'hget vehicle state')
    if [ -f "\$TEST_ROOT/vehicle-state" ]; then cat "\$TEST_ROOT/vehicle-state"
    else echo "\${VEHICLE_STATE:-stand-by}"; fi ;;
  *'hget vehicle dbc-updating') echo "\${UPDATING:-false}" ;;
  *'hget ota heartbeat-owner:dbc') echo "\${OWNER:-}" ;;
  *'hget ota status:'*) echo "\${OTA_STATUS:-idle}" ;;
  *) exit 90 ;;
esac
''');
    stub('systemctl', '''
side=\${REMOTE:-local}
echo "\$side systemctl \$*" >> "\$TEST_ROOT/calls"
for unit in "\$@"; do :; done
file="\$TEST_ROOT/\$side-\$unit"
case "\$1" in
  show)
    case "\$3" in
      LoadState)
        if [ -e "\$file.masked" ]; then echo masked
        elif [ -f "\$file" ]; then echo loaded
        else echo not-found; fi ;;
      ActiveState) cat "\$file" 2>/dev/null || echo inactive ;;
      *) exit 91 ;;
    esac ;;
  stop)
    [ "\${STOP_FAIL:-}" != "\$side:\$unit" ] || exit 1
    echo inactive > "\$file"
    if [ "\$side:\$unit" = local:librescoot-vehicle.service ] && [ -n "\${RACE_STATE:-}" ]; then
      echo "\$RACE_STATE" > "\$TEST_ROOT/vehicle-state"
    fi ;;
  start)
    [ "\${START_FAIL:-}" != "\$unit" ] || exit 1
    echo active > "\$file" ;;
  mask) touch "\$file.masked" ;;
  unmask) rm -f "\$file.masked" ;;
  daemon-reload) : ;;
  *) exit 92 ;;
esac
''');
    env = {'PATH': '${root.path}/bin:/usr/bin:/bin', 'TEST_ROOT': root.path};
  });
  tearDown(() => root.deleteSync(recursive: true));

  test(
    'reserves full-image control without stopping services before handoff',
    () {
      final result = run(
        'dbc_control_acquire outer; dbc_control_check; dbc_power_set 1; dbc_control_release',
      );
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(calls(), contains('lsc --redis-addr localhost:6379 dbc on'));
      expect(calls(), isNot(contains('systemctl stop')));
      expect(Directory('${root.path}/control').existsSync(), isFalse);
    },
  );

  for (final extra in <Map<String, String>>[
    {'VEHICLE_STATE': 'ready-to-drive'},
    {'VEHICLE_STATE': 'parked'},
    {'OTA_STATUS': 'installing'},
    {'OTA_STATUS': 'pending-reboot'},
    {'UPDATING': 'true'},
    {'OWNER': 'foreign'},
  ]) {
    test('rejects occupied or unlocked full-image runtime $extra', () {
      expect(run('dbc_control_acquire outer', extra: extra).exitCode, isNot(0));
      expect(calls(), isNot(contains('systemctl stop')));
      expect(Directory('${root.path}/control').existsSync(), isFalse);
    });
  }

  test('an unlock racing takeover restores the vehicle state machine', () {
    final result = run(
      'dbc_control_acquire outer; ! dbc_control_prepare; ! dbc_control_release',
      extra: {'RACE_STATE': 'parked'},
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
      state('librescoot-vehicle.service').readAsStringSync().trim(),
      'active',
    );
    expect(
      calls(),
      contains('local systemctl start librescoot-vehicle.service'),
    );
    expect(File('${root.path}/control/isolated').existsSync(), isFalse);
  });

  test('an already identified UMS dashboard needs no remote shell', () {
    final result = run(
      'dbc_control_acquire outer; DBC_ALREADY_UMS=yes; dbc_control_prepare; dbc_control_check',
      extra: {'SSH_FAIL': 'yes'},
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls(), isNot(contains('ssh ')));
  });

  test(
    'generated dashboard phase resumes full-image control during MDB installation',
    () {
      expect(
        run(
          'dbc_control_acquire outer; dbc_control_prepare; dbc_control_record handoff',
        ).exitCode,
        0,
      );
      final template = File('assets/trampoline.sh.template').readAsStringSync();
      final start = template.indexOf(
        'DBC_VEHICLE_UPDATE="\${DBC_VEHICLE_UPDATE:-none}"',
      );
      final end = template.indexOf('\n# The install is still running', start);
      final result = run(
        '''
${template.substring(start, end)}
dbc_update_start
[ "\$DBC_VEHICLE_UPDATE" = direct ]
[ "\$DBC_CONTROL_MODE" = maintenance ]
dbc_control_check
''',
        extra: {'OTA_STATUS': 'installing'},
      );
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    },
  );

  test(
    'isolates services after syncing the dashboard and persists across handoff',
    () {
      var result = run(
        'dbc_control_acquire outer; dbc_control_prepare; dbc_control_record handoff',
      );
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        calls().indexOf('sync remote'),
        lessThan(
          calls().indexOf('local systemctl stop librescoot-vehicle.service'),
        ),
      );
      for (final unit in [
        'librescoot-pm.service',
        'librescoot-update.service',
        'librescoot-vehicle.service',
      ]) {
        expect(state(unit).readAsStringSync().trim(), 'inactive');
        expect(
          File(
            '${root.path}/units/$unit.d/90-installer-dbc-run-1.conf',
          ).readAsStringSync(),
          contains('ConditionPathExists=!${root.path}/control/owner'),
        );
      }
      result = run(
        'dbc_control_acquire handoff; [ "\$DBC_CONTROL_MODE" = maintenance ]; dbc_control_check',
      );
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(run('dbc_control_acquire handoff').exitCode, isNot(0));
      expect(
        run('RUN_ID=other; dbc_control_acquire handoff').exitCode,
        isNot(0),
      );
    },
  );

  test('same-run pre-write retry resumes the consumed handoff', () {
    expect(
      run('''
dbc_control_acquire outer
dbc_control_prepare
dbc_control_record handoff
dbc_control_acquire handoff
''').exitCode,
      0,
    );
    final template = File('assets/trampoline.sh.template').readAsStringSync();
    final start = template.indexOf(
      'DBC_VEHICLE_UPDATE="\${DBC_VEHICLE_UPDATE:-none}"',
    );
    final end = template.indexOf('\n# The install is still running', start);
    final result = run('''
${template.substring(start, end)}
ONBOOT_TRIES=2
dbc_update_start
dbc_control_check
[ "\$DBC_CONTROL_MODE" = maintenance ]
''');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
      run('RUN_ID=foreign; dbc_control_acquire resume').exitCode,
      isNot(0),
    );
  });

  test('unreachable dashboard is not power-cut without syncing', () {
    final template = File('assets/trampoline.sh.template').readAsStringSync();
    final start = template.indexOf('dbc_owned_power_off() {');
    final end = template.indexOf('\n}\n', start) + 3;
    final result = run('''
${template.substring(start, end)}
DBC_VEHICLE_UPDATE=direct
dbc_control_check() { return 0; }
dbc_ssh_once_bounded() { return 1; }
dbc_power_off() { echo unsafe-power-off >> "\$TEST_ROOT/calls"; }
! dbc_owned_power_off
''');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('retaining power and ownership'));
    expect(calls(), isNot(contains('unsafe-power-off')));
  });

  test('retry can consume a handoff not reached by the first attempt', () {
    final result = run('''
dbc_control_acquire outer
dbc_control_prepare
dbc_control_record handoff
dbc_control_acquire resume
dbc_control_check
''');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('retry validates isolation before consuming the handoff', () {
    expect(
      run('''
dbc_control_acquire outer
dbc_control_prepare
dbc_control_record handoff
''').exitCode,
      0,
    );
    state('librescoot-vehicle.service').writeAsStringSync('active\n');
    expect(run('dbc_control_acquire resume').exitCode, isNot(0));
    expect(Directory('${root.path}/control/phase').existsSync(), isFalse);
    expect(
      File('${root.path}/control/state').readAsStringSync().trim(),
      'handoff',
    );
  });

  for (final boundary in [
    'artifact-install-unknown',
    'artifact-installed',
    'mask-unknown',
    'mask-prepared',
    'activation-unknown',
    'commit-unknown',
    'committed',
    'raw-write-unknown',
    'raw-written',
    'ums-preparing',
  ]) {
    test('retry refuses uncertain or completed write boundary $boundary', () {
      expect(
        run('''
dbc_control_acquire outer
dbc_control_prepare
dbc_control_record handoff
dbc_control_acquire handoff
dbc_control_record $boundary
''').exitCode,
        0,
      );
      expect(run('dbc_control_acquire resume').exitCode, isNot(0));
    });
  }

  test('restoration tolerates a GPIO export lost across reboot', () {
    final result = run('''
dbc_control_acquire outer
dbc_control_prepare
rm "\$DBC_CONTROL_DIR/remote"
touch "\$DBC_CONTROL_DIR/gpio"
dbc_control_record complete
dbc_control_release
''');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(Directory('${root.path}/control').existsSync(), isFalse);
  });

  test('full-image direct control uses GPIO, never lsc, after isolation', () {
    final result = run('''
dbc_control_acquire outer
dbc_control_prepare
mkdir -p '${root.path}/gpio/gpio50'
echo out > '${root.path}/gpio/gpio50/direction'
echo 0 > '${root.path}/gpio/gpio50/value'
touch "\$DBC_CONTROL_DIR/gpio"
dbc_power_set 1
[ "\$(cat '${root.path}/gpio/gpio50/value')" = 1 ]
''');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls(), isNot(contains('lsc --redis')));
  });

  test('never takes an already exported GPIO from another owner', () {
    Directory('${root.path}/gpio/gpio50').createSync(recursive: true);
    expect(
      run('dbc_control_acquire outer; dbc_control_prepare').exitCode,
      isNot(0),
    );
    expect(calls(), isNot(contains('systemctl stop')));
  });

  for (final failure in [
    {'SSH_FAIL': 'yes'},
    {'STOP_FAIL': 'local:librescoot-vehicle.service'},
    {'STOP_FAIL': 'remote:librescoot-update.service'},
  ]) {
    test('failed takeover retains recovery evidence $failure', () {
      final result = run(
        'dbc_control_acquire outer; ! dbc_control_prepare; ! dbc_control_release',
        extra: failure,
      );
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File('${root.path}/control/state').readAsStringSync().trim(),
        'maintenance-preparing',
      );
      expect(run('dbc_control_acquire outer').exitCode, isNot(0));
    });
  }

  test('lost isolation marker never falls back to lsc', () {
    final result = run('''
dbc_control_acquire outer
dbc_control_prepare
rm "\$DBC_CONTROL_DIR/isolated"
! dbc_power_set 0
''');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls(), isNot(contains('lsc --redis')));
  });

  test('failed service restoration retains the recovery record', () {
    final result = run(
      '''
dbc_control_acquire outer
dbc_control_prepare
rm "\$DBC_CONTROL_DIR/remote"
dbc_control_record complete
! dbc_control_release
''',
      extra: {'START_FAIL': 'librescoot-vehicle.service'},
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
      File('${root.path}/control/owner').readAsStringSync().trim(),
      'run-1',
    );
  });

  for (final loss in ['service', 'drop-in', 'owner']) {
    test('detects loss of maintenance isolation: $loss', () {
      expect(
        run(
          'dbc_control_acquire outer; dbc_control_prepare; dbc_control_record handoff',
        ).exitCode,
        0,
      );
      switch (loss) {
        case 'service':
          state('librescoot-vehicle.service').writeAsStringSync('active\n');
        case 'drop-in':
          File(
            '${root.path}/units/librescoot-update.service.d/90-installer-dbc-run-1.conf',
          ).deleteSync();
        case 'owner':
          File('${root.path}/control/owner').writeAsStringSync('foreign\n');
      }
      expect(run('dbc_control_acquire handoff').exitCode, isNot(0));
    });
  }

  test(
    'restores only changed services after success, leaving PM for finalization',
    () {
      state('librescoot-update.service').writeAsStringSync('inactive\n');
      final result = run('''
dbc_control_acquire outer
dbc_control_prepare
# Successful raw flashing replaces the original dashboard runtime.
rm "\$DBC_CONTROL_DIR/remote"
dbc_control_record handoff
''');
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final finish = run('''
dbc_control_acquire handoff
dbc_control_record committed
dbc_control_release
[ -d "\$DBC_CONTROL_DIR" ]
dbc_control_record complete
dbc_control_release
''');
      expect(finish.exitCode, 0, reason: '${finish.stdout}${finish.stderr}');
      expect(
        state('librescoot-vehicle.service').readAsStringSync().trim(),
        'active',
      );
      expect(
        state('librescoot-update.service').readAsStringSync().trim(),
        'inactive',
      );
      expect(
        state('librescoot-pm.service').readAsStringSync().trim(),
        'inactive',
      );
      expect(Directory('${root.path}/control').existsSync(), isFalse);
      expect(
        File(
          '${root.path}/units/librescoot-vehicle.service.d/90-installer-dbc-run-1.conf',
        ).existsSync(),
        isFalse,
      );
    },
  );
}

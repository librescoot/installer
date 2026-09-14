import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _onbootLifecycle(String source) {
  final start = source.indexOf(
    'DBC_VEHICLE_UPDATE="\${DBC_VEHICLE_UPDATE:-none}"',
  );
  final end = source.indexOf('\n# The install is still running', start);
  if (start < 0 || end < 0) {
    throw StateError('generated lifecycle helpers not found');
  }
  return source.substring(start, end);
}

String _outerLifecycle(String source) {
  final start = source.indexOf('DBC_VEHICLE_UPDATE=none');
  final end = source.indexOf('\ncollect_mdb_diagnostics()', start);
  if (start < 0 || end < 0) {
    throw StateError('outer lifecycle helpers not found');
  }
  return source.substring(start, end);
}

void main() {
  late Directory root;
  late Directory bin;
  late File vehicleState;
  late File heartbeat;
  late File events;
  late Map<String, String> environment;
  late String lifecycle;

  setUp(() {
    root = Directory.systemTemp.createTempSync('trampoline_safety_');
    bin = Directory('${root.path}/bin')..createSync();
    vehicleState = File('${root.path}/vehicle-state')
      ..writeAsStringSync('false');
    heartbeat = File('${root.path}/heartbeat')..writeAsStringSync('');
    events = File('${root.path}/events')..writeAsStringSync('');
    final evalCount = File('${root.path}/eval-count')..writeAsStringSync('0');
    final clock = File('${root.path}/clock')..writeAsStringSync('1000');
    final redis = File('${bin.path}/redis-cli')
      ..writeAsStringSync(r'''#!/bin/sh
if [ "$1" = -h ]; then shift 2; fi
if [ "$1" = --raw ]; then shift; fi
case "$1" in
  hget)
    cat "$VEHICLE_STATE"
    ;;
  lpush)
    case "$3" in
      start-dbc)
        echo true > "$VEHICLE_STATE"
        echo start >> "$EVENTS"
        ;;
      complete-dbc)
        [ ! -s "$HEARTBEAT" ] || exit 40
        echo false > "$VEHICLE_STATE"
        echo complete >> "$EVENTS"
        ;;
      *) exit 41 ;;
    esac
    echo 1
    ;;
  eval)
    count=$(cat "$EVAL_COUNT")
    count=$((count + 1))
    echo "$count" > "$EVAL_COUNT"
    if [ "${REDIS_FAIL_EVAL:-}" = yes ] ||
       { [ -n "${REDIS_FAIL_AFTER:-}" ] && [ "$count" -gt "$REDIS_FAIL_AFTER" ]; }; then
      [ "${REDIS_EXPIRE_ON_FAIL:-}" = yes ] && echo false > "$VEHICLE_STATE"
      exit 42
    fi
    if [ "${6:-}" = heartbeat-owner:dbc ]; then
      : > "$HEARTBEAT"
      echo heartbeat: >> "$EVENTS"
      echo cleared
    else
      value="${6:-}"
      printf '%s' "$value" > "$HEARTBEAT"
      printf 'heartbeat:%s\n' "$value" >> "$EVENTS"
      printf '%s\n' "$value"
    fi
    ;;
  *) exit 43 ;;
esac
''');
    final date = File('${bin.path}/date')
      ..writeAsStringSync(r'''#!/bin/sh
now=$(cat "$CLOCK")
echo $((now + 1)) > "$CLOCK"
echo "$now"
''');
    Process.runSync('chmod', ['755', redis.path, date.path]);
    environment = {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'VEHICLE_STATE': vehicleState.path,
      'HEARTBEAT': heartbeat.path,
      'EVENTS': events.path,
      'EVAL_COUNT': evalCount.path,
      'CLOCK': clock.path,
      'DBC_HEARTBEAT_INTERVAL': '0.02',
    };
    lifecycle = _onbootLifecycle(
      File('assets/trampoline.sh.template').readAsStringSync(),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProcessResult run(
    String body, {
    Map<String, String> extraEnvironment = const {},
  }) {
    final script = File('${root.path}/scenario.sh')
      ..writeAsStringSync('''#!/bin/sh
set -eu
RUN_ID=run-1
log() { :; }
$lifecycle
$body
''');
    return Process.runSync(
      'sh',
      [script.path],
      environment: {...environment, ...extraEnvironment},
    );
  }

  test('acknowledged lifecycle publishes until clear-before-complete', () {
    final result = run('''
dbc_update_start
sleep 0.09
dbc_update_complete
[ "\$(cat "\$VEHICLE_STATE")" = false ]
[ ! -s "\$HEARTBEAT" ]
''');

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final recorded = events.readAsLinesSync();
    expect(recorded.first, 'start');
    expect(
      recorded.where((event) => event.startsWith('heartbeat:')).length,
      greaterThanOrEqualTo(2),
    );
    expect(recorded[recorded.length - 2], 'heartbeat:');
    expect(recorded.last, 'complete');
  });

  test('generated handoff restarts heartbeat for an active lifecycle', () {
    vehicleState.writeAsStringSync('true');

    final result = run('''
DBC_VEHICLE_UPDATE=active
dbc_update_start
sleep 0.03
dbc_update_complete
''');

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final recorded = events.readAsLinesSync();
    expect(recorded, isNot(contains('start')));
    expect(recorded.first, startsWith('heartbeat:'));
    expect(recorded[recorded.length - 2], 'heartbeat:');
    expect(recorded.last, 'complete');
  });

  test('an expired hold cannot resume without a new heartbeat', () {
    final result = run(
      '''
dbc_update_start
sleep 0.05
if dbc_update_start; then exit 52; fi
''',
      extraEnvironment: {
        'REDIS_FAIL_AFTER': '1',
        'REDIS_EXPIRE_ON_FAIL': 'yes',
      },
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      events.readAsLinesSync().where((event) => event == 'start').length,
      2,
    );
  });

  test('heartbeat establishment failure never releases the lifecycle', () {
    final result = run(
      '''
if dbc_update_start; then exit 50; fi
if dbc_update_complete; then exit 51; fi
[ "\$(cat "\$VEHICLE_STATE")" = true ]
''',
      extraEnvironment: {'REDIS_FAIL_EVAL': 'yes'},
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(events.readAsLinesSync(), ['start']);
  });

  test('a heartbeat failure stops an active flash process', () {
    lifecycle = _outerLifecycle(
      File('assets/trampoline.sh.template').readAsStringSync(),
    );
    final result = run(
      '''
DBC_VEHICLE_UPDATE=active
echo true > "\$VEHICLE_STATE"
dbc_update_heartbeat_claim
sleep 30 &
DBC_HEARTBEAT_PID=\$!
sleep 30 &
flash_pid=\$!
set +e
wait_flash_with_dbc_heartbeat "\$flash_pid"
rc=\$?
set -e
[ "\$rc" -eq 125 ]
! kill -0 "\$flash_pid" 2>/dev/null
kill "\$DBC_HEARTBEAT_PID" 2>/dev/null || true
wait "\$DBC_HEARTBEAT_PID" 2>/dev/null || true
''',
      extraEnvironment: {'REDIS_FAIL_AFTER': '1'},
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('diagnostic marker is namespaced by installer run id', () {
    final source = File('assets/trampoline.sh.template').readAsStringSync();
    expect(source, contains('/data/installer/diagnostic-run-id'));
    expect(
      source,
      contains('diagnostic-run-id 2>/dev/null)\\" = \'\$RUN_ID\''),
    );
    expect(
      source,
      contains(
        "printf '%s\\\\n' '\$RUN_ID' > /data/installer/diagnostic-run-id",
      ),
    );
  });
}

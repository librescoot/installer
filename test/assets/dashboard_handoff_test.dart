import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  final helpers = File('assets/device.sh').absolute.path;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('handoff-');
  });
  tearDown(() => root.delete(recursive: true));

  Future<ProcessResult> run(String body) async {
    final script = File('${root.path}/case.sh');
    await script.writeAsString('''
. '$helpers'
HANDOFF_DIR='${root.path}/session'
mkdir -p "\$HANDOFF_DIR"
RUN_ID=test-run
MODE=flash
USB_HANDOFF_UDC_STATE='${root.path}/udc'
printf 'configured\\n' > "\$USB_HANDOFF_UDC_STATE"
ticks=100
handoff_now() { echo "\$ticks"; }
sleep() {
  ticks=\$((ticks + 1))
  if [ "\$ticks" -ge 180 ]; then mkdir -p "\$HANDOFF_DIR/decision"; fi
}
log() { echo "\$*"; }
ping() { return 1; }
ip() { echo '192.168.7.2 dev usb0'; }
ssh() { return 1; }
timeout() { shift; "\$@"; }
rmmod() { echo rebind; }
modprobe() { :; }
usb0_up() { :; }
role_write() { echo "role=\$1"; }
restore_gadget() { echo gadget-restored; }
lsusb() { :; }
$body
''');
    return Process.run('timeout', ['5', 'sh', script.path]);
  }

  test(
    'fresh installer lease waits without rebinding or granting a write',
    () async {
      final result = await run(r'''
    echo "$ticks" > "$HANDOFF_DIR/heartbeat"
    sleep() {
      ticks=$((ticks + 60))
      echo "$ticks" > "$HANDOFF_DIR/heartbeat"
      [ "$ticks" -lt 3700 ] || mkdir -p "$HANDOFF_DIR/decision"
    }
    wait_for_dashboard_connection
    ''');
      expect(result.exitCode, 2);
      expect(result.stdout, isNot(contains('rebind')));
      expect(
        File('${root.path}/session/ready').readAsStringSync().trim(),
        'test-run',
      );
      expect(File('${root.path}/session/decision/state').existsSync(), isFalse);
    },
  );

  test('lost heartbeat and unplugged cable never grant installation', () async {
    final result = await run(r'''
    echo 1 > "$HANDOFF_DIR/heartbeat"
    echo 'not attached' > "$USB_HANDOFF_UDC_STATE"
    wait_for_dashboard_connection
    ''');
    expect(result.exitCode, 2);
    expect(result.stdout, contains('gadget-restored'));
    expect(File('${root.path}/session/decision/state').existsSync(), isFalse);
  });

  for (final state in ['suspended', 'addressed', 'default', 'unknown']) {
    test('$state does not authorize installation or host probing', () async {
      final result = await run(
        'echo $state > "\$USB_HANDOFF_UDC_STATE"\nwait_for_dashboard_connection',
      );
      expect(result.exitCode, 2);
      expect(result.stdout, isNot(contains('role=host')));
      expect(result.stdout, isNot(contains('rebind')));
    });
  }

  test('failed readiness persistence cannot authorize installation', () async {
    final result = await run(r'''
    mkdir "$HANDOFF_DIR/ready"
    ping() { return 0; }
    ssh() { return 0; }
    wait_for_dashboard_connection
    ''');
    expect(result.exitCode, 1);
    expect(File('${root.path}/session/decision').existsSync(), isFalse);
  });

  test('renewed installer lease during recognition keeps waiting', () async {
    final result = await run(r'''
    ping() { return 0; }
    ssh() { echo "$ticks" > "$HANDOFF_DIR/heartbeat"; return 0; }
    wait_for_dashboard_connection
    ''');
    expect(result.exitCode, 2);
    expect(File('${root.path}/session/decision/state').existsSync(), isFalse);
  });

  test('unreadable UDC state does not mean disconnection', () async {
    final result = await run(r'''
    rm "$USB_HANDOFF_UDC_STATE"
    wait_for_dashboard_connection
    ''');
    expect(result.exitCode, 2);
    expect(result.stdout, isNot(contains('role=host')));
  });

  test(
    'rapid swap with continuous configured state is recognized after rebind',
    () async {
      final result = await run(r'''
    recognized=no
    modprobe() { recognized=yes; }
    ping() { [ "$recognized" = yes ]; }
    ssh() { [ "$recognized" = yes ]; }
    wait_for_dashboard_connection
    ''');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('rebind'));
      expect(
        File('${root.path}/session/decision/state').readAsStringSync().trim(),
        'active',
      );
    },
  );

  test('USB ping alone does not identify the dashboard', () async {
    final result = await run(
      'ping() { return 0; }\nwait_for_dashboard_connection',
    );
    expect(result.exitCode, 2);
  });

  test(
    'dashboard responding on another interface does not grant handoff',
    () async {
      final result = await run(r'''
    ip() { echo '192.168.7.2 dev ppp0'; }
    ping() { return 0; }
    ssh() { return 0; }
    wait_for_dashboard_connection
    ''');
      expect(result.exitCode, 2);
    },
  );

  test(
    'artifact upgrade accepts a positively identified PPP dashboard',
    () async {
      final result = await run(r'''
    MODE=upgrade
    DBC_MENDER=/data/test.mender
    ip() { echo '192.168.7.2 via 192.168.8.2 dev ppp0'; }
    ping() { [ "$2" = ppp0 ]; }
    ssh() { return 0; }
    wait_for_dashboard_connection
    ''');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('Dashboard identified over PPP'));
      expect(result.stdout, isNot(contains('rebind')));
      expect(
        File('${root.path}/session/decision/state').readAsStringSync().trim(),
        'active',
      );
    },
  );

  test('PPP does not grant a maps-only handoff', () async {
    final result = await run(r'''
    MODE=upgrade
    DBC_MENDER=""
    ip() { echo '192.168.7.2 dev ppp0'; }
    ping() { return 0; }
    ssh() { return 0; }
    wait_for_dashboard_connection
    ''');
    expect(result.exitCode, 2);
    expect(File('${root.path}/session/decision/state').existsSync(), isFalse);
  });

  test(
    'PPP reachability without dashboard identity never grants upgrade',
    () async {
      final result = await run(r'''
    MODE=upgrade
    DBC_MENDER=/data/test.mender
    ip() { echo '192.168.7.2 dev ppp0'; }
    ping() { return 0; }
    wait_for_dashboard_connection
    ''');
      expect(result.exitCode, 2);
      expect(File('${root.path}/session/decision/state').existsSync(), isFalse);
    },
  );

  for (final interface in ['ppp01', 'wwan0']) {
    test('upgrade rejects $interface as a PPP fallback route', () async {
      final result = await run('''
      MODE=upgrade
      DBC_MENDER=/data/test.mender
      ip() { echo '192.168.7.2 dev $interface'; }
      ping() { return 0; }
      ssh() { return 0; }
      wait_for_dashboard_connection
      ''');
      expect(result.exitCode, 2);
      expect(File('${root.path}/session/decision/state').existsSync(), isFalse);
    });
  }

  test(
    'fresh laptop lease blocks even a recognized PPP upgrade peer',
    () async {
      final result = await run(r'''
    MODE=upgrade
    DBC_MENDER=/data/test.mender
    ip() { echo '192.168.7.2 dev ppp0'; }
    ping() { return 0; }
    ssh() { return 0; }
    echo "$ticks" > "$HANDOFF_DIR/heartbeat"
    sleep() {
      ticks=$((ticks + 60))
      echo "$ticks" > "$HANDOFF_DIR/heartbeat"
      [ "$ticks" -lt 3700 ] || mkdir -p "$HANDOFF_DIR/decision"
    }
    wait_for_dashboard_connection
    ''');
      expect(result.exitCode, 2);
      expect(result.stdout, isNot(contains('rebind')));
      expect(File('${root.path}/session/decision/state').existsSync(), isFalse);
    },
  );

  test(
    'renewed laptop lease during PPP recognition prevents upgrade',
    () async {
      final result = await run(r'''
    MODE=upgrade
    DBC_MENDER=/data/test.mender
    ip() { echo '192.168.7.2 dev ppp0'; }
    ping() { return 0; }
    ssh() { echo "$ticks" > "$HANDOFF_DIR/heartbeat"; return 0; }
    wait_for_dashboard_connection
    ''');
      expect(result.exitCode, 2);
      expect(File('${root.path}/session/decision/state').existsSync(), isFalse);
    },
  );

  test('cancellation wins against PPP recognition', () async {
    final result = await run(r'''
    MODE=upgrade
    DBC_MENDER=/data/test.mender
    ip() { echo '192.168.7.2 dev ppp0'; }
    ping() { return 0; }
    ssh() { mkdir "$HANDOFF_DIR/decision"; echo cancelled > "$HANDOFF_DIR/decision/state"; return 0; }
    wait_for_dashboard_connection
    ''');
    expect(result.exitCode, 2);
    expect(
      File('${root.path}/session/decision/state').readAsStringSync().trim(),
      'cancelled',
    );
  });

  test('identified recovery USB device grants flash handoff', () async {
    final result = await run(r'''
    echo 'not attached' > "$USB_HANDOFF_UDC_STATE"
    lsusb() { echo 'Bus 001 Device 002: ID 0525:a4a5'; }
    wait_for_dashboard_connection || exit $?
    [ "$DBC_ALREADY_UMS" = yes ]
    ''');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      File('${root.path}/session/decision/state').readAsStringSync().trim(),
      'active',
    );
  });

  test('an upgrade cannot flash a dashboard in USB recovery', () async {
    final result = await run(r'''
    MODE=upgrade
    echo 'not attached' > "$USB_HANDOFF_UDC_STATE"
    lsusb() { echo 'Bus 001 Device 002: ID 0525:a4a5'; }
    wait_for_dashboard_connection
    ''');
    expect(result.exitCode, 3);
    expect(result.stdout, contains('gadget-restored'));
    expect(File('${root.path}/session/decision').existsSync(), isFalse);
  });

  test(
    'BootROM recovery restores the laptop interface without granting writes',
    () async {
      final result = await run(r'''
    echo 'not attached' > "$USB_HANDOFF_UDC_STATE"
    lsusb() { echo 'Bus 001 Device 002: ID 15a2:0061'; }
    wait_for_dashboard_connection
    ''');
      expect(result.exitCode, 4);
      expect(result.stdout, contains('gadget-restored'));
      expect(File('${root.path}/session/decision').existsSync(), isFalse);
    },
  );

  test('unrelated storage is not accepted as dashboard recovery', () async {
    final result = await run(r'''
    echo 'not attached' > "$USB_HANDOFF_UDC_STATE"
    lsusb() { echo 'Bus 001 Device 002: ID 1234:5678'; }
    wait_for_dashboard_connection
    ''');
    expect(result.exitCode, 2);
  });

  test(
    'cancellation wins even if recognition happens during its request',
    () async {
      final result = await run(r'''
    ping() { return 0; }
    ssh() { mkdir "$HANDOFF_DIR/decision"; echo cancelled > "$HANDOFF_DIR/decision/state"; return 0; }
    wait_for_dashboard_connection
    ''');
      expect(result.exitCode, 2);
      expect(
        File('${root.path}/session/decision/state').readAsStringSync().trim(),
        'cancelled',
      );
    },
  );

  test('bootstrap control loss fails closed', () async {
    final result = await run(r'''
    DBC_CONTROL_ACQUIRED=yes
    dbc_control_check() { return 1; }
    wait_for_dashboard_connection
    ''');
    expect(result.exitCode, 1);
    expect(File('${root.path}/session/decision').existsSync(), isFalse);
  });

  test(
    'masking and installation follow positive handoff, cancellation releases control',
    () {
      final source = File('assets/trampoline.sh.template').readAsStringSync();
      final waiting = source.indexOf('wait_for_dashboard_connection\n');
      expect(waiting, greaterThan(0));
      final mask = source.indexOf('systemctl mask librescoot-keycard');
      expect(mask, greaterThan(waiting));
      final waitingBlock = source.substring(waiting, mask);
      expect(waitingBlock, contains('HANDOFF_RESULT'));
      expect(waitingBlock, contains('dbc_update_complete || fail'));
      expect(waitingBlock, contains('signal_all_off'));
      expect(waitingBlock, contains('signal_install_start'));
      expect(source, isNot(contains('\nwait_for_laptop_disconnect\n')));
    },
  );
}

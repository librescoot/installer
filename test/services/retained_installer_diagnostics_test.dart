import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

class _Ssh extends SshService {
  Duration? requestedTimeout;
  String? requestedCommand;
  bool fail = false;

  @override
  Future<String> runCommand(
    String command, {
    Duration timeout = const Duration(seconds: 60),
    bool replayOnDisconnect = false,
  }) async {
    requestedCommand = command;
    requestedTimeout = timeout;
    if (fail) throw StateError('connection lost');
    return 'retained evidence';
  }
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('installer-evidence-');
  });
  tearDown(() => root.deleteSync(recursive: true));

  void put(String path, String content) {
    final file = File('${root.path}$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  ProcessResult collect() => Process.runSync('sh', [
    '-c',
    r'''
ip() {
  case "$*" in
    '-4 addr show dev usb0'|'route get 192.168.7.2'|'neigh show to 192.168.7.2') echo "network:$*" ;;
    *) echo 'unexpected network change' >&2; exit 90 ;;
  esac
}
systemctl() {
  [ "$1" = show ] || { echo 'unexpected service change' >&2; exit 91; }
  echo ActiveState=inactive
}
journalctl() { echo "journal:$*"; }
redis_cli() {
  case "$*" in
    '-h localhost --raw hmget battery:'*) echo 'battery sample' ;;
    *) echo 'unexpected Redis change' >&2; exit 92 ;;
  esac
}
''' +
        SshService.retainedInstallerDiagnosticsCommand
            .replaceAll('redis-cli', 'redis_cli')
            .replaceAll('/data/', '${root.path}/data/')
            .replaceAll('/etc/', '${root.path}/etc/')
            .replaceAll('/sys/', '${root.path}/sys/'),
  ]);

  test('collects retained evidence and current state without changing files', () {
    final files = {
      '/data/installer/trampoline.log': 'flash completed\nnetwork failed\n',
      '/data/installer/trampoline-status': 'error: no link\n',
      '/data/installer/trampoline-journal.log': 'saved kernel evidence\n',
      '/data/installer/mdb-usb-link.log': 'saved USB evidence\n',
      '/data/installer/trampoline-started-at': '2026-01-01 12:00:00\n',
      '/data/librescoot-installer/dbc-control/owner': 'test-run\n',
      '/data/librescoot-installer/dbc-control/state': 'artifact-install\n',
      '/data/librescoot-installer/dbc-control/isolated': '',
      '/etc/systemd/system/librescoot-vehicle.service.d/90-installer-dbc-test-run.conf':
          '[Unit]\nConditionPathExists=!/data/librescoot-installer/dbc-control/owner\n',
      '/sys/class/udc/ci_hdrc.0/state': 'configured\n',
    };
    files.forEach(put);
    final result = collect();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout, contains('flash completed\nnetwork failed'));
    expect(result.stdout, contains('saved kernel evidence'));
    expect(result.stdout, contains('saved USB evidence'));
    expect(result.stdout, contains('owner: test-run'));
    expect(result.stdout, contains('state: artifact-install'));
    expect(result.stdout, contains('ConditionPathExists='));
    expect(
      result.stdout,
      contains('current MDB USB/network state (laptop connected)'),
    );
    expect(result.stdout, contains('configured'));
    expect(result.stdout, contains('-u librescoot-onboot-inline.service'));
    expect(result.stdout, contains('--since 2026-01-01 12:00:00'));
    expect(result.stderr, isEmpty);
    for (final entry in files.entries) {
      expect(File('${root.path}${entry.key}').readAsStringSync(), entry.value);
    }
  });

  test('missing optional files do not prevent current-state diagnostics', () {
    final result = collect();
    expect(result.exitCode, 0);
    expect(result.stdout, contains('network:route get 192.168.7.2'));
    expect(result.stdout, contains('ActiveState=inactive'));
    expect(result.stdout, contains('journal:-b --no-pager'));
    expect(result.stdout, contains('-u librescoot-battery.service'));
    expect(root.listSync(), isEmpty);
  });

  test('limits retained logs while preserving their newest entries', () {
    put(
      '/data/installer/trampoline.log',
      '${List.generate(1500, (i) => 'line-$i').join('\n')}\n',
    );
    final result = collect();
    expect(result.exitCode, 0);
    expect(result.stdout, isNot(contains('line-499\n')));
    expect(result.stdout, contains('line-500\n'));
    expect(result.stdout, contains('line-1499\n'));
  });

  test('collects successful handover history after staging cleanup', () {
    put('/data/installer/run-state', 'run-id: run-current\n');
    put('/data/installer/last-install', 'run-id: run-current\n');
    put(
      '/data/installer/history/run-current/finalize.log',
      'services restored\n',
    );
    put(
      '/data/installer/history/run-current/handover-diagnostics.log',
      'battery running\n',
    );
    final result = collect();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout, contains('services restored'));
    expect(result.stdout, contains('battery running'));
    expect('services restored'.allMatches(result.stdout.toString()).length, 1);
    expect(result.stdout, contains('journal:-b --no-pager'));
  });

  test('rejects history paths outside a run directory', () {
    put('/data/installer/run-state', 'run-id: ../../private\n');
    put('/data/private/finalize.log', 'must not read\n');
    final result = collect();
    expect(result.exitCode, 0);
    expect(result.stdout, isNot(contains('must not read')));
  });

  test('uses bounded SSH and exposes collection failures for retry', () async {
    final ssh = _Ssh();
    expect(await ssh.readRetainedInstallerDiagnostics(), 'retained evidence');
    expect(ssh.requestedTimeout, const Duration(seconds: 30));
    expect(
      ssh.requestedCommand,
      SshService.retainedInstallerDiagnosticsCommand,
    );
    ssh.fail = true;
    await expectLater(ssh.readRetainedInstallerDiagnostics(), throwsStateError);
  });
}

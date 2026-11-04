import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';
import 'package:librescoot_installer/services/finalize_recovery_service.dart';
import 'package:librescoot_installer/services/finalize_script.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

class _RecoverySsh extends SshService {
  _RecoverySsh(this.script);
  String script;
  bool active = false;
  final uploads = <String, String>{};
  final commands = <String>[];
  String record = '';

  @override
  Future<InstallRunState?> readInstallRunState() async => InstallRunState(
    runId: 'run-recovery-test',
    actor: 'finalize',
    stage: 'restoring-services',
    result: TrampolineResult.error,
    finishState: 'pending',
  );

  @override
  Future<bool> installerExecutionActive() async => active;

  @override
  Future<String> runCommand(
    String command, {
    Duration timeout = const Duration(seconds: 60),
    bool replayOnDisconnect = false,
  }) async {
    commands.add(command);
    if (command.startsWith('if (')) return script;
    if (command.startsWith('cat /data/installer/last-install')) return record;
    expect(replayOnDisconnect, isFalse);
    return 'recovery-started\n';
  }

  @override
  Future<void> uploadFile(
    Uint8List content,
    String remotePath, {
    void Function(int, int)? onProgress,
  }) async => uploads[remotePath] = utf8.decode(content);
}

void main() {
  const runId = 'run-recovery-test';
  final template = File('assets/finalize.sh.template').readAsStringSync();
  String original() => FinalizeScript.render(
    template: template,
    mdbAction: 'leave',
    runId: runId,
    mode: 'upgrade',
    language: 'de',
    channel: 'stable',
    dbcVersion: 'v1.4.1',
    dbcAction: 'leave',
    releaseTag: 'v1.4.1',
    region: 'test-region',
    dashboardResult: 'complete',
    preserveSettings: true,
  );

  test(
    'preserves original run and requested settings while replacing code',
    () {
      final plan = FinalizeRecoveryPlan.parse(original(), runId);
      final rendered = plan.render(
        '$template\n# new recovery implementation\n',
      );
      expect(rendered, contains('RUN_ID="$runId"'));
      expect(rendered, contains('MDB_ACTION="leave"'));
      expect(rendered, contains('PRESERVE_SETTINGS="yes"'));
      expect(rendered, contains('TILES_REGION="test-region"'));
      expect(rendered, contains('# new recovery implementation'));
      expect(plan.scriptDigest, hasLength(64));
    },
  );

  for (final replacement in [
    'RUN_ID="run-different"',
    'RUN_ID="../../escape"',
    r'RUN_ID="$(touch /tmp/injected)"',
    'RUN_ID="run-recovery-test"\nRUN_ID="run-recovery-test"',
  ]) {
    test('rejects unsafe or ambiguous original identity: $replacement', () {
      final script = original().replaceFirst('RUN_ID="$runId"', replacement);
      expect(() => FinalizeRecoveryPlan.parse(script, runId), throwsStateError);
    });
  }

  test(
    'artifact failures and completed runs cannot enter handover recovery',
    () {
      for (final stage in [
        'installing-dbc-artifact',
        'finalization-failed',
        'complete',
      ]) {
        expect(
          FinalizeRecoveryService.eligibleState(
            InstallRunState(
              runId: runId,
              actor: 'finalize',
              stage: stage,
              result: TrampolineResult.error,
              finishState: 'pending',
            ),
          ),
          isFalse,
        );
      }
      expect(
        FinalizeRecoveryService.eligibleState(
          InstallRunState(
            runId: runId,
            actor: 'finalize',
            stage: 'restoring-services',
            result: TrampolineResult.success,
            finishState: 'complete',
          ),
        ),
        isFalse,
      );
    },
  );

  test(
    'recovery stages only a new finalizer and coordinator for the same run',
    () async {
      final ssh = _RecoverySsh(original());
      final recovery = FinalizeRecoveryService(ssh);
      final plan = (await recovery.inspect())!;
      await recovery.start(plan, template: '$template\n# corrected\n');
      expect(
        ssh.uploads.keys,
        unorderedEquals([
          '/data/installer/recovery-$runId-finalize.tmp',
          '/data/installer/recovery-$runId-onboot.tmp',
        ]),
      );
      expect(ssh.uploads.values.first, contains('# corrected'));
      expect(
        ssh.commands.last,
        contains('systemd-run --unit=librescoot-onboot-inline'),
      );
      expect(ssh.commands.last, isNot(contains('systemctl stop')));
    },
  );

  test('recovery does not stage over a newly active installer', () async {
    final ssh = _RecoverySsh(original());
    final recovery = FinalizeRecoveryService(ssh);
    final plan = (await recovery.inspect())!;
    ssh.active = true;
    await expectLater(
      recovery.start(plan, template: template),
      throwsStateError,
    );
    expect(ssh.uploads, isEmpty);
  });

  test(
    'an older completion record cannot hide this unfinished handover',
    () async {
      final ssh = _RecoverySsh(original());
      ssh.record = 'result: success\nrun-id: run-old\nfinish: complete\n';
      expect(await ssh.lastInstallSucceeded(), isFalse);
      ssh.record = 'result: success\nrun-id: $runId\nfinish: complete\n';
      expect(await ssh.lastInstallSucceeded(), isTrue);
    },
  );

  group('device-side recovery claim', () {
    late Directory root;
    late FinalizeRecoveryPlan plan;

    void put(String path, String contents) {
      final f = File('${root.path}$path');
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(contents);
    }

    setUp(() {
      root = Directory.systemTemp.createTempSync('finalizer-recovery-');
      plan = FinalizeRecoveryPlan.parse(original(), runId);
      put('/data/installer/scripts/90-finalize.sh', original());
      put('/data/installer/scripts/90-finalize.sh.tries', '5\n');
      put('/data/installer/scripts/signal.sh', '# signal\n');
      put('/data/installer/scripts/device.sh', '# helpers\n');
      put('/data/onboot.sh', SshService.onbootShim);
      put(
        '/data/installer/run-state',
        'run-id: $runId\nactor: finalize\nstage: restoring-services\nresult: error\nfinish: pending\n',
      );
      put(
        '/data/installer/recovery-$runId-finalize.tmp',
        '# corrected finalizer\n',
      );
      put(
        '/data/installer/recovery-$runId-onboot.tmp',
        '# corrected coordinator\n',
      );
      Directory(
        '${root.path}/data/installer/history/$runId',
      ).createSync(recursive: true);
      Directory('${root.path}/run').createSync();
    });
    tearDown(() => root.deleteSync(recursive: true));

    Future<ProcessResult> launch({
      bool active = false,
      String ota = 'idle',
      String vehicleState = 'stand-by',
    }) => Process.run('sh', [
      '-c',
      [
        '''
pgrep() { return ${active ? 0 : 1}; }
redis_cli() { case "\$*" in *'hget vehicle state') echo '$vehicleState' ;; *) echo '$ota' ;; esac; }
systemd_run() { echo "\$*" > '${root.path}/started'; }
''',
        FinalizeRecoveryService.launchCommand(
              plan,
              finalizerDigest: sha256
                  .convert(utf8.encode('# corrected finalizer\n'))
                  .toString(),
              coordinatorDigest: sha256
                  .convert(utf8.encode('# corrected coordinator\n'))
                  .toString(),
            )
            .replaceAll('redis-cli', 'redis_cli')
            .replaceAll('systemd-run', 'systemd_run')
            .replaceAll('/data/', '${root.path}/data/')
            .replaceAll(
              '/run/librescoot-installer-recovery',
              '${root.path}/run/librescoot-installer-recovery',
            ),
      ].join(),
    ]);

    void expectUntouched() {
      expect(
        File(
          '${root.path}/data/installer/scripts/90-finalize.sh',
        ).readAsStringSync(),
        original(),
      );
      expect(
        File(
          '${root.path}/data/installer/scripts/90-finalize.sh.tries',
        ).readAsStringSync(),
        '5\n',
      );
      expect(File('${root.path}/started').existsSync(), isFalse);
    }

    test(
      'replaces only finalization and coordinator, preserving history',
      () async {
        final result = await launch();
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout, contains('recovery-started'));
        expect(
          File(
            '${root.path}/data/installer/scripts/90-finalize.sh',
          ).readAsStringSync(),
          '# corrected finalizer\n',
        );
        expect(
          File(
            '${root.path}/data/installer/scripts/90-finalize.sh.tries',
          ).existsSync(),
          isFalse,
        );
        expect(
          File(
            '${root.path}/data/installer/history/$runId/finalize-before-recovery-${plan.scriptDigest}.sh',
          ).readAsStringSync(),
          original(),
        );
        expect(
          File('${root.path}/started').readAsStringSync(),
          contains('/bin/sh ${root.path}/data/onboot.sh'),
        );
      },
    );

    for (final phase in ['10-mdb-artifact.sh', '20-dbc.sh', '80-reboot.sh']) {
      test('refuses a queue still containing $phase', () async {
        put('/data/installer/scripts/$phase', '# unresolved work\n');
        expect((await launch()).exitCode, isNot(0));
        expectUntouched();
      });
    }

    test('refuses an executing installer', () async {
      expect((await launch(active: true)).exitCode, isNot(0));
      expectUntouched();
    });

    test('refuses recovery unless the vehicle is locked', () async {
      expect((await launch(vehicleState: 'ready-to-drive')).exitCode, 1);
      expectUntouched();
    });

    test('refuses an active OTA transaction', () async {
      expect((await launch(ota: 'installing')).exitCode, isNot(0));
      expectUntouched();
    });

    for (final path in [
      '/data/librescoot-installer/dbc-control/owner',
      '/data/installer/mdb-artifact-worker.sh',
    ]) {
      test('refuses unresolved ownership at $path', () async {
        put(path, 'unresolved\n');
        expect((await launch()).exitCode, isNot(0));
        expectUntouched();
      });
    }

    test(
      'refuses a corrupt recovery payload before replacing queued work',
      () async {
        put('/data/installer/recovery-$runId-finalize.tmp', '# truncated');
        expect((await launch()).exitCode, 1);
        expectUntouched();
      },
    );

    test('refuses stale approval after a script change', () async {
      put(
        '/data/installer/scripts/90-finalize.sh',
        '${original()}\n# changed\n',
      );
      expect((await launch()).exitCode, isNot(0));
      expect(File('${root.path}/started').existsSync(), isFalse);
      expect(
        File(
          '${root.path}/data/installer/scripts/90-finalize.sh',
        ).readAsStringSync(),
        endsWith('# changed\n'),
      );
    });

    test('refuses a changed run identity', () async {
      put(
        '/data/installer/run-state',
        'run-id: run-new\nactor: finalize\nstage: restoring-services\nfinish: pending\n',
      );
      expect((await launch()).exitCode, isNot(0));
      expectUntouched();
    });

    test('refuses a competing recovery claim', () async {
      Directory('${root.path}/run/librescoot-installer-recovery').createSync();
      expect((await launch()).exitCode, isNot(0));
      expectUntouched();
    });
  });
}

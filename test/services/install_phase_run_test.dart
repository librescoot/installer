import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/install_phase_scripts.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// Runs the real coordinator over the real phase scripts, with mender-update
/// and reboot stubbed. The phases decide whether a vehicle reboots and whether
/// it reboots into a rootfs that was never written, and none of that is
/// reachable from a unit test of the renderer.
void main() {
  late Directory root;
  late Directory scripts;
  late Directory bin;
  late String artifactTemplate;
  late String rebootTemplate;

  String rehome(String s) => s.replaceAll('/data/', '${root.path}/');

  Future<void> writePhase(String name, String body) async {
    final f = File('${scripts.path}/$name');
    await f.writeAsString(rehome(body));
    await Process.run('chmod', ['+x', f.path]);
  }

  Future<void> stub(String name, String body) async {
    final f = File('${bin.path}/$name');
    await f.writeAsString('#!/bin/sh\n$body\n');
    await Process.run('chmod', ['+x', f.path]);
  }

  Future<ProcessResult> boot() async {
    final f = File('${root.path}/onboot.sh');
    await f.writeAsString(rehome(SshService.onbootShim));
    return Process.run(
      'sh',
      [f.path],
      environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'},
    );
  }

  setUpAll(() {
    artifactTemplate =
        File('assets/mdb-artifact.sh.template').readAsStringSync();
    rebootTemplate = File('assets/reboot-phase.sh.template').readAsStringSync();
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('phase-run-');
    scripts = Directory('${root.path}/installer/scripts');
    await scripts.create(recursive: true);
    bin = Directory('${root.path}/bin');
    await bin.create(recursive: true);
    // Records into the same order file so the sequence around it is visible.
    // A stub cannot halt the coordinator the way a real reboot does, so the
    // finalize phase still runs here; on a vehicle it runs on the far side.
    await stub('reboot',
        'echo "reboot \$@" >> ${root.path}/order; '
        'echo "reboot \$@" >> ${root.path}/reboots');
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> queueAll({
    required String artifactPath,
    Duration wait = const Duration(seconds: 20),
  }) async {
    await writePhase(
      MdbArtifactScript.phaseName,
      MdbArtifactScript.render(
        template: artifactTemplate,
        runId: 'run-test',
        artifactPath: artifactPath,
      ),
    );
    await writePhase('20-dbc.sh',
        'echo 20 >> ${root.path}/order\nrm -f "\$0"\n');
    await writePhase(
      RebootPhaseScript.phaseName,
      RebootPhaseScript.render(
        template: rebootTemplate,
        runId: 'run-test',
        artifactWait: wait,
        rebootFallback: const Duration(seconds: 1),
      ),
    );
    await writePhase('90-finalize.sh',
        'echo 90 >> ${root.path}/order\nrm -f "\$0"\n');
  }

  test('a successful run reboots once, after the dashboard phase', () async {
    final artifact = File('${root.path}/a.mender');
    await artifact.writeAsString('x');
    await stub('mender-update', 'sleep 0.3; exit 0');
    await queueAll(artifactPath: artifact.path);

    final r = await boot();
    expect(r.exitCode, 0, reason: r.stderr.toString());

    // The join read it, so the reboot phase cleared it: nothing should find
    // this run's verdict on the far side of the reboot.
    expect(
      await File('${root.path}/installer/history/run-test/reboot.log')
          .readAsString(),
      contains('MDB artifact: ok'),
    );
    expect(
      File('${root.path}/installer/mdb-artifact.result').existsSync(),
      isFalse,
    );
    // The dashboard phase runs while the MDB write is still going, the
    // reboot follows it, and the handover is on the far side of the reboot.
    final order = await File('${root.path}/order').readAsLines();
    expect(order.first, '20');
    expect(order.last, '90');
    final firstReboot = order.indexWhere((l) => l.startsWith('reboot'));
    expect(firstReboot, greaterThan(-1), reason: 'it never rebooted');
    expect(firstReboot, lessThan(order.indexOf('90')),
        reason: 'the vehicle must be on its real image before it unlocks');
    // Graceful first; the forced one is only the fallback for a wedged sync,
    // and on a vehicle the graceful reboot ends the run before it is reached.
    expect(order[firstReboot].trim(), 'reboot');
    expect(order.where((l) => l.trim() == 'reboot -f').length, lessThan(2));
    // Retired before rebooting, or the next boot reboots again, forever.
    expect(
      File('${scripts.path}/${RebootPhaseScript.phaseName}').existsSync(),
      isFalse,
    );
  });

  test('the dashboard phase does not wait for the MDB write', () async {
    // The parallelism, observed rather than asserted from the source: the
    // dashboard phase records its time while mender is still running.
    final artifact = File('${root.path}/a.mender');
    await artifact.writeAsString('x');
    await stub('mender-update', 'sleep 2; exit 0');
    await queueAll(artifactPath: artifact.path);

    final started = DateTime.now();
    await writePhase('20-dbc.sh',
        'date +%s%N >> ${root.path}/dbc-at\nrm -f "\$0"\n');
    await boot();
    final elapsedToDbc = int.parse(
          (await File('${root.path}/dbc-at').readAsString()).trim(),
        ) ~/
        1000000;
    final dbcRanAfterMs =
        elapsedToDbc - started.millisecondsSinceEpoch;
    expect(dbcRanAfterMs, lessThan(2000),
        reason: 'the dashboard phase waited for the 2s MDB write');
  });

  test('a failed MDB install does not reboot the vehicle', () async {
    // u-boot would roll back to the image already running, and a run that
    // installed nothing would read as having worked.
    final artifact = File('${root.path}/a.mender');
    await artifact.writeAsString('x');
    await stub('mender-update', 'exit 3');
    await queueAll(artifactPath: artifact.path);

    await boot();

    expect(
      await File('${root.path}/installer/mdb-artifact.result').readAsString(),
      contains('error:'),
    );
    expect(File('${root.path}/reboots').existsSync(), isFalse,
        reason: 'it rebooted despite the install failing');
    expect(
      await File('${root.path}/installer/trampoline-status').readAsString(),
      contains('error:'),
    );
  });

  test('a missing artifact is caught before anything reboots', () async {
    await stub('mender-update', 'exit 0');
    await queueAll(artifactPath: '${root.path}/not-there.mender');

    await boot();

    expect(
      await File('${root.path}/installer/mdb-artifact.result').readAsString(),
      contains('missing'),
    );
    expect(File('${root.path}/reboots').existsSync(), isFalse);
  });

  test('a plan that leaves the MDB alone still reboots for the dashboard',
      () async {
    await stub('mender-update', 'exit 0');
    await queueAll(artifactPath: '');

    await boot();

    expect(
      await File('${root.path}/installer/history/run-test/reboot.log')
          .readAsString(),
      contains('MDB artifact: skipped'),
    );
    expect(await File('${root.path}/reboots').readAsString(),
        contains('reboot'));
  });

  test('the artifact phase retires, so the next boot does not reinstall',
      () async {
    // It used to stay queued. The boot after the reboot then ran it again and
    // backgrounded a second install of the same artifact into the now-inactive
    // slot, which the coordinator killed mid-write when it exited
    // (KillMode=control-group), leaving an open mender transaction behind for
    // the owner's next OTA. Three boots of that, then it gave up.
    final artifact = File('${root.path}/a.mender');
    await artifact.writeAsString('x');
    await stub('mender-update',
        'echo run >> ${root.path}/mender-runs; exit 0');
    await queueAll(artifactPath: artifact.path);

    await boot();
    expect(
      File('${scripts.path}/${MdbArtifactScript.phaseName}').existsSync(),
      isFalse,
      reason: 'it started the work; staying queued means doing it again',
    );

    // A second boot, as happens right after the reboot it triggered.
    await boot();
    final runs = await File('${root.path}/mender-runs').readAsLines();
    // One install, plus the commit-or-rollback preamble that precedes it.
    expect(runs.length, lessThanOrEqualTo(2),
        reason: 'the artifact was installed more than once');
  });

  test('a phase left queued is what the coordinator retries', () async {
    // The counterpart: 90 deliberately stays queued when it declines, and the
    // coordinator is what gives it another go on the next boot.
    await stub('mender-update', 'exit 0');
    await queueAll(artifactPath: '');
    await writePhase('90-finalize.sh',
        'echo 90 >> ${root.path}/order\n'); // never removes itself
    await boot();
    expect(File('${scripts.path}/90-finalize.sh').existsSync(), isTrue);
    await boot();
    expect((await File('${root.path}/order').readAsLines())
        .where((l) => l == '90'), hasLength(2));
  });
}

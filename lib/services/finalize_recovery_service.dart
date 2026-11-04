import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/trampoline_status.dart';
import 'finalize_script.dart';
import 'ssh_service.dart';

class FinalizeRecoveryPlan {
  FinalizeRecoveryPlan._(this.values, this.scriptDigest);

  final Map<String, String> values;
  final String scriptDigest;
  String get runId => values['RUN_ID']!;

  static FinalizeRecoveryPlan parse(String script, String expectedRunId) {
    const names = [
      'MDB_ACTION',
      'FINISH_LANGUAGE',
      'FINISH_CHANNEL',
      'RUN_ID',
      'MODE',
      'DBC_VERSION',
      'DBC_ACTION',
      'RELEASE_TAG',
      'TILES_REGION',
      'DASHBOARD_RESULT',
      'PRESERVE_SETTINGS',
    ];
    final values = <String, String>{};
    for (final name in names) {
      final matches = RegExp(
        '^$name="([a-zA-Z0-9._-]*)"\$',
        multiLine: true,
      ).allMatches(script).toList();
      if (matches.length != 1) {
        throw StateError('Cannot safely recover finalizer field $name');
      }
      values[name] = matches.single.group(1)!;
    }
    if (values['RUN_ID'] != expectedRunId ||
        !RegExp(r'^run-[a-zA-Z0-9._-]+$').hasMatch(expectedRunId) ||
        !{
          'leave',
          'upgrade',
          'cleanInstall',
          'fullImage',
        }.contains(values['MDB_ACTION']) ||
        !{'flash', 'upgrade'}.contains(values['MODE']) ||
        !{
          'complete',
          'skipped',
          'not-requested',
        }.contains(values['DASHBOARD_RESULT']) ||
        !{'yes', 'no'}.contains(values['PRESERVE_SETTINGS'])) {
      throw StateError(
        'Retained finalizer does not describe a recoverable handover',
      );
    }
    return FinalizeRecoveryPlan._(
      Map.unmodifiable(values),
      sha256.convert(utf8.encode(script)).toString(),
    );
  }

  String render(String template) => FinalizeScript.render(
    template: template,
    mdbAction: values['MDB_ACTION']!,
    runId: runId,
    mode: values['MODE']!,
    language: values['FINISH_LANGUAGE']!,
    channel: values['FINISH_CHANNEL']!,
    dbcVersion: values['DBC_VERSION']!,
    dbcAction: values['DBC_ACTION']!,
    releaseTag: values['RELEASE_TAG']!,
    region: values['TILES_REGION']!,
    dashboardResult: values['DASHBOARD_RESULT']!,
    preserveSettings: values['PRESERVE_SETTINGS'] == 'yes',
  );
}

/// Repairs only a verified finalization-only queue. Retained shell is parsed as
/// data, never sourced; firmware and map phases cannot enter this recovery path.
class FinalizeRecoveryService {
  FinalizeRecoveryService(this.ssh);
  final SshService ssh;

  static bool eligibleState(InstallRunState? state) =>
      state?.actor == 'finalize' &&
      state?.finishState == 'pending' &&
      {
        TrampolineResult.running,
        TrampolineResult.error,
      }.contains(state?.result) &&
      {'restoring-services', 'waiting-mdb-reboot'}.contains(state?.stage);

  static const queueCheck = r'''
[ -f /data/installer/scripts/90-finalize.sh ] || exit 1
[ -f /data/installer/scripts/signal.sh ] || exit 1
[ -f /data/installer/scripts/device.sh ] || exit 1
[ ! -e /data/librescoot-installer/dbc-control/owner ] || exit 1
[ ! -e /data/installer/mdb-artifact-worker.sh ] || exit 1
[ "$(redis-cli -h localhost --raw hget vehicle state)" = stand-by ] || exit 1
for component in mdb dbc dbc-boot; do
  state=$(redis-cli -h localhost --raw hget ota "status:$component") || exit 1
  case "$state" in ''|idle|staged-noop) ;; *) exit 1 ;; esac
done
state=$(redis-cli -h localhost --raw hget ota status:mdb-boot) || exit 1
case "$state" in ''|idle|staged-noop|pending-reboot) ;; *) exit 1 ;; esac
grep -Fq '# Installed by the Librescoot installer.' /data/onboot.sh || exit 1
for phase in /data/installer/scripts/[0-9][0-9]-*.sh; do
  [ "$phase" = /data/installer/scripts/90-finalize.sh ] || exit 1
done
grep -Fxq 'actor: finalize' /data/installer/run-state || exit 1
grep -Fxq 'finish: pending' /data/installer/run-state || exit 1
grep -Eq '^result: (running|error)$' /data/installer/run-state || exit 1
grep -Eq '^stage: (restoring-services|waiting-mdb-reboot)$' /data/installer/run-state || exit 1
''';

  Future<FinalizeRecoveryPlan?> inspect() async {
    final state = await ssh.readInstallRunState();
    if (!eligibleState(state)) return null;
    if (await ssh.installerExecutionActive()) return null;
    final script = await ssh.runCommand(
      'if ( $queueCheck ); then cat ${FinalizeScript.remotePath}; fi',
      replayOnDisconnect: true,
    );
    if (script.isEmpty) return null;
    return FinalizeRecoveryPlan.parse(script, state!.runId ?? '');
  }

  static String launchCommand(
    FinalizeRecoveryPlan plan, {
    required String finalizerDigest,
    required String coordinatorDigest,
  }) {
    for (final digest in [finalizerDigest, coordinatorDigest]) {
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
        throw ArgumentError('Invalid recovery payload digest');
      }
    }
    final run = plan.runId;
    final digest = plan.scriptDigest;
    return '''
set -eu
mkdir /run/librescoot-installer-recovery || exit 1
trap 'rmdir /run/librescoot-installer-recovery' EXIT HUP INT TERM
$queueCheck
grep -Fxq 'run-id: $run' /data/installer/run-state || exit 1
[ "\$(sha256sum ${FinalizeScript.remotePath} | cut -d ' ' -f 1)" = '$digest' ] || exit 1
execution=\$(
${SshService.installerExecutionProbeCommand}
)
[ "\$execution" = idle ] || exit 1
[ "\$(sha256sum /data/installer/recovery-$run-finalize.tmp | cut -d ' ' -f 1)" = '$finalizerDigest' ] || exit 1
[ "\$(sha256sum /data/installer/recovery-$run-onboot.tmp | cut -d ' ' -f 1)" = '$coordinatorDigest' ] || exit 1
cp ${FinalizeScript.remotePath} /data/installer/history/$run/finalize-before-recovery-$digest.sh
# Persist the retaining coordinator before replacing its queued work.
mv /data/installer/recovery-$run-onboot.tmp /data/onboot.sh
sync
mv /data/installer/recovery-$run-finalize.tmp ${FinalizeScript.remotePath}
rm -f ${FinalizeScript.remotePath}.tries
sync
systemd-run --unit=librescoot-onboot-inline --collect --quiet /bin/sh /data/onboot.sh
echo recovery-started
''';
  }

  Future<void> start(FinalizeRecoveryPlan approved, {String? template}) async {
    final current = await inspect();
    if (current == null ||
        current.runId != approved.runId ||
        current.scriptDigest != approved.scriptDigest) {
      throw StateError(
        'Installation changed; recovery must be inspected again',
      );
    }
    final run = current.runId;
    final finalizer = utf8.encode(
      current.render(template ?? await FinalizeScript.loadTemplate()),
    );
    final coordinator = utf8.encode(SshService.onbootShim);
    await ssh.uploadFile(
      Uint8List.fromList(finalizer),
      '/data/installer/recovery-$run-finalize.tmp',
    );
    await ssh.uploadFile(
      Uint8List.fromList(coordinator),
      '/data/installer/recovery-$run-onboot.tmp',
    );
    final result = await ssh.runCommand(
      launchCommand(
        current,
        finalizerDigest: sha256.convert(finalizer).toString(),
        coordinatorDigest: sha256.convert(coordinator).toString(),
      ),
    );
    if (!result.trim().endsWith('recovery-started')) {
      throw StateError(
        'Recovery launch was not acknowledged; inspect the existing run before retrying',
      );
    }
  }
}

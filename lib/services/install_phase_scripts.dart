import 'package:flutter/services.dart';

/// Placeholders left unfilled are valid shell in most positions, so a script
/// with one runs and takes the wrong branch rather than failing. Both scripts
/// here decide whether to reboot a vehicle, so they refuse to render instead.
List<String> unresolvedPlaceholders(String script) =>
    RegExp(r'\{\{[A-Z_]+\}\}')
        .allMatches(script)
        .map((m) => m.group(0)!)
        .toSet()
        .toList()
      ..sort();

String _normalise(String script) =>
    script.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// Installs the MDB's own .mender, in the background, on the far side of the
/// cable swap.
///
/// The install used to run over the laptop link and was followed by a reboot
/// to prove the rootfs committed. Both are gone: the board stays on the
/// bootstrap image until everything is done, and staying there is what lets
/// the user walk away as soon as the uploads finish.
class MdbArtifactScript {
  /// Ahead of the dashboard phase so its background install is already
  /// running while the dashboard is flashed and uploaded to.
  static const String phaseName = '10-mdb-artifact.sh';

  static const String remotePath = '/data/installer/scripts/$phaseName';

  /// Where [MdbArtifactScript] leaves its verdict, and where the reboot phase
  /// reads it. Values: `ok`, `skipped`, or a line starting `error:`.
  static const String resultPath = '/data/installer/mdb-artifact.result';

  /// [artifactPath] is the staged .mender on the device, empty for a plan
  /// that leaves the MDB alone. The phase is queued either way so the join in
  /// [RebootPhaseScript] always has something to read.
  static String render({
    required String template,
    required String runId,
    String artifactPath = '',
  }) {
    final rendered = template
        .replaceAll('{{RUN_ID}}', runId)
        .replaceAll('{{MDB_ARTIFACT_PATH}}', artifactPath);
    final left = unresolvedPlaceholders(rendered);
    if (left.isNotEmpty) {
      throw StateError('mdb-artifact template still wants ${left.join(", ")}');
    }
    return _normalise(rendered);
  }

  static Future<String> loadTemplate() =>
      rootBundle.loadString('assets/mdb-artifact.sh.template');
}

/// The single reboot, once both boards have their images.
class RebootPhaseScript {
  /// After the dashboard work, before the handover: 90-finalize.sh unlocks,
  /// and the vehicle should be on its real image when that happens.
  static const String phaseName = '80-reboot.sh';

  static const String remotePath = '/data/installer/scripts/$phaseName';

  /// How long to wait for the MDB artifact before calling it failed. Generous
  /// because it is a join, not a timeout anybody is watching: the dashboard
  /// work usually outlasts the MDB write, so this only bites when the write
  /// has genuinely wedged.
  static const Duration defaultArtifactWait = Duration(minutes: 30);

  /// How long a graceful reboot gets before the forced one. A wedged sync on
  /// eMMC can hang `reboot` itself, which is what the fallback is for.
  static const Duration defaultRebootFallback = Duration(seconds: 20);

  static String render({
    required String template,
    required String runId,
    Duration artifactWait = defaultArtifactWait,
    Duration rebootFallback = defaultRebootFallback,
  }) {
    final rendered = template
        .replaceAll('{{RUN_ID}}', runId)
        .replaceAll(
          '{{MDB_ARTIFACT_WAIT_SECONDS}}',
          '${artifactWait.inSeconds}',
        )
        .replaceAll(
          '{{REBOOT_FALLBACK_SECONDS}}',
          '${rebootFallback.inSeconds}',
        );
    final left = unresolvedPlaceholders(rendered);
    if (left.isNotEmpty) {
      throw StateError('reboot template still wants ${left.join(", ")}');
    }
    return _normalise(rendered);
  }

  static Future<String> loadTemplate() =>
      rootBundle.loadString('assets/reboot-phase.sh.template');
}

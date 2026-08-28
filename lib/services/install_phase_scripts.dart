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

/// The blinker bar, the front light, the dashboard LED and the hazards, in one
/// file every script on the board sources.
///
/// Staged into the scripts directory rather than beside the trampoline: every
/// sweep spares that directory by name, and the helpers have to outlive the
/// sweep in the dashboard phase to light anything afterwards. The coordinator's
/// phase glob is `[0-9][0-9]-*.sh`, so this is never run as a phase.
///
/// It carries no placeholders, so there is nothing to render.
class SignalHelpers {
  static const String fileName = 'signal.sh';

  static const String remotePath = '/data/installer/scripts/$fileName';

  static const String assetPath = 'assets/$fileName';

  static Future<String> load() => rootBundle.loadString(assetPath);
}

/// dbc_ssh, wait_dbc_ssh and the dashboard power helpers, in one file every
/// script that talks to the DBC sources.
///
/// Staged alongside signal.sh, for the same reason: both the trampoline and
/// the dashboard phase it writes need these, and a copy inside that phase's
/// heredoc is exactly the drift signal.sh was pulled out to stop.
class DeviceHelpers {
  static const String fileName = 'device.sh';

  static const String remotePath = '/data/installer/scripts/$fileName';

  static const String assetPath = 'assets/$fileName';

  static Future<String> load() => rootBundle.loadString(assetPath);
}

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

/// Decides whether the run needs its one reboot, and asks the coordinator for
/// it rather than doing it: a phase that reboots never returns to be recorded
/// as having run, and the reboot belongs between phases anyway.
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

  static String render({
    required String template,
    required String runId,
    Duration artifactWait = defaultArtifactWait,
  }) {
    final rendered = template
        .replaceAll('{{RUN_ID}}', runId)
        .replaceAll(
          '{{MDB_ARTIFACT_WAIT_SECONDS}}',
          '${artifactWait.inSeconds}',
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

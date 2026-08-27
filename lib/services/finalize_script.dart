import 'package:flutter/services.dart';

/// The last install phase: hand the vehicle back.
///
/// One copy, two callers. The laptop runs it detached at the end of an
/// attended install, because restoring usb0-policy severs the transport the
/// command arrived on. The coordinator runs it as the last phase of an
/// unattended one. Before this it was written twice, once inside the
/// trampoline and once spread across the installer's finish, and the two had
/// already drifted: the trampoline handled a `leave` action the installer
/// folded into "data was erased", and only one of them ever ended service
/// mode.
class FinalizeScript {
  /// Numbered high, with room left above it. Nothing an install queues should
  /// run after the vehicle has been handed back, but leaving the top of the
  /// range free is cheaper than renumbering later.
  static const String phaseName = '90-finalize.sh';

  static const String remotePath = '/data/installer/scripts/$phaseName';

  /// Values the script cannot work out for itself on the far side of a reboot.
  static String render({
    required String template,
    required String mdbAction,
    required String runId,
    required String mode,
    String language = '',
    String channel = '',
    String mdbVersion = '',
    String dbcVersion = '',
    String dbcAction = '',
    String releaseTag = '',
    String region = '',
  }) {
    final rendered = template
        .replaceAll('{{MDB_ACTION}}', mdbAction)
        .replaceAll('{{FINISH_LANGUAGE}}', language)
        .replaceAll('{{FINISH_CHANNEL}}', channel)
        .replaceAll('{{RUN_ID}}', runId)
        .replaceAll('{{MODE}}', mode)
        .replaceAll('{{MDB_VERSION}}', mdbVersion)
        .replaceAll('{{DBC_VERSION}}', dbcVersion)
        .replaceAll('{{DBC_ACTION}}', dbcAction)
        .replaceAll('{{RELEASE_TAG}}', releaseTag)
        .replaceAll('{{TILES_REGION}}', region);

    // An unfilled placeholder is valid shell in most of the places one
    // appears, so the script runs and takes the wrong branch rather than
    // failing. On this script that means restoring the wrong settings or
    // filing the run under an empty id.
    final left = unresolvedPlaceholders(rendered);
    if (left.isNotEmpty) {
      throw StateError('finalize template still wants ${left.join(", ")}');
    }
    return rendered.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  static List<String> unresolvedPlaceholders(String script) =>
      RegExp(r'\{\{[A-Z_]+\}\}')
          .allMatches(script)
          .map((m) => m.group(0)!)
          .toSet()
          .toList()
        ..sort();

  static Future<String> loadTemplate() =>
      rootBundle.loadString('assets/finalize.sh.template');
}

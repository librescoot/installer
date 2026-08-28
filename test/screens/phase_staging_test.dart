import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// The phases are what the board runs once the laptop is gone. Staging them
/// into a directory nothing has created yet fails on the first upload's chmod,
/// and the catch takes the other two with it: the run then hands off to a
/// coordinator with an empty directory and the scooter is never touched.
void main() {
  late String finish;

  setUpAll(() {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _onEnterFinish() async {');
    expect(start, isNot(-1));
    final end = source.indexOf('\n  /// Whether the device wrote', start);
    expect(end, isNot(-1));
    finish = source.substring(start, end);
  });

  test('the scripts directory exists before anything is uploaded into it', () {
    final mkdir = finish.indexOf('mkdir -p \${SshService.installerScriptsDir}');
    expect(mkdir, isNot(-1),
        reason: 'uploadFile does not create directories');
    for (final phase in [
      'FinalizeScript.remotePath',
      'MdbArtifactScript.remotePath',
      'RebootPhaseScript.remotePath',
    ]) {
      final at = finish.indexOf(phase);
      expect(at, isNot(-1), reason: '$phase is not staged at all');
      expect(at, greaterThan(mkdir),
          reason: '$phase is uploaded before the directory exists');
    }
  });

  test('every phase the coordinator is told to expect is one we upload', () {
    // The hand-off announces a phase list. A phase named there and not
    // uploaded is a board that stops halfway with no laptop attached.
    for (final path in [
      SshService.installerScriptsDir,
    ]) {
      expect(path, startsWith(SshService.installerDir),
          reason: 'phases have to survive the selective sweep');
    }
    expect(finish.indexOf('mkdir -p \${SshService.installerScriptsDir}'),
        lessThan(finish.indexOf('_cleanupMdb()')),
        reason: 'the sweep spares scripts/, but only if it is there to spare');
  });
}

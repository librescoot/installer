import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File('lib/screens/installer_screen.dart').readAsStringSync();
  final main = File('lib/main.dart').readAsStringSync();

  test('download failures sound once when newly reported, not on rebuild', () {
    final start = screen.indexOf('void _recordDownloadFailure(');
    final end = screen.indexOf('Future<DownloadItem> _localImageItem(', start);
    expect(start, isNonNegative);
    final handler = screen.substring(start, end);
    expect(handler, contains('if (_downloadsFailed != message)'));
    expect(handler, contains('_sounds.play(InstallerCue.error)'));
    expect(screen, contains('_recordDownloadFailure(e.toString())'));
  });

  test('visible failures and health warnings have distinct cues', () {
    expect(screen, contains('l10n.healthCheckFailed(e.toString()),\n          cue: InstallerCue.error'));
    expect(screen, contains('if (!health.allOk) _sounds.play(InstallerCue.critical)'));
    expect(main, contains('_unhandledErrorSounds.play(InstallerCue.error)'));
  });
}

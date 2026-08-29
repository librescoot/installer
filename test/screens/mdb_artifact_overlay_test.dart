import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String flow;

  setUpAll(() {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _runMdbArtifactInstall()');
    final end = source.indexOf('\n  String _preflightMessage(', start);
    expect(start, isNot(-1));
    expect(end, isNot(-1));
    flow = source.substring(start, end);
  });

  test('artifact overlay ends at the on-device handoff', () {
    expect(flow, contains('l10n.waitingForDbcUpload'));
    expect(flow, isNot(contains('l10n.waitingForMdbRestart')));
    expect(flow, isNot(contains('l10n.artifactVerifying')));
    expect(flow, contains('_setPhase(_phaseAfterMdbInstall)'));
  });
}

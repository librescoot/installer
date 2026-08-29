import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String flow;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
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
    expect(flow, isNot(contains('l10n.artifactInstalling')));
    expect(flow, contains('_setPhase(_phaseAfterMdbInstall)'));
  });

  test('download is a step only while requested inputs are running', () {
    expect(flow, contains('final downloading = !_isDryRun &&'));
    expect(flow, contains('if (downloading)'));
    expect(flow, contains('label: l10n.waitingForDownloads'));
    expect(source, contains('downloading\n            ? _handoffDownloadProgress'));
  });

  test('transfer progress starts without waiting for every download', () {
    expect(
      source,
      contains('_setBackgroundStatus(l10n.artifactStaging, progress: progress)'),
    );

    final start = source.indexOf('Future<void> _uploadDbcFiles(');
    final end = source.indexOf('\n  /// Confirm handler', start);
    final upload = source.substring(start, end);
    expect(upload, contains('if (!_dbcDownloadsReady)'));
    expect(upload, isNot(contains('_downloadState.allReady')));
    expect(upload, contains('l10n.filesStagedWaitingForHandoff'));
  });
}

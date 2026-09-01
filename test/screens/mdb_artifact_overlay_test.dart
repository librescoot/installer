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
    expect(
      source,
      contains('downloading\n            ? _handoffDownloadProgress'),
    );
  });

  test('handoff start keeps a stable disabled action until phase advance', () {
    final start = source.indexOf('Widget _buildDbcPrep(');
    final end = source.indexOf(
      '\n  Future<String?> _saveTrampolineFailureDiagnostics(',
      start,
    );
    final handoff = source.substring(start, end);
    expect(handoff, contains('_trampolineStartInFlight'));
    expect(handoff, contains('l10n.startingTrampoline'));

    final trampolineStart = handoff.indexOf('Future<void> _startTrampoline()');
    final startFlow = handoff.substring(trampolineStart);
    final launch = startFlow.indexOf(
      'await TrampolineService(_sshService).start',
    );
    final phaseAdvance = startFlow.indexOf(
      '_setPhase(InstallerPhase.dbcFlash)',
      launch,
    );
    expect(launch, greaterThan(-1));
    expect(phaseAdvance, greaterThan(launch));
    final afterLaunch = startFlow.substring(launch, phaseAdvance);
    expect(
      afterLaunch,
      isNot(contains('setState(() => _isProcessing = false)')),
      reason: 'clearing busy on DBC prep briefly exposes Retry before advance',
    );
    expect(
      afterLaunch,
      isNot(contains('Future.delayed')),
      reason: 'a post-launch delay exposes the wrong prep actions',
    );
  });

  test('autonomous handoff keeps error and skip actions', () {
    final start = source.indexOf('Widget _buildDbcFlash(');
    final end = source.indexOf('\n  Future<void> _watchDbcFlash()', start);
    final autonomous = source.substring(start, end);
    expect(autonomous, contains('EstimatedHandoffProgress('));
    expect(autonomous, contains('_autonomousHandoffStartedAt'));
    expect(autonomous, contains('l10n.dbcFlashSomethingWrong'));
    expect(autonomous, contains('l10n.skipToFinish'));
    expect(autonomous, isNot(contains('l10n.dbcFlashAllDone')));
  });

  test('transfer progress starts without waiting for every download', () {
    expect(
      source,
      contains(
        '_setBackgroundStatus(l10n.artifactStaging, progress: progress)',
      ),
    );

    final start = source.indexOf('Future<void> _uploadDbcFiles(');
    final end = source.indexOf('\n  /// Confirm handler', start);
    final upload = source.substring(start, end);
    expect(upload, contains('if (!_dbcDownloadsReady)'));
    expect(upload, isNot(contains('_downloadState.allReady')));
    expect(upload, contains('l10n.filesStagedWaitingForHandoff'));
  });
}

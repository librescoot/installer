import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('resume cannot continue until both recovery steps succeed', () {
    final start = source.indexOf('Future<void> _continueFromResume()');
    final end = source.indexOf('Future<void> _loadResumeEvidence()', start);
    final block = source.substring(start, end);

    final disarm = block.indexOf('await _sshService.disarmTrampolineOnboot()');
    final services = block.indexOf(
      'await _sshService.reviveInstallerServices()',
    );
    final setup = block.indexOf('await _completeConnectionSetup(');
    expect(disarm, greaterThan(-1));
    expect(services, greaterThan(disarm));
    expect(setup, greaterThan(services));
    expect(block, contains('_resumeCleanupError = e.toString();'));
    expect(block, contains('return;'));
    expect(block, isNot(contains('previous run (ok)')));
  });

  test(
    'active coordinators are observed without cleanup or new run-state writes',
    () {
      final connect = source.substring(
        source.indexOf('Future<void> _autoConnectMdb()'),
        source.indexOf('Future<void> _showPreviousInstallFailure('),
      );
      expect(connect, contains('await _sshService.installerExecutionActive()'));
      expect(
        connect.indexOf('await _observeExistingInstall()'),
        lessThan(connect.indexOf('await _sshService.detectServiceStack()')),
      );
      final continuation = source.substring(
        source.indexOf('Future<void> _continueFromResume()'),
        source.indexOf('Future<void> _loadResumeEvidence()'),
      );
      expect(
        continuation.indexOf('await _sshService.installerExecutionActive()'),
        lessThan(
          continuation.indexOf('await _sshService.disarmTrampolineOnboot()'),
        ),
      );
      final observer = source.substring(
        source.indexOf('Future<void> _watchRunningTrampoline()'),
        source.indexOf('String _localizedStage('),
      );
      expect(
        observer,
        contains("ensureConnected('previous installation status')"),
      );
      expect(observer, contains('catch (e)'));
      expect(observer, isNot(contains('trampolineAlive()')));
      final record = source.substring(
        source.indexOf('void _queueInstallPhaseRecord('),
        source.indexOf('Future<void> _fetchBleMac()'),
      );
      expect(record, contains('_resumeStillRunning'));
      expect(record, contains('phase == InstallerPhase.resumeDetected'));
      expect(record, contains('phase == InstallerPhase.mdbConnect'));
    },
  );

  test(
    'incomplete handoff confirmation discloses pending MDB install and reboot',
    () {
      final skip = source.substring(
        source.indexOf('Future<void> _skipDashboardTransfer()'),
        source.indexOf('Future<void> _startTrampoline()'),
      );
      expect(
        skip,
        contains('!_deviceFinishArmed && (_plan?.needsMdbArtifact ?? false)'),
      );
      expect(skip, contains('l10n.finishWithoutDbcPendingMdbBody'));
    },
  );

  test('resume screen shows cleanup progress, failure, and Retry', () {
    final start = source.indexOf('Widget _buildResumeDetected(');
    final end = source.indexOf('Widget _buildHealthCheck', start);
    final block = source.substring(start, end);

    expect(block, contains('l10n.resumeClearingLeftovers'));
    expect(block, contains('l10n.resumeCleanupFailed(_resumeCleanupError!)'));
    expect(block, contains('l10n.retryButton'));
  });
}

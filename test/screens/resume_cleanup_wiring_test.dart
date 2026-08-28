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

  test('resume screen shows cleanup progress, failure, and Retry', () {
    final start = source.indexOf('Widget _buildResumeDetected(');
    final end = source.indexOf('Widget _buildHealthCheck', start);
    final block = source.substring(start, end);

    expect(block, contains('l10n.resumeClearingLeftovers'));
    expect(block, contains('l10n.resumeCleanupFailed(_resumeCleanupError!)'));
    expect(block, contains('l10n.retryButton'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('selected configuration is backed up before destructive phases', () {
    final start = source.indexOf('Future<void> _startPlan() async');
    final end = source.indexOf('Widget _waitingPhase', start);
    final method = source.substring(start, end);

    final backup = method.indexOf('_configurationService.backup(');
    expect(backup, greaterThanOrEqualTo(0));
    expect(
      method.indexOf('_setPhase(InstallerPhase.mdbToUms)'),
      greaterThan(backup),
    );
    expect(
      method.indexOf('_setPhase(InstallerPhase.mdbFlash)'),
      greaterThan(backup),
    );
  });

  test(
    'destructive plans use a dedicated configuration confirmation phase',
    () {
      final start = source.indexOf('void _continueFromInstallPlan()');
      final end = source.indexOf(
        'Widget _buildConfigurationConfirmation',
        start,
      );
      final method = source.substring(start, end);

      expect(method, contains('BoardAction.cleanInstall'));
      expect(method, contains('BoardAction.fullImage'));
      expect(method, contains('InstallerPhase.configurationConfirmation'));
      expect(method, contains('_configurationInventory.categories.isNotEmpty'));
    },
  );

  test('restore choices put settings and keycards first with descriptions', () {
    final start = source.indexOf('static const _configurationDisplayOrder');
    final end = source.indexOf('String _configurationCategoryLabel', start);
    final order = source.substring(start, end);

    expect(
      order.indexOf('ConfigurationCategory.settings'),
      lessThan(order.indexOf('ConfigurationCategory.keycards')),
    );
    expect(
      order.indexOf('ConfigurationCategory.keycards'),
      lessThan(order.indexOf('ConfigurationCategory.identity')),
    );
    expect(
      source,
      contains('_configurationCategoryDescription(l10n, category)'),
    );
  });

  test('health check names transferable configuration categories', () {
    final start = source.indexOf('Widget _buildHealthCheck(');
    final end = source.indexOf('Future<void> _runHealthCheck()', start);
    final method = source.substring(start, end);

    expect(method, contains('configurationDetectedSummary(l10n, ['));
    expect(method, contains('_configurationInventory.categories.contains('));
  });

  test('install plan no longer embeds configuration checkboxes', () {
    final start = source.indexOf('Widget _buildInstallPlan(');
    final end = source.indexOf('void _continueFromInstallPlan()', start);
    final method = source.substring(start, end);

    expect(method, isNot(contains('CheckboxListTile')));
    expect(method, isNot(contains('configurationCategories:')));
  });

  test('upgrade fallback returns through selectable preservation plan', () {
    final start = source.indexOf('Future<void> _fallBackToFullImage() async');
    final end = source.indexOf('Widget _buildCbbReconnect', start);
    final method = source.substring(start, end);

    final fullImage = method.indexOf('withAction(BoardAction.fullImage)');
    final plan = method.indexOf('_setPhase(InstallerPhase.installPlan)');
    expect(fullImage, greaterThanOrEqualTo(0));
    expect(plan, greaterThan(fullImage));
    expect(method, isNot(contains('_setPhase(InstallerPhase.mdbToUms)')));
  });

  test('every full-image write invalidates an earlier restore', () {
    final start = source.indexOf('Future<void> _flashMdb() async');
    final end = source.indexOf('Widget _buildScooterPrep', start);
    final method = source.substring(start, end);

    expect(method, contains('_configurationRestoreVerified = false'));
  });

  test(
    'restore waits for the real data partition and verifies before advance',
    () {
      final start = source.indexOf('Future<void> _waitForMdbBoot(');
      final end = source.indexOf(
        'DashboardMessages _buildDashboardMessages',
        start,
      );
      final method = source.substring(start, end);

      final wait = method.indexOf('await _waitForDataPartition()');
      final restore = method.indexOf('_configurationService.restore(');
      final verified = method.indexOf('_configurationRestoreVerified = true');
      final advance = method.indexOf('_setPhase(_beginMdbInstall())', verified);
      expect(wait, greaterThanOrEqualTo(0));
      expect(restore, greaterThan(wait));
      expect(verified, greaterThan(restore));
      expect(advance, greaterThan(verified));
    },
  );

  test('finish success waits for post-finalization configuration checks', () {
    final start = source.indexOf('Widget _buildFinish(');
    final end = source.indexOf(
      'Widget _buildConfigurationVerificationPending',
      start,
    );
    final method = source.substring(start, end);

    expect(method, contains('_configurationPostFinalizeVerified'));
    expect(method, contains('_buildConfigurationVerificationPending(l10n)'));
    expect(method, contains('_buildConfigurationVerificationFailure(l10n)'));
  });

  test('verification failure exposes retained backup and retry', () {
    final start = source.indexOf(
      'Widget _buildConfigurationVerificationFailure',
    );
    final end = source.indexOf('Widget _buildFinishPending', start);
    final method = source.substring(start, end);

    expect(method, contains('_configurationBackup?.directoryPath'));
    expect(method, contains('configurationVerificationFailedBody(backupPath)'));
    expect(
      method,
      contains('_verifyConfigurationAfterFinalization(reconnect: true)'),
    );
  });

  test(
    'backup deletion requires confirmed completion and verified restore',
    () {
      final start = source.indexOf('Future<void> _cleanupBeforeClose() async');
      final end = source.indexOf('Future<bool> _shouldRetry', start);
      final method = source.substring(start, end);

      expect(method, contains('_finishCompletionConfirmed'));
      expect(method, contains('!_dbcOutcome.isIncomplete'));
      expect(method, contains('_configurationRestoreVerified'));
      expect(method, contains('_configurationPostFinalizeVerified'));
      expect(method, contains('_configurationService.deleteBackup(backup)'));
    },
  );
}

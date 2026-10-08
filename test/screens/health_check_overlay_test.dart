import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('health check stays in an overlay when results arrive', () {
    final start = source.indexOf('Widget _buildHealthCheck(');
    final end = source.indexOf('\n  Future<void> _runHealthCheck()', start);
    final build = source.substring(start, end);
    expect(build, contains('if (_scooterHealth == null)'));
    expect(build, contains('return _waitPhase('));
    expect(build, contains('title: l10n.healthCheckHeading'));
    expect(build, contains('return WaitScaffold('));
    expect(build, contains('overlay: OverlayCard('));
    expect(build, contains('HealthCheckPanel(health: health)'));
    expect(build, isNot(contains('return PhaseLayout(')));
  });

  test('battery explanation and readings precede installation context', () {
    final start = source.indexOf('Widget _buildHealthCheck(');
    final end = source.indexOf('\n  Future<void> _runHealthCheck()', start);
    final build = source.substring(start, end);
    final overlay = build.substring(build.indexOf('overlay: OverlayCard('));
    final purpose = overlay.indexOf('Text(l10n.healthCheckPurpose');
    final readings = overlay.indexOf('HealthCheckPanel(health: health)');
    final version = overlay.indexOf('l10n.healthVersionPlan(');
    final config = overlay.indexOf('configurationDetectedSummary(');
    expect(purpose, isNonNegative);
    expect(readings, greaterThan(purpose));
    expect(version, greaterThan(readings));
    expect(config, greaterThan(readings));
    expect(overlay.substring(purpose, readings), isNot(contains('_mdbInfo')));
  });

  test('overlay names battery polling and backup work', () {
    final start = source.indexOf('Future<void> _runHealthCheck()');
    final end = source.indexOf('\n  Widget _buildInstallPlan(', start);
    final run = source.substring(start, end);
    expect(run, contains('_beginWait(['));
    expect(run, contains('l10n.waitingForBatteryData'));
    expect(run, contains('l10n.inspectingConfiguration'));
  });
}

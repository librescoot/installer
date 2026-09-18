import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  test('the welcome screen warns before anything starts on ARM64', () {
    final welcome = source.substring(
      source.indexOf('Widget _buildWelcome('),
      source.indexOf('Widget _buildNotices('),
    );
    expect(
      welcome,
      contains('_hostArch == HostArchVerdict.x64OnArm64'),
      reason: 'the advisory has to be gated on the emulated case, or every '
          'ordinary x64 machine gets a warning that does not apply to it',
    );
    expect(welcome, contains('l10n.arm64EmulationNoticeWelcome'));
  });

  test('the verdict is probed once, inside the startup check', () {
    final check = source.substring(
      source.indexOf('Future<void> _checkElevation() async {'),
      source.indexOf('Future<void> _checkForInstallerUpdate()'),
    );
    expect(check, contains('_hostArch = detectHostArchitecture();'));
    final startup = source.substring(
      source.indexOf('void initState() {'),
      source.indexOf('Future<String?> _promptManualRootPassword('),
    );
    expect(startup, contains('_checkElevation();'));
  });

  test('every other verdict stays quiet', () {
    final welcome = source.substring(
      source.indexOf('Widget _buildWelcome('),
      source.indexOf('Widget _buildNotices('),
    );
    for (final quiet in [
      'HostArchVerdict.nativeX64',
      'HostArchVerdict.nativeArm64',
      'HostArchVerdict.unknown',
      'HostArchVerdict.notWindows',
    ]) {
      expect(
        welcome,
        isNot(contains(quiet)),
        reason: '$quiet is not something to warn the user about',
      );
    }
  });
}

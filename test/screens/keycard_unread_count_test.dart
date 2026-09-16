import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A keycard count that has not been read must not render as zero.
///
/// The panel showed "0 cards taught" and offered "register at least one" while
/// it was still asking the board, which reads as an answer rather than a
/// question. A missing redis key, an unparseable value and a genuine zero were
/// all int 0.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('the counts are nullable, so unread survives to the render', () {
    expect(source, contains('int? _keycardMasterCount;'));
    expect(source, contains('int? _keycardAuthorizedCount;'));
  });

  test('a failed or absent read does not become zero', () {
    // int.tryParse(...) ?? 0 is what collapsed the three cases into one.
    expect(
      source,
      contains("_keycardAuthorizedCount = int.tryParse(a ?? '');"),
    );
    expect(source, isNot(contains("int.tryParse(a ?? '') ?? 0")));
    expect(source, isNot(contains("int.tryParse(m ?? '') ?? 0")));
  });

  test('the panel says it is checking rather than showing a count', () {
    expect(source, contains('l10n.keycardCardsChecking'));
    expect(source, contains('cards == null'));
  });

  test('both languages carry the checking string', () {
    for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_de.arb']) {
      expect(
        File(arb).readAsStringSync(),
        contains('"keycardCardsChecking"'),
        reason: '$arb is missing it',
      );
    }
  });

  test('keycard startup begins before the user unlock gate', () {
    final prestart = source.indexOf(
      'await _sshService.prestartKeycardService()',
    );
    final unlock = source.indexOf('await _waitForUnlock(l10n)');
    expect(prestart, greaterThan(-1));
    expect(unlock, greaterThan(prestart));
  });

  test('a freshly flashed MDB prestarts after restoring keycard files', () {
    final calls = RegExp(
      r'await _sshService\.prestartKeycardService\(\)',
    ).allMatches(source);
    expect(
      calls.length,
      2,
      reason: 'connect and post-flash paths both prestart',
    );
    expect(
      source,
      isNot(
        contains(
          'stopped librescoot-keycard to prevent accidental master teach-in',
        ),
      ),
    );
    expect(source, contains('prestarted librescoot-keycard after MDB restore'));
    final restore = source.indexOf('_configurationService.restore(');
    final prestart = source.indexOf(
      'prestarted librescoot-keycard after MDB restore',
    );
    expect(prestart, greaterThan(restore));
  });

  test('reader preparation runs behind the Bluetooth screen', () {
    final setPhase = source.indexOf('void _setPhase(InstallerPhase phase)');
    final end = source.indexOf('void _queueInstallPhaseRecord', setPhase);
    final block = source.substring(setPhase, end);

    expect(
      block,
      contains(
        'if (phase == InstallerPhase.bluetoothPairing) {\n'
        '      _fetchBleMac();\n'
        '      _beginKeycardSetupPreparation();',
      ),
    );
    expect(
      block,
      contains(
        'if (phase == InstallerPhase.keycardSetup && leaving != phase) {\n'
        '      _beginKeycardSetupPreparation();',
      ),
    );
  });

  test('an active prestarted service keeps its startup count', () {
    final setup = source.indexOf('Future<void> _onEnterKeycardSetup()');
    final end = source.indexOf('Future<void> _keycardAddKnownCards', setup);
    final block = source.substring(setup, end);
    expect(block, contains("final alreadyActive = activeState == 'active';"));
    expect(
      block,
      contains(
        "if (!alreadyActive) {\n        await _sshService.runCommand(\n          'redis-cli hdel system keycard-master-count",
      ),
    );
    expect(block, contains('librescoot-keycard was ready from prestart'));
  });
}

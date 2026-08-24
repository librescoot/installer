import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('UMS timeout restores AutoPlay unless flash takes the lease', () {
    final start = source.indexOf('Future<void> _configureMdbUms()');
    final end = source.indexOf('Widget _buildMdbFlash', start);
    final block = source.substring(start, end);

    expect(block, contains('var autoPlayHandedToFlash = false;'));
    expect(block, contains('autoPlayHandedToFlash = true;'));
    expect(block, contains('if (!autoPlayHandedToFlash)'));
    expect(block, contains('await DriverService.restoreAutoPlay();'));
  });

  test('success, rejection, cancellation, and failure share one restore', () {
    final start = source.indexOf('Future<void> _flashMdb()');
    final end = source.indexOf('Future<bool> _waitForMassStorageDevice', start);
    final block = source.substring(start, end);
    final finallyIndex = block.lastIndexOf('} finally {');

    expect(block, contains('await DriverService.suppressAutoPlay();'));
    expect(block, contains('if (!safetyCheck.passed)'));
    expect(block, contains('await flashService.writeTwoPhase('));
    expect(block, contains('} on DownloadWaitCancelled {'));
    expect(block, contains('} catch (e, stackTrace) {'));
    expect(
      finallyIndex,
      greaterThan(block.indexOf('if (!safetyCheck.passed)')),
    );
    expect(finallyIndex, greaterThan(block.indexOf('writeTwoPhase(')));
    expect(
      RegExp(r'DriverService\.restoreAutoPlay\(\)').allMatches(block).length,
      1,
    );
  });

  test('graceful close restores any outstanding AutoPlay lease', () {
    final start = source.indexOf('Future<void> _cleanupBeforeClose()');
    final end = source.indexOf('Future<bool> _shouldRetry', start);
    final block = source.substring(start, end);

    expect(block, contains('DriverService.restoreAutoPlay'));
    expect(source, contains('if (_windowClosing || !mounted) return;'));
  });
}

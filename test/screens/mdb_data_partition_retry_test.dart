import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('every data partition wait stops its caller when cancelled', () {
    expect(
      RegExp(
        r'if \(!await _waitForDataPartition\(\)\) return;',
      ).allMatches(source).length,
      3,
    );
    expect(source, isNot(contains('await _waitForDataPartition();')));
  });

  test('artifact retry clears a failed background data wait', () {
    final retry = source.indexOf('label: l10n.artifactRetry');
    final waitMethod = source.indexOf(
      'Future<bool> _waitForDataPartition()',
      retry,
    );
    final action = source.substring(retry, waitMethod);

    expect(action, contains('_artifactStarted = false;'));
    expect(action, contains('_mdbStageError = null;'));
    expect(action, contains('_mdbStageStarted = false;'));
    expect(action, contains('_mdbStageDone = false;'));
  });
}

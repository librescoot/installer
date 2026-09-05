import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  String methodBody(String signature, {String? until}) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: signature);
    if (until == null) return source.substring(start);
    final end = source.indexOf(until, start + signature.length);
    expect(end, isNot(-1), reason: 'end marker not found after $signature: $until');
    return source.substring(start, end);
  }

  group('a failed dashboard verification stops, rather than restarting itself',
      () {
    test('no failure path clears the flag the build guard reads', () {
      final body = methodBody(
        'Future<void> _verifyDbcFlash(int generation) async {',
        until: 'Future<void> _captureTrampolineEvidence(',
      );
      expect(body, isNot(contains('_reconnectStarted = false')));
    });

    test('the only place that clears it is leaving the screen', () {
      final clears = '_reconnectStarted = false'.allMatches(source).length;
      expect(clears, 2);
      expect(
        methodBody('void _returnToDbcPrep() {', until: '\n  }'),
        contains('_reconnectStarted = false'),
      );
    });

    test('the run is wrapped so an unguarded throw reaches the screen', () {
      final wrapper = methodBody(
        'Future<void> _startDbcVerification() async {',
        until: '\n  void _failReconnect(',
      );
      expect(wrapper, contains('await _verifyDbcFlash(generation)'));
      expect(wrapper, contains('} catch (e, stack) {'));
      expect(wrapper, contains('_ownsReconnect(generation)'));
      expect(wrapper, contains('_failReconnect('));
    });

    test('nothing starts a run except through that wrapper', () {
      expect('Future.microtask(_verifyDbcFlash)'.allMatches(source).length, 0);
      expect(
        'Future.microtask(_startDbcVerification)'.allMatches(source).length,
        2,
      );
    });

    test('a superseded run cannot clear the live one\'s state', () {
      final body = methodBody(
        'Future<void> _verifyDbcFlash(int generation) async {',
        until: 'Future<void> _captureTrampolineEvidence(',
      );
      for (final m in RegExp(r'_failReconnect\(').allMatches(body)) {
        final before = body.substring(
          (m.start - 400).clamp(0, body.length),
          m.start,
        );
        expect(before, contains('_ownsReconnect(generation)'),
            reason: 'unguarded _failReconnect at offset ${m.start}');
      }
    });
  });
}

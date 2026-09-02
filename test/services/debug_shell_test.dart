import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/debug_shell.dart';

void main() {
  test('the shell is cmd.exe on Windows and /bin/sh elsewhere', () {
    expect(DebugShell.shellCommand('id', windows: true), [
      'cmd.exe',
      '/c',
      'id',
    ]);
    expect(DebugShell.shellCommand('id', windows: false), [
      '/bin/sh',
      '-c',
      'id',
    ]);
  });

  group('with a real shell', () {
    setUp(() {
      if (Platform.isWindows) {
        markTestSkipped('the process tests need /bin/sh');
      }
    });

    test('output arrives while the command is still running', () async {
      final lines = <String>[];
      final shell = DebugShell(appendLine: lines.add);
      expect(await shell.run('echo first; sleep 2; echo second'), isTrue);
      expect(shell.running, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(lines, contains('first'));
      expect(lines, isNot(contains('second')));

      await shell.finished;
      expect(lines, containsAllInOrder(['first', 'second', 'exit: 0']));
      expect(shell.running, isFalse);
    });

    test('a command that reads stdin gets EOF instead of waiting', () async {
      final lines = <String>[];
      final shell = DebugShell(appendLine: lines.add);
      expect(await shell.run('cat; echo done'), isTrue);
      await shell.finished.timeout(const Duration(seconds: 5));
      expect(lines, containsAllInOrder(['done', 'exit: 0']));
    });

    test('stop ends a command that would never finish', () async {
      final lines = <String>[];
      final shell = DebugShell(appendLine: lines.add);
      expect(await shell.run('sleep 60'), isTrue);
      await shell.stop().timeout(const Duration(seconds: 5));
      expect(shell.running, isFalse);
      expect(lines.last, startsWith('exit: '));
      expect(lines.last, isNot('exit: 0'));
    });

    test('a second command is refused while one is running', () async {
      final lines = <String>[];
      final shell = DebugShell(appendLine: lines.add);
      expect(await shell.run('sleep 60'), isTrue);
      expect(await shell.run('echo no'), isFalse);
      expect(lines, isNot(contains('no')));
      await shell.stop();
    });

    test('stderr is labelled and blank input is ignored', () async {
      final lines = <String>[];
      final shell = DebugShell(appendLine: lines.add);
      expect(await shell.run('   '), isFalse);
      expect(lines, isEmpty);
      expect(await shell.run('echo oops >&2'), isTrue);
      await shell.finished;
      expect(
        lines,
        containsAllInOrder(['> echo oops >&2', 'stderr: oops', 'exit: 0']),
      );
    });

    test('listeners fire on start and on exit', () async {
      var notified = 0;
      final shell = DebugShell(appendLine: (_) {})
        ..addListener(() => notified++);
      await shell.run('true');
      await shell.finished;
      expect(notified, 2);
    });
  });
}

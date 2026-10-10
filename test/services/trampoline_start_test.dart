import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the pattern matches the path the script is launched from', () async {
    // The bug was invisible to reading: both strings look like a trampoline
    // path. Run the match instead.
    final root = await Directory.systemTemp.createTemp('tramp-');
    addTearDown(() => root.delete(recursive: true));
    final scripts = Directory('${root.path}/installer/scripts');
    await scripts.create(recursive: true);
    final script = File('${scripts.path}/trampoline.sh');
    await script.writeAsString('#!/bin/sh\nsleep 20\n');
    await Process.run('chmod', ['+x', script.path]);

    final proc = await Process.start('sh', [script.path]);
    addTearDown(proc.kill);
    await Future.delayed(const Duration(milliseconds: 300));

    final good = await Process.run('pgrep', [
      '-f',
      'installer/scripts/[t]rampoline.sh',
    ]);
    expect(
      good.stdout.toString().trim(),
      isNotEmpty,
      reason: 'the shared pattern must find a running trampoline',
    );

    final old = await Process.run('pgrep', ['-f', 'installer/[t]rampoline.sh']);
    expect(
      old.stdout.toString().trim(),
      isEmpty,
      reason: 'the old pattern never could, which is the bug',
    );
  });
}

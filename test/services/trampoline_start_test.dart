import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// start() launches the trampoline with nohup and then asks whether it is
/// running, because nohup reports success either way. The two halves used
/// different patterns and the asking half could not match the path the script
/// runs from, so every run reported "Trampoline did not start on the MDB"
/// after the user had already been told to swap the cable.
void main() {
  late String source;

  setUpAll(() {
    source =
        File('lib/services/trampoline_service.dart').readAsStringSync();
  });

  test('one pattern, used by both the kill and the check', () {
    expect(source, contains("_trampolinePattern = 'installer/scripts/[t]rampoline.sh'"));
    expect(source, contains("pkill -f '\$_trampolinePattern'"));
    expect(source, contains("pgrep -f '\$_trampolinePattern'"));
    // No hand-written copy left to drift again.
    expect(RegExp(r"'installer/\[t\]rampoline\.sh'").hasMatch(source), isFalse,
        reason: 'a literal pattern is still in there');
  });

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

    final good = await Process.run(
        'pgrep', ['-f', 'installer/scripts/[t]rampoline.sh']);
    expect(good.stdout.toString().trim(), isNotEmpty,
        reason: 'the shared pattern must find a running trampoline');

    final old = await Process.run('pgrep', ['-f', 'installer/[t]rampoline.sh']);
    expect(old.stdout.toString().trim(), isEmpty,
        reason: 'the old pattern never could, which is the bug');
  });
}

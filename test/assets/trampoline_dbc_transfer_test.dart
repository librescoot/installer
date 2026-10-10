import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('assets/trampoline.sh.template').readAsStringSync();
  });

  test('dbc_put is valid POSIX shell', () async {
    final start = source.indexOf('dbc_put() {');
    final end = source.indexOf('\n}\n', start) + 3;
    final directory = await Directory.systemTemp.createTemp('dbc-put-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/dbc_put.sh');
    await script.writeAsString(source.substring(start, end));

    final syntax = await Process.run('sh', ['-n', script.path]);
    expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
  });
}

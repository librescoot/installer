import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the shell template and generated onboot phase parse', () {
    final template = File('assets/trampoline.sh.template');
    final templateResult = Process.runSync('bash', ['-n', template.path]);
    expect(
      templateResult.exitCode,
      0,
      reason: templateResult.stderr.toString(),
    );

    final chunks = RegExp(
      r'''cat >>? [^\n]*20-dbc\.sh" << (')?([A-Z_]+)\1?\n([\s\S]*?)\n\2\n''',
    ).allMatches(template.readAsStringSync());
    final generated = chunks
        .map((chunk) {
          final body = chunk.group(3)!;
          return chunk.group(1) == "'" ? body : body.replaceAll(r'\$', r'$');
        })
        .join('\n');
    expect(generated, isNotEmpty);
    final dir = Directory.systemTemp.createTempSync('installer_onboot_syntax_');
    try {
      final script = File('${dir.path}/20-dbc.sh')
        ..writeAsStringSync(generated);
      final result = Process.runSync('bash', ['-n', script.path]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}

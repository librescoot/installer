import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProcessResult> validate(String filename) =>
      Process.run('python3', ['tool/validate_release_manifest.py', filename]);

  test('the bundled fallback is a complete current-shape manifest', () async {
    final result = await validate('assets/latest.json.fallback');
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('syntactically valid but incomplete manifests are rejected', () async {
    final temp = await Directory.systemTemp.createTemp('manifest-shape-test-');
    addTearDown(() => temp.delete(recursive: true));
    final manifest = File('${temp.path}/latest.json')
      ..writeAsStringSync(jsonEncode(<String, Object?>{}));

    final result = await validate(manifest.path);

    expect(result.exitCode, 1);
    expect(result.stderr.toString(), contains('missing stable release'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Map<String, String>> derive(String version, String run) async {
    final result = await Process.run('sh', [
      'tool/native_version.sh',
      version,
      run,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    return {
      for (final line in result.stdout.toString().trim().split('\n'))
        line.split('=').first: line.substring(line.indexOf('=') + 1),
    };
  }

  test('beta tag produces native semver and numeric beta build', () async {
    expect(await derive('v1.4.0-beta.5', '123'), {
      'name': '1.4.0',
      'build': '5',
    });
  });

  test('stable and development builds use the workflow run number', () async {
    expect(await derive('v1.4.0', '123'), {'name': '1.4.0', 'build': '123'});
    expect(await derive('v1.4.0-beta.5-2-gabcdef', '124'), {
      'name': '1.4.0',
      'build': '124',
    });
  });
}

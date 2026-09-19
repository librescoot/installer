import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File(
    '.github/workflows/build-desktop.yml',
  ).readAsStringSync();

  test('fallback refresh validates a temporary file before replacement', () {
    final start = workflow.indexOf(
      '- name: Refresh bundled latest.json fallback',
    );
    final end = workflow.indexOf('- name: Import signing certificate', start);
    final step = workflow.substring(start, end);

    expect(step, contains('tmp=\$(mktemp'));
    expect(step, contains(r'tool/validate_release_manifest.py "$tmp"'));
    expect(
      step.indexOf('validate_release_manifest.py'),
      lessThan(step.indexOf('mv -f')),
    );
    expect(step, isNot(contains('-o assets/latest.json.fallback')));
  });

  test('desktop builds and artifact checks use derived native versions', () {
    for (final platform in ['macos', 'linux', 'windows']) {
      final build = RegExp(
        'flutter build $platform[^\\n]+',
      ).firstMatch(workflow)?.group(0);
      expect(build, isNotNull, reason: 'missing $platform build');
      expect(
        build,
        contains('--build-name=\${{ steps.version.outputs.name }}'),
      );
      expect(
        build,
        contains('--build-number=\${{ steps.version.outputs.build }}'),
      );
      expect(build, contains('--dart-define=APP_VERSION='));
    }
    expect(workflow, contains('Verify macOS version metadata'));
    expect(workflow, contains('Verify Windows version metadata'));
    expect(
      workflow,
      contains(
        r'$numeric = "${{ steps.version.outputs.name }}.${{ steps.version.outputs.build }}"',
      ),
    );
    expect(workflow, contains(r'$wrapper.FileVersionRaw.ToString()'));
  });
}

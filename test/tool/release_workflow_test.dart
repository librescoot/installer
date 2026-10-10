import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File(
    '.github/workflows/build-desktop.yml',
  ).readAsStringSync();

  test('stable releases test; pushes and betas build without the suite', () {
    final testJob = workflow.substring(
      workflow.indexOf('  test:\n'),
      workflow.indexOf('  build:\n'),
    );
    expect(
      testJob,
      contains(
        "startsWith(github.ref, 'refs/tags/v') && !contains(github.ref_name, '-')",
      ),
    );
    expect(
      testJob,
      contains(
        "inputs.release_tag != '' && !contains(inputs.release_tag, '-')",
      ),
    );
    expect(testJob, contains('inputs.run_tests == true'));
    expect(workflow, contains('type: boolean\n        default: false'));
    final buildJob = workflow.substring(workflow.indexOf('  build:\n'));
    expect(buildJob, contains('needs: test'));
    expect(
      buildJob,
      contains(
        "!cancelled() && (needs.test.result == 'success' || needs.test.result == 'skipped')",
      ),
    );
  });

  test(
    'release runs after successful builds even with a skipped test ancestor',
    () {
      final releaseJob = workflow.substring(workflow.indexOf('  release:\n'));
      final condition = releaseJob.substring(
        releaseJob.indexOf('    if: >-'),
        releaseJob.indexOf('    runs-on:'),
      );
      expect(releaseJob, contains('needs: build'));
      // An explicit status function suppresses GitHub's implicit success(),
      // which also considers skipped jobs earlier in the dependency chain.
      expect(condition, contains('!cancelled()'));
      expect(condition, contains("needs.build.result == 'success'"));
      expect(condition, contains("startsWith(github.ref, 'refs/tags/v')"));
      expect(condition, contains("inputs.release_tag != ''"));
      expect(condition, isNot(contains('success()')));
    },
  );

  test('beta releases refresh downloads but do not promote the main site', () {
    final token = workflow.substring(
      workflow.indexOf('- name: Generate app token for site rebuilds'),
      workflow.indexOf('- name: Trigger downloads site rebuild'),
    );
    final downloads = workflow.substring(
      workflow.indexOf('- name: Trigger downloads site rebuild'),
      workflow.indexOf('- name: Trigger main site rebuild'),
    );
    expect(token, isNot(contains('if:')));
    expect(downloads, isNot(contains('if:')));
    expect(downloads, contains('releases-changed'));
    final main = workflow.substring(
      workflow.indexOf('- name: Trigger main site rebuild'),
    );
    expect(
      main,
      contains("!contains(inputs.release_tag || github.ref_name, '-')"),
    );
  });

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

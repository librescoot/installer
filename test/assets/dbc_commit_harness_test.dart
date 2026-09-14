import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _commitDispatch(String source) {
  final start = source.indexOf(
    '    COMMIT_OUT="\$INSTALLER_DIR/dbc-commit.stdout"',
  );
  final end = source.indexOf(
    '\n\n    # Keep the installed updater suppressed',
    start,
  );
  if (start < 0 || end < 0) throw StateError('commit dispatch not found');
  return source
      .substring(start, end)
      .split('\n')
      .map((line) => line.startsWith('    ') ? line.substring(4) : line)
      .join('\n');
}

void main() {
  late Directory root;
  late File error;
  late String dispatch;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dbc_commit_harness_');
    error = File('${root.path}/error');
    dispatch = _commitDispatch(
      File('assets/trampoline.sh.template').readAsStringSync(),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProcessResult run(String mode) {
    final script = File('${root.path}/scenario.sh')
      ..writeAsStringSync('''#!/bin/sh
INSTALLER_DIR='${root.path}'
DBC_EXPECTED_ARTIFACT=release-v1.4.0
DBC_HEALTH_BOOT=boot-new
DBC_HEALTH_ROOT=179:3
DBC_VER=v1.4.0
DBC_ART_AFTER=release-v1.4.0
log() { :; }
artifact_fail() { printf '%s\n' "\$1" > '${error.path}'; exit 70; }
dbc_commit_verified() { return 0; }
dbc_ssh_once_bounded() {
  case '$mode' in
    success) printf '__MENDER_REMOTE_RC=0\ncommitted\n'; return 0 ;;
    remote-failure) printf '__MENDER_REMOTE_RC=7\n'; echo refused >&2; return 0 ;;
    transport-loss) echo disconnected >&2; return 1 ;;
  esac
}
$dispatch
''');
    return Process.runSync('sh', [script.path]);
  }

  test('accepts only a transported zero remote exit', () {
    final result = run('success');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(error.existsSync(), isFalse);
  });

  test('distinguishes a remote commit failure from transport loss', () {
    var result = run('remote-failure');
    expect(result.exitCode, 70);
    expect(error.readAsStringSync(), contains('commit returned exit 7'));

    error.deleteSync();
    result = run('transport-loss');
    expect(result.exitCode, 70);
    expect(error.readAsStringSync(), contains('commit outcome is unknown'));
  });
}

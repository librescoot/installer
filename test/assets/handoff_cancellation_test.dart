import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'handoff cancellation disarms boot phases and records cancellation',
    () async {
      final root = await Directory.systemTemp.createTemp('handoff-cancel-');
      addTearDown(() => root.delete(recursive: true));
      final template = await File(
        'assets/trampoline.sh.template',
      ).readAsString();
      final stateFunctions = template.substring(
        template.indexOf('write_run_state() {'),
        template.indexOf('# Per-step elapsed-time'),
      );
      final cancellation = template.substring(
        template.indexOf('if [ "\$HANDOFF_RESULT" -eq 2 ]; then'),
        template.indexOf('[ "\$HANDOFF_RESULT" -ne 3 ]'),
      );
      final scripts = Directory('${root.path}/scripts')..createSync();
      for (final name in [
        '10-mdb-artifact.sh',
        '10-mdb-artifact.sh.tries',
        '80-reboot.sh',
        '90-finalize.sh',
        '.expected',
        'signal.sh',
        'device.sh',
      ]) {
        File('${scripts.path}/$name').writeAsStringSync('retained');
      }
      final result = await Process.run('sh', [
        '-c',
        '''
INSTALLER_DIR='${root.path}'
SCRIPTS_DIR="\$INSTALLER_DIR/scripts"
STATUS_FILE="\$INSTALLER_DIR/trampoline-status"
LOG_FILE="\$INSTALLER_DIR/trampoline.log"
RUN_HISTORY_DIR="\$INSTALLER_DIR/history"
RUN_STATE_FILE="\$INSTALLER_DIR/run-state"
HANDOFF_DIR="\$INSTALLER_DIR/handoff-test-run"
RUN_ID=test-run
STEP_LABEL=waiting-for-dashboard
mkdir -p "\$HANDOFF_DIR"
: > "\$LOG_FILE"
signal_all_off() { :; }
dbc_update_complete() { :; }
fail() { exit 1; }
WAIT_KEYCARD_UNITS=''
$stateFunctions
HANDOFF_RESULT=2
$cancellation
''',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        scripts.listSync().map((f) => f.uri.pathSegments.last),
        unorderedEquals(['signal.sh', 'device.sh']),
      );
      expect(
        File('${root.path}/trampoline-status').readAsStringSync(),
        startsWith('cancelled\n'),
      );
      for (final path in ['run-state', 'history/test-run/record']) {
        expect(
          File('${root.path}/$path').readAsStringSync(),
          contains('result: cancelled\n'),
        );
      }
      expect(
        File('${root.path}/handoff-test-run/result').readAsStringSync(),
        'cancelled\n',
      );
    },
  );
}

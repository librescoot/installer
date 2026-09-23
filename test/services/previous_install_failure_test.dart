import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/previous_install_failure.dart';

void main() {
  Future<PreviousInstallFailure?> probe({
    String status = '',
    String state = '',
    String completion = '',
    String currentLog = '',
    String archivedLog = '',
    List<String>? commands,
  }) => probePreviousInstallFailure((command) async {
    commands?.add(command);
    if (command.contains('trampoline-status')) return status;
    if (command.contains('installer/run-state')) return state;
    if (command.contains('last-install')) return completion;
    if (command.contains('history/')) return archivedLog;
    if (command.contains('trampoline.log')) return currentLog;
    throw StateError(command);
  });

  test('reads retained failed status and its current log', () async {
    final failure = await probe(
      status: 'error: DBC did not finish\nrun-id: 123\n',
      state: 'run-id: 123\nresult: error\nstage: dbcFlash\n',
      currentLog: 'flash failed\n',
    );
    expect(failure?.reason, 'error: DBC did not finish');
    expect(failure?.logTail, 'flash failed');
    expect(failure?.runId, '123');
  });

  test('reads archived log after staging was swept', () async {
    final commands = <String>[];
    final failure = await probe(
      state: 'run-id: run-5\nresult: error\nstage: dbcFlash\n',
      archivedLog: 'retained failure\n',
      commands: commands,
    );
    expect(failure?.reason, 'dbcFlash');
    expect(failure?.logTail, 'retained failure');
    expect(commands, contains(contains('history/run-5/trampoline.log')));
  });

  test('does not report successful installs or their routine logs', () async {
    final commands = <String>[];
    expect(
      await probe(
        status: 'success\nrun-id: 123\n',
        state: 'run-id: 123\nresult: success\n',
        currentLog: 'routine output',
        commands: commands,
      ),
      isNull,
    );
    expect(
      commands.any((command) => command.contains('trampoline.log')),
      false,
    );
  });

  test('completed same run suppresses a stale failure status', () async {
    expect(
      await probe(
        status: 'error: transient\nrun-id: 123\n',
        completion: 'run-id: 123\nresult: success\nfinish: complete\n',
      ),
      isNull,
    );
  });

  test('rejects unsafe run identifiers in the archived path', () async {
    final commands = <String>[];
    await probe(
      state: 'run-id: ../../etc\nresult: error\nstage: dbcFlash\n',
      commands: commands,
    );
    expect(commands.any((command) => command.contains('history/')), false);
  });
}

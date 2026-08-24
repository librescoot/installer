import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';

void main() {
  test('a completion record parses as success', () {
    // A device that finishes on its own sweeps the staging directory, and the
    // status file goes with it. The completion record is what is left, and the
    // reconnect has to read a verdict out of it or it waits for a file that
    // will never come back.
    const record = 'result: success\n'
        'run-id: run-abc-1\n'
        'finish: complete\n'
        'mode: flash\n'
        'finished: 2026-08-22T14:49:45Z\n'
        'mdb: nightly-20260822T020747\n'
        'dbc: nightly-20260822t020747\n';
    final status = TrampolineStatus.parseCompletionRecord(record);
    expect(status.result, TrampolineResult.success);
    expect(status.completedFor('run-abc-1'), isTrue);
  });

  test('a stale completion record cannot finish the current run', () {
    const record = 'result: success\n'
        'run-id: run-old-1\n'
        'finish: complete\n';
    final status = TrampolineStatus.parseCompletionRecord(record);
    expect(status.completedFor('run-current-2'), isFalse);
  });

  test('a record written before handover completed is not completion', () {
    const record = 'result: success\n'
        'run-id: run-current-2\n'
        'finish: pending\n';
    final status = TrampolineStatus.parseCompletionRecord(record);
    expect(status.completedFor('run-current-2'), isFalse);
  });

  test('running is not a verdict', () {
    // Written before the dashboard work starts, so it means "not finished",
    // never "finished well".
    expect(TrampolineStatus.parse('running\n').result,
        isNot(TrampolineResult.success));
  });

  test('an error stays an error', () {
    expect(TrampolineStatus.parse('error: DBC not reachable\n').result,
        TrampolineResult.error);
  });
}

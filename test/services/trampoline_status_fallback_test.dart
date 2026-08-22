import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';

void main() {
  test('a completion record parses as success', () {
    // A device that finishes on its own sweeps the staging directory, and the
    // status file goes with it. The completion record is what is left, and the
    // reconnect has to read a verdict out of it or it waits for a file that
    // will never come back.
    const record = 'result: success\n'
        'mode: flash\n'
        'finished: 2026-08-22T14:49:45Z\n'
        'mdb: nightly-20260822T020747\n'
        'dbc: nightly-20260822t020747\n';
    final status = TrampolineStatus.parse(
        record.replaceFirst(RegExp(r'^result:\s*'), ''));
    expect(status.result, TrampolineResult.success);
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

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';

/// The laptop finish writes this record now. Only the device finish used to,
/// so a run the laptop closed out left `stage: finish, result: running`
/// behind and the next connect read a finished install as an abandoned one.
///
/// The reader is the trampoline's, so the shape has to be the trampoline's:
/// `result:` alone on the first line, everything else as `key: value` under
/// it, because parseCompletionRecord strips the first line's prefix and scans
/// only the tail for fields.
void main() {
  String record({
    String runId = 'run-abc-123',
    String mode = 'flash',
    String mdb = 'v1.2.1',
    String dbc = '',
  }) =>
      [
        'result: success',
        'run-id: $runId',
        'finish: complete',
        'stage: complete',
        'mode: $mode',
        'finished: 2026-08-26T16:18:11Z',
        'mdb: $mdb',
        'dbc: $dbc',
        '',
      ].join('\n');

  test('a laptop-written record reads as complete for its own run', () {
    final parsed = TrampolineStatus.parseCompletionRecord(record());
    expect(parsed.completedFor('run-abc-123'), isTrue);
  });

  test('it does not vouch for a different run', () {
    // The record outlives the run it describes, and the next install asks
    // whether THIS run finished, not whether one ever did.
    final parsed = TrampolineStatus.parseCompletionRecord(record());
    expect(parsed.completedFor('run-xyz-999'), isFalse);
  });

  test('an MDB-only run leaves the dashboard field empty, not invented', () {
    final parsed = TrampolineStatus.parseCompletionRecord(record(dbc: ''));
    expect(parsed.completedFor('run-abc-123'), isTrue);
  });

  test('the old running state is not mistaken for a finish', () {
    // What an MDB-only run used to leave behind.
    const stale = 'run-id: run-abc-123\n'
        'actor: installer\n'
        'stage: finish\n'
        'result: running\n'
        'finish: pending\n';
    expect(
      TrampolineStatus.parseCompletionRecord(stale).completedFor('run-abc-123'),
      isFalse,
    );
  });
}

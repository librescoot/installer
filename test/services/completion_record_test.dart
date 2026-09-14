import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';

/// The laptop finish writes this record now. Only the device finish used to,
/// so a run the laptop closed out left `stage: finish, result: running`
/// behind and the next connect read a finished install as an abandoned one.
void main() {
  String record({
    String runId = 'run-abc-123',
    String mode = 'flash',
    String mdb = 'v1.2.1',
    String dbc = '',
    String dashboardResult = 'complete',
  }) => [
    'result: success',
    'run-id: $runId',
    'finish: complete',
    'stage: complete',
    'mode: $mode',
    'finished: 2026-08-26T16:18:11Z',
    'mdb: $mdb',
    'dbc: $dbc',
    'dashboard-result: $dashboardResult',
    '',
  ].join('\n');

  test('a laptop-written record reads as complete for its own run', () {
    final parsed = TrampolineStatus.parseCompletionRecord(record());
    expect(
      parsed.completionFor('run-abc-123'),
      InstallCompletionOutcome.complete,
    );
  });

  test('it does not vouch for a different run', () {
    final parsed = TrampolineStatus.parseCompletionRecord(record());
    expect(
      parsed.completionFor('run-xyz-999'),
      InstallCompletionOutcome.notComplete,
    );
  });

  test('an MDB-only run leaves the dashboard field empty, not invented', () {
    final parsed = TrampolineStatus.parseCompletionRecord(record(dbc: ''));
    expect(
      parsed.completionFor('run-abc-123'),
      InstallCompletionOutcome.complete,
    );
  });

  test('an incomplete dashboard result remains a completed unsafe run', () {
    final parsed = TrampolineStatus.parseCompletionRecord(
      record(dashboardResult: 'incomplete'),
    );
    expect(parsed.dashboardResult, DashboardResult.incomplete);
    expect(
      parsed.completionFor('run-abc-123'),
      InstallCompletionOutcome.incomplete,
    );
  });

  test('the old running state is not mistaken for a finish', () {
    const stale =
        'run-id: run-abc-123\n'
        'actor: installer\n'
        'stage: finish\n'
        'result: running\n'
        'finish: pending\n';
    expect(
      TrampolineStatus.parseCompletionRecord(
        stale,
      ).completionFor('run-abc-123'),
      InstallCompletionOutcome.notComplete,
    );
  });
}

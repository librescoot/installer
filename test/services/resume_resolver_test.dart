import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/install_state.dart';
import 'package:librescoot_installer/models/installer_phase.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';
import 'package:librescoot_installer/services/resume_resolver.dart';

void main() {
  group('resolveResume', () {
    test('no state and no trampoline status -> fresh connect', () {
      final d = resolveResume(state: null, status: null);
      expect(d.phase, InstallerPhase.healthCheck);
      expect(d.skipUnlockGate, false);
    });
    test('mid Stage-1 (keycard-enrolled) resumes at dashboardPrep, skips gate', () {
      final d = resolveResume(
        state: InstallState(phase: InstallPhase.keycardEnrolled),
        status: null,
      );
      expect(d.phase, InstallerPhase.dashboardPrep);
      expect(d.skipUnlockGate, true);
      expect(d.bluetoothDone, true);
      expect(d.keycardDone, true);
    });
    test('trampoline armed + status success -> finished', () {
      final d = resolveResume(
        state: InstallState(phase: InstallPhase.trampolineArmed),
        status: TrampolineStatus.parse('success\nok'),
      );
      expect(d.phase, InstallerPhase.finish);
    });
    test('trampoline armed + status error -> swap/flash with error surfaced', () {
      final d = resolveResume(
        state: InstallState(phase: InstallPhase.trampolineArmed),
        status: TrampolineStatus.parse('error: DBC UMS not found\nlog'),
      );
      expect(d.phase, InstallerPhase.dbcSwapAndFlash);
      expect(d.previousError, contains('DBC UMS not found'));
    });
    test('trampoline armed + status unknown -> still running, swap/flash, no error', () {
      final d = resolveResume(
        state: InstallState(phase: InstallPhase.trampolineArmed),
        status: TrampolineStatus.parse(''),
      );
      expect(d.phase, InstallerPhase.dbcSwapAndFlash);
      expect(d.previousError, isNull);
    });
    test('legacy leftover (no state.json) but trampoline-status error -> skip gate, surface', () {
      final d = resolveResume(
        state: null,
        status: TrampolineStatus.parse('error: stalled in host mode'),
      );
      expect(d.skipUnlockGate, true);
      expect(d.previousError, contains('stalled in host mode'));
    });
  });
}

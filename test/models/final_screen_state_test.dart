import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/final_screen_state.dart';

void main() {
  group('finalScreenState', () {
    test('does not claim success until the completion record is confirmed', () {
      expect(
        finalScreenState(
          laptopOccupiesMdbUsb: false,
          completionConfirmed: false,
        ),
        FinalScreenState.finishingOnDevice,
      );
    });

    test('asks to restore the DBC cable when the laptop occupies the port', () {
      expect(
        finalScreenState(
          laptopOccupiesMdbUsb: true,
          completionConfirmed: false,
        ),
        FinalScreenState.reconnectDbc,
      );
    });

    test('a plan with no dashboard work finishes on the laptop cable', () {
      // The coordinator installs the MDB artifact, reboots and unlocks with
      // whatever is in the port. The DBC cable is for reassembly, not for
      // the install, so the screen must not say the install needs it.
      expect(
        finalScreenState(
          laptopOccupiesMdbUsb: true,
          completionConfirmed: false,
          dashboardWorkPending: false,
        ),
        FinalScreenState.finishingOnDevice,
      );
    });

    test('keeps the cable step after a confirmed reconnect', () {
      expect(
        finalScreenState(
          laptopOccupiesMdbUsb: true,
          completionConfirmed: true,
        ),
        FinalScreenState.completedReconnectDbc,
      );
    });

    test('reports success only when no cable step remains', () {
      expect(
        finalScreenState(
          laptopOccupiesMdbUsb: false,
          completionConfirmed: true,
        ),
        FinalScreenState.completed,
      );
    });
  });
}

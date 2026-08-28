import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/final_screen_state.dart';

void main() {
  group('finalScreenState', () {
    test('does not claim success until the completion record is confirmed', () {
      expect(
        finalScreenState(
          planNeedsHandoff: true,
          laptopAttached: false,
          completionConfirmed: false,
        ),
        FinalScreenState.finishingOnDevice,
      );
    });

    test('asks to restore the DBC cable when the laptop is attached', () {
      expect(
        finalScreenState(
          planNeedsHandoff: true,
          laptopAttached: true,
          completionConfirmed: false,
        ),
        FinalScreenState.reconnectDbc,
      );
    });

    test('keeps the cable step after a confirmed reconnect', () {
      expect(
        finalScreenState(
          planNeedsHandoff: true,
          laptopAttached: true,
          completionConfirmed: true,
        ),
        FinalScreenState.completedReconnectDbc,
      );
    });

    test('reports success only when no cable step remains', () {
      expect(
        finalScreenState(
          planNeedsHandoff: true,
          laptopAttached: false,
          completionConfirmed: true,
        ),
        FinalScreenState.completed,
      );
    });

    test('a confirmed MDB-only run still restores the cable after reconnect', () {
      expect(
        finalScreenState(
          planNeedsHandoff: false,
          laptopAttached: true,
          completionConfirmed: true,
        ),
        FinalScreenState.completedReconnectDbc,
      );
    });
  });
}

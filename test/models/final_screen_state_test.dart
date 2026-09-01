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

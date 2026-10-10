import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/critical_operation_coordinator.dart';

void main() {
  test('overlapping operations stay critical until the last owner exits', () {
    final transitions = <bool>[];
    final coordinator = CriticalOperationCoordinator(
      onChanged: transitions.add,
    );

    final mdbGate = coordinator.acquire();
    final dbcUpload = coordinator.acquire();
    dbcUpload.release();

    expect(coordinator.isCritical, isTrue);
    expect(transitions, [true]);

    mdbGate.release();
    expect(coordinator.isCritical, isFalse);
    expect(transitions, [true, false]);
  });

  test('a lease can only release its own acquisition once', () {
    final transitions = <bool>[];
    final coordinator = CriticalOperationCoordinator(
      onChanged: transitions.add,
    );
    final lease = coordinator.acquire();

    lease.release();
    lease.release();

    expect(coordinator.isCritical, isFalse);
    expect(transitions, [true, false]);
  });
}

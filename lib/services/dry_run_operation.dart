import 'critical_operation_coordinator.dart';

typedef DryRunDelay = Future<void> Function();

class DryRunReconnectOperation {
  const DryRunReconnectOperation();

  Future<void> execute({
    required DryRunDelay delay,
    required bool Function() owns,
    required void Function() onOwned,
  }) async {
    await delay();
    if (owns()) onOwned();
  }
}

class DryRunUploadOperation {
  const DryRunUploadOperation();

  Future<void> execute({
    required CriticalOperationCoordinator coordinator,
    required DryRunDelay delay,
    required bool Function() owns,
    required void Function() onOwned,
  }) async {
    final lease = coordinator.acquire();
    try {
      await delay();
      if (owns()) onOwned();
    } finally {
      lease.release();
    }
  }
}

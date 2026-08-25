class CriticalOperationCoordinator {
  CriticalOperationCoordinator({required void Function(bool) onChanged})
      : _onChanged = onChanged;

  final void Function(bool) _onChanged;
  final Set<CriticalOperationLease> _leases = {};

  bool get isCritical => _leases.isNotEmpty;

  CriticalOperationLease acquire() {
    late final CriticalOperationLease lease;
    lease = CriticalOperationLease._(() {
      if (!_leases.remove(lease)) return;
      if (_leases.isEmpty) _onChanged(false);
    });
    final wasIdle = _leases.isEmpty;
    _leases.add(lease);
    if (wasIdle) _onChanged(true);
    return lease;
  }
}

class CriticalOperationLease {
  CriticalOperationLease._(this._release);

  void Function()? _release;

  void release() {
    final release = _release;
    if (release == null) return;
    _release = null;
    release();
  }
}

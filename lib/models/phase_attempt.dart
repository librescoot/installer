enum PhaseAttemptStatus { ready, running, failed, completed }

class PhaseAttempt {
  PhaseAttemptStatus _status = PhaseAttemptStatus.ready;
  int _generation = 0;
  Object? _error;

  PhaseAttemptStatus get status => _status;
  Object? get error => _error;
  bool get isRunning => _status == PhaseAttemptStatus.running;
  bool get isFailed => _status == PhaseAttemptStatus.failed;

  int? begin() {
    if (_status == PhaseAttemptStatus.running ||
        _status == PhaseAttemptStatus.completed) {
      return null;
    }
    _status = PhaseAttemptStatus.running;
    _error = null;
    return ++_generation;
  }

  bool complete(int generation) {
    if (!isCurrent(generation)) return false;
    _status = PhaseAttemptStatus.completed;
    _error = null;
    return true;
  }

  bool fail(int generation, [Object? error]) {
    if (!isCurrent(generation)) return false;
    _status = PhaseAttemptStatus.failed;
    _error = error;
    return true;
  }

  void reset() {
    _generation++;
    _status = PhaseAttemptStatus.ready;
    _error = null;
  }

  bool isCurrent(int generation) {
    return generation == _generation && _status == PhaseAttemptStatus.running;
  }
}

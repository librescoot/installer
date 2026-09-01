import 'dart:async';

typedef SerialPollAction = Future<void> Function(PollGeneration generation);

class PollGeneration {
  const PollGeneration._(this._loop, this._value);

  final SerialPollingLoop _loop;
  final int _value;

  bool get isCurrent => _loop._running && _loop._generation == _value;
}

class SerialPollingLoop {
  Timer? _timer;
  Future<void>? _inFlight;
  bool _running = false;
  int _generation = 0;

  bool get isRunning => _running;

  void start({
    required Duration interval,
    required SerialPollAction poll,
    bool immediately = false,
  }) {
    if (_running) return;
    _running = true;
    final generation = PollGeneration._(this, ++_generation);
    _schedule(
      generation: generation,
      interval: interval,
      poll: poll,
      delay: immediately ? Duration.zero : interval,
    );
  }

  Future<void> stop() async {
    _running = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
    final inFlight = _inFlight;
    if (inFlight != null) await inFlight;
  }

  void _schedule({
    required PollGeneration generation,
    required Duration interval,
    required SerialPollAction poll,
    required Duration delay,
  }) {
    if (!generation.isCurrent) return;
    _timer = Timer(delay, () {
      _timer = null;
      final run = _run(generation: generation, interval: interval, poll: poll);
      _inFlight = run;
      unawaited(
        run.whenComplete(() {
          if (identical(_inFlight, run)) _inFlight = null;
        }),
      );
    });
  }

  Future<void> _run({
    required PollGeneration generation,
    required Duration interval,
    required SerialPollAction poll,
  }) async {
    try {
      await poll(generation);
    } catch (_) {
      // Polling is best-effort. The caller can log failures when useful.
    } finally {
      _schedule(
        generation: generation,
        interval: interval,
        poll: poll,
        delay: interval,
      );
    }
  }
}

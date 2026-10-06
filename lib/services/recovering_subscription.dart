import 'dart:async';

typedef EventConnection = ({
  Stream<String> events,
  Future<void> Function() stop,
});

class RecoveringSubscription {
  RecoveringSubscription({
    required this.connect,
    required this.onEvent,
    required this.onConnected,
    required this.onError,
    this.retryDelay = const Duration(seconds: 2),
  });

  final Future<EventConnection> Function() connect;
  final void Function(String) onEvent;
  final Future<void> Function() onConnected;
  final void Function(Object) onError;
  final Duration retryDelay;
  EventConnection? _connection;
  StreamSubscription<String>? _subscription;
  Future<void>? _opening;
  Timer? _retry;
  bool _stopped = false;
  int _generation = 0;

  Future<void> start() async {
    if (_stopped || _connection != null) return;
    final pending = _opening;
    if (pending != null) return pending;
    final opening = _open();
    _opening = opening;
    try {
      await opening;
    } finally {
      _opening = null;
      _scheduleRetry();
    }
  }

  Future<void> _open() async {
    final generation = ++_generation;
    try {
      final connection = await connect();
      if (_stopped || generation != _generation) {
        await connection.stop();
        return;
      }
      _connection = connection;
      _subscription = connection.events.listen(
        onEvent,
        onError: (Object error) {
          onError(error);
          unawaited(_lost(generation));
        },
        onDone: () => unawaited(_lost(generation)),
      );
      await onConnected();
    } catch (error) {
      onError(error);
      await _lost(generation);
      rethrow;
    }
  }

  Future<void> _lost(int generation) async {
    if (_stopped || generation != _generation) return;
    ++_generation;
    await _close();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_stopped || _connection != null || _retry != null) return;
    _retry = Timer(retryDelay, () {
      _retry = null;
      unawaited(start().catchError((Object _) {}));
    });
  }

  Future<void> _close() async {
    final subscription = _subscription;
    final connection = _connection;
    _subscription = null;
    _connection = null;
    try {
      await subscription?.cancel();
      await connection?.stop();
    } catch (error) {
      onError(error);
    }
  }

  Future<void> stop() async {
    _stopped = true;
    ++_generation;
    _retry?.cancel();
    _retry = null;
    await _close();
    try {
      await _opening;
    } catch (_) {
      // Connection errors are reported by _open.
    }
  }
}

import 'dart:async';

typedef AsyncAction = Future<void> Function();

class WindowCloseCoordinator {
  WindowCloseCoordinator({this.cleanupTimeout = const Duration(seconds: 8)});

  final Duration cleanupTimeout;
  Future<bool>? _closeInProgress;

  Future<bool> requestClose({
    required bool isCritical,
    required AsyncAction cleanup,
    required AsyncAction closeWindow,
  }) {
    final closeInProgress = _closeInProgress;
    if (closeInProgress != null) return closeInProgress;
    if (isCritical) return Future.value(false);

    final request = _close(cleanup, closeWindow);
    _closeInProgress = request;
    return request.whenComplete(() {
      if (identical(_closeInProgress, request)) {
        _closeInProgress = null;
      }
    });
  }

  Future<bool> _close(AsyncAction cleanup, AsyncAction closeWindow) async {
    try {
      await cleanup().timeout(cleanupTimeout);
    } catch (_) {
      // Cleanup is best-effort. A failed or unreachable device must not make
      // the desktop window impossible to close.
    }
    await closeWindow();
    return true;
  }
}
